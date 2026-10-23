15000 REM ====================================================================================
15002 REM sealoop part 3 (lines 15000-19999): selections (DESIGN 3.5.9 L5, L6, the index
15004 REM preparation IX 1-4, folded views). The indices of the idx being rewritten are the slots
15006 REM 11 ... 10 + N3 of the script variables (lp1walk 9000), each holding: x its kind (1 S a
15008 REM scalar, 2 R a range, 3 A :, 4 V an index vector, 5 M a mask, 6 MM a matrix mask), j its
15010 REM dimension, u its node, and the locals of IX: I (S), a b c l e (R: lo hi st, rcnt's l e),
15012 REM W (V), M (M, MM), X the extent (MM: X and Y), n (NW, NM, NN), N the kept extent, w the
15014 REM data of W or M, q the position. Globals: B the base (a tmp, or -lid of a store's root
15016 REM variable, read afresh at each use), V0 its folded view (0 none 1 .T 2 .flat 3 .col 4 .row).
15018 REM ====================================================================================
15020 REM ---- 15030: C7 = what becomes of idx Y5: 0 copied (rule 18), 1 L5 (a selection or a view
15022 REM base), 2 the target of an L6 store (of an asg, or of an L11 tasg: not written itself), 3
15023 REM the target of an L17 store (a str element by scalar indices of an asg or a tasg; 4g-1)
15030 LET C7 = 0
15031 LET X5 = H(Y5, 3)
15032 IF H(X5, 1) = 45 THEN 15040
15033 LET X5 = H(X5, 4)
15034 IF X5 = 0 THEN 15080
15035 IF H(X5, 1) = 16 THEN 15040
15036 IF H(X5, 1) = 46 THEN 15040
15037 IF H(X5, 2) <= 9 THEN 15033
15040 LET C7 = 1
15041 LET X5 = W(Y5)
15042 IF H(X5, 1) <> 23 THEN 15045
15043 IF H(X5, 3) = Y5 THEN 15048
15044 RETURN
15045 IF H(X5, 1) <> 24 THEN 15049
15046 LET X5 = H(X5, 3)
15047 IF H(X5, 4) > 0 THEN 15052
15048 LET C7 = 2
15049 RETURN
15050 REM a tasg's target: L6 only in L11's or L12's statements (copied otherwise)
15052 LET X5 = H(X5, 4)
15053 IF H(X5, 4) > 0 THEN 15052
15054 LET O5 = W(Y5)
15055 GOSUB 30890
15056 LET C7 = 2 * Y8
15057 RETURN
15058 REM ---- 15060: of the L5 idx Y5: V0 its folded view and B6 the node the base B names (the
15059 REM view's operand; a .T indexed by a whole-matrix mask is not folded: L10 made it a value)
15060 LET V0 = 0
15061 LET B6 = H(Y5, 3)
15062 IF H(B6, 1) <> 45 THEN 15076
15063 LET R2 = H(B6, 6)
15064 LET F9 = 4
15065 GOSUB 8440
15066 LET V0 = (POS("|T   |flat|col |row ", "|" & F9$) - 1) / 5 + 1
15067 IF V0 <> 1 THEN 15074
15068 LET X5 = H(B6, 4)
15069 IF H(X5, 4) > 0 THEN 15074
15070 IF H(X5, 2) <= 9 THEN 15074
15071 IF T(H(X5, 2), 1) <> 2 THEN 15074
15072 LET V0 = 0
15073 RETURN
15074 LET B6 = H(B6, 3)
15076 RETURN
15078 REM every index a scalar: L17's when the element type is str and Y5 is a target
15080 IF T(H(H(Y5, 3), 2), 2) <> 5 THEN 15049
15081 LET X5 = W(Y5)
15082 IF H(X5, 1) <> 23 THEN 15086
15083 IF H(X5, 3) <> Y5 THEN 15049
15084 LET C7 = 3
15085 RETURN
15086 IF H(X5, 1) <> 24 THEN 15049
15087 IF H(Y5, 4) > 0 THEN 15084
15088 RETURN
15095 REM ---- 15100: the global B of idx Y5 (C7 as 15030 gave it): L5 its base's tmp (made at the
15096 REM first need, its loc pos the idx's), V0, B6; a store's target -lid of its root, V0 0 or 2
15100 IF C7 > 1 THEN 15120
15102 GOSUB 15060
15104 IF H(Y5, 5) > 0 THEN 15114
15106 LET Q3 = R7
15108 LET R7 = H(Y5, 6)
15110 LET U1 = H(B6, 2)
15111 GOSUB 8100
15112 LET H(Y5, 5) = U0
15113 LET R7 = Q3
15114 LET V(2) = H(Y5, 5)
15116 RETURN
15120 LET V0 = 0
15122 LET B6 = H(Y5, 3)
15124 IF H(B6, 1) <> 45 THEN 15134
15126 LET R2 = H(B6, 6)
15128 LET F9 = 4
15129 GOSUB 8440
15130 IF F9$ <> "flat" THEN 2900
15131 LET V0 = 2
15132 LET B6 = H(B6, 3)
15134 IF H(B6, 1) <> 5 THEN 2900
15136 LET R2 = H(B6, 6)
15138 LET F9 = 4
15139 GOSUB 8440
15140 LET V(2) = -VAL(F9$)
15142 RETURN
15195 REM ---- 15200: S$ = the extent of dimension D7 of the base B (its folded view V0's: .T swaps,
15196 REM .flat rows * cols, .col (ext 0, 1), .row (1, ext 0)); Z9$ <> "": named by tmp Z9$
15200 IF V0 <> 2 THEN 15210
15202 LET S$ = "X B 0,X B 1,wbin P 3 mul"
15204 IF Z9$ = "" THEN 15230
15206 LET S$ = "X B 0,= r,X B 1,= s,L r,L s,wbin P 3 mul"
15208 GOTO 15228
15210 LET Q3 = D7
15212 IF V0 <> 1 THEN 15216
15214 LET Q3 = 1 - D7
15216 LET S$ = "X B " & STR$(Q3)
15218 IF V0 < 3 THEN 15226
15220 LET S$ = "X B 0"
15222 IF D7 = V0 - 3 THEN 15226
15224 LET S$ = "C 1"
15226 IF Z9$ = "" THEN 15230
15228 LET S$ = S$ & ",= " & Z9$
15230 RETURN
15295 REM ---- 15300: the indices of idx Y5 into the slots (N3 of them, N2 not scalars), checked
15296 REM against the rank of the base (or its view); a mask of a whole matrix is the only index
15300 LET N3 = 0
15301 LET N2 = 0
15302 LET X5 = H(H(Y5, 3), 4)
15304 IF X5 = 0 THEN 15344
15306 LET N3 = N3 + 1
15308 LET K8 = 10 + N3
15310 LET Q3 = 2
15312 IF H(X5, 1) = 16 THEN 15330
15314 LET Q3 = 3
15316 IF H(X5, 1) = 46 THEN 15330
15318 LET Q3 = 1
15320 LET Y6 = H(X5, 2)
15322 IF Y6 = 3 THEN 15330
15324 IF Y6 <= 9 THEN 2900
15325 LET Q3 = 3 + T(Y6, 1)
15326 IF T(Y6, 2) = 2 THEN 15329
15327 IF T(Y6, 1) = 1 THEN 15330
15328 GOTO 2900
15329 LET Q3 = Q3 + 1
15330 LET Q0 = 100 + 25 * K8
15332 LET V(Q0 + 15) = Q3
15334 LET V(Q0 + 5) = N3 - 1
15336 LET V(Q0 + 13) = X5
15337 IF Q3 = 1 THEN 15340
15338 LET N2 = N2 + 1
15340 LET X5 = H(X5, 4)
15342 GOTO 15304
15344 LET Y6 = H(H(Y5, 3), 2)
15346 IF Y6 <= 9 THEN 2900
15348 IF N3 = T(Y6, 1) THEN 15358
15350 IF N3 <> 1 THEN 2900
15352 IF T(Y6, 1) <> 2 THEN 2900
15354 IF V(390) <> 6 THEN 2900
15356 RETURN
15358 IF V(390) = 6 THEN 2900
15360 IF V(415) = 6 THEN 2900
15362 RETURN
15395 REM ==== L5 (rules 20, 28): the selection read, or the idx of a view base, X ===================
15400 LET Y5 = X
15402 LET R2 = H(X, 6)
15404 GOSUB 8400
15406 LET C7 = 1
15408 GOSUB 15100
15410 LET Q4 = 0
15412 GOSUB 15300
15414 LET V(54) = T(H(H(X, 3), 2), 2)
15416 LET V(58) = S(V(54))
15418 LET V(53) = H(X, 2)
15420 GOSUB 9115
15422 LET C9 = H(B6, 8)
15424 LET Z$ = "tmp " & P9$ & " @" & STR$(V(2))
15426 GOSUB 8050
15428 GOSUB 15500
15430 GOSUB 15600
15432 IF N2 = 0 THEN 15470
15434 GOSUB 15440
15436 LET S$ = "L R,]"
15438 GOTO 15476
15439 REM ---- 15440: IX 3, the result R (anew), DR DB, DW DM, O One, the nest reading B into R
15440 GOSUB 15700
15442 LET S$ = "L A,anew P %0 0 1,= R"
15444 IF K6 = 1 THEN 15448
15446 LET S$ = "L A,L H,anew P %0 0 2,= R"
15448 LET S$ = S$ & ",D R,= D,D B,= G"
15450 LET K8 = 0
15452 GOSUB 9000
15454 GOSUB 15750
15456 LET K8 = 0
15458 LET S$ = "C 0,B O,C 1,= U"
15460 GOSUB 9000
15462 GOSUB 15800
15464 LET S$ = "L G," & Q6$ & ",eld P %1 %5 0,L D,L O,est P %5 0,L O,L O,L U,wbin P 3 add,asg P set"
15466 GOSUB 9000
15468 GOTO 15850
15469 REM every index a scalar (a folded view): the element after IX 2
15470 GOSUB 15800
15474 LET S$ = "D B," & Q6$ & ",eld P %1 %5 0,]"
15476 LET K8 = 0
15478 GOSUB 9000
15480 LET N7 = N7 - 1
15482 GOTO 5180
15495 REM ---- 15500: IX 1, the indices evaluated: tmps after their subtrees (rcnt after a range's);
15496 REM a store (Q4 = 1) of an i64 target (E8) keeps a dynamic index vector by a bind, and on a
15497 REM fixed target (F8) copies an index vector that is its root variable (Decision 34)
15500 FOR K7 = 1 TO N3
15502 LET K8 = 10 + K7
15504 LET Q0 = 100 + 25 * K8
15506 LET X5 = V(Q0 + 13)
15508 ON V(Q0 + 15) GOTO 15510, 15514, 15596, 15570, 15590, 15590
15510 IF H(X5, 2) <> 3 THEN 2900
15512 LET S$ = "= I"
15513 GOTO 15592
15514 GOSUB 15530
15516 GOTO 15596
15520 REM ---- 15530: R of rng X5 (slot K8): tmp LO, tmp HI, tmp ST (or ci 1), rcnt at its position
15530 LET R6 = H(X5, 6)
15531 LET R2 = R6
15532 LET F9 = 2
15533 GOSUB 8440
15534 LET Q9$ = F9$
15535 LET X4 = H(X5, 3)
15536 IF H(X4, 2) <> 3 THEN 2900
15537 LET S$ = "= a"
15538 GOSUB 8900
15539 LET X4 = H(X4, 4)
15540 IF H(X4, 2) <> 3 THEN 2900
15541 LET S$ = "= b"
15542 GOSUB 8900
15543 LET S$ = "C 1,= c,"
15544 IF H(X4, 4) = 0 THEN 15550
15545 LET X4 = H(X4, 4)
15546 IF H(X4, 2) <> 3 THEN 2900
15547 LET S$ = "= c"
15548 GOSUB 8900
15549 LET S$ = ""
15550 LET R2 = R6
15551 LET F9 = 4
15552 GOSUB 8440
15553 LET S$ = S$ & "L a,L b,L c,R " & F9$ & " l e"
15554 GOTO 9000
15570 LET S$ = "= W"
15571 IF Q4 = 0 THEN 15592
15572 IF E8 <> 3 THEN 15592
15573 IF F8 = 1 THEN 15578
15574 IF T(H(X5, 2), 3) = 1 THEN 15592
15575 LET S$ = "B W"
15576 GOTO 15592
15578 IF H(X5, 1) <> 5 THEN 15592
15579 LET R2 = H(X5, 6)
15580 LET F9 = 4
15581 GOSUB 8440
15582 IF VAL(F9$) <> -V(2) THEN 15592
15583 LET Y7 = H(X5, 2)
15584 GOSUB 8700
15585 LET S$ = "= y,anew P " & STR$(Y7) & " 0 0,= W,C " & STR$(B5) & ",= T,D W,D y,L T,mcpy P"
15586 GOTO 15592
15590 LET S$ = "= M"
15592 LET X4 = X5
15594 GOSUB 8900
15596 NEXT K7
15598 RETURN
15599 REM ---- 15600: IX 2, the checks dimension by dimension (the extent X of each first)
15600 FOR K7 = 1 TO N3
15602 LET K8 = 10 + K7
15604 LET Q0 = 100 + 25 * K8
15606 LET D7 = V(Q0 + 5)
15608 LET Z9$ = "X"
15610 GOSUB 15200
15612 LET Q3 = V(Q0 + 15)
15614 IF Q3 <> 6 THEN 15622
15616 GOSUB 9000
15618 LET D7 = 1
15619 LET Z9$ = "Y"
15620 GOSUB 15200
15622 ON V(Q0 + 15) GOTO 15624, 15626, 15640, 15628, 15630, 15634
15624 LET S$ = S$ & ",L I,L X,chkb P %j"
15625 GOTO 15640
15626 LET S$ = S$ & ",L e,?,L a,L X,chkb P %j,L a,L l,L c,wbin P 3 mul,wbin P 3 add,L X,chkb P %j,)"
15627 GOTO 15640
15628 LET S$ = S$ & ",X W 0,= n,D W,= w,( n k,L w,L k,eld P 3 %3 0,L X,chkb P %j,)"
15629 GOTO 15640
15630 LET S$ = S$ & ",X M 0,= n,L X,L n,bin P 2 ne,= S,ci P 3 %6,= Z,L S,L X,L Z,L n,L Z"
15632 LET S$ = S$ & ",chk P SHAPE_MISMATCH 4"
15633 GOTO 15640
15634 LET S$ = S$ & ",X M 0,= r,X M 1,= s,L X,L r,bin P 2 ne,= t,L Y,L s,bin P 2 ne,= k,L t,L k"
15636 LET S$ = S$ & ",bin P 2 bor,= S,L S,L X,L Y,L r,L s,chk P SHAPE_MISMATCH 4,L X,L Y,wbin P 3 mul,= n"
15640 GOSUB 9000
15642 NEXT K7
15644 RETURN
15695 REM ---- 15700: IX 3, the kept extents N in dimension order, also as the globals A and H (K6)
15700 LET K6 = 0
15702 FOR K7 = 1 TO N3
15704 LET K8 = 10 + K7
15706 LET Q0 = 100 + 25 * K8
15708 LET Q3 = V(Q0 + 15)
15710 IF Q3 = 1 THEN 15740
15712 ON Q3 - 1 GOTO 15714, 15718, 15722, 15726, 15730
15714 LET S$ = "C 1,= r,L l,L r,wbin P 3 add,= t,C 0,= s,L e,L t,L s,lib P 3 where 3,= N"
15716 GOTO 15734
15718 LET V(Q0 + 18) = V(Q0 + 20)
15720 GOTO 15736
15722 LET V(Q0 + 18) = V(Q0 + 8)
15724 GOTO 15736
15726 LET S$ = "C 0,B N,D M,= w,( X k,L N,L N,L w,L k,eld P 2 %2 0,wbin P 3 add,asg P set,)"
15728 GOTO 15734
15730 LET S$ = "C 0,B N,D M,= w,( n k,L N,L N,L w,L k,eld P 2 %2 0,wbin P 3 add,asg P set,)"
15734 GOSUB 9000
15736 LET K6 = K6 + 1
15738 LET V(7 * K6 - 6) = V(Q0 + 18)
15740 NEXT K7
15742 RETURN
15745 REM ---- 15750: the data of each index vector and mask, in dimension order (w)
15750 FOR K7 = 1 TO N3
15752 LET K8 = 10 + K7
15754 LET Q3 = V(100 + 25 * K8 + 15)
15756 IF Q3 < 4 THEN 15762
15758 LET S$ = "D W,= w"
15759 IF Q3 = 4 THEN 15761
15760 LET S$ = "D M,= w"
15761 GOSUB 9000
15762 NEXT K7
15764 RETURN
15795 REM ---- 15800: IX 4, the nest opened (dimension 1 outside); Q6$ the base element's position
15800 FOR K7 = N3 TO 1 STEP -1
15802 LET K8 = 10 + K7
15804 LET Q0 = 100 + 25 * K8
15806 ON V(Q0 + 15) GOTO 15810, 15814, 15816, 15818, 15820, 15822
15810 LET V(Q0 + 9) = V(Q0 + 16)
15812 GOTO 15826
15814 LET S$ = "[ e a l c q"
15815 GOTO 15824
15816 LET S$ = "( X q"
15817 GOTO 15824
15818 LET S$ = "( n k,L w,L k,eld P 3 %3 0,= q"
15819 GOTO 15824
15820 LET S$ = "( X q,L w,L q,eld P 2 %2 0,?"
15821 GOTO 15824
15822 LET S$ = "( n q,L w,L q,eld P 2 %2 0,?"
15824 GOSUB 9000
15826 NEXT K7
15828 REM the positions (K L) and extents (E F) of dimensions 0 and 1 as globals
15830 LET V(11) = V(384)
15832 LET V(12) = V(409)
15834 LET V(5) = V(395)
15836 LET V(6) = V(420)
15838 LET K8 = 0
15840 LET Q6$ = "L K"
15841 IF N3 = 1 THEN 15849
15842 LET Q6$ = "L K,L L,L E,wbin P 3 mul,wbin P 3 add"
15843 IF V0 = 0 THEN 15849
15844 LET Q6$ = "L L,L K,L F,wbin P 3 mul,wbin P 3 add"
15845 IF V0 = 1 THEN 15849
15846 LET Q6$ = "L K"
15847 IF V0 = 3 THEN 15849
15848 LET Q6$ = "L L"
15849 RETURN
15850 REM ---- 15850: the nest closed (dimension 0 first)
15852 FOR K7 = 1 TO N3
15854 LET Q3 = V(100 + 25 * (10 + K7) + 15)
15856 IF Q3 = 1 THEN 15862
15858 LET S$ = ")"
15859 IF Q3 < 5 THEN 15861
15860 LET S$ = "),)"
15861 GOSUB 9000
15862 NEXT K7
15864 RETURN
15995 REM ==== L6 (rules 21, 19, 15 (i)): asg X to a selection or a .flat target ===================
16000 LET X3 = H(X, 3)
16002 LET R2 = H(X, 6)
16004 GOSUB 8400
16006 LET F9 = 3
16008 GOSUB 8440
16010 LET O6$ = F9$
16012 LET P6 = H(X3, 0)
16014 LET V6 = H(H(X3, 4), 2)
16016 LET V5 = H(X3, 4)
16018 GOSUB 16100
16020 LET N7 = N7 - 1
16022 GOTO 5180
16095 REM ---- 16100: the store to target X3 (an idx; P6 the row before its rows), op O6$, the value
16096 REM V5 (0: a generated lv) of type V6, its rows after the target's; written at P9$
16100 LET Y5 = X3
16102 LET C7 = 2
16104 GOSUB 15100
16106 LET Q4 = 1
16108 LET Y7 = H(B6, 2)
16110 GOSUB 8700
16112 LET F8 = F5
16114 LET E8 = E5
16115 LET O7$ = O6$
16116 LET V(54) = E5
16118 LET V(58) = S(E5)
16119 IF E5 = 5 THEN 16420
16120 GOSUB 15300
16122 LET B7 = O(P6, 0)
16124 LET G7 = O(H(X3, 8), 0)
16126 LET G8 = O9
16128 LET G9 = H(X3, 8)
16130 IF G9 <> B7 THEN 16134
16132 LET G9 = P6
16134 REM the root's row is not written; the value's rows are cut off (set: put back in front)
16136 LET O(P6, 0) = O(B7, 0)
16138 LET O(G9, 0) = 0
16140 LET O9 = G9
16142 LET N7 = N7 - 1
16144 GOSUB 9115
16146 IF O6$ <> "set" THEN 16300
16148 LET O(G8, 0) = O(P6, 0)
16150 LET O(P6, 0) = G7
16152 IF O9 <> P6 THEN 16156
16154 LET O9 = G8
16156 REM (1) the value: a scalar tmp, a dynamic array held by a bind, a fixed one a tmp (a copy
16157 REM into a new home when it is the target's root variable)
16158 LET C9 = G8
16160 LET L8 = V6
16162 LET Y7 = V6
16164 GOSUB 8700
16166 LET S$ = "= v"
16168 IF R5 = 0 THEN 16182
16170 IF F5 = 1 THEN 16176
16172 LET S$ = "B v"
16174 GOTO 16182
16176 IF V5 = 0 THEN 16182
16177 IF H(V5, 1) <> 5 THEN 16182
16178 LET R2 = H(V5, 6)
16179 LET F9 = 4
16180 GOSUB 8440
16181 IF VAL(F9$) = -V(2) THEN 16184
16182 LET K8 = 0
16183 GOTO 16186
16184 LET S$ = "= y,anew P " & STR$(V6) & " 0 0,= v,C " & STR$(B5) & ",= T,D v,D y,L T,mcpy P"
16185 LET K8 = 0
16186 GOSUB 9000
16188 LET V7 = R5
16190 GOSUB 15500
16192 GOSUB 16200
16194 LET S$ = "}"
16196 GOTO 9000
16199 REM ---- 16200: steps 3-7 storing the value v (V7: its rank), and a .flat scalar store
16200 GOSUB 15600
16202 LET K8 = 0
16204 IF N2 > 0 THEN 16220
16206 GOSUB 16280
16208 LET K8 = 11
16210 LET S$ = "L v,D B,L I,est P %5 0"
16212 GOTO 9000
16220 IF V7 = 0 THEN 16240
16222 GOSUB 15700
16224 LET K8 = 0
16226 LET S$ = "X v 0,= T,L A,L T,bin P 2 ne,= S,ci P 3 %6,= Z,L S,L A,L Z,L T,L Z,chk P SHAPE_MISMATCH 4"
16228 IF K6 = 1 THEN 16234
16230 LET S$ = "X v 0,= m,X v 1,= o,L A,L m,bin P 2 ne,= p,L H,L o,bin P 2 ne,= z,L p,L z,bin P 2 bor,= S"
16232 LET S$ = S$ & ",L S,L A,L H,L m,L o,chk P SHAPE_MISMATCH 4"
16234 GOSUB 9000
16240 GOSUB 16280
16242 LET S$ = "D B,= D"
16244 IF V7 = 0 THEN 16248
16246 LET S$ = S$ & ",D v,= h"
16248 GOSUB 9000
16250 GOSUB 15750
16252 LET K8 = 0
16254 IF V7 = 0 THEN 16258
16256 LET S$ = "C 0,B O,C 1,= U"
16257 GOSUB 9000
16258 GOSUB 15800
16260 LET S$ = "L v,L D," & Q6$ & ",est P %5 0"
16262 IF V7 = 0 THEN 16266
16264 LET S$ = "L h,L O,eld P %1 %5 0,L D," & Q6$ & ",est P %5 0,L O,L O,L U,wbin P 3 add,asg P set"
16266 GOSUB 9000
16268 GOTO 15850
16275 REM ---- 16280: (5) cow (lv T) of a dynamic target
16280 IF F8 = 1 THEN 16288
16282 LET K8 = 0
16284 LET S$ = "L B,cow P"
16286 GOSUB 9000
16288 RETURN
16295 REM ---- 16300: a compound store: (2), then G = the selection (L5 into G0, or the folded read)
16296 REM op the value (L7), then steps 3-7 storing G; the value's rows come back after the read
16300 GOSUB 15500
16302 LET C9 = O9
16304 IF N2 > 0 THEN 16330
16305 IF E8 = 5 THEN 16400
16306 GOSUB 15600
16308 LET K8 = 11
16310 LET S$ = "D B,L I,eld P %1 %5 0,= y"
16312 GOSUB 9000
16314 GOSUB 16380
16316 LET S$ = "L y,L v,bin P %1 " & O6$ & ",= v"
16318 GOSUB 9000
16320 LET V7 = 0
16322 GOTO 16360
16330 GOSUB 9115
16331 LET V(53) = H(X3, 2)
16332 GOSUB 15600
16334 GOSUB 15440
16336 GOSUB 16380
16338 LET K8 = 1
16339 LET S$ = "L R,= a"
16340 GOSUB 9000
16341 LET K8 = 2
16342 LET S$ = "L v,= a"
16343 GOSUB 9000
16344 LET N4 = 2
16345 LET T6 = H(X3, 2)
16346 LET Z6$ = "bin " & P9$ & " " & STR$(E8) & " " & O7$
16347 LET V(473) = V(2)
16348 GOSUB 20150
16349 LET V(2) = V(473)
16350 LET K8 = 0
16352 LET S$ = "L Q,],B v"
16354 GOSUB 9000
16356 LET V7 = 1
16360 GOSUB 16200
16362 LET S$ = "}"
16364 GOTO 9000
16375 REM ---- 16380: the value's rows back at the tail (G7 .. G8), named by tmp v
16380 LET O(O9, 0) = G7
16382 LET O9 = G8
16384 LET C9 = O9
16386 LET L8 = V6
16388 LET K8 = 0
16390 LET S$ = "= v"
16392 GOTO 9000
16395 REM ---- 16400: a compound .flat store of a str element with a scalar index (4g-1, L6's str
16396 REM extension): tmp v = xblk { the folded read y (checks included), tmp v = the value, value
16397 REM bin cat (lv y) (lv v) }, so an owned value is released right after the operation; then
16398 REM the store of 16200
16400 GOSUB 9115
16402 GOSUB 15600
16404 LET K8 = 11
16406 LET S$ = "D B,L I,eld P %1 %5 0,= y"
16408 GOSUB 9000
16410 GOSUB 16380
16412 LET S$ = "L y,L v,bin P %1 " & O7$ & ",],= v"
16414 GOSUB 9000
16416 GOTO 16320
16418 REM ---- 16420: the operation of a compound store of str elements is cat (rule 32)
16420 LET O7$ = "cat"
16422 GOTO 16120
