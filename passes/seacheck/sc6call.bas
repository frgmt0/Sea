8570 REM ---- ck_call: call J: a Sea function, a library function, or an error (LANGUAGE 8.1, 10) -----
8575 SUB "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
8580 LET G = N(J, 7)
8585 IF N(G, 0) = 30 THEN 8610
8590 IF M(G, 1) = 0 THEN 8660
8595 CALL "tyn": T(), M(G, 1), A$
8600 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", A$, "", "", 1
8605 GOTO 8660
8610 LET R = M(G, 2)
8615 IF R = 0 THEN 8660
8620 IF R < 0 THEN 8640
8625 IF Y(R, 0) <> 1 THEN 8655
8630 CALL "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
8635 GOTO 8660
8640 IF R > -9 THEN 8655
8645 CALL "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
8650 GOTO 8660
8655 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", S$(N(G, 6)), "", "", 1
8660 SUBEND
8665 REM ---- ck_ucall: call J of Sea function R: counts, ref marks and targets, types, aliasing ------
8670 REM (LANGUAGE 8.1, 8.3, 4.2: a ref argument of a var-rule candidate for an f64 parameter is an
8675 REM f64 store, Decision 8)
8680 SUB "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
8685 LET H = N(J, 1)
8690 LET P0 = Y(R, 6)
8695 IF Y(R, 7) = 0 THEN 8710
8700 LET M(J, 1) = Y(R, 2)
8705 GOTO 8715
8710 LET M(J, 1) = 1
8715 IF H <= P0 THEN 8730
8720 CALL "er": N(), X(), X$(), J, "TOO_MANY_ARGS", "", "", "", 0
8725 GOTO 8740
8730 IF H = P0 THEN 8740
8735 CALL "er": N(), X(), X$(), J, "MISSING_ARG", "", "", "", 0
8740 LET A = N(N(J, 7), 8)
8745 LET P = N(Y(R, 3), 7)
8750 FOR I = 1 TO H
8755 IF I > P0 THEN 8955
8760 LET D = M(P, 1)
8765 LET K = N(A, 0)
8770 IF K = 36 THEN 8960
8775 IF N(P, 1) = 1 THEN 8810
8780 REM an ordinary parameter
8785 IF K <> 37 THEN 8800
8790 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", S$(N(P, 6)), "", "", 1
8795 GOTO 8960
8800 CALL "cv": N(), M(), T(), C(), X(), X$(), A, D
8805 GOTO 8960
8810 REM a ref parameter: the argument says ref and is a var, or a ref parameter of the caller
8815 IF K = 37 THEN 8830
8820 CALL "er": N(), X(), X$(), A, "REF_NEEDED", S$(N(P, 6)), "", "", 1
8825 GOTO 8960
8830 LET G = N(A, 7)
8835 IF N(G, 0) = 30 THEN 8850
8840 IF M(G, 1) = 0 THEN 8960
8845 GOTO 8890
8850 REM a name: undeclared (reported at the name), else it must be a var or a ref parameter;
8855 REM a function, struct, constant, predeclared name or handle type is no ref target
8860 LET S = M(G, 2)
8865 IF S = 0 THEN 8960
8870 IF S < 0 THEN 8890
8875 IF Y(S, 0) <> 4 THEN 8890
8880 IF Y(S, 4) = 2 THEN 8900
8885 IF Y(S, 4) = 5 THEN 8900
8890 CALL "er": N(), X(), X$(), A, "REF_TARGET", "", "", "", 0
8895 GOTO 8960
8900 IF D = 0 THEN 8960
8905 IF M(G, 1) = D THEN 8960
8910 IF Y(S, 6) = 0 THEN 8935
8915 IF D <> 4 THEN 8935
8920 IF M(G, 1) <> 3 THEN 8935
8925 CALL "cand": M(), Y(), X(), S
8930 GOTO 8960
8935 CALL "tyn": T(), D, A$
8940 CALL "tyn": T(), M(G, 1), B$
8945 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
8950 GOTO 8960
8955 CALL "fin": N(), M(), C(), X(), X$(), A
8960 LET A = N(A, 8)
8965 LET P = N(P, 8)
8970 NEXT I
8975 REM a ref argument must not share its root variable with another argument (LANGUAGE 8.3)
8980 LET A = N(N(J, 7), 8)
8985 FOR I = 1 TO H
8990 IF N(A, 0) <> 37 THEN 9050
8995 CALL "root": N(), M(), Y(), A, S
9000 IF S = 0 THEN 9050
9005 LET B = N(N(J, 7), 8)
9010 IF B = 0 THEN 9050
9015 IF B = A THEN 9040
9020 CALL "root": N(), M(), Y(), B, S1
9025 IF S1 <> S THEN 9040
9030 CALL "er": N(), X(), X$(), A, "REF_ALIAS", "", "", "", 0
9035 GOTO 9060
9040 LET B = N(B, 8)
9045 GOTO 9010
9050 LET A = N(A, 8)
9055 NEXT I
9060 SUBEND
9065 REM ---- root: S = the local at the root of argument A (a name, or ref of a name), else 0 --------
9070 SUB "root": N(), M(), Y(), A, S
9075 LET S = 0
9080 LET G = A
9085 IF N(G, 0) <> 37 THEN 9095
9090 LET G = N(G, 7)
9095 IF N(G, 0) <> 30 THEN 9115
9100 IF M(G, 2) <= 0 THEN 9115
9105 IF Y(M(G, 2), 0) <> 4 THEN 9115
9110 LET S = M(G, 2)
9115 SUBEND
9120 REM ---- ck_lib: call J of a library function: phase 1 has printf, now, idiv (f64 and i64 are
9125 REM conv nodes); any other is 'not supported yet: <name>' at the call (DESIGN 2.6.2) ---------
9130 SUB "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9135 LET L$ = S$(N(N(J, 7), 6))
9140 LET H = N(J, 1)
9145 IF LEN(L$) <> 6 THEN 9165
9150 IF L$ <> "printf" THEN 9165
9155 CALL "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9160 GOTO 9385
9165 LET Z = 0
9170 IF LEN(L$) <> 3 THEN 9195
9175 IF L$ <> "now" THEN 9195
9180 LET Z = 1
9185 LET D = 4
9190 GOTO 9230
9195 IF LEN(L$) <> 4 THEN 9220
9200 IF L$ <> "idiv" THEN 9220
9205 LET Z = 2
9210 LET D = 3
9215 GOTO 9230
9220 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", L$, "", "", 1
9225 GOTO 9385
9230 REM the arguments: untyped constants are i64; the overload is now() or idiv(i64, i64)
9235 LET B$ = ""
9240 LET E = 0
9245 LET F = 0
9250 LET A = N(N(J, 7), 8)
9255 FOR I = 1 TO H
9260 IF N(A, 0) <> 37 THEN 9280
9265 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", L$, "", "", 1
9270 LET E = 1
9275 GOTO 9335
9280 CALL "vu": N(), M(), T(), X(), X$(), A, V
9285 CALL "fin": N(), M(), C(), X(), X$(), A
9290 IF V = 0 THEN 9300
9295 IF M(A, 1) = 3 THEN 9305
9300 LET F = 1
9305 IF V <> 0 THEN 9315
9310 LET E = 1
9315 CALL "tyn": T(), M(A, 1), A$
9320 IF I = 1 THEN 9330
9325 LET B$ = B$ & ", "
9330 LET B$ = B$ & A$
9335 LET A = N(A, 8)
9340 NEXT I
9345 LET M(J, 1) = D
9350 IF E = 1 THEN 9385
9355 IF Z = 2 THEN 9370
9360 IF H = 0 THEN 9385
9365 GOTO 9380
9370 IF H <> 2 THEN 9380
9375 IF F = 0 THEN 9385
9380 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", L$, B$, "", 2
9385 SUBEND
9390 REM ---- ck_printf: printf(format, args...) (LANGUAGE 11.1; DESIGN 2.6.2 "Within one formatting
9395 REM call"): an argument's own errors first, then the format literal, its conversions, the
9400 REM argument count, and each argument against its conversion ------------------------------
9405 SUB "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9410 DIM P(4100, 6)
9415 LET M(J, 1) = 1
9420 LET H = N(J, 1)
9425 LET G = N(J, 7)
9430 LET M(G, 8) = -J
9435 IF H > 0 THEN 9450
9440 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", "printf", "", "", 2
9445 GOTO 9735
9450 LET F = N(G, 8)
9455 LET Z = 0
9460 IF N(F, 0) <> 27 THEN 9475
9465 LET Z = 1
9470 CALL "fmtp": S$(N(F, 6)), P(), N0, E, E$, X(35)
9475 REM every argument: no ref, one value; untyped constants are f64 under f F e E g G, else i64
9480 LET A = N(F, 8)
9485 FOR I = 1 TO H - 1
9490 IF N(A, 0) <> 37 THEN 9505
9495 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", "printf", "", "", 1
9500 GOTO 9560
9505 CALL "vu": N(), M(), T(), X(), X$(), A, V
9510 IF V <> -1 THEN 9560
9515 LET D = 3
9520 IF Z = 0 THEN 9555
9525 IF E = 1 THEN 9555
9530 IF I > N0 THEN 9555
9535 CALL "fmtc": P(), I, Q
9540 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
9545 IF POS("fFeEgG", C$) = 0 THEN 9555
9550 LET D = 4
9555 CALL "stl": N(), M(), C(), X(), X$(), A, D
9560 LET A = N(A, 8)
9565 NEXT I
9570 IF X(9) > M(M(J, 0), 3) THEN 9735
9575 IF Z = 1 THEN 9595
9580 IF M(F, 1) = 0 THEN 9735
9585 CALL "er": N(), X(), X$(), F, "FORMAT_LITERAL", "", "", "", 0
9590 GOTO 9735
9595 IF E = 0 THEN 9615
9600 CALL "resc": E$, A$
9605 CALL "er": N(), X(), X$(), F, "FORMAT_BAD", A$, "", "", 1
9610 GOTO 9735
9615 IF N0 = H - 1 THEN 9635
9620 CALL "resc": S$(N(F, 6)), A$
9625 CALL "er": N(), X(), X$(), J, "FORMAT_COUNT", A$, STR$(N0), STR$(H - 1), 3
9630 GOTO 9735
9635 LET A = N(F, 8)
9640 FOR I = 1 TO H - 1
9645 CALL "fmtc": P(), I, Q
9650 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
9655 LET V = M(A, 1)
9660 REM an argument of error type (0: a failed constant, reported at its declaration) is settled
9665 IF V = 0 THEN 9725
9670 IF C$ = "s" THEN 9705
9675 IF V = 3 THEN 9725
9680 IF V = 4 THEN 9725
9685 IF V <> 2 THEN 9695
9690 IF POS("di", C$) > 0 THEN 9725
9695 LET B$ = "an integer or f64"
9700 GOTO 9715
9705 IF V = 5 THEN 9725
9710 LET B$ = "str"
9715 CALL "tyn": T(), V, C$
9720 CALL "er": N(), X(), X$(), A, "FORMAT_ARG", SEG$(S$(N(F, 6)), P(Q, 1), P(Q, 2)), B$, C$, 3
9725 LET A = N(A, 8)
9730 NEXT I
9735 SUBEND
9740 REM ---- fmtc: Q = the piece of the I-th conversion of a parsed format P ------------------------
9745 SUB "fmtc": P(), I, Q
9750 LET K = 0
9755 FOR Q = 1 TO P(0, 0)
9760 IF P(Q, 0) <> 2 THEN 9775
9765 LET K = K + 1
9770 IF K = I THEN 9785
9775 NEXT Q
9780 LET Q = 0
9785 SUBEND
9790 REM ---- fmtp: parse format F$ (LANGUAGE 11.1) into pieces P(1..P(0,0)): P(k,0) 1 text (bytes
9795 REM P(k,1)..P(k,2), %% not yet collapsed) or 2 conversion (P(k,1) the %, P(k,2) the letter,
9800 REM P(k,3) flags: 1 '-' 2 '+' 4 ' ' 8 '0' 16 '#', P(k,4) width, P(k,5) precision, -1 absent);
9805 REM N = conversions; E = 1 and E$ = the invalid conversion from its % through the byte that
9810 REM makes it invalid (or the end of the format); width and precision are at most V9 by value
9815 SUB "fmtp": F$, P(), N, E, E$, V9
9820 LET P(0, 0) = 0
9825 LET N = 0
9830 LET E = 0
9835 LET E$ = ""
9840 LET L0 = LEN(F$)
9845 LET I = 1
9850 LET S0 = 0
9855 IF I > L0 THEN 10230
9860 IF SEG$(F$, I, I) = "%" THEN 9885
9865 IF S0 > 0 THEN 9875
9870 LET S0 = I
9875 LET I = I + 1
9880 GOTO 9855
9885 IF I = L0 THEN 9915
9890 IF SEG$(F$, I + 1, I + 1) <> "%" THEN 9915
9895 IF S0 > 0 THEN 9905
9900 LET S0 = I
9905 LET I = I + 2
9910 GOTO 9855
9915 REM a conversion: the text before it is one piece
9920 IF S0 = 0 THEN 9950
9925 LET P(0, 0) = P(0, 0) + 1
9930 LET P(P(0, 0), 0) = 1
9935 LET P(P(0, 0), 1) = S0
9940 LET P(P(0, 0), 2) = I - 1
9945 LET S0 = 0
9950 LET S = I
9955 LET G = 0
9960 LET I = I + 1
9965 IF I > L0 THEN 10215
9970 LET H = POS("-+ 0#", SEG$(F$, I, I))
9975 IF H = 0 THEN 10005
9980 LET B = 2 ^ (H - 1)
9985 IF INT(G / B) - 2 * INT(G / (2 * B)) = 1 THEN 9995
9990 LET G = G + B
9995 LET I = I + 1
10000 GOTO 9965
10005 LET W = -1
10010 IF I > L0 THEN 10215
10015 LET H = POS("0123456789", SEG$(F$, I, I))
10020 IF H = 0 THEN 10055
10025 IF W >= 0 THEN 10035
10030 LET W = 0
10035 IF 10 * W + H - 1 > V9 THEN 10200
10040 LET W = 10 * W + H - 1
10045 LET I = I + 1
10050 GOTO 10010
10055 LET R = -1
10060 IF SEG$(F$, I, I) <> "." THEN 10110
10065 LET R = 0
10070 LET I = I + 1
10075 IF I > L0 THEN 10215
10080 LET H = POS("0123456789", SEG$(F$, I, I))
10085 IF H = 0 THEN 10110
10090 IF 10 * R + H - 1 > V9 THEN 10200
10095 LET R = 10 * R + H - 1
10100 LET I = I + 1
10105 GOTO 10075
10110 LET C$ = SEG$(F$, I, I)
10115 IF POS("diFfEeGgs", C$) = 0 THEN 10200
10120 REM C leaves # with d i s and 0 with s undefined: invalid here (LANGUAGE 11.1)
10125 IF G < 16 THEN 10135
10130 IF POS("dis", C$) > 0 THEN 10200
10135 IF C$ <> "s" THEN 10145
10140 IF INT(G / 8) - 2 * INT(G / 16) = 1 THEN 10200
10145 LET P(0, 0) = P(0, 0) + 1
10150 LET K = P(0, 0)
10155 LET P(K, 0) = 2
10160 LET P(K, 1) = S
10165 LET P(K, 2) = I
10170 LET P(K, 3) = G
10175 LET P(K, 4) = W
10180 LET P(K, 5) = R
10185 LET N = N + 1
10190 LET I = I + 1
10195 GOTO 9855
10200 LET E = 1
10205 LET E$ = SEG$(F$, S, I)
10210 GOTO 10255
10215 LET E = 1
10220 LET E$ = SEG$(F$, S, L0)
10225 GOTO 10255
10230 IF S0 = 0 THEN 10255
10235 LET P(0, 0) = P(0, 0) + 1
10240 LET P(P(0, 0), 0) = 1
10245 LET P(P(0, 0), 1) = S0
10250 LET P(P(0, 0), 2) = L0
10255 SUBEND
