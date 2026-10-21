1430 REM ---- table layouts of seacheck ---------------------------------------------------------
1435 REM N(i,0) kind 1-49 (sc_read's list: 1 prog 2 const 3 struct 5 fn 6 param 7 type 8 let 9 var
1440 REM 10 pname 11 pskip 12 ptuple 13 asg 14 tasg 15 cstmt 16 if 17 while 18 for 21 break 22
1445 REM continue 23 return 24 block 25 int 26 float 27 str 28 true 29 false 30 name 32 neg 33 not
1450 REM 34 bin 35 call 37 ref 38 conv 41 range 49 ifx ...); N(i,1..3) u and enum fields (for: npos in
1455 REM N(i,1..2)); N(i,4) F*1E9+L; N(i,5) column; N(i,6) string; N(i,7) first child; N(i,8) next sibling; N(i,9) parent.
1460 REM M(i,0) first node of the subtree (post-order range M(i,0)..i); M(i,1) type: -1 untyped
1465 REM integer constant, 0 error, 1 void, 2 bool, 3 i64, 4 f64, 5 str, 6-9 handles, >= 10 a T row;
1470 REM M(i,2) symbol (Y row, -p predeclared slot p, 0 none; pname, param, for: the local bound);
1475 REM M(i,3) errors recorded before the node was checked; M(i,4) pname: var rule f64 (1), return:
1480 REM tret (1); M(i,5) C row of a literal; M(i,6) children; M(i,7) cvt to f64 after the node (1);
1485 REM M(i,8) bin: powk k + 10, < 0: writing jumps past node -M(i,8) (em_expr); M(i,9) the
1490 REM statement ends every path with a return (1).
1495 REM Y(s,0) 1 fn 2 const 3 struct 4 local; Y(s,1) name; Y(s,2) type (fn: result); Y(s,3) node;
1500 REM Y(s,4) local: 1 let 2 var 3 for 4 par 5 ref par, fn: elemental, const: 0 1 2 (checked);
1505 REM Y(s,5) lid / fid / cid; Y(s,6) local: pname of a var-rule candidate, fn: np, const: ck_cord state; Y(s,7) fn: nr,
1510 REM const: value (cval: 0 not yet 1 i64 2 f64 3 none); Y(s,8) local: function, fn: last local row,
1515 REM const: C row of the value; Y(s,9) fn: first local row. Row 1 is .main, items follow.
1520 REM T(t,0) 1 tvec 7 ttuple 0 continuation; T(t,1) element or count; tuple components in the
1525 REM next rows, 9 per row (columns 0-8); T(t,9) the written id (DESIGN 3.5.1).
1530 REM W(1..) the value stack of evx; W(..199999) scope stack, pairs (name, symbol), marker -1; W(180001..)
1535 REM written types in id order (emission only, the scopes are empty then). X(1) nodes X(2) strings X(3)
1540 REM symbols X(4) last T row X(5) C rows X(6) key of the first error (0 none) X(7) its node X(8)
1545 REM its argument count X(9) errors recorded X(10) capacity overflow X(11) evx stack base X(12)
1550 REM scope stack top X(13) lids X(14) function X(15) loop depth X(16) var rule changed X(17)
1555 REM prog X(18) program file X(19) current node X(20)-X(25) LIM SYMBOLS TYPES CONSTS NODES
1560 REM STRINGS POWK X(27) emission mode X(28) types written X(29) top-level statements X(30)
1565 REM functions X(31) constants X(33) items X(34) FILE_VERSION X(35) LIM_DEC_FIELD X(36) X(37) npos of a symbols overflow X(38) types; C(r,0) 3 i64 4 f64, C(r,1..4) limbs; X$(1) error name, X$(2)-X$(4)
1570 REM its arguments, X$(10) predeclared names.
1575 REM ---- er: record error Q$ at node I (K arguments); the first in source order is kept ------
1580 SUB "er": N(), X(), X$(), I, Q$, A$, B$, C$, K
1585 LET X(9) = X(9) + 1
1590 IF X(10) = 1 THEN 1645
1595 LET Q = N(I, 4) * 10000 + N(I, 5)
1600 IF X(6) = 0 THEN 1610
1605 IF Q >= X(6) THEN 1645
1610 LET X(6) = Q
1615 LET X(7) = I
1620 LET X(8) = K
1625 LET X$(1) = Q$
1630 LET X$(2) = A$
1635 LET X$(3) = B$
1640 LET X$(4) = C$
1645 SUBEND
1650 REM ---- fatal: a capacity limit of DESIGN 2.7 is exceeded at node I (wins over every error) ---
1655 SUB "fatal": N(), X(), X$(), I, W$
1660 IF X(10) = 1 THEN 1695
1665 LET X(10) = 1
1670 LET X(6) = 1
1675 LET X(7) = I
1680 LET X(8) = 1
1685 LET X$(1) = "TOO_LARGE"
1690 LET X$(2) = W$
1695 SUBEND
1700 REM ---- intern: R = index of string Q$ in S$ (added if new; 0 if the table is full). G() (399989
1705 REM slots, at most half full) finds strings by a hash of the length and up to 32 bytes ----
1710 SUB "intern": S$(), X(), G(), Q$, R
1715 LET P9 = 399989
1720 LET L0 = LEN(Q$)
1725 LET V = L0 - P9 * INT(L0 / P9)
1730 LET S = 1
1735 IF L0 <= 32 THEN 1745
1740 LET S = INT(L0 / 32)
1745 FOR J = 1 TO L0 STEP S
1750 LET V = V * 263 + ASC(SEG$(Q$, J, J))
1755 LET V = V - P9 * INT(V / P9)
1760 NEXT J
1765 LET Q = V + 1
1770 LET R = G(Q)
1775 IF R = 0 THEN 1810
1780 IF LEN(S$(R)) <> L0 THEN 1790
1785 IF S$(R) = Q$ THEN 1845 ' equal lengths: = is exact
1790 LET Q = Q + 1
1795 IF Q <= P9 THEN 1770
1800 LET Q = 1
1805 GOTO 1770
1810 IF X(2) < X(24) THEN 1825
1815 LET R = 0
1820 GOTO 1845
1825 LET X(2) = X(2) + 1
1830 LET R = X(2)
1835 LET S$(R) = Q$
1840 LET G(Q) = R
1845 SUBEND
1850 REM ---- pdx: R = slot of predeclared name Q$ (1-4 constants, 5-8 handles, 9- functions) -----
1855 SUB "pdx": X$(), Q$, R
1860 LET R = 0
1865 IF LEN(Q$) > 10 THEN 1890
1870 IF LEN(Q$) = 0 THEN 1890
1875 LET P = POS(X$(10), "|" & Q$ & " ")
1880 IF P = 0 THEN 1890
1885 LET R = (P - 1) / 12 + 1
1890 SUBEND
1895 REM ---- lk: R = the symbol named Q (S$ index): scopes, then items, then predeclared (-slot) ---
1900 SUB "lk": Y(), W(), X(), X$(), S$(), Q, R
1905 LET R = 0
1910 FOR J = X(12) TO 199998 STEP 2
1915 IF W(J) <> Q THEN 1930
1920 LET R = W(J + 1)
1925 GOTO 1970
1930 NEXT J
1935 FOR J = 2 TO X(33)
1940 IF Y(J, 1) <> Q THEN 1955
1945 LET R = J
1950 GOTO 1970
1955 NEXT J
1960 CALL "pdx": X$(), S$(Q), P
1965 LET R = -P
1970 SUBEND
1975 REM ---- nsym: R = a new, cleared symbol row for the declaration at node I (capacity: program
1980 REM too large: symbols, reported at that declaration, fsym) ----------------------------
1985 SUB "nsym": N(), Y(), X(), X$(), I, R
1990 IF X(3) < X(20) THEN 2010
1995 CALL "fsym": N(), X(), X$(), I
2000 LET R = 0
2005 GOTO 2035
2010 LET X(3) = X(3) + 1
2015 LET R = X(3)
2020 FOR J = 0 TO 9
2025 LET Y(R, J) = 0
2030 NEXT J
2035 SUBEND
2040 REM ---- nloc: R = new local named Q, type D, mut U, declared by node I, bound in the scope;
2045 REM Z = 1 checks the binding (shadowing a predeclared name, a str local: DESIGN 2.6.2) ----
2050 SUB "nloc": N(), Y(), W(), X(), X$(), S$(), Q, D, U, I, Z, R
2055 CALL "nsym": N(), Y(), X(), X$(), I, R
2060 LET Y(R, 0) = 4
2065 LET Y(R, 1) = Q
2070 LET Y(R, 2) = D
2075 LET Y(R, 3) = I
2080 LET Y(R, 4) = U
2085 LET X(13) = X(13) + 1
2090 LET Y(R, 5) = X(13)
2095 LET Y(R, 8) = X(14)
2100 IF X(12) - 2 > X(11) THEN 2115
2105 CALL "fsym": N(), X(), X$(), I
2110 GOTO 2130
2115 LET X(12) = X(12) - 2
2120 LET W(X(12)) = Q
2125 LET W(X(12) + 1) = R
2130 IF Z = 0 THEN 2160
2135 CALL "pdx": X$(), S$(Q), P
2140 IF P = 0 THEN 2150
2145 CALL "er": N(), X(), X$(), I, "SHADOWS_PREDECLARED", "", "", "", 0
2150 IF D <> 5 THEN 2160
2155 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "strings", "", "", 1
2160 SUBEND
2165 REM ---- tyn: R$ = type Q written as in Sea source (DESIGN 2.6.2) -----------------------------
2170 SUB "tyn": T(), Q, R$
2175 IF Q < 10 THEN 2245
2180 IF T(Q, 0) = 1 THEN 2230
2185 LET R$ = "("
2190 FOR J = 1 TO T(Q, 1)
2195 CALL "tyn": T(), T(Q + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)), A$
2200 IF J = 1 THEN 2210
2205 LET R$ = R$ & ", "
2210 LET R$ = R$ & A$
2215 NEXT J
2220 LET R$ = R$ & ")"
2225 GOTO 2300
2230 CALL "tyn": T(), T(Q, 1), A$
2235 LET R$ = A$ & "[]"
2240 GOTO 2300
2245 LET A$ = "?|void|bool|i64|f64|str|Figure|Axes|Lu|Chol|"
2250 LET S = 1
2255 LET Q1 = Q
2260 IF Q1 >= 0 THEN 2270
2265 LET Q1 = 3
2270 FOR J = 0 TO Q1
2275 LET P = POS(A$, "|", S)
2280 IF J = Q1 THEN 2290
2285 LET S = P + 1
2290 NEXT J
2295 LET R$ = SEG$(A$, S, P - 1)
2300 SUBEND
2305 REM ---- tnew: R = the first of K new cleared T rows for one new type. LIM_TYPES counts types
2310 REM (X(38)), not rows; the rows of T always suffice (sc_lim: 2 per type and one more per 9
2315 REM tuple components, which are type nodes) ------------------------------------------------
2320 SUB "tnew": T(), N(), X(), X$(), K, R
2325 IF X(38) < X(21) THEN 2345
2330 CALL "fatal": N(), X(), X$(), X(19), "types"
2335 LET R = 0
2340 GOTO 2385
2345 LET X(38) = X(38) + 1
2350 LET R = X(4) + 1
2355 LET X(4) = X(4) + K
2360 FOR J = R TO X(4)
2365 FOR H = 0 TO 9
2370 LET T(J, H) = 0
2375 NEXT H
2380 NEXT J
2385 SUBEND
2390 REM ---- tvec: R = the type E[] (one id per structure, DESIGN 3.5.1) ---------------------------
2395 SUB "tvec": T(), N(), X(), X$(), E, R
2400 LET R = 10
2405 IF R > X(4) THEN 2430
2410 IF T(R, 0) <> 1 THEN 2420
2415 IF T(R, 1) = E THEN 2450
2420 CALL "tnext": T(), R
2425 GOTO 2405
2430 CALL "tnew": T(), N(), X(), X$(), 1, R
2435 IF R = 0 THEN 2450
2440 LET T(R, 0) = 1
2445 LET T(R, 1) = E
2450 SUBEND
2455 REM ---- ttup: R = the tuple of the K types U(1..K) ---------------------------------------------
2460 SUB "ttup": T(), N(), X(), X$(), U(), K, R
2465 LET R = 10
2470 IF R > X(4) THEN 2515
2475 IF T(R, 0) <> 7 THEN 2505
2480 IF T(R, 1) <> K THEN 2505
2485 FOR J = 1 TO K
2490 IF T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) <> U(J) THEN 2505
2495 NEXT J
2500 GOTO 2550
2505 CALL "tnext": T(), R
2510 GOTO 2470
2515 CALL "tnew": T(), N(), X(), X$(), 1 + INT((K + 8) / 9), R
2520 IF R = 0 THEN 2550
2525 LET T(R, 0) = 7
2530 LET T(R, 1) = K
2535 FOR J = 1 TO K
2540 LET T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) = U(J)
2545 NEXT J
2550 SUBEND
2555 REM ---- stl: an untyped constant subtree I takes type D (f64, else i64); every literal that
2560 REM becomes f64 must be exact (integer constant not exact in f64, LANGUAGE 4.2) -----------
2565 SUB "stl": N(), M(), C(), X(), X$(), I, D
2570 IF M(I, 1) <> -1 THEN 2640
2575 LET D1 = D
2580 IF D1 = 4 THEN 2590
2585 LET D1 = 3
2590 FOR J = M(I, 0) TO I
2595 IF M(J, 1) <> -1 THEN 2635
2600 LET M(J, 1) = D1
2605 IF D1 <> 4 THEN 2635
2610 IF N(J, 0) <> 25 THEN 2635
2615 LET R0 = M(J, 5)
2620 CALL "FEFRI": C(R0, 1), C(R0, 2), C(R0, 3), C(R0, 4), A3, A2, A1, A0, V
2625 IF V = 0 THEN 2635
2630 CALL "er": N(), X(), X$(), J, "NOT_EXACT_F64", "", "", "", 0
2635 NEXT J
2640 SUBEND
2645 REM ---- vu: R = the type of I used as one value; a multiple-result or void call is an error --
2650 SUB "vu": N(), M(), T(), X(), X$(), I, R
2655 LET R = M(I, 1)
2660 IF R < 10 THEN 2685
2665 IF T(R, 0) <> 7 THEN 2700
2670 CALL "er": N(), X(), X$(), I, "MULTI_VALUE", "", "", "", 0
2675 LET R = 0
2680 GOTO 2700
2685 IF R <> 1 THEN 2700
2690 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", "0", "1", "", 2
2695 LET R = 0
2700 SUBEND
2705 REM ---- cv: the value I stored into type D (initialisation, assignment, argument, return):
2710 REM untyped constants take D, i64 -> f64 is a cvt, anything else a type mismatch -----------
2715 SUB "cv": N(), M(), T(), C(), X(), X$(), I, D
2720 CALL "vu": N(), M(), T(), X(), X$(), I, T1
2725 IF T1 = 0 THEN 2790
2730 IF D = 0 THEN 2790
2735 IF T1 <> -1 THEN 2750
2740 CALL "stl": N(), M(), C(), X(), X$(), I, D
2745 LET T1 = M(I, 1)
2750 IF T1 = D THEN 2790
2755 IF T1 <> 3 THEN 2775
2760 IF D <> 4 THEN 2775
2765 LET M(I, 7) = 1
2770 GOTO 2790
2775 CALL "tyn": T(), D, A$
2780 CALL "tyn": T(), T1, B$
2785 CALL "er": N(), X(), X$(), I, "TYPE_MISMATCH", A$, B$, "", 2
2790 SUBEND
2795 REM ---- cand: an f64 is stored into local R: a var-rule candidate becomes f64 (Decision 8) ----
2800 SUB "cand": M(), Y(), X(), R
2805 IF R <= 0 THEN 2830
2810 IF Y(R, 6) = 0 THEN 2830
2815 IF M(Y(R, 6), 4) = 1 THEN 2830
2820 LET M(Y(R, 6), 4) = 1
2825 LET X(16) = 1
2830 SUBEND
2835 REM ---- resc: R$ = the bytes S$ written back as a string literal's source text (LANGUAGE 3.5):
2840 REM \" \\ \n \t \r \0, other control bytes \xHH, every other byte itself (DESIGN 2.6.2) ----
2845 SUB "resc": S$, R$
2850 DIM B(4100)
2855 LET R$ = ""
2860 LET L0 = LEN(S$)
2865 IF L0 = 0 THEN 3000
2870 CHANGE S$ TO B
2875 FOR J = 1 TO L0
2880 LET C1 = B(J)
2885 IF C1 = 34 THEN 2935
2890 IF C1 = 92 THEN 2935
2895 IF C1 = 10 THEN 2945
2900 IF C1 = 9 THEN 2955
2905 IF C1 = 13 THEN 2965
2910 IF C1 = 0 THEN 2975
2915 IF C1 < 32 THEN 2985
2920 IF C1 = 127 THEN 2985
2925 LET R$ = R$ & SEG$(S$, J, J)
2930 GOTO 2995
2935 LET R$ = R$ & "\" & SEG$(S$, J, J)
2940 GOTO 2995
2945 LET R$ = R$ & "\n"
2950 GOTO 2995
2955 LET R$ = R$ & "\t"
2960 GOTO 2995
2965 LET R$ = R$ & "\r"
2970 GOTO 2995
2975 LET R$ = R$ & "\0"
2980 GOTO 2995
2985 LET H = INT(C1 / 16)
2990 LET R$ = R$ & "\x" & SEG$("0123456789ABCDEF", H + 1, H + 1) & SEG$("0123456789ABCDEF", C1 - 16 * H + 1, C1 - 16 * H + 1)
2995 NEXT J
3000 SUBEND
3005 REM ---- kid: R = child J of node I ----------------------------------------------------------
3010 SUB "kid": N(), I, J, R
3015 LET R = N(I, 7)
3020 FOR H = 2 TO J
3025 LET R = N(R, 8)
3030 NEXT H
3035 SUBEND
3040 REM ---- opn: R$ = binary operator O as written (LANGUAGE 6.1) --------------------------------
3045 SUB "opn": O, R$
3050 LET A$ = "+ - * / % ^ @ == != < <= > >= & | && || "
3055 LET S = 1
3060 FOR J = 1 TO O
3065 LET P = POS(A$, " ", S)
3070 IF J = O THEN 3080
3075 LET S = P + 1
3080 NEXT J
3085 LET R$ = SEG$(A$, S, P - 1)
3090 SUBEND
3095 REM ---- pos: R$ = position F:L:C of node I (DESIGN 3.1) ---------------------------------------
3100 SUB "pos": N(), I, R$
3105 LET F = INT(N(I, 4) / 1E9)
3110 LET R$ = STR$(F) & ":" & STR$(N(I, 4) - F * 1E9) & ":" & STR$(N(I, 5))
3115 SUBEND
3120 REM ---- cnew: R = the C row of value (K, L3..L0), K 3 i64 or 4 f64 in C(r,0): a value already
3125 REM held shares its row (LIM_CONSTS counts distinct values, DESIGN 2.7); 0 when the table is
3130 REM full. H() (39989 slots, at most half full) finds rows by a hash of the value. ----------
3135 SUB "cnew": C(), H(), X(), K, L3, L2, L1, L0, R
3140 LET P9 = 39989
3145 LET V = K * 7 + L3
3150 LET V = V * 65536 + L2
3155 LET V = V - P9 * INT(V / P9)
3160 LET V = V * 65536 + L1
3165 LET V = V - P9 * INT(V / P9)
3170 LET V = V * 65536 + L0
3175 LET V = V - P9 * INT(V / P9)
3180 LET Q = V + 1
3185 LET R = H(Q)
3190 IF R = 0 THEN 3240
3195 IF C(R, 0) <> K THEN 3220
3200 IF C(R, 1) <> L3 THEN 3220
3205 IF C(R, 2) <> L2 THEN 3220
3210 IF C(R, 3) <> L1 THEN 3220
3215 IF C(R, 4) = L0 THEN 3295
3220 LET Q = Q + 1
3225 IF Q <= P9 THEN 3185
3230 LET Q = 1
3235 GOTO 3185
3240 IF X(5) < X(22) THEN 3255
3245 LET R = 0
3250 GOTO 3295
3255 LET X(5) = X(5) + 1
3260 LET R = X(5)
3265 LET C(R, 0) = K
3270 LET C(R, 1) = L3
3275 LET C(R, 2) = L2
3280 LET C(R, 3) = L1
3285 LET C(R, 4) = L0
3290 LET H(Q) = R
3295 SUBEND
3300 REM ---- fsym: the symbols limit is exceeded by the declaration at node I: reported at its name
3305 REM (the pname, the item, a parameter's param node, a loop variable's npos; DESIGN 2.6.2 here) --
3310 SUB "fsym": N(), X(), X$(), I
3315 IF X(10) = 1 THEN 3340
3320 CALL "fatal": N(), X(), X$(), I, "symbols"
3325 IF N(I, 0) <> 18 THEN 3340
3330 LET X(36) = N(I, 1)
3335 LET X(37) = N(I, 2)
3340 SUBEND
3345 REM ---- tnext: R = the T row of the type after the one at row R (a tuple has 1 + ceil(n/9)
3350 REM rows: its continuation rows are skipped) --------------------------------------------
3355 SUB "tnext": T(), R
3360 IF T(R, 0) <> 7 THEN 3370
3365 LET R = R + INT((T(R, 1) + 8) / 9)
3370 LET R = R + 1
3375 SUBEND
