10470 REM ---- powk: Z = 1 when the exponent B of a ^ is a constant whose exact value is an integer K0
10475 REM with |K0| <= LIM_POWK (DESIGN 3.5.5 "Constant exponents", LANGUAGE 6.5); Z = 2 when B names
10480 REM a constant without a value (Decision 25): no powk ------------------------------------------
10485 SUB "powk": N(), M(), Y(), C(), W(), X(), X$(), B, K0, Z
10490 LET Z = 0
10495 LET K0 = 0
10500 REM W() and X$() stand in for Q(), S$(), G$() of evx: with F = 0 evx never reads them
10510 CALL "evx": N(), M(), Y(), C(), W(), X(), X$(), W(), X$(), X$(), B, 0, K
10511 LET A3 = W(X(11) + 2)
10512 LET A2 = W(X(11) + 3)
10513 LET A1 = W(X(11) + 4)
10514 LET A0 = W(X(11) + 5)
10515 IF K = 0 THEN 10635
10520 IF K < 4 THEN 10545
10525 REM a poisoned exponent (a failed constant) is settled: Z = 2, no pow and no error from it
10530 IF A1 <> 3 THEN 10635
10535 LET Z = 2
10540 GOTO 10635
10545 IF K > 2 THEN 10635
10550 IF K = 1 THEN 10570
10555 CALL "FETOI": A3, A2, A1, A0, B3, B2, B1, B0, E
10560 IF E <> 0 THEN 10635
10565 GOTO 10590
10570 LET B3 = A3
10575 LET B2 = A2
10580 LET B1 = A1
10585 LET B0 = A0
10590 IF B3 + B2 + B1 <> 0 THEN 10615
10595 IF B0 > X(25) THEN 10635
10600 LET K0 = B0
10605 LET Z = 1
10610 GOTO 10635
10615 IF B3 + B2 + B1 <> 3 * 65535 THEN 10635
10620 IF B0 < 65536 - X(25) THEN 10635
10625 LET K0 = B0 - 65536
10630 LET Z = 1
10635 SUBEND
10640 REM ---- evx: the exact value of constant expression E with the semantics of LANGUAGE 6 (7.2,
10645 REM DESIGN 2.8, 3.5.2, 3.5.5): K 1 i64, 2 f64 (limbs A3..A0 in W(X(11)+2..5)), 3 bool (A0 0 or 1), 4 an error:
10650 REM the i64 operation at node A0 overflowed (A1 = 1) or divided by zero (A1 = 2), the first in
10655 REM evaluation order that the program would evaluate (&& and || skip their right operand as at
10660 REM run time; A1 = 3: a poisoned value from a constant without a value, A0 = 0);
10665 REM 0 not a constant value (a call, a variable, a ^ that is not a powk). Post-order
10670 REM with a value stack in W from X(11) up, five words per value (kind, four limbs); a
10675 REM constant's value was computed before (ck_cord, cval). F = 1 (a const item, cval): pow(x, y),
10680 REM sqrt(x) and a ^ that is not a powk are evaluated (FEPOW with the mtab words Q(), DESIGN 4.10.5;
10685 REM FESQR); F = 0 (powk; Q() unused): a call or such a ^ is no constant value. ------------------
10687 REM K = 5: a str (F = 1 only; its bytes in G$(50000 + its stack slot), evs in sn9str). ----------
10690 SUB "evx": N(), M(), Y(), C(), W(), X(), X$(), Q(), S$(), G$(), E, F, K
10695 LET B9 = X(11)
10700 LET P = B9
10705 FOR J = M(E, 0) TO E
10710 LET P0 = P - 5 * M(J, 6)
10715 LET V = 0
10720 LET R3 = 0
10725 LET R2 = 0
10730 LET R1 = 0
10735 LET R0 = 0
10740 LET K1 = N(J, 0)
10745 IF K1 = 25 THEN 10795
10750 IF K1 = 26 THEN 10870
10755 IF K1 = 28 THEN 10905
10760 IF K1 = 29 THEN 10910
10765 IF K1 = 30 THEN 10920
10770 IF K1 = 32 THEN 11090
10775 IF K1 = 33 THEN 11225
10780 IF K1 = 34 THEN 11383
10785 IF K1 = 35 THEN 11290
10790 IF K1 = 27 THEN 11381
10791 GOTO 11390
10795 LET H = M(J, 5)
10800 LET R3 = C(H, 1)
10805 LET R2 = C(H, 2)
10810 LET R1 = C(H, 3)
10815 LET R0 = C(H, 4)
10820 LET V = 1
10825 IF M(J, 1) <> 4 THEN 11390
10830 LET V = 2
10835 IF R3 <> 32768 THEN 10860
10840 IF R2 + R1 + R0 <> 0 THEN 10860
10845 REM the literal 2^63 (only under neg): +2^63 in f64
10850 LET R3 = 17376
10855 GOTO 11390
10860 CALL "FEFRI": C(H, 1), C(H, 2), C(H, 3), C(H, 4), R3, R2, R1, R0, Z
10865 GOTO 11390
10870 LET H = M(J, 5)
10875 LET R3 = C(H, 1)
10880 LET R2 = C(H, 2)
10885 LET R1 = C(H, 3)
10890 LET R0 = C(H, 4)
10895 LET V = 2
10900 GOTO 11390
10905 LET R0 = 1
10910 LET V = 3
10915 GOTO 11390
10920 LET S = M(J, 2)
10925 IF S = 0 THEN 11390
10930 IF S < 0 THEN 11045
10935 IF Y(S, 0) <> 2 THEN 11390
10940 REM the value of a constant (sn_const, before): 1 i64 2 f64 (limbs packed in Y(S,8), Y(S,9)),
10945 REM 3 bool (Y(S,8) itself); 6 failed: a poisoned value, kind 4 with A1 = 3; 5 none
10950 IF Y(S, 7) = 6 THEN 11030
10955 IF Y(S, 7) = 0 THEN 11390
10957 IF Y(S, 7) = 4 THEN 11381
10960 IF Y(S, 7) > 3 THEN 11390
10965 LET V = Y(S, 7)
10970 LET H = Y(S, 8)
10975 IF V <> 3 THEN 11005
10980 LET R3 = 0
10985 LET R2 = 0
10990 LET R1 = 0
10995 LET R0 = H
11000 GOTO 11390
11005 LET R3 = INT(H / 65536)
11010 LET R2 = H - 65536 * R3
11015 LET R1 = INT(Y(S, 9) / 65536)
11020 LET R0 = Y(S, 9) - 65536 * R1
11025 GOTO 11390
11030 LET V = 4
11035 LET R1 = 3
11040 GOTO 11390
11045 IF S < -4 THEN 11390
11050 REM pi inf nan eps (LANGUAGE 10.1; bits of DESIGN 3.5.5)
11055 LET V = 2
11060 LET R3 = VAL(SEG$("16393327523276015536", 5 * (-S) - 4, 5 * (-S)))
11065 IF S <> -1 THEN 11390
11070 LET R2 = 8699
11075 LET R1 = 21572
11080 LET R0 = 11544
11085 GOTO 11390
11090 LET G = N(J, 7)
11095 IF N(G, 0) <> 25 THEN 11150
11100 LET H = M(G, 5)
11105 IF C(H, 1) <> 32768 THEN 11150
11110 IF C(H, 2) + C(H, 3) + C(H, 4) <> 0 THEN 11150
11115 REM -2^63: the i64 pattern #8000000000000000, or the f64 -2^63
11120 LET V = 1
11125 LET R3 = 32768
11130 IF M(J, 1) <> 4 THEN 11390
11135 LET V = 2
11140 LET R3 = 50144
11145 GOTO 11390
11150 LET V = W(P0 + 1)
11155 IF V = 1 THEN 11190
11160 IF V = 2 THEN 11180
11165 IF V = 4 THEN 11260
11170 LET V = 0
11175 GOTO 11390
11180 CALL "FENEG": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), R3, R2, R1, R0
11185 GOTO 11390
11190 CALL "LMNEG": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), R3, R2, R1, R0, Z
11195 IF Z = 0 THEN 11390
11200 REM -(-2^63) overflows: an error at this node
11205 LET V = 4
11210 LET R0 = J
11215 LET R1 = 1
11220 GOTO 11390
11225 LET V = W(P0 + 1)
11230 IF V = 4 THEN 11260
11235 IF V = 3 THEN 11250
11240 LET V = 0
11245 GOTO 11390
11250 LET R0 = 1 - W(P0 + 5)
11255 GOTO 11390
11260 REM an error value passes up unchanged
11265 LET R3 = W(P0 + 2)
11270 LET R2 = W(P0 + 3)
11275 LET R1 = W(P0 + 4)
11280 LET R0 = W(P0 + 5)
11285 GOTO 11390
11290 REM pow(x, y) and sqrt(x) (F = 1): x at W(P0+6..), y at W(P0+11..) after the callee name's
11295 REM slot; an error operand passes up, the first one first
11300 IF F = 0 THEN 11390
11302 IF M(N(J, 7), 2) = -X(41) THEN 11312
11304 IF M(N(J, 7), 2) <> -X(39) THEN 11390
11306 LET Q9 = 5
11308 IF W(P0 + 6) = 4 THEN 11355
11310 GOTO 11320
11312 REM sqrt(x): the correctly rounded square root (FESQR, DESIGN 2.8)
11313 LET Q9 = 5
11314 IF W(P0 + 6) = 4 THEN 11355
11315 IF W(P0 + 6) <> 2 THEN 11390
11316 CALL "FESQR": W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11318 GOTO 11345
11320 LET Q9 = 10
11325 IF W(P0 + 11) = 4 THEN 11355
11330 IF W(P0 + 6) <> 2 THEN 11390
11335 IF W(P0 + 11) <> 2 THEN 11390
11340 CALL "FEPOW": Q(), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), W(P0 + 12), W(P0 + 13), W(P0 + 14), W(P0 + 15), R3, R2, R1, R0
11345 LET V = 2
11350 GOTO 11390
11355 LET V = 4
11360 LET R3 = W(P0 + Q9 + 2)
11365 LET R2 = W(P0 + Q9 + 3)
11370 LET R1 = W(P0 + Q9 + 4)
11375 LET R0 = W(P0 + Q9 + 5)
11380 GOTO 11390
11381 CALL "evs": N(), M(), Y(), W(), X(), X$(), S$(), G$(), J, P0, B9, F, V, R0
11382 GOTO 11390
11383 IF W(P0 + 1) + W(P0 + 6) = 10 THEN 11381
11385 CALL "evbin": N(), M(), W(), Q(), J, P0, F, V, R3, R2, R1, R0
11390 IF M(J, 7) <> 1 THEN 11410
11395 IF V <> 1 THEN 11410
11400 CALL "FEFRI": R3 + 0, R2 + 0, R1 + 0, R0 + 0, R3, R2, R1, R0, Z
11405 LET V = 2
11410 LET P = P0
11415 IF P + 5 < X(12) - 2 THEN 11435
11420 CALL "fatal": N(), X(), X$(), J, "nesting"
11425 LET V = 0
11430 GOTO 11470
11435 LET W(P + 1) = V
11440 LET W(P + 2) = R3
11445 LET W(P + 3) = R2
11450 LET W(P + 4) = R1
11455 LET W(P + 5) = R0
11460 LET P = P + 5
11465 NEXT J
11470 LET K = W(B9 + 1)
11495 IF V <> 0 THEN 11505
11500 LET K = 0
11505 SUBEND
11510 REM ---- evbin: the value of binary node J from its operands at W(P0+1..P0+10) (see evx): an
11515 REM error operand passes up (the left one first); && and || decided by the left operand ignore
11520 REM the right one; a powk by the pinned multiplications of LANGUAGE 6.5; with F = 1 another ^ by
11525 REM FEPOW (Q() the mtab words, DESIGN 4.10.5) ---------------------
11530 SUB "evbin": N(), M(), W(), Q(), J, P0, F, V, R3, R2, R1, R0
11535 LET V = 0
11540 LET U = W(P0 + 1)
11545 LET U2 = W(P0 + 6)
11550 LET O = N(J, 1)
11555 LET Q = 0
11560 IF U = 4 THEN 11985
11565 IF O < 16 THEN 11600
11570 REM && (16) and || (17): false && x is false, true || x is true, whatever x is
11575 IF U <> 3 THEN 11600
11580 IF W(P0 + 5) <> O - 16 THEN 11600
11585 LET V = 3
11590 LET R0 = O - 16
11595 GOTO 12180
11600 LET Q = 5
11605 IF M(J, 8) > 0 THEN 12020
11610 IF U2 = 4 THEN 11985
11615 IF U = 0 THEN 12180
11620 IF U <> U2 THEN 12180
11625 IF O < 8 THEN 11785
11630 IF U = 3 THEN 11685
11635 REM comparisons of two i64 or two f64 (LANGUAGE 6.4: NaN compares false except !=)
11640 IF O > 13 THEN 12180
11645 IF U = 2 THEN 11660
11650 CALL "LMCMP": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), Z
11655 GOTO 11665
11660 CALL "FECMP": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), Z
11665 REM Z -1 0 1 or 2 (unordered); the result of eq ne lt le gt ge in that order of Z
11670 LET V = 3
11675 LET R0 = VAL(SEG$("010010111000110000100110", 4 * (O - 8) + Z + 2, 4 * (O - 8) + Z + 2))
11680 GOTO 12180
11685 REM bool: == != & | && || (a decided && or || returned above)
11690 IF O = 8 THEN 11735
11695 IF O = 9 THEN 11760
11700 IF O < 14 THEN 12180
11705 LET V = 3
11710 LET R0 = W(P0 + 5) * W(P0 + 10)
11715 IF O = 14 THEN 12180
11720 IF O = 16 THEN 12180
11725 LET R0 = W(P0 + 5) + W(P0 + 10) - R0
11730 GOTO 12180
11735 LET V = 3
11740 LET R0 = 1
11745 IF W(P0 + 5) = W(P0 + 10) THEN 12180
11750 LET R0 = 0
11755 GOTO 12180
11760 LET V = 3
11765 LET R0 = 0
11770 IF W(P0 + 5) = W(P0 + 10) THEN 12180
11775 LET R0 = 1
11780 GOTO 12180
11785 IF O = 6 THEN 11960
11790 IF O > 5 THEN 12180
11795 IF U = 3 THEN 12180
11800 IF U = 2 THEN 11900
11805 ON O GOTO 11810, 11820, 11830, 12180, 11840
11810 CALL "LMADD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
11815 GOTO 11860
11820 CALL "LMSUB": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
11825 GOTO 11860
11830 CALL "LMMUL": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
11835 GOTO 11860
11840 CALL "LMMOD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0, Z
11845 REM a zero divisor (E = 2) is an error at this node
11850 IF Z = 0 THEN 11860
11855 LET Z = 2
11860 LET V = 1
11865 IF Z = 0 THEN 12180
11870 LET V = 4
11875 LET R1 = Z
11880 LET R0 = J
11885 LET R2 = 0
11890 LET R3 = 0
11895 GOTO 12180
11900 ON O GOTO 11905, 11915, 11925, 11935, 11945
11905 CALL "FEADD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11910 GOTO 11950
11915 CALL "FESUB": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11920 GOTO 11950
11925 CALL "FEMUL": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11930 GOTO 11950
11935 CALL "FEDIV": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11940 GOTO 11950
11945 CALL "FEMOD": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11950 LET V = 2
11955 GOTO 12180
11960 REM a ^ that is not a powk, in a const item (F = 1): the run time's pow (DESIGN 3.5.5)
11965 IF F = 0 THEN 12180
11970 IF U <> 2 THEN 12180
11975 CALL "FEPOW": Q(), W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 7), W(P0 + 8), W(P0 + 9), W(P0 + 10), R3, R2, R1, R0
11980 GOTO 11950
11985 REM the error of the operand at W(P0+Q+1..)
11990 LET V = 4
11995 LET R3 = W(P0 + Q + 2)
12000 LET R2 = W(P0 + Q + 3)
12005 LET R1 = W(P0 + Q + 4)
12010 LET R0 = W(P0 + Q + 5)
12015 GOTO 12180
12020 REM x^0 = 1, x^1 = x, x^2 = x*x, x^3 = (x*x)*x, x^4 = (x*x)*(x*x), x^-k = 1/(x^k)
12025 IF U <> 2 THEN 12180
12030 LET K = M(J, 8) - 10
12035 LET K1 = ABS(K)
12040 LET R3 = W(P0 + 2)
12045 LET R2 = W(P0 + 3)
12050 LET R1 = W(P0 + 4)
12055 LET R0 = W(P0 + 5)
12060 IF K1 > 0 THEN 12090
12065 LET R3 = 16368
12070 LET R2 = 0
12075 LET R1 = 0
12080 LET R0 = 0
12085 GOTO 12175
12090 IF K1 = 1 THEN 12145
12095 CALL "FEMUL": W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), Q3, Q2, Q1, Q0
12100 LET R3 = Q3
12105 LET R2 = Q2
12110 LET R1 = Q1
12115 LET R0 = Q0
12120 IF K1 = 2 THEN 12145
12125 IF K1 = 4 THEN 12140
12130 CALL "FEMUL": Q3, Q2, Q1, Q0, W(P0 + 2), W(P0 + 3), W(P0 + 4), W(P0 + 5), R3, R2, R1, R0
12135 GOTO 12145
12140 CALL "FEMUL": Q3, Q2, Q1, Q0, Q3, Q2, Q1, Q0, R3, R2, R1, R0
12145 IF K >= 0 THEN 12175
12150 CALL "FEDIV": 16368, 0, 0, 0, R3, R2, R1, R0, Q3, Q2, Q1, Q0
12155 LET R3 = Q3
12160 LET R2 = Q2
12165 LET R1 = Q1
12170 LET R0 = Q0
12175 LET V = 2
12180 SUBEND
12185 REM ---- cval: the value of const item S (LANGUAGE 7.2, DESIGN 3.4.1): Y(S,7) 1 i64, 2 f64, 3
12190 REM bool (limbs packed in Y(S,8), Y(S,9); bool: Y(S,8) 0 or 1), 4 str (G$(cid)), 5 none, 6 failed; an i64
12195 REM overflow or zero divisor (rcne) is Y(S,4) 1 or 2 at the operator node Y(S,9) ------------
12200 SUB "cval": N(), M(), Y(), C(), W(), X(), X$(), Q(), S$(), G$(), S
12205 LET Y(S, 7) = 6
12210 CALL "cexp": N(), Y(), S, E
12235 CALL "evx": N(), M(), Y(), C(), W(), X(), X$(), Q(), S$(), G$(), E, 1, K
12236 LET A3 = W(X(11) + 2)
12237 LET A2 = W(X(11) + 3)
12238 LET A1 = W(X(11) + 4)
12239 LET A0 = W(X(11) + 5)
12240 IF K > 0 THEN 12260
12245 REM not a constant value
12250 LET Y(S, 7) = 5
12255 GOTO 12355
12260 IF K < 4 THEN 12300
12262 IF K = 5 THEN 12290
12265 REM a poisoned operand (A1 = 3) gives no value; an overflow or zero divisor is rcne
12270 IF A1 = 3 THEN 12355
12275 LET Y(S, 4) = A1
12280 LET Y(S, 9) = A0
12285 GOTO 12355
12288 REM a str value (evs): its bytes in G$(cid), the constant rcns (DESIGN 3.4.2)
12290 LET Y(S, 7) = 4
12292 LET G$(Y(S, 5)) = G$(50001)
12294 GOTO 12355
12300 LET Y(S, 7) = K
12305 LET Y(S, 8) = A0
12310 IF K = 3 THEN 12355
12315 LET Y(S, 8) = A3 * 65536 + A2
12320 LET Y(S, 9) = A1 * 65536 + A0
12355 SUBEND
