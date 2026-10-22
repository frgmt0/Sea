8660 REM ---- ck_call: call J: a Sea function, a library function, or an error (LANGUAGE 8.1, 10) -----
8665 SUB "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
8670 LET G = N(J, 7)
8675 IF N(G, 0) = 30 THEN 8700
8680 IF M(G, 1) = 0 THEN 8750
8685 CALL "tyn": T(), M(G, 1), A$
8690 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", A$, "", "", 1
8695 GOTO 8750
8700 LET R = M(G, 2)
8705 IF R = 0 THEN 8750
8710 IF R < 0 THEN 8730
8715 IF Y(R, 0) <> 1 THEN 8745
8720 CALL "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
8725 GOTO 8750
8730 IF R > -9 THEN 8745
8735 CALL "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
8740 GOTO 8750
8745 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", S$(N(G, 6)), "", "", 1
8750 SUBEND
8755 REM ---- ck_ucall: call J of Sea function R: counts, ref marks and targets, types, aliasing ------
8760 REM (LANGUAGE 8.1, 8.3, 4.2: a ref argument of a var-rule candidate for an f64 parameter is an
8765 REM f64 store, Decision 8)
8770 SUB "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
8775 LET H = N(J, 1)
8780 LET P0 = Y(R, 6)
8785 IF Y(R, 7) = 0 THEN 8800
8790 LET M(J, 1) = Y(R, 2)
8795 GOTO 8805
8800 LET M(J, 1) = 1
8805 IF H <= P0 THEN 8820
8810 CALL "er": N(), X(), X$(), J, "TOO_MANY_ARGS", "", "", "", 0
8815 GOTO 8830
8820 IF H = P0 THEN 8830
8825 CALL "er": N(), X(), X$(), J, "MISSING_ARG", "", "", "", 0
8830 LET A = N(N(J, 7), 8)
8835 LET P = N(Y(R, 3), 7)
8840 FOR I = 1 TO H
8845 IF I > P0 THEN 9045
8850 LET D = M(P, 1)
8855 LET K = N(A, 0)
8860 IF K = 36 THEN 9050
8865 IF N(P, 1) = 1 THEN 8900
8870 REM an ordinary parameter
8875 IF K <> 37 THEN 8890
8880 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", S$(N(P, 6)), "", "", 1
8885 GOTO 9050
8890 CALL "cv": N(), M(), T(), C(), X(), X$(), A, D
8895 GOTO 9050
8900 REM a ref parameter: the argument says ref and is a var, or a ref parameter of the caller
8905 IF K = 37 THEN 8920
8910 CALL "er": N(), X(), X$(), A, "REF_NEEDED", S$(N(P, 6)), "", "", 1
8915 GOTO 9050
8920 LET G = N(A, 7)
8925 IF N(G, 0) = 30 THEN 8940
8930 IF M(G, 1) = 0 THEN 9050
8935 GOTO 8980
8940 REM a name: undeclared (reported at the name), else it must be a var or a ref parameter;
8945 REM a function, struct, constant, predeclared name or handle type is no ref target
8950 LET S = M(G, 2)
8955 IF S = 0 THEN 9050
8960 IF S < 0 THEN 8980
8965 IF Y(S, 0) <> 4 THEN 8980
8970 IF Y(S, 4) = 2 THEN 8990
8975 IF Y(S, 4) = 5 THEN 8990
8980 CALL "er": N(), X(), X$(), A, "REF_TARGET", "", "", "", 0
8985 GOTO 9050
8990 IF D = 0 THEN 9050
8995 IF M(G, 1) = D THEN 9050
9000 IF Y(S, 6) = 0 THEN 9025
9005 IF D <> 4 THEN 9025
9010 IF M(G, 1) <> 3 THEN 9025
9015 CALL "cand": M(), Y(), X(), S
9020 GOTO 9050
9025 CALL "tyn": T(), D, A$
9030 CALL "tyn": T(), M(G, 1), B$
9035 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
9040 GOTO 9050
9045 CALL "fin": N(), M(), C(), X(), X$(), A
9050 LET A = N(A, 8)
9055 LET P = N(P, 8)
9060 NEXT I
9065 REM a ref argument must not share its root variable with another argument (LANGUAGE 8.3)
9070 LET A = N(N(J, 7), 8)
9075 FOR I = 1 TO H
9080 IF N(A, 0) <> 37 THEN 9140
9085 CALL "root": N(), M(), Y(), A, S
9090 IF S = 0 THEN 9140
9095 LET B = N(N(J, 7), 8)
9100 IF B = 0 THEN 9140
9105 IF B = A THEN 9130
9110 CALL "root": N(), M(), Y(), B, S1
9115 IF S1 <> S THEN 9130
9120 CALL "er": N(), X(), X$(), A, "REF_ALIAS", "", "", "", 0
9125 GOTO 9150
9130 LET B = N(B, 8)
9135 GOTO 9100
9140 LET A = N(A, 8)
9145 NEXT I
9150 SUBEND
9155 REM ---- root: S = the local at the root of argument A (a name, or ref of a name), else 0 --------
9160 SUB "root": N(), M(), Y(), A, S
9165 LET S = 0
9170 LET G = A
9175 IF N(G, 0) <> 37 THEN 9185
9180 LET G = N(G, 7)
9185 IF N(G, 0) <> 30 THEN 9205
9190 IF M(G, 2) <= 0 THEN 9205
9195 IF Y(M(G, 2), 0) <> 4 THEN 9205
9200 LET S = M(G, 2)
9205 SUBEND
9210 REM ---- ck_lib: call J of a library function: printf, now, idiv (f64 and i64 are conv nodes),
9215 REM from phase 3 log exp sin cos pow hypot (DESIGN 4.10.5); any other is 'not supported yet:
9220 REM <name>' at the call (DESIGN 2.6.2) -----------------------------------------------------
9225 SUB "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9230 LET L$ = S$(N(N(J, 7), 6))
9235 LET H = N(J, 1)
9240 IF LEN(L$) <> 6 THEN 9260
9245 IF L$ <> "printf" THEN 9260
9250 CALL "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9255 GOTO 9595
9260 LET Z = 0
9265 IF LEN(L$) <> 3 THEN 9290
9270 IF L$ <> "now" THEN 9290
9275 LET Z = 1
9280 LET D = 4
9285 GOTO 9370
9290 IF LEN(L$) <> 4 THEN 9315
9295 IF L$ <> "idiv" THEN 9315
9300 LET Z = 2
9305 LET D = 3
9310 GOTO 9370
9315 REM log exp sin cos (f64) -> f64, pow hypot (f64, f64) -> f64: N9 arguments
9320 LET Z = POS("|log |exp |sin |cos |pow |hypot ", "|" & L$ & " ")
9325 IF Z = 0 THEN 9360
9330 LET N9 = 1
9335 IF Z < 20 THEN 9345
9340 LET N9 = 2
9345 LET Z = 3
9350 LET D = 4
9355 GOTO 9370
9360 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", L$, "", "", 1
9365 GOTO 9595
9370 REM the arguments: untyped constants are i64 (f64 for an elementary function, whose i64
9375 REM arguments are converted: LANGUAGE 4.2); the overload is now(), idiv(i64, i64) or f64s
9380 LET B$ = ""
9385 LET E = 0
9390 LET F = 0
9395 LET A = N(N(J, 7), 8)
9400 FOR I = 1 TO H
9405 IF N(A, 0) <> 37 THEN 9425
9410 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", L$, "", "", 1
9415 LET E = 1
9420 GOTO 9525
9425 CALL "vu": N(), M(), T(), X(), X$(), A, V
9430 IF Z = 3 THEN 9460
9435 CALL "fin": N(), M(), C(), X(), X$(), A
9440 IF V = 0 THEN 9450
9445 IF M(A, 1) = 3 THEN 9495
9450 LET F = 1
9455 GOTO 9495
9460 IF V <> -1 THEN 9475
9465 CALL "stl": N(), M(), C(), X(), X$(), A, 4
9470 GOTO 9505
9475 IF V = 4 THEN 9505
9480 IF V <> 3 THEN 9450
9485 LET M(A, 7) = 1
9490 GOTO 9505
9495 IF V <> 0 THEN 9505
9500 LET E = 1
9505 CALL "tyn": T(), M(A, 1), A$
9510 IF I = 1 THEN 9520
9515 LET B$ = B$ & ", "
9520 LET B$ = B$ & A$
9525 LET A = N(A, 8)
9530 NEXT I
9535 LET M(J, 1) = D
9540 IF E = 1 THEN 9595
9545 IF Z = 2 THEN 9580
9550 IF Z = 3 THEN 9565
9555 IF H = 0 THEN 9595
9560 GOTO 9590
9565 IF H <> N9 THEN 9590
9570 IF F = 0 THEN 9595
9575 GOTO 9590
9580 IF H <> 2 THEN 9590
9585 IF F = 0 THEN 9595
9590 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", L$, B$, "", 2
9595 SUBEND
9600 REM ---- ck_printf: printf(format, args...) (LANGUAGE 11.1; DESIGN 2.6.2 "Within one formatting
9605 REM call"): an argument's own errors first, then the format literal, its conversions, the
9610 REM argument count, and each argument against its conversion ------------------------------
9615 SUB "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9620 DIM P(4100, 6)
9625 LET M(J, 1) = 1
9630 LET H = N(J, 1)
9635 LET G = N(J, 7)
9640 LET M(G, 8) = -J
9645 IF H > 0 THEN 9660
9650 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", "printf", "", "", 2
9655 GOTO 9945
9660 LET F = N(G, 8)
9665 LET Z = 0
9670 IF N(F, 0) <> 27 THEN 9685
9675 LET Z = 1
9680 CALL "fmtp": S$(N(F, 6)), P(), N0, E, E$, X(35)
9685 REM every argument: no ref, one value; untyped constants are f64 under f F e E g G, else i64
9690 LET A = N(F, 8)
9695 FOR I = 1 TO H - 1
9700 IF N(A, 0) <> 37 THEN 9715
9705 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", "printf", "", "", 1
9710 GOTO 9770
9715 CALL "vu": N(), M(), T(), X(), X$(), A, V
9720 IF V <> -1 THEN 9770
9725 LET D = 3
9730 IF Z = 0 THEN 9765
9735 IF E = 1 THEN 9765
9740 IF I > N0 THEN 9765
9745 CALL "fmtc": P(), I, Q
9750 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
9755 IF POS("fFeEgG", C$) = 0 THEN 9765
9760 LET D = 4
9765 CALL "stl": N(), M(), C(), X(), X$(), A, D
9770 LET A = N(A, 8)
9775 NEXT I
9780 IF X(9) > M(M(J, 0), 3) THEN 9945
9785 IF Z = 1 THEN 9805
9790 IF M(F, 1) = 0 THEN 9945
9795 CALL "er": N(), X(), X$(), F, "FORMAT_LITERAL", "", "", "", 0
9800 GOTO 9945
9805 IF E = 0 THEN 9825
9810 CALL "resc": E$, A$
9815 CALL "er": N(), X(), X$(), F, "FORMAT_BAD", A$, "", "", 1
9820 GOTO 9945
9825 IF N0 = H - 1 THEN 9845
9830 CALL "resc": S$(N(F, 6)), A$
9835 CALL "er": N(), X(), X$(), J, "FORMAT_COUNT", A$, STR$(N0), STR$(H - 1), 3
9840 GOTO 9945
9845 LET A = N(F, 8)
9850 FOR I = 1 TO H - 1
9855 CALL "fmtc": P(), I, Q
9860 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
9865 LET V = M(A, 1)
9870 REM an argument of error type (0: a failed constant, reported at its declaration) is settled
9875 IF V = 0 THEN 9935
9880 IF C$ = "s" THEN 9915
9885 IF V = 3 THEN 9935
9890 IF V = 4 THEN 9935
9895 IF V <> 2 THEN 9905
9900 IF POS("di", C$) > 0 THEN 9935
9905 LET B$ = "an integer or f64"
9910 GOTO 9925
9915 IF V = 5 THEN 9935
9920 LET B$ = "str"
9925 CALL "tyn": T(), V, C$
9930 CALL "er": N(), X(), X$(), A, "FORMAT_ARG", SEG$(S$(N(F, 6)), P(Q, 1), P(Q, 2)), B$, C$, 3
9935 LET A = N(A, 8)
9940 NEXT I
9945 SUBEND
9950 REM ---- fmtc: Q = the piece of the I-th conversion of a parsed format P ------------------------
9955 SUB "fmtc": P(), I, Q
9960 LET K = 0
9965 FOR Q = 1 TO P(0, 0)
9970 IF P(Q, 0) <> 2 THEN 9985
9975 LET K = K + 1
9980 IF K = I THEN 9995
9985 NEXT Q
9990 LET Q = 0
9995 SUBEND
10000 REM ---- fmtp: parse format F$ (LANGUAGE 11.1) into pieces P(1..P(0,0)): P(k,0) 1 text (bytes
10005 REM P(k,1)..P(k,2), %% not yet collapsed) or 2 conversion (P(k,1) the %, P(k,2) the letter,
10010 REM P(k,3) flags: 1 '-' 2 '+' 4 ' ' 8 '0' 16 '#', P(k,4) width, P(k,5) precision, -1 absent);
10015 REM N = conversions; E = 1 and E$ = the invalid conversion from its % through the byte that
10020 REM makes it invalid (or the end of the format); width and precision are at most V9 by value
10025 SUB "fmtp": F$, P(), N, E, E$, V9
10030 LET P(0, 0) = 0
10035 LET N = 0
10040 LET E = 0
10045 LET E$ = ""
10050 LET L0 = LEN(F$)
10055 LET I = 1
10060 LET S0 = 0
10065 IF I > L0 THEN 10440
10070 IF SEG$(F$, I, I) = "%" THEN 10095
10075 IF S0 > 0 THEN 10085
10080 LET S0 = I
10085 LET I = I + 1
10090 GOTO 10065
10095 IF I = L0 THEN 10125
10100 IF SEG$(F$, I + 1, I + 1) <> "%" THEN 10125
10105 IF S0 > 0 THEN 10115
10110 LET S0 = I
10115 LET I = I + 2
10120 GOTO 10065
10125 REM a conversion: the text before it is one piece
10130 IF S0 = 0 THEN 10160
10135 LET P(0, 0) = P(0, 0) + 1
10140 LET P(P(0, 0), 0) = 1
10145 LET P(P(0, 0), 1) = S0
10150 LET P(P(0, 0), 2) = I - 1
10155 LET S0 = 0
10160 LET S = I
10165 LET G = 0
10170 LET I = I + 1
10175 IF I > L0 THEN 10425
10180 LET H = POS("-+ 0#", SEG$(F$, I, I))
10185 IF H = 0 THEN 10215
10190 LET B = 2 ^ (H - 1)
10195 IF INT(G / B) - 2 * INT(G / (2 * B)) = 1 THEN 10205
10200 LET G = G + B
10205 LET I = I + 1
10210 GOTO 10175
10215 LET W = -1
10220 IF I > L0 THEN 10425
10225 LET H = POS("0123456789", SEG$(F$, I, I))
10230 IF H = 0 THEN 10265
10235 IF W >= 0 THEN 10245
10240 LET W = 0
10245 IF 10 * W + H - 1 > V9 THEN 10410
10250 LET W = 10 * W + H - 1
10255 LET I = I + 1
10260 GOTO 10220
10265 LET R = -1
10270 IF SEG$(F$, I, I) <> "." THEN 10320
10275 LET R = 0
10280 LET I = I + 1
10285 IF I > L0 THEN 10425
10290 LET H = POS("0123456789", SEG$(F$, I, I))
10295 IF H = 0 THEN 10320
10300 IF 10 * R + H - 1 > V9 THEN 10410
10305 LET R = 10 * R + H - 1
10310 LET I = I + 1
10315 GOTO 10285
10320 LET C$ = SEG$(F$, I, I)
10325 IF POS("diFfEeGgs", C$) = 0 THEN 10410
10330 REM C leaves # with d i s and 0 with s undefined: invalid here (LANGUAGE 11.1)
10335 IF G < 16 THEN 10345
10340 IF POS("dis", C$) > 0 THEN 10410
10345 IF C$ <> "s" THEN 10355
10350 IF INT(G / 8) - 2 * INT(G / 16) = 1 THEN 10410
10355 LET P(0, 0) = P(0, 0) + 1
10360 LET K = P(0, 0)
10365 LET P(K, 0) = 2
10370 LET P(K, 1) = S
10375 LET P(K, 2) = I
10380 LET P(K, 3) = G
10385 LET P(K, 4) = W
10390 LET P(K, 5) = R
10395 LET N = N + 1
10400 LET I = I + 1
10405 GOTO 10065
10410 LET E = 1
10415 LET E$ = SEG$(F$, S, I)
10420 GOTO 10465
10425 LET E = 1
10430 LET E$ = SEG$(F$, S, L0)
10435 GOTO 10465
10440 IF S0 = 0 THEN 10465
10445 LET P(0, 0) = P(0, 0) + 1
10450 LET P(P(0, 0), 0) = 1
10455 LET P(P(0, 0), 1) = S0
10460 LET P(P(0, 0), 2) = L0
10465 SUBEND
