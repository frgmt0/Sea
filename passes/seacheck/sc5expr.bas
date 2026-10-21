6190 REM ---- ck_expr: the expression subtree E, bottom-up: nodes M(E,0)..E are its post-order, so
6195 REM every child is typed before its parent (no recursion over expressions). M(J,3) = the
6200 REM number of errors before node J (for the printf rule of DESIGN 2.6.2).
6205 SUB "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6210 FOR J = M(E, 0) TO E
6215 LET M(J, 3) = X(9)
6220 LET M(J, 1) = 0
6225 LET M(J, 7) = 0
6230 LET M(J, 8) = 0
6235 LET K = N(J, 0)
6240 IF K < 25 THEN 6460
6245 ON K - 24 GOTO 6250, 6260, 6270, 6335, 6335, 6345, 6460, 6355, 6355, 6365, 6375, 6385, 6395, 6405, 6415, 6460, 6445, 6415, 6425, 6415, 6460, 6425, 6435, 6460, 6455
6250 LET M(J, 1) = -1
6255 GOTO 6460
6260 LET M(J, 1) = 4
6265 GOTO 6460
6270 REM a string literal is only allowed as an argument of printf (phase 1, DESIGN 2.6.2)
6275 LET P = N(J, 9)
6280 IF N(P, 0) <> 35 THEN 6315
6285 LET G = N(P, 7)
6290 IF N(G, 0) <> 30 THEN 6315
6295 IF S$(N(G, 6)) <> "printf" THEN 6315
6300 IF LEN(S$(N(G, 6))) <> 6 THEN 6315
6305 LET M(J, 1) = 5
6310 GOTO 6460
6315 REM reported here; the str type stays, so a str local is reported at its name too
6320 LET M(J, 1) = 5
6325 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
6330 GOTO 6460
6335 LET M(J, 1) = 2
6340 GOTO 6460
6345 CALL "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
6350 GOTO 6460
6355 CALL "ck_un": N(), M(), T(), C(), X(), X$(), J
6360 GOTO 6460
6365 CALL "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
6370 GOTO 6460
6375 CALL "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
6380 GOTO 6460
6385 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "named arguments", "", "", 1
6390 GOTO 6460
6395 LET M(J, 1) = M(N(J, 7), 1)
6400 GOTO 6460
6405 CALL "ck_conv": N(), M(), T(), C(), X(), X$(), J
6410 GOTO 6460
6415 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "arrays", "", "", 1
6420 GOTO 6460
6425 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "structs", "", "", 1
6430 GOTO 6460
6435 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "records", "", "", 1
6440 GOTO 6460
6445 CALL "ck_rng": N(), M(), T(), C(), X(), X$(), J
6450 GOTO 6460
6455 CALL "ck_ifx": N(), M(), T(), C(), X(), X$(), J
6460 NEXT J
6465 SUBEND
6470 REM ---- ck_name: name J used as a value (LANGUAGE 7.2): local, constant or pi inf nan eps; the
6475 REM callee of a call and an assignment or ref target are left to their parent -------------
6480 SUB "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
6485 LET Q = N(J, 6)
6490 LET P = N(J, 9)
6495 CALL "lk": Y(), W(), X(), X$(), S$(), Q, R
6500 LET M(J, 2) = R
6505 LET Z = 0
6510 IF N(P, 0) <> 35 THEN 6530
6515 IF N(P, 7) <> J THEN 6530
6520 IF R <> 0 THEN 6675
6525 GOTO 6670
6530 IF N(P, 0) <> 13 THEN 6540
6535 IF N(P, 7) = J THEN 6555
6540 IF N(P, 0) <> 14 THEN 6550
6545 IF N(J, 8) <> 0 THEN 6555
6550 IF N(P, 0) <> 37 THEN 6560
6555 LET Z = 1
6560 IF R = 0 THEN 6670
6565 IF R < 0 THEN 6650
6570 IF Y(R, 0) = 4 THEN 6590
6575 IF Y(R, 0) = 2 THEN 6600
6580 IF Z = 1 THEN 6675
6585 GOTO 6670
6590 LET M(J, 1) = Y(R, 2)
6595 GOTO 6675
6600 IF Y(R, 4) = 2 THEN 6640
6605 IF Y(R, 4) = 0 THEN 6625
6610 REM the constant is being checked: its expression depends on itself
6615 CALL "er": N(), X(), X$(), J, "NOT_CONSTANT", "", "", "", 0
6620 GOTO 6675
6625 LET X9 = X(19)
6630 CALL "ck_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), R
6635 LET X(19) = X9
6640 LET M(J, 1) = Y(R, 2)
6645 GOTO 6675
6650 IF R < -4 THEN 6665
6655 LET M(J, 1) = 4
6660 GOTO 6675
6665 IF Z = 1 THEN 6675
6670 CALL "er": N(), X(), X$(), J, "UNDECLARED", S$(Q), "", "", 1
6675 SUBEND
6680 REM ---- ck_un: unary - and ! (LANGUAGE 6.4, 6.5); -2^63 is one constant (DESIGN 3.5.5) ------
6685 SUB "ck_un": N(), M(), T(), C(), X(), X$(), J
6690 LET A = N(J, 7)
6695 CALL "vu": N(), M(), T(), X(), X$(), A, D
6700 IF D = 0 THEN 6810
6705 IF N(J, 0) = 33 THEN 6780
6710 IF D = -1 THEN 6740
6715 IF D = 3 THEN 6770
6720 IF D = 4 THEN 6770
6725 CALL "tyn": T(), D, A$
6730 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "-", A$, "", 2
6735 GOTO 6810
6740 IF N(A, 0) <> 25 THEN 6770
6745 LET R0 = M(A, 5)
6750 IF C(R0, 1) <> 32768 THEN 6770
6755 IF C(R0, 2) + C(R0, 3) + C(R0, 4) <> 0 THEN 6770
6760 REM the operand 2^63: the neg is written as the constant -2^63, its operand is not written
6765 LET M(A, 8) = -A
6770 LET M(J, 1) = D
6775 GOTO 6810
6780 IF D = 2 THEN 6770
6785 IF D <> -1 THEN 6800
6790 CALL "stl": N(), M(), C(), X(), X$(), A, 3
6795 LET D = 3
6800 CALL "tyn": T(), D, A$
6805 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "!", A$, "", 2
6810 SUBEND
6815 REM ---- num2: operands A, B (types G1, G2) of a numeric operator: untyped constants take the
6820 REM other operand's type (i64 when both are untyped), the i64 side of a mixed pair is converted;
6825 REM Z = 1 when an operand is not numeric; R the common type (LANGUAGE 4.2) -----------------
6830 SUB "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
6835 LET Z = 0
6840 LET R = 0
6845 LET U = G1
6850 LET V = G2
6855 IF U <> -1 THEN 6885
6860 LET D = 3
6865 IF V <> 4 THEN 6875
6870 LET D = 4
6875 CALL "stl": N(), M(), C(), X(), X$(), A, D
6880 LET U = D
6885 IF V <> -1 THEN 6915
6890 LET D = 3
6895 IF U <> 4 THEN 6905
6900 LET D = 4
6905 CALL "stl": N(), M(), C(), X(), X$(), B, D
6910 LET V = D
6915 IF U < 3 THEN 6975
6920 IF U > 4 THEN 6975
6925 IF V < 3 THEN 6975
6930 IF V > 4 THEN 6975
6935 LET R = U
6940 IF U = V THEN 6980
6945 LET R = 4
6950 IF U = 4 THEN 6965
6955 LET M(A, 7) = 1
6960 GOTO 6980
6965 LET M(B, 7) = 1
6970 GOTO 6980
6975 LET Z = 1
6980 SUBEND
6985 REM ---- ck_bin: binary operator J (LANGUAGE 6.1-6.6, Appendix B; phase 1: scalars) ----------
6990 SUB "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
6995 LET A = N(J, 7)
7000 LET B = N(A, 8)
7005 LET O = N(J, 1)
7010 CALL "vu": N(), M(), T(), X(), X$(), A, G1
7015 CALL "vu": N(), M(), T(), X(), X$(), B, G2
7020 IF G1 = 0 THEN 7385
7025 IF G2 = 0 THEN 7385
7030 REM + and comparisons on str are phase 2 (DESIGN 2.6.2)
7035 IF G1 = 5 THEN 7340
7040 IF G2 = 5 THEN 7340
7045 ON O GOTO 7050, 7050, 7050, 7090, 7145, 7175, 7350, 7280, 7280, 7300, 7300, 7300, 7300, 7320, 7320, 7320, 7320
7050 IF G1 <> -1 THEN 7070
7055 IF G2 <> -1 THEN 7070
7060 LET M(J, 1) = -1
7065 GOTO 7385
7070 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7075 IF Z = 1 THEN 7350
7080 LET M(J, 1) = R
7085 GOTO 7385
7090 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7095 IF Z = 1 THEN 7350
7100 REM / divides f64 values: both i64 operands are converted (LANGUAGE 6.5)
7105 LET M(A, 7) = 0
7110 LET M(B, 7) = 0
7115 IF M(A, 1) <> 3 THEN 7125
7120 LET M(A, 7) = 1
7125 IF M(B, 1) <> 3 THEN 7135
7130 LET M(B, 7) = 1
7135 LET M(J, 1) = 4
7140 GOTO 7385
7145 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7150 IF Z = 1 THEN 7350
7155 LET M(J, 1) = R
7160 IF R = 3 THEN 7385
7165 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "f64 %", "", "", 1
7170 GOTO 7385
7175 IF G1 = 2 THEN 7350
7180 IF G1 > 4 THEN 7350
7185 IF G2 = 2 THEN 7350
7190 IF G2 > 4 THEN 7350
7195 REM ^ is f64: an i64 or untyped operand is converted (LANGUAGE 4.2 (d), 6.5)
7200 IF G1 <> -1 THEN 7210
7205 CALL "stl": N(), M(), C(), X(), X$(), A, 4
7210 IF G1 <> 3 THEN 7220
7215 LET M(A, 7) = 1
7220 IF G2 <> -1 THEN 7230
7225 CALL "stl": N(), M(), C(), X(), X$(), B, 4
7230 IF G2 <> 3 THEN 7240
7235 LET M(B, 7) = 1
7240 LET M(J, 1) = 4
7245 CALL "powk": N(), M(), Y(), C(), W(), X(), X$(), B, K0, Z
7250 IF Z = 0 THEN 7270
7255 LET M(J, 8) = K0 + 10
7260 LET M(M(B, 0), 8) = -B
7265 GOTO 7385
7270 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "pow", "", "", 1
7275 GOTO 7385
7280 IF G1 <> 2 THEN 7300
7285 IF G2 <> 2 THEN 7300
7290 LET M(J, 1) = 2
7295 GOTO 7385
7300 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
7305 IF Z = 1 THEN 7350
7310 LET M(J, 1) = 2
7315 GOTO 7385
7320 IF G1 <> 2 THEN 7350
7325 IF G2 <> 2 THEN 7350
7330 LET M(J, 1) = 2
7335 GOTO 7385
7340 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
7345 GOTO 7385
7350 CALL "fin": N(), M(), C(), X(), X$(), A
7355 CALL "fin": N(), M(), C(), X(), X$(), B
7360 CALL "opn": O, A$
7365 CALL "tyn": T(), M(A, 1), B$
7370 CALL "tyn": T(), M(B, 1), C$
7375 CALL "er": N(), X(), X$(), J, "BAD_OPERANDS", A$, B$, C$, 3
7380 LET M(J, 1) = 0
7385 SUBEND
7390 REM ---- ck_ifx: if expression J (LANGUAGE 6.10, 4.2 (f)) --------------------------------------
7395 SUB "ck_ifx": N(), M(), T(), C(), X(), X$(), J
7400 LET E = N(J, 7)
7405 LET A = N(E, 8)
7410 LET B = N(A, 8)
7415 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
7420 CALL "vu": N(), M(), T(), X(), X$(), A, G1
7425 CALL "vu": N(), M(), T(), X(), X$(), B, G2
7430 IF G1 = 0 THEN 7530
7435 IF G2 = 0 THEN 7530
7440 IF G1 <> -1 THEN 7470
7445 LET D = 3
7450 IF G2 <> 4 THEN 7460
7455 LET D = 4
7460 CALL "stl": N(), M(), C(), X(), X$(), A, D
7465 LET G1 = D
7470 IF G2 <> -1 THEN 7500
7475 LET D = 3
7480 IF G1 <> 4 THEN 7490
7485 LET D = 4
7490 CALL "stl": N(), M(), C(), X(), X$(), B, D
7495 LET G2 = D
7500 IF G1 = G2 THEN 7525
7505 CALL "tyn": T(), G1, A$
7510 CALL "tyn": T(), G2, B$
7515 CALL "er": N(), X(), X$(), B, "TYPE_MISMATCH", A$, B$, "", 2
7520 GOTO 7530
7525 LET M(J, 1) = G1
7530 SUBEND
7535 REM ---- ck_conv: f64(x), i64(x) of bool, i64, f64 (LANGUAGE 10.1; lib nodes, DESIGN 3.5.5) -----
7540 SUB "ck_conv": N(), M(), T(), C(), X(), X$(), J
7545 LET A = N(J, 7)
7550 LET O = N(J, 1)
7555 IF O < 3 THEN 7570
7560 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
7565 GOTO 7635
7570 CALL "vu": N(), M(), T(), X(), X$(), A, D
7575 IF D = 0 THEN 7635
7580 IF D <> -1 THEN 7600
7585 REM an untyped argument is i64 (both conversions accept i64, LANGUAGE 4.2)
7590 CALL "stl": N(), M(), C(), X(), X$(), A, 3
7595 LET D = 3
7600 REM bool, i64 and f64 (the identity too: f64(2.5), i64(7) in tests/programs/op_cvt)
7605 IF D < 2 THEN 7615
7610 IF D <= 4 THEN 7630
7615 CALL "tyn": T(), D, B$
7620 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", SEG$("f64i64", 3 * O - 2, 3 * O), B$, "", 2
7625 GOTO 7635
7630 LET M(J, 1) = 5 - O
7635 SUBEND
7640 REM ---- ck_rng: a range J; in phase 1 only as the iterable of a for: i64 bounds and step --------
7645 SUB "ck_rng": N(), M(), T(), C(), X(), X$(), J
7650 IF N(N(J, 9), 0) <> 18 THEN 7725
7655 LET A = N(J, 7)
7660 IF A = 0 THEN 7715
7665 CALL "vu": N(), M(), T(), X(), X$(), A, D
7670 IF D <> -1 THEN 7685
7675 CALL "stl": N(), M(), C(), X(), X$(), A, 3
7680 LET D = 3
7685 IF D = 3 THEN 7705
7690 IF D = 0 THEN 7705
7695 CALL "tyn": T(), D, B$
7700 CALL "er": N(), X(), X$(), A, "TYPE_MISMATCH", "i64", B$, "", 2
7705 LET A = N(A, 8)
7710 GOTO 7660
7715 CALL "tvec": T(), N(), X(), X$(), 3, R
7720 LET M(J, 1) = R
7725 SUBEND
