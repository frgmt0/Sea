6860 REM ---- ck_expr: the expression subtree E, bottom-up: nodes M(E,0)..E are its post-order, so
6865 REM every child is typed before its parent (no recursion over expressions). M(J,3) = the
6870 REM number of errors before node J (for the printf rule of DESIGN 2.6.2).
6875 SUB "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6880 FOR J = M(E, 0) TO E
6885 LET M(J, 3) = X(9)
6890 LET M(J, 1) = 0
6895 LET M(J, 7) = 0
6900 LET M(J, 8) = 0
6905 LET K = N(J, 0)
6910 IF K < 25 THEN 7130
6915 ON K - 24 GOTO 6920, 6930, 6940, 7005, 7005, 7015, 7130, 7025, 7025, 7035, 7045, 7055, 7065, 7075, 7085, 7130, 7115, 7085, 7095, 7085, 7130, 7095, 7105, 7130, 7125
6920 LET M(J, 1) = -1
6925 GOTO 7130
6930 LET M(J, 1) = 4
6935 GOTO 7130
6940 REM a string literal is only allowed as an argument of printf (phase 1, DESIGN 2.6.2)
6945 LET P = N(J, 9)
6950 IF N(P, 0) <> 35 THEN 6985
6955 LET G = N(P, 7)
6960 IF N(G, 0) <> 30 THEN 6985
6965 IF S$(N(G, 6)) <> "printf" THEN 6985
6970 IF LEN(S$(N(G, 6))) <> 6 THEN 6985
6975 LET M(J, 1) = 5
6980 GOTO 7130
6985 REM reported here; the str type stays, so a str local is reported at its name too
6990 LET M(J, 1) = 5
6995 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
7000 GOTO 7130
7005 LET M(J, 1) = 2
7010 GOTO 7130
7015 CALL "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7020 GOTO 7130
7025 CALL "ck_un": N(), M(), T(), C(), X(), X$(), J
7030 GOTO 7130
7035 CALL "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7040 GOTO 7130
7045 CALL "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7050 GOTO 7130
7055 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "named arguments", "", "", 1
7060 GOTO 7130
7065 LET M(J, 1) = M(N(J, 7), 1)
7070 GOTO 7130
7075 CALL "ck_conv": N(), M(), T(), C(), X(), X$(), J
7080 GOTO 7130
7085 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "arrays", "", "", 1
7090 GOTO 7130
7095 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "structs", "", "", 1
7100 GOTO 7130
7105 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "records", "", "", 1
7110 GOTO 7130
7115 CALL "ck_rng": N(), M(), T(), C(), X(), X$(), J
7120 GOTO 7130
7125 CALL "ck_ifx": N(), M(), T(), C(), X(), X$(), J
7130 NEXT J
7135 SUBEND
7140 REM ---- ck_name: name J used as a value (LANGUAGE 7.2): local, constant or pi inf nan eps; the
7145 REM callee of a call and an assignment or ref target are left to their parent -------------
7150 SUB "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7155 LET Q = N(J, 6)
7160 LET P = N(J, 9)
7165 CALL "lk": Y(), W(), X(), X$(), S$(), Q, R
7170 LET M(J, 2) = R
7175 LET Z = 0
7180 IF N(P, 0) <> 35 THEN 7200
7185 IF N(P, 7) <> J THEN 7200
7190 IF R <> 0 THEN 7325
7195 GOTO 7320
7200 IF N(P, 0) <> 13 THEN 7210
7205 IF N(P, 7) = J THEN 7225
7210 IF N(P, 0) <> 14 THEN 7220
7215 IF N(J, 8) <> 0 THEN 7225
7220 IF N(P, 0) <> 37 THEN 7230
7225 LET Z = 1
7230 IF R = 0 THEN 7320
7235 IF R < 0 THEN 7300
7240 IF Y(R, 0) = 4 THEN 7260
7245 IF Y(R, 0) = 2 THEN 7270
7250 IF Z = 1 THEN 7325
7255 GOTO 7320
7260 LET M(J, 1) = Y(R, 2)
7265 GOTO 7325
7270 IF Y(R, 4) = 2 THEN 7290
7275 REM constants are checked after those they name (ck_cord): this one is on a cycle
7280 CALL "er": N(), X(), X$(), J, "NOT_CONSTANT", "", "", "", 0
7285 GOTO 7325
7290 LET M(J, 1) = Y(R, 2)
7295 GOTO 7325
7300 IF R < -4 THEN 7315
7305 LET M(J, 1) = 4
7310 GOTO 7325
7315 IF Z = 1 THEN 7325
7320 CALL "er": N(), X(), X$(), J, "UNDECLARED", S$(Q), "", "", 1
7325 SUBEND
7330 REM ---- ck_un: unary - and ! (LANGUAGE 6.4, 6.5); -2^63 is one constant (DESIGN 3.5.5) ------
7335 SUB "ck_un": N(), M(), T(), C(), X(), X$(), J
7340 LET A = N(J, 7)
7345 CALL "vu": N(), M(), T(), X(), X$(), A, D
7350 IF D = 0 THEN 7460
7355 IF N(J, 0) = 33 THEN 7430
7360 IF D = -1 THEN 7390
7365 IF D = 3 THEN 7420
7370 IF D = 4 THEN 7420
7375 CALL "tyn": T(), D, A$
7380 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "-", A$, "", 2
7385 GOTO 7460
7390 IF N(A, 0) <> 25 THEN 7420
7395 LET R0 = M(A, 5)
7400 IF C(R0, 1) <> 32768 THEN 7420
7405 IF C(R0, 2) + C(R0, 3) + C(R0, 4) <> 0 THEN 7420
7410 REM the operand 2^63: the neg is written as the constant -2^63, its operand is not written
7415 LET M(A, 8) = -A
7420 LET M(J, 1) = D
7425 GOTO 7460
7430 IF D = 2 THEN 7420
7435 IF D <> -1 THEN 7450
7440 CALL "stl": N(), M(), C(), X(), X$(), A, 3
7445 LET D = 3
7450 CALL "tyn": T(), D, A$
7455 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "!", A$, "", 2
7460 SUBEND
7465 REM ---- num2: operands A, B (types G1, G2) of a numeric operator: untyped constants take the
7470 REM other operand's type (i64 when both are untyped), the i64 side of a mixed pair is converted;
7475 REM Z = 1 when an operand is not numeric; R the common type (LANGUAGE 4.2) -----------------
7480 SUB "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7485 LET Z = 0
7490 LET R = 0
7495 LET U = G1
7500 LET V = G2
7505 IF U <> -1 THEN 7535
7510 LET D = 3
7515 IF V <> 4 THEN 7525
7520 LET D = 4
7525 CALL "stl": N(), M(), C(), X(), X$(), A, D
7530 LET U = D
7535 IF V <> -1 THEN 7565
7540 LET D = 3
7545 IF U <> 4 THEN 7555
7550 LET D = 4
7555 CALL "stl": N(), M(), C(), X(), X$(), B, D
7560 LET V = D
7565 IF U < 3 THEN 7625
7570 IF U > 4 THEN 7625
7575 IF V < 3 THEN 7625
7580 IF V > 4 THEN 7625
7585 LET R = U
7590 IF U = V THEN 7630
7595 LET R = 4
7600 IF U = 4 THEN 7615
7605 LET M(A, 7) = 1
7610 GOTO 7630
7615 LET M(B, 7) = 1
7620 GOTO 7630
7625 LET Z = 1
7630 SUBEND
7635 REM ---- ck_bin: binary operator J (LANGUAGE 6.1-6.6, Appendix B; phase 1: scalars) ----------
7640 SUB "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7645 LET A = N(J, 7)
7650 LET B = N(A, 8)
7655 LET O = N(J, 1)
7660 CALL "vu": N(), M(), T(), X(), X$(), A, G1
7665 CALL "vu": N(), M(), T(), X(), X$(), B, G2
7670 IF G1 = 0 THEN 8035
7675 IF G2 = 0 THEN 8035
7680 REM + and comparisons on str are phase 2 (DESIGN 2.6.2)
7685 IF G1 = 5 THEN 7990
7690 IF G2 = 5 THEN 7990
7695 ON O GOTO 7700, 7700, 7700, 7740, 7795, 7825, 8000, 7930, 7930, 7950, 7950, 7950, 7950, 7970, 7970, 7970, 7970
7700 IF G1 <> -1 THEN 7720
7705 IF G2 <> -1 THEN 7720
7710 LET M(J, 1) = -1
7715 GOTO 8035
7720 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7725 IF Z = 1 THEN 8000
7730 LET M(J, 1) = R
7735 GOTO 8035
7740 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7745 IF Z = 1 THEN 8000
7750 REM / divides f64 values: both i64 operands are converted (LANGUAGE 6.5)
7755 LET M(A, 7) = 0
7760 LET M(B, 7) = 0
7765 IF M(A, 1) <> 3 THEN 7775
7770 LET M(A, 7) = 1
7775 IF M(B, 1) <> 3 THEN 7785
7780 LET M(B, 7) = 1
7785 LET M(J, 1) = 4
7790 GOTO 8035
7795 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7800 IF Z = 1 THEN 8000
7805 LET M(J, 1) = R
7810 IF R = 3 THEN 8035
7815 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "f64 %", "", "", 1
7820 GOTO 8035
7825 IF G1 = 2 THEN 8000
7830 IF G1 > 4 THEN 8000
7835 IF G2 = 2 THEN 8000
7840 IF G2 > 4 THEN 8000
7845 REM ^ is f64: an i64 or untyped operand is converted (LANGUAGE 4.2 (d), 6.5)
7850 IF G1 <> -1 THEN 7860
7855 CALL "stl": N(), M(), C(), X(), X$(), A, 4
7860 IF G1 <> 3 THEN 7870
7865 LET M(A, 7) = 1
7870 IF G2 <> -1 THEN 7880
7875 CALL "stl": N(), M(), C(), X(), X$(), B, 4
7880 IF G2 <> 3 THEN 7890
7885 LET M(B, 7) = 1
7890 LET M(J, 1) = 4
7895 CALL "powk": N(), M(), Y(), C(), W(), X(), X$(), B, K0, Z
7900 IF Z = 0 THEN 7920
7905 LET M(J, 8) = K0 + 10
7910 LET M(M(B, 0), 8) = -B
7915 GOTO 8035
7920 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "pow", "", "", 1
7925 GOTO 8035
7930 IF G1 <> 2 THEN 7950
7935 IF G2 <> 2 THEN 7950
7940 LET M(J, 1) = 2
7945 GOTO 8035
7950 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7955 IF Z = 1 THEN 8000
7960 LET M(J, 1) = 2
7965 GOTO 8035
7970 IF G1 <> 2 THEN 8000
7975 IF G2 <> 2 THEN 8000
7980 LET M(J, 1) = 2
7985 GOTO 8035
7990 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
7995 GOTO 8035
8000 CALL "fin": N(), M(), C(), X(), X$(), A
8005 CALL "fin": N(), M(), C(), X(), X$(), B
8010 CALL "opn": O, A$
8015 CALL "tyn": T(), M(A, 1), B$
8020 CALL "tyn": T(), M(B, 1), C$
8025 CALL "er": N(), X(), X$(), J, "BAD_OPERANDS", A$, B$, C$, 3
8030 LET M(J, 1) = 0
8035 SUBEND
8040 REM ---- ck_ifx: if expression J (LANGUAGE 6.10, 4.2 (f)) --------------------------------------
8045 SUB "ck_ifx": N(), M(), T(), C(), X(), X$(), J
8050 LET E = N(J, 7)
8055 LET A = N(E, 8)
8060 LET B = N(A, 8)
8065 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
8070 CALL "vu": N(), M(), T(), X(), X$(), A, G1
8075 CALL "vu": N(), M(), T(), X(), X$(), B, G2
8080 IF G1 = 0 THEN 8180
8085 IF G2 = 0 THEN 8180
8090 IF G1 <> -1 THEN 8120
8095 LET D = 3
8100 IF G2 <> 4 THEN 8110
8105 LET D = 4
8110 CALL "stl": N(), M(), C(), X(), X$(), A, D
8115 LET G1 = D
8120 IF G2 <> -1 THEN 8150
8125 LET D = 3
8130 IF G1 <> 4 THEN 8140
8135 LET D = 4
8140 CALL "stl": N(), M(), C(), X(), X$(), B, D
8145 LET G2 = D
8150 IF G1 = G2 THEN 8175
8155 CALL "tyn": T(), G1, A$
8160 CALL "tyn": T(), G2, B$
8165 CALL "er": N(), X(), X$(), B, "TYPE_MISMATCH", A$, B$, "", 2
8170 GOTO 8180
8175 LET M(J, 1) = G1
8180 SUBEND
8185 REM ---- ck_conv: f64(x), i64(x) of bool, i64, f64 (LANGUAGE 10.1; lib nodes, DESIGN 3.5.5) -----
8190 SUB "ck_conv": N(), M(), T(), C(), X(), X$(), J
8195 LET A = N(J, 7)
8200 LET O = N(J, 1)
8205 IF O < 3 THEN 8220
8210 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
8215 GOTO 8285
8220 CALL "vu": N(), M(), T(), X(), X$(), A, D
8225 IF D = 0 THEN 8285
8230 IF D <> -1 THEN 8250
8235 REM an untyped argument is i64 (both conversions accept i64, LANGUAGE 4.2)
8240 CALL "stl": N(), M(), C(), X(), X$(), A, 3
8245 LET D = 3
8250 REM bool, i64 and f64 (the identity too: f64(2.5), i64(7) in tests/programs/op_cvt)
8255 IF D < 2 THEN 8265
8260 IF D <= 4 THEN 8280
8265 CALL "tyn": T(), D, B$
8270 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", SEG$("f64i64", 3 * O - 2, 3 * O), B$, "", 2
8275 GOTO 8285
8280 LET M(J, 1) = 5 - O
8285 SUBEND
8290 REM ---- ck_rng: a range J; in phase 1 only as the iterable of a for: i64 bounds and step --------
8295 SUB "ck_rng": N(), M(), T(), C(), X(), X$(), J
8300 IF N(N(J, 9), 0) <> 18 THEN 8375
8305 LET A = N(J, 7)
8310 IF A = 0 THEN 8365
8315 CALL "vu": N(), M(), T(), X(), X$(), A, D
8320 IF D <> -1 THEN 8335
8325 CALL "stl": N(), M(), C(), X(), X$(), A, 3
8330 LET D = 3
8335 IF D = 3 THEN 8355
8340 IF D = 0 THEN 8355
8345 CALL "tyn": T(), D, B$
8350 CALL "er": N(), X(), X$(), A, "TYPE_MISMATCH", "i64", B$, "", 2
8355 LET A = N(A, 8)
8360 GOTO 8310
8365 CALL "tvec": T(), N(), X(), X$(), 3, R
8370 LET M(J, 1) = R
8375 SUBEND
