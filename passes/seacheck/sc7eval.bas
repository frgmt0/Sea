9410 REM ---- powk: Z = 1 when the exponent B of a ^ is a constant whose exact value is an integer K0
9415 REM with |K0| <= LIM_POWK (DESIGN 3.5.5 "Constant exponents", LANGUAGE 6.5) ------------------
9420 SUB "powk": N(), M(), Y(), C(), W(), X(), X$(), B, K0, Z
9425 LET Z = 0
9430 LET K0 = 0
9435 CALL "evx": N(), M(), Y(), C(), W(), X(), X$(), B, K, A3, A2, A1, A0
9440 IF K = 0 THEN 9530
9445 IF K = 1 THEN 9465
9450 CALL "FETOI": A3, A2, A1, A0, B3, B2, B1, B0, E
9455 IF E <> 0 THEN 9530
9460 GOTO 9485
9465 LET B3 = A3
9470 LET B2 = A2
9475 LET B1 = A1
9480 LET B0 = A0
9485 IF B3 + B2 + B1 <> 0 THEN 9510
9490 IF B0 > X(25) THEN 9530
9495 LET K0 = B0
9500 LET Z = 1
9505 GOTO 9530
9510 IF B3 + B2 + B1 <> 3 * 65535 THEN 9530
9515 IF B0 < 65536 - X(25) THEN 9530
9520 LET K0 = B0 - 65536
9525 LET Z = 1
9530 SUBEND
9535 REM ---- evx: the exact value of constant expression E (DESIGN 2.8, 3.5.5): K 1 i64, 2 f64 (limbs
9540 REM A3..A0), 0 not a value (a call, a variable, a ^ that is not a powk, an i64 overflow or
9545 REM division by zero, a comparison). Post-order with a value stack in W from X(11) up, five
9550 REM words per value (kind, four limbs); constants are evaluated once (cval). ---------------
9555 SUB "evx": N(), M(), Y(), C(), W(), X(), X$(), E, K, A3, A2, A1, A0
9560 LET B9 = X(11)
9565 LET P = B9
9570 FOR J = M(E, 0) TO E
9575 LET P0 = P - 5 * M(J, 6)
9580 LET V = 0
9585 LET R3 = 0
9590 LET R2 = 0
9595 LET R1 = 0
9600 LET R0 = 0
9605 LET K1 = N(J, 0)
9610 IF K1 = 25 THEN 9640
9615 IF K1 = 26 THEN 9715
9620 IF K1 = 30 THEN 9750
9625 IF K1 = 32 THEN 9870
9630 IF K1 = 34 THEN 9975
9635 GOTO 9980
9640 LET H = M(J, 5)
9645 LET R3 = C(H, 1)
9650 LET R2 = C(H, 2)
9655 LET R1 = C(H, 3)
9660 LET R0 = C(H, 4)
9665 LET V = 1
9670 IF M(J, 1) <> 4 THEN 9980
9675 LET V = 2
9680 IF R3 <> 32768 THEN 9705
9685 IF R2 + R1 + R0 <> 0 THEN 9705
9690 REM the literal 2^63 (only under neg): +2^63 in f64
9695 LET R3 = 17376
9700 GOTO 9980
9705 CALL "FEFRI": C(H, 1), C(H, 2), C(H, 3), C(H, 4), R3, R2, R1, R0, Z
9710 GOTO 9980
9715 LET H = M(J, 5)
9720 LET R3 = C(H, 1)
9725 LET R2 = C(H, 2)
9730 LET R1 = C(H, 3)
9735 LET R0 = C(H, 4)
9740 LET V = 2
9745 GOTO 9980
9750 LET S = M(J, 2)
9755 IF S = 0 THEN 9980
9760 IF S < 0 THEN 9825
9765 IF Y(S, 0) <> 2 THEN 9980
9770 LET X(11) = P
9775 CALL "cval": N(), M(), Y(), C(), W(), X(), X$(), S
9780 LET X(11) = B9
9785 IF Y(S, 7) > 2 THEN 9980
9790 LET V = Y(S, 7)
9795 LET H = Y(S, 8)
9800 LET R3 = C(H, 1)
9805 LET R2 = C(H, 2)
9810 LET R1 = C(H, 3)
9815 LET R0 = C(H, 4)
9820 GOTO 9980
9825 IF S < -4 THEN 9980
9830 REM pi inf nan eps (LANGUAGE 10.1; bits of DESIGN 3.5.5)
9835 LET V = 2
9840 LET R3 = VAL(SEG$("16393327523276015536", 5 * (-S) - 4, 5 * (-S)))
9845 IF S <> -1 THEN 9980
9850 LET R2 = 8699
9855 LET R1 = 21572
9860 LET R0 = 11544
9865 GOTO 9980
9870 LET G = N(J, 7)
9875 IF N(G, 0) <> 25 THEN 9930
9880 LET H = M(G, 5)
9885 IF C(H, 1) <> 32768 THEN 9930
9890 IF C(H, 2) + C(H, 3) + C(H, 4) <> 0 THEN 9930
9895 REM -2^63: the i64 pattern #8000000000000000, or the f64 -2^63
9900 LET V = 1
9905 LET R3 = 32768
9910 IF M(J, 1) <> 4 THEN 9980
9915 LET V = 2
9920 LET R3 = 50144
9925 GOTO 9980
9930 IF W(P0 + 1) = 1 THEN 9955
9935 IF W(P0 + 1) <> 2 THEN 9980
9940 CALL "FENEG": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), R3, R2, R1, R0
9945 LET V = 2
9950 GOTO 9980
9955 CALL "LMNEG": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), R3, R2, R1, R0, Z
9960 IF Z = 1 THEN 9980
9965 LET V = 1
9970 GOTO 9980
9975 CALL "evbin": N(), M(), W(), J, P0, V, R3, R2, R1, R0
9980 IF M(J, 7) <> 1 THEN 10000
9985 IF V <> 1 THEN 10000
9990 CALL "FEFRI": R3 + 0, R2 + 0, R1 + 0, R0 + 0, R3, R2, R1, R0, Z
9995 LET V = 2
10000 LET P = P0
10005 IF P + 5 < X(12) - 2 THEN 10025
10010 CALL "fatal": N(), X(), X$(), J, "nesting"
10015 LET V = 0
10020 GOTO 10060
10025 LET W(P + 1) = V
10030 LET W(P + 2) = R3
10035 LET W(P + 3) = R2
10040 LET W(P + 4) = R1
10045 LET W(P + 5) = R0
10050 LET P = P + 5
10055 NEXT J
10060 LET K = W(B9 + 1)
10065 LET A3 = W(B9 + 2)
10070 LET A2 = W(B9 + 3)
10075 LET A1 = W(B9 + 4)
10080 LET A0 = W(B9 + 5)
10085 IF V <> 0 THEN 10095
10090 LET K = 0
10095 SUBEND
10100 REM ---- evbin: the value of binary node J from its operands at W(P0+1..P0+10) (see evx); a
10105 REM powk by the pinned multiplications of LANGUAGE 6.5 ---------------------------------------
10110 SUB "evbin": N(), M(), W(), J, P0, V, R3, R2, R1, R0
10115 LET V = 0
10120 LET U = W(P0 + 1)
10125 LET U2 = W(P0 + 6)
10130 LET O = N(J, 1)
10135 IF M(J, 8) > 0 THEN 10275
10140 IF U = 0 THEN 10435
10145 IF U <> U2 THEN 10435
10150 IF O > 5 THEN 10435
10155 IF U = 2 THEN 10215
10160 ON O GOTO 10165, 10175, 10185, 10435, 10195
10165 CALL "LMADD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
10170 GOTO 10200
10175 CALL "LMSUB": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
10180 GOTO 10200
10185 CALL "LMMUL": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
10190 GOTO 10200
10195 CALL "LMMOD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
10200 IF Z <> 0 THEN 10435
10205 LET V = 1
10210 GOTO 10435
10215 ON O GOTO 10220, 10230, 10240, 10250, 10260
10220 CALL "FEADD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
10225 GOTO 10265
10230 CALL "FESUB": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
10235 GOTO 10265
10240 CALL "FEMUL": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
10245 GOTO 10265
10250 CALL "FEDIV": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
10255 GOTO 10265
10260 CALL "FEMOD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
10265 LET V = 2
10270 GOTO 10435
10275 REM x^0 = 1, x^1 = x, x^2 = x*x, x^3 = (x*x)*x, x^4 = (x*x)*(x*x), x^-k = 1/(x^k)
10280 IF U <> 2 THEN 10435
10285 LET K = M(J, 8) - 10
10290 LET K1 = ABS(K)
10295 LET R3 = W(P0 + 2)
10300 LET R2 = W(P0 + 3)
10305 LET R1 = W(P0 + 4)
10310 LET R0 = W(P0 + 5)
10315 IF K1 > 0 THEN 10345
10320 LET R3 = 16368
10325 LET R2 = 0
10330 LET R1 = 0
10335 LET R0 = 0
10340 GOTO 10430
10345 IF K1 = 1 THEN 10400
10350 CALL "FEMUL": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), Q3, Q2, Q1, Q0
10355 LET R3 = Q3
10360 LET R2 = Q2
10365 LET R1 = Q1
10370 LET R0 = Q0
10375 IF K1 = 2 THEN 10400
10380 IF K1 = 4 THEN 10395
10385 CALL "FEMUL": Q3, Q2, Q1, Q0, W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), R3, R2, R1, R0
10390 GOTO 10400
10395 CALL "FEMUL": Q3, Q2, Q1, Q0, Q3, Q2, Q1, Q0, R3, R2, R1, R0
10400 IF K >= 0 THEN 10430
10405 CALL "FEDIV": 16368, 0, 0, 0, R3, R2, R1, R0, Q3, Q2, Q1, Q0
10410 LET R3 = Q3
10415 LET R2 = Q2
10420 LET R1 = Q1
10425 LET R0 = Q0
10430 LET V = 2
10435 SUBEND
10440 REM ---- cval: the value of const item S, once: Y(S,7) 1 i64, 2 f64 (limbs in C row Y(S,8)),
10445 REM 3 no value (also while it is being evaluated) ------------------------------------------
10450 SUB "cval": N(), M(), Y(), C(), W(), X(), X$(), S
10455 IF Y(S, 7) <> 0 THEN 10545
10460 LET Y(S, 7) = 3
10465 LET F = Y(S, 3)
10470 LET E = N(F, 7)
10475 IF N(F, 1) = 0 THEN 10485
10480 LET E = N(E, 8)
10485 CALL "evx": N(), M(), Y(), C(), W(), X(), X$(), E, K, A3, A2, A1, A0
10490 IF K = 0 THEN 10545
10495 IF X(5) < X(22) THEN 10510
10500 CALL "fatal": N(), X(), X$(), F, "constants"
10505 GOTO 10545
10510 LET X(5) = X(5) + 1
10515 LET C(X(5), 1) = A3
10520 LET C(X(5), 2) = A2
10525 LET C(X(5), 3) = A1
10530 LET C(X(5), 4) = A0
10535 LET Y(S, 8) = X(5)
10540 LET Y(S, 7) = K
10545 SUBEND
