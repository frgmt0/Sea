35000 REM ====================================================================================
35005 REM The conditions 1-5 of T13 (DESIGN 2.12.6) on list B (L8 .. L9), F0 = 1 when all hold. (1)
35010 REM the body is one region (T a constant 1 and S C T invariant: TRY). (3) first the registers
35015 REM list A's body writes (R(r,0) = R5, J included) are not read after L (3200); then, with
35020 REM R(r,0) = L4 for list B: every f register read is written earlier in the iteration (W(r,0) =
35025 REM M4) or not written in the body, every i register read a mask written earlier, J as a unit
35030 REM access's idx, or a register of a sum8 group. (5) sum8 groups (flag 4, S(700000+8k+0..6): the
35035 REM records of iand, ldf, fadd, stf, then A, G, Y; R6 groups). (2) every record in the vector set,
35037 REM and (1) at least one unit access (UNIT, Decision 117).
35040 REM ====================================================================================
35045 LET F0 = 0
35050 LET R5 = L4
35055 FOR U7 = L8 + 1 TO L9 - 1
35060 IF FNC(U7) < 56 THEN 35070
35065 IF FNC(U7) <= 66 THEN 1399
35070 NEXT U7
35075 LET J5 = L6
35080 LET J6 = L7
35085 GOSUB 3200
35090 FOR X5 = 1 TO M7
35095 IF R(X5, 0) <> R5 THEN 35105
35100 IF W(100000 + X5, 2) = L3 THEN 1399
35105 NEXT X5
35110 GOSUB 3900
35115 GOSUB 29000
35120 LET R6 = 0
35125 FOR U7 = L8 + 1 TO L9 - 1
35130 IF FNC(U7) <> 17 THEN 35145
35135 IF FNO(U7, 1) <> P8 THEN 35145
35140 IF R(FNO(U7, 2), 6) <> 7 THEN 35145
35142 GOSUB 35500
35145 NEXT U7
35150 LET S4 = 0
35152 LET H5 = 0
35155 FOR U7 = L8 + 1 TO L9 - 1
35160 GOSUB 32000
35165 IF F0 = 0 THEN 1399
35167 GOSUB 35470
35170 NEXT U7
35171 LET F0 = 0
35172 IF H5 = 0 THEN 1399
35175 LET F0 = 1
35180 LET K2 = K2 - 1
35185 LET M4 = K2
35190 FOR N0 = L8 + 1 TO L9 - 1
35195 LET V0 = 19
35200 GOSUB 1315
35205 LET V0 = 20
35210 GOSUB 1315
35215 NEXT N0
35220 RETURN
35465 REM UNIT: H5 counts the unit accesses (condition 1, Decision 117): ldb ldf stb stf in the vector
35467 REM set that are neither an invariant load (flag 2) nor a sum8 record (flag 4)
35470 LET X3 = FNC(U7)
35472 IF FNB(I(U7, 0), 4) = 1 THEN 1399
35474 IF FNB(I(U7, 0), 2) = 1 THEN 1399
35476 IF X3 = 48 THEN 35484
35478 IF X3 = 49 THEN 35484
35480 IF X3 < 52 THEN 1399
35482 IF X3 > 53 THEN 1399
35484 LET H5 = H5 + 1
35486 RETURN
35495 REM SUM8: the group of the iand W J Q at U7, when ldf G A W 8 0, fadd G G Y, stf G A W 8 0 follow
35497 REM in this order, A an sa of a 64-byte slot, S the constant 0, W and G used by them only
35500 IF R(P5, 6) <> 0 THEN 1399
35505 LET X7 = FNO(U7, 0)
35510 IF V(500000 + X7) <> 1 THEN 1399
35515 IF V(400000 + X7) <> 2 THEN 1399
35520 FOR U8 = U7 + 1 TO L9 - 1
35525 IF FNC(U8) <> 49 THEN 35540
35530 IF FNO(U8, 2) = X7 THEN 35545
35540 NEXT U8
35542 RETURN
35545 LET D0 = FNO(U8, 1)
35550 LET D1 = FNO(U8, 0)
35555 IF R(D0, 5) <= 0 THEN 1399
35560 IF K(10000 + R(D0, 5), 1) <> 64 THEN 1399
35565 IF V(500000 + D1) <> 2 THEN 1399
35570 IF V(400000 + D1) <> 2 THEN 1399
35575 FOR U6 = U8 + 1 TO L9 - 1
35580 IF FNC(U6) <> 29 THEN 35590
35585 IF FNO(U6, 0) = D1 THEN 35595
35590 NEXT U6
35592 RETURN
35595 IF FNO(U6, 1) <> D1 THEN 1399
35600 IF FNO(U6, 2) = D1 THEN 1399
35605 FOR U5 = U6 + 1 TO L9 - 1
35610 IF FNC(U5) <> 53 THEN 35620
35615 IF FNO(U5, 0) = D1 THEN 35625
35620 NEXT U5
35622 RETURN
35625 IF FNO(U5, 1) <> D0 THEN 1399
35630 IF FNO(U5, 2) <> X7 THEN 1399
35635 LET X8 = U5
35640 GOSUB 35700
35645 IF F0 = 0 THEN 1399
35650 LET X8 = U8
35655 GOSUB 35700
35660 IF F0 = 0 THEN 1399
35662 IF R6 >= 4999 THEN 1399
35665 LET R6 = R6 + 1
35670 LET X5 = 700000 + 8 * R6
35675 LET S(X5) = U7
35677 LET S(X5 + 1) = U8
35679 LET S(X5 + 2) = U6
35681 LET S(X5 + 3) = U5
35683 LET S(X5 + 4) = D0
35685 LET S(X5 + 5) = D1
35687 LET S(X5 + 6) = FNO(U6, 2)
35690 FOR X4 = 0 TO 3
35692 LET I(S(X5 + X4), 0) = 4
35694 NEXT X4
35696 RETURN
35700 REM scale 8 and off 0 at record X8: F0 = 1
35705 LET F0 = 0
35710 IF FNO(X8, 3) <> 8 THEN 1399
35715 LET G9 = FNO(X8, 4)
35720 GOSUB 2240
35725 IF V5 <> 0 THEN 1399
35727 LET F0 = 1
35730 RETURN
