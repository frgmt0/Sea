7095 REM ---- ck_expr: the expression subtree E, bottom-up: nodes M(E,0)..E are its post-order, so
7100 REM every child is typed before its parent (no recursion over expressions). M(J,3) = the
7105 REM number of errors before node J (for the printf rule of DESIGN 2.6.2).
7110 SUB "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
7115 FOR J = M(E, 0) TO E
7120 LET M(J, 3) = X(9)
7125 LET M(J, 1) = 0
7130 LET M(J, 7) = 0
7135 LET M(J, 8) = 0
7140 LET K = N(J, 0)
7145 IF K < 25 THEN 7365
7150 ON K - 24 GOTO 7155, 7165, 7175, 7240, 7240, 7250, 7365, 7260, 7260, 7270, 7280, 7290, 7300, 7310, 7320, 7365, 7350, 7320, 7330, 7320, 7365, 7330, 7340, 7365, 7360
7155 LET M(J, 1) = -1
7160 GOTO 7365
7165 LET M(J, 1) = 4
7170 GOTO 7365
7175 REM a string literal is only allowed as an argument of printf (phase 1, DESIGN 2.6.2)
7180 LET P = N(J, 9)
7185 IF N(P, 0) <> 35 THEN 7220
7190 LET G = N(P, 7)
7195 IF N(G, 0) <> 30 THEN 7220
7200 IF S$(N(G, 6)) <> "printf" THEN 7220
7205 IF LEN(S$(N(G, 6))) <> 6 THEN 7220
7210 LET M(J, 1) = 5
7215 GOTO 7365
7220 REM reported here; the str type stays, so a str local is reported at its name too
7225 LET M(J, 1) = 5
7230 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
7235 GOTO 7365
7240 LET M(J, 1) = 2
7245 GOTO 7365
7250 CALL "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7255 GOTO 7365
7260 CALL "ck_un": N(), M(), T(), C(), X(), X$(), J
7265 GOTO 7365
7270 CALL "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7275 GOTO 7365
7280 CALL "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7285 GOTO 7365
7290 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "named arguments", "", "", 1
7295 GOTO 7365
7300 LET M(J, 1) = M(N(J, 7), 1)
7305 GOTO 7365
7310 CALL "ck_conv": N(), M(), T(), C(), X(), X$(), J
7315 GOTO 7365
7320 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "arrays", "", "", 1
7325 GOTO 7365
7330 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "structs", "", "", 1
7335 GOTO 7365
7340 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "records", "", "", 1
7345 GOTO 7365
7350 CALL "ck_rng": N(), M(), T(), C(), X(), X$(), J
7355 GOTO 7365
7360 CALL "ck_ifx": N(), M(), T(), C(), X(), X$(), J
7365 NEXT J
7370 SUBEND
7375 REM ---- ck_name: name J used as a value (LANGUAGE 7.2): local, constant or pi inf nan eps; the
7380 REM callee of a call and an assignment or ref target are left to their parent -------------
7385 SUB "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7390 LET Q = N(J, 6)
7395 LET P = N(J, 9)
7400 CALL "lk": Y(), W(), X(), X$(), S$(), Q, R
7405 LET M(J, 2) = R
7410 LET Z = 0
7415 IF N(P, 0) <> 35 THEN 7435
7420 IF N(P, 7) <> J THEN 7435
7425 IF R <> 0 THEN 7560
7430 GOTO 7555
7435 IF N(P, 0) <> 13 THEN 7445
7440 IF N(P, 7) = J THEN 7460
7445 IF N(P, 0) <> 14 THEN 7455
7450 IF N(J, 8) <> 0 THEN 7460
7455 IF N(P, 0) <> 37 THEN 7465
7460 LET Z = 1
7465 IF R = 0 THEN 7555
7470 IF R < 0 THEN 7535
7475 IF Y(R, 0) = 4 THEN 7495
7480 IF Y(R, 0) = 2 THEN 7505
7485 IF Z = 1 THEN 7560
7490 GOTO 7555
7495 LET M(J, 1) = Y(R, 2)
7500 GOTO 7560
7505 IF Y(R, 4) = 2 THEN 7525
7510 REM constants are checked after those they name (ck_cord): this one is on a cycle
7515 CALL "er": N(), X(), X$(), J, "NOT_CONSTANT", "", "", "", 0
7520 GOTO 7560
7525 LET M(J, 1) = Y(R, 2)
7530 GOTO 7560
7535 IF R < -4 THEN 7550
7540 LET M(J, 1) = 4
7545 GOTO 7560
7550 IF Z = 1 THEN 7560
7555 CALL "er": N(), X(), X$(), J, "UNDECLARED", S$(Q), "", "", 1
7560 SUBEND
7565 REM ---- ck_un: unary - and ! (LANGUAGE 6.4, 6.5); -2^63 is one constant (DESIGN 3.5.5) ------
7570 SUB "ck_un": N(), M(), T(), C(), X(), X$(), J
7575 LET A = N(J, 7)
7580 CALL "vu": N(), M(), T(), X(), X$(), A, D
7585 IF D = 0 THEN 7695
7590 IF N(J, 0) = 33 THEN 7665
7595 IF D = -1 THEN 7625
7600 IF D = 3 THEN 7655
7605 IF D = 4 THEN 7655
7610 CALL "tyn": T(), D, A$
7615 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "-", A$, "", 2
7620 GOTO 7695
7625 IF N(A, 0) <> 25 THEN 7655
7630 LET R0 = M(A, 5)
7635 IF C(R0, 1) <> 32768 THEN 7655
7640 IF C(R0, 2) + C(R0, 3) + C(R0, 4) <> 0 THEN 7655
7645 REM the operand 2^63: the neg is written as the constant -2^63, its operand is not written
7650 LET M(A, 8) = -A
7655 LET M(J, 1) = D
7660 GOTO 7695
7665 IF D = 2 THEN 7655
7670 IF D <> -1 THEN 7685
7675 CALL "stl": N(), M(), C(), X(), X$(), A, 3
7680 LET D = 3
7685 CALL "tyn": T(), D, A$
7690 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "!", A$, "", 2
7695 SUBEND
7700 REM ---- num2: operands A, B (types G1, G2) of a numeric operator: untyped constants take the
7705 REM other operand's type (i64 when both are untyped), the i64 side of a mixed pair is converted;
7710 REM Z = 1 when an operand is not numeric; R the common type (LANGUAGE 4.2) -----------------
7715 SUB "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7720 LET Z = 0
7725 LET R = 0
7730 LET U = G1
7735 LET V = G2
7740 IF U <> -1 THEN 7770
7745 LET D = 3
7750 IF V <> 4 THEN 7760
7755 LET D = 4
7760 CALL "stl": N(), M(), C(), X(), X$(), A, D
7765 LET U = D
7770 IF V <> -1 THEN 7800
7775 LET D = 3
7780 IF U <> 4 THEN 7790
7785 LET D = 4
7790 CALL "stl": N(), M(), C(), X(), X$(), B, D
7795 LET V = D
7800 IF U < 3 THEN 7860
7805 IF U > 4 THEN 7860
7810 IF V < 3 THEN 7860
7815 IF V > 4 THEN 7860
7820 LET R = U
7825 IF U = V THEN 7865
7830 LET R = 4
7835 IF U = 4 THEN 7850
7840 LET M(A, 7) = 1
7845 GOTO 7865
7850 LET M(B, 7) = 1
7855 GOTO 7865
7860 LET Z = 1
7865 SUBEND
7870 REM ---- ck_bin: binary operator J (LANGUAGE 6.1-6.6, Appendix B; phase 1: scalars) ----------
7875 SUB "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7880 LET A = N(J, 7)
7885 LET B = N(A, 8)
7890 LET O = N(J, 1)
7895 CALL "vu": N(), M(), T(), X(), X$(), A, G1
7900 CALL "vu": N(), M(), T(), X(), X$(), B, G2
7905 IF G1 = 0 THEN 8265
7910 IF G2 = 0 THEN 8265
7915 REM + and comparisons on str are phase 2 (DESIGN 2.6.2)
7920 IF G1 = 5 THEN 8220
7925 IF G2 = 5 THEN 8220
7930 ON O GOTO 7935, 7935, 7935, 7975, 8030, 8060, 8230, 8160, 8160, 8180, 8180, 8180, 8180, 8200, 8200, 8200, 8200
7935 IF G1 <> -1 THEN 7955
7940 IF G2 <> -1 THEN 7955
7945 LET M(J, 1) = -1
7950 GOTO 8265
7955 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7960 IF Z = 1 THEN 8230
7965 LET M(J, 1) = R
7970 GOTO 8265
7975 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7980 IF Z = 1 THEN 8230
7985 REM / divides f64 values: both i64 operands are converted (LANGUAGE 6.5)
7990 LET M(A, 7) = 0
7995 LET M(B, 7) = 0
8000 IF M(A, 1) <> 3 THEN 8010
8005 LET M(A, 7) = 1
8010 IF M(B, 1) <> 3 THEN 8020
8015 LET M(B, 7) = 1
8020 LET M(J, 1) = 4
8025 GOTO 8265
8030 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
8035 IF Z = 1 THEN 8230
8040 LET M(J, 1) = R
8045 IF R = 3 THEN 8265
8050 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "f64 %", "", "", 1
8055 GOTO 8265
8060 IF G1 = 2 THEN 8230
8065 IF G1 > 4 THEN 8230
8070 IF G2 = 2 THEN 8230
8075 IF G2 > 4 THEN 8230
8080 REM ^ is f64: an i64 or untyped operand is converted (LANGUAGE 4.2 (d), 6.5)
8085 IF G1 <> -1 THEN 8095
8090 CALL "stl": N(), M(), C(), X(), X$(), A, 4
8095 IF G1 <> 3 THEN 8105
8100 LET M(A, 7) = 1
8105 IF G2 <> -1 THEN 8115
8110 CALL "stl": N(), M(), C(), X(), X$(), B, 4
8115 IF G2 <> 3 THEN 8125
8120 LET M(B, 7) = 1
8125 LET M(J, 1) = 4
8130 CALL "powk": N(), M(), Y(), C(), W(), X(), X$(), B, K0, Z
8135 REM not a powk (Z 0, or 2 for a failed constant): bin pow, the run-time pow (DESIGN 4.10.5)
8140 IF Z <> 1 THEN 8265
8145 LET M(J, 8) = K0 + 10
8150 LET M(M(B, 0), 8) = -B
8155 GOTO 8265
8160 IF G1 <> 2 THEN 8180
8165 IF G2 <> 2 THEN 8180
8170 LET M(J, 1) = 2
8175 GOTO 8265
8180 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
8185 IF Z = 1 THEN 8230
8190 LET M(J, 1) = 2
8195 GOTO 8265
8200 IF G1 <> 2 THEN 8230
8205 IF G2 <> 2 THEN 8230
8210 LET M(J, 1) = 2
8215 GOTO 8265
8220 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
8225 GOTO 8265
8230 CALL "fin": N(), M(), C(), X(), X$(), A
8235 CALL "fin": N(), M(), C(), X(), X$(), B
8240 CALL "opn": O, A$
8245 CALL "tyn": T(), M(A, 1), B$
8250 CALL "tyn": T(), M(B, 1), C$
8255 CALL "er": N(), X(), X$(), J, "BAD_OPERANDS", A$, B$, C$, 3
8260 LET M(J, 1) = 0
8265 SUBEND
8270 REM ---- ck_ifx: if expression J (LANGUAGE 6.10, 4.2 (f)) --------------------------------------
8275 SUB "ck_ifx": N(), M(), T(), C(), X(), X$(), J
8280 LET E = N(J, 7)
8285 LET A = N(E, 8)
8290 LET B = N(A, 8)
8295 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
8300 CALL "vu": N(), M(), T(), X(), X$(), A, G1
8305 CALL "vu": N(), M(), T(), X(), X$(), B, G2
8310 IF G1 = 0 THEN 8410
8315 IF G2 = 0 THEN 8410
8320 IF G1 <> -1 THEN 8350
8325 LET D = 3
8330 IF G2 <> 4 THEN 8340
8335 LET D = 4
8340 CALL "stl": N(), M(), C(), X(), X$(), A, D
8345 LET G1 = D
8350 IF G2 <> -1 THEN 8380
8355 LET D = 3
8360 IF G1 <> 4 THEN 8370
8365 LET D = 4
8370 CALL "stl": N(), M(), C(), X(), X$(), B, D
8375 LET G2 = D
8380 IF G1 = G2 THEN 8405
8385 CALL "tyn": T(), G1, A$
8390 CALL "tyn": T(), G2, B$
8395 CALL "er": N(), X(), X$(), B, "TYPE_MISMATCH", A$, B$, "", 2
8400 GOTO 8410
8405 LET M(J, 1) = G1
8410 SUBEND
8415 REM ---- ck_conv: f64(x), i64(x) of bool, i64, f64 (LANGUAGE 10.1; lib nodes, DESIGN 3.5.5) -----
8420 SUB "ck_conv": N(), M(), T(), C(), X(), X$(), J
8425 LET A = N(J, 7)
8430 LET O = N(J, 1)
8435 IF O < 3 THEN 8450
8440 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
8445 GOTO 8515
8450 CALL "vu": N(), M(), T(), X(), X$(), A, D
8455 IF D = 0 THEN 8515
8460 IF D <> -1 THEN 8480
8465 REM an untyped argument is i64 (both conversions accept i64, LANGUAGE 4.2)
8470 CALL "stl": N(), M(), C(), X(), X$(), A, 3
8475 LET D = 3
8480 REM bool, i64 and f64 (the identity too: f64(2.5), i64(7) in tests/programs/op_cvt)
8485 IF D < 2 THEN 8495
8490 IF D <= 4 THEN 8510
8495 CALL "tyn": T(), D, B$
8500 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", SEG$("f64i64", 3 * O - 2, 3 * O), B$, "", 2
8505 GOTO 8515
8510 LET M(J, 1) = 5 - O
8515 SUBEND
8520 REM ---- ck_rng: a range J; in phase 1 only as the iterable of a for: i64 bounds and step --------
8525 SUB "ck_rng": N(), M(), T(), C(), X(), X$(), J
8530 IF N(N(J, 9), 0) <> 18 THEN 8605
8535 LET A = N(J, 7)
8540 IF A = 0 THEN 8595
8545 CALL "vu": N(), M(), T(), X(), X$(), A, D
8550 IF D <> -1 THEN 8565
8555 CALL "stl": N(), M(), C(), X(), X$(), A, 3
8560 LET D = 3
8565 IF D = 3 THEN 8585
8570 IF D = 0 THEN 8585
8575 CALL "tyn": T(), D, B$
8580 CALL "er": N(), X(), X$(), A, "TYPE_MISMATCH", "i64", B$, "", 2
8585 LET A = N(A, 8)
8590 GOTO 8540
8595 CALL "tvec": T(), N(), X(), X$(), 3, R
8600 LET M(J, 1) = R
8605 SUBEND
