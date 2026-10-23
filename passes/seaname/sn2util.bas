1475 REM ---- table layouts of seaname --------------------------------------------------------------
1480 REM N(i,0) kind 1-49 (sc_read's list: 1 prog 2 const 3 struct 5 fn 6 param 7 type 8 let 9 var
1485 REM 10 pname 11 pskip 12 ptuple 13 asg 14 tasg 15 cstmt 16 if 17 while 18 for 19 match 23 return
1490 REM 24 block 25 int 26 float 28 true 29 false 30 name 32 neg 33 not 34 bin 35 call 37 ref 41
1495 REM range ...); N(i,1..3) u and enum fields (for: npos in N(i,1..2)); N(i,4) F*1E9+L; N(i,5)
1500 REM column; N(i,6) string; N(i,7) first child; N(i,8) next sibling; N(i,9) parent.
1505 REM M(i,0) first node of the subtree (post-order range M(i,0)..i); M(i,1) type on the typed
1510 REM path (rs_expr): -1 untyped integer constant, 0 none or error, 2 bool, 3 i64, 4 f64, 5 str,
1515 REM >= 10 a T row; param: its type (ck_sig); M(i,2) symbol (Y row, -p predeclared slot p, 0 none;
1520 REM an entered item: its own row; pname, param, for: the local); M(i,4) 1: name, pname or for
1525 REM is replaced (rname rpname rfor); M(i,5) C row of a literal; M(i,6) children; M(i,7) cvt to f64
1530 REM after the node (1); M(i,8) bin: rpowk k + 10. A type node (tylk, tyres): M(i,1) its type, M(i,2)
1532 REM the symbol of an identifier base, M(i,3) the id of a predefined base (0: an identifier),
1533 REM M(i,4) 1: it becomes rtype, M(i,9) 1: resolved.
1535 REM Y(s,0) 1 fn 2 const 3 struct 4 local; Y(s,1) name; Y(s,2) type (fn: result; const: derived);
1540 REM Y(s,3) node; Y(s,4) local: mut, fn: elemental, const: 1 ovf, 2 div0 (rcne); Y(s,5) lid /
1545 REM fid / cid / sid; Y(s,6) fn: np, const: constant order (1 waiting, 2 done); Y(s,7) fn: nr,
1550 REM const: outcome (0 not yet 1 i64 2 f64 3 bool 5 none 6 failed); Y(s,8) local: function,
1555 REM const: value limbs 3,2 as L3*65536+L2 (bool: 0 or 1); Y(s,9) const: limbs 1,0, or rcne's node.
1560 REM Row 1 is .main, items follow (rows 2..X(33)), then the locals of each function.
1565 REM T(t,0) 1 T[] 2 T[,] 3 T[n] 4 T[r,c] 7 ttuple 0 continuation; T(t,1) element id (T(t,2..3) n or r c),
1570 REM or count with components (ids) in the next rows, 9 per row (columns 0-8); T(t,9) the id (3.4.2).
1575 REM W(1..) the constant order's stack, then the value stack of evx; W(..199999) scope stack,
1580 REM pairs (name, symbol), marker -1. X(1) nodes X(2) strings X(3) symbols X(4) last T row
1585 REM X(5) C rows X(6) key of the first error (0 none) X(7) its node X(8) its argument count
1590 REM X(9) errors recorded X(10) capacity overflow X(11) evx stack base X(12) scope stack top
1595 REM X(13) lids X(14) function X(17) prog X(19) current node X(20)-X(25) LIM SYMBOLS TYPES
1600 REM CONSTS NODES STRINGS POWK X(30) functions X(31) constants X(33) items X(34) FILE_VERSION
1605 REM X(35) LIM_DEC_FIELD X(36) X(37) npos of a symbols overflow X(38) types X(39) X(41) the
1610 REM predeclared slots of pow, sqrt X(40) the rules the typed path does not accept (fl) X(42)
1615 REM structs X(43) LIM_FIXED_ELEMS X(44) 1: a signature type (tyof); C(r,0) 3 i64 4 f64, C(r,1..4) limbs; X$(1) error name, X$(2)-X$(4) its arguments, X$(10) predeclared names.
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
2085 REM ---- nloc: R = new local named Q, declared by node I (pname, param, for), bound in the
2090 REM innermost scope; its lid is the next of the function (DESIGN 3.4.1 "Names") ------------
2095 SUB "nloc": N(), Y(), W(), X(), X$(), Q, I, R
2100 CALL "nsym": N(), Y(), X(), X$(), I, R
2105 LET Y(R, 0) = 4
2110 LET Y(R, 1) = Q
2115 LET Y(R, 3) = I
2120 LET X(13) = X(13) + 1
2125 LET Y(R, 5) = X(13)
2130 LET Y(R, 8) = X(14)
2135 IF X(12) - 2 > X(11) THEN 2150
2140 CALL "fsym": N(), X(), X$(), I
2145 GOTO 2165
2150 LET X(12) = X(12) - 2
2155 LET W(X(12)) = Q
2160 LET W(X(12) + 1) = R
2165 SUBEND
2210 REM ---- fl: the typed path meets a rule it does not accept (seaname reports no error: the
2215 REM constant being evaluated has no value, DESIGN 3.4.1 "Constants") -----------------------
2220 SUB "fl": X()
2225 LET X(40) = X(40) + 1
2230 SUBEND
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
2500 REM ---- ttup: R = the tuple of the K types U(1..K); a new one takes the next rtup id ---------
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
2577 LET T(R, 9) = 9 + X(38)
2580 FOR J = 1 TO K
2585 LET T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) = U(J)
2590 NEXT J
2595 SUBEND
2600 REM ---- stl: an untyped constant subtree I takes type D (f64, else i64); a literal that
2605 REM becomes f64 must be exact (LANGUAGE 4.2), else the typed path fails (fl) --------------
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
2675 CALL "fl": X()
2680 NEXT J
2685 SUBEND
2690 REM ---- vu: R = the type of I used as one value; a multiple-result or void call fails (fl) ---
2695 SUB "vu": N(), M(), T(), X(), X$(), I, R
2700 LET R = M(I, 1)
2705 IF R < 10 THEN 2730
2710 IF T(R, 0) <> 7 THEN 2745
2715 CALL "fl": X()
2720 LET R = 0
2725 GOTO 2745
2730 IF R <> 1 THEN 2745
2735 CALL "fl": X()
2740 LET R = 0
2745 SUBEND
2750 REM ---- cv: the value I stored into type D (the annotation of a const): untyped constants take
2755 REM D, i64 -> f64 is a cvt, anything else fails the typed path ---------------------------
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
2820 CALL "fl": X()
2835 SUBEND
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
