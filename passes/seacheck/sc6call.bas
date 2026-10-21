8610 REM ---- ck_call: call J: a Sea function, a library function, or an error (LANGUAGE 8.1, 10) -----
8615 SUB "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
8620 LET G = N(J, 7)
8625 IF N(G, 0) = 30 THEN 8650
8630 IF M(G, 1) = 0 THEN 8700
8635 CALL "tyn": T(), M(G, 1), A$
8640 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", A$, "", "", 1
8645 GOTO 8700
8650 LET R = M(G, 2)
8655 IF R = 0 THEN 8700
8660 IF R < 0 THEN 8680
8665 IF Y(R, 0) <> 1 THEN 8695
8670 CALL "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
8675 GOTO 8700
8680 IF R > -9 THEN 8695
8685 CALL "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
8690 GOTO 8700
8695 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", S$(N(G, 6)), "", "", 1
8700 SUBEND
8705 REM ---- ck_ucall: call J of Sea function R: counts, ref marks and targets, types, aliasing ------
8710 REM (LANGUAGE 8.1, 8.3, 4.2: a ref argument of a var-rule candidate for an f64 parameter is an
8715 REM f64 store, Decision 8)
8720 SUB "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
8725 LET H = N(J, 1)
8730 LET P0 = Y(R, 6)
8735 IF Y(R, 7) = 0 THEN 8750
8740 LET M(J, 1) = Y(R, 2)
8745 GOTO 8755
8750 LET M(J, 1) = 1
8755 IF H <= P0 THEN 8770
8760 CALL "er": N(), X(), X$(), J, "TOO_MANY_ARGS", "", "", "", 0
8765 GOTO 8780
8770 IF H = P0 THEN 8780
8775 CALL "er": N(), X(), X$(), J, "MISSING_ARG", "", "", "", 0
8780 LET A = N(N(J, 7), 8)
8785 LET P = N(Y(R, 3), 7)
8790 FOR I = 1 TO H
8795 IF I > P0 THEN 8995
8800 LET D = M(P, 1)
8805 LET K = N(A, 0)
8810 IF K = 36 THEN 9000
8815 IF N(P, 1) = 1 THEN 8850
8820 REM an ordinary parameter
8825 IF K <> 37 THEN 8840
8830 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", S$(N(P, 6)), "", "", 1
8835 GOTO 9000
8840 CALL "cv": N(), M(), T(), C(), X(), X$(), A, D
8845 GOTO 9000
8850 REM a ref parameter: the argument says ref and is a var, or a ref parameter of the caller
8855 IF K = 37 THEN 8870
8860 CALL "er": N(), X(), X$(), A, "REF_NEEDED", S$(N(P, 6)), "", "", 1
8865 GOTO 9000
8870 LET G = N(A, 7)
8875 IF N(G, 0) = 30 THEN 8890
8880 IF M(G, 1) = 0 THEN 9000
8885 GOTO 8930
8890 REM a name: undeclared (reported at the name), else it must be a var or a ref parameter;
8895 REM a function, struct, constant, predeclared name or handle type is no ref target
8900 LET S = M(G, 2)
8905 IF S = 0 THEN 9000
8910 IF S < 0 THEN 8930
8915 IF Y(S, 0) <> 4 THEN 8930
8920 IF Y(S, 4) = 2 THEN 8940
8925 IF Y(S, 4) = 5 THEN 8940
8930 CALL "er": N(), X(), X$(), A, "REF_TARGET", "", "", "", 0
8935 GOTO 9000
8940 IF D = 0 THEN 9000
8945 IF M(G, 1) = D THEN 9000
8950 IF Y(S, 6) = 0 THEN 8975
8955 IF D <> 4 THEN 8975
8960 IF M(G, 1) <> 3 THEN 8975
8965 CALL "cand": M(), Y(), X(), S
8970 GOTO 9000
8975 CALL "tyn": T(), D, A$
8980 CALL "tyn": T(), M(G, 1), B$
8985 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
8990 GOTO 9000
8995 CALL "fin": N(), M(), C(), X(), X$(), A
9000 LET A = N(A, 8)
9005 LET P = N(P, 8)
9010 NEXT I
9015 REM a ref argument must not share its root variable with another argument (LANGUAGE 8.3)
9020 LET A = N(N(J, 7), 8)
9025 FOR I = 1 TO H
9030 IF N(A, 0) <> 37 THEN 9090
9035 CALL "root": N(), M(), Y(), A, S
9040 IF S = 0 THEN 9090
9045 LET B = N(N(J, 7), 8)
9050 IF B = 0 THEN 9090
9055 IF B = A THEN 9080
9060 CALL "root": N(), M(), Y(), B, S1
9065 IF S1 <> S THEN 9080
9070 CALL "er": N(), X(), X$(), A, "REF_ALIAS", "", "", "", 0
9075 GOTO 9100
9080 LET B = N(B, 8)
9085 GOTO 9050
9090 LET A = N(A, 8)
9095 NEXT I
9100 SUBEND
9105 REM ---- root: S = the local at the root of argument A (a name, or ref of a name), else 0 --------
9110 SUB "root": N(), M(), Y(), A, S
9115 LET S = 0
9120 LET G = A
9125 IF N(G, 0) <> 37 THEN 9135
9130 LET G = N(G, 7)
9135 IF N(G, 0) <> 30 THEN 9155
9140 IF M(G, 2) <= 0 THEN 9155
9145 IF Y(M(G, 2), 0) <> 4 THEN 9155
9150 LET S = M(G, 2)
9155 SUBEND
9160 REM ---- ck_lib: call J of a library function: printf, now, idiv (f64 and i64 are conv nodes),
9165 REM from phase 3 log exp sin cos pow hypot (DESIGN 4.10.5); any other is 'not supported yet:
9170 REM <name>' at the call (DESIGN 2.6.2) -----------------------------------------------------
9175 SUB "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9180 LET L$ = S$(N(N(J, 7), 6))
9185 LET H = N(J, 1)
9190 IF LEN(L$) <> 6 THEN 9210
9195 IF L$ <> "printf" THEN 9210
9200 CALL "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9205 GOTO 9545
9210 LET Z = 0
9215 IF LEN(L$) <> 3 THEN 9240
9220 IF L$ <> "now" THEN 9240
9225 LET Z = 1
9230 LET D = 4
9235 GOTO 9320
9240 IF LEN(L$) <> 4 THEN 9265
9245 IF L$ <> "idiv" THEN 9265
9250 LET Z = 2
9255 LET D = 3
9260 GOTO 9320
9265 REM log exp sin cos (f64) -> f64, pow hypot (f64, f64) -> f64: N9 arguments
9270 LET Z = POS("|log |exp |sin |cos |pow |hypot ", "|" & L$ & " ")
9275 IF Z = 0 THEN 9310
9280 LET N9 = 1
9285 IF Z < 20 THEN 9295
9290 LET N9 = 2
9295 LET Z = 3
9300 LET D = 4
9305 GOTO 9320
9310 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", L$, "", "", 1
9315 GOTO 9545
9320 REM the arguments: untyped constants are i64 (f64 for an elementary function, whose i64
9325 REM arguments are converted: LANGUAGE 4.2); the overload is now(), idiv(i64, i64) or f64s
9330 LET B$ = ""
9335 LET E = 0
9340 LET F = 0
9345 LET A = N(N(J, 7), 8)
9350 FOR I = 1 TO H
9355 IF N(A, 0) <> 37 THEN 9375
9360 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", L$, "", "", 1
9365 LET E = 1
9370 GOTO 9475
9375 CALL "vu": N(), M(), T(), X(), X$(), A, V
9380 IF Z = 3 THEN 9410
9385 CALL "fin": N(), M(), C(), X(), X$(), A
9390 IF V = 0 THEN 9400
9395 IF M(A, 1) = 3 THEN 9445
9400 LET F = 1
9405 GOTO 9445
9410 IF V <> -1 THEN 9425
9415 CALL "stl": N(), M(), C(), X(), X$(), A, 4
9420 GOTO 9455
9425 IF V = 4 THEN 9455
9430 IF V <> 3 THEN 9400
9435 LET M(A, 7) = 1
9440 GOTO 9455
9445 IF V <> 0 THEN 9455
9450 LET E = 1
9455 CALL "tyn": T(), M(A, 1), A$
9460 IF I = 1 THEN 9470
9465 LET B$ = B$ & ", "
9470 LET B$ = B$ & A$
9475 LET A = N(A, 8)
9480 NEXT I
9485 LET M(J, 1) = D
9490 IF E = 1 THEN 9545
9495 IF Z = 2 THEN 9530
9500 IF Z = 3 THEN 9515
9505 IF H = 0 THEN 9545
9510 GOTO 9540
9515 IF H <> N9 THEN 9540
9520 IF F = 0 THEN 9545
9525 GOTO 9540
9530 IF H <> 2 THEN 9540
9535 IF F = 0 THEN 9545
9540 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", L$, B$, "", 2
9545 SUBEND
9550 REM ---- ck_printf: printf(format, args...) (LANGUAGE 11.1; DESIGN 2.6.2 "Within one formatting
9555 REM call"): an argument's own errors first, then the format literal, its conversions, the
9560 REM argument count, and each argument against its conversion ------------------------------
9565 SUB "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9570 DIM P(4100, 6)
9575 LET M(J, 1) = 1
9580 LET H = N(J, 1)
9585 LET G = N(J, 7)
9590 LET M(G, 8) = -J
9595 IF H > 0 THEN 9610
9600 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", "printf", "", "", 2
9605 GOTO 9895
9610 LET F = N(G, 8)
9615 LET Z = 0
9620 IF N(F, 0) <> 27 THEN 9635
9625 LET Z = 1
9630 CALL "fmtp": S$(N(F, 6)), P(), N0, E, E$, X(35)
9635 REM every argument: no ref, one value; untyped constants are f64 under f F e E g G, else i64
9640 LET A = N(F, 8)
9645 FOR I = 1 TO H - 1
9650 IF N(A, 0) <> 37 THEN 9665
9655 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", "printf", "", "", 1
9660 GOTO 9720
9665 CALL "vu": N(), M(), T(), X(), X$(), A, V
9670 IF V <> -1 THEN 9720
9675 LET D = 3
9680 IF Z = 0 THEN 9715
9685 IF E = 1 THEN 9715
9690 IF I > N0 THEN 9715
9695 CALL "fmtc": P(), I, Q
9700 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
9705 IF POS("fFeEgG", C$) = 0 THEN 9715
9710 LET D = 4
9715 CALL "stl": N(), M(), C(), X(), X$(), A, D
9720 LET A = N(A, 8)
9725 NEXT I
9730 IF X(9) > M(M(J, 0), 3) THEN 9895
9735 IF Z = 1 THEN 9755
9740 IF M(F, 1) = 0 THEN 9895
9745 CALL "er": N(), X(), X$(), F, "FORMAT_LITERAL", "", "", "", 0
9750 GOTO 9895
9755 IF E = 0 THEN 9775
9760 CALL "resc": E$, A$
9765 CALL "er": N(), X(), X$(), F, "FORMAT_BAD", A$, "", "", 1
9770 GOTO 9895
9775 IF N0 = H - 1 THEN 9795
9780 CALL "resc": S$(N(F, 6)), A$
9785 CALL "er": N(), X(), X$(), J, "FORMAT_COUNT", A$, STR$(N0), STR$(H - 1), 3
9790 GOTO 9895
9795 LET A = N(F, 8)
9800 FOR I = 1 TO H - 1
9805 CALL "fmtc": P(), I, Q
9810 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
9815 LET V = M(A, 1)
9820 REM an argument of error type (0: a failed constant, reported at its declaration) is settled
9825 IF V = 0 THEN 9885
9830 IF C$ = "s" THEN 9865
9835 IF V = 3 THEN 9885
9840 IF V = 4 THEN 9885
9845 IF V <> 2 THEN 9855
9850 IF POS("di", C$) > 0 THEN 9885
9855 LET B$ = "an integer or f64"
9860 GOTO 9875
9865 IF V = 5 THEN 9885
9870 LET B$ = "str"
9875 CALL "tyn": T(), V, C$
9880 CALL "er": N(), X(), X$(), A, "FORMAT_ARG", SEG$(S$(N(F, 6)), P(Q, 1), P(Q, 2)), B$, C$, 3
9885 LET A = N(A, 8)
9890 NEXT I
9895 SUBEND
9900 REM ---- fmtc: Q = the piece of the I-th conversion of a parsed format P ------------------------
9905 SUB "fmtc": P(), I, Q
9910 LET K = 0
9915 FOR Q = 1 TO P(0, 0)
9920 IF P(Q, 0) <> 2 THEN 9935
9925 LET K = K + 1
9930 IF K = I THEN 9945
9935 NEXT Q
9940 LET Q = 0
9945 SUBEND
9950 REM ---- fmtp: parse format F$ (LANGUAGE 11.1) into pieces P(1..P(0,0)): P(k,0) 1 text (bytes
9955 REM P(k,1)..P(k,2), %% not yet collapsed) or 2 conversion (P(k,1) the %, P(k,2) the letter,
9960 REM P(k,3) flags: 1 '-' 2 '+' 4 ' ' 8 '0' 16 '#', P(k,4) width, P(k,5) precision, -1 absent);
9965 REM N = conversions; E = 1 and E$ = the invalid conversion from its % through the byte that
9970 REM makes it invalid (or the end of the format); width and precision are at most V9 by value
9975 SUB "fmtp": F$, P(), N, E, E$, V9
9980 LET P(0, 0) = 0
9985 LET N = 0
9990 LET E = 0
9995 LET E$ = ""
10000 LET L0 = LEN(F$)
10005 LET I = 1
10010 LET S0 = 0
10015 IF I > L0 THEN 10390
10020 IF SEG$(F$, I, I) = "%" THEN 10045
10025 IF S0 > 0 THEN 10035
10030 LET S0 = I
10035 LET I = I + 1
10040 GOTO 10015
10045 IF I = L0 THEN 10075
10050 IF SEG$(F$, I + 1, I + 1) <> "%" THEN 10075
10055 IF S0 > 0 THEN 10065
10060 LET S0 = I
10065 LET I = I + 2
10070 GOTO 10015
10075 REM a conversion: the text before it is one piece
10080 IF S0 = 0 THEN 10110
10085 LET P(0, 0) = P(0, 0) + 1
10090 LET P(P(0, 0), 0) = 1
10095 LET P(P(0, 0), 1) = S0
10100 LET P(P(0, 0), 2) = I - 1
10105 LET S0 = 0
10110 LET S = I
10115 LET G = 0
10120 LET I = I + 1
10125 IF I > L0 THEN 10375
10130 LET H = POS("-+ 0#", SEG$(F$, I, I))
10135 IF H = 0 THEN 10165
10140 LET B = 2 ^ (H - 1)
10145 IF INT(G / B) - 2 * INT(G / (2 * B)) = 1 THEN 10155
10150 LET G = G + B
10155 LET I = I + 1
10160 GOTO 10125
10165 LET W = -1
10170 IF I > L0 THEN 10375
10175 LET H = POS("0123456789", SEG$(F$, I, I))
10180 IF H = 0 THEN 10215
10185 IF W >= 0 THEN 10195
10190 LET W = 0
10195 IF 10 * W + H - 1 > V9 THEN 10360
10200 LET W = 10 * W + H - 1
10205 LET I = I + 1
10210 GOTO 10170
10215 LET R = -1
10220 IF SEG$(F$, I, I) <> "." THEN 10270
10225 LET R = 0
10230 LET I = I + 1
10235 IF I > L0 THEN 10375
10240 LET H = POS("0123456789", SEG$(F$, I, I))
10245 IF H = 0 THEN 10270
10250 IF 10 * R + H - 1 > V9 THEN 10360
10255 LET R = 10 * R + H - 1
10260 LET I = I + 1
10265 GOTO 10235
10270 LET C$ = SEG$(F$, I, I)
10275 IF POS("diFfEeGgs", C$) = 0 THEN 10360
10280 REM C leaves # with d i s and 0 with s undefined: invalid here (LANGUAGE 11.1)
10285 IF G < 16 THEN 10295
10290 IF POS("dis", C$) > 0 THEN 10360
10295 IF C$ <> "s" THEN 10305
10300 IF INT(G / 8) - 2 * INT(G / 16) = 1 THEN 10360
10305 LET P(0, 0) = P(0, 0) + 1
10310 LET K = P(0, 0)
10315 LET P(K, 0) = 2
10320 LET P(K, 1) = S
10325 LET P(K, 2) = I
10330 LET P(K, 3) = G
10335 LET P(K, 4) = W
10340 LET P(K, 5) = R
10345 LET N = N + 1
10350 LET I = I + 1
10355 GOTO 10015
10360 LET E = 1
10365 LET E$ = SEG$(F$, S, I)
10370 GOTO 10415
10375 LET E = 1
10380 LET E$ = SEG$(F$, S, L0)
10385 GOTO 10415
10390 IF S0 = 0 THEN 10415
10395 LET P(0, 0) = P(0, 0) + 1
10400 LET P(P(0, 0), 0) = 1
10405 LET P(P(0, 0), 1) = S0
10410 LET P(P(0, 0), 2) = L0
10415 SUBEND
