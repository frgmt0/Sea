1475 REM ---- table layouts of seacheck ---------------------------------------------------------
1480 REM N(i,0) kind 1-49 (sc_read's list: 1 prog 2 const 3 struct 5 fn 6 param 7 type 8 let 9 var
1485 REM 10 pname 11 pskip 12 ptuple 13 asg 14 tasg 15 cstmt 16 if 17 while 18 for 21 break 22
1490 REM continue 23 return 24 block 25 int 26 float 27 str 28 true 29 false 30 name 32 neg 33 not
1495 REM 34 bin 35 call 37 ref 38 conv 41 range 49 ifx ...); N(i,1..3) u and enum fields (for: npos in
1500 REM N(i,1..2)); N(i,4) F*1E9+L; N(i,5) column; N(i,6) string; N(i,7) first child; N(i,8) next sibling; N(i,9) parent.
1505 REM M(i,0) first node of the subtree (post-order range M(i,0)..i); M(i,1) type: -1 untyped
1510 REM integer constant, 0 error, 1 void, 2 bool, 3 i64, 4 f64, 5 str, 6-9 handles, >= 10 a T row;
1515 REM M(i,2) symbol (Y row, -p predeclared slot p, 0 none; pname, param, for: the local bound);
1520 REM M(i,3) errors recorded before the node was checked; M(i,4) pname: var rule f64 (1), return:
1525 REM tret (1); M(i,5) C row of a literal; M(i,6) children; M(i,7) cvt to f64 after the node (1);
1530 REM M(i,8) bin: powk k + 10, < 0: writing jumps past node -M(i,8) (em_expr); M(i,9) the
1535 REM statement ends every path with a return (1).
1540 REM Y(s,0) 1 fn 2 const 3 struct 4 local; Y(s,1) name; Y(s,2) type (fn: result); Y(s,3) node;
1545 REM Y(s,4) local: 1 let 2 var 3 for 4 par 5 ref par, fn: elemental, const: 0 1 2 (checked);
1550 REM Y(s,5) lid / fid / cid; Y(s,6) local: pname of a var-rule candidate, fn: np, const: ck_cord state; Y(s,7) fn: nr,
1555 REM const: value (cval: 0 not yet 1 i64 2 f64 3 none); Y(s,8) local: function, fn: last local row,
1560 REM const: C row of the value; Y(s,9) fn: first local row. Row 1 is .main, items follow.
1565 REM T(t,0) 1 tvec 7 ttuple 0 continuation; T(t,1) element or count; tuple components in the
1570 REM next rows, 9 per row (columns 0-8); T(t,9) the written id (DESIGN 3.5.1).
1575 REM W(1..) the value stack of evx; W(..199999) scope stack, pairs (name, symbol), marker -1; W(180001..)
1580 REM written types in id order (emission only, the scopes are empty then). X(1) nodes X(2) strings X(3)
1585 REM symbols X(4) last T row X(5) C rows X(6) key of the first error (0 none) X(7) its node X(8)
1590 REM its argument count X(9) errors recorded X(10) capacity overflow X(11) evx stack base X(12)
1595 REM scope stack top X(13) lids X(14) function X(15) loop depth X(16) var rule changed X(17)
1600 REM prog X(18) program file X(19) current node X(20)-X(25) LIM SYMBOLS TYPES CONSTS NODES
1605 REM STRINGS POWK X(27) emission mode X(28) types written X(29) top-level statements X(30)
1610 REM functions X(31) constants X(33) items X(34) FILE_VERSION X(35) LIM_DEC_FIELD X(36) X(37) npos of a symbols overflow X(38) types X(39) the predeclared slot of pow; C(r,0) 3 i64 4 f64, C(r,1..4) limbs; X$(1) error name, X$(2)-X$(4)
1615 REM its arguments, X$(10) predeclared names.
1620 REM ---- er: record error Q$ at node I (K arguments); the first in source order is kept ------
1625 SUB "er": N(), X(), X$(), I, Q$, A$, B$, C$, K
1630 LET X(9) = X(9) + 1
1635 IF X(10) = 1 THEN 1690
1640 LET Q = N(I, 4) * 10000 + N(I, 5)
1645 IF X(6) = 0 THEN 1655
1650 IF Q >= X(6) THEN 1690
1655 LET X(6) = Q
1660 LET X(7) = I
1665 LET X(8) = K
1670 LET X$(1) = Q$
1675 LET X$(2) = A$
1680 LET X$(3) = B$
1685 LET X$(4) = C$
1690 SUBEND
1695 REM ---- fatal: a capacity limit of DESIGN 2.7 is exceeded at node I (wins over every error) ---
1700 SUB "fatal": N(), X(), X$(), I, W$
1705 IF X(10) = 1 THEN 1740
1710 LET X(10) = 1
1715 LET X(6) = 1
1720 LET X(7) = I
1725 LET X(8) = 1
1730 LET X$(1) = "TOO_LARGE"
1735 LET X$(2) = W$
1740 SUBEND
1745 REM ---- intern: R = index of string Q$ in S$ (added if new; 0 if the table is full). G() (399989
1750 REM slots, at most half full) finds strings by a hash of the length and up to 32 bytes ----
1755 SUB "intern": S$(), X(), G(), Q$, R
1760 LET P9 = 399989
1765 LET L0 = LEN(Q$)
1770 LET V = L0 - P9 * INT(L0 / P9)
1775 LET S = 1
1780 IF L0 <= 32 THEN 1790
1785 LET S = INT(L0 / 32)
1790 FOR J = 1 TO L0 STEP S
1795 LET V = V * 263 + ASC(SEG$(Q$, J, J))
1800 LET V = V - P9 * INT(V / P9)
1805 NEXT J
1810 LET Q = V + 1
1815 LET R = G(Q)
1820 IF R = 0 THEN 1855
1825 IF LEN(S$(R)) <> L0 THEN 1835
1830 IF S$(R) = Q$ THEN 1890 ' equal lengths: = is exact
1835 LET Q = Q + 1
1840 IF Q <= P9 THEN 1815
1845 LET Q = 1
1850 GOTO 1815
1855 IF X(2) < X(24) THEN 1870
1860 LET R = 0
1865 GOTO 1890
1870 LET X(2) = X(2) + 1
1875 LET R = X(2)
1880 LET S$(R) = Q$
1885 LET G(Q) = R
1890 SUBEND
1895 REM ---- pdx: R = slot of predeclared name Q$ (1-4 constants, 5-8 handles, 9- functions) -----
1900 SUB "pdx": X$(), Q$, R
1905 LET R = 0
1910 IF LEN(Q$) > 10 THEN 1935
1915 IF LEN(Q$) = 0 THEN 1935
1920 LET P = POS(X$(10), "|" & Q$ & " ")
1925 IF P = 0 THEN 1935
1930 LET R = (P - 1) / 12 + 1
1935 SUBEND
1940 REM ---- lk: R = the symbol named Q (S$ index): scopes, then items, then predeclared (-slot) ---
1945 SUB "lk": Y(), W(), X(), X$(), S$(), Q, R
1950 LET R = 0
1955 FOR J = X(12) TO 199998 STEP 2
1960 IF W(J) <> Q THEN 1975
1965 LET R = W(J + 1)
1970 GOTO 2015
1975 NEXT J
1980 FOR J = 2 TO X(33)
1985 IF Y(J, 1) <> Q THEN 2000
1990 LET R = J
1995 GOTO 2015
2000 NEXT J
2005 CALL "pdx": X$(), S$(Q), P
2010 LET R = -P
2015 SUBEND
2020 REM ---- nsym: R = a new, cleared symbol row for the declaration at node I (capacity: program
2025 REM too large: symbols, reported at that declaration, fsym) ----------------------------
2030 SUB "nsym": N(), Y(), X(), X$(), I, R
2035 IF X(3) < X(20) THEN 2055
2040 CALL "fsym": N(), X(), X$(), I
2045 LET R = 0
2050 GOTO 2080
2055 LET X(3) = X(3) + 1
2060 LET R = X(3)
2065 FOR J = 0 TO 9
2070 LET Y(R, J) = 0
2075 NEXT J
2080 SUBEND
2085 REM ---- nloc: R = new local named Q, type D, mut U, declared by node I, bound in the scope;
2090 REM Z = 1 checks the binding (shadowing a predeclared name, a str local: DESIGN 2.6.2) ----
2095 SUB "nloc": N(), Y(), W(), X(), X$(), S$(), Q, D, U, I, Z, R
2100 CALL "nsym": N(), Y(), X(), X$(), I, R
2105 LET Y(R, 0) = 4
2110 LET Y(R, 1) = Q
2115 LET Y(R, 2) = D
2120 LET Y(R, 3) = I
2125 LET Y(R, 4) = U
2130 LET X(13) = X(13) + 1
2135 LET Y(R, 5) = X(13)
2140 LET Y(R, 8) = X(14)
2145 IF X(12) - 2 > X(11) THEN 2160
2150 CALL "fsym": N(), X(), X$(), I
2155 GOTO 2175
2160 LET X(12) = X(12) - 2
2165 LET W(X(12)) = Q
2170 LET W(X(12) + 1) = R
2175 IF Z = 0 THEN 2205
2180 CALL "pdx": X$(), S$(Q), P
2185 IF P = 0 THEN 2195
2190 CALL "er": N(), X(), X$(), I, "SHADOWS_PREDECLARED", "", "", "", 0
2195 IF D <> 5 THEN 2205
2200 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "strings", "", "", 1
2205 SUBEND
2210 REM ---- tyn: R$ = type Q written as in Sea source (DESIGN 2.6.2) -----------------------------
2215 SUB "tyn": T(), Q, R$
2220 IF Q < 10 THEN 2290
2225 IF T(Q, 0) = 1 THEN 2275
2230 LET R$ = "("
2235 FOR J = 1 TO T(Q, 1)
2240 CALL "tyn": T(), T(Q + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)), A$
2245 IF J = 1 THEN 2255
2250 LET R$ = R$ & ", "
2255 LET R$ = R$ & A$
2260 NEXT J
2265 LET R$ = R$ & ")"
2270 GOTO 2345
2275 CALL "tyn": T(), T(Q, 1), A$
2280 LET R$ = A$ & "[]"
2285 GOTO 2345
2290 LET A$ = "?|void|bool|i64|f64|str|Figure|Axes|Lu|Chol|"
2295 LET S = 1
2300 LET Q1 = Q
2305 IF Q1 >= 0 THEN 2315
2310 LET Q1 = 3
2315 FOR J = 0 TO Q1
2320 LET P = POS(A$, "|", S)
2325 IF J = Q1 THEN 2335
2330 LET S = P + 1
2335 NEXT J
2340 LET R$ = SEG$(A$, S, P - 1)
2345 SUBEND
2350 REM ---- tnew: R = the first of K new cleared T rows for one new type. LIM_TYPES counts types
2355 REM (X(38)), not rows; the rows of T always suffice (sc_lim: 2 per type and one more per 9
2360 REM tuple components, which are type nodes) ------------------------------------------------
2365 SUB "tnew": T(), N(), X(), X$(), K, R
2370 IF X(38) < X(21) THEN 2390
2375 CALL "fatal": N(), X(), X$(), X(19), "types"
2380 LET R = 0
2385 GOTO 2430
2390 LET X(38) = X(38) + 1
2395 LET R = X(4) + 1
2400 LET X(4) = X(4) + K
2405 FOR J = R TO X(4)
2410 FOR H = 0 TO 9
2415 LET T(J, H) = 0
2420 NEXT H
2425 NEXT J
2430 SUBEND
2435 REM ---- tvec: R = the type E[] (one id per structure, DESIGN 3.5.1) ---------------------------
2440 SUB "tvec": T(), N(), X(), X$(), E, R
2445 LET R = 10
2450 IF R > X(4) THEN 2475
2455 IF T(R, 0) <> 1 THEN 2465
2460 IF T(R, 1) = E THEN 2495
2465 CALL "tnext": T(), R
2470 GOTO 2450
2475 CALL "tnew": T(), N(), X(), X$(), 1, R
2480 IF R = 0 THEN 2495
2485 LET T(R, 0) = 1
2490 LET T(R, 1) = E
2495 SUBEND
2500 REM ---- ttup: R = the tuple of the K types U(1..K) ---------------------------------------------
2505 SUB "ttup": T(), N(), X(), X$(), U(), K, R
2510 LET R = 10
2515 IF R > X(4) THEN 2560
2520 IF T(R, 0) <> 7 THEN 2550
2525 IF T(R, 1) <> K THEN 2550
2530 FOR J = 1 TO K
2535 IF T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) <> U(J) THEN 2550
2540 NEXT J
2545 GOTO 2595
2550 CALL "tnext": T(), R
2555 GOTO 2515
2560 CALL "tnew": T(), N(), X(), X$(), 1 + INT((K + 8) / 9), R
2565 IF R = 0 THEN 2595
2570 LET T(R, 0) = 7
2575 LET T(R, 1) = K
2580 FOR J = 1 TO K
2585 LET T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) = U(J)
2590 NEXT J
2595 SUBEND
2600 REM ---- stl: an untyped constant subtree I takes type D (f64, else i64); every literal that
2605 REM becomes f64 must be exact (integer constant not exact in f64, LANGUAGE 4.2) -----------
2610 SUB "stl": N(), M(), C(), X(), X$(), I, D
2615 IF M(I, 1) <> -1 THEN 2685
2620 LET D1 = D
2625 IF D1 = 4 THEN 2635
2630 LET D1 = 3
2635 FOR J = M(I, 0) TO I
2640 IF M(J, 1) <> -1 THEN 2680
2645 LET M(J, 1) = D1
2650 IF D1 <> 4 THEN 2680
2655 IF N(J, 0) <> 25 THEN 2680
2660 LET R0 = M(J, 5)
2665 CALL "FEFRI": C(R0, 1), C(R0, 2), C(R0, 3), C(R0, 4), A3, A2, A1, A0, V
2670 IF V = 0 THEN 2680
2675 CALL "er": N(), X(), X$(), J, "NOT_EXACT_F64", "", "", "", 0
2680 NEXT J
2685 SUBEND
2690 REM ---- vu: R = the type of I used as one value; a multiple-result or void call is an error --
2695 SUB "vu": N(), M(), T(), X(), X$(), I, R
2700 LET R = M(I, 1)
2705 IF R < 10 THEN 2730
2710 IF T(R, 0) <> 7 THEN 2745
2715 CALL "er": N(), X(), X$(), I, "MULTI_VALUE", "", "", "", 0
2720 LET R = 0
2725 GOTO 2745
2730 IF R <> 1 THEN 2745
2735 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", "0", "1", "", 2
2740 LET R = 0
2745 SUBEND
2750 REM ---- cv: the value I stored into type D (initialisation, assignment, argument, return):
2755 REM untyped constants take D, i64 -> f64 is a cvt, anything else a type mismatch -----------
2760 SUB "cv": N(), M(), T(), C(), X(), X$(), I, D
2765 CALL "vu": N(), M(), T(), X(), X$(), I, T1
2770 IF T1 = 0 THEN 2835
2775 IF D = 0 THEN 2835
2780 IF T1 <> -1 THEN 2795
2785 CALL "stl": N(), M(), C(), X(), X$(), I, D
2790 LET T1 = M(I, 1)
2795 IF T1 = D THEN 2835
2800 IF T1 <> 3 THEN 2820
2805 IF D <> 4 THEN 2820
2810 LET M(I, 7) = 1
2815 GOTO 2835
2820 CALL "tyn": T(), D, A$
2825 CALL "tyn": T(), T1, B$
2830 CALL "er": N(), X(), X$(), I, "TYPE_MISMATCH", A$, B$, "", 2
2835 SUBEND
2840 REM ---- cand: an f64 is stored into local R: a var-rule candidate becomes f64 (Decision 8) ----
2845 SUB "cand": M(), Y(), X(), R
2850 IF R <= 0 THEN 2875
2855 IF Y(R, 6) = 0 THEN 2875
2860 IF M(Y(R, 6), 4) = 1 THEN 2875
2865 LET M(Y(R, 6), 4) = 1
2870 LET X(16) = 1
2875 SUBEND
2880 REM ---- resc: R$ = the bytes S$ written back as a string literal's source text (LANGUAGE 3.5):
2885 REM \" \\ \n \t \r \0, other control bytes \xHH, every other byte itself (DESIGN 2.6.2) ----
2890 SUB "resc": S$, R$
2895 DIM B(4100)
2900 LET R$ = ""
2905 LET L0 = LEN(S$)
2910 IF L0 = 0 THEN 3045
2915 CHANGE S$ TO B
2920 FOR J = 1 TO L0
2925 LET C1 = B(J)
2930 IF C1 = 34 THEN 2980
2935 IF C1 = 92 THEN 2980
2940 IF C1 = 10 THEN 2990
2945 IF C1 = 9 THEN 3000
2950 IF C1 = 13 THEN 3010
2955 IF C1 = 0 THEN 3020
2960 IF C1 < 32 THEN 3030
2965 IF C1 = 127 THEN 3030
2970 LET R$ = R$ & SEG$(S$, J, J)
2975 GOTO 3040
2980 LET R$ = R$ & "\" & SEG$(S$, J, J)
2985 GOTO 3040
2990 LET R$ = R$ & "\n"
2995 GOTO 3040
3000 LET R$ = R$ & "\t"
3005 GOTO 3040
3010 LET R$ = R$ & "\r"
3015 GOTO 3040
3020 LET R$ = R$ & "\0"
3025 GOTO 3040
3030 LET H = INT(C1 / 16)
3035 LET R$ = R$ & "\x" & SEG$("0123456789ABCDEF", H + 1, H + 1) & SEG$("0123456789ABCDEF", C1 - 16 * H + 1, C1 - 16 * H + 1)
3040 NEXT J
3045 SUBEND
3050 REM ---- kid: R = child J of node I ----------------------------------------------------------
3055 SUB "kid": N(), I, J, R
3060 LET R = N(I, 7)
3065 FOR H = 2 TO J
3070 LET R = N(R, 8)
3075 NEXT H
3080 SUBEND
3085 REM ---- opn: R$ = binary operator O as written (LANGUAGE 6.1) --------------------------------
3090 SUB "opn": O, R$
3095 LET A$ = "+ - * / % ^ @ == != < <= > >= & | && || "
3100 LET S = 1
3105 FOR J = 1 TO O
3110 LET P = POS(A$, " ", S)
3115 IF J = O THEN 3125
3120 LET S = P + 1
3125 NEXT J
3130 LET R$ = SEG$(A$, S, P - 1)
3135 SUBEND
3140 REM ---- pos: R$ = position F:L:C of node I (DESIGN 3.1) ---------------------------------------
3145 SUB "pos": N(), I, R$
3150 LET F = INT(N(I, 4) / 1E9)
3155 LET R$ = STR$(F) & ":" & STR$(N(I, 4) - F * 1E9) & ":" & STR$(N(I, 5))
3160 SUBEND
3165 REM ---- cnew: R = the C row of value (K, L3..L0), K 3 i64 or 4 f64 in C(r,0): a value already
3170 REM held shares its row (LIM_CONSTS counts distinct values, DESIGN 2.7); 0 when the table is
3175 REM full. H() (39989 slots, at most half full) finds rows by a hash of the value. ----------
3180 SUB "cnew": C(), H(), X(), K, L3, L2, L1, L0, R
3185 LET P9 = 39989
3190 LET V = K * 7 + L3
3195 LET V = V * 65536 + L2
3200 LET V = V - P9 * INT(V / P9)
3205 LET V = V * 65536 + L1
3210 LET V = V - P9 * INT(V / P9)
3215 LET V = V * 65536 + L0
3220 LET V = V - P9 * INT(V / P9)
3225 LET Q = V + 1
3230 LET R = H(Q)
3235 IF R = 0 THEN 3285
3240 IF C(R, 0) <> K THEN 3265
3245 IF C(R, 1) <> L3 THEN 3265
3250 IF C(R, 2) <> L2 THEN 3265
3255 IF C(R, 3) <> L1 THEN 3265
3260 IF C(R, 4) = L0 THEN 3340
3265 LET Q = Q + 1
3270 IF Q <= P9 THEN 3230
3275 LET Q = 1
3280 GOTO 3230
3285 IF X(5) < X(22) THEN 3300
3290 LET R = 0
3295 GOTO 3340
3300 LET X(5) = X(5) + 1
3305 LET R = X(5)
3310 LET C(R, 0) = K
3315 LET C(R, 1) = L3
3320 LET C(R, 2) = L2
3325 LET C(R, 3) = L1
3330 LET C(R, 4) = L0
3335 LET H(Q) = R
3340 SUBEND
3345 REM ---- fsym: the symbols limit is exceeded by the declaration at node I: reported at its name
3350 REM (the pname, the item, a parameter's param node, a loop variable's npos; DESIGN 2.6.2 here) --
3355 SUB "fsym": N(), X(), X$(), I
3360 IF X(10) = 1 THEN 3385
3365 CALL "fatal": N(), X(), X$(), I, "symbols"
3370 IF N(I, 0) <> 18 THEN 3385
3375 LET X(36) = N(I, 1)
3380 LET X(37) = N(I, 2)
3385 SUBEND
3390 REM ---- tnext: R = the T row of the type after the one at row R (a tuple has 1 + ceil(n/9)
3395 REM rows: its continuation rows are skipped) --------------------------------------------
3400 SUB "tnext": T(), R
3405 IF T(R, 0) <> 7 THEN 3415
3410 LET R = R + INT((T(R, 1) + 8) / 9)
3415 LET R = R + 1
3420 SUBEND
