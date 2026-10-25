20000 REM ====================================================================================
20005 REM T8: hoisting and constant commoning (DESIGN 5.8 T8, Decision 63, L-aj, L-ao), pass P7 (1
20010 REM after T6, 2 after T7), the loops innermost first (in the order of their closing records).
20015 REM An instruction I of L moves before L when: it is pure, or a load without idx no remaining
20020 REM record of L may change; its operands are not written by the remaining records of L
20025 REM (R(r,9) counts those writes); it is the only remaining definition of its destination D in L;
20030 REM every remaining read of D in L lies after I in a part contained in I's part ("I's block"
20035 REM read as its part); D is read nowhere outside L (nor by a moved instruction) unless I is
20040 REM anticipated; and a load also by (a) anticipation and an object pointer base, (b) a header
20045 REM field of an array register, (c) bytes inside a private base's memory. The moved ones keep
20050 REM their order before L's opening record (flag 1, placed); then COMMON. Flag 32 marks them.
20052 REM L is left alone inside more than 4999 loops (ANC) or when the moved ones' new W rows
20053 REM would pass row 199999 (L-bv).
20055 REM ====================================================================================
20060 LET Q8 = 2
20065 GOSUB 3000
20070 FOR L = 1 TO L9
20075 LET I8 = S(820000 + L)
20080 GOSUB 3100
20085 IF L6 = 0 THEN 20990
20090 GOSUB 1515
20095 GOSUB 1820
20100 GOSUB 2700
20105 GOSUB 2850
20110 GOSUB 4600
20112 IF W2 = 1 THEN 20990
20115 GOSUB 4200
20120 LET O0 = 0
20125 FOR N4 = L6 + 1 TO L7 - 1
20130 LET X3 = Q(I(N4, 1), 6)
20135 IF X3 < 56 THEN 20145
20140 IF X3 <= 66 THEN 20800
20145 IF FNB(I(N4, 0), 16) = 1 THEN 20800
20150 LET X4 = Q(I(N4, 1), 7)
20155 IF X4 = 1 THEN 20200
20160 IF X4 <> 3 THEN 20800
20165 IF O(I(N4, 2) + 2) <> 0 THEN 20800
20170 FOR M4 = L6 TO L7
20175 IF FNB(I(M4, 0), 32) = 1 THEN 20195
20180 LET Y1 = N4
20185 LET Y = M4
20190 GOSUB 3800
20192 IF F0 = 1 THEN 20800
20195 NEXT M4
20200 REM operands not written in L (but by moved ones); D defined once in L
20205 LET N0 = N4
20210 GOSUB 3490
20215 IF F0 = 0 THEN 20800
20220 LET D = X7
20225 IF R(D, 9) <> 1 THEN 20800
20230 REM every remaining read of D in L after I, in a part that I's part contains
20235 FOR M4 = L6 TO L7
20240 IF FNB(I(M4, 0), 32) = 1 THEN 20275
20245 LET N0 = M4
20250 GOSUB 3476
20255 IF F0 = 0 THEN 20275
20260 IF M4 <= N4 THEN 20800
20265 LET P5 = S(N4)
20267 LET P6 = S(M4)
20270 GOSUB 2800
20272 IF F0 = 0 THEN 20800
20275 NEXT M4
20280 REM anticipated (F3 = 1): at the top level of L's body, no ret, release, call, nor exit or next
20285 REM of L or of an enclosing loop before it
20290 LET F3 = 0
20295 IF S(N4) <> 2 * L6 THEN 20340
20300 LET F2 = 1
20305 FOR M4 = L6 + 1 TO N4 - 1
20310 LET X3 = Q(I(M4, 1), 6)
20315 IF X3 = 67 THEN 20340
20320 IF X3 = 72 THEN 20340
20325 LET Y = M4
20327 GOSUB 4700
20330 IF F0 = 1 THEN 20340
20335 NEXT M4
20338 LET F3 = 1
20340 IF F3 = 1 THEN 20385
20345 REM not anticipated: D read nowhere outside L, nor by a moved instruction
20350 LET X7 = D
20355 FOR M4 = 1 TO A0
20360 IF FNB(I(M4, 0), 32) = 1 THEN 20372
20365 IF M4 < L6 THEN 20372
20370 IF M4 <= L7 THEN 20380
20372 LET N0 = M4
20374 GOSUB 3476
20376 IF F0 > 0 THEN 20800
20380 NEXT M4
20385 IF Q(I(N4, 1), 7) = 1 THEN 20700
20390 REM a load: (a), (b) or (c)
20395 LET P8 = I(N4, 2)
20400 LET P9 = O(P8 + 1)
20405 LET G9 = O(P8 + 4)
20410 GOSUB 3240
20415 LET X4 = 8
20420 IF Q(I(N4, 1), 6) <> 48 THEN 20430
20425 LET X4 = 1
20430 IF F3 = 0 THEN 20440
20435 IF R(P9, 0) = 1 THEN 20700
20440 IF R(P9, 5) <> 1 THEN 20470
20445 IF V5 = K9 THEN 20700
20450 IF V5 = K6 THEN 20700
20455 IF V5 = K7 THEN 20700
20460 IF V5 = K8 THEN 20700
20470 IF R(P9, 7) <> 1 THEN 20800
20475 IF V5 < 0 THEN 20800
20480 IF V5 = N8 THEN 20800
20485 IF P9 <= M(5) THEN 20510
20490 LET X8 = O(I(R(P9, 4), 2) + 1)
20495 IF V5 + X4 <= K(10000 + X8, 1) THEN 20700
20500 GOTO 20800
20510 LET V3 = V5
20515 FOR M4 = 1 TO A0
20520 IF Q(I(M4, 1), 7) < 3 THEN 20550
20525 IF O(I(M4, 2) + 1) <> P9 THEN 20550
20530 LET G9 = O(I(M4, 2) + 4)
20535 GOSUB 3240
20537 IF V5 = N8 THEN 20550
20540 LET X5 = 8
20542 IF Q(I(M4, 1), 6) = 48 THEN 20546
20544 IF Q(I(M4, 1), 6) <> 52 THEN 20548
20546 LET X5 = 1
20548 IF V3 + X4 <= V5 + X5 THEN 20700
20550 NEXT M4
20555 GOTO 20800
20700 REM I moves out: flag 32, its write no longer counts in L
20705 LET I(N4, 0) = I(N4, 0) + 32
20710 LET O0 = O0 + 1
20715 LET R(D, 9) = R(D, 9) - 1
20800 NEXT N4
20805 IF O0 = 0 THEN 20850
20807 IF A0 + O0 > 199999 THEN 20996
20810 GOSUB 2005
20815 FOR N4 = L6 + 1 TO L7 - 1
20820 IF FNB(I(N4, 0), 32) = 0 THEN 20845
20825 LET X8 = N4
20830 GOSUB 2200
20832 LET W(H7, 0) = W(H7, 0) - 32 + 1 - FNB(W(H7, 0), 1)
20835 LET H4 = L6
20837 GOSUB 2300
20840 LET W(N4, 1) = 0
20845 NEXT N4
20847 GOSUB 2400
20850 GOSUB 22000
20990 NEXT L
20995 RETURN
20996 FOR N4 = L6 + 1 TO L7 - 1
20997 LET I(N4, 0) = I(N4, 0) - 32 * FNB(I(N4, 0), 32)
20998 NEXT N4
20999 GOTO 20990
22000 REM ---- COMMON: among the records standing before L's opening record (the run of placed ones,
22002 REM up to a block record, exit, next or ret), a later one equal (T3) to an earlier one of the
22004 REM run whose operands are not written between, both destinations having one definition in the
22006 REM function, has its reads replaced by the earlier destination and is deleted
22010 GOSUB 3100
22015 LET J5 = L6
22020 IF J5 <= 1 THEN 22045
22025 IF FNB(I(J5 - 1, 0), 1) = 0 THEN 22045
22030 LET X3 = Q(I(J5 - 1, 1), 6)
22035 IF X3 < 56 THEN 22042
22040 IF X3 <= 66 THEN 22045
22042 LET J5 = J5 - 1
22043 GOTO 22020
22045 LET O0 = 0
22050 FOR M4 = J5 TO L6 - 1
22055 FOR M5 = M4 - 1 TO J5 STEP -1
22060 IF I(M5, 1) = 0 THEN 22150
22065 LET Y1 = M5
22070 LET Y = M4
22075 GOSUB 4000
22080 IF F0 = 0 THEN 22150
22085 FOR N = M5 + 1 TO M4 - 1
22090 IF I(N, 1) = 0 THEN 22110
22095 LET N0 = N
22100 GOSUB 3490
22102 LET N0 = M4
22104 GOSUB 3476
22106 IF F0 > 0 THEN 22150
22110 NEXT N
22115 LET N0 = M5
22117 GOSUB 3490
22120 LET S3 = X7
22122 GOSUB 3435
22124 IF F0 <> 1 THEN 22150
22126 LET N0 = M4
22128 GOSUB 3490
22130 LET D3 = X7
22132 GOSUB 3435
22134 IF F0 <> 1 THEN 22150
22136 LET V0 = 6
22138 FOR N0 = 1 TO A0
22140 GOSUB 1105
22142 NEXT N0
22144 LET I(M4, 1) = 0
22146 LET O0 = O0 + 1
22148 GOTO 22155
22150 NEXT M5
22155 NEXT M4
22160 IF O0 = 0 THEN 1095
22165 GOTO 69450
