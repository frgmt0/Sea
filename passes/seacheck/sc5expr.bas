9010 REM ---- ck_expr: the expression subtree E, bottom-up: nodes M(E,0)..E are its post-order, so
9015 REM every child is typed before its parent (no recursion over expressions). M(J,3) = the
9020 REM number of errors before node J (for the printf rule of DESIGN 2.6.2).
9025 SUB "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
9030 FOR J = M(E, 0) TO E
9035 LET M(J, 3) = X(9)
9040 LET M(J, 1) = 0
9045 LET M(J, 7) = 0
9050 LET M(J, 8) = 0
9055 LET K = N(J, 0)
9060 IF K < 25 THEN 9280
9065 ON K - 24 GOTO 9070, 9080, 9090, 9155, 9155, 9165, 9280, 9175, 9175, 9185, 9195, 9205, 9215, 9225, 9235, 9280, 9265, 9235, 9245, 9235, 9280, 9245, 9255, 9280, 9275
9070 LET M(J, 1) = -1
9075 GOTO 9280
9080 LET M(J, 1) = 4
9085 GOTO 9280
9090 REM a string literal is only allowed as an argument of printf (phase 1, DESIGN 2.6.2)
9095 LET P = N(J, 9)
9100 IF N(P, 0) <> 35 THEN 9135
9105 LET G = N(P, 7)
9110 IF N(G, 0) <> 30 THEN 9135
9115 IF S$(N(G, 6)) <> "printf" THEN 9135
9120 IF LEN(S$(N(G, 6))) <> 6 THEN 9135
9125 LET M(J, 1) = 5
9130 GOTO 9280
9135 REM reported here; the str type stays, so a str local is reported at its name too
9140 LET M(J, 1) = 5
9145 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
9150 GOTO 9280
9155 LET M(J, 1) = 2
9160 GOTO 9280
9165 CALL "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9170 GOTO 9280
9175 CALL "ck_un": N(), M(), T(), C(), X(), X$(), J
9180 GOTO 9280
9185 CALL "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9190 GOTO 9280
9195 CALL "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9200 GOTO 9280
9205 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "named arguments", "", "", 1
9210 GOTO 9280
9215 LET M(J, 1) = M(N(J, 7), 1)
9220 GOTO 9280
9225 CALL "ck_conv": N(), M(), T(), C(), X(), X$(), J
9230 GOTO 9280
9235 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "arrays", "", "", 1
9240 GOTO 9280
9245 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "structs", "", "", 1
9250 GOTO 9280
9255 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "records", "", "", 1
9260 GOTO 9280
9265 CALL "ck_rng": N(), M(), T(), C(), X(), X$(), J
9270 GOTO 9280
9275 CALL "ck_ifx": N(), M(), T(), C(), X(), X$(), J
9280 NEXT J
9285 SUBEND
9290 REM ---- ck_name: name J used as a value (LANGUAGE 7.2): local, constant or pi inf nan eps; the
9295 REM callee of a call and an assignment or ref target are left to their parent; what the name
9300 REM denotes is the rname's (rsv) ----------------------------------------------------------
9305 SUB "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9310 LET Q = N(J, 6)
9315 LET P = N(J, 9)
9320 CALL "rsv": N(), Y(), X(), X$(), S$(), J, R
9325 LET M(J, 2) = R
9330 LET Z = 0
9335 IF N(P, 0) <> 35 THEN 9355
9340 IF N(P, 7) <> J THEN 9355
9345 IF R <> 0 THEN 9480
9350 GOTO 9475
9355 IF N(P, 0) <> 13 THEN 9365
9360 IF N(P, 7) = J THEN 9380
9365 IF N(P, 0) <> 14 THEN 9375
9370 IF N(J, 8) <> 0 THEN 9380
9375 IF N(P, 0) <> 37 THEN 9385
9380 LET Z = 1
9385 IF R = 0 THEN 9475
9390 IF R < 0 THEN 9455
9395 IF Y(R, 0) = 4 THEN 9415
9400 IF Y(R, 0) = 2 THEN 9425
9405 IF Z = 1 THEN 9480
9410 GOTO 9475
9415 LET M(J, 1) = Y(R, 2)
9420 GOTO 9480
9425 IF Y(R, 4) = 2 THEN 9445
9430 REM constants are checked after those they name (ck_cord): this one is on a cycle
9435 CALL "er": N(), X(), X$(), J, "NOT_CONSTANT", "", "", "", 0
9440 GOTO 9480
9445 LET M(J, 1) = Y(R, 2)
9450 GOTO 9480
9455 IF R < -4 THEN 9470
9460 LET M(J, 1) = 4
9465 GOTO 9480
9470 IF Z = 1 THEN 9480
9475 CALL "er": N(), X(), X$(), J, "UNDECLARED", S$(Q), "", "", 1
9480 SUBEND
9485 REM ---- ck_un: unary - and ! (LANGUAGE 6.4, 6.5); -2^63 is one constant (DESIGN 3.5.5) ------
9490 SUB "ck_un": N(), M(), T(), C(), X(), X$(), J
9495 LET A = N(J, 7)
9500 CALL "vu": N(), M(), T(), X(), X$(), A, D
9505 IF D = 0 THEN 9615
9510 IF N(J, 0) = 33 THEN 9585
9515 IF D = -1 THEN 9545
9520 IF D = 3 THEN 9575
9525 IF D = 4 THEN 9575
9530 CALL "tyn": T(), D, A$
9535 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "-", A$, "", 2
9540 GOTO 9615
9545 IF N(A, 0) <> 25 THEN 9575
9550 LET R0 = M(A, 5)
9555 IF C(R0, 1) <> 32768 THEN 9575
9560 IF C(R0, 2) + C(R0, 3) + C(R0, 4) <> 0 THEN 9575
9565 REM the operand 2^63: the neg is written as the constant -2^63, its operand is not written
9570 LET M(A, 8) = -A
9575 LET M(J, 1) = D
9580 GOTO 9615
9585 IF D = 2 THEN 9575
9590 IF D <> -1 THEN 9605
9595 CALL "stl": N(), M(), C(), X(), X$(), A, 3
9600 LET D = 3
9605 CALL "tyn": T(), D, A$
9610 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "!", A$, "", 2
9615 SUBEND
9620 REM ---- num2: operands A, B (types G1, G2) of a numeric operator: untyped constants take the
9625 REM other operand's type (i64 when both are untyped), the i64 side of a mixed pair is converted;
9630 REM Z = 1 when an operand is not numeric; R the common type (LANGUAGE 4.2) -----------------
9635 SUB "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
9640 LET Z = 0
9645 LET R = 0
9650 LET U = G1
9655 LET V = G2
9660 IF U <> -1 THEN 9690
9665 LET D = 3
9670 IF V <> 4 THEN 9680
9675 LET D = 4
9680 CALL "stl": N(), M(), C(), X(), X$(), A, D
9685 LET U = D
9690 IF V <> -1 THEN 9720
9695 LET D = 3
9700 IF U <> 4 THEN 9710
9705 LET D = 4
9710 CALL "stl": N(), M(), C(), X(), X$(), B, D
9715 LET V = D
9720 IF U < 3 THEN 9780
9725 IF U > 4 THEN 9780
9730 IF V < 3 THEN 9780
9735 IF V > 4 THEN 9780
9740 LET R = U
9745 IF U = V THEN 9785
9750 LET R = 4
9755 IF U = 4 THEN 9770
9760 LET M(A, 7) = 1
9765 GOTO 9785
9770 LET M(B, 7) = 1
9775 GOTO 9785
9780 LET Z = 1
9785 SUBEND
9790 REM ---- ck_bin: binary operator J (LANGUAGE 6.1-6.6, Appendix B; phase 1: scalars) ----------
9795 SUB "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9800 LET A = N(J, 7)
9805 LET B = N(A, 8)
9810 LET O = N(J, 1)
9815 CALL "vu": N(), M(), T(), X(), X$(), A, G1
9820 CALL "vu": N(), M(), T(), X(), X$(), B, G2
9825 IF G1 = 0 THEN 10180
9830 IF G2 = 0 THEN 10180
9835 REM + and comparisons on str are phase 2 (DESIGN 2.6.2)
9840 IF G1 = 5 THEN 10135
9845 IF G2 = 5 THEN 10135
9850 ON O GOTO 9855, 9855, 9855, 9895, 9950, 9980, 10145, 10075, 10075, 10095, 10095, 10095, 10095, 10115, 10115, 10115, 10115
9855 IF G1 <> -1 THEN 9875
9860 IF G2 <> -1 THEN 9875
9865 LET M(J, 1) = -1
9870 GOTO 10180
9875 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
9880 IF Z = 1 THEN 10145
9885 LET M(J, 1) = R
9890 GOTO 10180
9895 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
9900 IF Z = 1 THEN 10145
9905 REM / divides f64 values: both i64 operands are converted (LANGUAGE 6.5)
9910 LET M(A, 7) = 0
9915 LET M(B, 7) = 0
9920 IF M(A, 1) <> 3 THEN 9930
9925 LET M(A, 7) = 1
9930 IF M(B, 1) <> 3 THEN 9940
9935 LET M(B, 7) = 1
9940 LET M(J, 1) = 4
9945 GOTO 10180
9950 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
9955 IF Z = 1 THEN 10145
9960 LET M(J, 1) = R
9965 IF R = 3 THEN 10180
9970 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "f64 %", "", "", 1
9975 GOTO 10180
9980 IF G1 = 2 THEN 10145
9985 IF G1 > 4 THEN 10145
9990 IF G2 = 2 THEN 10145
9995 IF G2 > 4 THEN 10145
10000 REM ^ is f64: an i64 or untyped operand is converted (LANGUAGE 4.2 (d), 6.5)
10005 IF G1 <> -1 THEN 10015
10010 CALL "stl": N(), M(), C(), X(), X$(), A, 4
10015 IF G1 <> 3 THEN 10025
10020 LET M(A, 7) = 1
10025 IF G2 <> -1 THEN 10035
10030 CALL "stl": N(), M(), C(), X(), X$(), B, 4
10035 IF G2 <> 3 THEN 10045
10040 LET M(B, 7) = 1
10045 LET M(J, 1) = 4
10050 REM powk k where sea.res has rpowk k (DESIGN 3.4.1 "Constant exponents"), else bin pow
10055 IF N(J, 3) = 0 THEN 10180
10060 LET M(J, 8) = N(J, 2) + 10
10065 LET M(M(B, 0), 8) = -B
10070 GOTO 10180
10075 IF G1 <> 2 THEN 10095
10080 IF G2 <> 2 THEN 10095
10085 LET M(J, 1) = 2
10090 GOTO 10180
10095 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
10100 IF Z = 1 THEN 10145
10105 LET M(J, 1) = 2
10110 GOTO 10180
10115 IF G1 <> 2 THEN 10145
10120 IF G2 <> 2 THEN 10145
10125 LET M(J, 1) = 2
10130 GOTO 10180
10135 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
10140 GOTO 10180
10145 CALL "fin": N(), M(), C(), X(), X$(), A
10150 CALL "fin": N(), M(), C(), X(), X$(), B
10155 CALL "opn": O, A$
10160 CALL "tyn": T(), M(A, 1), B$
10165 CALL "tyn": T(), M(B, 1), C$
10170 CALL "er": N(), X(), X$(), J, "BAD_OPERANDS", A$, B$, C$, 3
10175 LET M(J, 1) = 0
10180 SUBEND
10185 REM ---- ck_ifx: if expression J (LANGUAGE 6.10, 4.2 (f)) --------------------------------------
10190 SUB "ck_ifx": N(), M(), T(), C(), X(), X$(), J
10195 LET E = N(J, 7)
10200 LET A = N(E, 8)
10205 LET B = N(A, 8)
10210 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
10215 CALL "vu": N(), M(), T(), X(), X$(), A, G1
10220 CALL "vu": N(), M(), T(), X(), X$(), B, G2
10225 IF G1 = 0 THEN 10325
10230 IF G2 = 0 THEN 10325
10235 IF G1 <> -1 THEN 10265
10240 LET D = 3
10245 IF G2 <> 4 THEN 10255
10250 LET D = 4
10255 CALL "stl": N(), M(), C(), X(), X$(), A, D
10260 LET G1 = D
10265 IF G2 <> -1 THEN 10295
10270 LET D = 3
10275 IF G1 <> 4 THEN 10285
10280 LET D = 4
10285 CALL "stl": N(), M(), C(), X(), X$(), B, D
10290 LET G2 = D
10295 IF G1 = G2 THEN 10320
10300 CALL "tyn": T(), G1, A$
10305 CALL "tyn": T(), G2, B$
10310 CALL "er": N(), X(), X$(), B, "TYPE_MISMATCH", A$, B$, "", 2
10315 GOTO 10325
10320 LET M(J, 1) = G1
10325 SUBEND
10330 REM ---- ck_conv: f64(x), i64(x) of bool, i64, f64 (LANGUAGE 10.1; lib nodes, DESIGN 3.5.5) -----
10335 SUB "ck_conv": N(), M(), T(), C(), X(), X$(), J
10340 LET A = N(J, 7)
10345 LET O = N(J, 1)
10350 IF O < 3 THEN 10365
10355 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
10360 GOTO 10430
10365 CALL "vu": N(), M(), T(), X(), X$(), A, D
10370 IF D = 0 THEN 10430
10375 IF D <> -1 THEN 10395
10380 REM an untyped argument is i64 (both conversions accept i64, LANGUAGE 4.2)
10385 CALL "stl": N(), M(), C(), X(), X$(), A, 3
10390 LET D = 3
10395 REM bool, i64 and f64 (the identity too: f64(2.5), i64(7) in tests/programs/op_cvt)
10400 IF D < 2 THEN 10410
10405 IF D <= 4 THEN 10425
10410 CALL "tyn": T(), D, B$
10415 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", SEG$("f64i64", 3 * O - 2, 3 * O), B$, "", 2
10420 GOTO 10430
10425 LET M(J, 1) = 5 - O
10430 SUBEND
10435 REM ---- ck_rng: a range J; in phase 1 only as the iterable of a for: i64 bounds and step --------
10440 SUB "ck_rng": N(), M(), T(), C(), X(), X$(), J
10445 IF N(N(J, 9), 0) <> 18 THEN 10520
10450 LET A = N(J, 7)
10455 IF A = 0 THEN 10510
10460 CALL "vu": N(), M(), T(), X(), X$(), A, D
10465 IF D <> -1 THEN 10480
10470 CALL "stl": N(), M(), C(), X(), X$(), A, 3
10475 LET D = 3
10480 IF D = 3 THEN 10500
10485 IF D = 0 THEN 10500
10490 CALL "tyn": T(), D, B$
10495 CALL "er": N(), X(), X$(), A, "TYPE_MISMATCH", "i64", B$, "", 2
10500 LET A = N(A, 8)
10505 GOTO 10455
10510 CALL "tvec": T(), N(), X(), X$(), 3, R
10515 LET M(J, 1) = R
10520 SUBEND
10525 REM ---- rsv: R = what rname J denotes (DESIGN 3.4.1): a local of the current function X(14) (its
10530 REM row from the lid), a constant, function or struct (its item row), a predeclared name (-slot)
10535 REM or nothing (0) -------------------------------------------------------------------------
10540 SUB "rsv": N(), Y(), X(), X$(), S$(), J, R
10545 LET R = 0
10550 IF N(J, 1) = 0 THEN 10615
10555 LET H = N(J, 2)
10560 ON N(J, 1) GOTO 10565, 10575, 10585, 10595, 10605, 10615
10565 LET R = Y(X(14), 9) - 1 + H
10570 GOTO 10615
10575 LET R = X(31) + H
10580 GOTO 10615
10585 LET R = H
10590 GOTO 10615
10595 LET R = X(11) + H
10600 GOTO 10615
10605 CALL "pdx": X$(), S$(N(J, 6)), P
10610 LET R = -P
10615 SUBEND
