7145 REM ---- ck_expr: the expression subtree E, bottom-up: nodes M(E,0)..E are its post-order, so
7150 REM every child is typed before its parent (no recursion over expressions). M(J,3) = the
7155 REM number of errors before node J (for the printf rule of DESIGN 2.6.2).
7160 SUB "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
7165 FOR J = M(E, 0) TO E
7170 LET M(J, 3) = X(9)
7175 LET M(J, 1) = 0
7180 LET M(J, 7) = 0
7185 LET M(J, 8) = 0
7190 LET K = N(J, 0)
7195 IF K < 25 THEN 7415
7200 ON K - 24 GOTO 7205, 7215, 7225, 7290, 7290, 7300, 7415, 7310, 7310, 7320, 7330, 7340, 7350, 7360, 7370, 7415, 7400, 7370, 7380, 7370, 7415, 7380, 7390, 7415, 7410
7205 LET M(J, 1) = -1
7210 GOTO 7415
7215 LET M(J, 1) = 4
7220 GOTO 7415
7225 REM a string literal is only allowed as an argument of printf (phase 1, DESIGN 2.6.2)
7230 LET P = N(J, 9)
7235 IF N(P, 0) <> 35 THEN 7270
7240 LET G = N(P, 7)
7245 IF N(G, 0) <> 30 THEN 7270
7250 IF S$(N(G, 6)) <> "printf" THEN 7270
7255 IF LEN(S$(N(G, 6))) <> 6 THEN 7270
7260 LET M(J, 1) = 5
7265 GOTO 7415
7270 REM reported here; the str type stays, so a str local is reported at its name too
7275 LET M(J, 1) = 5
7280 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
7285 GOTO 7415
7290 LET M(J, 1) = 2
7295 GOTO 7415
7300 CALL "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7305 GOTO 7415
7310 CALL "ck_un": N(), M(), T(), C(), X(), X$(), J
7315 GOTO 7415
7320 CALL "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7325 GOTO 7415
7330 CALL "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7335 GOTO 7415
7340 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "named arguments", "", "", 1
7345 GOTO 7415
7350 LET M(J, 1) = M(N(J, 7), 1)
7355 GOTO 7415
7360 CALL "ck_conv": N(), M(), T(), C(), X(), X$(), J
7365 GOTO 7415
7370 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "arrays", "", "", 1
7375 GOTO 7415
7380 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "structs", "", "", 1
7385 GOTO 7415
7390 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "records", "", "", 1
7395 GOTO 7415
7400 CALL "ck_rng": N(), M(), T(), C(), X(), X$(), J
7405 GOTO 7415
7410 CALL "ck_ifx": N(), M(), T(), C(), X(), X$(), J
7415 NEXT J
7420 SUBEND
7425 REM ---- ck_name: name J used as a value (LANGUAGE 7.2): local, constant or pi inf nan eps; the
7430 REM callee of a call and an assignment or ref target are left to their parent -------------
7435 SUB "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7440 LET Q = N(J, 6)
7445 LET P = N(J, 9)
7450 CALL "lk": Y(), W(), X(), X$(), S$(), Q, R
7455 LET M(J, 2) = R
7460 LET Z = 0
7465 IF N(P, 0) <> 35 THEN 7485
7470 IF N(P, 7) <> J THEN 7485
7475 IF R <> 0 THEN 7610
7480 GOTO 7605
7485 IF N(P, 0) <> 13 THEN 7495
7490 IF N(P, 7) = J THEN 7510
7495 IF N(P, 0) <> 14 THEN 7505
7500 IF N(J, 8) <> 0 THEN 7510
7505 IF N(P, 0) <> 37 THEN 7515
7510 LET Z = 1
7515 IF R = 0 THEN 7605
7520 IF R < 0 THEN 7585
7525 IF Y(R, 0) = 4 THEN 7545
7530 IF Y(R, 0) = 2 THEN 7555
7535 IF Z = 1 THEN 7610
7540 GOTO 7605
7545 LET M(J, 1) = Y(R, 2)
7550 GOTO 7610
7555 IF Y(R, 4) = 2 THEN 7575
7560 REM constants are checked after those they name (ck_cord): this one is on a cycle
7565 CALL "er": N(), X(), X$(), J, "NOT_CONSTANT", "", "", "", 0
7570 GOTO 7610
7575 LET M(J, 1) = Y(R, 2)
7580 GOTO 7610
7585 IF R < -4 THEN 7600
7590 LET M(J, 1) = 4
7595 GOTO 7610
7600 IF Z = 1 THEN 7610
7605 CALL "er": N(), X(), X$(), J, "UNDECLARED", S$(Q), "", "", 1
7610 SUBEND
7615 REM ---- ck_un: unary - and ! (LANGUAGE 6.4, 6.5); -2^63 is one constant (DESIGN 3.5.5) ------
7620 SUB "ck_un": N(), M(), T(), C(), X(), X$(), J
7625 LET A = N(J, 7)
7630 CALL "vu": N(), M(), T(), X(), X$(), A, D
7635 IF D = 0 THEN 7745
7640 IF N(J, 0) = 33 THEN 7715
7645 IF D = -1 THEN 7675
7650 IF D = 3 THEN 7705
7655 IF D = 4 THEN 7705
7660 CALL "tyn": T(), D, A$
7665 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "-", A$, "", 2
7670 GOTO 7745
7675 IF N(A, 0) <> 25 THEN 7705
7680 LET R0 = M(A, 5)
7685 IF C(R0, 1) <> 32768 THEN 7705
7690 IF C(R0, 2) + C(R0, 3) + C(R0, 4) <> 0 THEN 7705
7695 REM the operand 2^63: the neg is written as the constant -2^63, its operand is not written
7700 LET M(A, 8) = -A
7705 LET M(J, 1) = D
7710 GOTO 7745
7715 IF D = 2 THEN 7705
7720 IF D <> -1 THEN 7735
7725 CALL "stl": N(), M(), C(), X(), X$(), A, 3
7730 LET D = 3
7735 CALL "tyn": T(), D, A$
7740 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "!", A$, "", 2
7745 SUBEND
7750 REM ---- num2: operands A, B (types G1, G2) of a numeric operator: untyped constants take the
7755 REM other operand's type (i64 when both are untyped), the i64 side of a mixed pair is converted;
7760 REM Z = 1 when an operand is not numeric; R the common type (LANGUAGE 4.2) -----------------
7765 SUB "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7770 LET Z = 0
7775 LET R = 0
7780 LET U = G1
7785 LET V = G2
7790 IF U <> -1 THEN 7820
7795 LET D = 3
7800 IF V <> 4 THEN 7810
7805 LET D = 4
7810 CALL "stl": N(), M(), C(), X(), X$(), A, D
7815 LET U = D
7820 IF V <> -1 THEN 7850
7825 LET D = 3
7830 IF U <> 4 THEN 7840
7835 LET D = 4
7840 CALL "stl": N(), M(), C(), X(), X$(), B, D
7845 LET V = D
7850 IF U < 3 THEN 7910
7855 IF U > 4 THEN 7910
7860 IF V < 3 THEN 7910
7865 IF V > 4 THEN 7910
7870 LET R = U
7875 IF U = V THEN 7915
7880 LET R = 4
7885 IF U = 4 THEN 7900
7890 LET M(A, 7) = 1
7895 GOTO 7915
7900 LET M(B, 7) = 1
7905 GOTO 7915
7910 LET Z = 1
7915 SUBEND
7920 REM ---- ck_bin: binary operator J (LANGUAGE 6.1-6.6, Appendix B; phase 1: scalars) ----------
7925 SUB "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7930 LET A = N(J, 7)
7935 LET B = N(A, 8)
7940 LET O = N(J, 1)
7945 CALL "vu": N(), M(), T(), X(), X$(), A, G1
7950 CALL "vu": N(), M(), T(), X(), X$(), B, G2
7955 IF G1 = 0 THEN 8315
7960 IF G2 = 0 THEN 8315
7965 REM + and comparisons on str are phase 2 (DESIGN 2.6.2)
7970 IF G1 = 5 THEN 8270
7975 IF G2 = 5 THEN 8270
7980 ON O GOTO 7985, 7985, 7985, 8025, 8080, 8110, 8280, 8210, 8210, 8230, 8230, 8230, 8230, 8250, 8250, 8250, 8250
7985 IF G1 <> -1 THEN 8005
7990 IF G2 <> -1 THEN 8005
7995 LET M(J, 1) = -1
8000 GOTO 8315
8005 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
8010 IF Z = 1 THEN 8280
8015 LET M(J, 1) = R
8020 GOTO 8315
8025 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
8030 IF Z = 1 THEN 8280
8035 REM / divides f64 values: both i64 operands are converted (LANGUAGE 6.5)
8040 LET M(A, 7) = 0
8045 LET M(B, 7) = 0
8050 IF M(A, 1) <> 3 THEN 8060
8055 LET M(A, 7) = 1
8060 IF M(B, 1) <> 3 THEN 8070
8065 LET M(B, 7) = 1
8070 LET M(J, 1) = 4
8075 GOTO 8315
8080 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
8085 IF Z = 1 THEN 8280
8090 LET M(J, 1) = R
8095 IF R = 3 THEN 8315
8100 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "f64 %", "", "", 1
8105 GOTO 8315
8110 IF G1 = 2 THEN 8280
8115 IF G1 > 4 THEN 8280
8120 IF G2 = 2 THEN 8280
8125 IF G2 > 4 THEN 8280
8130 REM ^ is f64: an i64 or untyped operand is converted (LANGUAGE 4.2 (d), 6.5)
8135 IF G1 <> -1 THEN 8145
8140 CALL "stl": N(), M(), C(), X(), X$(), A, 4
8145 IF G1 <> 3 THEN 8155
8150 LET M(A, 7) = 1
8155 IF G2 <> -1 THEN 8165
8160 CALL "stl": N(), M(), C(), X(), X$(), B, 4
8165 IF G2 <> 3 THEN 8175
8170 LET M(B, 7) = 1
8175 LET M(J, 1) = 4
8180 CALL "powk": N(), M(), Y(), C(), W(), X(), X$(), B, K0, Z
8185 REM not a powk (Z 0, or 2 for a failed constant): bin pow, the run-time pow (DESIGN 4.10.5)
8190 IF Z <> 1 THEN 8315
8195 LET M(J, 8) = K0 + 10
8200 LET M(M(B, 0), 8) = -B
8205 GOTO 8315
8210 IF G1 <> 2 THEN 8230
8215 IF G2 <> 2 THEN 8230
8220 LET M(J, 1) = 2
8225 GOTO 8315
8230 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
8235 IF Z = 1 THEN 8280
8240 LET M(J, 1) = 2
8245 GOTO 8315
8250 IF G1 <> 2 THEN 8280
8255 IF G2 <> 2 THEN 8280
8260 LET M(J, 1) = 2
8265 GOTO 8315
8270 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
8275 GOTO 8315
8280 CALL "fin": N(), M(), C(), X(), X$(), A
8285 CALL "fin": N(), M(), C(), X(), X$(), B
8290 CALL "opn": O, A$
8295 CALL "tyn": T(), M(A, 1), B$
8300 CALL "tyn": T(), M(B, 1), C$
8305 CALL "er": N(), X(), X$(), J, "BAD_OPERANDS", A$, B$, C$, 3
8310 LET M(J, 1) = 0
8315 SUBEND
8320 REM ---- ck_ifx: if expression J (LANGUAGE 6.10, 4.2 (f)) --------------------------------------
8325 SUB "ck_ifx": N(), M(), T(), C(), X(), X$(), J
8330 LET E = N(J, 7)
8335 LET A = N(E, 8)
8340 LET B = N(A, 8)
8345 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
8350 CALL "vu": N(), M(), T(), X(), X$(), A, G1
8355 CALL "vu": N(), M(), T(), X(), X$(), B, G2
8360 IF G1 = 0 THEN 8460
8365 IF G2 = 0 THEN 8460
8370 IF G1 <> -1 THEN 8400
8375 LET D = 3
8380 IF G2 <> 4 THEN 8390
8385 LET D = 4
8390 CALL "stl": N(), M(), C(), X(), X$(), A, D
8395 LET G1 = D
8400 IF G2 <> -1 THEN 8430
8405 LET D = 3
8410 IF G1 <> 4 THEN 8420
8415 LET D = 4
8420 CALL "stl": N(), M(), C(), X(), X$(), B, D
8425 LET G2 = D
8430 IF G1 = G2 THEN 8455
8435 CALL "tyn": T(), G1, A$
8440 CALL "tyn": T(), G2, B$
8445 CALL "er": N(), X(), X$(), B, "TYPE_MISMATCH", A$, B$, "", 2
8450 GOTO 8460
8455 LET M(J, 1) = G1
8460 SUBEND
8465 REM ---- ck_conv: f64(x), i64(x) of bool, i64, f64 (LANGUAGE 10.1; lib nodes, DESIGN 3.5.5) -----
8470 SUB "ck_conv": N(), M(), T(), C(), X(), X$(), J
8475 LET A = N(J, 7)
8480 LET O = N(J, 1)
8485 IF O < 3 THEN 8500
8490 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
8495 GOTO 8565
8500 CALL "vu": N(), M(), T(), X(), X$(), A, D
8505 IF D = 0 THEN 8565
8510 IF D <> -1 THEN 8530
8515 REM an untyped argument is i64 (both conversions accept i64, LANGUAGE 4.2)
8520 CALL "stl": N(), M(), C(), X(), X$(), A, 3
8525 LET D = 3
8530 REM bool, i64 and f64 (the identity too: f64(2.5), i64(7) in tests/programs/op_cvt)
8535 IF D < 2 THEN 8545
8540 IF D <= 4 THEN 8560
8545 CALL "tyn": T(), D, B$
8550 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", SEG$("f64i64", 3 * O - 2, 3 * O), B$, "", 2
8555 GOTO 8565
8560 LET M(J, 1) = 5 - O
8565 SUBEND
8570 REM ---- ck_rng: a range J; in phase 1 only as the iterable of a for: i64 bounds and step --------
8575 SUB "ck_rng": N(), M(), T(), C(), X(), X$(), J
8580 IF N(N(J, 9), 0) <> 18 THEN 8655
8585 LET A = N(J, 7)
8590 IF A = 0 THEN 8645
8595 CALL "vu": N(), M(), T(), X(), X$(), A, D
8600 IF D <> -1 THEN 8615
8605 CALL "stl": N(), M(), C(), X(), X$(), A, 3
8610 LET D = 3
8615 IF D = 3 THEN 8635
8620 IF D = 0 THEN 8635
8625 CALL "tyn": T(), D, B$
8630 CALL "er": N(), X(), X$(), A, "TYPE_MISMATCH", "i64", B$, "", 2
8635 LET A = N(A, 8)
8640 GOTO 8590
8645 CALL "tvec": T(), N(), X(), X$(), 3, R
8650 LET M(J, 1) = R
8655 SUBEND
