19400 REM ---- the reductions, sorting and searching of sub-phase 4f (DESIGN 2.6.2 step 4f and "Readings
19405 REM fixed by 4f", 3.5.5; LANGUAGE 8.1, 10.5, 10.6; Decisions 21, 39, 43): the named options dim:
19410 REM and desc:, the overloads of sum mean variance std max min argmax argmin nnz any all sort
19415 REM argsort find find_first find_last and their result types --------------------------------
19420 REM ---- ck_narg: named argument J (name: value) of a call. dim: of sum mean variance std max min
19425 REM any all nnz and desc: of sort argsort are checked here: a dim: value i64 (201), constant (237),
19430 REM 0 or 1 (262), in that order, at the value; a desc: value bool (201); then (value first, DESIGN
19435 REM 2.6.2) a name given twice is 225 at the second narg. Any other narg is 'not supported yet:
19440 REM named arguments'. M(J,1) the value's type (0 after an error), M(J,5) the dim value, which is
19445 REM then written as one ci (M(first node,8) = -J, em_expr) -----------------------------------
19450 SUB "ck_narg": N(), M(), Y(), T(), C(), S$(), X(), X$(), J
19455 LET M(J, 1) = 0
19460 LET V = N(J, 7)
19465 LET G = N(N(J, 9), 7)
19475 IF N(G, 0) <> 30 THEN 19510
19480 IF M(G, 2) >= -8 THEN 19510
19485 LET C$ = "|" & S$(N(G, 6)) & "|"
19490 IF S$(N(J, 6)) <> "dim" THEN 19500
19495 IF POS("|sum|mean|variance|std|max|min|any|all|nnz|", C$) > 0 THEN 19515
19500 IF S$(N(J, 6)) <> "desc" THEN 19510
19505 IF POS("|sort|argsort|", C$) > 0 THEN 19517
19510 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "named arguments", "", "", 1
19512 GOTO 19658
19515 LET Z = 1
19516 GOTO 19555
19517 LET Z = 2
19555 CALL "vu": N(), M(), T(), X(), X$(), V, D
19560 IF D = 0 THEN 19658
19565 IF D <> -1 THEN 19580
19570 CALL "stl": N(), M(), C(), X(), X$(), V, 3
19575 LET D = 3
19580 IF D = 4 - Z THEN 19595
19585 CALL "tyn": T(), D, A$
19590 CALL "er": N(), X(), X$(), V, "TYPE_MISMATCH", SEG$("i64 bool", 4 * Z - 3, 5 * Z - 2), A$, "", 2
19592 GOTO 19658
19595 IF Z = 2 THEN 19646
19605 CALL "cex": N(), M(), Y(), S$(), V, Q
19610 IF Q = 1 THEN 19620
19615 CALL "er": N(), X(), X$(), V, "NOT_CONSTANT", "", "", "", 0
19617 GOTO 19658
19620 CALL "dimv": N(), M(), Y(), C(), V, R, J9
19625 IF R < 0 THEN 19658
19630 IF R < 2 THEN 19645
19632 LET A$ = "DIM_VALUE"
19634 IF R = 2 THEN 19640
19636 LET V = J9
19637 LET A$ = "INT_OVERFLOW_C"
19638 IF R = 3 THEN 19640
19639 LET A$ = "INT_DIV_ZERO_C"
19640 CALL "er": N(), X(), X$(), V, A$, "", "", "", 0
19642 GOTO 19658
19645 LET M(J, 5) = R
19646 REM after its value: a name the call gave before (interned: one S$ index per name)
19647 LET A = N(G, 8)
19648 IF A = J THEN 19655
19649 IF N(A, 0) <> 36 THEN 19653
19650 IF N(A, 6) <> N(J, 6) THEN 19653
19651 CALL "er": N(), X(), X$(), J, "PARAM_TWICE", "", "", "", 0
19652 GOTO 19658
19653 LET A = N(A, 8)
19654 GOTO 19648
19655 IF Z = 2 THEN 19657
19656 LET M(M(V, 0), 8) = -J
19657 LET M(J, 1) = 4 - Z
19658 SUBEND
19660 REM ---- cex: Z = 1 when expression E is a constant expression (LANGUAGE 7.2: literals,
19665 REM str literals, constants, operators, pi inf nan eps, the calls sqrt and pow); an undeclared name counts as
19670 REM one (it is reported where it stands) -----------------------------------------------------
19675 SUB "cex": N(), M(), Y(), S$(), E, Z
19680 LET Z = 0
19685 FOR J = M(E, 0) TO E
19690 LET K = N(J, 0)
19695 IF K = 30 THEN 19730
19700 IF POS("|25|26|27|28|29|32|33|34|", "|" & STR$(K) & "|") > 0 THEN 19765
19705 IF K <> 35 THEN 19770
19710 LET H = N(J, 7)
19715 IF N(H, 0) <> 30 THEN 19770
19720 IF POS("|pow|sqrt|", "|" & S$(N(H, 6)) & "|") > 0 THEN 19765
19725 GOTO 19770
19730 IF M(J, 2) = 0 THEN 19765
19735 IF N(N(J, 9), 0) <> 35 THEN 19745
19740 IF N(N(J, 9), 7) = J THEN 19765
19745 IF M(J, 2) < 0 THEN 19760
19750 IF Y(M(J, 2), 0) = 2 THEN 19765
19755 GOTO 19770
19760 IF M(J, 2) < -4 THEN 19770
19765 NEXT J
19767 LET Z = 1
19770 SUBEND
19775 REM ---- dimv: the exact value of the i64 constant expression E (int literals, i64 constants,
19780 REM neg, add sub mul mod; LANGUAGE 6.5, 6.6): R 0 or 1 that value, 2 another value, 3 integer
19785 REM overflow or 4 integer division by zero at node J9 (the first failing operation in
19790 REM evaluation order), -1 a constant without a value (reported at its declaration). A stack of
19795 REM values: sign S(k,0) (1 or -1) and magnitude S(k,1..4) (16-bit limbs, most significant
19800 REM first); A B the operands' magnitudes, P the result's (P(0) 1 when it reaches 2^64), Z5 its sign
19805 SUB "dimv": N(), M(), Y(), C(), E, R, J9
19810 DIM S(99, 4), A(4), B(4), P(8), G(4)
19815 LET R = -1
19820 LET D = 0
19825 FOR J = M(E, 0) TO E
19830 LET K = N(J, 0)
19835 LET Q = M(J, 5)
19840 IF K = 25 THEN 19875
19845 IF K = 32 THEN 19925
19850 IF K = 34 THEN 19945
19855 IF K <> 30 THEN 20180
19860 LET Q = M(J, 2)
19862 IF Q < 1 THEN 20180
19865 IF Y(Q, 7) <> 1 THEN 20180
19870 LET Q = Y(Q, 8)
19875 REM push the C row Q (two's complement); a negative one as its magnitude 2^64 - value
19880 LET D = D + 1
19885 LET Z5 = 1
19890 FOR I = 1 TO 4
19895 LET A(I) = 0
19900 LET B(I) = C(Q, I)
19905 IF C(Q, 1) < 32768 THEN 19915
19910 LET B(I) = 65535 - C(Q, I)
19912 LET A(I) = INT(I / 4)
19913 LET Z5 = -1
19915 NEXT I
19920 GOSUB 20185
19922 GOTO 20125
19925 REM neg: of the literal 2^63 it is already the value -2^63 (DESIGN 3.5.5)
19930 IF M(N(J, 7), 8) < 0 THEN 20155
19935 LET S(D, 0) = -S(D, 0)
19940 GOTO 20140
19945 LET D = D - 1
19950 FOR I = 1 TO 4
19955 LET A(I) = S(D, I)
19960 LET B(I) = S(D + 1, I)
19965 NEXT I
19970 LET Z5 = S(D, 0)
19975 LET B0 = S(D + 1, 0)
19980 LET O = N(J, 1)
19985 IF O = 3 THEN 20035
19990 IF O = 5 THEN 20080
19995 IF O > 2 THEN 20180
20000 REM a + b, a - b: equal signs add the magnitudes, else the smaller is taken from the larger
20005 LET B0 = B0 * (3 - 2 * O)
20010 IF Z5 <> B0 THEN 20020
20012 GOSUB 20185
20014 GOTO 20125
20020 GOSUB 20215
20022 IF C9 >= 0 THEN 20028
20024 GOSUB 20265
20026 LET Z5 = B0
20028 GOSUB 20240
20030 GOTO 20125
20035 REM a * b: the product of the magnitudes, which must stay below 2^64
20040 FOR I = 1 TO 8
20045 LET P(I) = 0
20050 NEXT I
20052 FOR I = 1 TO 4
20054 FOR K = 1 TO 4
20056 LET P(I + K) = P(I + K) + A(I) * B(K)
20058 NEXT K
20060 NEXT I
20062 FOR I = 8 TO 2 STEP -1
20064 LET Q = INT(P(I) / 65536)
20066 LET P(I) = P(I) - 65536 * Q
20068 LET P(I - 1) = P(I - 1) + Q
20070 NEXT I
20072 LET P(0) = SGN(P(1) + P(2) + P(3) + P(4))
20074 FOR I = 1 TO 4
20075 LET P(I) = P(I + 4)
20076 NEXT I
20077 LET Z5 = Z5 * B0
20078 GOTO 20125
20080 REM a % b, floored: r = |a| mod |b| by shift and subtract, then |b| - r when r <> 0 and the
20082 REM signs differ; the result has the sign of b (LANGUAGE 6.6)
20084 IF B(1) + B(2) + B(3) + B(4) > 0 THEN 20090
20086 LET R = 4
20088 GOTO 20175
20090 FOR I = 1 TO 4
20092 LET G(I) = A(I)
20094 LET A(I) = 0
20096 NEXT I
20098 FOR I1 = 1 TO 4
20100 FOR I2 = 15 TO 0 STEP -1
20101 LET C0 = INT(G(I1) / 2 ^ I2) - 2 * INT(G(I1) / 2 ^ (I2 + 1))
20102 FOR Q = 4 TO 1 STEP -1
20103 LET A(Q) = 2 * A(Q) + C0
20104 LET C0 = INT(A(Q) / 65536)
20105 LET A(Q) = A(Q) - 65536 * C0
20106 NEXT Q
20107 GOSUB 20215
20108 IF C9 < 0 THEN 20113
20109 GOSUB 20240
20110 FOR Q = 1 TO 4
20111 LET A(Q) = P(Q)
20112 NEXT Q
20113 NEXT I2
20114 NEXT I1
20115 FOR Q = 1 TO 4
20116 LET P(Q) = A(Q)
20117 NEXT Q
20118 LET P(0) = 0
20119 IF P(1) + P(2) + P(3) + P(4) = 0 THEN 20123
20120 IF Z5 = B0 THEN 20123
20121 GOSUB 20265
20122 GOSUB 20240
20123 LET Z5 = B0
20125 REM the result (magnitude P, sign Z5) replaces the operands, within the range of i64
20127 IF P(0) > 0 THEN 20170
20129 LET S(D, 0) = Z5
20131 FOR I = 1 TO 4
20133 LET S(D, I) = P(I)
20135 NEXT I
20140 IF S(D, 1) < 32768 THEN 20155
20145 IF S(D, 0) > 0 THEN 20170
20150 IF S(D, 1) + S(D, 2) + S(D, 3) + S(D, 4) > 32768 THEN 20170
20155 NEXT J
20160 LET R = 2
20161 IF S(1, 1) + S(1, 2) + S(1, 3) > 0 THEN 20180
20162 IF S(1, 4) = 0 THEN 20165
20163 IF S(1, 4) <> 1 THEN 20180
20164 IF S(1, 0) < 0 THEN 20180
20165 LET R = S(1, 4)
20167 GOTO 20180
20170 LET R = 3
20175 LET J9 = J
20180 GOTO 20290
20185 REM -- P = A + B, P(0) the carry out of the top limb
20190 LET C0 = 0
20195 FOR L = 4 TO 1 STEP -1
20200 LET P(L) = A(L) + B(L) + C0
20205 LET C0 = INT(P(L) / 65536)
20207 LET P(L) = P(L) - 65536 * C0
20210 NEXT L
20212 LET P(0) = C0
20213 RETURN
20215 REM -- C9 = the sign of A - B (magnitudes)
20220 LET C9 = 0
20225 FOR L = 1 TO 4
20230 IF C9 <> 0 THEN 20235
20232 LET C9 = SGN(A(L) - B(L))
20235 NEXT L
20237 RETURN
20240 REM -- P = A - B for A >= B
20245 LET C0 = 0
20250 FOR L = 4 TO 1 STEP -1
20252 LET P(L) = A(L) - B(L) - C0
20254 LET C0 = 0
20256 IF P(L) >= 0 THEN 20260
20258 LET P(L) = P(L) + 65536
20259 LET C0 = 1
20260 NEXT L
20262 LET P(0) = 0
20263 RETURN
20265 REM -- exchange A and B
20270 FOR L = 1 TO 4
20275 LET Q = A(L)
20280 LET A(L) = B(L)
20285 LET B(L) = Q
20287 NEXT L
20288 RETURN
20290 SUBEND
20295 REM ---- lopt: of library call J, G9 its named arguments and D9 the first named dim (0 none) -----
20300 SUB "lopt": N(), S$(), J, G9, D9
20305 LET G9 = 0
20310 LET D9 = 0
20315 LET A = N(N(J, 7), 8)
20320 IF A = 0 THEN 20355
20325 IF N(A, 0) <> 36 THEN 20345
20330 LET G9 = G9 + 1
20335 IF D9 > 0 THEN 20345
20340 IF S$(N(A, 6)) <> "dim" THEN 20345
20342 LET D9 = A
20345 LET A = N(A, 8)
20350 GOTO 20320
20355 SUBEND
20360 REM ---- lred: the overloads of the 4f library call J of class Z (ck_lib: 16 sum max min, 17 mean
20365 REM variance std, 18 argmax argmin, 19 nnz, 20 any all, 21 sort, 22 argsort, 23 find, 24
20370 REM find_first find_last; 25 lower and 26 args: lstr) with H1 positional arguments, G9 named ones and the dim narg D9: one
20375 REM vector (with dim: one matrix) of f64 or i64 (19, 20, 23, 24: bool). D the result type, Z9 = 1
20380 REM for no overload. A dim: form is lib name.dim (M(J,9) 1) with a vector result, fixed-size of
20385 REM c (dim 0) or r (dim 1) elements for a fixed T[r,c]; sort and argsort of a fixed vector take
20390 REM a dyn (M(arg,5)), and without desc: the inserted cb 0 (M(J,9) 2; Decision 39, DESIGN 3.5.5)
20395 SUB "lred": N(), M(), T(), X(), X$(), J, Z, H1, G9, D9, D, Z9
20400 LET Z9 = 1
20405 LET D = 0
20407 IF Z < 25 THEN 20410
20408 CALL "lstr": N(), M(), T(), X(), X$(), J, Z, H1, D, Z9
20409 GOTO 20520
20410 IF H1 <> 1 THEN 20520
20415 LET A = N(N(J, 7), 8)
20420 CALL "shp": T(), M(A, 1), E, K, F, A0, B0
20425 IF K <> 1 + SGN(D9) THEN 20520
20430 LET S = VAL(SEG$("000403030200030303", 2 * Z - 31, 2 * Z - 30))
20435 IF POS("|19|20|23|24|", "|" & STR$(Z) & "|") = 0 THEN 20450
20440 IF E <> 2 THEN 20520
20445 GOTO 20470
20450 IF E <> 5 THEN 20465
20455 REM sort and argsort of a dynamic str vector (Decision 40, 4g-1); a str[] for any other is no overload
20460 IF Z > 20 THEN 20470
20465 IF E < 3 THEN 20520
20467 IF E > 4 THEN 20520
20470 IF S > 0 THEN 20480
20475 LET S = E
20480 IF Z < 21 THEN 20500
20482 IF Z > 23 THEN 20510
20484 CALL "tarr": T(), N(), X(), X$(), 1, S, 0, 0, D
20486 IF Z = 23 THEN 20515
20488 LET M(J, 9) = 2 - 2 * SGN(G9)
20490 IF F = 0 THEN 20515
20492 CALL "tarr": T(), N(), X(), X$(), 1, E, 0, 0, M(A, 5)
20494 GOTO 20515
20500 IF D9 = 0 THEN 20510
20502 LET M(J, 9) = 1
20504 CALL "tarr": T(), N(), X(), X$(), 1 + 2 * F, S, F * (A0 + (B0 - A0) * (1 - M(D9, 5))), 0, D
20506 GOTO 20515
20510 LET D = S
20515 LET Z9 = 0
20520 SUBEND
20525 REM ---- lerr: D = the result type of the 4f library call of class Z with an argument error or no
20530 REM overload, D9 its dim narg: i64, bool, f64 or i64[] where it does not depend on the
20535 REM arguments, else (sum max min sort and every dim: form) 0 (DESIGN 2.6.2); lower str, args str[] --
20540 SUB "lerr": T(), N(), X(), X$(), Z, D9, D
20545 LET D = VAL(SEG$("0004030302000000030500", 2 * Z - 31, 2 * Z - 30))
20550 IF Z > 20 THEN 20565
20555 IF Z = 18 THEN 20565
20560 LET D = D * (1 - SGN(D9))
20565 IF ABS(Z - 22.5) > 1 THEN 20572
20570 CALL "tarr": T(), N(), X(), X$(), 1, 3, 0, 0, D
20571 GOTO 20575
20572 IF Z <> 26 THEN 20575
20573 CALL "tarr": T(), N(), X(), X$(), 1, 5, 0, 0, D
20575 SUBEND
20580 REM ---- lpos: P$ = the position of the library call whose argument J takes a dyn (the fixed-size
20585 REM vector of sort and argsort: the dyn is at the call, DESIGN 3.5.5), else P$ unchanged --------
20590 SUB "lpos": N(), M(), J, P$
20595 LET P = N(J, 9)
20600 IF N(P, 0) <> 35 THEN 20620
20605 IF N(P, 7) = J THEN 20620
20610 IF M(N(P, 7), 2) >= 0 THEN 20620
20615 CALL "pos": N(), P, P$
20620 SUBEND
