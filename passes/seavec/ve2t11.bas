10000 REM ====================================================================================
10005 REM T11: unrolling of short constant loops (DESIGN 2.12.6, Decisions 102, 117, L-ev, L-gq). An
10010 REM innermost loop B J S C T (S T constants of seavec, R(r,6)) with a known count n, 1 <= n <= 8 (C
10015 REM a constant 0..7, or C's only definition an rcount of constant lo hi st: RCNT 10600), at most
10020 REM 64 body records, no block record, exit, next or ret, and a load or store with an sa base
10025 REM (R(base,5) > 0) and idx J becomes n copies of its body, copy k (from 1) led by li Jk (S +
10030 REM (k-1)*T); a register the body writes gets a fresh name per copy (K4 the map, K5 the copy), a
10035 REM read takes the newest name (copy 1: the original); then a mov back to the original register of
10040 REM every register written in the body and read after the loop (3200) or carried around it (read
10045 REM before its write: W(r,1) = K6). The guard and the rcount stay. Candidates: the loops of the
10050 REM function before T11, in record order (L-gt); a loop whose J is read after it is left (L-gs).
10052 REM Locals N4 (scan), L6 L7 (the loop), H0 H4 (J and Jk), D0 D1 D2 (S, n - 1, T values).
10055 REM ====================================================================================
10060 LET N4 = 1
10065 IF N4 > A0 THEN 1399
10070 IF FNC(N4) <> 56 THEN 10590
10075 LET L6 = N4
10080 LET L7 = K(FNO(L6, 0), 4)
10085 IF L7 - L6 > 65 THEN 10590
10090 FOR N3 = L6 + 1 TO L7 - 1
10095 IF FNC(N3) < 56 THEN 10105
10100 IF FNC(N3) <= 66 THEN 10590
10105 NEXT N3
10110 LET H0 = FNO(L6, 1)
10115 LET D0 = R(FNO(L6, 2), 6)
10120 LET D2 = R(FNO(L6, 4), 6)
10125 IF D0 = N8 THEN 10590
10130 IF D2 = N8 THEN 10590
10135 LET X5 = FNO(L6, 3)
10137 LET D1 = R(X5, 6)
10139 IF D1 = N8 THEN 10600
10141 IF D1 < 0 THEN 10590
10143 IF D1 > 7 THEN 10590
10145 IF ABS(D0 + D1 * D2) > U9 THEN 10590
10150 IF ABS(D0) > U9 THEN 10590
10155 FOR N3 = L6 + 1 TO L7 - 1
10160 IF Q(I(N3, 1), 7) < 3 THEN 10175
10165 IF FNO(N3, 2) <> H0 THEN 10175
10170 IF R(FNO(N3, 1), 5) > 0 THEN 10185
10175 NEXT N3
10180 GOTO 10590
10185 LET J5 = L6
10190 LET J6 = L7
10195 GOSUB 3200
10200 IF W(100000 + H0, 2) = L3 THEN 10590
10205 REM the registers written in the body (R(r,0) = K3), carried ones (W(r,1) = K6), the list of
10210 REM those to move back, in the order of their first writes: S(830000+1 .. D3)
10215 LET K2 = K2 - 3
10220 LET K3 = K2 + 2
10225 LET K5 = K2 + 1
10230 LET K6 = K2
10235 LET V0 = 2
10240 LET J3 = L6 + 1
10245 LET J4 = L7 - 1
10250 GOSUB 1800
10255 LET D3 = 0
10260 FOR N0 = L6 + 1 TO L7 - 1
10265 LET V0 = 8
10270 GOSUB 1315
10275 LET V0 = 9
10280 GOSUB 1315
10285 NEXT N0
10290 FOR N0 = L6 + 1 TO L7 - 1
10295 LET X7 = 0
10300 LET V0 = 14
10305 GOSUB 1315
10310 NEXT N0
10315 REM the copies (each li Jk at its top), then the moves back; K4 the map, K5 each copy's stamp
10320 LET T3 = A0 + 1
10325 LET T4 = A1 + 1
10330 LET O0 = 0
10335 LET W3 = M7
10336 LET W4 = A2
10337 LET W5 = A6
10340 LET K2 = K2 - 1
10345 LET K4 = K2
10350 FOR D4 = 0 TO D1
10355 LET K2 = K2 - 1
10360 LET K5 = K2
10365 LET V3 = D0 + D4 * D2
10370 GOSUB 2720
10375 LET H4 = Z5
10380 FOR X8 = L6 + 1 TO L7 - 1
10382 GOSUB 2600
10384 LET N0 = H7
10386 LET V0 = 6
10388 GOSUB 1315
10389 LET V0 = 7
10390 GOSUB 1315
10392 NEXT X8
10394 NEXT D4
10400 FOR D4 = 1 TO D3
10405 LET H3 = 5
10410 LET O3 = S(830000 + D4)
10415 LET O4 = R(O3, 9)
10420 GOSUB 2500
10425 NEXT D4
10430 LET U0 = T3 - A0 - 1 - (L7 - L6 + 1)
10435 LET U1 = T4 - A1 - 1
10440 LET U3 = 0
10445 GOSUB 3100
10450 IF O0 = 1 THEN 10460
10455 IF F0 = 1 THEN 10475
10460 LET M7 = W3
10465 LET A2 = W4
10467 LET A6 = W5
10470 GOTO 10590
10475 LET J7 = A0 + 1
10480 LET J8 = T3 - 1
10485 LET N4 = L6 + J8 - J7
10490 GOSUB 2800
10495 GOSUB 1900
10500 LET D9 = D9 + 1
10590 LET N4 = N4 + 1
10595 GOTO 10065
10597 REM ---- RCNT: C (X5) not a constant: n from its only definition, an rcount C E lo hi st incl of
10598 REM constant lo hi st, by LANGUAGE 5.1's element count, enumerated exactly (D1 = n - 1, 1 <= n <= 8)
10600 IF R(X5, 3) <> 1 THEN 10590
10605 LET X4 = R(X5, 4)
10610 IF X4 <= 0 THEN 10590
10615 IF FNC(X4) <> 28 THEN 10590
10620 IF FNO(X4, 0) <> X5 THEN 10590
10625 LET V2 = R(FNO(X4, 2), 6)
10630 LET V3 = R(FNO(X4, 3), 6)
10635 LET V4 = R(FNO(X4, 4), 6)
10640 IF V2 = N8 THEN 10590
10645 IF V3 = N8 THEN 10590
10650 IF V4 = N8 THEN 10590
10655 IF V4 = 0 THEN 10590
10660 LET X6 = 0
10665 LET V5 = V2
10670 IF X6 > 8 THEN 10590
10675 IF V4 < 0 THEN 10690
10680 IF V5 > V3 THEN 10715
10685 GOTO 10695
10690 IF V5 < V3 THEN 10715
10695 IF V5 <> V3 THEN 10705
10700 IF FNO(X4, 5) = 0 THEN 10715
10705 LET X6 = X6 + 1
10707 LET V5 = V5 + V4
10710 GOTO 10670
10715 IF X6 = 0 THEN 10590
10720 LET D1 = X6 - 1
10725 GOTO 10145
