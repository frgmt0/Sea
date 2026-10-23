7145 REM ---- rs_expr: the expression subtree E, bottom-up: nodes M(E,0)..E are its post-order, so
7150 REM every child comes before its parent (no recursion over expressions). Its names are resolved
7155 REM (rs_name) and it is typed on the well-typed path of a constant expression (LANGUAGE 4.2, 6;
7160 REM DESIGN 3.4.1): literals, true, false, neg, not, bin, names of constants or of pi inf nan
7165 REM eps, calls of pow and sqrt; any other node fails the typed path (fl, type 0). Every ^ whose
7170 REM exponent is a constant integer k, |k| <= LIM_POWK, is marked rpowk (ck_bin).
7175 SUB "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
7180 FOR J = M(E, 0) TO E
7185 LET M(J, 1) = 0
7190 LET M(J, 7) = 0
7195 LET M(J, 8) = 0
7200 LET K = N(J, 0)
7205 IF K = 25 THEN 7255
7210 IF K = 26 THEN 7265
7212 IF K = 27 THEN 7271
7215 IF K = 28 THEN 7275
7220 IF K = 29 THEN 7275
7225 IF K = 30 THEN 7285
7230 IF K = 32 THEN 7295
7235 IF K = 33 THEN 7295
7240 IF K = 34 THEN 7305
7245 IF K = 35 THEN 7315
7250 CALL "fl": X()
7252 GOTO 7320
7255 LET M(J, 1) = -1
7260 GOTO 7320
7265 LET M(J, 1) = 4
7270 GOTO 7320
7271 LET M(J, 1) = 5
7272 GOTO 7320
7275 LET M(J, 1) = 2
7280 GOTO 7320
7285 CALL "rs_name": N(), M(), Y(), W(), S$(), X(), X$(), J
7290 GOTO 7320
7295 CALL "ck_un": N(), M(), T(), C(), X(), X$(), J
7300 GOTO 7320
7305 CALL "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7310 GOTO 7320
7315 CALL "ck_lc": N(), M(), T(), C(), X(), X$(), J
7320 NEXT J
7325 SUBEND
7425 REM ---- rs_name: name J (rname, DESIGN 3.4.1 "Names"): the locals in scope innermost first,
7430 REM then the entered items, then the predeclared names (lk). On the typed path a constant with
7435 REM a value has its type (rcns: str), pi inf nan eps are f64, the callee of a call is left to the call;
7440 REM any other name (a constant waiting or without a value: Decision 25) fails it ------------
7445 SUB "rs_name": N(), M(), Y(), W(), S$(), X(), X$(), J
7450 CALL "lk": Y(), W(), X(), X$(), S$(), N(J, 6), R
7455 LET M(J, 2) = R
7460 LET M(J, 4) = 1
7465 LET P = N(J, 9)
7470 IF N(P, 0) <> 35 THEN 7480
7475 IF N(P, 7) = J THEN 7535
7480 IF R < 0 THEN 7520
7485 IF R = 0 THEN 7530
7490 IF Y(R, 0) <> 2 THEN 7530
7495 IF Y(R, 6) <> 2 THEN 7530
7500 LET V = Y(R, 7)
7505 IF V < 1 THEN 7530
7510 IF V > 4 THEN 7530
7515 LET M(J, 1) = VAL(SEG$("3425", V, V))
7517 GOTO 7535
7520 IF R < -4 THEN 7530
7525 LET M(J, 1) = 4
7527 GOTO 7535
7530 CALL "fl": X()
7535 SUBEND
7540 REM ---- fin: an untyped constant that no context typed is i64 (LANGUAGE 4.2) ------------------
7545 SUB "fin": N(), M(), C(), X(), X$(), I
7550 IF M(I, 1) <> -1 THEN 7560
7555 CALL "stl": N(), M(), C(), X(), X$(), I, 3
7560 SUBEND
7615 REM ---- ck_un: unary - and ! (LANGUAGE 6.4, 6.5) ---------------------------------------------
7620 SUB "ck_un": N(), M(), T(), C(), X(), X$(), J
7625 LET A = N(J, 7)
7630 CALL "vu": N(), M(), T(), X(), X$(), A, D
7635 IF D = 0 THEN 7745
7640 IF N(J, 0) = 33 THEN 7715
7645 IF D = -1 THEN 7705
7650 IF D = 3 THEN 7705
7655 IF D = 4 THEN 7705
7665 CALL "fl": X()
7670 GOTO 7745
7705 LET M(J, 1) = D
7710 GOTO 7745
7715 IF D = 2 THEN 7705
7720 IF D <> -1 THEN 7740
7725 CALL "stl": N(), M(), C(), X(), X$(), A, 3
7740 CALL "fl": X()
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
7920 REM ---- ck_bin: binary operator J (LANGUAGE 6.1-6.6, Appendix B) on the typed path. A ^ is
7925 REM rpowk k when its exponent alone, taken as f64 (an untyped one) or converted (an i64 one),
7930 REM evaluates exactly to an integer k with |k| <= LIM_POWK (DESIGN 3.4.1, 3.5.5): seacheck
7935 REM writes the powk only where it finds the ^ well typed, so the base is not consulted ------
7940 SUB "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7942 LET A = N(J, 7)
7944 LET B = N(A, 8)
7946 LET O = N(J, 1)
7948 CALL "vu": N(), M(), T(), X(), X$(), A, G1
7950 CALL "vu": N(), M(), T(), X(), X$(), B, G2
7952 IF O <> 6 THEN 7955
7953 CALL "pwx": N(), M(), Y(), C(), W(), X(), X$(), J, B, G2
7955 IF G1 = 0 THEN 8315
7960 IF G2 = 0 THEN 8315
7965 REM + and the comparisons of two str (LANGUAGE 7.2, lead decision L-g: sbin)
7970 IF G1 = 5 THEN 7976
7975 IF G2 = 5 THEN 8270
7976 IF G1 <> 5 THEN 7980
7977 CALL "sbin": M(), X(), J, O, G2
7978 GOTO 8315
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
8100 REM % with an f64 operand: 'not supported yet: f64 %' (DESIGN 2.6.2), not on the typed path
8105 CALL "fl": X()
8107 GOTO 8315
8110 IF G1 = 2 THEN 8280
8115 IF G1 > 4 THEN 8280
8120 IF G2 = 2 THEN 8280
8125 IF G2 > 4 THEN 8280
8130 REM ^ is f64: an i64 or untyped operand is converted (LANGUAGE 4.2 (d), 6.5)
8135 IF G1 <> -1 THEN 8145
8140 CALL "stl": N(), M(), C(), X(), X$(), A, 4
8145 IF G1 <> 3 THEN 8175
8150 LET M(A, 7) = 1
8175 LET M(J, 1) = 4
8180 GOTO 8315
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
8270 CALL "fl": X()
8275 GOTO 8315
8280 CALL "fin": N(), M(), C(), X(), X$(), A
8285 CALL "fin": N(), M(), C(), X(), X$(), B
8290 CALL "fl": X()
8310 LET M(J, 1) = 0
8315 SUBEND
8320 REM ---- pwx: the exponent B (type G2) of the ^ at J: an untyped exponent is f64 (it must be
8325 REM exact), an i64 one is converted; a numeric one that is a powk (exact evaluation, powk)
8330 REM marks J with k + 10 in M(J,8) (DESIGN 3.5.5 "Constant exponents") ---------------------
8335 SUB "pwx": N(), M(), Y(), C(), W(), X(), X$(), J, B, G2
8340 IF G2 <> -1 THEN 8350
8345 CALL "stl": N(), M(), C(), X(), X$(), B, 4
8350 IF G2 <> 3 THEN 8360
8355 LET M(B, 7) = 1
8360 IF G2 < 3 THEN 8380
8365 IF G2 > 4 THEN 8380
8370 GOTO 8385
8380 IF G2 <> -1 THEN 8400
8385 CALL "powk": N(), M(), Y(), C(), W(), X(), X$(), B, K0, Z
8390 IF Z <> 1 THEN 8400
8395 LET M(J, 8) = K0 + 10
8400 SUBEND
8405 REM ---- ck_lc: call J on the typed path: pow(x, y) and sqrt(x) with positional f64 arguments
8410 REM (an untyped one is f64, an i64 one is converted: LANGUAGE 4.2, 7.2), of type f64; any
8415 REM other call, a ref or named argument or another count fails it (fl) -------------------
8420 SUB "ck_lc": N(), M(), T(), C(), X(), X$(), J
8425 LET G = N(J, 7)
8430 IF N(G, 0) <> 30 THEN 8585
8435 LET N9 = 2
8440 IF M(G, 2) = -X(39) THEN 8460
8445 LET N9 = 1
8450 IF M(G, 2) = -X(41) THEN 8460
8455 GOTO 8585
8460 LET H = N(J, 1)
8465 LET E = 0
8470 LET F = 0
8475 LET A = N(G, 8)
8480 FOR I = 1 TO H
8485 IF N(A, 0) <> 37 THEN 8505
8490 CALL "fl": X()
8495 LET E = 1
8500 GOTO 8560
8505 CALL "vu": N(), M(), T(), X(), X$(), A, V
8510 IF V <> -1 THEN 8525
8515 CALL "stl": N(), M(), C(), X(), X$(), A, 4
8520 GOTO 8560
8525 IF V = 4 THEN 8560
8530 IF V <> 3 THEN 8545
8535 LET M(A, 7) = 1
8540 GOTO 8560
8545 LET F = 1
8550 IF V <> 0 THEN 8560
8555 LET E = 1
8560 LET A = N(A, 8)
8565 NEXT I
8570 LET M(J, 1) = 4
8575 IF E = 1 THEN 8590
8577 IF H <> N9 THEN 8585
8580 IF F = 0 THEN 8590
8585 CALL "fl": X()
8590 SUBEND
