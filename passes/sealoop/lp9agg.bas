45000 REM ====================================================================================
45002 REM sealoop part 9 (lines 45000-49999): the rewrites of 4g-2 (DESIGN 3.5.9, "What sealoop
45004 REM rewrites in 4g"): L15 projection; the fld and slit nodes validated (a fld on an
45006 REM assignment target is not written: L17 or L6 rewrites it); L17 in general (field paths,
45008 REM reference and aggregate elements by scalar indices; R17-R19, R23-R25), also for the str
45010 REM elements of 4g-1; the field root of L6; R20's counted copies of L6 and L10. Struct
45012 REM layouts from the module layout (C(), L-k). Path globals: Z6 the target's top node, R9 its
45014 REM root lv, E9 the root's lid, E7 its type, E4 1 for a ref parameter of a dynamic array
45016 REM type, E2 that root's tmp B, H8 1 when Z6 is L6's selection (its indices and checks are
45018 REM IX's); per idx node x of the path J(x,0) J(x,1) its index tmps, J(x,2) the rows extent,
45020 REM J(x,3) its array's tmp (step 4), J(x,4) its element's address (step 4, then step 5's), J(x,5)
45021 REM a local made for a dol of x whose container is an element (45940), its step-4 tmp.
45022 REM F6 1 while L6 reads its base B as the field chain whose top is Z5 (lp1walk 9040); S0
45023 REM the rows of the deferred indices (46040), Y2 the first idx deferred, Y3 1 from it on.
45024 REM ====================================================================================
45025 REM ==== L15 proj i of the vector V of structs (rule 29): xblk P F[] { tmp V; tmp N = ext 0;
45026 REM tmp R = anew F[] N; tmp DR; tmp DV; loop(N; K) { est sF 0 (eld F s(S) off DV K) DR K } }
45030 LET R2 = H(X, 6)
45032 GOSUB 8400
45034 LET F9 = 4
45036 GOSUB 8440
45038 LET I1 = VAL(F9$)
45040 LET Y7 = H(X1, 2)
45042 GOSUB 8700
45044 IF R5 <> 1 THEN 2900
45046 IF C(E5, 0) <> 4 THEN 2900
45048 IF I1 >= C(E5, 5) THEN 2900
45050 CALL "ly_fld": C(), E5, I1, I2, I3
45052 REM the field a scalar or a str, the result the dynamic vector of the field's type
45054 IF I2 < 2 THEN 2900
45056 IF I2 > 5 THEN 2900
45058 LET T6 = H(X, 2)
45060 IF T(T6, 1) <> 1 THEN 2900
45062 IF T(T6, 3) <> 0 THEN 2900
45064 IF T(T6, 2) <> I2 THEN 2900
45066 LET V(53) = T6
45068 GOSUB 9115
45070 LET K8 = 0
45072 LET X4 = X1
45074 LET S$ = "= V"
45076 GOSUB 8900
45078 LET C9 = O9
45080 LET S$ = "X V 0,= N,L N,anew P %0 0 1,= R,D R,= D,D V,= W,( N K,L W,L K,eld P " & STR$(I2) & " " & STR$(S(E5))
45082 LET S$ = S$ & " " & STR$(I3) & ",L D,L K,est P " & STR$(S(I2)) & " 0,),L R,]"
45084 GOSUB 9000
45086 LET N7 = N7 - 1
45088 GOTO 5180
45095 REM ---- fld i of a struct or record value: validated; on an assignment target not written
45096 REM (L17 or L6 writes the path), elsewhere copied (sealower's rules 18 and 27 (e))
45100 LET Y7 = H(X1, 2)
45102 IF Y7 <= 9 THEN 2900
45104 IF C(Y7, 0) <> 4 THEN 2900
45106 LET R2 = H(X, 6)
45108 LET F9 = 4
45110 GOSUB 8440
45112 LET I1 = VAL(F9$)
45114 IF I1 >= C(Y7, 5) THEN 2900
45116 CALL "ly_fld": C(), Y7, I1, I2, I3
45118 IF H(X, 2) <> I2 THEN 2900
45120 LET Y0 = X
45122 GOSUB 45200
45124 IF T2 = 0 THEN 5160
45126 GOTO 5170
45145 REM ---- slit of a struct or record type: one value per field, of the field's type; copied
45150 LET Y7 = H(X, 2)
45152 IF Y7 <= 9 THEN 2900
45154 IF C(Y7, 0) <> 4 THEN 2900
45156 LET R2 = H(X, 6)
45158 LET F9 = 4
45160 GOSUB 8440
45162 IF VAL(F9$) <> C(Y7, 5) THEN 2900
45164 LET X4 = X1
45166 LET I1 = 0
45168 IF I1 = C(Y7, 5) THEN 5160
45170 CALL "ly_fld": C(), Y7, I1, I2, I3
45172 IF H(X4, 2) <> I2 THEN 2900
45174 LET X4 = H(X4, 4)
45176 LET I1 = I1 + 1
45178 GOTO 45168
45195 REM ---- 45200: T2 = 1 if node Y0 lies on the target of an asg (the base chain of fld, idx and
45196 REM view nodes up to its first child), 2 on a target of a tasg that L11 or L12 rewrites, else
45197 REM 0; Z4 the top of that chain
45200 LET T2 = 0
45202 LET Z4 = Y0
45204 LET P0 = W(Z4)
45206 IF P0 = 0 THEN 45248
45208 LET K1 = H(P0, 1)
45210 IF K1 = 23 THEN 45230
45212 IF K1 = 24 THEN 45234
45214 IF H(P0, 3) <> Z4 THEN 45248
45216 IF K1 = 56 THEN 45226
45218 IF K1 = 39 THEN 45226
45220 IF K1 <> 45 THEN 45248
45226 LET Z4 = P0
45228 GOTO 45204
45230 IF H(P0, 3) <> Z4 THEN 45248
45232 LET T2 = 1
45233 RETURN
45234 LET X5 = Z4
45235 IF H(X5, 4) = 0 THEN 45238
45236 LET X5 = H(X5, 4)
45237 GOTO 45235
45238 IF X5 = Z4 THEN 45248
45240 LET O5 = P0
45242 GOSUB 30890
45244 LET T2 = 2 * Y8
45248 RETURN
45295 REM ---- 45300: the path below Z6 (H8 = 1: Z6 a selection, its indices L6's) down to its root
45296 REM lv R9, every idx on it of scalar i64 indices, as many as its base's rank; E9 E7 E4 E2
45300 LET Z2 = Z6
45302 LET K1 = H(Z2, 1)
45304 IF K1 = 5 THEN 45340
45306 IF K1 = 56 THEN 45336
45308 IF K1 <> 39 THEN 2900
45310 IF Z2 <> Z6 THEN 45316
45312 IF H8 = 0 THEN 45316
45314 GOTO 45336
45316 LET Z9 = Z2
45318 GOSUB 45390
45320 LET Y7 = H(H1, 2)
45322 IF Y7 <= 9 THEN 2900
45324 IF T(Y7, 1) = 0 THEN 2900
45326 IF H(Z2, 2) <> T(Y7, 2) THEN 2900
45328 LET X5 = H(H1, 4)
45329 LET I1 = 0
45330 IF X5 = 0 THEN 45335
45331 IF H(X5, 2) <> 3 THEN 2900
45332 LET I1 = I1 + 1
45333 LET X5 = H(X5, 4)
45334 GOTO 45330
45335 IF I1 <> T(Y7, 1) THEN 2900
45336 LET Z9 = Z2
45337 GOSUB 45390
45338 LET Z2 = H1
45339 GOTO 45302
45340 REM the root: a local or a ref parameter (its par record's mode)
45342 LET R9 = Z2
45344 LET R2 = H(Z2, 6)
45346 LET F9 = 4
45348 GOSUB 8440
45350 LET E9 = VAL(F9$)
45352 LET E7 = H(Z2, 2)
45354 LET E4 = 0
45356 LET E2 = 0
45358 IF E9 > G(F0, 2) THEN 45370
45360 LET Z$ = D$(G(F0, 6) + E9)
45362 IF SEG$(Z$, LEN(Z$) - 3, LEN(Z$)) <> " ref" THEN 45370
45364 IF T(E7, 1) = 0 THEN 45370
45366 IF T(E7, 3) = 1 THEN 45370
45368 LET E4 = 1
45370 RETURN
45375 REM ---- 45380: Z9 = the next idx of the path above node Z9 (from R9: the first), 0 after Z6
45380 IF Z9 = Z6 THEN 45387
45382 LET Z9 = W(Z9)
45384 IF H(Z9, 1) <> 39 THEN 45380
45386 RETURN
45387 LET Z9 = 0
45388 RETURN
45389 REM ---- 45390: H1 = the base node of the idx Z9 (a folded .flat view: its operand)
45390 LET H1 = H(Z9, 3)
45392 IF H(H1, 1) <> 45 THEN 45396
45394 LET H1 = H(H1, 3)
45396 RETURN
45397 REM ==== L17 (rules 19, 27 (d), (f), 15 (i)): the target X3 (rows after P6: the root's, then
45398 REM the indices'), the value (V5 = 1: its rows after the target's, type V6; V5 = 0: the .l local
45399 REM V(7) of an L12 block, R25), op O6$, at P9$: block P n { (1) value; (2) tmp B; (3) indices;
45400 REM (4) checks; (5) cows; (6) est }; op set aside: (3), tmp R0 = xblk P T 2 {...}, (2), (4)-(6)
45401 LET Z6 = X3
45402 LET H8 = 0
45403 GOSUB 45300
45404 LET B7 = O(P6, 0)
45405 LET G9 = H(X3, 8)
45406 LET G7 = O(B7, 0)
45407 IF G9 <> B7 THEN 45409
45408 LET G7 = 0
45409 LET G5 = O(G9, 0)
45410 LET G8 = O9
45411 LET O(P6, 0) = 0
45412 LET O(G9, 0) = 0
45413 LET O9 = P6
45414 LET C9 = P6
45415 GOSUB 9115
45416 LET K8 = 0
45417 IF O6$ <> "set" THEN 45450
45418 REM set: (1) the value (the root's row dropped), (2), (3)
45419 LET N7 = N7 - 1
45420 LET G1 = V(7)
45421 IF V5 = 0 THEN 45426
45422 GOSUB 45480
45423 LET U1 = V6
45424 GOSUB 45895
45425 LET G1 = U0
45426 GOSUB 45490
45427 GOSUB 45570
45428 GOTO 45540
45449 REM op: (3); xblk { tmp T0 = the read (the root's row, each idx with lv of its index tmps,
45450 REM the fld records), tmp Vv = the value, value bin op }; tmp R0; (2)
45451 GOSUB 46120
45452 GOSUB 9115
45453 LET O(O9, 0) = B7
45454 LET O(B7, 0) = 0
45455 LET O9 = B7
45456 LET C9 = B7
45457 LET Z9 = R9
45458 LET Z9 = W(Z9)
45459 IF H(Z9, 1) <> 39 THEN 45465
45460 LET V1 = J(Z9, 0)
45461 GOSUB 8200
45462 IF J(Z9, 1) = 0 THEN 45465
45463 LET V1 = J(Z9, 1)
45464 GOSUB 8200
45465 LET N7 = N7 + 1
45466 LET Q2$ = "nodes"
45467 IF N7 > N8 THEN 2930
45468 GOSUB 8060
45469 LET O(O0, 1) = H(Z9, 6)
45470 IF Z9 <> Z6 THEN 45458
45471 LET U1 = H(X3, 2)
45472 GOSUB 45895
45473 LET V(51) = U0
45474 GOSUB 45480
45475 LET U1 = V6
45476 GOSUB 45895
45477 LET V(7) = U0
45478 GOTO 45500
45479 REM ---- 45480: the value's rows G5 ... G8 back at the tail
45480 LET O(O9, 0) = G5
45482 LET O9 = G8
45484 LET C9 = O9
45486 RETURN
45489 REM ---- 45490: (2) a ref parameter root of a dynamic array type: tmp B = its lv (E2)
45490 IF E4 = 0 THEN 45498
45492 LET Q9 = -E9
45493 GOSUB 45800
45494 LET U1 = E7
45496 GOSUB 45895
45497 LET E2 = U0
45498 RETURN
45499 REM ---- the operation: lv T0, lv Vv, bin op of the target's type (cat of a str; of an array
45500 REM target the L7 xblk of that bin, as L7 writes it), the xblk closed, tmp R0, then (2)
45502 LET Q3$ = O6$
45503 LET Y7 = H(X3, 2)
45504 GOSUB 8700
45505 IF E5 <> 5 THEN 45508
45506 LET Q3$ = "cat"
45508 LET T6 = H(X3, 2)
45510 IF T(T6, 1) > 0 THEN 45520
45512 LET S$ = "L y,L G,bin P " & STR$(T6) & " " & Q3$ & ",],= G"
45514 GOTO 45534
45520 GOSUB 9115
45522 LET K8 = 1
45524 LET S$ = "L y,= a"
45526 GOSUB 9000
45528 LET K8 = 2
45530 LET S$ = "L G,= a"
45531 GOSUB 9000
45532 GOSUB 45560
45533 LET S$ = "L Q,],],= G"
45534 LET K8 = 0
45535 GOSUB 9000
45536 LET G1 = V(7)
45538 GOSUB 45490
45540 REM (4) checks, (5) cows, (6) the store; the block closed
45541 LET C9 = O9
45542 GOSUB 45620
45543 GOSUB 45660
45544 GOSUB 45710
45545 LET K8 = 0
45546 LET S$ = "}"
45547 GOTO 9000
45555 REM ---- 45560: L7 (2)-(6) of bin op of the slots 1 and 2 (T6 the array type; lp4ew 20150)
45560 LET Y7 = T6
45562 GOSUB 8700
45563 LET N4 = 2
45564 LET Z6$ = "bin " & P9$ & " " & STR$(E5) & " " & Q3$
45566 GOTO 20150
45569 REM ---- 45570: (3) the index rows back at the tail (G7 = 0: none), each index named by a tmp
45570 IF G7 = 0 THEN 45574
45572 LET O(O9, 0) = G7
45573 LET O9 = G9
45574 GOSUB 45600
45576 LET C9 = O9
45578 RETURN
45595 REM ---- 45600: (3) the indices of every idx of the path (not L6's selection), source order
45600 GOSUB 46030
45601 GOSUB 45380
45602 IF Z9 = 0 THEN 45619
45603 IF J(Z9, 5) > 0 THEN 46040
45604 IF Z9 = Z6 THEN 45618
45605 LET Z1 = Z9
45606 GOSUB 45390
45607 LET X5 = H(H1, 4)
45608 LET I1 = 0
45609 LET C9 = H(X5, 8)
45610 LET U1 = 3
45611 GOSUB 45895
45612 LET J(Z1, I1) = U0
45613 LET I1 = I1 + 1
45614 LET X5 = H(X5, 4)
45615 IF X5 > 0 THEN 45609
45616 GOSUB 45380
45617 GOTO 45602
45618 IF H8 = 0 THEN 45605
45619 RETURN
45620 REM ---- 45620: (4) the checks, outermost array first, against the arrays as they are: the
45621 REM base (the root, its tmp B, or tmp Bk = the field chain), per dimension tmp X = ext and chkb;
45622 REM to go on through a field of an element tmp Dk = data, tmp Ek = eld S s(S) 0 Dk pos
45623 GOSUB 46035
45624 GOSUB 45380
45625 IF Z9 = 0 THEN 45619
45626 IF Z9 <> Z6 THEN 45628
45627 IF H8 = 1 THEN 45619
45628 LET Z1 = Z9
45629 GOSUB 45390
45630 IF H1 = R9 THEN 45636
45631 LET H2 = H1
45632 GOSUB 45840
45633 GOSUB 46050
45634 LET J(Z1, 3) = V1
45635 GOSUB 46060
45636 LET I1 = 0
45637 LET A1 = 0
45638 GOSUB 45860
45639 LET Z$ = "ext " & P9$ & " 3 " & STR$(I1)
45640 GOSUB 8050
45641 LET U1 = 3
45642 GOSUB 45895
45643 LET I2 = U0
45644 IF I1 > 0 THEN 45646
45645 LET J(Z1, 2) = U0
45646 LET V1 = J(Z1, I1)
45647 GOSUB 8200
45648 LET V1 = I2
45649 GOSUB 8200
45650 LET Z$ = "chkb " & P9$ & " " & STR$(I1)
45651 GOSUB 8050
45652 LET I1 = I1 + 1
45653 IF I1 < T(H(H1, 2), 1) THEN 45637
45654 LET A1 = 0
45655 GOSUB 45680
45656 GOTO 45625
45659 REM ---- 45660: (5) copy on write outermost first, each array as the cow before left it (R23)
45660 LET Z9 = R9
45661 GOSUB 45380
45662 IF Z9 = 0 THEN 45619
45663 LET Z1 = Z9
45664 GOSUB 45390
45665 IF T(H(H1, 2), 3) = 1 THEN 45670
45666 LET A1 = 1
45667 GOSUB 45860
45668 LET Z$ = "cow " & P9$
45669 GOSUB 8050
45670 LET A1 = 1
45671 GOSUB 45680
45672 GOTO 45662
45679 REM ---- 45680: Z9 = the idx after Z1; when there is one, Z1's element address into J(Z1,4)
45680 LET Z9 = Z1
45681 GOSUB 45380
45682 IF Z9 = 0 THEN 45619
45683 LET I3 = T(H(H1, 2), 2)
45684 IF C(I3, 0) <> 4 THEN 2900
45685 LET E3 = I3
45686 GOSUB 8150
45687 GOSUB 45860
45688 LET Z$ = "adat " & P9$ & " ^" & STR$(I3)
45689 GOSUB 8050
45690 LET U1 = -I3
45691 GOSUB 45895
45692 GOSUB 8200
45693 GOSUB 45880
45694 LET Z$ = "eld " & P9$ & " " & STR$(I3) & " " & STR$(S(I3)) & " 0"
45695 GOSUB 8050
45696 LET U1 = I3
45697 GOSUB 45895
45698 LET J(Z1, 4) = U0
45699 RETURN
45705 REM ---- 45710: (6) est sc off (the value) A X: A the data of the innermost array, X its position
45706 REM (sc its element's size; off the offset of the fields after it, R24), or a struct root's
45707 REM home at ci 0 (sc its size)
45710 LET V1 = G1
45711 GOSUB 8200
45712 LET P3 = 0
45713 LET Z1 = Z6
45714 IF H(Z6, 1) = 39 THEN 45730
45715 LET H2 = Z6
45716 GOSUB 45820
45717 LET Z2 = H3
45718 LET Y7 = H(H(Z2, 3), 2)
45719 LET R2 = H(Z2, 6)
45720 LET F9 = 4
45721 GOSUB 8440
45722 LET I1 = VAL(F9$)
45723 CALL "ly_fld": C(), Y7, I1, I2, I3
45724 LET P3 = P3 + I3
45725 IF Z2 = Z6 THEN 45728
45726 LET Z2 = W(Z2)
45727 GOTO 45718
45728 LET Z1 = H(H3, 3)
45729 IF Z1 = R9 THEN 45740
45730 LET A1 = 1
45731 LET Z9 = Z1
45732 GOSUB 45390
45733 GOSUB 45860
45734 LET I3 = T(H(H1, 2), 2)
45735 GOTO 45744
45740 LET Q9 = -E9
45741 GOSUB 45800
45742 LET I3 = E7
45744 LET E3 = I3
45745 GOSUB 8150
45746 LET Z$ = "adat " & P9$ & " ^" & STR$(I3)
45747 GOSUB 8050
45748 IF Z1 = R9 THEN 45751
45749 GOSUB 45880
45750 GOTO 45753
45751 LET V2 = 0
45752 GOSUB 8300
45753 LET Z$ = "est " & P9$ & " " & STR$(S(I3)) & " " & STR$(P3)
45754 GOTO 8050
45795 REM ---- 45800: lv of the local Q9 (> 0 a row of U, < 0 minus the lid of a local of sea.hir)
45800 IF Q9 > 0 THEN 45806
45802 LET Z$ = "lv " & P9$ & " " & STR$(A(G(F0, 1) - Q9)) & " " & STR$(-Q9)
45804 GOTO 8050
45806 LET V1 = Q9
45808 GOTO 8200
45815 REM ---- 45820: of the field chain whose top is the fld H2: H3 its first fld, Q9 its container
45816 REM (the root, or the address J(x,4) of the element of the idx x below it)
45820 LET H3 = H2
45822 LET Z2 = H(H3, 3)
45824 IF H(Z2, 1) <> 56 THEN 45830
45826 LET H3 = Z2
45828 GOTO 45822
45830 LET Q9 = -E9
45832 IF Z2 = R9 THEN 45838
45834 LET Q9 = J(Z2, 4)
45838 RETURN
45839 REM ---- 45840: the field chain H2 read afresh: lv of its container, its fld records (at P)
45840 GOSUB 45820
45841 IF Q9 = 0 THEN 2900
45842 GOSUB 45800
45844 LET Z2 = H3
45845 LET R2 = H(Z2, 6)
45846 LET F9 = 4
45847 GOSUB 8440
45848 LET Z$ = "fld " & P9$ & " " & STR$(H(Z2, 2)) & " " & F9$
45849 GOSUB 8050
45850 IF Z2 = H2 THEN 45857
45851 LET Z2 = W(Z2)
45852 GOTO 45845
45857 LET S4 = H(H2, 2)
45858 LET L8 = S4
45859 RETURN
45860 REM ---- 45860: the array of the idx Z1 (base H1): the root (A1 = 0: its tmp B if any) or its
45861 REM field chain (A1 = 0: the tmp of step 4; A1 = 1: read afresh over the containers of step 5)
45862 IF H1 <> R9 THEN 45870
45863 LET Q9 = -E9
45864 IF A1 = 1 THEN 45867
45865 IF E2 = 0 THEN 45867
45866 LET Q9 = E2
45867 GOSUB 45800
45868 LET S4 = E7
45869 RETURN
45870 IF A1 = 0 THEN 45874
45871 LET H2 = H1
45872 GOTO 45840
45874 LET V1 = J(Z1, 3)
45876 GOTO 8200
45879 REM ---- 45880: the position of idx Z1: lv I0, or lin(I0, I1, X0) of rule 18
45880 LET V1 = J(Z1, 0)
45881 GOSUB 8200
45882 IF J(Z1, 1) = 0 THEN 45893
45883 LET V1 = J(Z1, 1)
45884 GOSUB 8200
45885 LET V1 = J(Z1, 2)
45886 GOSUB 8200
45887 LET Z$ = "wbin " & P9$ & " 3 mul"
45888 GOSUB 8050
45889 LET Z$ = "wbin " & P9$ & " 3 add"
45890 GOTO 8050
45893 RETURN
45894 REM ---- 45895: U0 = a new let local of type U1, named by a tmp after the cursor (V1 = U0)
45895 LET U2 = 0
45896 GOSUB 8100
45897 LET V1 = U0
45898 GOTO 8250
45899 REM ==== L6 with a field root (3.5.9, L6's 4g-2 extension) and the counted copies of R20 ====
45900 REM ---- 45900: lp3sel 15100's store target whose base B6 is a field chain (L6's field root, or
45901 REM the dol of an L17 target): the path below the idx Y5 (C7 = 2: a selection, H8 = 1); B is
45902 REM then read as the chain whose top is B6 (F6 = 1, Z5; lp1walk 9040)
45904 LET Z6 = Y5
45906 LET H8 = 0
45908 IF C7 <> 2 THEN 45912
45910 LET H8 = 1
45912 GOSUB 45300
45914 LET Z5 = B6
45916 LET F6 = 1
45918 LET V(2) = 1
45919 RETURN
45920 REM ---- 45920 (lp3sel 15500): with a field root, (2) for a set, then (3) the path's indices,
45921 REM before IX 1 of the selection (all indices in source order)
45922 IF F6 = 0 THEN 45929
45924 IF O6$ <> "set" THEN 45928
45926 GOSUB 45490
45928 GOTO 46090
45929 RETURN
45930 REM ---- 45930 (lp3sel 15600): with a field root, (2) for a compound store, then (4) the
45931 REM path's checks, before IX 2 of the selection on the field array
45932 IF F6 = 0 THEN 45929
45934 IF O6$ = "set" THEN 45938
45936 GOSUB 45490
45938 GOTO 46113
45939 REM ---- 45940 (lp1walk 9040): B with a field root, the chain Z5 read afresh; a dol (X8$) whose container is an element not addressed yet reads the local J(Y5,5), bound by step 4
45940 LET H2 = Z5
45941 GOSUB 45820
45942 IF Q9 <> 0 THEN 45840
45943 IF LEN(X8$) = 0 THEN 2900
45944 IF J(Y5, 5) > 0 THEN 45949
45945 LET U1 = H(Z5, 2)
45946 LET U2 = 0
45947 GOSUB 8100
45948 LET J(Y5, 5) = U0
45949 LET V1 = J(Y5, 5)
45950 LET S4 = U(V1, 1)
45951 LET L8 = S4
45952 GOTO 8200
45955 REM ---- 45960 (lp3sel 16184): L6 (1)'s copy of the target's root into a new home; of counted
45956 REM elements (str, a struct holding counts) R20's mcpy with the element count ci n
45960 LET S$ = "= y,anew P " & STR$(V6) & " 0 0,= v,C " & STR$(B5) & ",= T,D v,D y,L T,mcpy P"
45962 IF C(E5, 3) = 0 THEN 45966
45964 LET S$ = "= y,anew P " & STR$(V6) & " 0 0,= v,D v,D y,C " & STR$(T(V6, 0) * T(V6, 4)) & ",mcpy P"
45966 RETURN
45967 REM ---- 45970: S$ & Q5$, the copy into the address scripts Q7$ (destination, source) of the
45968 REM bytes of the fixed-size Y7 (a tmp named Q8$), or of counted elements E5 (R20) its element
45969 REM count ci n, then U3$
45970 LET Q3$ = "C " & STR$(T(Y7, 0) * T(Y7, 4))
45971 IF C(E5, 3) > 0 THEN 45974
45972 LET Q5$ = Q5$ & ",C " & STR$(B5) & ",= " & Q8$
45973 LET Q3$ = "L " & Q8$
45974 LET S$ = S$ & Q5$ & "," & Q7$ & "," & Q3$ & ",mcpy P" & U3$
45975 RETURN
45979 REM ---- 45980: L10 dyn (lp4ew 20545, lp6tup 30456): the copy of the fixed S into the new A
45980 LET Q5$ = ",D A,= D"
45981 LET Q7$ = "L D,D S"
45982 LET Q8$ = "K"
45983 LET U3$ = ",L A,]"
45984 GOTO 45970
45985 REM ---- 45986: L10 fix (lp4ew 20562, lp6tup 30475): the copy of A into the new home V
45986 LET Q5$ = ",anew P %0 0 0,= V,D A,= D"
45987 LET Q7$ = "D V,L D"
45988 LET Q8$ = "K"
45989 LET U3$ = ",L V,]"
45990 GOTO 45970
45991 REM ---- 45992: L10, a fixed-size .flat, .col or .row materialized (lp4ew 20664)
45992 LET S$ = ""
45993 LET Q5$ = "anew P %0 0 0,= V,D V,= D,D A,= S"
45994 LET Q7$ = "L D,L S"
45995 LET Q8$ = "B"
45996 LET U3$ = ",L V,]"
45997 GOTO 45970
46000 REM ---- 46000: the end of an L6 block (lp3sel 16196, 16364): closed, field mode off
46002 GOSUB 9000
46004 LET F6 = 0
46006 RETURN
46010 REM ---- 46010, 46020 (lp3sel 16344, 16350): the L7 of a compound selection store reads
46011 REM B as a name of its own: field mode off around it
46012 LET N4 = 2
46014 LET F3 = F6
46016 LET F6 = 0
46018 RETURN
46020 LET F6 = F3
46022 LET K8 = 0
46024 RETURN
46026 REM ==== a dol in the indices of an idx whose container is an element (J(x,5) > 0): from the
46027 REM first such idx Y2 on, each idx's indices are evaluated in step 4, right after its array's
46028 REM tmp Bk (that local), then checked; the indices before stay step 3's (left to right)
46030 LET Z9 = R9
46031 LET S0 = 0
46032 LET Y2 = 0
46033 RETURN
46035 LET Z9 = R9
46036 LET Y3 = 0
46037 RETURN
46038 REM ---- 46040 (step 3): the index rows from the idx Z9 on (after the last index tmp C9, up to
46039 REM the tail) cut off into S0
46040 LET Y2 = Z9
46041 LET S0 = O(C9, 0)
46042 IF S0 = 0 THEN 2900
46043 LET O(C9, 0) = 0
46044 LET O9 = C9
46045 RETURN
46048 REM ---- 46050 (step 4): V1 = the tmp of the array of idx Z1 (base H1): while rows are cut off,
46049 REM the local of its dol (J(Z1,5)), else a new one
46050 LET U1 = H(H1, 2)
46051 IF S0 = 0 THEN 45895
46052 IF J(Z1, 5) = 0 THEN 45895
46053 LET V1 = J(Z1, 5)
46054 GOTO 8250
46058 REM ---- 46060 (step 4): from Y2 on, the cut rows of idx Z1's indices put back at the tail, each
46059 REM index named by a tmp (J(Z1,i)); the cursor at the tail
46060 IF Z1 <> Y2 THEN 46062
46061 LET Y3 = 1
46062 IF Y3 = 0 THEN 46089
46063 IF S0 = 0 THEN 46089
46064 LET G2 = H(H1, 4)
46065 IF H(G2, 4) = 0 THEN 46068
46066 LET G2 = H(G2, 4)
46067 GOTO 46065
46068 LET G3 = H(G2, 8)
46069 LET O(O9, 0) = S0
46070 LET S0 = O(G3, 0)
46071 LET O(G3, 0) = 0
46072 LET O9 = G3
46073 LET X5 = H(H1, 4)
46074 LET I1 = 0
46075 LET C9 = H(X5, 8)
46076 LET U1 = 3
46077 GOSUB 45895
46078 LET J(Z1, I1) = U0
46079 LET I1 = I1 + 1
46080 LET X5 = H(X5, 4)
46081 IF X5 > 0 THEN 46075
46082 LET C9 = O9
46089 RETURN
46090 REM ---- 46090 (45920): L6's path indices; with rows cut off, then the path's checks (step 4,
46091 REM the deferred indices among them), the selection's tmp B (its dol's local) and its index
46092 REM rows back at the tail, before IX 1
46093 GOSUB 45600
46094 IF S0 = 0 THEN 46111
46095 LET C9 = O9
46096 GOSUB 45620
46097 IF S0 = 0 THEN 46109
46098 IF J(Z6, 5) = 0 THEN 46105
46099 LET Z9 = Z6
46100 GOSUB 45390
46101 LET H2 = H1
46102 GOSUB 45840
46103 LET V1 = J(Z6, 5)
46104 GOSUB 8250
46105 LET O(O9, 0) = S0
46106 IF O(O9, 0) = 0 THEN 46108
46107 LET O9 = O(O9, 0)
46108 IF O(O9, 0) > 0 THEN 46107
46109 LET S0 = 0
46110 LET C9 = O9
46111 RETURN
46112 REM ---- 46113 (45930): the path's checks before IX 2, unless 46090 made them for a set
46113 IF O6$ <> "set" THEN 45620
46114 IF Y2 = 0 THEN 45620
46115 RETURN
46118 REM ---- 46120 (L17, op): (3), and with rows cut off, step 4 before the xblk (the deferred
46119 REM indices are evaluated there; the checks are repeated after it)
46120 GOSUB 45570
46121 IF S0 = 0 THEN 46123
46122 GOSUB 45620
46123 RETURN
