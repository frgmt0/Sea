9595 REM ---- ck_expr: the expression subtree E, bottom-up: nodes M(E,0)..E are its post-order, so
9600 REM every child is typed before its parent (no recursion over expressions). M(J,3) = the
9605 REM number of errors before node J (for the printf rule of DESIGN 2.6.2).
9610 SUB "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
9615 FOR J = M(E, 0) TO E
9620 LET M(J, 3) = X(9)
9625 LET M(J, 1) = 0
9630 LET M(J, 7) = 0
9635 LET M(J, 8) = 0
9640 LET K = N(J, 0)
9645 IF K < 25 THEN 9905
9650 ON K - 24 GOTO 9655, 9665, 9675, 9740, 9740, 9750, 9830, 9760, 9760, 9770, 9780, 9790, 9800, 9810, 9820, 9905, 9890, 9860, 9840, 9860, 9905, 9870, 9880, 9905, 9900
9655 LET M(J, 1) = -1
9660 GOTO 9905
9665 LET M(J, 1) = 4
9670 GOTO 9905
9675 REM a string literal is only allowed as an argument of printf (phase 1, DESIGN 2.6.2)
9680 LET P = N(J, 9)
9685 IF N(P, 0) <> 35 THEN 9720
9690 LET G = N(P, 7)
9695 IF N(G, 0) <> 30 THEN 9720
9700 IF S$(N(G, 6)) <> "printf" THEN 9720
9705 IF LEN(S$(N(G, 6))) <> 6 THEN 9720
9710 LET M(J, 1) = 5
9715 GOTO 9905
9720 REM reported here; the str type stays, so a str local is reported at its name too
9725 LET M(J, 1) = 5
9730 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
9735 GOTO 9905
9740 LET M(J, 1) = 2
9745 GOTO 9905
9750 CALL "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9755 GOTO 9905
9760 CALL "ck_un": N(), M(), T(), C(), X(), X$(), J
9765 GOTO 9905
9770 CALL "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9775 GOTO 9905
9780 CALL "ck_call": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9785 GOTO 9905
9790 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "named arguments", "", "", 1
9795 GOTO 9905
9800 LET M(J, 1) = M(N(J, 7), 1)
9805 GOTO 9905
9810 CALL "ck_conv": N(), M(), T(), C(), X(), X$(), J
9815 GOTO 9905
9820 CALL "ck_idx": N(), M(), T(), C(), X(), X$(), J
9825 GOTO 9905
9830 CALL "ck_dol": N(), M(), X(), J
9835 GOTO 9905
9840 REM a view (.T .flat .col .row, LANGUAGE 5.6) is from 4e; any other field access from 4g
9845 LET Q$ = S$(N(J, 6))
9850 IF LEN(Q$) > 4 THEN 9870
9855 IF POS("|T|flat|col|row|", "|" & Q$ & "|") = 0 THEN 9870
9860 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "arrays", "", "", 1
9865 GOTO 9905
9870 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "structs", "", "", 1
9875 GOTO 9905
9880 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "records", "", "", 1
9885 GOTO 9905
9890 CALL "ck_rng": N(), M(), T(), C(), X(), X$(), J
9895 GOTO 9905
9900 CALL "ck_ifx": N(), M(), T(), C(), X(), X$(), J
9905 NEXT J
9910 SUBEND
9915 REM ---- ck_name: name J used as a value (LANGUAGE 7.2): local, constant or pi inf nan eps; the
9920 REM callee of a call and an assignment or ref target are left to their parent; what the name
9925 REM denotes is the rname's (rsv) ----------------------------------------------------------
9930 SUB "ck_name": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
9935 LET Q = N(J, 6)
9940 LET P = N(J, 9)
9945 CALL "rsv": N(), Y(), X(), X$(), S$(), J, R
9950 LET M(J, 2) = R
9955 LET Z = 0
9960 IF N(P, 0) <> 35 THEN 9980
9965 IF N(P, 7) <> J THEN 9980
9970 IF R <> 0 THEN 10105
9975 GOTO 10100
9980 IF N(P, 0) <> 13 THEN 9990
9985 IF N(P, 7) = J THEN 10005
9990 IF N(P, 0) <> 14 THEN 10000
9995 IF N(J, 8) <> 0 THEN 10005
10000 IF N(P, 0) <> 37 THEN 10010
10005 LET Z = 1
10010 IF R = 0 THEN 10100
10015 IF R < 0 THEN 10080
10020 IF Y(R, 0) = 4 THEN 10040
10025 IF Y(R, 0) = 2 THEN 10050
10030 IF Z = 1 THEN 10105
10035 GOTO 10100
10040 LET M(J, 1) = Y(R, 2)
10045 GOTO 10105
10050 IF Y(R, 4) = 2 THEN 10070
10055 REM constants are checked after those they name (ck_cord): this one is on a cycle
10060 CALL "er": N(), X(), X$(), J, "NOT_CONSTANT", "", "", "", 0
10065 GOTO 10105
10070 LET M(J, 1) = Y(R, 2)
10075 GOTO 10105
10080 IF R < -4 THEN 10095
10085 LET M(J, 1) = 4
10090 GOTO 10105
10095 IF Z = 1 THEN 10105
10100 CALL "er": N(), X(), X$(), J, "UNDECLARED", S$(Q), "", "", 1
10105 SUBEND
10110 REM ---- ck_un: unary - and ! (LANGUAGE 6.4, 6.5); -2^63 is one constant (DESIGN 3.5.5); on an
10115 REM array (element-wise) from 4e ----------------------------------------------------------
10120 SUB "ck_un": N(), M(), T(), C(), X(), X$(), J
10125 LET A = N(J, 7)
10130 CALL "vu": N(), M(), T(), X(), X$(), A, D
10135 IF D = 0 THEN 10300
10140 REM an array operand: its element type must suit the operator; then from 4e (arrays)
10145 CALL "elt": T(), D, E, K9
10150 IF K9 = 0 THEN 10195
10155 IF E < 2 THEN 10195
10160 IF E > 4 THEN 10195
10165 IF N(J, 0) = 33 THEN 10180
10170 IF E = 2 THEN 10195
10175 GOTO 10185
10180 IF E <> 2 THEN 10195
10185 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "arrays", "", "", 1
10190 GOTO 10300
10195 IF N(J, 0) = 33 THEN 10270
10200 IF D = -1 THEN 10230
10205 IF D = 3 THEN 10260
10210 IF D = 4 THEN 10260
10215 CALL "tyn": T(), D, A$
10220 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "-", A$, "", 2
10225 GOTO 10300
10230 IF N(A, 0) <> 25 THEN 10260
10235 LET R0 = M(A, 5)
10240 IF C(R0, 1) <> 32768 THEN 10260
10245 IF C(R0, 2) + C(R0, 3) + C(R0, 4) <> 0 THEN 10260
10250 REM the operand 2^63: the neg is written as the constant -2^63, its operand is not written
10255 LET M(A, 8) = -A
10260 LET M(J, 1) = D
10265 GOTO 10300
10270 IF D = 2 THEN 10260
10275 IF D <> -1 THEN 10290
10280 CALL "stl": N(), M(), C(), X(), X$(), A, 3
10285 LET D = 3
10290 CALL "tyn": T(), D, A$
10295 CALL "er": N(), X(), X$(), J, "BAD_OPERAND", "!", A$, "", 2
10300 SUBEND
10305 REM ---- num2: operands A, B (types G1, G2) of a numeric operator: untyped constants take the
10310 REM other operand's type (i64 when both are untyped), the i64 side of a mixed pair is converted;
10315 REM Z = 1 when an operand is not numeric; R the common type (LANGUAGE 4.2) -----------------
10320 SUB "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
10325 LET Z = 0
10330 LET R = 0
10335 LET U = G1
10340 LET V = G2
10345 IF U <> -1 THEN 10375
10350 LET D = 3
10355 IF V <> 4 THEN 10365
10360 LET D = 4
10365 CALL "stl": N(), M(), C(), X(), X$(), A, D
10370 LET U = D
10375 IF V <> -1 THEN 10405
10380 LET D = 3
10385 IF U <> 4 THEN 10395
10390 LET D = 4
10395 CALL "stl": N(), M(), C(), X(), X$(), B, D
10400 LET V = D
10405 IF U < 3 THEN 10465
10410 IF U > 4 THEN 10465
10415 IF V < 3 THEN 10465
10420 IF V > 4 THEN 10465
10425 LET R = U
10430 IF U = V THEN 10470
10435 LET R = 4
10440 IF U = 4 THEN 10455
10445 LET M(A, 7) = 1
10450 GOTO 10470
10455 LET M(B, 7) = 1
10460 GOTO 10470
10465 LET Z = 1
10470 SUBEND
10475 REM ---- ck_bin: binary operator J (LANGUAGE 6.1-6.6, Appendix B; phase 1: scalars) ----------
10480 SUB "ck_bin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
10485 LET K1 = 0
10490 LET K2 = 0
10495 LET A = N(J, 7)
10500 LET B = N(A, 8)
10505 LET O = N(J, 1)
10510 CALL "vu": N(), M(), T(), X(), X$(), A, G1
10515 CALL "vu": N(), M(), T(), X(), X$(), B, G2
10520 IF G1 = 0 THEN 10985
10525 IF G2 = 0 THEN 10985
10530 REM an array operand: && and || take scalars only, @ is from phase 8 (vector @ vector is no
10535 REM product); an element-wise operator is checked on the element types (an untyped constant
10540 REM takes the other element type), then reported as from 4e (arrays), or a vector with a
10545 REM matrix (LANGUAGE 6.2-6.4)
10550 CALL "elt": T(), G1, E1, K1
10555 CALL "elt": T(), G2, E2, K2
10560 IF K1 + K2 = 0 THEN 10640
10565 IF O > 15 THEN 10950
10570 IF O <> 7 THEN 10630
10575 IF K1 = 0 THEN 10950
10580 IF K2 = 0 THEN 10950
10585 IF E1 < 3 THEN 10950
10590 IF E1 > 4 THEN 10950
10595 IF E2 < 3 THEN 10950
10600 IF E2 > 4 THEN 10950
10605 IF K1 + K2 > 2 THEN 10620
10610 CALL "er": N(), X(), X$(), J, "MATMUL_VECTORS", "", "", "", 0
10615 GOTO 10985
10620 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "@", "", "", 1
10625 GOTO 10985
10630 LET G1 = E1
10635 LET G2 = E2
10640 REM + and comparisons on str are phase 2 (DESIGN 2.6.2)
10645 IF G1 = 5 THEN 10940
10650 IF G2 = 5 THEN 10940
10655 ON O GOTO 10660, 10660, 10660, 10700, 10755, 10785, 10950, 10880, 10880, 10900, 10900, 10900, 10900, 10920, 10920, 10920, 10920
10660 IF G1 <> -1 THEN 10680
10665 IF G2 <> -1 THEN 10680
10670 LET M(J, 1) = -1
10675 GOTO 10985
10680 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
10685 IF Z = 1 THEN 10950
10690 LET M(J, 1) = R
10695 GOTO 10985
10700 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
10705 IF Z = 1 THEN 10950
10710 REM / divides f64 values: both i64 operands are converted (LANGUAGE 6.5)
10715 LET M(A, 7) = 0
10720 LET M(B, 7) = 0
10725 IF M(A, 1) <> 3 THEN 10735
10730 LET M(A, 7) = 1
10735 IF M(B, 1) <> 3 THEN 10745
10740 LET M(B, 7) = 1
10745 LET M(J, 1) = 4
10750 GOTO 10985
10755 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
10760 IF Z = 1 THEN 10950
10765 LET M(J, 1) = R
10770 IF R = 3 THEN 10985
10775 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "f64 %", "", "", 1
10780 GOTO 10985
10785 IF G1 = 2 THEN 10950
10790 IF G1 > 4 THEN 10950
10795 IF G2 = 2 THEN 10950
10800 IF G2 > 4 THEN 10950
10805 REM ^ is f64: an i64 or untyped operand is converted (LANGUAGE 4.2 (d), 6.5)
10810 IF G1 <> -1 THEN 10820
10815 CALL "stl": N(), M(), C(), X(), X$(), A, 4
10820 IF G1 <> 3 THEN 10830
10825 LET M(A, 7) = 1
10830 IF G2 <> -1 THEN 10840
10835 CALL "stl": N(), M(), C(), X(), X$(), B, 4
10840 IF G2 <> 3 THEN 10850
10845 LET M(B, 7) = 1
10850 LET M(J, 1) = 4
10855 REM powk k where sea.res has rpowk k (DESIGN 3.4.1 "Constant exponents"), else bin pow
10860 IF N(J, 3) = 0 THEN 10985
10865 LET M(J, 8) = N(J, 2) + 10
10870 LET M(M(B, 0), 8) = -B
10875 GOTO 10985
10880 IF G1 <> 2 THEN 10900
10885 IF G2 <> 2 THEN 10900
10890 LET M(J, 1) = 2
10895 GOTO 10985
10900 CALL "num2": N(), M(), C(), X(), X$(), A, B, G1, G2, R, Z
10905 IF Z = 1 THEN 10950
10910 LET M(J, 1) = 2
10915 GOTO 10985
10920 IF G1 <> 2 THEN 10950
10925 IF G2 <> 2 THEN 10950
10930 LET M(J, 1) = 2
10935 GOTO 10985
10940 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
10945 GOTO 10985
10950 CALL "fin": N(), M(), C(), X(), X$(), A
10955 CALL "fin": N(), M(), C(), X(), X$(), B
10960 CALL "opn": O, A$
10965 CALL "tyn": T(), M(A, 1), B$
10970 CALL "tyn": T(), M(B, 1), C$
10975 CALL "er": N(), X(), X$(), J, "BAD_OPERANDS", A$, B$, C$, 3
10980 LET M(J, 1) = 0
10985 IF K1 + K2 = 0 THEN 11025
10990 IF M(J, 1) = 0 THEN 11025
10995 LET M(J, 1) = 0
11000 IF K1 * K2 = 0 THEN 11020
11005 IF K1 = K2 THEN 11020
11010 CALL "er": N(), X(), X$(), J, "VEC_MAT", "", "", "", 0
11015 GOTO 11025
11020 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "arrays", "", "", 1
11025 SUBEND
11030 REM ---- ck_ifx: if expression J (LANGUAGE 6.10, 4.2 (f)) --------------------------------------
11035 SUB "ck_ifx": N(), M(), T(), C(), X(), X$(), J
11040 LET E = N(J, 7)
11045 LET A = N(E, 8)
11050 LET B = N(A, 8)
11055 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
11060 CALL "vu": N(), M(), T(), X(), X$(), A, G1
11065 CALL "vu": N(), M(), T(), X(), X$(), B, G2
11070 IF G1 = 0 THEN 11170
11075 IF G2 = 0 THEN 11170
11080 IF G1 <> -1 THEN 11110
11085 LET D = 3
11090 IF G2 <> 4 THEN 11100
11095 LET D = 4
11100 CALL "stl": N(), M(), C(), X(), X$(), A, D
11105 LET G1 = D
11110 IF G2 <> -1 THEN 11140
11115 LET D = 3
11120 IF G1 <> 4 THEN 11130
11125 LET D = 4
11130 CALL "stl": N(), M(), C(), X(), X$(), B, D
11135 LET G2 = D
11140 IF G1 = G2 THEN 11165
11145 CALL "tyn": T(), G1, A$
11150 CALL "tyn": T(), G2, B$
11155 CALL "er": N(), X(), X$(), B, "TYPE_MISMATCH", A$, B$, "", 2
11160 GOTO 11170
11165 LET M(J, 1) = G1
11170 SUBEND
11175 REM ---- ck_conv: f64(x), i64(x) of bool, i64, f64 (LANGUAGE 10.1; lib nodes, DESIGN 3.5.5) -----
11180 SUB "ck_conv": N(), M(), T(), C(), X(), X$(), J
11185 LET A = N(J, 7)
11190 LET O = N(J, 1)
11195 IF O < 3 THEN 11210
11200 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "strings", "", "", 1
11205 GOTO 11300
11210 CALL "vu": N(), M(), T(), X(), X$(), A, D
11215 IF D = 0 THEN 11300
11220 IF D <> -1 THEN 11240
11225 REM an untyped argument is i64 (both conversions accept i64, LANGUAGE 4.2)
11230 CALL "stl": N(), M(), C(), X(), X$(), A, 3
11235 LET D = 3
11240 REM bool, i64 and f64 (the identity too: f64(2.5), i64(7) in tests/programs/op_cvt); of an
11245 REM array of these from 4e (arrays, at the conv node)
11250 CALL "elt": T(), D, E, K
11255 IF E < 2 THEN 11280
11260 IF E > 4 THEN 11280
11265 IF K = 0 THEN 11295
11270 CALL "er": N(), X(), X$(), J, "NOT_SUPPORTED", "arrays", "", "", 1
11275 GOTO 11300
11280 CALL "tyn": T(), D, B$
11285 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", SEG$("f64i64", 3 * O - 2, 3 * O), B$, "", 2
11290 GOTO 11300
11295 LET M(J, 1) = 5 - O
11300 SUBEND
11305 REM ---- ck_rng: a range J (a for's, an index, a value): i64 bounds and step; type i64[] --------
11310 SUB "ck_rng": N(), M(), T(), C(), X(), X$(), J
11315 LET A = N(J, 7)
11320 IF A = 0 THEN 11375
11325 CALL "vu": N(), M(), T(), X(), X$(), A, D
11330 IF D <> -1 THEN 11345
11335 CALL "stl": N(), M(), C(), X(), X$(), A, 3
11340 LET D = 3
11345 IF D = 3 THEN 11365
11350 IF D = 0 THEN 11365
11355 CALL "tyn": T(), D, B$
11360 CALL "er": N(), X(), X$(), A, "TYPE_MISMATCH", "i64", B$, "", 2
11365 LET A = N(A, 8)
11370 GOTO 11320
11375 CALL "tarr": T(), N(), X(), X$(), 1, 3, R
11380 LET M(J, 1) = R
11385 SUBEND
11390 REM ---- rsv: R = what rname J denotes (DESIGN 3.4.1): a local of the current function X(14) (its
11395 REM row from the lid), a constant, function or struct (its item row), a predeclared name (-slot)
11400 REM or nothing (0) -------------------------------------------------------------------------
11405 SUB "rsv": N(), Y(), X(), X$(), S$(), J, R
11410 LET R = 0
11415 IF N(J, 1) = 0 THEN 11480
11420 LET H = N(J, 2)
11425 ON N(J, 1) GOTO 11430, 11440, 11450, 11460, 11470, 11480
11430 LET R = Y(X(14), 9) - 1 + H
11435 GOTO 11480
11440 LET R = X(31) + H
11445 GOTO 11480
11450 LET R = H
11455 GOTO 11480
11460 LET R = X(11) + H
11465 GOTO 11480
11470 CALL "pdx": X$(), S$(N(J, 6)), P
11475 LET R = -P
11480 SUBEND
11485 REM ---- ck_idx: index J, base[i] or base[i, j] (LANGUAGE 5.2): the base must be an array (else
11490 REM '%s cannot be indexed', at the index), one index per dimension (a whole-matrix mask aside);
11495 REM each index a scalar i64 (an untyped constant is i64), else 'index must be i64' at the
11500 REM index; a range, ':', an index vector or a mask is a selection, from 4e (arrays, at the
11505 REM index's node). The type of an index by scalars is the element type -----------------------
11510 SUB "ck_idx": N(), M(), T(), C(), X(), X$(), J
11515 LET B = N(J, 7)
11520 LET H = N(J, 1)
11525 CALL "vu": N(), M(), T(), X(), X$(), B, G
11530 IF G = 0 THEN 11730
11535 CALL "fin": N(), M(), C(), X(), X$(), B
11540 CALL "elt": T(), M(B, 1), E, K
11545 IF K > 0 THEN 11565
11550 CALL "tyn": T(), M(B, 1), A$
11555 CALL "er": N(), X(), X$(), J, "NOT_INDEXABLE", A$, "", "", 1
11560 GOTO 11730
11565 LET Z = 0
11570 LET A = N(B, 8)
11575 LET V1 = 0
11580 FOR I = 1 TO H
11585 IF N(A, 0) = 40 THEN 11655
11590 IF N(A, 0) = 41 THEN 11655
11595 CALL "vu": N(), M(), T(), X(), X$(), A, V
11600 IF V = 0 THEN 11660
11605 CALL "fin": N(), M(), C(), X(), X$(), A
11610 LET V = M(A, 1)
11615 LET V1 = V
11620 IF V = 3 THEN 11665
11625 CALL "elt": T(), V, E1, K1
11630 IF K1 = 0 THEN 11645
11635 IF E1 = 2 THEN 11655
11640 IF E1 = 3 THEN 11655
11645 CALL "er": N(), X(), X$(), A, "INDEX_I64", "", "", "", 0
11650 GOTO 11660
11655 CALL "er": N(), X(), X$(), A, "NOT_SUPPORTED", "arrays", "", "", 1
11660 LET Z = 1
11665 LET A = N(A, 8)
11670 NEXT I
11675 IF H = K THEN 11720
11680 REM A[M] with M of type bool[,] is the mask of the whole matrix
11685 IF K <> 2 THEN 11710
11690 IF H <> 1 THEN 11710
11695 IF V1 < 10 THEN 11710
11700 IF T(V1, 0) <> 2 THEN 11710
11705 IF T(V1, 1) = 2 THEN 11720
11710 CALL "er": N(), X(), X$(), J, "INDEX_COUNT", STR$(K), STR$(H), "", 2
11715 GOTO 11730
11720 IF Z = 1 THEN 11730
11725 LET M(J, 1) = E
11730 SUBEND
11735 REM ---- ck_dol: $ at node J: the extent of the dimension it indexes in the innermost enclosing
11740 REM index (LANGUAGE 5.3; pass 1 has reported a $ outside every index): i64, M(J,5) = its dim
11745 REM (0 or 1, the index's place); a $ without one is a bad record --------------------------
11750 SUB "ck_dol": N(), M(), X(), J
11755 LET M(J, 1) = 3
11760 LET G = J
11765 LET P = N(G, 9)
11770 IF P = 0 THEN 11845
11775 IF P = X(17) THEN 11845
11780 IF N(P, 0) <> 39 THEN 11835
11785 IF N(P, 7) = G THEN 11835
11790 REM G is an index of P: its place among P's children after the base
11795 LET D = 0
11800 LET Q = N(N(P, 7), 8)
11805 IF Q = G THEN 11825
11810 LET D = D + 1
11815 LET Q = N(Q, 8)
11820 GOTO 11805
11825 LET M(J, 5) = D
11830 GOTO 11850
11835 LET G = P
11840 GOTO 11765
11845 LET X(26) = 1
11850 SUBEND
