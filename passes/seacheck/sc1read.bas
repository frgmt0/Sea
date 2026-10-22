535 REM ---- sc_read: the header and the whole tree of sea.res into N M C S$ T (DESIGN 3.1-3.4.1) ---
540 REM Every record is checked against passes.txt (opcode of set A, field count with repeated and
545 REM optional fields, field encodings, enumeration words) and built with one stack (DESIGN 3.3).
550 REM A record has up to 72 fields with its opcode (3.4.1 "Reading sea.res in seacheck"). Node
555 REM fields: pos to N(i,4..5), the first string to N(i,6) (interned), the first u and enum fields
560 REM of a sea.ast record to N(i,1..3) (enums as the private codes of E1$; the npos of for to the
565 REM next two), an i or f literal to a C row (M(i,5), one row per distinct value). A replacement
570 REM record (codes 50-63) becomes the node of the record it replaces (rfn fn, rst struct, rcn*
575 REM const, rpname pname, rfor for, rint int, rname name, rpowk bin) with its new fields in
580 REM free slots of N(i,1..3) and M(i,1..4) (layout: the REM block of sc2util). rerr and rtup are
585 REM not nodes: rerr is the first error found (X(6) X(7)=0 X(8) X(36) X(37) X$(1..4), not
590 REM interned), rtup a T row (W(150000+id)). prog is row 0 (not counted as a node).
595 REM locals: B B$ V$ enums, R R$ records, Q Q$ fields (tb_records), G record row of each kind,
600 REM K1$ kind slots, E1$ enum codes, G$ fields, U u values by field, V values in order, L limbs,
605 REM D0 stack depth, D9 prog seen, D8 0 before rerr, 1 after it, 2 after an rtup, 3 in the tree
610 SUB "sc_read": P$, E(), E$(), E0, N(), M(), C(), S$(), W(), T(), X(), X$(), F$(), N1, H(), O()
615 DIM B(39,2), B$(39), V$(299), R(399,9), R$(399), Q(1499,3), Q$(1499), Z(8), G$(73), U(72), L(4)
620 DIM G(63), A$(1), V(140), Y(70)
625 REM the 63 record kinds of sea.res, in this pass's private order (10-byte slots "|name    ")
630 LET L$ = "prog const struct field fn param type let var pname pskip ptuple asg tasg cstmt if while "
635 LET L$ = L$ & "for match arm break continue return block int float str true false name dollar neg "
640 LET L$ = L$ & "not bin call narg ref conv index all range rangev dot array row slit rlit init ifx "
645 LET L$ = L$ & "rerr rtup rfn rst rcni rcnf rcnb rcne rcn rpname rfor rint rname rpowk "
650 LET K1$ = ""
655 LET S = 1
660 LET P = POS(L$, " ", S)
665 IF P = 0 THEN 685
670 LET K1$ = K1$ & SEG$("|" & SEG$(L$, S, P - 1) & "          ", 1, 10)
675 LET S = P + 1
680 GOTO 660
685 REM the node kind each replacement record becomes (kinds 52-63)
690 LET R9$ = "05030202020202101825303400"
695 REM the enumeration words of sea.ast and their private codes: "|binop.add=01|..."
700 LET L$ = "binop:add sub mul div mod pow matmul eq ne lt le gt ge band bor and or;"
705 LET L$ = L$ & "asgop:set add sub mul div;shape:s v m fv fm;cvtype:f64 i64 str;"
710 LET E1$ = ""
715 LET S = 1
720 IF S > LEN(L$) THEN 805
725 LET P = POS(L$, ":", S)
730 LET A$ = SEG$(L$, S, P - 1)
735 LET S = P + 1
740 LET V = 0
745 LET P = POS(L$, " ", S)
750 LET P1 = POS(L$, ";", S)
755 IF P = 0 THEN 785
760 IF P > P1 THEN 785
765 LET V = V + 1
770 LET E1$ = E1$ & "|" & A$ & "." & SEG$(L$, S, P - 1) & "=" & SEG$(STR$(100 + V), 2, 3)
775 LET S = P + 1
780 GOTO 745
785 LET V = V + 1
790 LET E1$ = E1$ & "|" & A$ & "." & SEG$(L$, S, P1 - 1) & "=" & SEG$(STR$(100 + V), 2, 3)
795 LET S = P1 + 1
800 GOTO 720
805 LET E1$ = E1$ & "|"
810 REM passes.txt, and the record row of every kind
815 LET Z(1) = 39
820 LET Z(2) = 299
825 LET Z(3) = 399
830 LET Z(4) = 1499
835 CALL "tb_records": P$, E(), E$(), E0, B(), B$(), V$(), R(), R$(), Q(), Q$(), Z()
840 FOR K = 1 TO 63
845 LET G(K) = 0
850 LET A$ = SEG$(K1$, 10 * K - 8, 10 * K)
855 FOR J = 1 TO Z(7)
860 IF R(J, 1) <> 1 THEN 875
865 IF R$(J) <> A$ THEN 875 ' = ignores the padding blanks of A$
870 LET G(K) = J
875 NEXT J
880 IF G(K) > 0 THEN 890
885 CALL "dg_bug": P$, "passes.txt has no sea.res record " & A$
890 NEXT K
895 CALL "io_hdr": 1, P$, E(), E$(), E0, B(), B$(), V$(), Z(5), X(34), T$, F$(), 100, N1, L$
900 REM the target, for the header of sea.hir1, in X$(11)
905 LET X$(11) = T$
910 LET L9 = N1 + 3
915 LET D0 = 0
920 LET D9 = 0
925 LET D8 = 0
930 LET X(32) = 9
935 REM ---- one record per pass of this loop; L$ holds it
940 IF LEN(L$) <> 4 THEN 950
945 IF L$ = "#end" THEN 2215
950 IF D9 = 1 THEN 2230
955 CALL "io_split": L$, G$(), 73, G0
960 IF G0 < 1 THEN 2230
965 LET P1 = POS(K1$, "|" & G$(1) & " ")
970 IF P1 = 0 THEN 2230
975 LET K0 = (P1 - 1) / 10 + 1
980 LET R0 = G(K0)
985 REM the place of a record: rerr first (at most one), then the rtup records, then the tree
990 IF K0 > 51 THEN 1035
995 IF K0 < 50 THEN 1035
1000 IF K0 = 51 THEN 1020
1005 IF D8 > 0 THEN 2230
1010 LET D8 = 1
1015 GOTO 1140
1020 IF D8 > 2 THEN 2230
1025 LET D8 = 2
1030 GOTO 1140
1035 LET D8 = 3
1040 REM an int must be an rint in sea.res (3.4.1)
1045 IF K0 = 25 THEN 2230
1050 LET K = K0
1055 IF K0 < 52 THEN 1065
1060 LET K = VAL(SEG$(R9$, 2 * K0 - 103, 2 * K0 - 102))
1065 REM prog, the last record, takes row 0: it is not counted against LIM_NODES
1070 LET I = 0
1075 IF K = 1 THEN 1120
1080 IF X(1) < X(23) THEN 1110
1085 REM more nodes than the table holds: reported at the position of the node being read
1090 CALL "io_pos": G$(2), F1, L1, C1, T
1095 IF T <> 0 THEN 2230
1100 LET A$(1) = "nodes"
1105 CALL "dg_compile": P$, F$(), N1, F1, L1, C1, "TOO_LARGE", A$(), 1, E(), E$(), E0
1110 LET I = X(1) + 1
1115 LET X(1) = I
1120 LET N(I, 0) = K
1125 FOR J = 1 TO 9
1130 LET N(I, J) = 0
1135 NEXT J
1140 REM ---- the fields in order: a field that repeats takes the value of its count field
1145 LET S1 = 0
1150 LET Y9 = 0
1155 LET N9 = 0
1160 LET V0 = 0
1165 LET F9 = 1
1170 FOR J = 1 TO R(R0, 4)
1175 LET Q0 = R(R0, 3) + J - 1
1180 LET Y1 = Q(Q0, 1)
1185 LET U(J) = 0
1190 LET H9 = 1
1195 IF Q(Q0, 3) = 0 THEN 1205
1200 LET H9 = U(Q(Q0, 3))
1205 FOR H8 = 1 TO H9
1210 LET F9 = F9 + 1
1215 IF F9 > G0 THEN 2230
1220 LET F0$ = G$(F9)
1225 IF F0$ <> "-" THEN 1235
1230 IF Q(Q0, 2) = 1 THEN 1775
1235 IF Y1 = 1 THEN 1280
1240 IF Y1 = 2 THEN 1370
1245 IF Y1 = 3 THEN 1415
1250 IF Y1 = 4 THEN 1525
1255 IF Y1 = 5 THEN 1605
1260 IF Y1 = 8 THEN 1280
1265 IF Y1 = 9 THEN 1280
1270 IF Y1 > 100 THEN 1710
1275 GOTO 2230
1280 CALL "io_u": F0$, V, T
1285 IF T <> 0 THEN 2230
1290 IF Y1 <> 9 THEN 1300
1295 IF V < 1 THEN 2230
1300 IF H9 > 1 THEN 1310
1305 LET U(J) = V
1310 IF Y1 <> 8 THEN 1335
1315 REM a ty field: 0, 1-9 or the id of an rtup already read, as its T row
1320 IF V < 10 THEN 1335
1325 IF V >= X(32) + 1 THEN 2230
1330 LET V = W(150000 + V)
1335 IF K0 > 49 THEN 1355
1340 LET S1 = S1 + 1
1345 LET N(I, S1) = V
1350 GOTO 1775
1355 LET V0 = V0 + 1
1360 LET V(V0) = V
1365 GOTO 1775
1370 CALL "io_i": F0$, V, K2, L(), T
1375 IF T <> 0 THEN 2230
1380 IF K0 = 63 THEN 1390
1385 GOTO 1425
1390 REM the k of rpowk: |k| <= LIM_POWK
1395 IF K2 <> 0 THEN 2230
1400 IF ABS(V) > X(25) THEN 2230
1405 LET N(I, 2) = V
1410 GOTO 1775
1415 CALL "io_f": F0$, L(), T
1420 IF T <> 0 THEN 2230
1425 IF K0 < 50 THEN 1460
1430 IF K0 = 61 THEN 1455
1435 REM the value of an rcni or rcnf: kept as two 32-bit halves in M(i,1..2)
1440 LET M(I, 1) = L(1) * 65536 + L(2)
1445 LET M(I, 2) = L(3) * 65536 + L(4)
1450 GOTO 1775
1455 IF Y1 = 3 THEN 1500
1460 REM one C row per distinct value (LIM_CONSTS counts distinct values, DESIGN 2.7)
1465 CALL "cnew": C(), H(), X(), Y1 + 1, L(1), L(2), L(3), L(4), H1
1470 IF H1 > 0 THEN 1490
1475 LET A$(1) = "constants"
1480 LET F1 = INT(N(I, 4) / 1E9)
1485 CALL "dg_compile": P$, F$(), N1, F1, N(I, 4) - F1 * 1E9, N(I, 5), "TOO_LARGE", A$(), 1, E(), E$(), E0
1490 LET M(I, 5) = H1
1495 GOTO 1775
1500 REM rint: the fv bits in N(i,1..2), N(i,3) = 1 (an fv of - leaves 0: not exact in f64)
1505 LET N(I, 1) = L(1) * 65536 + L(2)
1510 LET N(I, 2) = L(3) * 65536 + L(4)
1515 LET N(I, 3) = 1
1520 GOTO 1775
1525 CALL "io_unesc": F0$, 0, S0$, T
1530 IF T <> 0 THEN 2230
1535 IF K0 <> 50 THEN 1560
1540 REM the substitutions of rerr: not interned
1545 IF H8 > 3 THEN 2230
1550 LET X$(H8 + 1) = S0$
1555 GOTO 1775
1560 IF N9 > 0 THEN 2230
1565 LET N9 = 1
1570 CALL "intern": S$(), X(), O(), S0$, H
1575 IF H > 0 THEN 1595
1580 LET A$(1) = "strings"
1585 LET F1 = INT(N(I, 4) / 1E9)
1590 CALL "dg_compile": P$, F$(), N1, F1, N(I, 4) - F1 * 1E9, N(I, 5), "TOO_LARGE", A$(), 1, E(), E$(), E0
1595 LET N(I, 6) = H
1600 GOTO 1775
1605 CALL "io_pos": F0$, F1, L1, C1, T
1610 IF T <> 0 THEN 2230
1615 IF F1 >= N1 THEN 2230
1620 IF Y9 = 1 THEN 1670
1625 LET Y9 = 1
1630 IF K0 = 50 THEN 1650
1635 LET N(I, 4) = F1 * 1E9 + L1
1640 LET N(I, 5) = C1
1645 GOTO 1775
1650 LET X(36) = F1 * 1E9 + L1
1655 LET X(37) = C1
1660 GOTO 1775
1665 REM a later pos field (the npos of for and rfor, the epos of rcne)
1670 IF K0 = 57 THEN 1695
1675 LET N(I, S1 + 1) = F1 * 1E9 + L1
1680 LET N(I, S1 + 2) = C1
1685 LET S1 = S1 + 2
1690 GOTO 1775
1695 LET M(I, 1) = F1 * 1E9 + L1
1700 LET M(I, 2) = C1
1705 GOTO 1775
1710 CALL "tb_word": B(), V$(), Y1 - 100, F0$, H
1715 IF H = 0 THEN 2230
1720 IF K0 < 50 THEN 1745
1725 REM nkind and cerr: the word's place in its enumeration (nkind loc=1 ... none=6)
1730 LET V0 = V0 + 1
1735 LET V(V0) = H
1740 GOTO 1775
1745 LET A$ = B$(Y1 - 100)
1750 LET H = POS(E1$, "|" & A$ & "." & F0$ & "=")
1755 IF H > 0 THEN 1765
1760 CALL "dg_bug": P$, "enumeration word " & A$ & "." & F0$ & " unknown to this pass"
1765 LET S1 = S1 + 1
1770 LET N(I, S1) = VAL(SEG$(E1$, H + LEN(A$) + LEN(F0$) + 3, H + LEN(A$) + LEN(F0$) + 4))
1775 NEXT H8
1780 NEXT J
1785 IF F9 <> G0 THEN 2230
1790 IF K0 < 50 THEN 2030
1795 ON K0 - 49 GOTO 1800, 1810, 1870, 1905, 1920, 1920, 1920, 1920, 1920, 1975, 1975, 2030, 2000, 2015
1800 CALL "sc_rerr": P$, E(), E$(), E0, X(), X$(), V()
1805 GOTO 2205
1810 REM rtup id n t1..tn: ids dense from 10, n >= 2
1815 IF V(1) <> X(32) + 1 THEN 2230
1820 IF V(2) < 2 THEN 2230
1825 FOR J = 1 TO V(2)
1830 LET Y(J) = V(J + 2)
1835 NEXT J
1840 LET X(19) = 0
1845 CALL "ttup": T(), N(), X(), X$(), Y(), V(2), H
1850 IF H = 0 THEN 2205
1855 LET X(32) = V(1)
1860 LET W(150000 + V(1)) = H
1865 GOTO 2205
1870 REM rfn: el np nr (as fn) fid rty, the parameter types follow
1875 LET N(I, 1) = V(1)
1880 LET N(I, 2) = V(2)
1885 LET N(I, 3) = V(3)
1890 LET M(I, 2) = V(4)
1895 LET M(I, 1) = V(5)
1900 GOTO 2030
1905 LET N(I, 1) = V(1)
1910 LET N(I, 2) = V(2)
1915 GOTO 2030
1920 REM rcni rcnf rcnb rcne rcn: t (as const), cid, N(i,3) the outcome 1-5; rcnb v, rcne e
1925 LET N(I, 1) = V(1)
1930 LET N(I, 2) = V(2)
1935 LET N(I, 3) = K0 - 53
1940 IF K0 = 56 THEN 1960
1945 IF K0 <> 57 THEN 2030
1950 LET M(I, 4) = V(3)
1955 GOTO 2030
1960 IF V(3) > 1 THEN 2230
1965 LET M(I, 1) = V(3)
1970 GOTO 2030
1975 IF K0 = 60 THEN 1990
1980 LET N(I, 1) = V(1)
1985 GOTO 2030
1990 LET N(I, 3) = V(1)
1995 GOTO 2030
2000 LET N(I, 1) = V(1)
2005 LET N(I, 2) = V(2)
2010 GOTO 2030
2015 LET N(I, 1) = 6
2020 LET N(I, 3) = 1
2025 REM ---- the children: the pops of the record (DESIGN 3.3), the earliest-written first
2030 LET P0 = 0
2035 FOR H = 1 TO R(R0, 5)
2040 LET V = R(R0, 5 + H)
2045 IF V < 0 THEN 2060
2050 LET P0 = P0 + V
2055 GOTO 2065
2060 LET P0 = P0 + U(-V)
2065 NEXT H
2070 IF P0 > D0 THEN 2235
2075 LET M(I, 6) = P0
2080 LET M(I, 0) = I
2085 IF P0 = 0 THEN 2170
2090 LET N(I, 7) = W(D0 - P0 + 1)
2095 LET M(I, 0) = M(W(D0 - P0 + 1), 0)
2100 FOR H = D0 - P0 + 1 TO D0
2105 LET N(W(H), 9) = I
2110 IF H = D0 THEN 2120
2115 LET N(W(H), 8) = W(H + 1)
2120 NEXT H
2125 LET D0 = D0 - P0
2130 IF K0 <> 52 THEN 2170
2135 REM rfn: the parameter types onto its first np children, the param nodes
2140 LET H = N(I, 7)
2145 FOR J = 1 TO V(2)
2150 IF N(H, 0) <> 6 THEN 2230
2155 LET M(H, 1) = V(5 + J)
2160 LET H = N(H, 8)
2165 NEXT J
2170 IF K = 1 THEN 2190
2175 LET D0 = D0 + 1
2180 LET W(D0) = I
2185 GOTO 2205
2190 IF D0 <> 0 THEN 2235
2195 LET D9 = 1
2200 LET X(17) = I
2205 CALL "io_read": 1, L$, L9, P$, E(), E$(), E0
2210 GOTO 940
2215 IF D9 = 0 THEN 2235
2220 CALL "io_end": 1, P$, E(), E$(), E0
2225 GOTO 2240
2230 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
2235 CALL "dg_internal": P$, "BAD_TREE", E(), E$(), E0
2240 SUBEND
2245 REM ---- sc_rerr: the rerr record (code V(1), k V(2), strings in X$(2..)) becomes the first error
2250 REM found (DESIGN 2.6.2 "Order across the two programs"): a code of phase C2 with k equal to
2255 REM the number of its args letters; X(7) = 0 marks it (its position is X(36) X(37)) -----------
2260 SUB "sc_rerr": P$, E(), E$(), E0, X(), X$(), V()
2265 FOR J = 1 TO E0
2270 IF E(J) <> V(1) THEN 2325
2275 IF E$(J, 2) <> "C2" THEN 2330
2280 LET K = LEN(E$(J, 4))
2285 IF E$(J, 4) <> "-" THEN 2295
2290 LET K = 0
2295 IF K <> V(2) THEN 2330
2300 LET X$(1) = E$(J, 1)
2305 LET X(6) = X(36) * 10000 + X(37)
2310 LET X(7) = 0
2315 LET X(8) = K
2320 GOTO 2335
2325 NEXT J
2330 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
2335 SUBEND
