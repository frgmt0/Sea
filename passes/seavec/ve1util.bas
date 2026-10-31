1000 REM ====================================================================================
1005 REM seavec part 1 (lines 1000-9999): set-up, the operand visitor, the facts of DESIGN 5.8's Terms
1010 REM and 2.12.6's constants, immediates, new registers, work lists (records appended above A0),
1015 REM the splice of a list in place of records of the function, and the block structure.
1020 REM ====================================================================================
1025 REM SETUP (once, after lirrw's header entry): S(999800+code) the record row of every internal
1030 REM code 1-119 (DESIGN 3.6.4; lirrw's table, API.md), S(999700+code) the x code of a scalar code
1035 REM the vector body maps (fadd..fmax fcmp fsel iand ior bnot mov ldf ldb stf stb), S(999600+k)
1040 REM S(999610+k) S(999620+k) the S$ rows of sea_f, sea_f_x, sea_f_y (f = log exp sin cos pow hypot,
1045 REM k = 1..6, named through the entries table), S(999650) the word avx2 of enumeration feat.
1050 FOR N3 = 1 TO 119
1055 LET S(999800 + N3) = 0
1060 NEXT N3
1065 FOR N3 = 1 TO Z(7)
1070 IF Q(N3, 6) = 0 THEN 1080
1075 LET S(999800 + Q(N3, 6)) = N3
1080 NEXT N3
1085 FOR N3 = 1 TO 119
1090 IF S(999800 + N3) = 0 THEN 1245
1095 NEXT N3
1100 LET X$ = "029082030083031084032085033088034089035090036086037087042095026096017116018117023118"
1105 LET X$ = X$ & "005005049074048076053078052080"
1110 FOR N3 = 1 TO LEN(X$) STEP 6
1115 LET S(999700 + VAL(SEG$(X$, N3, N3 + 2))) = VAL(SEG$(X$, N3 + 3, N3 + 5))
1120 NEXT N3
1125 LET O$ = "LOG   EXP   SIN   COS   POW   HYPOT "
1130 FOR K3 = 1 TO 6
1135 LET X$ = SEG$(O$, 6 * K3 - 5, 6 * K3)
1140 IF SEG$(X$, LEN(X$), LEN(X$)) <> " " THEN 1155
1145 LET X$ = SEG$(X$, 1, LEN(X$) - 1)
1150 GOTO 1140
1155 GOSUB 1200
1160 LET S(999600 + K3) = Q2
1165 LET X$ = X$ & "_X"
1170 GOSUB 1200
1175 LET S(999610 + K3) = Q2
1180 LET X$ = SEG$(X$, 1, LEN(X$) - 1) & "Y"
1185 GOSUB 1200
1190 LET S(999620 + K3) = Q2
1192 NEXT K3
1194 CALL "tb_enum": N$(), Z(5), "feat", X3
1195 CALL "tb_word": N(), W$(), X3, "avx2", X4
1196 LET S(999650) = X4
1197 IF X4 = 0 THEN 1245
1198 LET K2 = -1E6
1199 RETURN
1200 REM ENT: Q2 = the S$ row of the symbol of the entry named X$ (interned as lirrw interns it)
1205 FOR N3 = 1 TO N7
1210 IF LEN(Y$(N3, 1)) <> LEN(X$) THEN 1230
1215 IF Y$(N3, 1) <> X$ THEN 1230
1220 LET Z$ = Y$(N3, 2)
1225 GOTO 75000
1230 NEXT N3
1245 CALL "dg_bug": P$, "a record, entry or word that seavec writes is missing from the contract files"
1300 REM ---- VIS: visit the register operands of instruction N0 in field order; for each, O(P0) is the
1305 REM register and R0 its role (1 read, 2 written); mode V0 selects the callback (1400). Locals P0 W9
1310 REM J9 B3 J0 J8 R0 and U(field) (the u fields, for the repeat counts).
1315 LET P0 = I(N0, 2)
1320 LET W9 = I(N0, 1)
1325 IF W9 = 0 THEN 1399
1330 FOR J9 = 1 TO Q(W9, 4)
1335 LET B3 = Q(W9, 3) + J9 - 1
1340 LET R0 = F(B3, 0)
1345 IF R0 = 0 THEN 1395
1350 LET J0 = 1
1355 IF F(B3, 3) = 0 THEN 1365
1360 LET J0 = U(F(B3, 3))
1365 FOR J8 = 1 TO J0
1370 IF R0 > 2 THEN 1380
1375 IF O(P0) > 0 THEN 1400
1380 IF R0 = 5 THEN 1600
1385 LET P0 = P0 + 1 + INT(R0 / 7)
1390 NEXT J8
1395 NEXT J9
1399 RETURN
1400 ON V0 GOTO 1410, 1440, 1450, 1460, 1470, 1490, 1510, 1520, 1530, 1540, 1550, 1560, 1570, 1580, 1610, 1670, 1680, 1642, 1742, 1780, 1820, 1840
1405 REM 1 FACT: definitions (R3 R4), the sa slot (R5), reads (R8) of the function
1410 LET X5 = O(P0)
1412 IF R0 = 1 THEN 1436
1414 LET R(X5, 3) = R(X5, 3) + 1
1416 LET R(X5, 4) = N0
1418 IF FNC(N0) <> 4 THEN 1430
1420 IF R(X5, 5) = 0 THEN 1428
1422 IF R(X5, 5) = FNO(N0, 1) THEN 1385
1424 GOTO 1430
1428 LET R(X5, 5) = FNO(N0, 1)
1429 GOTO 1385
1430 LET R(X5, 5) = -1
1432 GOTO 1385
1436 LET R(X5, 8) = R(X5, 8) + 1
1438 GOTO 1385
1439 REM 2 MARKW: R(r,0) = K3 for the registers written
1440 IF R0 = 2 THEN 1442
1441 GOTO 1385
1442 LET R(O(P0), 0) = K3
1444 GOTO 1385
1449 REM 3 CNT: reads V(400000+r), writes V(500000+r) under the stamp V(600000+r) = K3
1450 LET X5 = O(P0)
1452 IF V(600000 + X5) = K3 THEN 1456
1453 LET V(600000 + X5) = K3
1454 LET V(400000 + X5) = 0
1455 LET V(500000 + X5) = 0
1456 LET V(300000 + 100000 * R0 + X5) = V(300000 + 100000 * R0 + X5) + 1
1458 GOTO 1385
1459 REM 4 F0 counts the reads of X7 (5: its writes)
1460 IF R0 <> 1 THEN 1385
1462 IF O(P0) = X7 THEN 1478
1464 GOTO 1385
1470 IF R0 <> 2 THEN 1385
1472 IF O(P0) <> X7 THEN 1385
1478 LET F0 = F0 + 1
1480 GOTO 1385
1489 REM 6 RD: rename the reads: H0 reads H4, else a register with W(r,0) = K4 reads R(r,9)
1490 IF R0 <> 1 THEN 1385
1492 LET X5 = O(P0)
1494 IF X5 <> H0 THEN 1497
1495 LET O(P0) = H4
1496 GOTO 1385
1497 IF W(X5, 0) <> K4 THEN 1385
1498 LET O(P0) = R(X5, 9)
1499 GOTO 1385
1509 REM 7 WR: rename the writes of the registers with R(r,0) = K3: a fresh one per K4 (W(r,1) = K5)
1510 IF R0 <> 2 THEN 1385
1512 LET X5 = O(P0)
1513 IF R(X5, 0) <> K3 THEN 1385
1514 GOSUB 1700
1516 LET O(P0) = R(X5, 9)
1518 GOTO 1385
1519 REM 8 the reads of a register R(r,0) = K3 not yet written in this record order (W(r,1) <> K5)
1520 IF R0 <> 1 THEN 1385
1522 LET X5 = O(P0)
1523 IF R(X5, 0) <> K3 THEN 1385
1524 IF W(X5, 1) = K5 THEN 1385
1526 LET W(X5, 1) = K6
1528 GOTO 1385
1529 REM 9 the writes: W(r,1) = K5 (after mode 8, so K6 marks a read before the first write)
1530 IF R0 <> 2 THEN 1385
1532 IF W(O(P0), 1) = K6 THEN 1385
1534 LET W(O(P0), 1) = K5
1536 GOTO 1385
1539 REM 10 AFT: the registers read get W(100000+r,2) = L3 (read after L)
1540 IF R0 <> 1 THEN 1385
1542 LET W(100000 + O(P0), 2) = L3
1544 GOTO 1385
1549 REM 11 LOC: a register referenced gets W(100000+r,3) = K3 (outside L: not local)
1550 LET W(100000 + O(P0), 3) = K3
1552 GOTO 1385
1559 REM 12 CPY: a register with W(100000+r,4) = L2 (local) gets a fresh one per copy K5 (1700)
1560 LET X5 = O(P0)
1562 IF W(100000 + X5, 4) <> L2 THEN 1385
1564 GOSUB 1700
1566 LET O(P0) = R(X5, 9)
1568 GOTO 1385
1569 REM 13 a register written here (L), not a parameter, not referenced outside L (W(100000+r,3) <> K3):
1570 REM W(100000+r,4) = L2 (DESIGN 2.12.6 "Registers": locals are written in L and read only in L)
1571 IF R0 <> 2 THEN 1385
1572 IF O(P0) <= M(5) THEN 1385
1573 IF W(100000 + O(P0), 3) = K3 THEN 1385
1574 LET W(100000 + O(P0), 4) = L2
1575 GOTO 1385
1579 REM 14 the first write of a register of the body (R(r,0) = K3) carried (W(r,1) = K6) or read after L
1580 IF R0 <> 2 THEN 1385
1582 LET X5 = O(P0)
1584 IF R(X5, 0) <> K3 THEN 1385
1586 IF W(X5, 2) = K3 THEN 1385
1588 LET W(X5, 2) = K3
1590 IF W(X5, 1) = K6 THEN 1594
1592 IF W(100000 + X5, 2) <> L3 THEN 1385
1594 LET D3 = D3 + 1
1596 LET S(830000 + D3) = X5
1598 GOTO 1385
1600 LET U(J9) = O(P0)
1605 GOTO 1385
1609 REM 15 (T12) a read of an sa register (R(r,5) = s > 0) other than as the base of ldi ldf sti stf: S(830000+s) = 0
1610 IF R0 <> 1 THEN 1385
1612 LET X5 = R(O(P0), 5)
1614 IF X5 <= 0 THEN 1385
1616 IF P0 <> I(N0, 2) + 1 THEN 1626
1618 IF FNB(FNC(N0), 1) = 0 THEN 1626
1620 IF FNC(N0) < 47 THEN 1626
1622 IF FNC(N0) <= 53 THEN 1385
1626 LET S(830000 + X5) = 0
1628 GOTO 1385
1639 REM 18 rename every write (1700) and note it in the merge list S(660000+4k+0..2) (k = W(r,2) under
1641 REM W(r,3) = M2; M1 entries): the register, its name in part 1 (+1) and part 2 (+2): M3 the part
1642 IF R0 <> 2 THEN 1385
1643 LET X5 = O(P0)
1644 GOSUB 1700
1645 LET O(P0) = R(X5, 9)
1646 IF W(X5, 1) <> M0 THEN 1648
1647 LET W(R(X5, 9), 1) = M0
1648 IF W(X5, 3) = M2 THEN 1656
1649 IF M1 >= 9999 THEN 1660
1650 LET M1 = M1 + 1
1651 LET S(660000 + 4 * M1) = X5
1652 LET S(660001 + 4 * M1) = 0
1653 LET S(660002 + 4 * M1) = 0
1654 LET W(X5, 2) = M1
1655 LET W(X5, 3) = M2
1656 LET S(660000 + 4 * W(X5, 2) + M3) = R(X5, 9)
1658 GOTO 1385
1660 LET O0 = 1
1662 GOTO 1385
1669 REM 16 an i register written: a mask candidate (W(r,1) = M0)
1670 IF R0 <> 2 THEN 1385
1672 IF R(O(P0), 1) <> 1 THEN 1385
1674 LET W(O(P0), 1) = M0
1676 GOTO 1385
1679 REM 17 a mask candidate referenced other than as fcmp ldb iand ior bnot mov, fsel c, stb s, if c
1680 LET X5 = O(P0)
1681 IF W(X5, 1) <> M0 THEN 1385
1682 LET X3 = FNC(N0)
1683 IF X3 = 17 THEN 1385
1684 IF X3 = 18 THEN 1385
1685 IF X3 = 23 THEN 1385
1686 IF X3 = 5 THEN 1385
1687 LET X4 = 10 * X3 + P0 - I(N0, 2)
1688 IF X4 = 421 THEN 1385
1689 IF X4 = 480 THEN 1385
1690 IF X4 = 261 THEN 1385
1691 IF X4 = 520 THEN 1385
1692 IF X4 = 601 THEN 1385
1693 IF X4 = 611 THEN 1385
1694 LET W(X5, 1) = 0
1695 LET Z9 = 1
1696 GOTO 1385
1697 REM NAME: register X5 gets a fresh name R(r,9) of its class unless it has one for K5 (V(900000+r));
1698 REM W(r,0) = K4 marks the map valid; NEWR clobbers Z4 Z5 Z9
1700 IF W(X5, 0) <> K4 THEN 1710
1705 IF V(900000 + X5) = K5 THEN 1399
1710 LET Z4 = R(X5, 1)
1715 GOSUB 2300
1720 LET R(X5, 9) = Z5
1725 LET W(X5, 0) = K4
1730 LET V(900000 + X5) = K5
1735 RETURN
1739 REM 19 (condition 3) a read: p any; f written earlier (W(r,0) = M4) or not written in the body
1741 REM (R(r,0) <> L4); i a mask written earlier, any in a sum8 record, J as a load or store idx; else F0 = 0
1742 IF R0 <> 1 THEN 1385
1743 LET X5 = O(P0)
1744 LET X4 = R(X5, 1)
1746 IF X4 = 3 THEN 1385
1748 IF W(X5, 0) = M4 THEN 1758
1750 IF X4 = 1 THEN 1760
1754 IF R(X5, 0) <> L4 THEN 1385
1756 GOTO 1770
1758 IF X4 = 2 THEN 1385
1759 IF W(X5, 1) = M0 THEN 1385
1760 IF FNB(I(N0, 0), 4) = 1 THEN 1385
1762 IF X5 <> P8 THEN 1770
1764 IF P0 - I(N0, 2) <> 2 THEN 1770
1766 IF Q(I(N0, 1), 7) >= 3 THEN 1385
1770 LET F0 = 0
1772 GOTO 1385
1779 REM 20 the registers written get W(r,0) = M4
1780 IF R0 <> 2 THEN 1385
1782 LET W(O(P0), 0) = M4
1784 GOTO 1385
1795 REM VISR / VISW: mode V0 over the records J3 .. J4
1800 FOR N0 = J3 TO J4
1805 GOSUB 1315
1810 NEXT N0
1815 RETURN
1819 REM 21 (the splats) the first read of an f register not written in the body: Xsplat Sr r (W(r,2), W(r,3) = M5)
1820 IF R0 <> 1 THEN 1385
1822 LET X5 = O(P0)
1824 IF R(X5, 1) <> 2 THEN 1385
1826 IF R(X5, 0) = L4 THEN 1385
1828 IF W(X5, 3) = M5 THEN 1385
1830 LET H3 = 97 + V7
1831 LET Z4 = 4 + V7 / 17
1832 LET O4 = X5
1833 GOSUB 2700
1834 LET W(X5, 2) = Z5
1835 LET W(X5, 3) = M5
1836 GOTO 1385
1839 REM 22 (the vector body) each register operand becomes MAPOP of it
1840 LET X7 = O(P0)
1842 GOSUB 42500
1844 LET O(P0) = X5
1846 GOTO 1385
1895 REM ---- FACTS: R(r,3..8) of every register (header comment of part 0), DESIGN 5.8 Terms and the
1897 REM constants of T13 (2.12.6: an li, or mov iadd isub imul of constants, folded in -2^52..2^52)
1900 FOR X5 = 1 TO M7
1905 LET R(X5, 3) = 0
1910 LET R(X5, 4) = -1
1915 LET R(X5, 5) = 0
1920 LET R(X5, 6) = N8
1925 LET R(X5, 7) = N8
1930 LET R(X5, 8) = 0
1935 IF X5 > M(5) THEN 1950
1940 LET R(X5, 3) = 1
1945 LET R(X5, 4) = 0
1946 LET R(X5, 5) = -1
1950 NEXT X5
1955 LET V0 = 1
1960 LET J3 = 1
1965 LET J4 = A0
1970 GOSUB 1800
1975 LET Z9 = 0
1980 FOR X5 = 1 TO M7
1985 IF R(X5, 6) <> N8 THEN 2065
1990 IF R(X5, 3) <> 1 THEN 2065
1995 LET X4 = R(X5, 4)
2000 IF X4 <= 0 THEN 2065
2005 LET X3 = FNC(X4)
2010 LET V2 = N8
2015 IF X3 <> 1 THEN 2030
2020 LET C2 = FNO(X4, 1)
2022 GOSUB 2200
2024 LET R(X5, 7) = V2
2025 IF V2 = N8 THEN 2065
2026 GOTO 2060
2030 IF X3 < 5 THEN 2065
2035 IF X3 > 8 THEN 2065
2040 LET V3 = R(FNO(X4, 1), 6)
2042 IF V3 = N8 THEN 2065
2044 LET V2 = V3
2046 IF X3 = 5 THEN 2060
2048 LET V4 = R(FNO(X4, 2), 6)
2050 IF V4 = N8 THEN 2065
2052 LET V2 = V3 + V4
2053 IF X3 = 6 THEN 2058
2054 LET V2 = V3 - V4
2055 IF X3 = 7 THEN 2058
2056 LET V2 = V3 * V4
2058 IF ABS(V2) > U9 THEN 2065
2060 LET R(X5, 6) = V2
2062 LET Z9 = 1
2065 NEXT X5
2070 IF Z9 = 1 THEN 1975
2075 GOTO 2100
2095 REM ESC (P3): S(850000+r) = 1 for a parameter r, S(860000+s) = 1 for a slot s one of whose sa
2097 REM registers is a stored value or an operand of mov padd psel; S(851000+r) the largest off +
2098 REM size of the accesses without idx through parameter r (T8 (c), 5.8)
2100 FOR X5 = 1 TO M(5)
2102 LET S(850000 + X5) = 0
2104 LET S(851000 + X5) = 0
2106 NEXT X5
2108 FOR X5 = 1 TO S6
2110 LET S(860000 + X5) = 0
2112 NEXT X5
2114 FOR N0 = 1 TO A0
2116 LET X3 = FNC(N0)
2118 IF X3 = 5 THEN 2150
2120 IF X3 = 46 THEN 2150
2122 IF X3 = 27 THEN 2150
2124 IF X3 < 47 THEN 2160
2126 IF X3 > 54 THEN 2160
2128 LET X5 = FNO(N0, 1)
2130 IF X5 > M(5) THEN 2142
2132 IF FNO(N0, 2) <> 0 THEN 2142
2134 LET G9 = FNO(N0, 4)
2136 GOSUB 2240
2137 IF V5 = N8 THEN 2142
2138 LET X4 = 7 * SGN(ABS(X3 - 48) * ABS(X3 - 52)) + 1
2140 IF V5 + X4 <= S(851000 + X5) THEN 2142
2141 LET S(851000 + X5) = V5 + X4
2142 IF X3 < 51 THEN 2160
2144 LET X5 = FNO(N0, 0)
2146 GOSUB 2170
2148 GOTO 2160
2150 FOR X4 = 1 TO I(N0, 3) - 1
2152 LET X5 = FNO(N0, X4)
2154 GOSUB 2170
2156 NEXT X4
2160 NEXT N0
2165 RETURN
2170 IF R(X5, 1) <> 3 THEN 2190
2172 IF R(X5, 5) <= 0 THEN 2176
2174 LET S(860000 + R(X5, 5)) = 1
2176 IF X5 > M(5) THEN 2190
2178 LET S(850000 + X5) = 1
2190 RETURN
2195 REM IMMV: V2 = the i64 immediate of row C2 of C when it lies in -2^52 .. 2^52, else N8
2200 LET V2 = N8
2202 IF C(C2, 1) <= 16 THEN 2212
2204 IF C(C2, 1) < 65520 THEN 1399
2206 LET V2 = (((C(C2, 1) - 65536) * 65536 + C(C2, 2)) * 65536 + C(C2, 3)) * 65536 + C(C2, 4)
2208 IF V2 >= -U9 THEN 1399
2210 GOTO 2218
2212 LET V2 = ((C(C2, 1) * 65536 + C(C2, 2)) * 65536 + C(C2, 3)) * 65536 + C(C2, 4)
2214 IF V2 <= U9 THEN 1399
2218 LET V2 = N8
2220 RETURN
2235 REM OFFV: V5 = the value of the off field of row G9 of G when it lies in -2^52 .. 2^52, else N8
2240 LET V5 = N8
2242 IF G(G9, 0) <= 16 THEN 2252
2244 IF G(G9, 0) < 65520 THEN 1399
2246 LET V5 = (((G(G9, 0) - 65536) * 65536 + G(G9, 1)) * 65536 + G(G9, 2)) * 65536 + G(G9, 3)
2248 IF V5 >= -U9 THEN 1399
2250 GOTO 2258
2252 LET V5 = ((G(G9, 0) * 65536 + G(G9, 1)) * 65536 + G(G9, 2)) * 65536 + G(G9, 3)
2254 IF V5 <= U9 THEN 1399
2258 LET V5 = N8
2260 RETURN
2295 REM NEWR: Z5 = a new register of class Z4 (number M7 + 1, above every number in use); at the
2297 REM limit O0 = 1 and Z5 = 0 (the caller then drops what it was building)
2300 LET Z5 = 0
2301 IF M7 >= R9 THEN 2590
2302 LET M7 = M7 + 1
2303 LET Z5 = M7
2304 FOR Z9 = 0 TO 9
2306 LET R(Z5, Z9) = 0
2308 NEXT Z9
2310 LET R(Z5, 1) = Z4
2312 LET R(Z5, 6) = N8
2314 LET R(Z5, 7) = N8
2316 RETURN
2345 REM NEWC: V4 = a new row of C holding the integer V3 (|V3| <= 2^52); NEWG: a new row of G
2350 LET V4 = 0
2351 IF A2 >= M9 THEN 2590
2352 LET A2 = A2 + 1
2353 LET V4 = A2
2354 LET Z0 = 1
2356 GOTO 2370
2360 LET V4 = 0
2361 IF A6 >= 199999 THEN 2590
2362 LET A6 = A6 + 1
2363 LET V4 = A6
2364 LET Z0 = 0
2370 LET Z1 = V3
2372 IF V3 >= 0 THEN 2380
2374 LET Z1 = -V3 - 1
2380 FOR Z9 = 4 TO 1 STEP -1
2382 LET X8 = Z1 - 65536 * INT(Z1 / 65536)
2383 IF V3 >= 0 THEN 2386
2384 LET X8 = 65535 - X8
2386 LET Z1 = INT(Z1 / 65536)
2388 IF Z0 = 1 THEN 2394
2390 LET G(V4, Z9 - 1) = X8
2392 GOTO 2396
2394 LET C(V4, Z9) = X8
2396 NEXT Z9
2398 RETURN
2495 REM ---- EMIT: a new list record of code H3 with the operands O3 .. O8 (Q's field count of them,
2497 REM no repeated field) at row T3: H7 its row; O0 = 1 when the list leaves I or O (nothing then)
2500 LET H6 = Q(S(999800 + H3), 4)
2505 LET S(999001) = O3
2510 LET S(999002) = O4
2515 LET S(999003) = O5
2520 LET S(999004) = O6
2525 LET S(999005) = O7
2530 LET S(999006) = O8
2535 IF T3 >= 199999 THEN 2590
2540 IF T4 + H6 >= 799999 THEN 2590
2545 LET H7 = T3
2550 LET I(T3, 0) = 0
2555 LET I(T3, 1) = S(999800 + H3)
2560 LET I(T3, 2) = T4
2565 LET I(T3, 3) = H6
2570 LET I(T3, 4) = 0
2575 FOR Z9 = 1 TO H6
2577 LET O(T4 + Z9 - 1) = S(999000 + Z9)
2579 NEXT Z9
2581 LET T3 = T3 + 1
2583 LET T4 = T4 + H6
2585 RETURN
2590 LET O0 = 1
2592 RETURN
2595 REM COPY: a new list record copying record X8 (flags, site, operands): H7 its row
2600 LET H6 = I(X8, 3)
2620 IF T3 >= 199999 THEN 2590
2625 IF T4 + H6 >= 799999 THEN 2590
2630 LET H7 = T3
2635 FOR Z9 = 0 TO 4
2640 LET I(T3, Z9) = I(X8, Z9)
2645 NEXT Z9
2650 LET I(T3, 2) = T4
2652 FOR Z9 = 1 TO H6
2654 LET O(T4 + Z9 - 1) = O(I(X8, 2) + Z9 - 1)
2656 NEXT Z9
2658 GOTO 2581
2695 REM E1 E2 E3: a new register Z5 of class Z4 written by code H3 with the operands O4 (E2: O4 O5;
2697 REM E3: O4 O5 O6) after it; ELI: Z5 = a new i register loaded with V3 (an li); EMEM: code H3,
2698 REM register O3, base O4, idx O5, scale O6 and the off value V3 (a new row of G)
2700 GOSUB 2300
2705 LET O3 = Z5
2710 GOSUB 2500
2715 RETURN
2720 LET Z4 = 1
2725 GOSUB 2350
2730 LET O4 = V4
2735 LET H3 = 1
2740 GOTO 2700
2750 GOSUB 2360
2755 LET O7 = V4
2760 GOTO 2500
2795 REM ---- SPLICE: the function's records J5 .. J6 replaced by the list records J7 .. J8 (built in W
2797 REM and V, copied back), the blocks renumbered (2900) and K rebuilt (69455)
2800 LET Z1 = 0
2805 LET Z2 = 0
2810 FOR Z3 = 1 TO J5 - 1
2815 GOSUB 2860
2820 NEXT Z3
2825 FOR Z3 = J7 TO J8
2830 GOSUB 2860
2835 NEXT Z3
2840 FOR Z3 = J6 + 1 TO A0
2845 GOSUB 2860
2850 NEXT Z3
2852 LET A0 = Z1
2854 LET A1 = Z2
2856 GOTO 2880
2860 LET Z1 = Z1 + 1
2862 FOR Z9 = 0 TO 4
2864 LET W(Z1, Z9) = I(Z3, Z9)
2866 NEXT Z9
2868 LET W(Z1, 2) = Z2 + 1
2870 FOR Z9 = 0 TO I(Z3, 3) - 1
2872 LET V(Z2 + 1 + Z9) = O(I(Z3, 2) + Z9)
2874 NEXT Z9
2876 LET Z2 = Z2 + I(Z3, 3)
2878 RETURN
2880 FOR Z3 = 1 TO A0
2882 FOR Z9 = 0 TO 4
2884 LET I(Z3, Z9) = W(Z3, Z9)
2886 NEXT Z9
2888 NEXT Z3
2890 FOR Z3 = 1 TO A1
2892 LET O(Z3) = V(Z3)
2894 NEXT Z3
2895 REM BLKREN: blocks numbered 1, 2, ... by opening record (every block has a number of its own,
2897 REM at most 19999), closing, else, exit and next records by the map S(800000+old)
2900 LET Z1 = 0
2905 FOR Z3 = 1 TO A0
2910 LET X3 = FNC(Z3)
2915 IF X3 < 56 THEN 2950
2920 IF X3 > 65 THEN 2950
2925 LET Z2 = I(Z3, 2)
2930 IF X3 = 57 THEN 2945
2931 IF X3 = 59 THEN 2945
2932 IF X3 > 61 THEN 2945
2935 LET Z1 = Z1 + 1
2940 LET S(800000 + O(Z2)) = Z1
2945 LET O(Z2) = S(800000 + O(Z2))
2950 NEXT Z3
2955 LET B2 = Z1
2965 GOTO 69455
2995 REM ---- LSCAN: the block partners of the list (or function) records J3 .. J4: S(n) of an opening
2997 REM or else record its closing record, of a closing record its opening one; S(200000+o) the else
2998 REM of the block opened at o (0 none); S(820000..) the stack (Z1 deep)
3000 LET Z1 = 0
3005 FOR Z3 = J3 TO J4
3010 LET X3 = FNC(Z3)
3015 IF X3 < 56 THEN 3060
3020 IF X3 > 63 THEN 3060
3025 IF X3 = 57 THEN 3045
3026 IF X3 = 59 THEN 3045
3027 IF X3 = 62 THEN 3040
3028 IF X3 = 63 THEN 3045
3030 LET Z1 = Z1 + 1
3032 LET S(820000 + Z1) = Z3
3034 LET S(200000 + Z3) = 0
3036 GOTO 3060
3040 LET S(200000 + S(820000 + Z1)) = Z3
3042 GOTO 3060
3045 LET Z2 = S(820000 + Z1)
3047 LET Z1 = Z1 - 1
3050 LET S(Z3) = Z2
3052 LET S(Z2) = Z3
3054 IF S(200000 + Z2) = 0 THEN 3060
3056 LET S(S(200000 + Z2)) = Z3
3060 NEXT Z3
3065 RETURN
3095 REM ---- CAP: F0 = 1 when the function, with U0 more records, U1 more operands, U3 more blocks,
3097 REM fits the LIR capacity limits (Decision 72), and so do M7, A2, A6 (registers, immediates, offs)
3100 LET F0 = 0
3105 IF A0 + U0 > I9 THEN 1399
3110 IF A1 + U1 > O9 THEN 1399
3115 IF B2 + U3 > B9 THEN 1399
3120 IF M7 > R9 THEN 1399
3125 IF A2 > M9 THEN 1399
3130 IF A6 >= 199999 THEN 1399
3135 LET F0 = 1
3140 RETURN
3195 REM ---- AFTER: W(100000+r,2) = L3 for the registers read after the records J5 .. J6 can run:
3197 REM read at a record after J6, or before J5 inside a loop that encloses J5 (implementer reading)
3200 LET K2 = K2 - 1
3205 LET L3 = K2
3210 LET V0 = 10
3215 LET J3 = J6 + 1
3220 LET J4 = A0
3225 GOSUB 1800
3230 LET J3 = J5
3235 FOR Z3 = 1 TO J5 - 1
3240 LET X3 = FNC(Z3)
3245 IF X3 = 56 THEN 3255
3250 IF X3 <> 58 THEN 3265
3255 IF K(O(I(Z3, 2)), 4) < J6 THEN 3265
3260 LET J3 = Z3
3262 GOTO 3270
3265 NEXT Z3
3270 LET J4 = J5 - 1
3275 GOTO 1800
3295 REM ---- LOCALS (L-bl): W(100000+r,4) = L2 for the registers, not parameters, written in the records
3297 REM J5 .. J6 of the function and referenced nowhere else (DESIGN 2.12.6 "Registers"; fresh per copy)
3300 LET K2 = K2 - 1
3305 LET K3 = K2
3310 LET V0 = 11
3315 LET J3 = 1
3320 LET J4 = J5 - 1
3325 GOSUB 1800
3330 LET J3 = J6 + 1
3335 LET J4 = A0
3340 GOSUB 1800
3345 LET K2 = K2 - 1
3350 LET L2 = K2
3355 LET V0 = 13
3360 FOR N0 = J5 TO J6
3365 GOSUB 1315
3370 NEXT N0
3375 RETURN
3395 REM ---- COPYR: list copies of the records U2 .. U4 that are not deleted (I(n,1) = 0)
3400 FOR X8 = U2 TO U4
3405 IF I(X8, 1) = 0 THEN 3415
3410 GOSUB 2600
3415 NEXT X8
3420 RETURN
3445 REM ---- DEST: X7 = the register a pure instruction N0 writes (its first written field), 0 none
3450 LET X7 = 0
3452 LET W9 = I(N0, 1)
3454 FOR J9 = 1 TO Q(W9, 4)
3456 IF F(Q(W9, 3) + J9 - 1, 0) = 2 THEN 3462
3458 NEXT J9
3460 RETURN
3462 LET X7 = O(I(N0, 2) + J9 - 1)
3464 RETURN
3895 REM ---- MARKL: R(r,0) = L4 (a new stamp) for the registers the list records L8 .. L9 write
3900 LET K2 = K2 - 1
3905 LET K3 = K2
3910 LET L4 = K2
3915 LET V0 = 2
3920 LET J3 = L8
3925 LET J4 = L9
3930 GOTO 1800
3945 REM ---- OPENS: F0 = the opening records (loop do if ifz) among the records J3 .. J4
3950 LET F0 = 0
3955 FOR Z3 = J3 TO J4
3960 LET X3 = FNC(Z3)
3965 IF X3 < 56 THEN 3985
3970 IF X3 > 61 THEN 3985
3975 IF X3 = 57 THEN 3985
3977 IF X3 = 59 THEN 3985
3980 LET F0 = F0 + 1
3985 NEXT Z3
3990 RETURN
