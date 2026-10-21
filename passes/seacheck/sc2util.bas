1395 REM ---- table layouts of seacheck ---------------------------------------------------------
1400 REM N(i,0) kind 1-49 (sc_read's list: 1 prog 2 const 3 struct 5 fn 6 param 7 type 8 let 9 var
1405 REM 10 pname 11 pskip 12 ptuple 13 asg 14 tasg 15 cstmt 16 if 17 while 18 for 21 break 22
1410 REM continue 23 return 24 block 25 int 26 float 27 str 28 true 29 false 30 name 32 neg 33 not
1415 REM 34 bin 35 call 37 ref 38 conv 41 range 49 ifx ...); N(i,1..3) u and enum fields (for: npos in
1420 REM N(i,1..2)); N(i,4) F*1E9+L; N(i,5) column; N(i,6) string; N(i,7) first child; N(i,8) next sibling; N(i,9) parent.
1425 REM M(i,0) first node of the subtree (post-order range M(i,0)..i); M(i,1) type: -1 untyped
1430 REM integer constant, 0 error, 1 void, 2 bool, 3 i64, 4 f64, 5 str, 6-9 handles, >= 10 a T row;
1435 REM M(i,2) symbol (Y row, -p predeclared slot p, 0 none; pname, param, for: the local bound);
1440 REM M(i,3) errors recorded before the node was checked; M(i,4) pname: var rule f64 (1), return:
1445 REM tret (1); M(i,5) C row of a literal; M(i,6) children; M(i,7) cvt to f64 after the node (1);
1450 REM M(i,8) bin: powk k + 10, < 0: writing jumps past node -M(i,8) (em_expr); M(i,9) the
1455 REM statement ends every path with a return (1).
1460 REM Y(s,0) 1 fn 2 const 3 struct 4 local; Y(s,1) name; Y(s,2) type (fn: result); Y(s,3) node;
1465 REM Y(s,4) local: 1 let 2 var 3 for 4 par 5 ref par, fn: elemental, const: 0 1 2 (checked);
1470 REM Y(s,5) lid / fid / cid; Y(s,6) local: pname of a var-rule candidate, fn: np, const: ck_cord state; Y(s,7) fn: nr,
1475 REM const: value (cval: 0 not yet 1 i64 2 f64 3 none); Y(s,8) local: function, fn: last local row,
1480 REM const: C row of the value; Y(s,9) fn: first local row. Row 1 is .main, items follow.
1485 REM T(t,0) 1 tvec 7 ttuple 0 continuation; T(t,1) element or count; tuple components in the
1490 REM next rows, 9 per row (columns 0-8); T(t,9) the written id (DESIGN 3.5.1).
1495 REM W(1..) the value stack of evx; W(..199999) scope stack, pairs (name, symbol), marker -1; W(180001..)
1500 REM written types in id order (emission only, the scopes are empty then). X(1) nodes X(2) strings X(3)
1505 REM symbols X(4) last T row X(5) C rows X(6) key of the first error (0 none) X(7) its node X(8)
1510 REM its argument count X(9) errors recorded X(10) capacity overflow X(11) evx stack base X(12)
1515 REM scope stack top X(13) lids X(14) function X(15) loop depth X(16) var rule changed X(17)
1520 REM prog X(18) program file X(19) current node X(20)-X(25) LIM SYMBOLS TYPES CONSTS NODES
1525 REM STRINGS POWK X(27) emission mode X(28) types written X(29) top-level statements X(30)
1530 REM functions X(31) constants X(33) items X(34) FILE_VERSION X(35) LIM_DEC_FIELD; C(r,0) 3 i64 4 f64, C(r,1..4) limbs; X$(1) error name, X$(2)-X$(4)
1535 REM its arguments, X$(10) predeclared names.
1540 REM ---- er: record error Q$ at node I (K arguments); the first in source order is kept ------
1545 SUB "er": N(), X(), X$(), I, Q$, A$, B$, C$, K
1550 LET X(9) = X(9) + 1
1555 IF X(10) = 1 THEN 1610
1560 LET Q = N(I, 4) * 10000 + N(I, 5)
1565 IF X(6) = 0 THEN 1575
1570 IF Q >= X(6) THEN 1610
1575 LET X(6) = Q
1580 LET X(7) = I
1585 LET X(8) = K
1590 LET X$(1) = Q$
1595 LET X$(2) = A$
1600 LET X$(3) = B$
1605 LET X$(4) = C$
1610 SUBEND
1615 REM ---- fatal: a capacity limit of DESIGN 2.7 is exceeded at node I (wins over every error) ---
1620 SUB "fatal": N(), X(), X$(), I, W$
1625 IF X(10) = 1 THEN 1660
1630 LET X(10) = 1
1635 LET X(6) = 1
1640 LET X(7) = I
1645 LET X(8) = 1
1650 LET X$(1) = "TOO_LARGE"
1655 LET X$(2) = W$
1660 SUBEND
1665 REM ---- intern: R = index of string Q$ in S$ (added if new; 0 if the table is full). G() (399989
1670 REM slots, at most half full) finds strings by a hash of the length and up to 32 bytes ----
1675 SUB "intern": S$(), X(), G(), Q$, R
1680 LET P9 = 399989
1685 LET L0 = LEN(Q$)
1690 LET V = L0 - P9 * INT(L0 / P9)
1695 LET S = 1
1700 IF L0 <= 32 THEN 1710
1705 LET S = INT(L0 / 32)
1710 FOR J = 1 TO L0 STEP S
1715 LET V = V * 263 + ASC(SEG$(Q$, J, J))
1720 LET V = V - P9 * INT(V / P9)
1725 NEXT J
1730 LET Q = V + 1
1735 LET R = G(Q)
1740 IF R = 0 THEN 1775
1745 IF LEN(S$(R)) <> L0 THEN 1755
1750 IF S$(R) = Q$ THEN 1810 ' equal lengths: = is exact
1755 LET Q = Q + 1
1760 IF Q <= P9 THEN 1735
1765 LET Q = 1
1770 GOTO 1735
1775 IF X(2) < X(24) THEN 1790
1780 LET R = 0
1785 GOTO 1810
1790 LET X(2) = X(2) + 1
1795 LET R = X(2)
1800 LET S$(R) = Q$
1805 LET G(Q) = R
1810 SUBEND
1815 REM ---- pdx: R = slot of predeclared name Q$ (1-4 constants, 5-8 handles, 9- functions) -----
1820 SUB "pdx": X$(), Q$, R
1825 LET R = 0
1830 IF LEN(Q$) > 10 THEN 1855
1835 IF LEN(Q$) = 0 THEN 1855
1840 LET P = POS(X$(10), "|" & Q$ & " ")
1845 IF P = 0 THEN 1855
1850 LET R = (P - 1) / 12 + 1
1855 SUBEND
1860 REM ---- lk: R = the symbol named Q (S$ index): scopes, then items, then predeclared (-slot) ---
1865 SUB "lk": Y(), W(), X(), X$(), S$(), Q, R
1870 LET R = 0
1875 FOR J = X(12) TO 199998 STEP 2
1880 IF W(J) <> Q THEN 1895
1885 LET R = W(J + 1)
1890 GOTO 1935
1895 NEXT J
1900 FOR J = 2 TO X(33)
1905 IF Y(J, 1) <> Q THEN 1920
1910 LET R = J
1915 GOTO 1935
1920 NEXT J
1925 CALL "pdx": X$(), S$(Q), P
1930 LET R = -P
1935 SUBEND
1940 REM ---- nsym: R = a new, cleared symbol row (capacity: program too large: symbols) -----------
1945 SUB "nsym": N(), Y(), X(), X$(), R
1950 IF X(3) < X(20) THEN 1970
1955 CALL "fatal": N(), X(), X$(), X(19), "symbols"
1960 LET R = 0
1965 GOTO 1995
1970 LET X(3) = X(3) + 1
1975 LET R = X(3)
1980 FOR J = 0 TO 9
1985 LET Y(R, J) = 0
1990 NEXT J
1995 SUBEND
2000 REM ---- nloc: R = new local named Q, type D, mut U, declared by node I, bound in the scope;
2005 REM Z = 1 checks the binding (shadowing a predeclared name, a str local: DESIGN 2.6.2) ----
2010 SUB "nloc": N(), Y(), W(), X(), X$(), S$(), Q, D, U, I, Z, R
2015 CALL "nsym": N(), Y(), X(), X$(), R
2020 LET Y(R, 0) = 4
2025 LET Y(R, 1) = Q
2030 LET Y(R, 2) = D
2035 LET Y(R, 3) = I
2040 LET Y(R, 4) = U
2045 LET X(13) = X(13) + 1
2050 LET Y(R, 5) = X(13)
2055 LET Y(R, 8) = X(14)
2060 IF X(12) - 2 > X(11) THEN 2075
2065 CALL "fatal": N(), X(), X$(), I, "symbols"
2070 GOTO 2090
2075 LET X(12) = X(12) - 2
2080 LET W(X(12)) = Q
2085 LET W(X(12) + 1) = R
2090 IF Z = 0 THEN 2120
2095 CALL "pdx": X$(), S$(Q), P
2100 IF P = 0 THEN 2110
2105 CALL "er": N(), X(), X$(), I, "SHADOWS_PREDECLARED", "", "", "", 0
2110 IF D <> 5 THEN 2120
2115 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "strings", "", "", 1
2120 SUBEND
2125 REM ---- tyn: R$ = type Q written as in Sea source (DESIGN 2.6.2) -----------------------------
2130 SUB "tyn": T(), Q, R$
2135 IF Q < 10 THEN 2205
2140 IF T(Q, 0) = 1 THEN 2190
2145 LET R$ = "("
2150 FOR J = 1 TO T(Q, 1)
2155 CALL "tyn": T(), T(Q + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)), A$
2160 IF J = 1 THEN 2170
2165 LET R$ = R$ & ", "
2170 LET R$ = R$ & A$
2175 NEXT J
2180 LET R$ = R$ & ")"
2185 GOTO 2260
2190 CALL "tyn": T(), T(Q, 1), A$
2195 LET R$ = A$ & "[]"
2200 GOTO 2260
2205 LET A$ = "?|void|bool|i64|f64|str|Figure|Axes|Lu|Chol|"
2210 LET S = 1
2215 LET Q1 = Q
2220 IF Q1 >= 0 THEN 2230
2225 LET Q1 = 3
2230 FOR J = 0 TO Q1
2235 LET P = POS(A$, "|", S)
2240 IF J = Q1 THEN 2250
2245 LET S = P + 1
2250 NEXT J
2255 LET R$ = SEG$(A$, S, P - 1)
2260 SUBEND
2265 REM ---- tnew: R = K new cleared T rows (capacity: program too large: types) -------------------
2270 SUB "tnew": T(), N(), X(), X$(), K, R
2275 IF X(4) - 9 + K <= X(21) THEN 2295
2280 CALL "fatal": N(), X(), X$(), X(19), "types"
2285 LET R = 0
2290 GOTO 2330
2295 LET R = X(4) + 1
2300 LET X(4) = X(4) + K
2305 FOR J = R TO X(4)
2310 FOR H = 0 TO 9
2315 LET T(J, H) = 0
2320 NEXT H
2325 NEXT J
2330 SUBEND
2335 REM ---- tvec: R = the type E[] (one id per structure, DESIGN 3.5.1) ---------------------------
2340 SUB "tvec": T(), N(), X(), X$(), E, R
2345 FOR R = 10 TO X(4)
2350 IF T(R, 0) <> 1 THEN 2360
2355 IF T(R, 1) = E THEN 2380
2360 NEXT R
2365 CALL "tnew": T(), N(), X(), X$(), 1, R
2370 LET T(R, 0) = 1
2375 LET T(R, 1) = E
2380 SUBEND
2385 REM ---- ttup: R = the tuple of the K types U(1..K) ---------------------------------------------
2390 SUB "ttup": T(), N(), X(), X$(), U(), K, R
2395 LET R = 10
2400 IF R > X(4) THEN 2445
2405 IF T(R, 0) <> 7 THEN 2435
2410 IF T(R, 1) <> K THEN 2435
2415 FOR J = 1 TO K
2420 IF T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) <> U(J) THEN 2435
2425 NEXT J
2430 GOTO 2475
2435 LET R = R + 1
2440 GOTO 2400
2445 CALL "tnew": T(), N(), X(), X$(), 1 + INT((K + 8) / 9), R
2450 LET T(R, 0) = 7
2455 LET T(R, 1) = K
2460 FOR J = 1 TO K
2465 LET T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) = U(J)
2470 NEXT J
2475 SUBEND
2480 REM ---- stl: an untyped constant subtree I takes type D (f64, else i64); every literal that
2485 REM becomes f64 must be exact (integer constant not exact in f64, LANGUAGE 4.2) -----------
2490 SUB "stl": N(), M(), C(), X(), X$(), I, D
2495 IF M(I, 1) <> -1 THEN 2565
2500 LET D1 = D
2505 IF D1 = 4 THEN 2515
2510 LET D1 = 3
2515 FOR J = M(I, 0) TO I
2520 IF M(J, 1) <> -1 THEN 2560
2525 LET M(J, 1) = D1
2530 IF D1 <> 4 THEN 2560
2535 IF N(J, 0) <> 25 THEN 2560
2540 LET R0 = M(J, 5)
2545 CALL "FEFRI": C(R0, 1), C(R0, 2), C(R0, 3), C(R0, 4), A3, A2, A1, A0, V
2550 IF V = 0 THEN 2560
2555 CALL "er": N(), X(), X$(), J, "NOT_EXACT_F64", "", "", "", 0
2560 NEXT J
2565 SUBEND
2570 REM ---- vu: R = the type of I used as one value; a multiple-result or void call is an error --
2575 SUB "vu": N(), M(), T(), X(), X$(), I, R
2580 LET R = M(I, 1)
2585 IF R < 10 THEN 2610
2590 IF T(R, 0) <> 7 THEN 2625
2595 CALL "er": N(), X(), X$(), I, "MULTI_VALUE", "", "", "", 0
2600 LET R = 0
2605 GOTO 2625
2610 IF R <> 1 THEN 2625
2615 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", "0", "1", "", 2
2620 LET R = 0
2625 SUBEND
2630 REM ---- cv: the value I stored into type D (initialisation, assignment, argument, return):
2635 REM untyped constants take D, i64 -> f64 is a cvt, anything else a type mismatch -----------
2640 SUB "cv": N(), M(), T(), C(), X(), X$(), I, D
2645 CALL "vu": N(), M(), T(), X(), X$(), I, T1
2650 IF T1 = 0 THEN 2715
2655 IF D = 0 THEN 2715
2660 IF T1 <> -1 THEN 2675
2665 CALL "stl": N(), M(), C(), X(), X$(), I, D
2670 LET T1 = M(I, 1)
2675 IF T1 = D THEN 2715
2680 IF T1 <> 3 THEN 2700
2685 IF D <> 4 THEN 2700
2690 LET M(I, 7) = 1
2695 GOTO 2715
2700 CALL "tyn": T(), D, A$
2705 CALL "tyn": T(), T1, B$
2710 CALL "er": N(), X(), X$(), I, "TYPE_MISMATCH", A$, B$, "", 2
2715 SUBEND
2720 REM ---- cand: an f64 is stored into local R: a var-rule candidate becomes f64 (Decision 8) ----
2725 SUB "cand": M(), Y(), X(), R
2730 IF R <= 0 THEN 2755
2735 IF Y(R, 6) = 0 THEN 2755
2740 IF M(Y(R, 6), 4) = 1 THEN 2755
2745 LET M(Y(R, 6), 4) = 1
2750 LET X(16) = 1
2755 SUBEND
2760 REM ---- resc: R$ = the bytes S$ written back as a string literal's source text (LANGUAGE 3.5):
2765 REM \" \\ \n \t \r \0, other control bytes \xHH, every other byte itself (DESIGN 2.6.2) ----
2770 SUB "resc": S$, R$
2775 DIM B(4100)
2780 LET R$ = ""
2785 LET L0 = LEN(S$)
2790 IF L0 = 0 THEN 2925
2795 CHANGE S$ TO B
2800 FOR J = 1 TO L0
2805 LET C1 = B(J)
2810 IF C1 = 34 THEN 2860
2815 IF C1 = 92 THEN 2860
2820 IF C1 = 10 THEN 2870
2825 IF C1 = 9 THEN 2880
2830 IF C1 = 13 THEN 2890
2835 IF C1 = 0 THEN 2900
2840 IF C1 < 32 THEN 2910
2845 IF C1 = 127 THEN 2910
2850 LET R$ = R$ & SEG$(S$, J, J)
2855 GOTO 2920
2860 LET R$ = R$ & "\" & SEG$(S$, J, J)
2865 GOTO 2920
2870 LET R$ = R$ & "\n"
2875 GOTO 2920
2880 LET R$ = R$ & "\t"
2885 GOTO 2920
2890 LET R$ = R$ & "\r"
2895 GOTO 2920
2900 LET R$ = R$ & "\0"
2905 GOTO 2920
2910 LET H = INT(C1 / 16)
2915 LET R$ = R$ & "\x" & SEG$("0123456789ABCDEF", H + 1, H + 1) & SEG$("0123456789ABCDEF", C1 - 16 * H + 1, C1 - 16 * H + 1)
2920 NEXT J
2925 SUBEND
2930 REM ---- kid: R = child J of node I ----------------------------------------------------------
2935 SUB "kid": N(), I, J, R
2940 LET R = N(I, 7)
2945 FOR H = 2 TO J
2950 LET R = N(R, 8)
2955 NEXT H
2960 SUBEND
2965 REM ---- opn: R$ = binary operator O as written (LANGUAGE 6.1) --------------------------------
2970 SUB "opn": O, R$
2975 LET A$ = "+ - * / % ^ @ == != < <= > >= & | && || "
2980 LET S = 1
2985 FOR J = 1 TO O
2990 LET P = POS(A$, " ", S)
2995 IF J = O THEN 3005
3000 LET S = P + 1
3005 NEXT J
3010 LET R$ = SEG$(A$, S, P - 1)
3015 SUBEND
3020 REM ---- pos: R$ = position F:L:C of node I (DESIGN 3.1) ---------------------------------------
3025 SUB "pos": N(), I, R$
3030 LET F = INT(N(I, 4) / 1E9)
3035 LET R$ = STR$(F) & ":" & STR$(N(I, 4) - F * 1E9) & ":" & STR$(N(I, 5))
3040 SUBEND
3045 REM ---- cnew: R = the C row of value (K, L3..L0), K 3 i64 or 4 f64 in C(r,0): a value already
3050 REM held shares its row (LIM_CONSTS counts distinct values, DESIGN 2.7); 0 when the table is
3055 REM full. H() (39989 slots, at most half full) finds rows by a hash of the value. ----------
3060 SUB "cnew": C(), H(), X(), K, L3, L2, L1, L0, R
3065 LET P9 = 39989
3070 LET V = K * 7 + L3
3075 LET V = V * 65536 + L2
3080 LET V = V - P9 * INT(V / P9)
3085 LET V = V * 65536 + L1
3090 LET V = V - P9 * INT(V / P9)
3095 LET V = V * 65536 + L0
3100 LET V = V - P9 * INT(V / P9)
3105 LET Q = V + 1
3110 LET R = H(Q)
3115 IF R = 0 THEN 3165
3120 IF C(R, 0) <> K THEN 3145
3125 IF C(R, 1) <> L3 THEN 3145
3130 IF C(R, 2) <> L2 THEN 3145
3135 IF C(R, 3) <> L1 THEN 3145
3140 IF C(R, 4) = L0 THEN 3220
3145 LET Q = Q + 1
3150 IF Q <= P9 THEN 3110
3155 LET Q = 1
3160 GOTO 3110
3165 IF X(5) < X(22) THEN 3180
3170 LET R = 0
3175 GOTO 3220
3180 LET X(5) = X(5) + 1
3185 LET R = X(5)
3190 LET C(R, 0) = K
3195 LET C(R, 1) = L3
3200 LET C(R, 2) = L2
3205 LET C(R, 3) = L1
3210 LET C(R, 4) = L0
3215 LET H(Q) = R
3220 SUBEND
