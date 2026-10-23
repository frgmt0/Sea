11855 REM ---- ck_call: call J: a Sea function, a library function, or an error (LANGUAGE 8.1, 10) -----
11860 SUB "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
11865 LET G = N(J, 7)
11870 IF N(G, 0) = 30 THEN 11895
11875 IF M(G, 1) = 0 THEN 11945
11880 CALL "tyn": T(), M(G, 1), A$
11885 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", A$, "", "", 1
11890 GOTO 11945
11895 LET R = M(G, 2)
11900 IF R = 0 THEN 11945
11905 IF R < 0 THEN 11925
11910 IF Y(R, 0) <> 1 THEN 11940
11915 CALL "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
11920 GOTO 11945
11925 IF R > -9 THEN 11940
11930 CALL "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
11935 GOTO 11945
11940 CALL "er": N(), X(), X$(), J, "NOT_FUNCTION", S$(N(G, 6)), "", "", 1
11945 SUBEND
11950 REM ---- ck_ucall: call J of Sea function R: counts, ref marks and targets, types, aliasing ------
11955 REM (LANGUAGE 8.1, 8.3, 4.2: a ref argument of a var-rule candidate for an f64 parameter is an
11960 REM f64 store, Decision 8)
11965 SUB "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
11970 LET H = N(J, 1)
11975 LET P0 = Y(R, 6)
11980 IF Y(R, 7) = 0 THEN 11995
11985 LET M(J, 1) = Y(R, 2)
11990 GOTO 12000
11995 LET M(J, 1) = 1
12000 IF H <= P0 THEN 12015
12005 CALL "er": N(), X(), X$(), J, "TOO_MANY_ARGS", "", "", "", 0
12010 GOTO 12025
12015 IF H = P0 THEN 12025
12020 CALL "er": N(), X(), X$(), J, "MISSING_ARG", "", "", "", 0
12025 LET A = N(N(J, 7), 8)
12030 LET P = N(Y(R, 3), 7)
12035 FOR I = 1 TO H
12040 IF I > P0 THEN 12320
12045 LET D = M(P, 1)
12050 LET K = N(A, 0)
12055 IF K = 36 THEN 12325
12060 IF N(P, 1) = 1 THEN 12095
12065 REM an ordinary parameter
12070 IF K <> 37 THEN 12085
12075 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", S$(N(P, 6)), "", "", 1
12080 GOTO 12325
12085 CALL "cv": N(), M(), T(), C(), X(), X$(), A, D
12090 GOTO 12325
12095 REM a ref parameter: the argument says ref and is a var, or a ref parameter of the caller
12100 IF K = 37 THEN 12115
12105 CALL "er": N(), X(), X$(), A, "REF_NEEDED", S$(N(P, 6)), "", "", 1
12110 GOTO 12325
12115 LET G = N(A, 7)
12120 LET B = G
12125 IF N(G, 0) = 30 THEN 12210
12130 IF N(G, 0) = 39 THEN 12145
12135 IF M(G, 1) = 0 THEN 12325
12140 GOTO 12250
12145 REM an element of a var or ref parameter; a selection (a range, :, an index vector or a mask)
12150 REM is no ref target (LANGUAGE 8.3)
12155 LET Q = N(N(G, 7), 8)
12160 IF Q = 0 THEN 12195
12165 IF N(Q, 0) = 40 THEN 12250
12170 IF N(Q, 0) = 41 THEN 12250
12175 CALL "elt": T(), M(Q, 1), E9, K9
12180 IF K9 > 0 THEN 12250
12185 LET Q = N(Q, 8)
12190 GOTO 12160
12195 IF M(G, 1) = 0 THEN 12325
12200 LET B = N(G, 7)
12205 IF N(B, 0) <> 30 THEN 12250
12210 REM a name: undeclared (reported at the name), else it must be a var or a ref parameter;
12215 REM a function, struct, constant, predeclared name or handle type is no ref target
12220 LET S = M(B, 2)
12225 IF S = 0 THEN 12325
12230 IF S < 0 THEN 12250
12235 IF Y(S, 0) <> 4 THEN 12250
12240 IF Y(S, 4) = 2 THEN 12260
12245 IF Y(S, 4) = 5 THEN 12260
12250 CALL "er": N(), X(), X$(), A, "REF_TARGET", "", "", "", 0
12255 GOTO 12325
12260 IF D = 0 THEN 12325
12265 IF M(G, 1) = D THEN 12325
12270 IF B <> G THEN 12300
12275 IF Y(S, 6) = 0 THEN 12300
12280 IF D <> 4 THEN 12300
12285 IF M(G, 1) <> 3 THEN 12300
12290 CALL "cand": M(), Y(), X(), S
12295 GOTO 12325
12300 CALL "tyn": T(), D, A$
12305 CALL "tyn": T(), M(G, 1), B$
12310 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
12315 GOTO 12325
12320 CALL "fin": N(), M(), C(), X(), X$(), A
12325 LET A = N(A, 8)
12330 LET P = N(P, 8)
12335 NEXT I
12340 REM a ref argument must not share its root variable with another argument (LANGUAGE 8.3)
12345 LET A = N(N(J, 7), 8)
12350 FOR I = 1 TO H
12355 IF N(A, 0) <> 37 THEN 12415
12360 CALL "root": N(), M(), Y(), A, S
12365 IF S = 0 THEN 12415
12370 LET B = N(N(J, 7), 8)
12375 IF B = 0 THEN 12415
12380 IF B = A THEN 12405
12385 CALL "root": N(), M(), Y(), B, S1
12390 IF S1 <> S THEN 12405
12395 CALL "er": N(), X(), X$(), A, "REF_ALIAS", "", "", "", 0
12400 GOTO 12425
12405 LET B = N(B, 8)
12410 GOTO 12375
12415 LET A = N(A, 8)
12420 NEXT I
12425 SUBEND
12430 REM ---- root: S = the local at the root of argument A (a name or an element of one, through
12435 REM every index, or ref of such a path; LANGUAGE 8.3), else 0 --------------------------------
12440 SUB "root": N(), M(), Y(), A, S
12445 LET S = 0
12450 LET G = A
12455 IF N(G, 0) <> 37 THEN 12465
12460 LET G = N(G, 7)
12465 IF N(G, 0) <> 39 THEN 12480
12470 LET G = N(G, 7)
12475 GOTO 12465
12480 IF N(G, 0) <> 30 THEN 12500
12485 IF M(G, 2) <= 0 THEN 12500
12490 IF Y(M(G, 2), 0) <> 4 THEN 12500
12495 LET S = M(G, 2)
12500 SUBEND
12505 REM ---- ck_lib: call J of a library function (LANGUAGE 10): printf (ck_printf), and by class Z
12510 REM 1 now() 2 idiv(i64, i64) 3 log exp sin cos sqrt floor ceil trunc round (f64) 4 isnan(f64)
12515 REM 5 pow hypot (f64, f64) 6 abs sign (i64 | f64) 7 min max (n, n) 8 where(bool, x, x) 9
12520 REM ind2sub(i64, i64) -> (i64, i64) 10 sub2ind(i64, i64, i64) 11 zeros ones (n) | (r, c) 12
12525 REM filled(v, n) | (v, r, c) 13 len (a vector or str) 14 rows cols (a matrix) 15 numel (a
12530 REM vector or matrix); any other is 'not supported yet: <name>' at the call, and so is min or max
12535 REM with one argument (the reduction, 4f; DESIGN 2.6.2). Untyped constants are f64 where f64 is
12540 REM taken (classes 3-5), the other's type in min, max and where, else i64 (LANGUAGE 4.2); an
12545 REM i64 for an f64 is converted. The overload is judged on the element types; array arguments of
12550 REM an elemental function (2-10) are then broadcast (lbc, LANGUAGE 6.3, 10.4, 10.7) ---------
12555 SUB "ck_lib": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
12560 DIM U(9), V(9), K(9)
12565 LET L$ = S$(N(N(J, 7), 6))
12570 LET H = N(J, 1)
12575 IF LEN(L$) <> 6 THEN 12595
12580 IF L$ <> "printf" THEN 12595
12585 CALL "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
12590 GOTO 13610
12595 LET Q$ = "|now 01|idiv 02|log 03|exp 03|sin 03|cos 03|sqrt 03|floor 03|ceil 03|trunc 03|round 03"
12600 LET Q$ = Q$ & "|isnan 04|pow 05|hypot 05|abs 06|sign 06|min 07|max 07|where 08|ind2sub 09"
12605 LET Q$ = Q$ & "|sub2ind 10|zeros 11|ones 11|filled 12|len 13|rows 14|cols 14|numel 15|"
12610 LET P = POS(Q$, "|" & L$ & " ")
12615 IF P = 0 THEN 12635
12620 LET Z = VAL(SEG$(Q$, P + LEN(L$) + 2, P + LEN(L$) + 3))
12625 IF Z <> 7 THEN 12645
12630 IF H <> 1 THEN 12645
12635 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", L$, "", "", 1
12640 GOTO 13610
12645 REM the arguments: no ref, one value each; U(i) the type, V(i) the element type, K(i) the rank
12650 LET E = 0
12655 LET A = N(N(J, 7), 8)
12660 FOR I = 1 TO H
12665 LET Q = 0
12670 IF N(A, 0) <> 37 THEN 12690
12675 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", L$, "", "", 1
12680 LET E = 1
12685 GOTO 12765
12690 CALL "vu": N(), M(), T(), X(), X$(), A, Q
12691 IF Q = 0 THEN 12760
12692 REM an untyped literal passed where f64 is taken (classes 3-5) is f64 (LANGUAGE 4.2 (b))
12693 IF M(A, 4) <> 2 THEN 12700
12694 IF Z < 3 THEN 12700
12696 IF Z > 5 THEN 12700
12697 CALL "rtf": N(), M(), T(), X(), X$(), A
12698 LET Q = M(A, 1)
12700 IF Q <> -1 THEN 12765
12705 IF Z < 3 THEN 12745
12710 IF Z > 5 THEN 12725
12715 CALL "stl": N(), M(), C(), X(), X$(), A, 4
12720 GOTO 12750
12725 REM min, max, where: an untyped constant waits for the other operand
12730 IF Z = 7 THEN 12765
12735 IF Z <> 8 THEN 12745
12740 IF I > 1 THEN 12765
12745 CALL "fin": N(), M(), C(), X(), X$(), A
12750 LET Q = M(A, 1)
12755 GOTO 12765
12760 LET E = 1
12765 IF I > 9 THEN 12775
12770 LET U(I) = Q
12775 LET A = N(A, 8)
12780 NEXT I
12785 REM the waiting untyped constants: of min and max (arguments 1, 2) and where (2, 3) the other
12790 REM one's type when it is f64 (else i64), any other untyped argument i64
12795 LET D1 = 3
12800 IF Z = 7 THEN 12810
12805 IF Z <> 8 THEN 12840
12810 IF H < Z - 5 THEN 12840
12815 FOR I = Z - 6 TO Z - 5
12820 CALL "elt": T(), U(I), Q, Q1
12825 IF Q <> 4 THEN 12835
12830 LET D1 = 4
12835 NEXT I
12840 LET A = N(N(J, 7), 8)
12845 FOR I = 1 TO H
12850 IF M(A, 1) <> -1 THEN 12870
12855 CALL "stl": N(), M(), C(), X(), X$(), A, D1
12860 IF I > 9 THEN 12870
12865 LET U(I) = M(A, 1)
12870 LET A = N(A, 8)
12875 IF I > 9 THEN 12895
12880 CALL "elt": T(), U(I), Q, Q1
12885 LET V(I) = Q
12890 LET K(I) = Q1
12895 NEXT I
12900 LET D = 0
12905 IF E = 0 THEN 12970
12910 REM an argument with an error: the result type when it does not depend on the arguments
12915 LET D = VAL(SEG$("040304020400000000030000030303", 2 * Z - 1, 2 * Z))
12920 IF Z = 9 THEN 12950
12925 IF Z <> 11 THEN 13605
12930 IF H < 1 THEN 13605
12935 IF H > 2 THEN 13605
12940 CALL "tarr": T(), N(), X(), X$(), H, 4, 0, 0, D
12945 GOTO 13605
12950 LET U(1) = 3
12955 LET U(2) = 3
12960 CALL "ttup": T(), N(), X(), X$(), U(), 2, D
12965 GOTO 13605
12970 REM the overload, by class, on the element types: D the result type (0: no overload)
12975 ON Z GOTO 12980, 12990, 13035, 13035, 13070, 13100, 13125, 13165, 12990, 13220, 13250, 13285, 13340, 13360, 13375
12980 IF H = 0 THEN 13395
12985 GOTO 13545
12990 IF H <> 2 THEN 13545
12995 IF V(1) <> 3 THEN 13545
13000 IF V(2) <> 3 THEN 13545
13005 LET D = 3
13010 GOTO 13460
13035 IF H <> 1 THEN 13545
13040 CALL "num": V(1), Q
13045 IF Q = 0 THEN 13545
13050 LET D = 4
13055 IF Z = 3 THEN 13405
13060 LET D = 2
13065 GOTO 13405
13070 IF H <> 2 THEN 13545
13075 CALL "num": V(1), Q
13080 CALL "num": V(2), Q1
13085 IF Q * Q1 = 0 THEN 13545
13090 LET D = 4
13095 GOTO 13405
13100 IF H <> 1 THEN 13545
13105 CALL "num": V(1), Q
13110 IF Q = 0 THEN 13545
13115 LET D = V(1)
13120 GOTO 13460
13125 IF H <> 2 THEN 13545
13130 CALL "num": V(1), Q
13135 CALL "num": V(2), Q1
13140 IF Q * Q1 = 0 THEN 13545
13145 LET D = 3
13150 IF V(1) + V(2) = 6 THEN 13460
13155 LET D = 4
13160 GOTO 13405
13165 IF H <> 3 THEN 13545
13170 IF V(1) <> 2 THEN 13545
13175 LET D = 2
13180 IF V(2) + V(3) = 4 THEN 13460
13185 CALL "num": V(2), Q
13190 CALL "num": V(3), Q1
13195 IF Q * Q1 = 0 THEN 13545
13200 LET D = 3
13205 IF V(2) + V(3) = 6 THEN 13460
13210 LET D = 4
13215 GOTO 13405
13220 IF H <> 3 THEN 13545
13225 FOR I = 1 TO 3
13230 IF V(I) <> 3 THEN 13545
13235 NEXT I
13240 LET D = 3
13245 GOTO 13460
13250 IF H < 1 THEN 13545
13255 IF H > 2 THEN 13545
13260 FOR I = 1 TO H
13265 IF U(I) <> 3 THEN 13545
13270 NEXT I
13275 CALL "tarr": T(), N(), X(), X$(), H, 4, 0, 0, D
13280 GOTO 13605
13285 IF H < 2 THEN 13545
13290 IF H > 3 THEN 13545
13295 FOR I = 2 TO H
13300 IF U(I) <> 3 THEN 13545
13305 NEXT I
13310 IF U(1) < 2 THEN 13545
13315 IF U(1) > 5 THEN 13545
13320 REM a str value is a strings construct, reported where the str comes from (4g)
13325 IF U(1) = 5 THEN 13605
13330 CALL "tarr": T(), N(), X(), X$(), H - 1, U(1), 0, 0, D
13335 GOTO 13605
13340 IF H <> 1 THEN 13545
13345 IF U(1) = 5 THEN 13385
13350 IF K(1) <> 1 THEN 13545
13355 GOTO 13385
13360 IF H <> 1 THEN 13545
13365 IF K(1) <> 2 THEN 13545
13370 GOTO 13385
13375 IF H <> 1 THEN 13545
13380 IF K(1) = 0 THEN 13545
13385 LET D = 3
13390 GOTO 13605
13395 LET D = 4
13400 GOTO 13605
13405 REM an i64 (or i64 elements) where the function takes f64 (classes 3-5, min and max, where) is
13407 REM converted, element by element for an array (acv)
13410 LET A = N(N(J, 7), 8)
13415 FOR I = 1 TO H
13420 IF V(I) <> 3 THEN 13450
13425 IF Z < 7 THEN 13445
13430 IF D <> 4 THEN 13450
13435 IF Z = 7 THEN 13445
13440 IF I = 1 THEN 13450
13445 CALL "acv": N(), M(), T(), X(), X$(), A
13450 LET A = N(A, 8)
13455 NEXT I
13460 REM an elemental function with array arguments: their broadcast (lbc; ind2sub of an array r is
13462 REM the phase-rule word ind2sub)
13465 CALL "lbc": N(), M(), T(), X(), X$(), J, Z, D, U(), K(), H
13540 GOTO 13605
13545 REM no overload: the argument types as written
13550 LET B$ = ""
13555 LET A = N(N(J, 7), 8)
13560 FOR I = 1 TO H
13565 CALL "tyn": T(), M(A, 1), A$
13570 IF I = 1 THEN 13580
13575 LET B$ = B$ & ", "
13580 LET B$ = B$ & A$
13585 LET A = N(A, 8)
13590 NEXT I
13595 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", L$, B$, "", 2
13600 GOTO 12915
13605 LET M(J, 1) = D
13610 SUBEND
13615 REM ---- num: Q = 1 when type V is i64 or f64, else 0 ------------------------------------------
13620 SUB "num": V, Q
13625 LET Q = 0
13630 IF V < 3 THEN 13645
13635 IF V > 4 THEN 13645
13640 LET Q = 1
13645 SUBEND
13650 REM ---- ck_printf: printf(format, args...) (LANGUAGE 11.1; DESIGN 2.6.2 "Within one formatting
13655 REM call"): an argument's own errors first, then the format literal, its conversions, the
13660 REM argument count, and each argument against its conversion ------------------------------
13665 SUB "ck_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
13670 DIM P(4100, 6)
13675 LET M(J, 1) = 1
13680 LET H = N(J, 1)
13685 LET G = N(J, 7)
13690 LET M(G, 8) = -J
13695 IF H > 0 THEN 13710
13700 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", "printf", "", "", 2
13705 GOTO 13995
13710 LET F = N(G, 8)
13715 LET Z = 0
13720 IF N(F, 0) <> 27 THEN 13735
13725 LET Z = 1
13730 CALL "fmtp": S$(N(F, 6)), P(), N0, E, E$, X(35)
13735 REM every argument: no ref, one value; untyped constants are f64 under f F e E g G, else i64
13740 LET A = N(F, 8)
13745 FOR I = 1 TO H - 1
13750 IF N(A, 0) <> 37 THEN 13765
13755 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", "printf", "", "", 1
13760 GOTO 13820
13765 CALL "vu": N(), M(), T(), X(), X$(), A, V
13770 IF V <> -1 THEN 13820
13775 LET D = 3
13780 IF Z = 0 THEN 13815
13785 IF E = 1 THEN 13815
13790 IF I > N0 THEN 13815
13795 CALL "fmtc": P(), I, Q
13800 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
13805 IF POS("fFeEgG", C$) = 0 THEN 13815
13810 LET D = 4
13815 CALL "stl": N(), M(), C(), X(), X$(), A, D
13820 LET A = N(A, 8)
13825 NEXT I
13830 IF X(9) > M(M(J, 0), 3) THEN 13995
13835 IF Z = 1 THEN 13855
13840 IF M(F, 1) = 0 THEN 13995
13845 CALL "er": N(), X(), X$(), F, "FORMAT_LITERAL", "", "", "", 0
13850 GOTO 13995
13855 IF E = 0 THEN 13875
13860 CALL "resc": E$, A$
13865 CALL "er": N(), X(), X$(), F, "FORMAT_BAD", A$, "", "", 1
13870 GOTO 13995
13875 IF N0 = H - 1 THEN 13895
13880 CALL "resc": S$(N(F, 6)), A$
13885 CALL "er": N(), X(), X$(), J, "FORMAT_COUNT", A$, STR$(N0), STR$(H - 1), 3
13890 GOTO 13995
13895 LET A = N(F, 8)
13900 FOR I = 1 TO H - 1
13905 CALL "fmtc": P(), I, Q
13910 LET C$ = SEG$(S$(N(F, 6)), P(Q, 2), P(Q, 2))
13915 LET V = M(A, 1)
13920 REM an argument of error type (0: a failed constant, reported at its declaration) is settled
13925 IF V = 0 THEN 13985
13930 IF C$ = "s" THEN 13965
13935 IF V = 3 THEN 13985
13940 IF V = 4 THEN 13985
13945 IF V <> 2 THEN 13955
13950 IF POS("di", C$) > 0 THEN 13985
13955 LET B$ = "an integer or f64"
13960 GOTO 13975
13965 IF V = 5 THEN 13985
13970 LET B$ = "str"
13975 CALL "tyn": T(), V, C$
13980 CALL "er": N(), X(), X$(), A, "FORMAT_ARG", SEG$(S$(N(F, 6)), P(Q, 1), P(Q, 2)), B$, C$, 3
13985 LET A = N(A, 8)
13990 NEXT I
13995 SUBEND
14000 REM ---- fmtc: Q = the piece of the I-th conversion of a parsed format P ------------------------
14005 SUB "fmtc": P(), I, Q
14010 LET K = 0
14015 FOR Q = 1 TO P(0, 0)
14020 IF P(Q, 0) <> 2 THEN 14035
14025 LET K = K + 1
14030 IF K = I THEN 14045
14035 NEXT Q
14040 LET Q = 0
14045 SUBEND
14050 REM ---- fmtp: parse format F$ (LANGUAGE 11.1) into pieces P(1..P(0,0)): P(k,0) 1 text (bytes
14055 REM P(k,1)..P(k,2), %% not yet collapsed) or 2 conversion (P(k,1) the %, P(k,2) the letter,
14060 REM P(k,3) flags: 1 '-' 2 '+' 4 ' ' 8 '0' 16 '#', P(k,4) width, P(k,5) precision, -1 absent);
14065 REM N = conversions; E = 1 and E$ = the invalid conversion from its % through the byte that
14070 REM makes it invalid (or the end of the format); width and precision are at most V9 by value
14075 SUB "fmtp": F$, P(), N, E, E$, V9
14080 LET P(0, 0) = 0
14085 LET N = 0
14090 LET E = 0
14095 LET E$ = ""
14100 LET L0 = LEN(F$)
14105 LET I = 1
14110 LET S0 = 0
14115 IF I > L0 THEN 14490
14120 IF SEG$(F$, I, I) = "%" THEN 14145
14125 IF S0 > 0 THEN 14135
14130 LET S0 = I
14135 LET I = I + 1
14140 GOTO 14115
14145 IF I = L0 THEN 14175
14150 IF SEG$(F$, I + 1, I + 1) <> "%" THEN 14175
14155 IF S0 > 0 THEN 14165
14160 LET S0 = I
14165 LET I = I + 2
14170 GOTO 14115
14175 REM a conversion: the text before it is one piece
14180 IF S0 = 0 THEN 14210
14185 LET P(0, 0) = P(0, 0) + 1
14190 LET P(P(0, 0), 0) = 1
14195 LET P(P(0, 0), 1) = S0
14200 LET P(P(0, 0), 2) = I - 1
14205 LET S0 = 0
14210 LET S = I
14215 LET G = 0
14220 LET I = I + 1
14225 IF I > L0 THEN 14475
14230 LET H = POS("-+ 0#", SEG$(F$, I, I))
14235 IF H = 0 THEN 14265
14240 LET B = 2 ^ (H - 1)
14245 IF INT(G / B) - 2 * INT(G / (2 * B)) = 1 THEN 14255
14250 LET G = G + B
14255 LET I = I + 1
14260 GOTO 14225
14265 LET W = -1
14270 IF I > L0 THEN 14475
14275 LET H = POS("0123456789", SEG$(F$, I, I))
14280 IF H = 0 THEN 14315
14285 IF W >= 0 THEN 14295
14290 LET W = 0
14295 IF 10 * W + H - 1 > V9 THEN 14460
14300 LET W = 10 * W + H - 1
14305 LET I = I + 1
14310 GOTO 14270
14315 LET R = -1
14320 IF SEG$(F$, I, I) <> "." THEN 14370
14325 LET R = 0
14330 LET I = I + 1
14335 IF I > L0 THEN 14475
14340 LET H = POS("0123456789", SEG$(F$, I, I))
14345 IF H = 0 THEN 14370
14350 IF 10 * R + H - 1 > V9 THEN 14460
14355 LET R = 10 * R + H - 1
14360 LET I = I + 1
14365 GOTO 14335
14370 LET C$ = SEG$(F$, I, I)
14375 IF POS("diFfEeGgs", C$) = 0 THEN 14460
14380 REM C leaves # with d i s and 0 with s undefined: invalid here (LANGUAGE 11.1)
14385 IF G < 16 THEN 14395
14390 IF POS("dis", C$) > 0 THEN 14460
14395 IF C$ <> "s" THEN 14405
14400 IF INT(G / 8) - 2 * INT(G / 16) = 1 THEN 14460
14405 LET P(0, 0) = P(0, 0) + 1
14410 LET K = P(0, 0)
14415 LET P(K, 0) = 2
14420 LET P(K, 1) = S
14425 LET P(K, 2) = I
14430 LET P(K, 3) = G
14435 LET P(K, 4) = W
14440 LET P(K, 5) = R
14445 LET N = N + 1
14450 LET I = I + 1
14455 GOTO 14115
14460 LET E = 1
14465 LET E$ = SEG$(F$, S, I)
14470 GOTO 14515
14475 LET E = 1
14480 LET E$ = SEG$(F$, S, L0)
14485 GOTO 14515
14490 IF S0 = 0 THEN 14515
14495 LET P(0, 0) = P(0, 0) + 1
14500 LET P(P(0, 0), 0) = 1
14505 LET P(P(0, 0), 1) = S0
14510 LET P(P(0, 0), 2) = L0
14515 SUBEND
