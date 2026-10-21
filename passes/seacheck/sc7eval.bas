10260 REM ---- powk: Z = 1 when the exponent B of a ^ is a constant whose exact value is an integer K0
10265 REM with |K0| <= LIM_POWK (DESIGN 3.5.5 "Constant exponents", LANGUAGE 6.5); Z = 2 when B reads
10270 REM a failed constant (no further error) ------------------------------------------------------
10275 SUB "powk": N(), M(), Y(), C(), W(), X(), X$(), B, K0, Z
10280 LET Z = 0
10285 LET K0 = 0
10290 CALL "evx": N(), M(), Y(), C(), W(), X(), X$(), B, K, A3, A2, A1, A0
10295 IF K = 0 THEN 10415
10300 IF K < 4 THEN 10325
10305 REM a poisoned exponent (a failed constant) is settled: Z = 2, no pow and no error from it
10310 IF A1 <> 3 THEN 10415
10315 LET Z = 2
10320 GOTO 10415
10325 IF K > 2 THEN 10415
10330 IF K = 1 THEN 10350
10335 CALL "FETOI": A3, A2, A1, A0, B3, B2, B1, B0, E
10340 IF E <> 0 THEN 10415
10345 GOTO 10370
10350 LET B3 = A3
10355 LET B2 = A2
10360 LET B1 = A1
10365 LET B0 = A0
10370 IF B3 + B2 + B1 <> 0 THEN 10395
10375 IF B0 > X(25) THEN 10415
10380 LET K0 = B0
10385 LET Z = 1
10390 GOTO 10415
10395 IF B3 + B2 + B1 <> 3 * 65535 THEN 10415
10400 IF B0 < 65536 - X(25) THEN 10415
10405 LET K0 = B0 - 65536
10410 LET Z = 1
10415 SUBEND
10420 REM ---- evx: the exact value of constant expression E with the semantics of LANGUAGE 6 (7.2,
10425 REM DESIGN 2.8, 3.5.2, 3.5.5): K 1 i64, 2 f64 (limbs A3..A0), 3 bool (A0 0 or 1), 4 an error:
10430 REM the i64 operation at node A0 overflowed (A1 = 1) or divided by zero (A1 = 2), the first in
10435 REM evaluation order that the program would evaluate (&& and || skip their right operand as at
10440 REM run time; A1 = 3: a poisoned value from a failed constant, already reported, A0 = 0);
10445 REM 0 not a constant value (a call, a variable, a ^ that is not a powk). Post-order
10450 REM with a value stack in W from X(11) up, five words per value (kind, four limbs); a
10455 REM constant's value was computed before (ck_cord, cval). --------------------------------
10460 SUB "evx": N(), M(), Y(), C(), W(), X(), X$(), E, K, A3, A2, A1, A0
10465 LET B9 = X(11)
10470 LET P = B9
10475 FOR J = M(E, 0) TO E
10480 LET P0 = P - 5 * M(J, 6)
10485 LET V = 0
10490 LET R3 = 0
10495 LET R2 = 0
10500 LET R1 = 0
10505 LET R0 = 0
10510 LET K1 = N(J, 0)
10515 IF K1 = 25 THEN 10560
10520 IF K1 = 26 THEN 10635
10525 IF K1 = 28 THEN 10670
10530 IF K1 = 29 THEN 10675
10535 IF K1 = 30 THEN 10685
10540 IF K1 = 32 THEN 10855
10545 IF K1 = 33 THEN 10990
10550 IF K1 = 34 THEN 11055
10555 GOTO 11060
10560 LET H = M(J, 5)
10565 LET R3 = C(H, 1)
10570 LET R2 = C(H, 2)
10575 LET R1 = C(H, 3)
10580 LET R0 = C(H, 4)
10585 LET V = 1
10590 IF M(J, 1) <> 4 THEN 11060
10595 LET V = 2
10600 IF R3 <> 32768 THEN 10625
10605 IF R2 + R1 + R0 <> 0 THEN 10625
10610 REM the literal 2^63 (only under neg): +2^63 in f64
10615 LET R3 = 17376
10620 GOTO 11060
10625 CALL "FEFRI": C(H, 1), C(H, 2), C(H, 3), C(H, 4), R3, R2, R1, R0, Z
10630 GOTO 11060
10635 LET H = M(J, 5)
10640 LET R3 = C(H, 1)
10645 LET R2 = C(H, 2)
10650 LET R1 = C(H, 3)
10655 LET R0 = C(H, 4)
10660 LET V = 2
10665 GOTO 11060
10670 LET R0 = 1
10675 LET V = 3
10680 GOTO 11060
10685 LET S = M(J, 2)
10690 IF S = 0 THEN 11060
10695 IF S < 0 THEN 10810
10700 IF Y(S, 0) <> 2 THEN 11060
10705 REM the value of a constant (computed before, ck_cord): 1 i64 2 f64 (C row Y(S,8)), 3 bool (Y(S,8) itself)
10710 REM 6 failed (an error was reported for it): a poisoned value, kind 4 with A1 = 3
10715 IF Y(S, 7) = 6 THEN 10795
10720 IF Y(S, 7) = 0 THEN 11060
10725 IF Y(S, 7) > 3 THEN 11060
10730 LET V = Y(S, 7)
10735 LET H = Y(S, 8)
10740 IF V <> 3 THEN 10770
10745 LET R3 = 0
10750 LET R2 = 0
10755 LET R1 = 0
10760 LET R0 = H
10765 GOTO 11060
10770 LET R3 = C(H, 1)
10775 LET R2 = C(H, 2)
10780 LET R1 = C(H, 3)
10785 LET R0 = C(H, 4)
10790 GOTO 11060
10795 LET V = 4
10800 LET R1 = 3
10805 GOTO 11060
10810 IF S < -4 THEN 11060
10815 REM pi inf nan eps (LANGUAGE 10.1; bits of DESIGN 3.5.5)
10820 LET V = 2
10825 LET R3 = VAL(SEG$("16393327523276015536", 5 * (-S) - 4, 5 * (-S)))
10830 IF S <> -1 THEN 11060
10835 LET R2 = 8699
10840 LET R1 = 21572
10845 LET R0 = 11544
10850 GOTO 11060
10855 LET G = N(J, 7)
10860 IF N(G, 0) <> 25 THEN 10915
10865 LET H = M(G, 5)
10870 IF C(H, 1) <> 32768 THEN 10915
10875 IF C(H, 2) + C(H, 3) + C(H, 4) <> 0 THEN 10915
10880 REM -2^63: the i64 pattern #8000000000000000, or the f64 -2^63
10885 LET V = 1
10890 LET R3 = 32768
10895 IF M(J, 1) <> 4 THEN 11060
10900 LET V = 2
10905 LET R3 = 50144
10910 GOTO 11060
10915 LET V = W(P0 + 1)
10920 IF V = 1 THEN 10955
10925 IF V = 2 THEN 10945
10930 IF V = 4 THEN 11025
10935 LET V = 0
10940 GOTO 11060
10945 CALL "FENEG": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), R3, R2, R1, R0
10950 GOTO 11060
10955 CALL "LMNEG": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), R3, R2, R1, R0, Z
10960 IF Z = 0 THEN 11060
10965 REM -(-2^63) overflows: an error at this node
10970 LET V = 4
10975 LET R0 = J
10980 LET R1 = 1
10985 GOTO 11060
10990 LET V = W(P0 + 1)
10995 IF V = 4 THEN 11025
11000 IF V = 3 THEN 11015
11005 LET V = 0
11010 GOTO 11060
11015 LET R0 = 1 - W(P0 + 5)
11020 GOTO 11060
11025 REM an error value passes up unchanged
11030 LET R3 = W(P0 + 2)
11035 LET R2 = W(P0 + 3)
11040 LET R1 = W(P0 + 4)
11045 LET R0 = W(P0 + 5)
11050 GOTO 11060
11055 CALL "evbin": N(), M(), W(), J, P0, V, R3, R2, R1, R0
11060 IF M(J, 7) <> 1 THEN 11080
11065 IF V <> 1 THEN 11080
11070 CALL "FEFRI": R3 + 0, R2 + 0, R1 + 0, R0 + 0, R3, R2, R1, R0, Z
11075 LET V = 2
11080 LET P = P0
11085 IF P + 5 < X(12) - 2 THEN 11105
11090 CALL "fatal": N(), X(), X$(), J, "nesting"
11095 LET V = 0
11100 GOTO 11140
11105 LET W(P + 1) = V
11110 LET W(P + 2) = R3
11115 LET W(P + 3) = R2
11120 LET W(P + 4) = R1
11125 LET W(P + 5) = R0
11130 LET P = P + 5
11135 NEXT J
11140 LET K = W(B9 + 1)
11145 LET A3 = W(B9 + 2)
11150 LET A2 = W(B9 + 3)
11155 LET A1 = W(B9 + 4)
11160 LET A0 = W(B9 + 5)
11165 IF V <> 0 THEN 11175
11170 LET K = 0
11175 SUBEND
11180 REM ---- evbin: the value of binary node J from its operands at W(P0+1..P0+10) (see evx): an
11185 REM error operand passes up (the left one first); && and || decided by the left operand ignore
11190 REM the right one; a powk by the pinned multiplications of LANGUAGE 6.5 ---------------------
11195 SUB "evbin": N(), M(), W(), J, P0, V, R3, R2, R1, R0
11200 LET V = 0
11205 LET U = W(P0 + 1)
11210 LET U2 = W(P0 + 6)
11215 LET O = N(J, 1)
11220 LET Q = 0
11225 IF U = 4 THEN 11620
11230 IF O < 16 THEN 11265
11235 REM && (16) and || (17): false && x is false, true || x is true, whatever x is
11240 IF U <> 3 THEN 11265
11245 IF W(P0 + 5) <> O - 16 THEN 11265
11250 LET V = 3
11255 LET R0 = O - 16
11260 GOTO 11815
11265 LET Q = 5
11270 IF M(J, 8) > 0 THEN 11655
11275 IF U2 = 4 THEN 11620
11280 IF U = 0 THEN 11815
11285 IF U <> U2 THEN 11815
11290 IF O < 8 THEN 11450
11295 IF U = 3 THEN 11350
11300 REM comparisons of two i64 or two f64 (LANGUAGE 6.4: NaN compares false except !=)
11305 IF O > 13 THEN 11815
11310 IF U = 2 THEN 11325
11315 CALL "LMCMP": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), Z
11320 GOTO 11330
11325 CALL "FECMP": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), Z
11330 REM Z -1 0 1 or 2 (unordered); the result of eq ne lt le gt ge in that order of Z
11335 LET V = 3
11340 LET R0 = VAL(SEG$("010010111000110000100110", 4 * (O - 8) + Z + 2, 4 * (O - 8) + Z + 2))
11345 GOTO 11815
11350 REM bool: == != & | && || (a decided && or || returned above)
11355 IF O = 8 THEN 11400
11360 IF O = 9 THEN 11425
11365 IF O < 14 THEN 11815
11370 LET V = 3
11375 LET R0 = W(P0 + 5) * W(P0 + 10)
11380 IF O = 14 THEN 11815
11385 IF O = 16 THEN 11815
11390 LET R0 = W(P0 + 5) + W(P0 + 10) - R0
11395 GOTO 11815
11400 LET V = 3
11405 LET R0 = 1
11410 IF W(P0 + 5) = W(P0 + 10) THEN 11815
11415 LET R0 = 0
11420 GOTO 11815
11425 LET V = 3
11430 LET R0 = 0
11435 IF W(P0 + 5) = W(P0 + 10) THEN 11815
11440 LET R0 = 1
11445 GOTO 11815
11450 IF O > 5 THEN 11815
11455 IF U = 3 THEN 11815
11460 IF U = 2 THEN 11560
11465 ON O GOTO 11470, 11480, 11490, 11815, 11500
11470 CALL "LMADD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
11475 GOTO 11520
11480 CALL "LMSUB": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
11485 GOTO 11520
11490 CALL "LMMUL": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
11495 GOTO 11520
11500 CALL "LMMOD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
11505 REM a zero divisor (E = 2) is an error at this node
11510 IF Z = 0 THEN 11520
11515 LET Z = 2
11520 LET V = 1
11525 IF Z = 0 THEN 11815
11530 LET V = 4
11535 LET R1 = Z
11540 LET R0 = J
11545 LET R2 = 0
11550 LET R3 = 0
11555 GOTO 11815
11560 ON O GOTO 11565, 11575, 11585, 11595, 11605
11565 CALL "FEADD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11570 GOTO 11610
11575 CALL "FESUB": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11580 GOTO 11610
11585 CALL "FEMUL": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11590 GOTO 11610
11595 CALL "FEDIV": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11600 GOTO 11610
11605 CALL "FEMOD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11610 LET V = 2
11615 GOTO 11815
11620 REM the error of the operand at W(P0+Q+1..)
11625 LET V = 4
11630 LET R3 = W(P0 + Q + 2)
11635 LET R2 = W(P0 + Q + 3)
11640 LET R1 = W(P0 + Q + 4)
11645 LET R0 = W(P0 + Q + 5)
11650 GOTO 11815
11655 REM x^0 = 1, x^1 = x, x^2 = x*x, x^3 = (x*x)*x, x^4 = (x*x)*(x*x), x^-k = 1/(x^k)
11660 IF U <> 2 THEN 11815
11665 LET K = M(J, 8) - 10
11670 LET K1 = ABS(K)
11675 LET R3 = W(P0 + 2)
11680 LET R2 = W(P0 + 3)
11685 LET R1 = W(P0 + 4)
11690 LET R0 = W(P0 + 5)
11695 IF K1 > 0 THEN 11725
11700 LET R3 = 16368
11705 LET R2 = 0
11710 LET R1 = 0
11715 LET R0 = 0
11720 GOTO 11810
11725 IF K1 = 1 THEN 11780
11730 CALL "FEMUL": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), Q3, Q2, Q1, Q0
11735 LET R3 = Q3
11740 LET R2 = Q2
11745 LET R1 = Q1
11750 LET R0 = Q0
11755 IF K1 = 2 THEN 11780
11760 IF K1 = 4 THEN 11775
11765 CALL "FEMUL": Q3, Q2, Q1, Q0, W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), R3, R2, R1, R0
11770 GOTO 11780
11775 CALL "FEMUL": Q3, Q2, Q1, Q0, Q3, Q2, Q1, Q0, R3, R2, R1, R0
11780 IF K >= 0 THEN 11810
11785 CALL "FEDIV": 16368, 0, 0, 0, R3, R2, R1, R0, Q3, Q2, Q1, Q0
11790 LET R3 = Q3
11795 LET R2 = Q2
11800 LET R1 = Q1
11805 LET R0 = Q0
11810 LET V = 2
11815 SUBEND
11820 REM ---- cval: the value of const item S (LANGUAGE 7.2): Y(S,7) 1 i64, 2 f64, 3 bool, 5 none, 6 failed
11825 REM (number: C row Y(S,8); bool: Y(S,8) is 0 or 1); an i64 overflow or zero divisor is error
11830 REM 260 or 261 at its operator ----
11835 SUB "cval": N(), M(), Y(), C(), W(), X(), X$(), H(), S
11840 IF Y(S, 7) <> 0 THEN 11990
11845 LET Y(S, 7) = 6
11850 LET F = Y(S, 3)
11855 LET E = N(F, 7)
11860 IF N(F, 1) = 0 THEN 11870
11865 LET E = N(E, 8)
11870 CALL "evx": N(), M(), Y(), C(), W(), X(), X$(), E, K, A3, A2, A1, A0
11875 IF K > 0 THEN 11895
11880 REM no constant value (an error was reported by the check): none
11885 LET Y(S, 7) = 5
11890 GOTO 11990
11895 IF K < 4 THEN 11935
11900 REM a failed operand (A1 = 3) was reported already: this constant fails too, silently
11905 IF A1 = 3 THEN 11990
11910 IF A1 = 2 THEN 11925
11915 CALL "er": N(), X(), X$(), A0, "INT_OVERFLOW_C", "", "", "", 0
11920 GOTO 11990
11925 CALL "er": N(), X(), X$(), A0, "INT_DIV_ZERO_C", "", "", "", 0
11930 GOTO 11990
11935 REM a bool value is kept in Y(S,8) itself (0 or 1): only numbers count as constants (DESIGN
11940 REM 2.7); the C row is keyed by type: 3 i64, 4 f64
11945 LET R = A0
11950 IF K = 3 THEN 11980
11955 LET D = K + 2
11960 CALL "cnew": C(), H(), X(), D, A3, A2, A1, A0, R
11965 IF R > 0 THEN 11980
11970 CALL "fatal": N(), X(), X$(), F, "constants"
11975 GOTO 11990
11980 LET Y(S, 8) = R
11985 LET Y(S, 7) = K
11990 SUBEND
