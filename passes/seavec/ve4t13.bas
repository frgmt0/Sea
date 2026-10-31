20000 REM ====================================================================================
20005 REM T13: if-conversion and vectorization (DESIGN 2.12.6, Decisions 99-101, 108, 115, L-fg). The
20010 REM candidates are the loop records of the function before T13 whose body holds no loop record
20015 REM (flag 1 of I(n,0)), visited in record order; the records a rewrite writes carry no flag, so
20020 REM they are never visited. Each candidate L (records L6 .. L7) is tried by TRY (20200): L is
20025 REM copied into a work list, prepared there (P1 21000, P2 25000, P3 and the if-conversion 30000),
20030 REM checked (conditions 1-5, 35000) and rewritten into the vector form (40000), which a splice
20035 REM puts in place of L; anything that fails leaves the function as it was (the lists, the new
20040 REM registers and immediates are dropped: M7 A2 A6 B6 restored).
20045 REM Names of T13: P5 P6 P7 the registers S C T of L, P8 its J, L4 the stamp of the registers the
20050 REM current list writes (R(r,0)), L5 the candidate's stamp, M0 the mask stamp (W(r,1)), L8 .. L9
20055 REM the current list, I5 .. I6 P2's records before L, I7 .. I8 list A (L after P1 and P2), B6
20060 REM the last block number given.
20065 REM ====================================================================================
20070 FOR N3 = 1 TO A0
20075 IF FNC(N3) <> 56 THEN 20100
20080 FOR X4 = N3 + 1 TO K(FNO(N3, 0), 4) - 1
20085 IF FNC(X4) = 56 THEN 20100
20090 NEXT X4
20095 LET I(N3, 0) = 1
20100 NEXT N3
20105 LET N4 = 1
20110 IF N4 > A0 THEN 1399
20115 IF FNB(I(N4, 0), 1) = 0 THEN 20130
20120 LET I(N4, 0) = I(N4, 0) - 1
20125 GOSUB 20200
20130 LET N4 = N4 + 1
20135 GOTO 20110
20195 REM ---- TRY: candidate N4; on success N4 is the last record of the vector form in the function
20200 LET L6 = N4
20205 LET L7 = K(FNO(L6, 0), 4)
20210 LET P8 = FNO(L6, 1)
20215 LET P5 = FNO(L6, 2)
20220 LET P6 = FNO(L6, 3)
20225 LET P7 = FNO(L6, 4)
20230 IF R(P7, 6) <> 1 THEN 1399
20235 LET W3 = M7
20240 LET W4 = A2
20245 LET W5 = A6
20250 LET B6 = B2
20255 LET O0 = 0
20260 LET T3 = A0 + 1
20265 LET T4 = A1 + 1
20270 LET L8 = T3
20275 FOR X8 = L6 TO L7
20280 GOSUB 2600
20285 LET I(H7, 0) = 0
20290 NEXT X8
20295 LET L9 = T3 - 1
20300 IF O0 = 1 THEN 20390
20305 GOSUB 3900
20310 IF R(P5, 0) = L4 THEN 20390
20315 IF R(P6, 0) = L4 THEN 20390
20320 IF R(P7, 0) = L4 THEN 20390
20325 REM the reads of each register outside L: W(100000+r,0) under the stamp W(100000+r,1) = L5
20330 LET K2 = K2 - 1
20335 LET L5 = K2
20340 LET K3 = K2
20345 LET V0 = 3
20350 LET J3 = L6
20355 LET J4 = L7
20360 GOSUB 1800
20365 FOR X5 = 1 TO M7
20370 IF V(600000 + X5) <> K3 THEN 20385
20375 LET W(100000 + X5, 0) = R(X5, 8) - V(400000 + X5)
20380 LET W(100000 + X5, 1) = L5
20385 NEXT X5
20386 GOSUB 21000
20387 IF F0 = 0 THEN 20390
20388 GOSUB 25000
20389 IF F0 = 1 THEN 20395
20390 LET M7 = W3
20391 LET A2 = W4
20392 LET A6 = W5
20393 RETURN
20395 GOSUB 30000
20400 IF F0 = 0 THEN 20390
20405 GOSUB 35000
20410 IF F0 = 0 THEN 20390
20415 GOSUB 40000
20420 IF O0 = 1 THEN 20390
20425 LET U0 = J8 - J7 + 1 - (L7 - L6 + 1)
20430 LET U1 = T4 - A1
20435 LET J3 = L6
20440 LET J4 = L7
20442 GOSUB 3950
20444 LET U3 = -F0
20446 LET J3 = J7
20448 LET J4 = J8
20450 GOSUB 3950
20452 LET U3 = U3 + F0
20455 GOSUB 3100
20460 IF F0 = 0 THEN 20390
20465 LET J5 = L6
20470 LET J6 = L7
20475 LET N4 = L6 + J8 - J7
20480 GOSUB 2800
20485 GOSUB 1900
20490 LET D9 = D9 + 1
20495 RETURN
20995 REM ====================================================================================
21000 REM P1 (2.12.6): each do D of the list, innermost first (the first enddo), whose body holds no
21005 REM loop, do, ret, next or exit of another block, is dissolved: rule 1 deletes the records after
21010 REM an exit D, or after a block both parts of which end in exit D, up to the end of their part;
21015 REM rule 2 moves the records after a block exactly one part of which ends in exit D to the end of
21020 REM its other part (an else made when it has none); then, when D's body ends in exit D and every
21025 REM exit D is in tail position, the exits, the do and the enddo go. Else F0 = 0 (L is not
21030 REM vectorized). Names: U5 U6 the do and its enddo, Q7 D, S(400000+n) the flags of FLAGS.
21035 REM ====================================================================================
21040 LET F0 = 1
21045 LET J3 = L8
21050 LET J4 = L9
21055 GOSUB 3000
21060 FOR U6 = L8 + 1 TO L9 - 1
21065 IF FNC(U6) = 59 THEN 21080
21070 NEXT U6
21075 RETURN
21080 LET U5 = S(U6)
21085 LET Q7 = FNO(U5, 0)
21090 LET F0 = 0
21095 FOR X4 = U5 + 1 TO U6 - 1
21100 LET X3 = FNC(X4)
21105 IF X3 = 56 THEN 1399
21110 IF X3 = 58 THEN 1399
21115 IF X3 = 65 THEN 1399
21120 IF X3 = 66 THEN 1399
21125 IF X3 <> 64 THEN 21135
21130 IF FNO(X4, 0) <> Q7 THEN 1399
21135 NEXT X4
21140 GOSUB 21400
21145 FOR U7 = U5 + 1 TO U6 - 1
21150 IF S(400000 + U7) = 0 THEN 21170
21155 IF FNC(U7 + 1) = 59 THEN 21170
21160 IF FNC(U7 + 1) < 62 THEN 21180
21165 IF FNC(U7 + 1) > 63 THEN 21180
21170 NEXT U7
21175 GOTO 21300
21180 REM U8 the record that ends U7's part (else, endif or enddo at U7's level)
21185 LET X4 = 0
21190 FOR U8 = U7 + 1 TO U6
21195 LET X3 = FNC(U8)
21200 IF X3 = 62 THEN 21225
21205 IF X3 = 57 THEN 21225
21210 IF X3 = 59 THEN 21225
21215 IF X3 = 63 THEN 21225
21217 IF X3 < 56 THEN 21235
21219 IF X3 > 61 THEN 21235
21221 LET X4 = X4 + 1
21223 GOTO 21235
21225 IF X4 = 0 THEN 21240
21230 IF X3 = 62 THEN 21235
21232 LET X4 = X4 - 1
21235 NEXT U8
21240 REM the new list: rule 1 (flag 3) drops U7+1 .. U8-1; rule 2 moves them into the other part
21242 LET X5 = T3
21245 LET X6 = S(400000 + U7)
21250 LET U2 = L8
21252 LET U4 = U7
21254 IF X6 = 3 THEN 21290
21256 LET X7 = S(200000 + S(U7))
21258 LET U4 = U7 - 1
21260 IF X6 = 2 THEN 21264
21262 LET U4 = X7 - 1
21264 GOSUB 3400
21266 IF X6 = 1 THEN 21272
21268 IF X7 > 0 THEN 21272
21269 LET H3 = 62
21270 LET O3 = FNO(U7, 0)
21271 GOSUB 2500
21272 LET U2 = U7 + 1
21273 LET U4 = U8 - 1
21274 GOSUB 3400
21276 LET U2 = U7
21278 IF X6 = 2 THEN 21282
21280 LET U2 = X7
21282 LET U4 = U7
21290 GOSUB 3400
21292 LET U2 = U8
21293 LET U4 = L9
21294 GOSUB 3400
21295 LET L8 = X5
21296 LET L9 = T3 - 1
21297 IF O0 = 1 THEN 1399
21298 GOTO 21040
21300 REM tail position: D's body ends in exit D, and so does every exit D's way out to enddo D
21305 IF S(400000 + U6 - 1) <> 3 THEN 1399
21310 FOR U7 = U5 + 1 TO U6 - 1
21315 IF FNC(U7) <> 64 THEN 21350
21320 LET X4 = U7
21325 IF X4 + 1 = U6 THEN 21350
21330 IF FNC(X4 + 1) = 63 THEN 21345
21335 IF FNC(X4 + 1) <> 62 THEN 1399
21340 LET X4 = S(X4 + 1) - 1
21345 LET X4 = X4 + 1
21347 GOTO 21325
21350 NEXT U7
21355 LET X5 = T3
21360 FOR X8 = L8 TO L9
21362 IF X8 = U5 THEN 21375
21364 IF X8 = U6 THEN 21375
21366 IF FNC(X8) <> 64 THEN 21372
21368 IF X8 < U5 THEN 21372
21370 IF X8 < U6 THEN 21375
21372 GOSUB 2600
21375 NEXT X8
21380 GOTO 21295
21395 REM FLAGS: S(400000+n) for the records of D's body: 3 an exit D, or an endif both parts of
21397 REM whose block end in exit D; 2 an endif whose first part alone ends so; 1 its else part alone
21400 FOR U7 = U5 + 1 TO U6 - 1
21405 LET S(400000 + U7) = 0
21410 IF FNC(U7) <> 64 THEN 21425
21415 IF FNO(U7, 0) <> Q7 THEN 21470
21417 LET S(400000 + U7) = 3
21420 GOTO 21470
21425 IF FNC(U7) <> 63 THEN 21470
21430 LET X4 = S(U7)
21435 LET X7 = S(200000 + X4)
21440 LET X5 = U7 - 1
21445 IF X7 = 0 THEN 21450
21447 LET X5 = X7 - 1
21450 LET X6 = 0
21452 IF X5 <= X4 THEN 21458
21455 IF S(400000 + X5) <> 3 THEN 21458
21456 LET X6 = 2
21458 IF X7 = 0 THEN 21468
21460 IF U7 - 1 <= X7 THEN 21468
21462 IF S(400000 + U7 - 1) <> 3 THEN 21468
21464 LET X6 = X6 + 1
21468 LET S(400000 + U7) = X6
21470 NEXT U7
21475 RETURN
