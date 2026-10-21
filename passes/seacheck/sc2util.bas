1325 REM ---- table layouts of seacheck ---------------------------------------------------------
1330 REM N(i,0) kind 1-49 (sc_read's list: 1 prog 2 const 3 struct 5 fn 6 param 7 type 8 let 9 var
1335 REM 10 pname 11 pskip 12 ptuple 13 asg 14 tasg 15 cstmt 16 if 17 while 18 for 21 break 22
1340 REM continue 23 return 24 block 25 int 26 float 27 str 28 true 29 false 30 name 32 neg 33 not
1345 REM 34 bin 35 call 37 ref 38 conv 41 range 49 ifx ...); N(i,1..3) u and enum fields; N(i,4)
1350 REM F*1E9+L; N(i,5) column; N(i,6) string; N(i,7) first child; N(i,8) next sibling; N(i,9) parent.
1355 REM M(i,0) first node of the subtree (post-order range M(i,0)..i); M(i,1) type: -1 untyped
1360 REM integer constant, 0 error, 1 void, 2 bool, 3 i64, 4 f64, 5 str, 6-9 handles, >= 10 a T row;
1365 REM M(i,2) symbol (Y row, -p predeclared slot p, 0 none; pname, param, for: the local bound);
1370 REM M(i,3) errors recorded before the node was checked; M(i,4) pname: var rule f64 (1), return:
1375 REM tret (1); M(i,5) C row of a literal; M(i,6) children; M(i,7) cvt to f64 after the node (1);
1380 REM M(i,8) bin: powk k + 10, < 0: writing jumps past node -M(i,8) (em_expr); M(i,9) the
1385 REM statement ends every path with a return (1).
1390 REM Y(s,0) 1 fn 2 const 3 struct 4 local; Y(s,1) name; Y(s,2) type (fn: result); Y(s,3) node;
1395 REM Y(s,4) local: 1 let 2 var 3 for 4 par 5 ref par, fn: elemental, const: 0 1 2 (checked);
1400 REM Y(s,5) lid / fid / cid; Y(s,6) local: pname of a var-rule candidate, fn: np; Y(s,7) fn: nr,
1405 REM const: value (cval: 0 not yet 1 i64 2 f64 3 none); Y(s,8) local: function, fn: last local row,
1410 REM const: C row of the value; Y(s,9) fn: first local row. Row 1 is .main, items follow.
1415 REM T(t,0) 1 tvec 7 ttuple 0 continuation; T(t,1) element or count; tuple components in the
1420 REM next rows, 9 per row (columns 0-8); T(t,9) the written id (DESIGN 3.5.1).
1425 REM W(1..) the value stack of evx; W(..199999) scope stack, pairs (name, symbol), marker -1; W(180001..)
1430 REM written types in id order (emission only, the scopes are empty then). X(1) nodes X(2) strings X(3)
1435 REM symbols X(4) last T row X(5) C rows X(6) key of the first error (0 none) X(7) its node X(8)
1440 REM its argument count X(9) errors recorded X(10) capacity overflow X(11) evx stack base X(12)
1445 REM scope stack top X(13) lids X(14) function X(15) loop depth X(16) var rule changed X(17)
1450 REM prog X(18) program file X(19) current node X(20)-X(25) LIM SYMBOLS TYPES CONSTS NODES
1455 REM STRINGS POWK X(27) emission mode X(28) types written X(29) top-level statements X(30)
1460 REM functions X(31) constants X(33) items X(34) FILE_VERSION; X$(1) error name, X$(2)-X$(4)
1465 REM its arguments, X$(10) predeclared names.
1470 REM ---- er: record error Q$ at node I (K arguments); the first in source order is kept ------
1475 SUB "er": N(), X(), X$(), I, Q$, A$, B$, C$, K
1480 LET X(9) = X(9) + 1
1485 IF X(10) = 1 THEN 1540
1490 LET Q = N(I, 4) * 10000 + N(I, 5)
1495 IF X(6) = 0 THEN 1505
1500 IF Q >= X(6) THEN 1540
1505 LET X(6) = Q
1510 LET X(7) = I
1515 LET X(8) = K
1520 LET X$(1) = Q$
1525 LET X$(2) = A$
1530 LET X$(3) = B$
1535 LET X$(4) = C$
1540 SUBEND
1545 REM ---- fatal: a capacity limit of DESIGN 2.7 is exceeded at node I (wins over every error) ---
1550 SUB "fatal": N(), X(), X$(), I, W$
1555 IF X(10) = 1 THEN 1590
1560 LET X(10) = 1
1565 LET X(6) = 1
1570 LET X(7) = I
1575 LET X(8) = 1
1580 LET X$(1) = "TOO_LARGE"
1585 LET X$(2) = W$
1590 SUBEND
1595 REM ---- intern: R = index of string Q$ in S$ (added if new; 0 if the table is full) ----------
1600 SUB "intern": S$(), X(), Q$, R
1605 LET L0 = LEN(Q$)
1610 FOR R = 1 TO X(2)
1615 IF LEN(S$(R)) <> L0 THEN 1625
1620 IF S$(R) = Q$ THEN 1655 ' equal lengths: = is exact
1625 NEXT R
1630 LET R = 0
1635 IF X(2) >= X(24) THEN 1655
1640 LET X(2) = X(2) + 1
1645 LET R = X(2)
1650 LET S$(R) = Q$
1655 SUBEND
1660 REM ---- pdx: R = slot of predeclared name Q$ (1-4 constants, 5-8 handles, 9- functions) -----
1665 SUB "pdx": X$(), Q$, R
1670 LET R = 0
1675 IF LEN(Q$) > 10 THEN 1700
1680 IF LEN(Q$) = 0 THEN 1700
1685 LET P = POS(X$(10), "|" & Q$ & " ")
1690 IF P = 0 THEN 1700
1695 LET R = (P - 1) / 12 + 1
1700 SUBEND
1705 REM ---- lk: R = the symbol named Q (S$ index): scopes, then items, then predeclared (-slot) ---
1710 SUB "lk": Y(), W(), X(), X$(), S$(), Q, R
1715 LET R = 0
1720 FOR J = X(12) TO 199998 STEP 2
1725 IF W(J) <> Q THEN 1740
1730 LET R = W(J + 1)
1735 GOTO 1780
1740 NEXT J
1745 FOR J = 2 TO X(33)
1750 IF Y(J, 1) <> Q THEN 1765
1755 LET R = J
1760 GOTO 1780
1765 NEXT J
1770 CALL "pdx": X$(), S$(Q), P
1775 LET R = -P
1780 SUBEND
1785 REM ---- nsym: R = a new, cleared symbol row (capacity: program too large: symbols) -----------
1790 SUB "nsym": N(), Y(), X(), X$(), R
1795 IF X(3) < X(20) THEN 1815
1800 CALL "fatal": N(), X(), X$(), X(19), "symbols"
1805 LET R = 0
1810 GOTO 1840
1815 LET X(3) = X(3) + 1
1820 LET R = X(3)
1825 FOR J = 0 TO 9
1830 LET Y(R, J) = 0
1835 NEXT J
1840 SUBEND
1845 REM ---- nloc: R = new local named Q, type D, mut U, declared by node I, bound in the scope;
1850 REM Z = 1 checks the binding (shadowing a predeclared name, a str local: DESIGN 2.6.2) ----
1855 SUB "nloc": N(), Y(), W(), X(), X$(), S$(), Q, D, U, I, Z, R
1860 CALL "nsym": N(), Y(), X(), X$(), R
1865 LET Y(R, 0) = 4
1870 LET Y(R, 1) = Q
1875 LET Y(R, 2) = D
1880 LET Y(R, 3) = I
1885 LET Y(R, 4) = U
1890 LET X(13) = X(13) + 1
1895 LET Y(R, 5) = X(13)
1900 LET Y(R, 8) = X(14)
1905 IF X(12) - 2 > X(11) THEN 1920
1910 CALL "fatal": N(), X(), X$(), I, "symbols"
1915 GOTO 1935
1920 LET X(12) = X(12) - 2
1925 LET W(X(12)) = Q
1930 LET W(X(12) + 1) = R
1935 IF Z = 0 THEN 1965
1940 CALL "pdx": X$(), S$(Q), P
1945 IF P = 0 THEN 1955
1950 CALL "er": N(), X(), X$(), I, "SHADOWS_PREDECLARED", "", "", "", 0
1955 IF D <> 5 THEN 1965
1960 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "strings", "", "", 1
1965 SUBEND
1970 REM ---- tyn: R$ = type Q written as in Sea source (DESIGN 2.6.2) -----------------------------
1975 SUB "tyn": T(), Q, R$
1980 IF Q < 10 THEN 2050
1985 IF T(Q, 0) = 1 THEN 2035
1990 LET R$ = "("
1995 FOR J = 1 TO T(Q, 1)
2000 CALL "tyn": T(), T(Q + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)), A$
2005 IF J = 1 THEN 2015
2010 LET R$ = R$ & ", "
2015 LET R$ = R$ & A$
2020 NEXT J
2025 LET R$ = R$ & ")"
2030 GOTO 2105
2035 CALL "tyn": T(), T(Q, 1), A$
2040 LET R$ = A$ & "[]"
2045 GOTO 2105
2050 LET A$ = "?|void|bool|i64|f64|str|Figure|Axes|Lu|Chol|"
2055 LET S = 1
2060 LET Q1 = Q
2065 IF Q1 >= 0 THEN 2075
2070 LET Q1 = 3
2075 FOR J = 0 TO Q1
2080 LET P = POS(A$, "|", S)
2085 IF J = Q1 THEN 2095
2090 LET S = P + 1
2095 NEXT J
2100 LET R$ = SEG$(A$, S, P - 1)
2105 SUBEND
2110 REM ---- tnew: R = K new cleared T rows (capacity: program too large: types) -------------------
2115 SUB "tnew": T(), N(), X(), X$(), K, R
2120 IF X(4) - 9 + K <= X(21) THEN 2140
2125 CALL "fatal": N(), X(), X$(), X(19), "types"
2130 LET R = 0
2135 GOTO 2175
2140 LET R = X(4) + 1
2145 LET X(4) = X(4) + K
2150 FOR J = R TO X(4)
2155 FOR H = 0 TO 9
2160 LET T(J, H) = 0
2165 NEXT H
2170 NEXT J
2175 SUBEND
2180 REM ---- tvec: R = the type E[] (one id per structure, DESIGN 3.5.1) ---------------------------
2185 SUB "tvec": T(), N(), X(), X$(), E, R
2190 FOR R = 10 TO X(4)
2195 IF T(R, 0) <> 1 THEN 2205
2200 IF T(R, 1) = E THEN 2225
2205 NEXT R
2210 CALL "tnew": T(), N(), X(), X$(), 1, R
2215 LET T(R, 0) = 1
2220 LET T(R, 1) = E
2225 SUBEND
2230 REM ---- ttup: R = the tuple of the K types U(1..K) ---------------------------------------------
2235 SUB "ttup": T(), N(), X(), X$(), U(), K, R
2240 LET R = 10
2245 IF R > X(4) THEN 2290
2250 IF T(R, 0) <> 7 THEN 2280
2255 IF T(R, 1) <> K THEN 2280
2260 FOR J = 1 TO K
2265 IF T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) <> U(J) THEN 2280
2270 NEXT J
2275 GOTO 2320
2280 LET R = R + 1
2285 GOTO 2245
2290 CALL "tnew": T(), N(), X(), X$(), 1 + INT((K + 8) / 9), R
2295 LET T(R, 0) = 7
2300 LET T(R, 1) = K
2305 FOR J = 1 TO K
2310 LET T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) = U(J)
2315 NEXT J
2320 SUBEND
2325 REM ---- stl: an untyped constant subtree I takes type D (f64, else i64); every literal that
2330 REM becomes f64 must be exact (integer constant not exact in f64, LANGUAGE 4.2) -----------
2335 SUB "stl": N(), M(), C(), X(), X$(), I, D
2340 IF M(I, 1) <> -1 THEN 2410
2345 LET D1 = D
2350 IF D1 = 4 THEN 2360
2355 LET D1 = 3
2360 FOR J = M(I, 0) TO I
2365 IF M(J, 1) <> -1 THEN 2405
2370 LET M(J, 1) = D1
2375 IF D1 <> 4 THEN 2405
2380 IF N(J, 0) <> 25 THEN 2405
2385 LET R0 = M(J, 5)
2390 CALL "FEFRI": C(R0, 1), C(R0, 2), C(R0, 3), C(R0, 4), A3, A2, A1, A0, V
2395 IF V = 0 THEN 2405
2400 CALL "er": N(), X(), X$(), J, "NOT_EXACT_F64", "", "", "", 0
2405 NEXT J
2410 SUBEND
2415 REM ---- vu: R = the type of I used as one value; a multiple-result or void call is an error --
2420 SUB "vu": N(), M(), T(), X(), X$(), I, R
2425 LET R = M(I, 1)
2430 IF R < 10 THEN 2455
2435 IF T(R, 0) <> 7 THEN 2470
2440 CALL "er": N(), X(), X$(), I, "MULTI_VALUE", "", "", "", 0
2445 LET R = 0
2450 GOTO 2470
2455 IF R <> 1 THEN 2470
2460 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", "0", "1", "", 2
2465 LET R = 0
2470 SUBEND
2475 REM ---- cv: the value I stored into type D (initialisation, assignment, argument, return):
2480 REM untyped constants take D, i64 -> f64 is a cvt, anything else a type mismatch -----------
2485 SUB "cv": N(), M(), T(), C(), X(), X$(), I, D
2490 CALL "vu": N(), M(), T(), X(), X$(), I, T1
2495 IF T1 = 0 THEN 2560
2500 IF D = 0 THEN 2560
2505 IF T1 <> -1 THEN 2520
2510 CALL "stl": N(), M(), C(), X(), X$(), I, D
2515 LET T1 = M(I, 1)
2520 IF T1 = D THEN 2560
2525 IF T1 <> 3 THEN 2545
2530 IF D <> 4 THEN 2545
2535 LET M(I, 7) = 1
2540 GOTO 2560
2545 CALL "tyn": T(), D, A$
2550 CALL "tyn": T(), T1, B$
2555 CALL "er": N(), X(), X$(), I, "TYPE_MISMATCH", A$, B$, "", 2
2560 SUBEND
2565 REM ---- cand: an f64 is stored into local R: a var-rule candidate becomes f64 (Decision 8) ----
2570 SUB "cand": M(), Y(), X(), R
2575 IF R <= 0 THEN 2600
2580 IF Y(R, 6) = 0 THEN 2600
2585 IF M(Y(R, 6), 4) = 1 THEN 2600
2590 LET M(Y(R, 6), 4) = 1
2595 LET X(16) = 1
2600 SUBEND
2605 REM ---- resc: R$ = the bytes S$ written back as a string literal's source text (LANGUAGE 3.5):
2610 REM \" \\ \n \t \r \0, other control bytes \xHH, every other byte itself (DESIGN 2.6.2) ----
2615 SUB "resc": S$, R$
2620 DIM B(4100)
2625 LET R$ = ""
2630 LET L0 = LEN(S$)
2635 IF L0 = 0 THEN 2770
2640 CHANGE S$ TO B
2645 FOR J = 1 TO L0
2650 LET C1 = B(J)
2655 IF C1 = 34 THEN 2705
2660 IF C1 = 92 THEN 2705
2665 IF C1 = 10 THEN 2715
2670 IF C1 = 9 THEN 2725
2675 IF C1 = 13 THEN 2735
2680 IF C1 = 0 THEN 2745
2685 IF C1 < 32 THEN 2755
2690 IF C1 = 127 THEN 2755
2695 LET R$ = R$ & SEG$(S$, J, J)
2700 GOTO 2765
2705 LET R$ = R$ & "\" & SEG$(S$, J, J)
2710 GOTO 2765
2715 LET R$ = R$ & "\n"
2720 GOTO 2765
2725 LET R$ = R$ & "\t"
2730 GOTO 2765
2735 LET R$ = R$ & "\r"
2740 GOTO 2765
2745 LET R$ = R$ & "\0"
2750 GOTO 2765
2755 LET H = INT(C1 / 16)
2760 LET R$ = R$ & "\x" & SEG$("0123456789ABCDEF", H + 1, H + 1) & SEG$("0123456789ABCDEF", C1 - 16 * H + 1, C1 - 16 * H + 1)
2765 NEXT J
2770 SUBEND
2775 REM ---- kid: R = child J of node I ----------------------------------------------------------
2780 SUB "kid": N(), I, J, R
2785 LET R = N(I, 7)
2790 FOR H = 2 TO J
2795 LET R = N(R, 8)
2800 NEXT H
2805 SUBEND
2810 REM ---- opn: R$ = binary operator O as written (LANGUAGE 6.1) --------------------------------
2815 SUB "opn": O, R$
2820 LET A$ = "+ - * / % ^ @ == != < <= > >= & | && || "
2825 LET S = 1
2830 FOR J = 1 TO O
2835 LET P = POS(A$, " ", S)
2840 IF J = O THEN 2850
2845 LET S = P + 1
2850 NEXT J
2855 LET R$ = SEG$(A$, S, P - 1)
2860 SUBEND
2865 REM ---- pos: R$ = position F:L:C of node I (DESIGN 3.1) ---------------------------------------
2870 SUB "pos": N(), I, R$
2875 LET F = INT(N(I, 4) / 1E9)
2880 LET R$ = STR$(F) & ":" & STR$(N(I, 4) - F * 1E9) & ":" & STR$(N(I, 5))
2885 SUBEND
