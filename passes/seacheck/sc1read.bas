550 REM ---- sc_read: the header and the whole tree of sea.res into N M C S$ T (DESIGN 3.1-3.4.1) ---
555 REM Every record is checked against passes.txt (opcode of set A, field count with repeated and
560 REM optional fields, field encodings, enumeration words) and built with one stack (DESIGN 3.3).
565 REM A record has up to 72 fields with its opcode (3.4.1 "Reading sea.res in seacheck"). Node
570 REM fields: pos to N(i,4..5), the first string to N(i,6) (interned), the first u and enum fields
575 REM of a sea.ast record to N(i,1..3) (enums as the private codes of E1$; the npos of for to the
580 REM next two), an i or f literal to a C row (M(i,5), one row per distinct value). A replacement
585 REM record (codes 50-63) becomes the node of the record it replaces (rfn fn, rst struct, rcn*
590 REM const, rpname pname, rfor for, rint int, rname name, rpowk bin) with its new fields in
595 REM free slots of N(i,1..3) and M(i,1..4) (layout: the REM block of sc2util). rerr and rtup are
600 REM not nodes: rerr is the first error found (X(6) X(7)=0 X(8) X(36) X(37) X$(1..4), not
605 REM interned), rtup a T row (W(150000+id)). prog is row 0 (not counted as a node).
610 REM locals: B B$ V$ enums, R R$ records, Q Q$ fields (tb_records), G record row of each kind,
615 REM K1$ kind slots, E1$ enum codes, G$ fields, U u values by field, V values in order, L limbs,
620 REM D0 stack depth, D9 prog seen, D8 0 before rerr, 1 after it, 2 after an rtup, 3 in the tree
625 SUB "sc_read": P$, E(), E$(), E0, N(), M(), C(), S$(), W(), T(), X(), X$(), F$(), N1, H(), O()
630 DIM B(39,2), B$(39), V$(299), R(399,9), R$(399), Q(1499,3), Q$(1499), Z(8), G$(73), U(72), L(4)
635 DIM G(72), A$(1), V(140)
640 REM the 72 record kinds of sea.res, in this pass's private order (10-byte slots "|name    ")
645 LET L$ = "prog const struct field fn param type let var pname pskip ptuple asg tasg cstmt if while "
650 LET L$ = L$ & "for match arm break continue return block int float str true false name dollar neg "
655 LET L$ = L$ & "not bin call narg ref conv index all range rangev dot array row slit rlit init ifx "
660 LET L$ = L$ & "rerr rtup rfn rst rcni rcnf rcnb rcne rcn rpname rfor rint rname rpowk rtvec rtmat "
665 LET L$ = L$ & "rtfvec rtfmat rtst rtfd rtype rslit rcns "
670 LET K1$ = ""
675 LET S = 1
680 LET P = POS(L$, " ", S)
685 IF P = 0 THEN 705
690 LET K1$ = K1$ & SEG$("|" & SEG$(L$, S, P - 1) & "          ", 1, 10)
695 LET S = P + 1
700 GOTO 680
705 REM the node kind each replacement record becomes (kinds 52-72; 64-69 are no nodes)
710 LET R9$ = "050302020202021018253034000000000000074602"
715 REM the enumeration words of sea.ast and their private codes: "|binop.add=01|..."
720 LET L$ = "binop:add sub mul div mod pow matmul eq ne lt le gt ge band bor and or;"
725 LET L$ = L$ & "asgop:set add sub mul div;shape:s v m fv fm;cvtype:f64 i64 str;"
730 LET E1$ = ""
735 LET S = 1
740 IF S > LEN(L$) THEN 825
745 LET P = POS(L$, ":", S)
750 LET A$ = SEG$(L$, S, P - 1)
755 LET S = P + 1
760 LET V = 0
765 LET P = POS(L$, " ", S)
770 LET P1 = POS(L$, ";", S)
775 IF P = 0 THEN 805
780 IF P > P1 THEN 805
785 LET V = V + 1
790 LET E1$ = E1$ & "|" & A$ & "." & SEG$(L$, S, P - 1) & "=" & SEG$(STR$(100 + V), 2, 3)
795 LET S = P + 1
800 GOTO 765
805 LET V = V + 1
810 LET E1$ = E1$ & "|" & A$ & "." & SEG$(L$, S, P1 - 1) & "=" & SEG$(STR$(100 + V), 2, 3)
815 LET S = P1 + 1
820 GOTO 740
825 LET E1$ = E1$ & "|"
830 REM passes.txt, and the record row of every kind
835 LET Z(1) = 39
840 LET Z(2) = 299
845 LET Z(3) = 399
850 LET Z(4) = 1499
855 CALL "tb_records": P$, E(), E$(), E0, B(), B$(), V$(), R(), R$(), Q(), Q$(), Z()
860 FOR K = 1 TO 72
865 LET G(K) = 0
870 LET A$ = SEG$(K1$, 10 * K - 8, 10 * K)
875 FOR J = 1 TO Z(7)
880 IF R(J, 1) <> 1 THEN 895
885 IF R$(J) <> A$ THEN 895 ' = ignores the padding blanks of A$
890 LET G(K) = J
895 NEXT J
900 IF G(K) > 0 THEN 910
905 CALL "dg_bug": P$, "passes.txt has no sea.res record " & A$
910 NEXT K
915 CALL "io_hdr": 1, P$, E(), E$(), E0, B(), B$(), V$(), Z(5), X(34), T$, F$(), 100, N1, L$
920 REM the target, for the header of sea.hir1, in X$(11)
925 LET X$(11) = T$
930 LET L9 = N1 + 3
935 LET D0 = 0
940 LET D9 = 0
945 LET D8 = 0
950 LET X(32) = 9
955 REM ---- one record per pass of this loop; L$ holds it
960 IF LEN(L$) <> 4 THEN 970
965 IF L$ = "#end" THEN 2385
970 IF D9 = 1 THEN 2400
975 CALL "io_split": L$, G$(), 73, G0
980 IF G0 < 1 THEN 2400
985 LET P1 = POS(K1$, "|" & G$(1) & " ")
990 IF P1 = 0 THEN 2400
995 LET K0 = (P1 - 1) / 10 + 1
1000 LET R0 = G(K0)
1005 REM the place of a record: rerr first (at most one), then the type table (rtup rtvec rtmat
1010 REM rtfvec rtfmat, DESIGN 3.4.2), then the tree. The records of 4g-2 (rtst rtfd rslit) are
1015 REM not written before 4g-2; rcns (4g-1) replaces a const.
1020 IF K0 < 50 THEN 1085
1025 IF K0 > 69 THEN 1080
1030 IF K0 > 67 THEN 2400
1035 IF K0 > 63 THEN 1065
1040 IF K0 > 51 THEN 1085
1045 IF K0 = 51 THEN 1065
1050 IF D8 > 0 THEN 2400
1055 LET D8 = 1
1060 GOTO 1210
1065 IF D8 > 2 THEN 2400
1070 LET D8 = 2
1075 GOTO 1210
1080 IF K0 = 71 THEN 2400
1085 IF D8 = 3 THEN 1110
1090 REM the first record of the tree: the type table is complete, its ty fields become T rows
1095 CALL "sc_tfix": T(), W(), X(), Z
1100 IF Z = 1 THEN 2400
1105 LET D8 = 3
1110 REM an int must be an rint in sea.res (3.4.1)
1115 IF K0 = 25 THEN 2400
1120 LET K = K0
1125 IF K0 < 52 THEN 1135
1130 LET K = VAL(SEG$(R9$, 2 * K0 - 103, 2 * K0 - 102))
1135 REM prog, the last record, takes row 0: it is not counted against LIM_NODES
1140 LET I = 0
1145 IF K = 1 THEN 1190
1150 IF X(1) < X(23) THEN 1180
1155 REM more nodes than the table holds: reported at the position of the node being read
1160 CALL "io_pos": G$(2), F1, L1, C1, T
1165 IF T <> 0 THEN 2400
1170 LET A$(1) = "nodes"
1175 CALL "dg_compile": P$, F$(), N1, F1, L1, C1, "TOO_LARGE", A$(), 1, E(), E$(), E0
1180 LET I = X(1) + 1
1185 LET X(1) = I
1190 LET N(I, 0) = K
1195 FOR J = 1 TO 9
1200 LET N(I, J) = 0
1205 NEXT J
1210 REM ---- the fields in order: a field that repeats takes the value of its count field
1215 LET S1 = 0
1220 LET Y9 = 0
1225 LET N9 = 0
1230 LET V0 = 0
1235 LET F9 = 1
1240 FOR J = 1 TO R(R0, 4)
1245 LET Q0 = R(R0, 3) + J - 1
1250 LET Y1 = Q(Q0, 1)
1255 LET U(J) = 0
1260 LET H9 = 1
1265 IF Q(Q0, 3) = 0 THEN 1275
1270 LET H9 = U(Q(Q0, 3))
1275 FOR H8 = 1 TO H9
1280 LET F9 = F9 + 1
1285 IF F9 > G0 THEN 2400
1290 LET F0$ = G$(F9)
1295 IF F0$ <> "-" THEN 1305
1300 IF Q(Q0, 2) = 1 THEN 1855
1305 IF Y1 = 1 THEN 1350
1310 IF Y1 = 2 THEN 1450
1315 IF Y1 = 3 THEN 1495
1320 IF Y1 = 4 THEN 1605
1325 IF Y1 = 5 THEN 1685
1330 IF Y1 = 8 THEN 1350
1335 IF Y1 = 9 THEN 1350
1340 IF Y1 > 100 THEN 1790
1345 GOTO 2400
1350 CALL "io_u": F0$, V, T
1355 IF T <> 0 THEN 2400
1360 IF Y1 <> 9 THEN 1370
1365 IF V < 1 THEN 2400
1370 IF H9 > 1 THEN 1380
1375 LET U(J) = V
1380 IF Y1 <> 8 THEN 1415
1385 REM a ty field of the tree: 0, 1-9 or an id of the type table, as its T row (a ty field of
1390 REM the table may name a later id: sc_tfix maps them at the end of the table)
1395 IF D8 < 3 THEN 1415
1400 IF V < 10 THEN 1415
1405 IF V >= X(32) + 1 THEN 2400
1410 LET V = W(150000 + V)
1415 IF K0 > 49 THEN 1435
1420 LET S1 = S1 + 1
1425 LET N(I, S1) = V
1430 GOTO 1855
1435 LET V0 = V0 + 1
1440 LET V(V0) = V
1445 GOTO 1855
1450 CALL "io_i": F0$, V, K2, L(), T
1455 IF T <> 0 THEN 2400
1460 IF K0 = 63 THEN 1470
1465 GOTO 1505
1470 REM the k of rpowk: |k| <= LIM_POWK
1475 IF K2 <> 0 THEN 2400
1480 IF ABS(V) > X(25) THEN 2400
1485 LET N(I, 2) = V
1490 GOTO 1855
1495 CALL "io_f": F0$, L(), T
1500 IF T <> 0 THEN 2400
1505 IF K0 < 50 THEN 1540
1510 IF K0 = 61 THEN 1535
1515 REM the value of an rcni or rcnf: kept as two 32-bit halves in M(i,1..2)
1520 LET M(I, 1) = L(1) * 65536 + L(2)
1525 LET M(I, 2) = L(3) * 65536 + L(4)
1530 GOTO 1855
1535 IF Y1 = 3 THEN 1580
1540 REM one C row per distinct value (LIM_CONSTS counts distinct values, DESIGN 2.7)
1545 CALL "cnew": C(), H(), X(), Y1 + 1, L(1), L(2), L(3), L(4), H1
1550 IF H1 > 0 THEN 1570
1555 LET A$(1) = "constants"
1560 LET F1 = INT(N(I, 4) / 1E9)
1565 CALL "dg_compile": P$, F$(), N1, F1, N(I, 4) - F1 * 1E9, N(I, 5), "TOO_LARGE", A$(), 1, E(), E$(), E0
1570 LET M(I, 5) = H1
1575 GOTO 1855
1580 REM rint: the fv bits in N(i,1..2), N(i,3) = 1 (an fv of - leaves 0: not exact in f64)
1585 LET N(I, 1) = L(1) * 65536 + L(2)
1590 LET N(I, 2) = L(3) * 65536 + L(4)
1595 LET N(I, 3) = 1
1600 GOTO 1855
1605 CALL "io_unesc": F0$, 0, S0$, T
1610 IF T <> 0 THEN 2400
1615 IF K0 <> 50 THEN 1640
1620 REM the substitutions of rerr: not interned
1625 IF H8 > 3 THEN 2400
1630 LET X$(H8 + 1) = S0$
1635 GOTO 1855
1640 IF N9 = 0 THEN 1645
1641 REM the value of an rcns, its second string: interned, its S$ index in M(i,1)
1642 IF K0 <> 72 THEN 2400
1645 LET N9 = N9 + 1
1650 CALL "intern": S$(), X(), O(), S0$, H
1655 IF H > 0 THEN 1675
1660 LET A$(1) = "strings"
1665 LET F1 = INT(N(I, 4) / 1E9)
1670 CALL "dg_compile": P$, F$(), N1, F1, N(I, 4) - F1 * 1E9, N(I, 5), "TOO_LARGE", A$(), 1, E(), E$(), E0
1675 IF N9 = 2 THEN 1678
1676 LET N(I, 6) = H
1677 GOTO 1855
1678 LET M(I, 1) = H
1680 GOTO 1855
1685 CALL "io_pos": F0$, F1, L1, C1, T
1690 IF T <> 0 THEN 2400
1695 IF F1 >= N1 THEN 2400
1700 IF Y9 = 1 THEN 1750
1705 LET Y9 = 1
1710 IF K0 = 50 THEN 1730
1715 LET N(I, 4) = F1 * 1E9 + L1
1720 LET N(I, 5) = C1
1725 GOTO 1855
1730 LET X(36) = F1 * 1E9 + L1
1735 LET X(37) = C1
1740 GOTO 1855
1745 REM a later pos field (the npos of for and rfor, the epos of rcne)
1750 IF K0 = 57 THEN 1775
1755 LET N(I, S1 + 1) = F1 * 1E9 + L1
1760 LET N(I, S1 + 2) = C1
1765 LET S1 = S1 + 2
1770 GOTO 1855
1775 LET M(I, 1) = F1 * 1E9 + L1
1780 LET M(I, 2) = C1
1785 GOTO 1855
1790 CALL "tb_word": B(), V$(), Y1 - 100, F0$, H
1795 IF H = 0 THEN 2400
1800 IF K0 < 50 THEN 1825
1805 REM nkind and cerr: the word's place in its enumeration (nkind loc=1 ... none=6)
1810 LET V0 = V0 + 1
1815 LET V(V0) = H
1820 GOTO 1855
1825 LET A$ = B$(Y1 - 100)
1830 LET H = POS(E1$, "|" & A$ & "." & F0$ & "=")
1835 IF H > 0 THEN 1845
1840 CALL "dg_bug": P$, "enumeration word " & A$ & "." & F0$ & " unknown to this pass"
1845 LET S1 = S1 + 1
1850 LET N(I, S1) = VAL(SEG$(E1$, H + LEN(A$) + LEN(F0$) + 3, H + LEN(A$) + LEN(F0$) + 4))
1855 NEXT H8
1860 NEXT J
1865 IF F9 <> G0 THEN 2400
1870 IF K0 < 50 THEN 2200
1875 ON K0 - 49 GOTO 1880, 1890, 2040, 2075, 2090, 2090, 2090, 2090, 2090, 2145, 2145, 2200, 2170, 2185, 1965, 1965, 1965, 1965, 2400, 2400, 2015, 2400, 2141
1880 CALL "sc_rerr": P$, E(), E$(), E0, X(), X$(), V()
1885 GOTO 2375
1890 REM rtup id n t1..tn: ids dense from 10, n >= 2; one T row and ceil(n/9) more (the ids of the
1895 REM components are mapped to T rows by sc_tfix)
1900 IF V(1) <> X(32) + 1 THEN 2400
1905 IF V(2) < 2 THEN 2400
1910 LET X(19) = 0
1915 CALL "tnew": T(), N(), X(), X$(), 1 + INT((V(2) + 8) / 9), H
1920 IF H = 0 THEN 2375
1925 LET T(H, 0) = 7
1930 LET T(H, 1) = V(2)
1935 FOR J = 1 TO V(2)
1940 LET T(H + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) = V(J + 2)
1945 NEXT J
1950 LET X(32) = V(1)
1955 LET W(150000 + V(1)) = H
1960 GOTO 2375
1965 REM rtvec, rtmat, rtfvec, rtfmat id elt [n | r c]: T(t,0) 1-4, the element id in T(t,1), the
1967 REM extents of a fixed-size one in T(t,2..3)
1970 IF V(1) <> X(32) + 1 THEN 2400
1975 LET X(19) = 0
1980 CALL "tnew": T(), N(), X(), X$(), 1, H
1985 IF H = 0 THEN 2375
1990 LET T(H, 0) = K0 - 63
1995 LET T(H, 1) = V(2)
1996 IF K0 < 66 THEN 2000
1997 LET T(H, 2) = V(3)
1998 IF K0 = 66 THEN 2000
1999 LET T(H, 3) = V(4)
2000 LET X(32) = V(1)
2005 LET W(150000 + V(1)) = H
2010 GOTO 2375
2015 REM rtype: shape (1 s 2 v 3 m 4 fv 5 fm) and nd as type, N(i,3) the T row of ty plus 1
2020 LET N(I, 1) = V(1)
2025 LET N(I, 2) = V(2)
2030 LET N(I, 3) = V(3) + 1
2035 GOTO 2200
2040 REM rfn: el np nr (as fn) fid rty, the parameter types follow
2045 LET N(I, 1) = V(1)
2050 LET N(I, 2) = V(2)
2055 LET N(I, 3) = V(3)
2060 LET M(I, 2) = V(4)
2065 LET M(I, 1) = V(5)
2070 GOTO 2200
2075 LET N(I, 1) = V(1)
2080 LET N(I, 2) = V(2)
2085 GOTO 2200
2090 REM rcni rcnf rcnb rcne rcn: t (as const), cid, N(i,3) the outcome 1-5; rcnb v, rcne e; rcns (2141) 6
2095 LET N(I, 1) = V(1)
2100 LET N(I, 2) = V(2)
2105 LET N(I, 3) = K0 - 53
2110 IF K0 = 56 THEN 2130
2115 IF K0 <> 57 THEN 2200
2120 LET M(I, 4) = V(3)
2125 GOTO 2200
2130 IF V(3) > 1 THEN 2400
2135 LET M(I, 1) = V(3)
2140 GOTO 2200
2141 LET N(I, 1) = V(1)
2142 LET N(I, 2) = V(2)
2143 LET N(I, 3) = 6
2144 GOTO 2200
2145 IF K0 = 60 THEN 2160
2150 LET N(I, 1) = V(1)
2155 GOTO 2200
2160 LET N(I, 3) = V(1)
2165 GOTO 2200
2170 LET N(I, 1) = V(1)
2175 LET N(I, 2) = V(2)
2180 GOTO 2200
2185 LET N(I, 1) = 6
2190 LET N(I, 3) = 1
2195 REM ---- the children: the pops of the record (DESIGN 3.3), the earliest-written first
2200 LET P0 = 0
2205 FOR H = 1 TO R(R0, 5)
2210 LET V = R(R0, 5 + H)
2215 IF V < 0 THEN 2230
2220 LET P0 = P0 + V
2225 GOTO 2235
2230 LET P0 = P0 + U(-V)
2235 NEXT H
2240 IF P0 > D0 THEN 2405
2245 LET M(I, 6) = P0
2250 LET M(I, 0) = I
2255 IF P0 = 0 THEN 2340
2260 LET N(I, 7) = W(D0 - P0 + 1)
2265 LET M(I, 0) = M(W(D0 - P0 + 1), 0)
2270 FOR H = D0 - P0 + 1 TO D0
2275 LET N(W(H), 9) = I
2280 IF H = D0 THEN 2290
2285 LET N(W(H), 8) = W(H + 1)
2290 NEXT H
2295 LET D0 = D0 - P0
2300 IF K0 <> 52 THEN 2340
2305 REM rfn: the parameter types onto its first np children, the param nodes
2310 LET H = N(I, 7)
2315 FOR J = 1 TO V(2)
2320 IF N(H, 0) <> 6 THEN 2400
2325 LET M(H, 1) = V(5 + J)
2330 LET H = N(H, 8)
2335 NEXT J
2340 IF K = 1 THEN 2360
2345 LET D0 = D0 + 1
2350 LET W(D0) = I
2355 GOTO 2375
2360 IF D0 <> 0 THEN 2405
2365 LET D9 = 1
2370 LET X(17) = I
2375 CALL "io_read": 1, L$, L9, P$, E(), E$(), E0
2380 GOTO 960
2385 IF D9 = 0 THEN 2405
2390 CALL "io_end": 1, P$, E(), E$(), E0
2395 GOTO 2410
2400 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
2405 CALL "dg_internal": P$, "BAD_TREE", E(), E$(), E0
2410 SUBEND
2415 REM ---- sc_rerr: the rerr record (code V(1), k V(2), strings in X$(2..)) becomes the first error
2420 REM found (DESIGN 2.6.2 "Order across the two programs"): a code of phase C2 with k equal to
2425 REM the number of its args letters; X(7) = 0 marks it (its position is X(36) X(37)) -----------
2430 SUB "sc_rerr": P$, E(), E$(), E0, X(), X$(), V()
2435 FOR J = 1 TO E0
2440 IF E(J) <> V(1) THEN 2495
2445 IF E$(J, 2) <> "C2" THEN 2500
2450 LET K = LEN(E$(J, 4))
2455 IF E$(J, 4) <> "-" THEN 2465
2460 LET K = 0
2465 IF K <> V(2) THEN 2500
2470 LET X$(1) = E$(J, 1)
2475 LET X(6) = X(36) * 10000 + X(37)
2480 LET X(7) = 0
2485 LET X(8) = K
2490 GOTO 2505
2495 NEXT J
2500 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
2505 SUBEND
2510 REM ---- sc_tfix: the end of the type table (DESIGN 3.4.2): every ty field of its records (read
2515 REM as ids, a field may name a later id) becomes the T row of that id; an element type must be
2520 REM bool, i64, f64 or str (4d: no struct types yet), a tuple component 1-9 or an id of the
2525 REM table. Z = 1 for a violation (BAD_RECORD) ----------------------------------------------
2530 SUB "sc_tfix": T(), W(), X(), Z
2535 LET Z = 0
2540 FOR I = 10 TO X(32)
2545 LET R = W(150000 + I)
2550 IF T(R, 0) = 7 THEN 2570
2555 IF T(R, 1) < 2 THEN 2625
2560 IF T(R, 1) > 5 THEN 2625
2565 GOTO 2615
2570 FOR J = 1 TO T(R, 1)
2575 LET R1 = R + 1 + INT((J - 1) / 9)
2580 LET C1 = J - 1 - 9 * INT((J - 1) / 9)
2585 LET V = T(R1, C1)
2590 IF V < 1 THEN 2625
2595 IF V < 10 THEN 2610
2600 IF V > X(32) THEN 2625
2605 LET T(R1, C1) = W(150000 + V)
2610 NEXT J
2615 NEXT I
2620 GOTO 2630
2625 LET Z = 1
2630 SUBEND
