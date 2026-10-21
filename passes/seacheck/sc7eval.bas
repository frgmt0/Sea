10420 REM ---- powk: Z = 1 when the exponent B of a ^ is a constant whose exact value is an integer K0
10425 REM with |K0| <= LIM_POWK (DESIGN 3.5.5 "Constant exponents", LANGUAGE 6.5); Z = 2 when B reads
10430 REM a failed constant (no further error) ------------------------------------------------------
10435 SUB "powk": N(), M(), Y(), C(), W(), X(), X$(), B, K0, Z
10440 LET Z = 0
10445 LET K0 = 0
10450 REM W() fills evx's mtab slot Q(): with F = 0 evx never reads it, and Q() is not in scope here
10455 REM W() only fills the mtab slot Q() of evx: F = 0 never reads it, and Q() is not in scope here
10460 CALL "evx": N(), M(), Y(), C(), W(), X(), X$(), W(), B, 0, K, A3, A2, A1, A0
10465 IF K = 0 THEN 10585
10470 IF K < 4 THEN 10495
10475 REM a poisoned exponent (a failed constant) is settled: Z = 2, no pow and no error from it
10480 IF A1 <> 3 THEN 10585
10485 LET Z = 2
10490 GOTO 10585
10495 IF K > 2 THEN 10585
10500 IF K = 1 THEN 10520
10505 CALL "FETOI": A3, A2, A1, A0, B3, B2, B1, B0, E
10510 IF E <> 0 THEN 10585
10515 GOTO 10540
10520 LET B3 = A3
10525 LET B2 = A2
10530 LET B1 = A1
10535 LET B0 = A0
10540 IF B3 + B2 + B1 <> 0 THEN 10565
10545 IF B0 > X(25) THEN 10585
10550 LET K0 = B0
10555 LET Z = 1
10560 GOTO 10585
10565 IF B3 + B2 + B1 <> 3 * 65535 THEN 10585
10570 IF B0 < 65536 - X(25) THEN 10585
10575 LET K0 = B0 - 65536
10580 LET Z = 1
10585 SUBEND
10590 REM ---- evx: the exact value of constant expression E with the semantics of LANGUAGE 6 (7.2,
10595 REM DESIGN 2.8, 3.5.2, 3.5.5): K 1 i64, 2 f64 (limbs A3..A0), 3 bool (A0 0 or 1), 4 an error:
10600 REM the i64 operation at node A0 overflowed (A1 = 1) or divided by zero (A1 = 2), the first in
10605 REM evaluation order that the program would evaluate (&& and || skip their right operand as at
10610 REM run time; A1 = 3: a poisoned value from a failed constant, already reported, A0 = 0);
10615 REM 0 not a constant value (a call, a variable, a ^ that is not a powk). Post-order
10620 REM with a value stack in W from X(11) up, five words per value (kind, four limbs); a
10625 REM constant's value was computed before (ck_cord, cval). F = 1 (a const item, cval): pow(x, y)
10630 REM and a ^ that is not a powk are evaluated by FEPOW with the mtab words Q() (DESIGN 4.10.5);
10635 REM F = 0 (powk; Q() unused): they are no constant value. --------------------------------
10640 SUB "evx": N(), M(), Y(), C(), W(), X(), X$(), Q(), E, F, K, A3, A2, A1, A0
10645 LET B9 = X(11)
10650 LET P = B9
10655 FOR J = M(E, 0) TO E
10660 LET P0 = P - 5 * M(J, 6)
10665 LET V = 0
10670 LET R3 = 0
10675 LET R2 = 0
10680 LET R1 = 0
10685 LET R0 = 0
10690 LET K1 = N(J, 0)
10695 IF K1 = 25 THEN 10745
10700 IF K1 = 26 THEN 10820
10705 IF K1 = 28 THEN 10855
10710 IF K1 = 29 THEN 10860
10715 IF K1 = 30 THEN 10870
10720 IF K1 = 32 THEN 11040
10725 IF K1 = 33 THEN 11175
10730 IF K1 = 34 THEN 11335
10735 IF K1 = 35 THEN 11240
10740 GOTO 11340
10745 LET H = M(J, 5)
10750 LET R3 = C(H, 1)
10755 LET R2 = C(H, 2)
10760 LET R1 = C(H, 3)
10765 LET R0 = C(H, 4)
10770 LET V = 1
10775 IF M(J, 1) <> 4 THEN 11340
10780 LET V = 2
10785 IF R3 <> 32768 THEN 10810
10790 IF R2 + R1 + R0 <> 0 THEN 10810
10795 REM the literal 2^63 (only under neg): +2^63 in f64
10800 LET R3 = 17376
10805 GOTO 11340
10810 CALL "FEFRI": C(H, 1), C(H, 2), C(H, 3), C(H, 4), R3, R2, R1, R0, Z
10815 GOTO 11340
10820 LET H = M(J, 5)
10825 LET R3 = C(H, 1)
10830 LET R2 = C(H, 2)
10835 LET R1 = C(H, 3)
10840 LET R0 = C(H, 4)
10845 LET V = 2
10850 GOTO 11340
10855 LET R0 = 1
10860 LET V = 3
10865 GOTO 11340
10870 LET S = M(J, 2)
10875 IF S = 0 THEN 11340
10880 IF S < 0 THEN 10995
10885 IF Y(S, 0) <> 2 THEN 11340
10890 REM the value of a constant (computed before, ck_cord): 1 i64 2 f64 (C row Y(S,8)), 3 bool (Y(S,8) itself)
10895 REM 6 failed (an error was reported for it): a poisoned value, kind 4 with A1 = 3
10900 IF Y(S, 7) = 6 THEN 10980
10905 IF Y(S, 7) = 0 THEN 11340
10910 IF Y(S, 7) > 3 THEN 11340
10915 LET V = Y(S, 7)
10920 LET H = Y(S, 8)
10925 IF V <> 3 THEN 10955
10930 LET R3 = 0
10935 LET R2 = 0
10940 LET R1 = 0
10945 LET R0 = H
10950 GOTO 11340
10955 LET R3 = C(H, 1)
10960 LET R2 = C(H, 2)
10965 LET R1 = C(H, 3)
10970 LET R0 = C(H, 4)
10975 GOTO 11340
10980 LET V = 4
10985 LET R1 = 3
10990 GOTO 11340
10995 IF S < -4 THEN 11340
11000 REM pi inf nan eps (LANGUAGE 10.1; bits of DESIGN 3.5.5)
11005 LET V = 2
11010 LET R3 = VAL(SEG$("16393327523276015536", 5 * (-S) - 4, 5 * (-S)))
11015 IF S <> -1 THEN 11340
11020 LET R2 = 8699
11025 LET R1 = 21572
11030 LET R0 = 11544
11035 GOTO 11340
11040 LET G = N(J, 7)
11045 IF N(G, 0) <> 25 THEN 11100
11050 LET H = M(G, 5)
11055 IF C(H, 1) <> 32768 THEN 11100
11060 IF C(H, 2) + C(H, 3) + C(H, 4) <> 0 THEN 11100
11065 REM -2^63: the i64 pattern #8000000000000000, or the f64 -2^63
11070 LET V = 1
11075 LET R3 = 32768
11080 IF M(J, 1) <> 4 THEN 11340
11085 LET V = 2
11090 LET R3 = 50144
11095 GOTO 11340
11100 LET V = W(P0 + 1)
11105 IF V = 1 THEN 11140
11110 IF V = 2 THEN 11130
11115 IF V = 4 THEN 11210
11120 LET V = 0
11125 GOTO 11340
11130 CALL "FENEG": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), R3, R2, R1, R0
11135 GOTO 11340
11140 CALL "LMNEG": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), R3, R2, R1, R0, Z
11145 IF Z = 0 THEN 11340
11150 REM -(-2^63) overflows: an error at this node
11155 LET V = 4
11160 LET R0 = J
11165 LET R1 = 1
11170 GOTO 11340
11175 LET V = W(P0 + 1)
11180 IF V = 4 THEN 11210
11185 IF V = 3 THEN 11200
11190 LET V = 0
11195 GOTO 11340
11200 LET R0 = 1 - W(P0 + 5)
11205 GOTO 11340
11210 REM an error value passes up unchanged
11215 LET R3 = W(P0 + 2)
11220 LET R2 = W(P0 + 3)
11225 LET R1 = W(P0 + 4)
11230 LET R0 = W(P0 + 5)
11235 GOTO 11340
11240 REM pow(x, y) (F = 1): x at W(P0+6..), y at W(P0+11..) after the callee name's slot; an error
11245 REM operand passes up, the first one first
11250 IF F = 0 THEN 11340
11255 IF M(N(J, 7), 2) <> -X(39) THEN 11340
11260 LET Q9 = 5
11265 IF W(P0 + 6) = 4 THEN 11305
11270 LET Q9 = 10
11275 IF W(P0 + 11) = 4 THEN 11305
11280 IF W(P0 + 6) <> 2 THEN 11340
11285 IF W(P0 + 11) <> 2 THEN 11340
11290 CALL "FEPOW": Q(), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), W(P0 + 12), W(P0 + 13), W(P0 + 14), W(P0 + 15), R3, R2, R1, R0
11295 LET V = 2
11300 GOTO 11340
11305 LET V = 4
11310 LET R3 = W(P0 + Q9 + 2)
11315 LET R2 = W(P0 + Q9 + 3)
11320 LET R1 = W(P0 + Q9 + 4)
11325 LET R0 = W(P0 + Q9 + 5)
11330 GOTO 11340
11335 CALL "evbin": N(), M(), W(), Q(), J, P0, F, V, R3, R2, R1, R0
11340 IF M(J, 7) <> 1 THEN 11360
11345 IF V <> 1 THEN 11360
11350 CALL "FEFRI": R3 + 0, R2 + 0, R1 + 0, R0 + 0, R3, R2, R1, R0, Z
11355 LET V = 2
11360 LET P = P0
11365 IF P + 5 < X(12) - 2 THEN 11385
11370 CALL "fatal": N(), X(), X$(), J, "nesting"
11375 LET V = 0
11380 GOTO 11420
11385 LET W(P + 1) = V
11390 LET W(P + 2) = R3
11395 LET W(P + 3) = R2
11400 LET W(P + 4) = R1
11405 LET W(P + 5) = R0
11410 LET P = P + 5
11415 NEXT J
11420 LET K = W(B9 + 1)
11425 LET A3 = W(B9 + 2)
11430 LET A2 = W(B9 + 3)
11435 LET A1 = W(B9 + 4)
11440 LET A0 = W(B9 + 5)
11445 IF V <> 0 THEN 11455
11450 LET K = 0
11455 SUBEND
11460 REM ---- evbin: the value of binary node J from its operands at W(P0+1..P0+10) (see evx): an
11465 REM error operand passes up (the left one first); && and || decided by the left operand ignore
11470 REM the right one; a powk by the pinned multiplications of LANGUAGE 6.5; with F = 1 another ^ by
11475 REM FEPOW (Q() the mtab words, DESIGN 4.10.5) ---------------------
11480 SUB "evbin": N(), M(), W(), Q(), J, P0, F, V, R3, R2, R1, R0
11485 LET V = 0
11490 LET U = W(P0 + 1)
11495 LET U2 = W(P0 + 6)
11500 LET O = N(J, 1)
11505 LET Q = 0
11510 IF U = 4 THEN 11935
11515 IF O < 16 THEN 11550
11520 REM && (16) and || (17): false && x is false, true || x is true, whatever x is
11525 IF U <> 3 THEN 11550
11530 IF W(P0 + 5) <> O - 16 THEN 11550
11535 LET V = 3
11540 LET R0 = O - 16
11545 GOTO 12130
11550 LET Q = 5
11555 IF M(J, 8) > 0 THEN 11970
11560 IF U2 = 4 THEN 11935
11565 IF U = 0 THEN 12130
11570 IF U <> U2 THEN 12130
11575 IF O < 8 THEN 11735
11580 IF U = 3 THEN 11635
11585 REM comparisons of two i64 or two f64 (LANGUAGE 6.4: NaN compares false except !=)
11590 IF O > 13 THEN 12130
11595 IF U = 2 THEN 11610
11600 CALL "LMCMP": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), Z
11605 GOTO 11615
11610 CALL "FECMP": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), Z
11615 REM Z -1 0 1 or 2 (unordered); the result of eq ne lt le gt ge in that order of Z
11620 LET V = 3
11625 LET R0 = VAL(SEG$("010010111000110000100110", 4 * (O - 8) + Z + 2, 4 * (O - 8) + Z + 2))
11630 GOTO 12130
11635 REM bool: == != & | && || (a decided && or || returned above)
11640 IF O = 8 THEN 11685
11645 IF O = 9 THEN 11710
11650 IF O < 14 THEN 12130
11655 LET V = 3
11660 LET R0 = W(P0 + 5) * W(P0 + 10)
11665 IF O = 14 THEN 12130
11670 IF O = 16 THEN 12130
11675 LET R0 = W(P0 + 5) + W(P0 + 10) - R0
11680 GOTO 12130
11685 LET V = 3
11690 LET R0 = 1
11695 IF W(P0 + 5) = W(P0 + 10) THEN 12130
11700 LET R0 = 0
11705 GOTO 12130
11710 LET V = 3
11715 LET R0 = 0
11720 IF W(P0 + 5) = W(P0 + 10) THEN 12130
11725 LET R0 = 1
11730 GOTO 12130
11735 IF O = 6 THEN 11910
11740 IF O > 5 THEN 12130
11745 IF U = 3 THEN 12130
11750 IF U = 2 THEN 11850
11755 ON O GOTO 11760, 11770, 11780, 12130, 11790
11760 CALL "LMADD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
11765 GOTO 11810
11770 CALL "LMSUB": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
11775 GOTO 11810
11780 CALL "LMMUL": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
11785 GOTO 11810
11790 CALL "LMMOD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
11795 REM a zero divisor (E = 2) is an error at this node
11800 IF Z = 0 THEN 11810
11805 LET Z = 2
11810 LET V = 1
11815 IF Z = 0 THEN 12130
11820 LET V = 4
11825 LET R1 = Z
11830 LET R0 = J
11835 LET R2 = 0
11840 LET R3 = 0
11845 GOTO 12130
11850 ON O GOTO 11855, 11865, 11875, 11885, 11895
11855 CALL "FEADD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11860 GOTO 11900
11865 CALL "FESUB": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11870 GOTO 11900
11875 CALL "FEMUL": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11880 GOTO 11900
11885 CALL "FEDIV": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11890 GOTO 11900
11895 CALL "FEMOD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11900 LET V = 2
11905 GOTO 12130
11910 REM a ^ that is not a powk, in a const item (F = 1): the run time's pow (DESIGN 3.5.5)
11915 IF F = 0 THEN 12130
11920 IF U <> 2 THEN 12130
11925 CALL "FEPOW": Q(), W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11930 GOTO 11900
11935 REM the error of the operand at W(P0+Q+1..)
11940 LET V = 4
11945 LET R3 = W(P0 + Q + 2)
11950 LET R2 = W(P0 + Q + 3)
11955 LET R1 = W(P0 + Q + 4)
11960 LET R0 = W(P0 + Q + 5)
11965 GOTO 12130
11970 REM x^0 = 1, x^1 = x, x^2 = x*x, x^3 = (x*x)*x, x^4 = (x*x)*(x*x), x^-k = 1/(x^k)
11975 IF U <> 2 THEN 12130
11980 LET K = M(J, 8) - 10
11985 LET K1 = ABS(K)
11990 LET R3 = W(P0 + 2)
11995 LET R2 = W(P0 + 3)
12000 LET R1 = W(P0 + 4)
12005 LET R0 = W(P0 + 5)
12010 IF K1 > 0 THEN 12040
12015 LET R3 = 16368
12020 LET R2 = 0
12025 LET R1 = 0
12030 LET R0 = 0
12035 GOTO 12125
12040 IF K1 = 1 THEN 12095
12045 CALL "FEMUL": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), Q3, Q2, Q1, Q0
12050 LET R3 = Q3
12055 LET R2 = Q2
12060 LET R1 = Q1
12065 LET R0 = Q0
12070 IF K1 = 2 THEN 12095
12075 IF K1 = 4 THEN 12090
12080 CALL "FEMUL": Q3, Q2, Q1, Q0, W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), R3, R2, R1, R0
12085 GOTO 12095
12090 CALL "FEMUL": Q3, Q2, Q1, Q0, Q3, Q2, Q1, Q0, R3, R2, R1, R0
12095 IF K >= 0 THEN 12125
12100 CALL "FEDIV": 16368, 0, 0, 0, R3, R2, R1, R0, Q3, Q2, Q1, Q0
12105 LET R3 = Q3
12110 LET R2 = Q2
12115 LET R1 = Q1
12120 LET R0 = Q0
12125 LET V = 2
12130 SUBEND
12135 REM ---- cval: the value of const item S (LANGUAGE 7.2): Y(S,7) 1 i64, 2 f64, 3 bool, 5 none, 6 failed
12140 REM (number: C row Y(S,8); bool: Y(S,8) is 0 or 1); an i64 overflow or zero divisor is error
12145 REM 260 or 261 at its operator ----
12150 SUB "cval": N(), M(), Y(), C(), W(), X(), X$(), H(), Q(), S
12155 IF Y(S, 7) <> 0 THEN 12305
12160 LET Y(S, 7) = 6
12165 LET F = Y(S, 3)
12170 LET E = N(F, 7)
12175 IF N(F, 1) = 0 THEN 12185
12180 LET E = N(E, 8)
12185 CALL "evx": N(), M(), Y(), C(), W(), X(), X$(), Q(), E, 1, K, A3, A2, A1, A0
12190 IF K > 0 THEN 12210
12195 REM no constant value (an error was reported by the check): none
12200 LET Y(S, 7) = 5
12205 GOTO 12305
12210 IF K < 4 THEN 12250
12215 REM a failed operand (A1 = 3) was reported already: this constant fails too, silently
12220 IF A1 = 3 THEN 12305
12225 IF A1 = 2 THEN 12240
12230 CALL "er": N(), X(), X$(), A0, "INT_OVERFLOW_C", "", "", "", 0
12235 GOTO 12305
12240 CALL "er": N(), X(), X$(), A0, "INT_DIV_ZERO_C", "", "", "", 0
12245 GOTO 12305
12250 REM a bool value is kept in Y(S,8) itself (0 or 1): only numbers count as constants (DESIGN
12255 REM 2.7); the C row is keyed by type: 3 i64, 4 f64
12260 LET R = A0
12265 IF K = 3 THEN 12295
12270 LET D = K + 2
12275 CALL "cnew": C(), H(), X(), D, A3, A2, A1, A0, R
12280 IF R > 0 THEN 12295
12285 CALL "fatal": N(), X(), X$(), F, "constants"
12290 GOTO 12305
12295 LET Y(S, 8) = R
12300 LET Y(S, 7) = K
12305 SUBEND
