1000 REM ====================================================================================
1005 REM sealopt part 1 (lines 1000-9999): set-up, the operand visitor, the facts of DESIGN 5.8's
1010 REM Terms that T5-T9 need (definitions, constants, array registers, private bases, object
1015 REM pointers, may-change, T3's equality), the block structure, and the rebuild of a function
1020 REM from a snapshot with records put before and after others (insertions, moves, copies).
1025 REM ====================================================================================
1030 REM SETUP (once, after lirrw's header entry): the rows of the opcodes this pass writes besides
1035 REM lirrw's E2 li E4 mov E5 iadd E6 isub E7 imul E9 iand G4 icmp: R1 padd R3 ldi R4 ldf R5 ldp
1040 REM R6 sti R7 stf I4 if I5 else I6 endif
1045 LET R1 = 0
1050 LET R3 = 0
1052 LET R4 = 0
1054 LET R5 = 0
1056 LET R6 = 0
1058 LET R7 = 0
1060 LET I4 = 0
1062 LET I5 = 0
1064 LET I6 = 0
1066 FOR N3 = 1 TO A8
1067 LET X4 = A(N3)
1068 LET X3 = Q(X4, 6)
1069 IF X3 <> 46 THEN 1071
1070 LET R1 = X4
1071 IF X3 <> 47 THEN 1073
1072 LET R3 = X4
1073 IF X3 <> 49 THEN 1075
1074 LET R4 = X4
1075 IF X3 <> 50 THEN 1077
1076 LET R5 = X4
1077 IF X3 <> 51 THEN 1079
1078 LET R6 = X4
1079 IF X3 <> 53 THEN 1081
1080 LET R7 = X4
1081 IF X3 <> 60 THEN 1083
1082 LET I4 = X4
1083 IF X3 <> 62 THEN 1085
1084 LET I5 = X4
1085 IF X3 <> 63 THEN 1087
1086 LET I6 = X4
1087 NEXT N3
1089 IF R1 * R3 * R4 * R5 * R6 * R7 * I4 * I5 * I6 <> 0 THEN 1095
1090 CALL "dg_bug": P$, "an opcode that sealopt writes is missing from passes.txt"
1095 RETURN
1100 REM ---- VIS: visit the register operands of instruction N0 in field order; for each, O(P0) is
1102 REM the register and R0 its role (1 read, 2 written); mode V0 selects the callback (1210).
1104 REM Locals P0 W9 J9 B3 J0 J8 R0 and U(field) (the u fields, for the repeat counts).
1105 LET P0 = I(N0, 2)
1110 LET W9 = I(N0, 1)
1115 IF W9 = 0 THEN 1095
1120 FOR J9 = 1 TO Q(W9, 4)
1125 LET B3 = Q(W9, 3) + J9 - 1
1130 LET R0 = F(B3, 0)
1135 IF R0 = 0 THEN 1195
1140 LET J0 = 1
1145 IF F(B3, 3) = 0 THEN 1155
1150 LET J0 = U(F(B3, 3))
1155 FOR J8 = 1 TO J0
1160 IF R0 > 2 THEN 1175
1165 IF O(P0) = 0 THEN 1175
1170 GOSUB 1210
1175 IF R0 <> 5 THEN 1182
1180 LET U(J9) = O(P0)
1182 LET P0 = P0 + 1
1185 IF R0 <> 7 THEN 1192
1190 LET P0 = P0 + 1
1192 NEXT J8
1195 NEXT J9
1200 RETURN
1205 REM CBD: the callback of mode V0 (it returns to VIS)
1210 ON V0 GOTO 1220, 1235, 1245, 1250, 1260, 1290, 1300, 1310, 1320, 1330, 1340, 1350, 1360, 1380, 1400, 1450, 1475, 1495, 1912
1215 REM 1 DEFS: count the definitions of a written register, remember the last
1220 IF R0 <> 2 THEN 1095
1225 LET R(O(P0), 3) = R(O(P0), 3) + 1
1230 LET R(O(P0), 4) = N0
1232 RETURN
1234 REM 2 mark every register R(r,8) = 1; 3 unmark it; 4 unmark the registers read
1235 LET R(O(P0), 8) = 1
1240 RETURN
1245 LET R(O(P0), 8) = 0
1247 RETURN
1250 IF R0 <> 1 THEN 1095
1255 LET R(O(P0), 8) = 0
1257 RETURN
1258 REM 5 rename the marked (local) registers: R(r,9) the fresh number, given at the first reference
1260 LET X5 = O(P0)
1262 IF R(X5, 8) <> 1 THEN 1095
1265 IF R(X5, 9) > 0 THEN 1280
1270 LET Z4 = R(X5, 1)
1272 GOSUB 3360
1275 LET R(X5, 9) = Z5
1280 LET O(P0) = R(X5, 9)
1285 RETURN
1288 REM 6 the reads of D3 read S3
1290 IF R0 <> 1 THEN 1095
1292 IF O(P0) <> D3 THEN 1095
1294 LET O(P0) = S3
1296 RETURN
1298 REM 7 F0 counts the writes of X7; 8 its reads
1300 IF R0 <> 2 THEN 1095
1302 IF O(P0) <> X7 THEN 1095
1304 LET F0 = F0 + 1
1306 RETURN
1310 IF R0 <> 1 THEN 1095
1312 IF O(P0) <> X7 THEN 1095
1314 LET F0 = F0 + 1
1316 RETURN
1318 REM 9 R(r,9) counts the writes of r
1320 IF R0 <> 2 THEN 1095
1322 LET R(O(P0), 9) = R(O(P0), 9) + 1
1324 RETURN
1328 REM 10 the writes of D3 write S3
1330 IF R0 <> 2 THEN 1095
1332 IF O(P0) <> D3 THEN 1095
1334 LET O(P0) = S3
1336 RETURN
1338 REM 11 the reads of r read R(r,Q7) when that is not 0; 12 the writes alike
1340 IF R0 <> 1 THEN 1095
1342 IF R(O(P0), Q7) = 0 THEN 1095
1344 LET O(P0) = R(O(P0), Q7)
1346 RETURN
1350 IF R0 <> 2 THEN 1095
1352 IF R(O(P0), Q7) = 0 THEN 1095
1354 LET O(P0) = R(O(P0), Q7)
1356 RETURN
1358 REM 13 (T6) a read of a copy-set member (R(r,0) = 1) other than as a base, outside the cow
1359 REM (W1 = 1: N0 is part of one of the key's cows): F0 = 0
1360 IF R0 <> 1 THEN 1095
1362 IF R(O(P0), 0) <> 1 THEN 1095
1364 IF W1 = 1 THEN 1095
1366 IF Q(W9, 7) < 3 THEN 1374
1368 IF Q(W9, 7) > 4 THEN 1374
1370 IF P0 = I(N0, 2) + 1 THEN 1095
1374 LET F0 = 0
1376 RETURN
1378 REM 14 (private bases) a read of a candidate other than as the base of an access without idx
1380 IF R0 <> 1 THEN 1095
1382 IF R(O(P0), 7) <> 1 THEN 1095
1384 IF Q(W9, 7) < 3 THEN 1394
1386 IF Q(W9, 7) > 4 THEN 1394
1388 IF P0 <> I(N0, 2) + 1 THEN 1394
1390 IF O(I(N0, 2) + 2) = 0 THEN 1095
1394 LET R(O(P0), 7) = 0
1396 RETURN
1398 REM 15 (array registers) a definition of a candidate that is not one of 5.8's forms removes it
1400 IF R0 <> 2 THEN 1095
1402 LET X5 = O(P0)
1404 IF R(X5, 1) <> 3 THEN 1095
1406 IF R(X5, 5) <> 1 THEN 1095
1408 LET X8 = Q(W9, 6)
1410 IF X8 = 5 THEN 1432
1412 IF X8 <> 68 THEN 1440
1414 LET X8 = O(I(N0, 2))
1416 IF X8 = Y3 THEN 1095
1418 IF X8 = Y4 THEN 1095
1420 IF X8 = Y5 THEN 1095
1422 IF X8 = Y6 THEN 1095
1424 IF X8 = Y7 THEN 1095
1426 IF X8 = Y8 THEN 1095
1428 IF X8 <> Y9 THEN 1440
1430 LET X8 = O(I(N0, 2) + 4)
1431 GOTO 1434
1432 LET X8 = O(I(N0, 2) + 1)
1434 IF R(X8, 1) <> 3 THEN 1440
1436 IF R(X8, 5) = 1 THEN 1095
1440 LET R(X5, 5) = 0
1442 LET Z9 = 1
1444 RETURN
1448 REM 16 (object pointers) a definition of a p register that is not of 5.8's forms: R(r,8) = 1
1449 REM (an ldp of SEA_ARR_DATA, a data pointer, is not one of them, L-bv)
1450 IF R0 <> 2 THEN 1095
1452 LET X5 = O(P0)
1454 IF R(X5, 1) <> 3 THEN 1095
1456 LET X8 = Q(W9, 6)
1458 IF X8 = 67 THEN 1095
1460 IF X8 = 68 THEN 1095
1462 IF X8 = 50 THEN 1501
1464 IF X8 = 4 THEN 1095
1466 IF X8 <> 5 THEN 1470
1468 IF R(O(I(N0, 2) + 1), 0) = 1 THEN 1095
1470 LET R(X5, 8) = 1
1472 RETURN
1474 REM 17 (private bases) the slot of the sa definitions of a p register, -1 for any other one
1475 IF R0 <> 2 THEN 1095
1477 LET X5 = O(P0)
1479 IF R(X5, 1) <> 3 THEN 1095
1481 IF Q(W9, 6) <> 4 THEN 1491
1483 LET X8 = O(I(N0, 2) + 1)
1485 IF R(X5, 7) = 0 THEN 1489
1487 IF R(X5, 7) = X8 THEN 1095
1488 GOTO 1491
1489 LET R(X5, 7) = X8
1490 RETURN
1491 LET R(X5, 7) = -1
1493 RETURN
1494 REM 18 X7 = the register written (the last one); F0 = 0 when a register read has R(r,9) > 0
1495 IF R0 <> 2 THEN 1498
1496 LET X7 = O(P0)
1497 RETURN
1498 IF R(O(P0), 9) = 0 THEN 1095
1499 LET F0 = 0
1500 RETURN
1501 LET G9 = O(I(N0, 2) + 4)
1502 GOSUB 3240
1503 IF V5 <> K8 THEN 1095
1504 GOTO 1470
1505 REM ---- INFO: definitions (R(r,3) count, R(r,4) the last one, 0 the func record), constants
1510 REM (R(r,6)), array registers (R(r,5) = 1) and private bases (R(r,7) = 1), DESIGN 5.8 Terms
1515 FOR R2 = 1 TO M7
1520 LET R(R2, 3) = 0
1525 LET R(R2, 4) = -1
1530 NEXT R2
1535 FOR R2 = 1 TO M(5)
1540 LET R(R2, 3) = 1
1545 LET R(R2, 4) = 0
1550 NEXT R2
1555 LET V0 = 1
1560 FOR N0 = 1 TO A0
1565 GOSUB 1105
1570 NEXT N0
1575 REM constants: the only definition is one li of a value in -2^52 .. 2^52
1580 FOR R2 = 1 TO M7
1585 LET R(R2, 6) = N8
1590 IF R(R2, 3) <> 1 THEN 1620
1595 LET X4 = R(R2, 4)
1600 IF X4 <= 0 THEN 1620
1605 IF Q(I(X4, 1), 6) <> 1 THEN 1620
1610 LET C2 = O(I(X4, 2) + 1)
1612 GOSUB 3200
1615 LET R(R2, 6) = V2
1620 NEXT R2
1625 REM array registers: the largest set closed under the allowed definitions
1630 FOR R2 = 1 TO M7
1635 LET R(R2, 5) = 0
1640 IF R(R2, 1) <> 3 THEN 1660
1645 IF R(R2, 3) < 1 THEN 1660
1650 IF R2 <= M(5) THEN 1660
1655 LET R(R2, 5) = 1
1660 NEXT R2
1665 LET Z9 = 0
1670 LET V0 = 15
1675 FOR N0 = 1 TO A0
1680 GOSUB 1105
1685 NEXT N0
1690 IF Z9 = 1 THEN 1665
1695 REM private bases: a parameter never written, or sa definitions of one slot; every read the
1700 REM base of a load or store without idx
1705 FOR R2 = 1 TO M7
1710 LET R(R2, 7) = 0
1715 NEXT R2
1720 LET V0 = 17
1725 FOR N0 = 1 TO A0
1730 GOSUB 1105
1735 NEXT N0
1740 FOR R2 = 1 TO M7
1745 LET X4 = 0
1750 IF R(R2, 1) <> 3 THEN 1775
1755 IF R2 > M(5) THEN 1770
1760 IF R(R2, 3) = 1 THEN 1773
1765 GOTO 1775
1770 IF R(R2, 7) <= 0 THEN 1775
1773 LET X4 = 1
1775 LET R(R2, 7) = X4
1780 NEXT R2
1785 LET V0 = 14
1790 FOR N0 = 1 TO A0
1795 GOSUB 1105
1800 NEXT N0
1805 RETURN
1810 REM ---- OBJPTR (T8 (a)): R(r,0) = 1 for the object pointers, the least set closed under the
1815 REM definitions param, call, rcall, ldp, sa and mov from an object pointer
1820 FOR R2 = 1 TO M7
1825 LET R(R2, 0) = 0
1830 NEXT R2
1835 FOR R2 = 1 TO M7
1840 LET R(R2, 8) = 0
1845 NEXT R2
1850 LET V0 = 16
1855 FOR N0 = 1 TO A0
1860 GOSUB 1105
1865 NEXT N0
1870 LET Z9 = 0
1875 FOR R2 = 1 TO M7
1880 IF R(R2, 1) <> 3 THEN 1900
1885 IF R(R2, 8) = 1 THEN 1900
1890 IF R(R2, 0) = 1 THEN 1900
1892 IF R(R2, 3) < 1 THEN 1900
1895 LET R(R2, 0) = 1
1897 LET Z9 = 1
1900 NEXT R2
1905 IF Z9 = 1 THEN 1835
1910 RETURN
1911 REM 19 the registers read: S(836000+1 .. H0), H0 <= 1999 (else W2 = 1, nothing written, L-bv)
1912 IF R0 <> 1 THEN 1095
1913 IF H0 >= 1999 THEN 1919
1914 LET H0 = H0 + 1
1916 LET S(836000 + H0) = O(P0)
1918 RETURN
1919 LET W2 = 1
1920 RETURN
2000 REM ---- SNAP: W(n,0..4) = I(n,0..4), V = O, no records to put anywhere yet; M0 the records,
2002 REM M1 the last W row, M2 the last operand of V, M3 the li and lf instructions (immediates)
2005 LET M3 = 0
2010 FOR N3 = 1 TO A0
2015 FOR X4 = 0 TO 4
2020 LET W(N3, X4) = I(N3, X4)
2025 NEXT X4
2030 LET S(200000 + N3) = 0
2035 LET S(400000 + N3) = 0
2040 IF Q(I(N3, 1), 6) > 2 THEN 2050
2042 IF Q(I(N3, 1), 6) < 1 THEN 2050
2045 LET M3 = M3 + 1
2050 NEXT N3
2055 FOR X4 = 1 TO A1
2060 LET V(X4) = O(X4)
2065 NEXT X4
2070 LET M0 = A0
2075 LET M1 = A0
2080 LET M2 = A1
2085 RETURN
2095 REM ---- NEWI: a new W row H7 for the instruction of row H3 with the operands O3 .. O7 (its count)
2100 LET M1 = M1 + 1
2105 LET W(M1, 0) = 0
2110 LET W(M1, 1) = H3
2115 LET W(M1, 2) = M2 + 1
2120 LET W(M1, 3) = Q(H3, 4)
2125 LET W(M1, 4) = 0
2130 LET V(M2 + 1) = O3
2135 LET V(M2 + 2) = O4
2140 LET V(M2 + 3) = O5
2145 LET V(M2 + 4) = O6
2150 LET V(M2 + 5) = O7
2155 LET M2 = M2 + Q(H3, 4)
2160 LET S(600000 + M1) = 0
2165 LET H7 = M1
2170 IF H3 <> E2 THEN 1095
2175 LET M3 = M3 + 1
2180 RETURN
2195 REM ---- CLONE: a new W row H7 copying row X8 (CLONEOP: with its own copy of the operands)
2200 LET M1 = M1 + 1
2205 FOR Z9 = 0 TO 4
2210 LET W(M1, Z9) = W(X8, Z9)
2215 NEXT Z9
2220 LET S(600000 + M1) = 0
2225 LET H7 = M1
2230 IF Q(W(X8, 1), 6) > 2 THEN 1095
2232 IF Q(W(X8, 1), 6) < 1 THEN 1095
2235 LET M3 = M3 + 1
2240 RETURN
2245 GOSUB 2200
2250 LET W(H7, 2) = M2 + 1
2255 FOR Z9 = 0 TO W(H7, 3) - 1
2260 LET V(M2 + 1 + Z9) = V(W(X8, 2) + Z9)
2265 NEXT Z9
2270 LET M2 = M2 + W(H7, 3)
2275 RETURN
2295 REM ---- APPB / APPA: W row H7 joins the records put before / after snapshot record H4
2300 LET Z0 = 200000 + H4
2305 GOTO 2320
2310 LET Z0 = 400000 + H4
2320 IF S(Z0) = 0 THEN 2340
2325 LET Z0 = 600000 + S(Z0)
2330 GOTO 2320
2340 LET S(Z0) = H7
2345 RETURN
2395 REM ---- REBUILD: the function from the snapshot: each record with what stands before and after
2397 REM it (a record whose W(n,1) is 0 is dropped); then the blocks renumbered (BLKREN)
2400 LET Z1 = 0
2405 LET Z2 = 0
2410 FOR N3 = 1 TO M0
2415 LET Z3 = S(200000 + N3)
2420 IF Z3 = 0 THEN 2440
2425 GOSUB 2480
2430 LET Z3 = S(600000 + Z3)
2435 GOTO 2420
2440 LET Z3 = N3
2445 IF W(N3, 1) = 0 THEN 2455
2450 GOSUB 2480
2455 LET Z3 = S(400000 + N3)
2460 IF Z3 = 0 THEN 2475
2465 GOSUB 2480
2470 LET Z3 = S(600000 + Z3)
2472 GOTO 2460
2475 NEXT N3
2476 LET A0 = Z1
2477 LET A1 = Z2
2478 GOTO 2500
2479 REM EMIT: W row Z3 becomes instruction Z1 (its operands from V)
2480 LET Z1 = Z1 + 1
2482 LET I(Z1, 0) = W(Z3, 0)
2484 LET I(Z1, 1) = W(Z3, 1)
2486 LET I(Z1, 3) = W(Z3, 3)
2488 LET I(Z1, 4) = W(Z3, 4)
2490 LET I(Z1, 2) = Z2 + 1
2492 FOR X4 = 0 TO W(Z3, 3) - 1
2494 LET O(Z2 + 1 + X4) = V(W(Z3, 2) + X4)
2496 NEXT X4
2498 LET Z2 = Z2 + W(Z3, 3)
2499 RETURN
2500 REM ---- BLKREN: blocks numbered 1, 2, ... by opening record; a closing record or else takes its
2502 REM block's, an exit or next the innermost open block of its old number (the copies of a block
2504 REM are never open together); then lirrw's K table (69455)
2505 LET D0 = 0
2510 LET D1 = 0
2515 FOR N3 = 1 TO A0
2520 LET X3 = Q(I(N3, 1), 6)
2525 IF X3 < 56 THEN 2600
2530 IF X3 > 65 THEN 2600
2535 LET P4 = I(N3, 2)
2540 IF X3 = 62 THEN 2580
2545 IF X3 > 63 THEN 2585
2550 IF X3 = 57 THEN 2572
2555 IF X3 = 59 THEN 2572
2560 IF X3 = 63 THEN 2572
2562 LET D1 = D1 + 1
2564 LET D0 = D0 + 1
2566 LET S(800000 + 2 * D0) = O(P4)
2568 LET S(800001 + 2 * D0) = D1
2570 LET O(P4) = D1
2571 GOTO 2600
2572 LET O(P4) = S(800001 + 2 * D0)
2574 LET D0 = D0 - 1
2576 GOTO 2600
2580 LET O(P4) = S(800001 + 2 * D0)
2582 GOTO 2600
2585 FOR X4 = D0 TO 1 STEP -1
2590 IF S(800000 + 2 * X4) = O(P4) THEN 2597
2595 NEXT X4
2596 GOTO 2600
2597 LET O(P4) = S(800001 + 2 * X4)
2600 NEXT N3
2605 LET B2 = D1
2610 GOSUB 69455
2615 RETURN
2695 REM ---- STRUCT: S(n) the part of record n (2*o, 2*o + 1 for the else part, 0 the body)
2700 LET D0 = 0
2705 LET S(800000) = 0
2710 FOR N3 = 1 TO A0
2715 LET X3 = Q(I(N3, 1), 6)
2720 IF X3 = 57 THEN 2760
2725 IF X3 = 59 THEN 2760
2730 IF X3 = 63 THEN 2760
2735 IF X3 = 62 THEN 2770
2740 LET S(N3) = S(800000 + D0)
2742 IF X3 < 56 THEN 2790
2745 IF X3 > 61 THEN 2790
2750 LET D0 = D0 + 1
2755 LET S(800000 + D0) = 2 * N3
2757 GOTO 2790
2760 LET D0 = D0 - 1
2765 LET S(N3) = S(800000 + D0)
2767 GOTO 2790
2770 LET X4 = K(O(I(N3, 2)), 2)
2775 LET S(N3) = S(X4)
2780 LET S(800000 + D0) = 2 * X4 + 1
2790 NEXT N3
2795 RETURN
2797 REM CONTAINS: F0 = 1 when part P5 contains part P6 (or is it); P6 is changed
2800 LET F0 = 1
2805 IF P6 = P5 THEN 1095
2810 LET F0 = 0
2815 IF P6 = 0 THEN 1095
2820 LET P6 = S(INT(P6 / 2))
2825 GOTO 2800
2845 REM ---- DEADBITS: flag 16 of I(n,0) for the records after an exit, next or ret up to the end of
2847 REM their part (L-bb 3), from lirrw's entry 69460 (which overwrites I(n,0))
2850 FOR N3 = 1 TO A0
2852 LET S(600000 + N3) = I(N3, 0) - 16 * FNB(I(N3, 0), 16)
2854 NEXT N3
2856 GOSUB 69460
2858 FOR N3 = 1 TO A0
2860 LET X4 = 0
2862 IF I(N3, 0) >= 0 THEN 2866
2864 LET X4 = 16
2866 LET I(N3, 0) = S(600000 + N3) + X4
2868 NEXT N3
2870 RETURN
2995 REM ---- IDS: a fresh id (I(n,0) / 4096) for every opening record; S(820000+1 .. L9) the ids of
2997 REM the loops (loop, do) in the order Q8: 1 of their opening records, 2 of their closing ones
3000 LET I7 = 0
3005 LET L9 = 0
3010 FOR N3 = 1 TO A0
3015 LET X3 = Q(I(N3, 1), 6)
3020 IF X3 < 56 THEN 3070
3025 IF X3 > 61 THEN 3070
3030 IF X3 = 57 THEN 3055
3035 IF X3 = 59 THEN 3055
3040 LET I7 = I7 + 1
3045 LET I(N3, 0) = I(N3, 0) - 4096 * INT(I(N3, 0) / 4096) + 4096 * I7
3050 IF Q8 = 2 THEN 3070
3052 IF X3 > 58 THEN 3070
3053 GOTO 3060
3055 IF Q8 = 1 THEN 3070
3057 LET X4 = INT(I(K(O(I(N3, 2)), 2), 0) / 4096)
3058 GOTO 3062
3060 LET X4 = I7
3062 LET L9 = L9 + 1
3065 LET S(820000 + L9) = X4
3070 NEXT N3
3075 RETURN
3095 REM ---- FINDID: L6 the opening record of id I8 (0: none), L8 its block, L7 its closing record
3100 LET L6 = 0
3105 FOR N3 = 1 TO A0
3110 IF INT(I(N3, 0) / 4096) = I8 THEN 3125
3115 NEXT N3
3120 RETURN
3125 LET L6 = N3
3130 LET L8 = O(I(L6, 2))
3135 LET L7 = K(L8, 4)
3140 RETURN
3145 REM NEWID: a fresh id for every opening record among the records with flag 64 (a new copy)
3150 FOR N3 = 1 TO A0
3155 IF FNB(I(N3, 0), 64) = 0 THEN 3185
3160 LET X3 = Q(I(N3, 1), 6)
3165 IF X3 < 56 THEN 3185
3170 IF X3 > 61 THEN 3185
3172 IF X3 = 57 THEN 3185
3174 IF X3 = 59 THEN 3185
3176 LET I7 = I7 + 1
3180 LET I(N3, 0) = I(N3, 0) - 4096 * INT(I(N3, 0) / 4096) + 4096 * I7
3185 NEXT N3
3190 RETURN
3195 REM ---- IMMV: V2 = the i64 immediate of row C2 of C when it lies in -2^52 .. 2^52, else N8
3200 LET V2 = N8
3202 IF C(C2, 1) <= 16 THEN 3212
3204 IF C(C2, 1) < 65520 THEN 1095
3206 LET V2 = (((C(C2, 1) - 65536) * 65536 + C(C2, 2)) * 65536 + C(C2, 3)) * 65536 + C(C2, 4)
3208 IF V2 >= -U9 THEN 1095
3210 GOTO 3218
3212 LET V2 = ((C(C2, 1) * 65536 + C(C2, 2)) * 65536 + C(C2, 3)) * 65536 + C(C2, 4)
3214 IF V2 <= U9 THEN 1095
3218 LET V2 = N8
3220 RETURN
3235 REM OFFV: V5 = the value of the off field of row G9 of G when it lies in -2^52 .. 2^52, else N8
3240 LET V5 = N8
3242 IF G(G9, 0) <= 16 THEN 3252
3244 IF G(G9, 0) < 65520 THEN 1095
3246 LET V5 = (((G(G9, 0) - 65536) * 65536 + G(G9, 1)) * 65536 + G(G9, 2)) * 65536 + G(G9, 3)
3248 IF V5 >= -U9 THEN 1095
3250 GOTO 3258
3252 LET V5 = ((G(G9, 0) * 65536 + G(G9, 1)) * 65536 + G(G9, 2)) * 65536 + G(G9, 3)
3254 IF V5 <= U9 THEN 1095
3258 LET V5 = N8
3260 RETURN
3275 REM NEWC: V4 = a new row of C holding the integer V3 (|V3| <= 2^52); NEWG: a new row of G
3280 LET A2 = A2 + 1
3282 LET V4 = A2
3284 LET W1 = 1
3286 GOTO 3300
3290 LET A6 = A6 + 1
3292 LET V4 = A6
3294 LET W1 = 0
3300 LET Z0 = V3
3305 IF V3 >= 0 THEN 3315
3310 LET Z0 = -V3 - 1
3315 FOR Z9 = 4 TO 1 STEP -1
3320 LET X8 = Z0 - 65536 * INT(Z0 / 65536)
3325 IF V3 >= 0 THEN 3335
3330 LET X8 = 65535 - X8
3335 LET Z0 = INT(Z0 / 65536)
3337 IF W1 = 1 THEN 3342
3339 LET G(V4, Z9 - 1) = X8
3340 GOTO 3345
3342 LET C(V4, Z9) = X8
3345 NEXT Z9
3350 RETURN
3355 REM NEWR: Z5 = a new register of class Z4 (number M7 + 1, above every number in use)
3360 LET M7 = M7 + 1
3362 LET Z5 = M7
3364 FOR Z9 = 0 TO 9
3366 LET R(Z5, Z9) = 0
3368 NEXT Z9
3370 LET R(Z5, 1) = Z4
3372 LET R(Z5, 6) = N8
3374 RETURN
3395 REM ---- WRANGE: F0 = the writes of register X7 by the records J3 .. J4
3400 LET F0 = 0
3405 LET V0 = 7
3410 FOR N0 = J3 TO J4
3415 GOSUB 1105
3420 NEXT N0
3425 RETURN
3430 REM NDEFS: F0 = the definitions of register X7 in the function (a parameter's func record counts)
3435 LET J3 = 1
3440 LET J4 = A0
3445 GOSUB 3400
3450 IF X7 > M(5) THEN 1095
3455 LET F0 = F0 + 1
3460 RETURN
3465 REM WRITES / READS: F0 = the writes / reads of register X7 by record N0
3470 LET F0 = 0
3472 LET V0 = 7
3474 GOTO 1105
3476 LET F0 = 0
3478 LET V0 = 8
3480 GOTO 1105
3485 REM DEST: X7 = the register instruction N0 writes (pure instructions and loads write one)
3490 LET X7 = 0
3492 LET F0 = 1
3494 LET V0 = 18
3496 GOTO 1105
3500 REM ---- REGION: J6 .. J7 - 1 the region of record J5 (no block record, exit, next or ret)
3505 LET J6 = J5
3510 IF J6 <= 1 THEN 3530
3515 LET X3 = Q(I(J6 - 1, 1), 6)
3518 IF X3 < 56 THEN 3525
3520 IF X3 <= 66 THEN 3530
3525 LET J6 = J6 - 1
3527 GOTO 3510
3530 LET J7 = J5
3535 IF J7 > A0 THEN 3560
3540 LET X3 = Q(I(J7, 1), 6)
3545 IF X3 < 56 THEN 3555
3550 IF X3 <= 66 THEN 3560
3555 LET J7 = J7 + 1
3557 GOTO 3535
3560 RETURN
3595 REM ---- RANGECNT: T3 instructions, T4 operands, T5 opening records, T6 li and lf among the
3597 REM records J3 .. J4 that are not deleted (I(n,1) = 0) and not marked with flag 32
3600 LET T3 = 0
3605 LET T4 = 0
3610 LET T5 = 0
3615 LET T6 = 0
3620 FOR N3 = J3 TO J4
3625 IF I(N3, 1) = 0 THEN 3665
3630 IF FNB(I(N3, 0), 32) = 1 THEN 3665
3635 LET T3 = T3 + 1
3640 LET T4 = T4 + I(N3, 3)
3645 LET X3 = Q(I(N3, 1), 6)
3650 IF X3 > 2 THEN 3657
3655 LET T6 = T6 + 1
3657 IF X3 = 56 THEN 3663
3659 IF X3 = 58 THEN 3663
3660 IF X3 < 60 THEN 3665
3661 IF X3 > 61 THEN 3665
3663 LET T5 = T5 + 1
3665 NEXT N3
3670 RETURN
3695 REM ---- CAPOK (after SNAP): F0 = 1 when the function, with U0 more instructions, U1 more operands,
3697 REM U2 more registers, U3 more blocks and U4 more immediates than now (records made since SNAP
3698 REM included), fits the LIR capacity limits (Decision 72) and U5 W rows, U6 operands the buffers
3700 LET F0 = 0
3705 IF A0 + M1 - M0 + U0 > I9 THEN 1095
3710 IF M2 + U1 > O9 THEN 1095
3712 IF M2 + U6 + 5 > 999999 THEN 1095
3714 IF M1 + U5 > 199999 THEN 1095
3720 IF M7 + U2 > R9 THEN 1095
3725 IF B2 + U3 > B9 THEN 1095
3730 IF M3 + U4 > M9 THEN 1095
3731 IF A2 + U4 > 199999 THEN 1095
3732 IF A6 + 2 > 199999 THEN 1095
3735 LET F0 = 1
3740 RETURN
3795 REM ---- MAYCH (DESIGN 5.8 Terms): F0 = 1 when the load at record Y1 may be changed by record Y
3800 LET F0 = 0
3805 LET X8 = I(Y1, 2)
3810 LET X5 = O(X8 + 1)
3815 LET G9 = O(X8 + 4)
3820 GOSUB 3240
3822 LET X3 = Q(I(Y, 1), 6)
3825 IF O(X8 + 2) <> 0 THEN 3895
3830 IF R(X5, 5) <> 1 THEN 3860
3835 IF V5 = K6 THEN 1095
3840 IF V5 = K7 THEN 1095
3845 IF V5 = K8 THEN 1095
3850 IF V5 <> K9 THEN 3860
3852 IF X3 < 71 THEN 3920
3855 GOTO 3925
3860 IF R(X5, 7) <> 1 THEN 3895
3865 IF Q(I(Y, 1), 7) <> 4 THEN 1095
3870 IF O(I(Y, 2) + 1) <> X5 THEN 1095
3872 LET X4 = 8
3874 IF Q(I(Y1, 1), 6) <> 48 THEN 3877
3876 LET X4 = 1
3877 IF V5 = N8 THEN 3925
3878 LET V3 = V5
3880 LET G9 = O(I(Y, 2) + 4)
3882 GOSUB 3240
3883 IF V5 = N8 THEN 3925
3884 IF V5 >= V3 + X4 THEN 1095
3886 LET X4 = 8
3888 IF X3 <> 52 THEN 3892
3890 LET X4 = 1
3892 IF V3 >= V5 + X4 THEN 1095
3893 GOTO 3925
3895 IF Q(I(Y, 1), 7) <> 4 THEN 3915
3900 IF Q(I(Y, 1), 8) <> Q(I(Y1, 1), 8) THEN 3915
3905 IF R(O(I(Y, 2) + 1), 7) <> 1 THEN 3925
3915 IF X3 = 55 THEN 3925
3920 IF X3 = 67 THEN 3925
3922 IF X3 <> 68 THEN 1095
3925 LET F0 = 1
3930 RETURN
3995 REM ---- EQUAL (T3's equality): F0 = 1 when the instructions at Y1 and Y have the same opcode and
3997 REM fields but the destination and the site (immediates and offsets compared by value)
4000 LET F0 = 0
4005 LET X3 = I(Y1, 1)
4010 IF I(Y, 1) <> X3 THEN 1095
4015 LET X4 = I(Y1, 2)
4020 LET X5 = I(Y, 2)
4025 FOR Z9 = 1 TO Q(X3, 4)
4030 LET X8 = F(Q(X3, 3) + Z9 - 1, 0)
4035 IF X8 = 0 THEN 4095
4040 IF X8 = 2 THEN 4085
4045 IF X8 = 3 THEN 4060
4050 IF X8 = 4 THEN 4070
4055 IF O(X4) <> O(X5) THEN 1095
4057 GOTO 4085
4060 FOR Z0 = 1 TO 4
4062 IF C(O(X4), Z0) <> C(O(X5), Z0) THEN 1095
4064 NEXT Z0
4066 GOTO 4085
4070 FOR Z0 = 0 TO 3
4072 IF G(O(X4), Z0) <> G(O(X5), Z0) THEN 1095
4074 NEXT Z0
4085 LET X4 = X4 + 1
4090 LET X5 = X5 + 1
4095 NEXT Z9
4100 LET F0 = 1
4105 RETURN
4195 REM ---- COUNTW: R(r,9) = the writes of r by the records L6 .. L7 (a loop and what it holds)
4200 FOR R2 = 1 TO M7
4205 LET R(R2, 9) = 0
4210 NEXT R2
4215 LET V0 = 9
4220 FOR N0 = L6 TO L7
4225 GOSUB 1105
4230 NEXT N0
4235 RETURN
4295 REM ---- LOCALS (L-bl): R(r,8) = 1 for the registers every reference to which lies in L6 .. L7,
4297 REM the opening record not reading them; U2 their number; R(r,9) cleared (the renaming map)
4300 FOR R2 = 1 TO M7
4305 LET R(R2, 8) = 0
4307 LET R(R2, 9) = 0
4310 NEXT R2
4315 LET V0 = 2
4320 FOR N0 = L6 TO L7
4325 GOSUB 1105
4330 NEXT N0
4335 LET V0 = 3
4340 FOR N0 = 1 TO A0
4345 IF N0 < L6 THEN 4355
4350 IF N0 <= L7 THEN 4360
4355 GOSUB 1105
4360 NEXT N0
4365 LET N0 = L6
4370 LET V0 = 4
4375 GOSUB 1105
4380 LET U2 = 0
4385 FOR R2 = 1 TO M7
4390 IF R2 > M(5) THEN 4398
4395 LET R(R2, 8) = 0
4398 LET U2 = U2 + R(R2, 8)
4400 NEXT R2
4405 RETURN
4495 REM ---- RENAME: the local registers (R(r,8) = 1) of the records with flag 64 get fresh numbers
4497 REM (in order of first reference); flag 64 cleared, fresh ids for their opening records
4500 GOSUB 3150
4505 LET V0 = 5
4510 FOR N0 = 1 TO A0
4515 IF FNB(I(N0, 0), 64) = 0 THEN 4530
4520 LET I(N0, 0) = I(N0, 0) - 64
4525 GOSUB 1105
4530 NEXT N0
4535 RETURN
4595 REM ---- ANC: S(830000+1 .. A7) the opening records of the loops that enclose record L6; W2 = 1
4597 REM when they are more than 4999 (the table's region, L-bv: the caller leaves the loop alone)
4600 LET A7 = 0
4602 LET W2 = 0
4605 LET P6 = S(L6)
4610 IF P6 = 0 THEN 1095
4615 LET X4 = INT(P6 / 2)
4620 LET X3 = Q(I(X4, 1), 6)
4625 IF X3 = 56 THEN 4632
4630 IF X3 <> 58 THEN 4645
4632 IF A7 < 4999 THEN 4635
4633 LET W2 = 1
4634 RETURN
4635 LET A7 = A7 + 1
4640 LET S(830000 + A7) = X4
4645 LET P6 = S(X4)
4650 GOTO 4610
4695 REM NAMEDOUT: F0 = 1 when record Y is a ret, or an exit or next naming a loop that encloses L6
4697 REM (F2 = 1: or naming L6's loop itself)
4700 LET F0 = 0
4705 LET X3 = Q(I(Y, 1), 6)
4710 IF X3 = 66 THEN 4745
4715 IF X3 < 64 THEN 1095
4720 IF X3 > 65 THEN 1095
4725 LET X4 = O(I(Y, 2))
4727 IF F2 = 0 THEN 4732
4730 IF X4 = L8 THEN 4745
4732 FOR Z9 = 1 TO A7
4735 IF O(I(S(830000 + Z9), 2)) = X4 THEN 4745
4740 NEXT Z9
4742 RETURN
4745 LET F0 = 1
4750 RETURN
