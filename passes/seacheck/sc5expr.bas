7045 REM ---- ck_expr: the expression subtree E, bottom-up: nodes M(E,0)..E are its post-order, so
7050 REM every child is typed before its parent (no recursion over expressions). M(J,3) = the
7055 REM number of errors before node J (for the printf rule of DESIGN 2.6.2).
7060 SUB "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
7065 FOR J = M(E, 0) TO E
7070 LET M(J, 3) = X(9)
7075 LET M(J, 1) = 0
7080 LET M(J, 7) = 0
7085 LET M(J, 8) = 0
7090 LET K = N(J, 0)
7095 IF K < 25 THEN 7315
7100 ON K - 24 GOTO 7105, 7115, 7125, 7190, 7190, 7200, 7315, 7210, 7210, 7220, 7230, 7240, 7250, 7260, 7270, 7315, 7300, 7270, 7280, 7270, 7315, 7280, 7290, 7315, 7310
7105 LET M(J, 1) = -1
7110 GOTO 7315
7115 LET M(J, 1) = 4
7120 GOTO 7315
7125 REM a string literal is only allowed as an argument of printf (phase 1, DESIGN 2.6.2)
7130 LET P = N(J, 9)
7135 IF N(P, 0) <> 35 THEN 7170
7140 LET G = N(P, 7)
7145 IF N(G, 0) <> 30 THEN 7170
7150 IF S$(N(G, 6)) <> "printf" THEN 7170
7155 IF LEN(S$(N(G, 6))) <> 6 THEN 7170
7160 LET M(J, 1) = 5
7165 GOTO 7315
7170 REM reported here; the str type stays, so a str local is reported at its name too
7175 LET M(J, 1) = 5
7180 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
7185 GOTO 7315
7190 LET M(J, 1) = 2
7195 GOTO 7315
7200 CALL "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7205 GOTO 7315
7210 CALL "ck_un": N(), M(), T(), C(), X(), X$(), J
7215 GOTO 7315
7220 CALL "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7225 GOTO 7315
7230 CALL "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7235 GOTO 7315
7240 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "named arguments", "", "", 1
7245 GOTO 7315
7250 LET M(J, 1) = M(N(J, 7), 1)
7255 GOTO 7315
7260 CALL "ck_conv": N(), M(), T(), C(), X(), X$(), J
7265 GOTO 7315
7270 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "arrays", "", "", 1
7275 GOTO 7315
7280 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "structs", "", "", 1
7285 GOTO 7315
7290 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "records", "", "", 1
7295 GOTO 7315
7300 CALL "ck_rng": N(), M(), T(), C(), X(), X$(), J
7305 GOTO 7315
7310 CALL "ck_ifx": N(), M(), T(), C(), X(), X$(), J
7315 NEXT J
7320 SUBEND
7325 REM ---- ck_name: name J used as a value (LANGUAGE 7.2): local, constant or pi inf nan eps; the
7330 REM callee of a call and an assignment or ref target are left to their parent -------------
7335 SUB "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7340 LET Q = N(J, 6)
7345 LET P = N(J, 9)
7350 CALL "lk": Y(), W(), X(), X$(), S$(), Q, R
7355 LET M(J, 2) = R
7360 LET Z = 0
7365 IF N(P, 0) <> 35 THEN 7385
7370 IF N(P, 7) <> J THEN 7385
7375 IF R <> 0 THEN 7510
7380 GOTO 7505
7385 IF N(P, 0) <> 13 THEN 7395
7390 IF N(P, 7) = J THEN 7410
7395 IF N(P, 0) <> 14 THEN 7405
7400 IF N(J, 8) <> 0 THEN 7410
7405 IF N(P, 0) <> 37 THEN 7415
7410 LET Z = 1
7415 IF R = 0 THEN 7505
7420 IF R < 0 THEN 7485
7425 IF Y(R, 0) = 4 THEN 7445
7430 IF Y(R, 0) = 2 THEN 7455
7435 IF Z = 1 THEN 7510
7440 GOTO 7505
7445 LET M(J, 1) = Y(R, 2)
7450 GOTO 7510
7455 IF Y(R, 4) = 2 THEN 7475
7460 REM constants are checked after those they name (ck_cord): this one is on a cycle
7465 CALL "er": N(), X(), X$(), J, "NOT_CONSTANT", "", "", "", 0
7470 GOTO 7510
7475 LET M(J, 1) = Y(R, 2)
7480 GOTO 7510
7485 IF R < -4 THEN 7500
7490 LET M(J, 1) = 4
7495 GOTO 7510
7500 IF Z = 1 THEN 7510
7505 CALL "er": N(), X(), X$(), J, "UNDECLARED", S$(Q), "", "", 1
7510 SUBEND
7515 REM ---- ck_un: unary - and ! (LANGUAGE 6.4, 6.5); -2^63 is one constant (DESIGN 3.5.5) ------
7520 SUB "ck_un": N(), M(), T(), C(), X(), X$(), J
7525 LET A = N(J, 7)
7530 CALL "vu": N(), M(), T(), X(), X$(), A, D
7535 IF D = 0 THEN 7645
7540 IF N(J, 0) = 33 THEN 7615
7545 IF D = -1 THEN 7575
7550 IF D = 3 THEN 7605
7555 IF D = 4 THEN 7605
7560 CALL "tyn": T(), D, A$
7565 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "-", A$, "", 2
7570 GOTO 7645
7575 IF N(A, 0) <> 25 THEN 7605
7580 LET R0 = M(A, 5)
7585 IF C(R0, 1) <> 32768 THEN 7605
7590 IF C(R0, 2) + C(R0, 3) + C(R0, 4) <> 0 THEN 7605
7595 REM the operand 2^63: the neg is written as the constant -2^63, its operand is not written
7600 LET M(A, 8) = -A
7605 LET M(J, 1) = D
7610 GOTO 7645
7615 IF D = 2 THEN 7605
7620 IF D <> -1 THEN 7635
7625 CALL "stl": N(), M(), C(), X(), X$(), A, 3
7630 LET D = 3
7635 CALL "tyn": T(), D, A$
7640 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "!", A$, "", 2
7645 SUBEND
7650 REM ---- num2: operands A, B (types G1, G2) of a numeric operator: untyped constants take the
7655 REM other operand's type (i64 when both are untyped), the i64 side of a mixed pair is converted;
7660 REM Z = 1 when an operand is not numeric; R the common type (LANGUAGE 4.2) -----------------
7665 SUB "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7670 LET Z = 0
7675 LET R = 0
7680 LET U = G1
7685 LET V = G2
7690 IF U <> -1 THEN 7720
7695 LET D = 3
7700 IF V <> 4 THEN 7710
7705 LET D = 4
7710 CALL "stl": N(), M(), C(), X(), X$(), A, D
7715 LET U = D
7720 IF V <> -1 THEN 7750
7725 LET D = 3
7730 IF U <> 4 THEN 7740
7735 LET D = 4
7740 CALL "stl": N(), M(), C(), X(), X$(), B, D
7745 LET V = D
7750 IF U < 3 THEN 7810
7755 IF U > 4 THEN 7810
7760 IF V < 3 THEN 7810
7765 IF V > 4 THEN 7810
7770 LET R = U
7775 IF U = V THEN 7815
7780 LET R = 4
7785 IF U = 4 THEN 7800
7790 LET M(A, 7) = 1
7795 GOTO 7815
7800 LET M(B, 7) = 1
7805 GOTO 7815
7810 LET Z = 1
7815 SUBEND
7820 REM ---- ck_bin: binary operator J (LANGUAGE 6.1-6.6, Appendix B; phase 1: scalars) ----------
7825 SUB "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7830 LET A = N(J, 7)
7835 LET B = N(A, 8)
7840 LET O = N(J, 1)
7845 CALL "vu": N(), M(), T(), X(), X$(), A, G1
7850 CALL "vu": N(), M(), T(), X(), X$(), B, G2
7855 IF G1 = 0 THEN 8225
7860 IF G2 = 0 THEN 8225
7865 REM + and comparisons on str are phase 2 (DESIGN 2.6.2)
7870 IF G1 = 5 THEN 8180
7875 IF G2 = 5 THEN 8180
7880 ON O GOTO 7885, 7885, 7885, 7925, 7980, 8010, 8190, 8120, 8120, 8140, 8140, 8140, 8140, 8160, 8160, 8160, 8160
7885 IF G1 <> -1 THEN 7905
7890 IF G2 <> -1 THEN 7905
7895 LET M(J, 1) = -1
7900 GOTO 8225
7905 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7910 IF Z = 1 THEN 8190
7915 LET M(J, 1) = R
7920 GOTO 8225
7925 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7930 IF Z = 1 THEN 8190
7935 REM / divides f64 values: both i64 operands are converted (LANGUAGE 6.5)
7940 LET M(A, 7) = 0
7945 LET M(B, 7) = 0
7950 IF M(A, 1) <> 3 THEN 7960
7955 LET M(A, 7) = 1
7960 IF M(B, 1) <> 3 THEN 7970
7965 LET M(B, 7) = 1
7970 LET M(J, 1) = 4
7975 GOTO 8225
7980 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7985 IF Z = 1 THEN 8190
7990 LET M(J, 1) = R
7995 IF R = 3 THEN 8225
8000 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "f64 %", "", "", 1
8005 GOTO 8225
8010 IF G1 = 2 THEN 8190
8015 IF G1 > 4 THEN 8190
8020 IF G2 = 2 THEN 8190
8025 IF G2 > 4 THEN 8190
8030 REM ^ is f64: an i64 or untyped operand is converted (LANGUAGE 4.2 (d), 6.5)
8035 IF G1 <> -1 THEN 8045
8040 CALL "stl": N(), M(), C(), X(), X$(), A, 4
8045 IF G1 <> 3 THEN 8055
8050 LET M(A, 7) = 1
8055 IF G2 <> -1 THEN 8065
8060 CALL "stl": N(), M(), C(), X(), X$(), B, 4
8065 IF G2 <> 3 THEN 8075
8070 LET M(B, 7) = 1
8075 LET M(J, 1) = 4
8080 CALL "powk": N(), M(), Y(), C(), W(), X(), X$(), B, K0, Z
8085 IF Z = 0 THEN 8110
8090 IF Z = 2 THEN 8225
8095 LET M(J, 8) = K0 + 10
8100 LET M(M(B, 0), 8) = -B
8105 GOTO 8225
8110 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "pow", "", "", 1
8115 GOTO 8225
8120 IF G1 <> 2 THEN 8140
8125 IF G2 <> 2 THEN 8140
8130 LET M(J, 1) = 2
8135 GOTO 8225
8140 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
8145 IF Z = 1 THEN 8190
8150 LET M(J, 1) = 2
8155 GOTO 8225
8160 IF G1 <> 2 THEN 8190
8165 IF G2 <> 2 THEN 8190
8170 LET M(J, 1) = 2
8175 GOTO 8225
8180 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
8185 GOTO 8225
8190 CALL "fin": N(), M(), C(), X(), X$(), A
8195 CALL "fin": N(), M(), C(), X(), X$(), B
8200 CALL "opn": O, A$
8205 CALL "tyn": T(), M(A, 1), B$
8210 CALL "tyn": T(), M(B, 1), C$
8215 CALL "er": N(), X(), X$(), J, "BAD_OPERANDS", A$, B$, C$, 3
8220 LET M(J, 1) = 0
8225 SUBEND
8230 REM ---- ck_ifx: if expression J (LANGUAGE 6.10, 4.2 (f)) --------------------------------------
8235 SUB "ck_ifx": N(), M(), T(), C(), X(), X$(), J
8240 LET E = N(J, 7)
8245 LET A = N(E, 8)
8250 LET B = N(A, 8)
8255 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
8260 CALL "vu": N(), M(), T(), X(), X$(), A, G1
8265 CALL "vu": N(), M(), T(), X(), X$(), B, G2
8270 IF G1 = 0 THEN 8370
8275 IF G2 = 0 THEN 8370
8280 IF G1 <> -1 THEN 8310
8285 LET D = 3
8290 IF G2 <> 4 THEN 8300
8295 LET D = 4
8300 CALL "stl": N(), M(), C(), X(), X$(), A, D
8305 LET G1 = D
8310 IF G2 <> -1 THEN 8340
8315 LET D = 3
8320 IF G1 <> 4 THEN 8330
8325 LET D = 4
8330 CALL "stl": N(), M(), C(), X(), X$(), B, D
8335 LET G2 = D
8340 IF G1 = G2 THEN 8365
8345 CALL "tyn": T(), G1, A$
8350 CALL "tyn": T(), G2, B$
8355 CALL "er": N(), X(), X$(), B, "TYPE_MISMATCH", A$, B$, "", 2
8360 GOTO 8370
8365 LET M(J, 1) = G1
8370 SUBEND
8375 REM ---- ck_conv: f64(x), i64(x) of bool, i64, f64 (LANGUAGE 10.1; lib nodes, DESIGN 3.5.5) -----
8380 SUB "ck_conv": N(), M(), T(), C(), X(), X$(), J
8385 LET A = N(J, 7)
8390 LET O = N(J, 1)
8395 IF O < 3 THEN 8410
8400 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
8405 GOTO 8475
8410 CALL "vu": N(), M(), T(), X(), X$(), A, D
8415 IF D = 0 THEN 8475
8420 IF D <> -1 THEN 8440
8425 REM an untyped argument is i64 (both conversions accept i64, LANGUAGE 4.2)
8430 CALL "stl": N(), M(), C(), X(), X$(), A, 3
8435 LET D = 3
8440 REM bool, i64 and f64 (the identity too: f64(2.5), i64(7) in tests/programs/op_cvt)
8445 IF D < 2 THEN 8455
8450 IF D <= 4 THEN 8470
8455 CALL "tyn": T(), D, B$
8460 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", SEG$("f64i64", 3 * O - 2, 3 * O), B$, "", 2
8465 GOTO 8475
8470 LET M(J, 1) = 5 - O
8475 SUBEND
8480 REM ---- ck_rng: a range J; in phase 1 only as the iterable of a for: i64 bounds and step --------
8485 SUB "ck_rng": N(), M(), T(), C(), X(), X$(), J
8490 IF N(N(J, 9), 0) <> 18 THEN 8565
8495 LET A = N(J, 7)
8500 IF A = 0 THEN 8555
8505 CALL "vu": N(), M(), T(), X(), X$(), A, D
8510 IF D <> -1 THEN 8525
8515 CALL "stl": N(), M(), C(), X(), X$(), A, 3
8520 LET D = 3
8525 IF D = 3 THEN 8545
8530 IF D = 0 THEN 8545
8535 CALL "tyn": T(), D, B$
8540 CALL "er": N(), X(), X$(), A, "TYPE_MISMATCH", "i64", B$, "", 2
8545 LET A = N(A, 8)
8550 GOTO 8500
8555 CALL "tvec": T(), N(), X(), X$(), 3, R
8560 LET M(J, 1) = R
8565 SUBEND
