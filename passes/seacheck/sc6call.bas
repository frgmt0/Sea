10620 REM ---- ck_call: call J: a Sea function, a library function, or an error (LANGUAGE 8.1, 10) -----
10625 SUB "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
10630 LET G = N(J, 7)
10635 IF N(G, 0) = 30 THEN 10660
10640 IF M(G, 1) = 0 THEN 10710
10645 CALL "tyn": T(), M(G, 1), A$
10650 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", A$, "", "", 1
10655 GOTO 10710
10660 LET R = M(G, 2)
10665 IF R = 0 THEN 10710
10670 IF R < 0 THEN 10690
10675 IF Y(R, 0) <> 1 THEN 10705
10680 CALL "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
10685 GOTO 10710
10690 IF R > -9 THEN 10705
10695 CALL "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
10700 GOTO 10710
10705 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", S$(N(G, 6)), "", "", 1
10710 SUBEND
10715 REM ---- ck_ucall: call J of Sea function R: counts, ref marks and targets, types, aliasing ------
10720 REM (LANGUAGE 8.1, 8.3, 4.2: a ref argument of a var-rule candidate for an f64 parameter is an
10725 REM f64 store, Decision 8)
10730 SUB "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
10735 LET H = N(J, 1)
10740 LET P0 = Y(R, 6)
10745 IF Y(R, 7) = 0 THEN 10760
10750 LET M(J, 1) = Y(R, 2)
10755 GOTO 10765
10760 LET M(J, 1) = 1
10765 IF H <= P0 THEN 10780
10770 CALL "er": N(), X(), X$(), J, "TOO_MANY_ARGS", "", "", "", 0
10775 GOTO 10790
10780 IF H = P0 THEN 10790
10785 CALL "er": N(), X(), X$(), J, "MISSING_ARG", "", "", "", 0
10790 LET A = N(N(J, 7), 8)
10795 LET P = N(Y(R, 3), 7)
10800 FOR I = 1 TO H
10805 IF I > P0 THEN 11005
10810 LET D = M(P, 1)
10815 LET K = N(A, 0)
10820 IF K = 36 THEN 11010
10825 IF N(P, 1) = 1 THEN 10860
10830 REM an ordinary parameter
10835 IF K <> 37 THEN 10850
10840 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", S$(N(P, 6)), "", "", 1
10845 GOTO 11010
10850 CALL "cv": N(), M(), T(), C(), X(), X$(), A, D
10855 GOTO 11010
10860 REM a ref parameter: the argument says ref and is a var, or a ref parameter of the caller
10865 IF K = 37 THEN 10880
10870 CALL "er": N(), X(), X$(), A, "REF_NEEDED", S$(N(P, 6)), "", "", 1
10875 GOTO 11010
10880 LET G = N(A, 7)
10885 IF N(G, 0) = 30 THEN 10900
10890 IF M(G, 1) = 0 THEN 11010
10895 GOTO 10940
10900 REM a name: undeclared (reported at the name), else it must be a var or a ref parameter;
10905 REM a function, struct, constant, predeclared name or handle type is no ref target
10910 LET S = M(G, 2)
10915 IF S = 0 THEN 11010
10920 IF S < 0 THEN 10940
10925 IF Y(S, 0) <> 4 THEN 10940
10930 IF Y(S, 4) = 2 THEN 10950
10935 IF Y(S, 4) = 5 THEN 10950
10940 CALL "er": N(), X(), X$(), A, "REF_TARGET", "", "", "", 0
10945 GOTO 11010
10950 IF D = 0 THEN 11010
10955 IF M(G, 1) = D THEN 11010
10960 IF Y(S, 6) = 0 THEN 10985
10965 IF D <> 4 THEN 10985
10970 IF M(G, 1) <> 3 THEN 10985
10975 CALL "cand": M(), Y(), X(), S
10980 GOTO 11010
10985 CALL "tyn": T(), D, A$
10990 CALL "tyn": T(), M(G, 1), B$
10995 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
11000 GOTO 11010
11005 CALL "fin": N(), M(), C(), X(), X$(), A
11010 LET A = N(A, 8)
11015 LET P = N(P, 8)
11020 NEXT I
11025 REM a ref argument must not share its root variable with another argument (LANGUAGE 8.3)
11030 LET A = N(N(J, 7), 8)
11035 FOR I = 1 TO H
11040 IF N(A, 0) <> 37 THEN 11100
11045 CALL "root": N(), M(), Y(), A, S
11050 IF S = 0 THEN 11100
11055 LET B = N(N(J, 7), 8)
11060 IF B = 0 THEN 11100
11065 IF B = A THEN 11090
11070 CALL "root": N(), M(), Y(), B, S1
11075 IF S1 <> S THEN 11090
11080 CALL "er": N(), X(), X$(), A, "REF_ALIAS", "", "", "", 0
11085 GOTO 11110
11090 LET B = N(B, 8)
11095 GOTO 11060
11100 LET A = N(A, 8)
11105 NEXT I
11110 SUBEND
11115 REM ---- root: S = the local at the root of argument A (a name, or ref of a name), else 0 --------
11120 SUB "root": N(), M(), Y(), A, S
11125 LET S = 0
11130 LET G = A
11135 IF N(G, 0) <> 37 THEN 11145
11140 LET G = N(G, 7)
11145 IF N(G, 0) <> 30 THEN 11165
11150 IF M(G, 2) <= 0 THEN 11165
11155 IF Y(M(G, 2), 0) <> 4 THEN 11165
11160 LET S = M(G, 2)
11165 SUBEND
11170 REM ---- ck_lib: call J of a library function: printf, now, idiv (f64 and i64 are conv nodes),
11175 REM from phase 3 log exp sin cos pow hypot (DESIGN 4.10.5); any other is 'not supported yet:
11180 REM <name>' at the call (DESIGN 2.6.2) -----------------------------------------------------
11185 SUB "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
11190 LET L$ = S$(N(N(J, 7), 6))
11195 LET H = N(J, 1)
11200 IF LEN(L$) <> 6 THEN 11220
11205 IF L$ <> "printf" THEN 11220
11210 CALL "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
11215 GOTO 11555
11220 LET Z = 0
11225 IF LEN(L$) <> 3 THEN 11250
11230 IF L$ <> "now" THEN 11250
11235 LET Z = 1
11240 LET D = 4
11245 GOTO 11330
11250 IF LEN(L$) <> 4 THEN 11275
11255 IF L$ <> "idiv" THEN 11275
11260 LET Z = 2
11265 LET D = 3
11270 GOTO 11330
11275 REM log exp sin cos (f64) -> f64, pow hypot (f64, f64) -> f64: N9 arguments
11280 LET Z = POS("|log |exp |sin |cos |pow |hypot ", "|" & L$ & " ")
11285 IF Z = 0 THEN 11320
11290 LET N9 = 1
11295 IF Z < 20 THEN 11305
11300 LET N9 = 2
11305 LET Z = 3
11310 LET D = 4
11315 GOTO 11330
11320 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", L$, "", "", 1
11325 GOTO 11555
11330 REM the arguments: untyped constants are i64 (f64 for an elementary function, whose i64
11335 REM arguments are converted: LANGUAGE 4.2); the overload is now(), idiv(i64, i64) or f64s
11340 LET B$ = ""
11345 LET E = 0
11350 LET F = 0
11355 LET A = N(N(J, 7), 8)
11360 FOR I = 1 TO H
11365 IF N(A, 0) <> 37 THEN 11385
11370 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", L$, "", "", 1
11375 LET E = 1
11380 GOTO 11485
11385 CALL "vu": N(), M(), T(), X(), X$(), A, V
11390 IF Z = 3 THEN 11420
11395 CALL "fin": N(), M(), C(), X(), X$(), A
11400 IF V = 0 THEN 11410
11405 IF M(A, 1) = 3 THEN 11455
11410 LET F = 1
11415 GOTO 11455
11420 IF V <> -1 THEN 11435
11425 CALL "stl": N(), M(), C(), X(), X$(), A, 4
11430 GOTO 11465
11435 IF V = 4 THEN 11465
11440 IF V <> 3 THEN 11410
11445 LET M(A, 7) = 1
11450 GOTO 11465
11455 IF V <> 0 THEN 11465
11460 LET E = 1
11465 CALL "tyn": T(), M(A, 1), A$
11470 IF I = 1 THEN 11480
11475 LET B$ = B$ & ", "
11480 LET B$ = B$ & A$
11485 LET A = N(A, 8)
11490 NEXT I
11495 LET M(J, 1) = D
11500 IF E = 1 THEN 11555
11505 IF Z = 2 THEN 11540
11510 IF Z = 3 THEN 11525
11515 IF H = 0 THEN 11555
11520 GOTO 11550
11525 IF H <> N9 THEN 11550
11530 IF F = 0 THEN 11555
11535 GOTO 11550
11540 IF H <> 2 THEN 11550
11545 IF F = 0 THEN 11555
11550 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", L$, B$, "", 2
11555 SUBEND
11560 REM ---- ck_printf: printf(format, args...) (LANGUAGE 11.1; DESIGN 2.6.2 "Within one formatting
11565 REM call"): an argument's own errors first, then the format literal, its conversions, the
11570 REM argument count, and each argument against its conversion ------------------------------
11575 SUB "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
11580 DIM P(4100, 6)
11585 LET M(J, 1) = 1
11590 LET H = N(J, 1)
11595 LET G = N(J, 7)
11600 LET M(G, 8) = -J
11605 IF H > 0 THEN 11620
11610 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", "printf", "", "", 2
11615 GOTO 11905
11620 LET F = N(G, 8)
11625 LET Z = 0
11630 IF N(F, 0) <> 27 THEN 11645
11635 LET Z = 1
11640 CALL "fmtp": S$(N(F, 6)), P(), N0, E, E$, X(35)
11645 REM every argument: no ref, one value; untyped constants are f64 under f F e E g G, else i64
11650 LET A = N(F, 8)
11655 FOR I = 1 TO H - 1
11660 IF N(A, 0) <> 37 THEN 11675
11665 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", "printf", "", "", 1
11670 GOTO 11730
11675 CALL "vu": N(), M(), T(), X(), X$(), A, V
11680 IF V <> -1 THEN 11730
11685 LET D = 3
11690 IF Z = 0 THEN 11725
11695 IF E = 1 THEN 11725
11700 IF I > N0 THEN 11725
11705 CALL "fmtc": P(), I, Q
11710 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
11715 IF POS("fFeEgG", C$) = 0 THEN 11725
11720 LET D = 4
11725 CALL "stl": N(), M(), C(), X(), X$(), A, D
11730 LET A = N(A, 8)
11735 NEXT I
11740 IF X(9) > M(M(J, 0), 3) THEN 11905
11745 IF Z = 1 THEN 11765
11750 IF M(F, 1) = 0 THEN 11905
11755 CALL "er": N(), X(), X$(), F, "FORMAT_LITERAL", "", "", "", 0
11760 GOTO 11905
11765 IF E = 0 THEN 11785
11770 CALL "resc": E$, A$
11775 CALL "er": N(), X(), X$(), F, "FORMAT_BAD", A$, "", "", 1
11780 GOTO 11905
11785 IF N0 = H - 1 THEN 11805
11790 CALL "resc": S$(N(F, 6)), A$
11795 CALL "er": N(), X(), X$(), J, "FORMAT_COUNT", A$, STR$(N0), STR$(H - 1), 3
11800 GOTO 11905
11805 LET A = N(F, 8)
11810 FOR I = 1 TO H - 1
11815 CALL "fmtc": P(), I, Q
11820 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
11825 LET V = M(A, 1)
11830 REM an argument of error type (0: a failed constant, reported at its declaration) is settled
11835 IF V = 0 THEN 11895
11840 IF C$ = "s" THEN 11875
11845 IF V = 3 THEN 11895
11850 IF V = 4 THEN 11895
11855 IF V <> 2 THEN 11865
11860 IF POS("di", C$) > 0 THEN 11895
11865 LET B$ = "an integer or f64"
11870 GOTO 11885
11875 IF V = 5 THEN 11895
11880 LET B$ = "str"
11885 CALL "tyn": T(), V, C$
11890 CALL "er": N(), X(), X$(), A, "FORMAT_ARG", SEG$(S$(N(F, 6)), P(Q, 1), P(Q, 2)), B$, C$, 3
11895 LET A = N(A, 8)
11900 NEXT I
11905 SUBEND
11910 REM ---- fmtc: Q = the piece of the I-th conversion of a parsed format P ------------------------
11915 SUB "fmtc": P(), I, Q
11920 LET K = 0
11925 FOR Q = 1 TO P(0, 0)
11930 IF P(Q, 0) <> 2 THEN 11945
11935 LET K = K + 1
11940 IF K = I THEN 11955
11945 NEXT Q
11950 LET Q = 0
11955 SUBEND
11960 REM ---- fmtp: parse format F$ (LANGUAGE 11.1) into pieces P(1..P(0,0)): P(k,0) 1 text (bytes
11965 REM P(k,1)..P(k,2), %% not yet collapsed) or 2 conversion (P(k,1) the %, P(k,2) the letter,
11970 REM P(k,3) flags: 1 '-' 2 '+' 4 ' ' 8 '0' 16 '#', P(k,4) width, P(k,5) precision, -1 absent);
11975 REM N = conversions; E = 1 and E$ = the invalid conversion from its % through the byte that
11980 REM makes it invalid (or the end of the format); width and precision are at most V9 by value
11985 SUB "fmtp": F$, P(), N, E, E$, V9
11990 LET P(0, 0) = 0
11995 LET N = 0
12000 LET E = 0
12005 LET E$ = ""
12010 LET L0 = LEN(F$)
12015 LET I = 1
12020 LET S0 = 0
12025 IF I > L0 THEN 12400
12030 IF SEG$(F$, I, I) = "%" THEN 12055
12035 IF S0 > 0 THEN 12045
12040 LET S0 = I
12045 LET I = I + 1
12050 GOTO 12025
12055 IF I = L0 THEN 12085
12060 IF SEG$(F$, I + 1, I + 1) <> "%" THEN 12085
12065 IF S0 > 0 THEN 12075
12070 LET S0 = I
12075 LET I = I + 2
12080 GOTO 12025
12085 REM a conversion: the text before it is one piece
12090 IF S0 = 0 THEN 12120
12095 LET P(0, 0) = P(0, 0) + 1
12100 LET P(P(0, 0), 0) = 1
12105 LET P(P(0, 0), 1) = S0
12110 LET P(P(0, 0), 2) = I - 1
12115 LET S0 = 0
12120 LET S = I
12125 LET G = 0
12130 LET I = I + 1
12135 IF I > L0 THEN 12385
12140 LET H = POS("-+ 0#", SEG$(F$, I, I))
12145 IF H = 0 THEN 12175
12150 LET B = 2 ^ (H - 1)
12155 IF INT(G / B) - 2 * INT(G / (2 * B)) = 1 THEN 12165
12160 LET G = G + B
12165 LET I = I + 1
12170 GOTO 12135
12175 LET W = -1
12180 IF I > L0 THEN 12385
12185 LET H = POS("0123456789", SEG$(F$, I, I))
12190 IF H = 0 THEN 12225
12195 IF W >= 0 THEN 12205
12200 LET W = 0
12205 IF 10 * W + H - 1 > V9 THEN 12370
12210 LET W = 10 * W + H - 1
12215 LET I = I + 1
12220 GOTO 12180
12225 LET R = -1
12230 IF SEG$(F$, I, I) <> "." THEN 12280
12235 LET R = 0
12240 LET I = I + 1
12245 IF I > L0 THEN 12385
12250 LET H = POS("0123456789", SEG$(F$, I, I))
12255 IF H = 0 THEN 12280
12260 IF 10 * R + H - 1 > V9 THEN 12370
12265 LET R = 10 * R + H - 1
12270 LET I = I + 1
12275 GOTO 12245
12280 LET C$ = SEG$(F$, I, I)
12285 IF POS("diFfEeGgs", C$) = 0 THEN 12370
12290 REM C leaves # with d i s and 0 with s undefined: invalid here (LANGUAGE 11.1)
12295 IF G < 16 THEN 12305
12300 IF POS("dis", C$) > 0 THEN 12370
12305 IF C$ <> "s" THEN 12315
12310 IF INT(G / 8) - 2 * INT(G / 16) = 1 THEN 12370
12315 LET P(0, 0) = P(0, 0) + 1
12320 LET K = P(0, 0)
12325 LET P(K, 0) = 2
12330 LET P(K, 1) = S
12335 LET P(K, 2) = I
12340 LET P(K, 3) = G
12345 LET P(K, 4) = W
12350 LET P(K, 5) = R
12355 LET N = N + 1
12360 LET I = I + 1
12365 GOTO 12025
12370 LET E = 1
12375 LET E$ = SEG$(F$, S, I)
12380 GOTO 12425
12385 LET E = 1
12390 LET E$ = SEG$(F$, S, L0)
12395 GOTO 12425
12400 IF S0 = 0 THEN 12425
12405 LET P(0, 0) = P(0, 0) + 1
12410 LET P(P(0, 0), 0) = 1
12415 LET P(P(0, 0), 1) = S0
12420 LET P(P(0, 0), 2) = L0
12425 SUBEND
