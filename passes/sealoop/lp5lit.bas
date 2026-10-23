24900 REM ====================================================================================
24902 REM sealoop part 5 (lines 24900-29999): L9, array literals (numeric, str, struct elements), concatenation (DESIGN
24904 REM 3.5.9, rule 26 (a)-(d)). Of a concatenation each part p keeps in H(p,5) its tmp Q, in
24906 REM H(p,7) and H(p,8) the tmps of its rows and cols (a vector row's part: its length), each
24908 REM row r in H(r,5) the tmp of its rows, H(r,7) their static number, H(r,8) 1 for a row of
24910 REM matrices and scalars. Globals: A a vector row's length so far, E F a row's shape so far,
24912 REM G H the stack's, U the result, D its data, m the row offset, J the column offset.
24914 REM ====================================================================================
24995 REM ==== L9: the literal X of type T6 ===================================================================
25000 LET R2 = H(X, 6)
25002 GOSUB 8400
25004 LET T6 = H(X, 2)
25006 LET V(53) = T6
25008 LET Y7 = T6
25010 GOSUB 8700
25012 IF R5 = 0 THEN 2900
25014 LET R4 = R5
25016 LET F4 = F5
25018 LET V(54) = E5
25020 LET V(58) = S(E5)
25022 LET K8 = 0
25024 REM the rows: R8 of them, C8 parts in the first; Z8 = 1 a concatenation, Z7 = 1 all constants
25026 LET R8 = 0
25028 LET Z8 = 0
25030 LET Z7 = 1
25032 LET X4 = X1
25034 IF X4 = 0 THEN 25060
25036 LET R8 = R8 + 1
25038 LET Q3 = 0
25040 LET X5 = H(X4, 3)
25042 IF X5 = 0 THEN 25054
25044 LET Q3 = Q3 + 1
25046 IF H(X5, 1) <= 3 THEN 25049
25048 LET Z7 = 0
25049 IF T(H(X5, 2), 1) = 0 THEN 25052
25050 LET Z8 = 1
25052 LET X5 = H(X5, 4)
25053 GOTO 25042
25054 IF R8 > 1 THEN 25058
25056 LET C8 = Q3
25058 LET X4 = H(X4, 4)
25059 GOTO 25034
25060 IF R8 > 0 THEN 25080
25061 REM (d) []: an array of extent 0 (cleared), or a fixed-size home
25062 LET S$ = "anew P %0 0 0"
25064 IF F4 = 1 THEN 25072
25066 LET S$ = "C 0,anew P %0 1 1"
25068 IF R4 = 1 THEN 25072
25070 LET S$ = "C 0,C 0,anew P %0 1 2"
25072 GOTO 25480
25080 IF Z8 = 1 THEN 25300
25082 REM (a) fixed: home H; (b) dynamic: array A; each element stored at its column-major place
25083 REM right after it (all constants: their rows moved, in column-major order, under a cdat)
25084 LET S$ = "anew P %0 0 0,= H,D H,= D"
25086 LET Y9$ = "L H,]"
25088 IF F4 = 1 THEN 25150
25090 LET Y9$ = "L A,]"
25092 LET S$ = "C " & STR$(C8) & ",= R,L R,anew P %0 0 1,= A,D A,= D"
25094 IF R4 = 1 THEN 25098
25096 LET S$ = "C " & STR$(R8) & ",= R,C " & STR$(C8) & ",= C,L R,L C,anew P %0 0 2,= A,D A,= D"
25098 IF Z7 = 0 THEN 25150
25100 LET O(H(X, 0), 0) = 0
25102 LET O9 = H(X, 0)
25104 LET C9 = O9
25106 GOSUB 9115
25108 GOSUB 9000
25110 FOR J7 = 1 TO C8
25112 LET X4 = X1
25114 FOR I7 = 1 TO R8
25116 LET X5 = H(X4, 3)
25118 FOR Q3 = 2 TO J7
25120 LET X5 = H(X5, 4)
25122 NEXT Q3
25124 GOSUB 8060
25126 LET O(O0, 1) = O(H(X5, 7), 1)
25128 LET X4 = H(X4, 4)
25130 NEXT I7
25132 NEXT J7
25134 LET S$ = "cdat P ^" & STR$(V(54)) & " " & STR$(R8 * C8) & ",= S,C " & STR$(R8 * C8 * V(58))
25136 LET S$ = S$ & ",= B,L D,L S,L B,mcpy P," & Y9$
25138 GOTO 25480
25150 LET C9 = H(X, 0)
25152 GOSUB 9115
25154 GOSUB 9000
25156 LET X4 = X1
25158 LET I7 = 0
25160 IF X4 = 0 THEN 25180
25162 LET X5 = H(X4, 3)
25164 LET J7 = 0
25166 IF X5 = 0 THEN 25176
25168 LET S$ = "L D,C " & STR$(I7 + J7 * R8) & ",est P %5 0"
25170 LET C9 = H(X5, 8)
25171 GOSUB 9000
25172 LET X5 = H(X5, 4)
25173 LET J7 = J7 + 1
25174 GOTO 25166
25176 LET X4 = H(X4, 4)
25177 LET I7 = I7 + 1
25178 GOTO 25160
25180 LET C9 = O9
25182 LET S$ = Y9$
25184 GOTO 25480
25295 REM ---- (c) concatenation: the parts named in source order, the shapes row by row, the copies
25300 GOSUB 9115
25304 LET X6 = X1
25305 IF X6 = 0 THEN 25320
25306 LET X5 = H(X6, 3)
25307 IF X5 = 0 THEN 25314
25308 LET X4 = X5
25309 LET S$ = "= Q"
25310 GOSUB 8900
25311 LET H(X5, 5) = V(17)
25312 LET X5 = H(X5, 4)
25313 GOTO 25307
25314 LET X6 = H(X6, 4)
25315 GOTO 25305
25320 LET C9 = O9
25322 IF R4 = 2 THEN 25360
25324 REM a vector: one row of scalars and vectors, its lengths summed into A (no check)
25326 LET X6 = X1
25328 GOSUB 25500
25330 LET S$ = "L A,anew P %0 0 1,= U,D U,= D"
25332 IF F4 = 0 THEN 25336
25334 LET S$ = "anew P %0 0 0,= U,D U,= D"
25336 GOSUB 9000
25338 LET X5 = H(X1, 3)
25340 LET D8 = 0
25341 LET S$ = "C 0,= J"
25342 IF X5 = 0 THEN 25358
25343 GOSUB 9000
25344 LET V(17) = H(X5, 5)
25345 LET V(12) = H(X5, 7)
25346 LET S$ = "L Q,L D,L J,est P %5 0"
25347 LET Q3 = 1
25348 IF T(H(X5, 2), 1) = 0 THEN 25351
25349 LET S$ = "D Q,= y,( L z,L y,L z,eld P %1 %5 0,L D,L J,L z,wbin P 3 add,est P %5 0,)"
25350 LET Q3 = T(H(X5, 2), 0)
25351 GOSUB 9000
25352 LET D8 = D8 + Q3
25353 LET V(11) = H(X5, 7)
25354 LET S$ = "L J,L K,wbin P 3 add,= J"
25355 IF F4 = 0 THEN 25357
25356 LET S$ = "C " & STR$(D8) & ",= J"
25357 LET X5 = H(X5, 4)
25358 IF X5 > 0 THEN 25342
25359 LET S$ = "L U,]"
25360 IF R4 = 1 THEN 25480
25361 REM a matrix: each row's join (E, F), then the stack (G, H) checked row by row
25362 LET X6 = X1
25363 LET I7 = 0
25364 IF X6 = 0 THEN 25390
25366 GOSUB 25530
25368 IF I7 > 0 THEN 25374
25370 LET V(7) = V(5)
25371 LET V(8) = V(6)
25372 GOTO 25380
25374 LET S$ = "L H,L F,bin P 2 ne,= S,L S,L G,L H,L E,L F,chk P SHAPE_MISMATCH 4,"
25376 IF F4 = 0 THEN 25378
25377 LET S$ = ""
25378 LET S$ = S$ & "L G,L E,wbin P 3 add,= G"
25379 GOSUB 9000
25380 LET I7 = I7 + 1
25381 LET X6 = H(X6, 4)
25382 GOTO 25364
25390 LET S$ = "L G,L H,anew P %0 0 2,= U,D U,= D"
25392 IF F4 = 0 THEN 25396
25394 LET S$ = "anew P %0 0 0,= U,D U,= D"
25396 GOSUB 9000
25398 REM the copies: m the offset of each row, J (25600) of each part in it
25400 LET X6 = X1
25402 LET D8 = 0
25404 LET S$ = "C 0,= m"
25406 IF X6 = 0 THEN 25420
25408 GOSUB 9000
25410 GOSUB 25600
25412 LET V(5) = H(X6, 5)
25414 LET D8 = D8 + H(X6, 7)
25415 LET S$ = "L m,L E,wbin P 3 add,= m"
25416 IF F4 = 0 THEN 25418
25417 LET S$ = "C " & STR$(D8) & ",= m"
25418 LET X6 = H(X6, 4)
25419 GOTO 25406
25420 LET S$ = "L U,]"
25480 GOSUB 9000
25482 LET N7 = N7 - 1
25484 GOTO 5180
25495 REM ---- 25500: the row X6 of scalars and vectors: each part's length L (H(p,7)), summed into A
25500 LET X5 = H(X6, 3)
25501 LET Q3 = 0
25502 IF X5 = 0 THEN 25516
25503 LET V(17) = H(X5, 5)
25504 LET S$ = "C 1,= L"
25505 IF T(H(X5, 2), 1) = 0 THEN 25507
25506 LET S$ = "X Q 0,= L"
25507 IF Q3 = 0 THEN 25509
25508 LET S$ = S$ & ",L A,L L,wbin P 3 add,= A"
25509 GOSUB 9000
25510 LET H(X5, 7) = V(12)
25511 IF Q3 > 0 THEN 25513
25512 LET V(1) = V(12)
25513 LET Q3 = 1
25514 LET X5 = H(X5, 4)
25515 GOTO 25502
25516 RETURN
25525 REM ---- 25530: the join (E, F) of row X6 of a matrix: a vector row is 1 x its length; a row of
25526 REM matrices and scalars takes each part's (R, C), checked against the row so far (no check of
25527 REM fixed-size parts), F summed
25530 LET Q3 = 0
25531 LET X5 = H(X6, 3)
25532 IF X5 = 0 THEN 25538
25533 IF T(H(X5, 2), 1) = 0 THEN 25536
25534 IF T(H(X5, 2), 1) <> 2 THEN 25536
25535 LET Q3 = 1
25536 LET X5 = H(X5, 4)
25537 GOTO 25532
25538 LET H(X6, 8) = Q3
25539 LET H(X6, 7) = 1
25540 IF Q3 = 1 THEN 25549
25541 GOSUB 25500
25542 LET S$ = "C 1,= E"
25543 GOSUB 9000
25544 LET V(6) = V(1)
25545 LET H(X6, 5) = V(5)
25546 RETURN
25549 LET X5 = H(X6, 3)
25550 LET Q3 = 0
25551 IF X5 = 0 THEN 25575
25552 LET V(17) = H(X5, 5)
25553 LET S$ = "C 1,= R,C 1,= C"
25554 IF T(H(X5, 2), 1) = 0 THEN 25556
25555 LET S$ = "X Q 0,= R,X Q 1,= C"
25556 IF Q3 = 0 THEN 25562
25557 IF F4 = 1 THEN 25560
25558 LET S$ = S$ & ",L E,L R,bin P 2 ne,= S,L S,L E,L F,L R,L C,chk P SHAPE_MISMATCH 4"
25560 LET S$ = S$ & ",L F,L C,wbin P 3 add,= F"
25562 GOSUB 9000
25563 LET H(X5, 7) = V(18)
25564 LET H(X5, 8) = V(3)
25565 IF Q3 > 0 THEN 25571
25566 LET V(5) = V(18)
25567 LET V(6) = V(3)
25568 IF T(H(X5, 2), 1) = 0 THEN 25571
25569 LET H(X6, 7) = T(H(X5, 2), 0)
25571 LET Q3 = 1
25572 LET X5 = H(X5, 4)
25573 GOTO 25551
25575 LET H(X6, 5) = V(5)
25576 RETURN
25595 REM ---- 25600: the parts of row X6 copied into U at (m, J); J the next part's offset
25600 LET X5 = H(X6, 3)
25601 LET D6 = 0
25602 LET S$ = "C 0,= J"
25603 IF X5 = 0 THEN 25630
25604 GOSUB 9000
25605 LET V(17) = H(X5, 5)
25606 LET S$ = "L Q,L D,L m,L J,L G,wbin P 3 mul,wbin P 3 add,est P %5 0"
25607 IF T(H(X5, 2), 1) = 0 THEN 25616
25608 LET V(18) = H(X5, 7)
25609 LET V(3) = H(X5, 8)
25610 LET S$ = ""
25611 IF H(X6, 8) = 1 THEN 25614
25612 LET V(3) = H(X5, 7)
25613 LET S$ = "C 1,= R,"
25614 LET S$ = S$ & "D Q,= y,( C h,( R z,L y,L z,L h,L R,wbin P 3 mul,wbin P 3 add,eld P %1 %5 0,L D,L m,L z"
25615 LET S$ = S$ & ",wbin P 3 add,L J,L h,wbin P 3 add,L G,wbin P 3 mul,wbin P 3 add,est P %5 0,),)"
25616 GOSUB 9000
25617 LET V(3) = H(X5, 8)
25618 IF H(X6, 8) = 1 THEN 25620
25619 LET V(3) = H(X5, 7)
25620 LET Q3 = 1
25621 IF T(H(X5, 2), 1) = 0 THEN 25625
25622 LET Q3 = T(H(X5, 2), 4)
25623 IF H(X6, 8) = 1 THEN 25625
25624 LET Q3 = T(H(X5, 2), 0)
25625 LET D6 = D6 + Q3
25626 LET S$ = "L J,L C,wbin P 3 add,= J"
25627 IF F4 = 0 THEN 25629
25628 LET S$ = "C " & STR$(D6) & ",= J"
25629 LET X5 = H(X5, 4)
25630 IF X5 > 0 THEN 25604
25631 RETURN
