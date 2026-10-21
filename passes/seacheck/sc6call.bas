8380 REM ---- ck_call: call J: a Sea function, a library function, or an error (LANGUAGE 8.1, 10) -----
8385 SUB "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
8390 LET G = N(J, 7)
8395 IF N(G, 0) = 30 THEN 8420
8400 IF M(G, 1) = 0 THEN 8470
8405 CALL "tyn": T(), M(G, 1), A$
8410 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", A$, "", "", 1
8415 GOTO 8470
8420 LET R = M(G, 2)
8425 IF R = 0 THEN 8470
8430 IF R < 0 THEN 8450
8435 IF Y(R, 0) <> 1 THEN 8465
8440 CALL "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
8445 GOTO 8470
8450 IF R > -9 THEN 8465
8455 CALL "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
8460 GOTO 8470
8465 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", S$(N(G, 6)), "", "", 1
8470 SUBEND
8475 REM ---- ck_ucall: call J of Sea function R: counts, ref marks and targets, types, aliasing ------
8480 REM (LANGUAGE 8.1, 8.3, 4.2: a ref argument of a var-rule candidate for an f64 parameter is an
8485 REM f64 store, Decision 8)
8490 SUB "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
8495 LET H = N(J, 1)
8500 LET P0 = Y(R, 6)
8505 IF Y(R, 7) = 0 THEN 8520
8510 LET M(J, 1) = Y(R, 2)
8515 GOTO 8525
8520 LET M(J, 1) = 1
8525 IF H <= P0 THEN 8540
8530 CALL "er": N(), X(), X$(), J, "TOO_MANY_ARGS", "", "", "", 0
8535 GOTO 8550
8540 IF H = P0 THEN 8550
8545 CALL "er": N(), X(), X$(), J, "MISSING_ARG", "", "", "", 0
8550 LET A = N(N(J, 7), 8)
8555 LET P = N(Y(R, 3), 7)
8560 FOR I = 1 TO H
8565 IF I > P0 THEN 8765
8570 LET D = M(P, 1)
8575 LET K = N(A, 0)
8580 IF K = 36 THEN 8770
8585 IF N(P, 1) = 1 THEN 8620
8590 REM an ordinary parameter
8595 IF K <> 37 THEN 8610
8600 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", S$(N(P, 6)), "", "", 1
8605 GOTO 8770
8610 CALL "cv": N(), M(), T(), C(), X(), X$(), A, D
8615 GOTO 8770
8620 REM a ref parameter: the argument says ref and is a var, or a ref parameter of the caller
8625 IF K = 37 THEN 8640
8630 CALL "er": N(), X(), X$(), A, "REF_NEEDED", S$(N(P, 6)), "", "", 1
8635 GOTO 8770
8640 LET G = N(A, 7)
8645 IF N(G, 0) = 30 THEN 8660
8650 IF M(G, 1) = 0 THEN 8770
8655 GOTO 8700
8660 REM a name: undeclared (reported at the name), else it must be a var or a ref parameter;
8665 REM a function, struct, constant, predeclared name or handle type is no ref target
8670 LET S = M(G, 2)
8675 IF S = 0 THEN 8770
8680 IF S < 0 THEN 8700
8685 IF Y(S, 0) <> 4 THEN 8700
8690 IF Y(S, 4) = 2 THEN 8710
8695 IF Y(S, 4) = 5 THEN 8710
8700 CALL "er": N(), X(), X$(), A, "REF_TARGET", "", "", "", 0
8705 GOTO 8770
8710 IF D = 0 THEN 8770
8715 IF M(G, 1) = D THEN 8770
8720 IF Y(S, 6) = 0 THEN 8745
8725 IF D <> 4 THEN 8745
8730 IF M(G, 1) <> 3 THEN 8745
8735 CALL "cand": M(), Y(), X(), S
8740 GOTO 8770
8745 CALL "tyn": T(), D, A$
8750 CALL "tyn": T(), M(G, 1), B$
8755 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
8760 GOTO 8770
8765 CALL "fin": N(), M(), C(), X(), X$(), A
8770 LET A = N(A, 8)
8775 LET P = N(P, 8)
8780 NEXT I
8785 REM a ref argument must not share its root variable with another argument (LANGUAGE 8.3)
8790 LET A = N(N(J, 7), 8)
8795 FOR I = 1 TO H
8800 IF N(A, 0) <> 37 THEN 8860
8805 CALL "root": N(), M(), Y(), A, S
8810 IF S = 0 THEN 8860
8815 LET B = N(N(J, 7), 8)
8820 IF B = 0 THEN 8860
8825 IF B = A THEN 8850
8830 CALL "root": N(), M(), Y(), B, S1
8835 IF S1 <> S THEN 8850
8840 CALL "er": N(), X(), X$(), A, "REF_ALIAS", "", "", "", 0
8845 GOTO 8870
8850 LET B = N(B, 8)
8855 GOTO 8820
8860 LET A = N(A, 8)
8865 NEXT I
8870 SUBEND
8875 REM ---- root: S = the local at the root of argument A (a name, or ref of a name), else 0 --------
8880 SUB "root": N(), M(), Y(), A, S
8885 LET S = 0
8890 LET G = A
8895 IF N(G, 0) <> 37 THEN 8905
8900 LET G = N(G, 7)
8905 IF N(G, 0) <> 30 THEN 8925
8910 IF M(G, 2) <= 0 THEN 8925
8915 IF Y(M(G, 2), 0) <> 4 THEN 8925
8920 LET S = M(G, 2)
8925 SUBEND
8930 REM ---- ck_lib: call J of a library function: phase 1 has printf, now, idiv (f64 and i64 are
8935 REM conv nodes); any other is 'not supported yet: <name>' at the call (DESIGN 2.6.2) ---------
8940 SUB "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
8945 LET L$ = S$(N(N(J, 7), 6))
8950 LET H = N(J, 1)
8955 IF LEN(L$) <> 6 THEN 8975
8960 IF L$ <> "printf" THEN 8975
8965 CALL "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
8970 GOTO 9195
8975 LET Z = 0
8980 IF LEN(L$) <> 3 THEN 9005
8985 IF L$ <> "now" THEN 9005
8990 LET Z = 1
8995 LET D = 4
9000 GOTO 9040
9005 IF LEN(L$) <> 4 THEN 9030
9010 IF L$ <> "idiv" THEN 9030
9015 LET Z = 2
9020 LET D = 3
9025 GOTO 9040
9030 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", L$, "", "", 1
9035 GOTO 9195
9040 REM the arguments: untyped constants are i64; the overload is now() or idiv(i64, i64)
9045 LET B$ = ""
9050 LET E = 0
9055 LET F = 0
9060 LET A = N(N(J, 7), 8)
9065 FOR I = 1 TO H
9070 IF N(A, 0) <> 37 THEN 9090
9075 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", L$, "", "", 1
9080 LET E = 1
9085 GOTO 9145
9090 CALL "vu": N(), M(), T(), X(), X$(), A, V
9095 CALL "fin": N(), M(), C(), X(), X$(), A
9100 IF V = 0 THEN 9110
9105 IF M(A, 1) = 3 THEN 9115
9110 LET F = 1
9115 IF V <> 0 THEN 9125
9120 LET E = 1
9125 CALL "tyn": T(), M(A, 1), A$
9130 IF I = 1 THEN 9140
9135 LET B$ = B$ & ", "
9140 LET B$ = B$ & A$
9145 LET A = N(A, 8)
9150 NEXT I
9155 LET M(J, 1) = D
9160 IF E = 1 THEN 9195
9165 IF Z = 2 THEN 9180
9170 IF H = 0 THEN 9195
9175 GOTO 9190
9180 IF H <> 2 THEN 9190
9185 IF F = 0 THEN 9195
9190 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", L$, B$, "", 2
9195 SUBEND
9200 REM ---- ck_printf: printf(format, args...) (LANGUAGE 11.1; DESIGN 2.6.2 "Within one formatting
9205 REM call"): an argument's own errors first, then the format literal, its conversions, the
9210 REM argument count, and each argument against its conversion ------------------------------
9215 SUB "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9220 DIM P(4100, 6)
9225 LET M(J, 1) = 1
9230 LET H = N(J, 1)
9235 LET G = N(J, 7)
9240 LET M(G, 8) = -J
9245 IF H > 0 THEN 9260
9250 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", "printf", "", "", 2
9255 GOTO 9535
9260 LET F = N(G, 8)
9265 LET Z = 0
9270 IF N(F, 0) <> 27 THEN 9285
9275 LET Z = 1
9280 CALL "fmtp": S$(N(F, 6)), P(), N0, E, E$, X(35)
9285 REM every argument: no ref, one value; untyped constants are f64 under f F e E g G, else i64
9290 LET A = N(F, 8)
9295 FOR I = 1 TO H - 1
9300 IF N(A, 0) <> 37 THEN 9315
9305 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", "printf", "", "", 1
9310 GOTO 9370
9315 CALL "vu": N(), M(), T(), X(), X$(), A, V
9320 IF V <> -1 THEN 9370
9325 LET D = 3
9330 IF Z = 0 THEN 9365
9335 IF E = 1 THEN 9365
9340 IF I > N0 THEN 9365
9345 CALL "fmtc": P(), I, Q
9350 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
9355 IF POS("fFeEgG", C$) = 0 THEN 9365
9360 LET D = 4
9365 CALL "stl": N(), M(), C(), X(), X$(), A, D
9370 LET A = N(A, 8)
9375 NEXT I
9380 IF X(9) > M(M(J, 0), 3) THEN 9535
9385 IF Z = 1 THEN 9405
9390 IF M(F, 1) = 0 THEN 9535
9395 CALL "er": N(), X(), X$(), F, "FORMAT_LITERAL", "", "", "", 0
9400 GOTO 9535
9405 IF E = 0 THEN 9425
9410 CALL "resc": E$, A$
9415 CALL "er": N(), X(), X$(), F, "FORMAT_BAD", A$, "", "", 1
9420 GOTO 9535
9425 IF N0 = H - 1 THEN 9445
9430 CALL "resc": S$(N(F, 6)), A$
9435 CALL "er": N(), X(), X$(), J, "FORMAT_COUNT", A$, STR$(N0), STR$(H - 1), 3
9440 GOTO 9535
9445 LET A = N(F, 8)
9450 FOR I = 1 TO H - 1
9455 CALL "fmtc": P(), I, Q
9460 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
9465 LET V = M(A, 1)
9470 IF C$ = "s" THEN 9505
9475 IF V = 3 THEN 9525
9480 IF V = 4 THEN 9525
9485 IF V <> 2 THEN 9495
9490 IF POS("di", C$) > 0 THEN 9525
9495 LET B$ = "an integer or f64"
9500 GOTO 9515
9505 IF V = 5 THEN 9525
9510 LET B$ = "str"
9515 CALL "tyn": T(), V, C$
9520 CALL "er": N(), X(), X$(), A, "FORMAT_ARG", SEG$(S$(N(F, 6)), P(Q, 1), P(Q, 2)), B$, C$, 3
9525 LET A = N(A, 8)
9530 NEXT I
9535 SUBEND
9540 REM ---- fmtc: Q = the piece of the I-th conversion of a parsed format P ------------------------
9545 SUB "fmtc": P(), I, Q
9550 LET K = 0
9555 FOR Q = 1 TO P(0, 0)
9560 IF P(Q, 0) <> 2 THEN 9575
9565 LET K = K + 1
9570 IF K = I THEN 9585
9575 NEXT Q
9580 LET Q = 0
9585 SUBEND
9590 REM ---- fmtp: parse format F$ (LANGUAGE 11.1) into pieces P(1..P(0,0)): P(k,0) 1 text (bytes
9595 REM P(k,1)..P(k,2), %% not yet collapsed) or 2 conversion (P(k,1) the %, P(k,2) the letter,
9600 REM P(k,3) flags: 1 '-' 2 '+' 4 ' ' 8 '0' 16 '#', P(k,4) width, P(k,5) precision, -1 absent);
9605 REM N = conversions; E = 1 and E$ = the invalid conversion from its % through the byte that
9610 REM makes it invalid (or the end of the format); width and precision are at most V9 by value
9615 SUB "fmtp": F$, P(), N, E, E$, V9
9620 LET P(0, 0) = 0
9625 LET N = 0
9630 LET E = 0
9635 LET E$ = ""
9640 LET L0 = LEN(F$)
9645 LET I = 1
9650 LET S0 = 0
9655 IF I > L0 THEN 10030
9660 IF SEG$(F$, I, I) = "%" THEN 9685
9665 IF S0 > 0 THEN 9675
9670 LET S0 = I
9675 LET I = I + 1
9680 GOTO 9655
9685 IF I = L0 THEN 9715
9690 IF SEG$(F$, I + 1, I + 1) <> "%" THEN 9715
9695 IF S0 > 0 THEN 9705
9700 LET S0 = I
9705 LET I = I + 2
9710 GOTO 9655
9715 REM a conversion: the text before it is one piece
9720 IF S0 = 0 THEN 9750
9725 LET P(0, 0) = P(0, 0) + 1
9730 LET P(P(0, 0), 0) = 1
9735 LET P(P(0, 0), 1) = S0
9740 LET P(P(0, 0), 2) = I - 1
9745 LET S0 = 0
9750 LET S = I
9755 LET G = 0
9760 LET I = I + 1
9765 IF I > L0 THEN 10015
9770 LET H = POS("-+ 0#", SEG$(F$, I, I))
9775 IF H = 0 THEN 9805
9780 LET B = 2 ^ (H - 1)
9785 IF INT(G / B) - 2 * INT(G / (2 * B)) = 1 THEN 9795
9790 LET G = G + B
9795 LET I = I + 1
9800 GOTO 9765
9805 LET W = -1
9810 IF I > L0 THEN 10015
9815 LET H = POS("0123456789", SEG$(F$, I, I))
9820 IF H = 0 THEN 9855
9825 IF W >= 0 THEN 9835
9830 LET W = 0
9835 IF 10 * W + H - 1 > V9 THEN 10000
9840 LET W = 10 * W + H - 1
9845 LET I = I + 1
9850 GOTO 9810
9855 LET R = -1
9860 IF SEG$(F$, I, I) <> "." THEN 9910
9865 LET R = 0
9870 LET I = I + 1
9875 IF I > L0 THEN 10015
9880 LET H = POS("0123456789", SEG$(F$, I, I))
9885 IF H = 0 THEN 9910
9890 IF 10 * R + H - 1 > V9 THEN 10000
9895 LET R = 10 * R + H - 1
9900 LET I = I + 1
9905 GOTO 9875
9910 LET C$ = SEG$(F$, I, I)
9915 IF POS("diFfEeGgs", C$) = 0 THEN 10000
9920 REM C leaves # with d i s and 0 with s undefined: invalid here (LANGUAGE 11.1)
9925 IF G < 16 THEN 9935
9930 IF POS("dis", C$) > 0 THEN 10000
9935 IF C$ <> "s" THEN 9945
9940 IF INT(G / 8) - 2 * INT(G / 16) = 1 THEN 10000
9945 LET P(0, 0) = P(0, 0) + 1
9950 LET K = P(0, 0)
9955 LET P(K, 0) = 2
9960 LET P(K, 1) = S
9965 LET P(K, 2) = I
9970 LET P(K, 3) = G
9975 LET P(K, 4) = W
9980 LET P(K, 5) = R
9985 LET N = N + 1
9990 LET I = I + 1
9995 GOTO 9655
10000 LET E = 1
10005 LET E$ = SEG$(F$, S, I)
10010 GOTO 10055
10015 LET E = 1
10020 LET E$ = SEG$(F$, S, L0)
10025 GOTO 10055
10030 IF S0 = 0 THEN 10055
10035 LET P(0, 0) = P(0, 0) + 1
10040 LET P(P(0, 0), 0) = 1
10045 LET P(P(0, 0), 1) = S0
10050 LET P(P(0, 0), 2) = L0
10055 SUBEND
