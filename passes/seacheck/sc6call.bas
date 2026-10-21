7730 REM ---- ck_call: call J: a Sea function, a library function, or an error (LANGUAGE 8.1, 10) -----
7735 SUB "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7740 LET G = N(J, 7)
7745 IF N(G, 0) = 30 THEN 7770
7750 IF M(G, 1) = 0 THEN 7820
7755 CALL "tyn": T(), M(G, 1), A$
7760 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", A$, "", "", 1
7765 GOTO 7820
7770 LET R = M(G, 2)
7775 IF R = 0 THEN 7820
7780 IF R < 0 THEN 7800
7785 IF Y(R, 0) <> 1 THEN 7815
7790 CALL "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
7795 GOTO 7820
7800 IF R > -9 THEN 7815
7805 CALL "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
7810 GOTO 7820
7815 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", S$(N(G, 6)), "", "", 1
7820 SUBEND
7825 REM ---- ck_ucall: call J of Sea function R: counts, ref marks and targets, types, aliasing ------
7830 REM (LANGUAGE 8.1, 8.3, 4.2: a ref argument of a var-rule candidate for an f64 parameter is an
7835 REM f64 store, Decision 8)
7840 SUB "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
7845 LET H = N(J, 1)
7850 LET P0 = Y(R, 6)
7855 IF Y(R, 7) = 0 THEN 7870
7860 LET M(J, 1) = Y(R, 2)
7865 GOTO 7875
7870 LET M(J, 1) = 1
7875 IF H <= P0 THEN 7890
7880 CALL "er": N(), X(), X$(), J, "TOO_MANY_ARGS", "", "", "", 0
7885 GOTO 7900
7890 IF H = P0 THEN 7900
7895 CALL "er": N(), X(), X$(), J, "MISSING_ARG", "", "", "", 0
7900 LET A = N(N(J, 7), 8)
7905 LET P = N(Y(R, 3), 7)
7910 FOR I = 1 TO H
7915 IF I > P0 THEN 8095
7920 LET D = M(P, 1)
7925 LET K = N(A, 0)
7930 IF K = 36 THEN 8100
7935 IF N(P, 1) = 1 THEN 7970
7940 REM an ordinary parameter
7945 IF K <> 37 THEN 7960
7950 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", S$(N(P, 6)), "", "", 1
7955 GOTO 8100
7960 CALL "cv": N(), M(), T(), C(), X(), X$(), A, D
7965 GOTO 8100
7970 REM a ref parameter: the argument says ref and is a var, or a ref parameter of the caller
7975 IF K = 37 THEN 7990
7980 CALL "er": N(), X(), X$(), A, "REF_NEEDED", S$(N(P, 6)), "", "", 1
7985 GOTO 8100
7990 LET G = N(A, 7)
7995 IF M(G, 1) = 0 THEN 8100
8000 IF N(G, 0) <> 30 THEN 8030
8005 LET S = M(G, 2)
8010 IF S <= 0 THEN 8030
8015 IF Y(S, 0) <> 4 THEN 8030
8020 IF Y(S, 4) = 2 THEN 8040
8025 IF Y(S, 4) = 5 THEN 8040
8030 CALL "er": N(), X(), X$(), A, "REF_TARGET", "", "", "", 0
8035 GOTO 8100
8040 IF D = 0 THEN 8100
8045 IF M(G, 1) = D THEN 8100
8050 IF Y(S, 6) = 0 THEN 8075
8055 IF D <> 4 THEN 8075
8060 IF M(G, 1) <> 3 THEN 8075
8065 CALL "cand": M(), Y(), X(), S
8070 GOTO 8100
8075 CALL "tyn": T(), D, A$
8080 CALL "tyn": T(), M(G, 1), B$
8085 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
8090 GOTO 8100
8095 CALL "fin": N(), M(), C(), X(), X$(), A
8100 LET A = N(A, 8)
8105 LET P = N(P, 8)
8110 NEXT I
8115 REM a ref argument must not share its root variable with another argument (LANGUAGE 8.3)
8120 LET A = N(N(J, 7), 8)
8125 FOR I = 1 TO H
8130 IF N(A, 0) <> 37 THEN 8190
8135 CALL "root": N(), M(), Y(), A, S
8140 IF S = 0 THEN 8190
8145 LET B = N(N(J, 7), 8)
8150 IF B = 0 THEN 8190
8155 IF B = A THEN 8180
8160 CALL "root": N(), M(), Y(), B, S1
8165 IF S1 <> S THEN 8180
8170 CALL "er": N(), X(), X$(), A, "REF_ALIAS", "", "", "", 0
8175 GOTO 8200
8180 LET B = N(B, 8)
8185 GOTO 8150
8190 LET A = N(A, 8)
8195 NEXT I
8200 SUBEND
8205 REM ---- root: S = the local at the root of argument A (a name, or ref of a name), else 0 --------
8210 SUB "root": N(), M(), Y(), A, S
8215 LET S = 0
8220 LET G = A
8225 IF N(G, 0) <> 37 THEN 8235
8230 LET G = N(G, 7)
8235 IF N(G, 0) <> 30 THEN 8255
8240 IF M(G, 2) <= 0 THEN 8255
8245 IF Y(M(G, 2), 0) <> 4 THEN 8255
8250 LET S = M(G, 2)
8255 SUBEND
8260 REM ---- ck_lib: call J of a library function: phase 1 has printf, now, idiv (f64 and i64 are
8265 REM conv nodes); any other is 'not supported yet: <name>' at the call (DESIGN 2.6.2) ---------
8270 SUB "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
8275 LET L$ = S$(N(N(J, 7), 6))
8280 LET H = N(J, 1)
8285 IF LEN(L$) <> 6 THEN 8305
8290 IF L$ <> "printf" THEN 8305
8295 CALL "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
8300 GOTO 8525
8305 LET Z = 0
8310 IF LEN(L$) <> 3 THEN 8335
8315 IF L$ <> "now" THEN 8335
8320 LET Z = 1
8325 LET D = 4
8330 GOTO 8370
8335 IF LEN(L$) <> 4 THEN 8360
8340 IF L$ <> "idiv" THEN 8360
8345 LET Z = 2
8350 LET D = 3
8355 GOTO 8370
8360 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", L$, "", "", 1
8365 GOTO 8525
8370 REM the arguments: untyped constants are i64; the overload is now() or idiv(i64, i64)
8375 LET B$ = ""
8380 LET E = 0
8385 LET F = 0
8390 LET A = N(N(J, 7), 8)
8395 FOR I = 1 TO H
8400 IF N(A, 0) <> 37 THEN 8420
8405 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", L$, "", "", 1
8410 LET E = 1
8415 GOTO 8475
8420 CALL "vu": N(), M(), T(), X(), X$(), A, V
8425 CALL "fin": N(), M(), C(), X(), X$(), A
8430 IF V = 0 THEN 8440
8435 IF M(A, 1) = 3 THEN 8445
8440 LET F = 1
8445 IF V <> 0 THEN 8455
8450 LET E = 1
8455 CALL "tyn": T(), M(A, 1), A$
8460 IF I = 1 THEN 8470
8465 LET B$ = B$ & ", "
8470 LET B$ = B$ & A$
8475 LET A = N(A, 8)
8480 NEXT I
8485 LET M(J, 1) = D
8490 IF E = 1 THEN 8525
8495 IF Z = 2 THEN 8510
8500 IF H = 0 THEN 8525
8505 GOTO 8520
8510 IF H <> 2 THEN 8520
8515 IF F = 0 THEN 8525
8520 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", L$, B$, "", 2
8525 SUBEND
8530 REM ---- ck_printf: printf(format, args...) (LANGUAGE 11.1; DESIGN 2.6.2 "Within one formatting
8535 REM call"): an argument's own errors first, then the format literal, its conversions, the
8540 REM argument count, and each argument against its conversion ------------------------------
8545 SUB "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
8550 DIM P(4100, 6)
8555 LET M(J, 1) = 1
8560 LET H = N(J, 1)
8565 LET G = N(J, 7)
8570 LET M(G, 8) = -J
8575 IF H > 0 THEN 8590
8580 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", "printf", "", "", 2
8585 GOTO 8865
8590 LET F = N(G, 8)
8595 LET Z = 0
8600 IF N(F, 0) <> 27 THEN 8615
8605 LET Z = 1
8610 CALL "fmtp": S$(N(F, 6)), P(), N0, E, E$
8615 REM every argument: no ref, one value; untyped constants are f64 under f F e E g G, else i64
8620 LET A = N(F, 8)
8625 FOR I = 1 TO H - 1
8630 IF N(A, 0) <> 37 THEN 8645
8635 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", "printf", "", "", 1
8640 GOTO 8700
8645 CALL "vu": N(), M(), T(), X(), X$(), A, V
8650 IF V <> -1 THEN 8700
8655 LET D = 3
8660 IF Z = 0 THEN 8695
8665 IF E = 1 THEN 8695
8670 IF I > N0 THEN 8695
8675 CALL "fmtc": P(), I, Q
8680 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
8685 IF POS("fFeEgG", C$) = 0 THEN 8695
8690 LET D = 4
8695 CALL "stl": N(), M(), C(), X(), X$(), A, D
8700 LET A = N(A, 8)
8705 NEXT I
8710 IF X(9) > M(M(J, 0), 3) THEN 8865
8715 IF Z = 1 THEN 8735
8720 IF M(F, 1) = 0 THEN 8865
8725 CALL "er": N(), X(), X$(), F, "FORMAT_LITERAL", "", "", "", 0
8730 GOTO 8865
8735 IF E = 0 THEN 8755
8740 CALL "resc": E$, A$
8745 CALL "er": N(), X(), X$(), F, "FORMAT_BAD", A$, "", "", 1
8750 GOTO 8865
8755 IF N0 = H - 1 THEN 8775
8760 CALL "resc": S$(N(F, 6)), A$
8765 CALL "er": N(), X(), X$(), J, "FORMAT_COUNT", A$, STR$(N0), STR$(H - 1), 3
8770 GOTO 8865
8775 LET A = N(F, 8)
8780 FOR I = 1 TO H - 1
8785 CALL "fmtc": P(), I, Q
8790 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
8795 LET V = M(A, 1)
8800 IF C$ = "s" THEN 8835
8805 IF V = 3 THEN 8855
8810 IF V = 4 THEN 8855
8815 IF V <> 2 THEN 8825
8820 IF POS("di", C$) > 0 THEN 8855
8825 LET B$ = "an integer or f64"
8830 GOTO 8845
8835 IF V = 5 THEN 8855
8840 LET B$ = "str"
8845 CALL "tyn": T(), V, C$
8850 CALL "er": N(), X(), X$(), A, "FORMAT_ARG", SEG$(S$(N(F, 6)), P(Q, 1), P(Q, 2)), B$, C$, 3
8855 LET A = N(A, 8)
8860 NEXT I
8865 SUBEND
8870 REM ---- fmtc: Q = the piece of the I-th conversion of a parsed format P ------------------------
8875 SUB "fmtc": P(), I, Q
8880 LET K = 0
8885 FOR Q = 1 TO P(0, 0)
8890 IF P(Q, 0) <> 2 THEN 8905
8895 LET K = K + 1
8900 IF K = I THEN 8915
8905 NEXT Q
8910 LET Q = 0
8915 SUBEND
8920 REM ---- fmtp: parse format F$ (LANGUAGE 11.1) into pieces P(1..P(0,0)): P(k,0) 1 text (bytes
8925 REM P(k,1)..P(k,2), %% not yet collapsed) or 2 conversion (P(k,1) the %, P(k,2) the letter,
8930 REM P(k,3) flags: 1 '-' 2 '+' 4 ' ' 8 '0' 16 '#', P(k,4) width, P(k,5) precision, -1 absent);
8935 REM N = conversions; E = 1 and E$ = the invalid conversion from its % through the byte that
8940 REM makes it invalid (or the end of the format) ------------------------------------------
8945 SUB "fmtp": F$, P(), N, E, E$
8950 LET P(0, 0) = 0
8955 LET N = 0
8960 LET E = 0
8965 LET E$ = ""
8970 LET L0 = LEN(F$)
8975 LET I = 1
8980 LET S0 = 0
8985 IF I > L0 THEN 9380
8990 IF SEG$(F$, I, I) = "%" THEN 9015
8995 IF S0 > 0 THEN 9005
9000 LET S0 = I
9005 LET I = I + 1
9010 GOTO 8985
9015 IF I = L0 THEN 9045
9020 IF SEG$(F$, I + 1, I + 1) <> "%" THEN 9045
9025 IF S0 > 0 THEN 9035
9030 LET S0 = I
9035 LET I = I + 2
9040 GOTO 8985
9045 REM a conversion: the text before it is one piece
9050 IF S0 = 0 THEN 9080
9055 LET P(0, 0) = P(0, 0) + 1
9060 LET P(P(0, 0), 0) = 1
9065 LET P(P(0, 0), 1) = S0
9070 LET P(P(0, 0), 2) = I - 1
9075 LET S0 = 0
9080 LET S = I
9085 LET G = 0
9090 LET I = I + 1
9095 IF I > L0 THEN 9365
9100 LET H = POS("-+ 0#", SEG$(F$, I, I))
9105 IF H = 0 THEN 9135
9110 LET B = 2 ^ (H - 1)
9115 IF INT(G / B) - 2 * INT(G / (2 * B)) = 1 THEN 9125
9120 LET G = G + B
9125 LET I = I + 1
9130 GOTO 9095
9135 LET W = -1
9140 LET D = 0
9145 IF I > L0 THEN 9365
9150 LET H = POS("0123456789", SEG$(F$, I, I))
9155 IF H = 0 THEN 9195
9160 LET D = D + 1
9165 IF D > 9 THEN 9350
9170 IF W >= 0 THEN 9180
9175 LET W = 0
9180 LET W = 10 * W + H - 1
9185 LET I = I + 1
9190 GOTO 9145
9195 LET R = -1
9200 IF SEG$(F$, I, I) <> "." THEN 9260
9205 LET R = 0
9210 LET D = 0
9215 LET I = I + 1
9220 IF I > L0 THEN 9365
9225 LET H = POS("0123456789", SEG$(F$, I, I))
9230 IF H = 0 THEN 9260
9235 LET D = D + 1
9240 IF D > 9 THEN 9350
9245 LET R = 10 * R + H - 1
9250 LET I = I + 1
9255 GOTO 9220
9260 LET C$ = SEG$(F$, I, I)
9265 IF POS("diFfEeGgs", C$) = 0 THEN 9350
9270 REM C leaves # with d i s and 0 with s undefined: invalid here (LANGUAGE 11.1)
9275 IF G < 16 THEN 9285
9280 IF POS("dis", C$) > 0 THEN 9350
9285 IF C$ <> "s" THEN 9295
9290 IF INT(G / 8) - 2 * INT(G / 16) = 1 THEN 9350
9295 LET P(0, 0) = P(0, 0) + 1
9300 LET K = P(0, 0)
9305 LET P(K, 0) = 2
9310 LET P(K, 1) = S
9315 LET P(K, 2) = I
9320 LET P(K, 3) = G
9325 LET P(K, 4) = W
9330 LET P(K, 5) = R
9335 LET N = N + 1
9340 LET I = I + 1
9345 GOTO 8985
9350 LET E = 1
9355 LET E$ = SEG$(F$, S, I)
9360 GOTO 9405
9365 LET E = 1
9370 LET E$ = SEG$(F$, S, L0)
9375 GOTO 9405
9380 IF S0 = 0 THEN 9405
9385 LET P(0, 0) = P(0, 0) + 1
9390 LET P(P(0, 0), 0) = 1
9395 LET P(P(0, 0), 1) = S0
9400 LET P(P(0, 0), 2) = L0
9405 SUBEND
