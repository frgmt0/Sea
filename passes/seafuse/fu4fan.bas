30000 REM ====================================================================================
30002 REM seafuse part 4 (lines 30000-39999): the fusion analysis (DESIGN 2.12.2, 2.12.4; Decisions
30004 REM 95, 96, 111; L-ei, L-em, L-en, L-er, L-es, L-fe), run once before the walk (fu1walk). Over
30006 REM every node X (the table Y of Decision 112 (1), one column per item): Y(X,0) its class (0
30008 REM not fusible, 1 a quiet fusible node, 2 a failing one); Y(X,2) the root of the element-wise
30010 REM tree it belongs to (itself for a root; -X a barrier root, never fused, F1 (2)); Y(X,7) the
30012 REM root of the tree it is a leaf of, Y(X,4) its leaf kind (1 a scalar, 2 a whole array, 3 a
30014 REM folded view, 4 a folded selection S R A V, 5 a read of a group's own value, 6 a mask
30016 REM selection, 7 an argument of a uniform parameter), Y(X,5) the view's code (1 .T 2 .flat 3
30018 REM .col 4 .row) or the group statement a kind-5 leaf reads; of a root Y(X,5) its fusible
30020 REM nodes and Y(X,6) its folded leaves; of a folded idx or view Y(X,6) the local of its base
30022 REM B (made at the first need); Y(X,1) the role in the walk (1 a fused node or folded leaf,
30024 REM not written; 2 the root of a tree fused in place, F1 at it; 3 a group statement or its
30026 REM target, not written; 4 a folded index's rng or all, a target's root lv; 5 a dol a folded
30028 REM idx claims, its extent written; 6 the last statement of a unit, F1 (3) or F2 at it; 7 a
30030 REM reduction fused standalone, F3 at it); Y(X,3) its slot while a unit is written (fu5f1).
30032 REM G(F,0) of a function: 1 quiet, 2 not (L-ei). Statements of the units: fu6grp.
30040 FOR X2 = 1 TO H0
30042 FOR X3 = 0 TO 7
30044 LET Y(X2, X3) = 0
30046 NEXT X3
30048 NEXT X2
30050 LET Q4 = 0
30052 FOR X3 = 1 TO H0
30054 GOSUB 30200
30056 LET Y(X3, 0) = C3
30058 NEXT X3
30060 REM ---- the trees, top down (a parent's id is above its children's): a quiet fusible node at
30062 REM an elemental position of a fused node joins its tree; any other fusible node is a root;
30064 REM a failing root stored by an L6 selection store is a barrier (F1 (2) (ii), L-en)
30066 FOR X3 = H0 TO 1 STEP -1
30068 IF Y(X3, 0) = 0 THEN 30090
30070 LET Y(X3, 2) = X3
30072 LET X6 = W(X3)
30074 IF X6 = 0 THEN 30084
30076 IF Y(X3, 0) <> 1 THEN 30084
30078 IF Y(X6, 2) <= 0 THEN 30084
30079 IF T(H(X6, 2), 1) = 0 THEN 30084
30080 GOSUB 30480
30082 IF C3 = 1 THEN 30088
30084 IF Y(X3, 0) = 2 THEN 30092
30086 GOTO 30090
30088 LET Y(X3, 2) = Y(X6, 2)
30090 NEXT X3
30091 GOTO 30100
30092 REM a failing root: the value of an asg set to a selection or .flat target is a barrier
30093 IF X6 = 0 THEN 30090
30094 IF H(X6, 1) <> 23 THEN 30090
30095 IF H(X6, 3) = X3 THEN 30090
30096 LET X7 = H(X6, 3)
30097 GOSUB 30460
30098 LET Y(X3, 2) = X3 - 2 * X3 * INT(C3 / 2)
30099 GOTO 30090
30100 REM ---- the leaves of every tree (a child of a tree node that is not in that tree) and their
30102 REM kinds; each root counts its fusible nodes (5) and folded leaves (6)
30104 FOR X3 = 1 TO H0
30106 IF Y(X3, 0) = 0 THEN 30112
30108 IF Y(X3, 2) <> X3 THEN 30112
30110 LET Y(X3, 5) = 0
30112 NEXT X3
30114 FOR X3 = 1 TO H0
30116 LET X6 = W(X3)
30118 IF Y(X3, 0) = 0 THEN 30124
30120 IF Y(X3, 2) <= 0 THEN 30124
30122 LET Y(Y(X3, 2), 5) = Y(Y(X3, 2), 5) + 1
30124 IF X6 = 0 THEN 30140
30126 IF Y(X6, 0) = 0 THEN 30140
30128 IF Y(X6, 2) <= 0 THEN 30140
30130 IF Y(X3, 0) = 0 THEN 30134
30132 IF Y(X3, 2) = Y(X6, 2) THEN 30140
30134 LET Y(X3, 7) = Y(X6, 2)
30136 GOSUB 30502
30138 IF ABS(Y(X3, 4) - 3.5) <> .5 THEN 30140
30139 LET Y(Y(X6, 2), 6) = Y(Y(X6, 2), 6) + 1
30140 NEXT X3
30141 GOSUB 55000
30142 FOR X3 = 1 TO H0
30144 IF Y(X3, 4) <> 6 THEN 30148
30145 IF Y(Y(X3, 7), 3) = 1 THEN 30148
30146 LET Y(X3, 4) = 2
30148 NEXT X3
30155 REM the slots (generation counters) cleared before the units
30156 FOR X3 = 1 TO H0
30157 LET Y(X3, 3) = 0
30158 NEXT X3
30159 GOSUB 50000
30160 REM ---- the units (fu6grp), then the trees fused in place: two fusible nodes, a folded leaf, a
30161 REM matrix space, or a unit's value (Decision 111); one vector node to L7 (L-em), an emap to L19
30162 FOR X3 = 1 TO H0
30163 IF Y(X3, 0) = 0 THEN 30170
30164 IF Y(X3, 2) <> X3 THEN 30170
30165 IF Y(X3, 1) > 0 THEN 30170
30166 IF Y(X3, 5) + Y(X3, 6) > 1 THEN 30174
30167 IF T(H(X3, 2), 1) <> 2 THEN 30170
30168 GOTO 30890
30170 NEXT X3
30172 RETURN
30174 IF T(H(X3, 2), 1) > 0 THEN 30168
30175 GOTO 30170
30176 REM ---- an emap of k >= 2 results (a ttuple), the value of a tbind (F2 (1), F5): every component an
30177 REM array of bool i64 f64 elements, else 0; its arguments are leaves (30079)
30178 IF H(X3, 2) <= 9 THEN 30298
30179 IF T(H(X3, 2), 1) > 0 THEN 30204
30180 IF H(W(X3), 1) <> 21 THEN 30298
30181 LET Y6 = H(X3, 2)
30182 GOSUB 20955
30183 LET L5 = VAL(F9$)
30184 FOR W4 = 1 TO L5
30185 GOSUB 20966
30186 IF U1 <= 9 THEN 30298
30187 IF T(U1, 1) = 0 THEN 30298
30188 IF ABS(T(U1, 2) - 3) > 1 THEN 30298
30189 NEXT W4
30190 GOTO 30280
30195 REM ---- 30200: C3 = the class of node X3 (2.12.2 "Quiet and failing"): a bin un cvt powk, an
30196 REM elemental lib or where, or an emap (k = 1; k >= 2: 30176) of an array type with bool i64 f64 elements,
30197 REM every operand's element type bool i64 f64 (an emap's: 20900); 1 quiet, 2 failing, else 0
30200 LET C3 = 0
30202 LET K2 = H(X3, 1)
30203 IF K2 = 64 THEN 30176
30204 IF H(X3, 2) <= 9 THEN 30298
30206 IF T(H(X3, 2), 1) = 0 THEN 30298
30208 LET E6 = T(H(X3, 2), 2)
30210 IF ABS(E6 - 3) > 1 THEN 30298
30212 IF K2 = 64 THEN 30280
30214 IF ABS(K2 - 7.5) > 1.5 THEN 30218
30216 GOTO 30220
30218 IF K2 <> 12 THEN 30298
30220 REM every operand of bool i64 f64 (elements), one of them an array
30222 LET C4 = 0
30224 LET X6 = H(X3, 3)
30226 IF X6 = 0 THEN 30240
30228 LET E7 = H(X6, 2)
30230 IF E7 <= 9 THEN 30236
30232 IF T(E7, 1) = 0 THEN 30298
30234 LET C4 = 1
30235 LET E7 = T(E7, 2)
30236 IF ABS(E7 - 3) > 1 THEN 30298
30237 LET X6 = H(X6, 4)
30238 GOTO 30226
30240 IF C4 = 0 THEN 30298
30242 LET R2 = H(X3, 6)
30244 LET F9 = 4
30246 GOSUB 8440
30248 LET C3 = 1
30250 ON K2 - 5 GOTO 30252, 30256, 30260, 30254, 30298, 30298, 30264
30252 IF E6 = 4 THEN 30298
30253 GOTO 30295
30254 GOTO 30252
30256 IF F9$ = "not" THEN 30298
30258 GOTO 30252
30260 IF POS("|matmul|cat|", "|" & F9$ & "|") > 0 THEN 30297
30262 IF POS("|add|sub|mul|div|mod|pow|", "|" & F9$ & "|") > 0 THEN 30252
30263 GOTO 30298
30264 IF POS("|where|isnan|sign|sqrt|floor|ceil|trunc|round|log|exp|sin|cos|pow|hypot|f64|", "|" & F9$ & "|") > 0 THEN 30298
30266 IF F9$ <> "min" THEN 30270
30267 IF H(H(X3, 3), 4) > 0 THEN 30298
30268 GOTO 30297
30270 IF F9$ <> "max" THEN 30272
30271 GOTO 30267
30272 IF F9$ = "abs" THEN 30252
30274 IF POS("|i64|idiv|sub2ind|", "|" & F9$ & "|") > 0 THEN 30295
30276 GOTO 30297
30280 REM an emap: its callee validated (H(X3,5)); quiet when the callee's body is (L-ei)
30282 LET X9 = X
30284 LET X = X3
30286 GOSUB 20900
30288 LET X = X9
30290 LET C3 = 1
30292 IF Q4 > 0 THEN 30294
30293 GOSUB 30700
30294 IF G(H(X3, 5), 0) = 1 THEN 30298
30295 LET C3 = 2
30296 GOTO 30298
30297 LET C3 = 0
30298 RETURN
30455 REM ---- 30460: C3 = the kind of the store target X7 (its node): 1 a whole variable (an lv), 2
30456 REM an L6 target (an idx with an index that is not a scalar, or a .flat base), 0 another
30460 LET C3 = 0
30462 IF H(X7, 1) <> 5 THEN 30464
30463 LET C3 = 1
30464 IF H(X7, 1) <> 39 THEN 30476
30466 IF H(H(X7, 3), 1) <> 45 THEN 30468
30467 LET C3 = 2
30468 LET X8 = H(H(X7, 3), 4)
30470 IF X8 = 0 THEN 30476
30472 IF H(X8, 2) = 3 THEN 30474
30473 LET C3 = 2
30474 LET X8 = H(X8, 4)
30475 GOTO 30470
30476 RETURN
30477 REM ---- 30480: C3 = 1 if node X3 stands at an elemental position of its parent X6 (any operand of
30478 REM a bin un cvt powk lib; of an emap an argument whose type is not its parameter's, 20900)
30480 LET C3 = 1
30482 IF H(X6, 1) <> 64 THEN 30498
30484 LET X7 = H(X6, 3)
30486 LET C4 = 1
30488 IF X7 = X3 THEN 30494
30490 LET X7 = H(X7, 4)
30491 LET C4 = C4 + 1
30492 GOTO 30488
30494 IF H(X3, 2) <> A(G(H(X6, 5), 1) + C4) THEN 30498
30496 LET C3 = 0
30498 RETURN
30499 REM ---- 30500: Y(X3,4) = the kind of the leaf X3 of the tree of its parent X6 (Y(X3,5) a view's code)
30502 LET Y(X3, 4) = 7
30504 GOSUB 30480
30506 IF C3 = 0 THEN 30598
30508 LET Y(X3, 4) = 1
30510 IF H(X3, 2) <= 9 THEN 30598
30512 IF T(H(X3, 2), 1) = 0 THEN 30598
30514 LET Y(X3, 4) = 2
30516 LET X8 = H(X3, 3)
30518 IF H(X3, 1) = 45 THEN 30530
30520 IF H(X3, 1) = 39 THEN 30550
30522 RETURN
30529 REM a view of an operand that is not a view: .T and .flat of a matrix, .col and .row of a vector
30530 IF H(X8, 1) = 45 THEN 30598
30532 IF H(X8, 2) <= 9 THEN 30598
30534 LET R2 = H(X3, 6)
30536 LET F9 = 4
30538 GOSUB 8440
30540 LET C4 = (POS("|T   |flat|col |row ", "|" & F9$) - 1) / 5 + 1
30542 IF T(H(X8, 2), 1) <> 2 - INT(C4 / 3) THEN 30598
30544 LET Y(X3, 4) = 3
30546 LET Y(X3, 5) = C4
30548 RETURN
30549 REM an idx of a base that is not a view: its indices S R A V (4), with an M or MM (6)
30550 IF H(X8, 1) = 45 THEN 30598
30552 LET C4 = 4
30554 LET X8 = H(X8, 4)
30556 IF X8 = 0 THEN 30574
30558 IF H(X8, 1) = 16 THEN 30554
30560 IF H(X8, 1) = 46 THEN 30554
30562 LET E7 = H(X8, 2)
30564 IF E7 = 3 THEN 30554
30566 IF E7 <= 9 THEN 30598
30568 IF T(E7, 2) = 3 THEN 30554
30570 IF T(E7, 2) <> 2 THEN 30598
30572 LET C4 = 6
30573 GOTO 30554
30574 LET Y(X3, 4) = C4
30598 RETURN
30599 REM ---- 30600: the roles of tree X3 fused in place: its nodes and folded leaves not written (1), the rng and all of a folded idx (4), the dols it claims (5)
30600 LET X6 = X3
30602 GOSUB 30660
30604 FOR X8 = X7 TO X3 - 1
30606 IF Y(X8, 0) = 0 THEN 30610
30608 IF Y(X8, 2) <> X3 THEN 30610
30609 LET Y(X8, 1) = 1
30610 IF Y(X8, 7) <> X3 THEN 30616
30612 IF ABS(Y(X8, 4) - 3.5) <> .5 THEN 30616
30614 GOSUB 30640
30616 NEXT X8
30618 RETURN
30635 REM ---- 30640: the folded leaf X8 not written (1); its rng and all indices (4); its dols (5)
30640 LET Y(X8, 1) = 1
30642 IF Y(X8, 4) = 3 THEN 30658
30644 LET X9 = H(H(X8, 3), 4)
30646 IF X9 = 0 THEN 30652
30648 IF ABS(H(X9, 1) - 31) <> 15 THEN 30650
30649 LET Y(X9, 1) = 4
30650 LET X9 = H(X9, 4)
30651 GOTO 30646
30652 LET X6 = X8
30653 GOSUB 30660
30654 FOR X9 = X7 TO X8
30655 IF H(X9, 1) <> 40 THEN 30657
30656 GOSUB 30680
30657 NEXT X9
30658 RETURN
30659 REM ---- 30660: X7 = the first node of the subtree of X6 (its leftmost descendant)
30660 LET X7 = X6
30662 IF H(X7, 3) = 0 THEN 30666
30664 LET X7 = H(X7, 3)
30665 GOTO 30662
30666 RETURN
30675 REM ---- 30680: the dol X9 is claimed by the innermost idx whose indices hold it; by X8: role 5
30680 LET C5 = X9
30682 LET C6 = W(C5)
30684 IF C6 = 0 THEN 30698
30686 IF H(C6, 1) <> 39 THEN 30694
30688 IF H(C6, 3) = C5 THEN 30694
30690 IF C6 <> X8 THEN 30692
30691 LET Y(X9, 1) = 5
30692 RETURN
30694 LET C5 = C6
30696 GOTO 30682
30698 RETURN
30699 REM ---- 30700: G(F,0) of every function (L-ei): 1 quiet (2.12.2 by element type, no index, loop, error, str; quiet callees), else 2
30700 LET Q4 = 1
30702 FOR C5 = 1 TO G0
30704 LET G(C5, 0) = 1
30706 LET R2 = G(C5, 6)
30708 LET R2 = R2 + 1
30710 LET K2 = R(P(R2, 0), 0)
30712 IF K2 = 36 THEN 30724
30714 IF ABS(K2 - 34.5) < 1 THEN 30708
30716 LET X6 = P(R2, 1)
30718 GOSUB 30750
30720 IF C4 = 1 THEN 30722
30721 LET G(C5, 0) = 2
30722 GOTO 30708
30724 NEXT C5
30726 REM calls: a callee not quiet makes the caller not quiet, until nothing changes
30728 LET C6 = 0
30730 FOR C5 = 1 TO G0
30732 IF G(C5, 0) = 2 THEN 30745
30734 LET R2 = G(C5, 6)
30736 LET R2 = R2 + 1
30737 LET K2 = R(P(R2, 0), 0)
30738 IF K2 = 36 THEN 30745
30739 IF K2 <> 10 THEN 30736
30740 LET F9 = 5
30741 GOSUB 8440
30742 IF G(VAL(F9$), 0) = 1 THEN 30736
30743 LET G(C5, 0) = 2
30744 LET C6 = 1
30745 NEXT C5
30746 IF C6 = 1 THEN 30728
30748 RETURN
30749 REM ---- 30750: C4 = 1 if the node X6 (record R2, kind K2) of a body of C5 is quiet by its kind
30750 LET C4 = 1
30752 IF POS("|1|2|3|5|17|18|19|20|21|22|24|25|30|31|32|56|", "|" & STR$(K2) & "|") > 0 THEN 30798
30754 LET F9 = 4
30756 IF K2 > 12 THEN 30762
30758 IF K2 < 6 THEN 30762
30760 GOSUB 8440
30762 IF K2 = 6 THEN 30793
30764 IF K2 = 9 THEN 30793
30766 IF K2 <> 7 THEN 30770
30768 IF F9$ = "not" THEN 30798
30769 GOTO 30793
30770 IF K2 <> 8 THEN 30776
30772 IF POS("|add|sub|mul|div|mod|pow|", "|" & F9$ & "|") > 0 THEN 30793
30773 IF POS("|matmul|cat|", "|" & F9$ & "|") > 0 THEN 30797
30774 IF H(H(X6, 3), 2) = 5 THEN 30797
30775 GOTO 30798
30776 IF K2 <> 10 THEN 30781
30777 LET F9 = 5
30778 GOSUB 8440
30779 IF VAL(F9$) = C5 THEN 30797
30780 GOTO 30798
30781 IF K2 <> 23 THEN 30787
30782 LET F9 = 3
30783 GOSUB 8440
30784 IF F9$ = "set" THEN 30798
30785 IF H(H(X6, 3), 2) = 4 THEN 30798
30786 GOTO 30797
30787 IF K2 <> 12 THEN 30797
30788 IF POS("|isnan|sign|sqrt|floor|ceil|trunc|round|log|exp|sin|cos|pow|hypot|f64|min|max|", "|" & F9$ & "|") > 0 THEN 30798
30789 IF F9$ = "where" THEN 30796
30790 IF F9$ <> "abs" THEN 30797
30793 IF H(X6, 2) = 4 THEN 30798
30794 GOTO 30797
30796 IF H(X6, 2) <> 5 THEN 30798
30797 LET C4 = 0
30798 RETURN
30799 REM ---- 30800: a node of the walk with a role: 1, 3, 4 not written; 2 F1 (fu5f1); 5 a dol
30800 ON Y(X, 1) GOTO 5188, 40050, 5188, 5188, 30820, 50100, 55100, 56400
30819 REM a dol a folded idx claims: lv of its base B (made at the first need) at P, ext of it at the dol
30820 LET C5 = X
30821 GOSUB 30908
30822 LET C6 = W(C5)
30824 IF H(C6, 1) <> 39 THEN 30828
30826 IF H(C6, 3) <> C5 THEN 30832
30828 LET C5 = C6
30830 GOTO 30822
30832 LET X8 = C6
30834 GOSUB 40950
30836 GOSUB 40925
30838 LET R2 = C6
30840 GOSUB 8400
30842 LET Z$ = "lv " & P9$ & " " & STR$(H(H(X8, 3), 2)) & " @" & STR$(Y(X8, 6))
30844 GOSUB 8050
30846 LET R2 = H(X, 6)
30848 GOSUB 8400
30850 LET F9 = 4
30852 GOSUB 8440
30854 LET Z$ = "ext " & P9$ & " 3 " & F9$
30856 GOSUB 8050
30858 GOTO 5188
30859 REM ---- 30860: I3 = the slots (fu5f1 40900) of the tree whose root is X9 (30860), X6 (30862) or X3 (30864); 30870: I3 += those of the root I5: a leaf
30860 LET I5 = X9
30861 GOTO 30866
30862 LET I5 = X6
30863 GOTO 30866
30864 LET I5 = X3
30866 LET I3 = 0
30868 GOSUB 30870
30869 RETURN
30870 REM 1 (a selection 3, its indices'), a fusible node 1; a leaf root 3. A unit has the slots 200 - 1386: a tree, unit or concatenation over 1180 is not fused (L-el, 2.12.3)
30871 IF Y(I5, 0) <> 0 THEN 30874
30872 LET I3 = I3 + 3
30873 RETURN
30874 LET I4 = I5
30875 IF H(I4, 3) = 0 THEN 30878
30876 LET I4 = H(I4, 3)
30877 GOTO 30875
30878 FOR I2 = I4 TO I5
30880 IF Y(I2, 7) <> I5 THEN 30884
30881 LET I3 = I3 + 1
30882 IF Y(I2, 4) <> 4 THEN 30884
30883 LET I3 = I3 + 2
30884 IF Y(I2, 0) = 0 THEN 30888
30886 IF Y(I2, 2) <> I5 THEN 30888
30887 LET I3 = I3 + 1
30888 NEXT I2
30889 RETURN
30890 REM ---- (30168) the tree X3 fused in place (role 2) when its slots fit (30864) and it is not denied (30900)
30891 GOSUB 30864
30892 IF I3 > 1180 THEN 30170
30893 GOSUB 30900
30894 IF I6 = 1 THEN 30170
30895 LET Y(X3, 1) = 2
30896 GOSUB 30600
30897 GOTO 30170
30899 REM ---- 30900: I6 = 1 when the fusion of node I5 is denied: I5 is O2 or later (a limit passed inside a fusion, fu0main 2940)
30900 LET I6 = 0
30902 IF O2 = 0 THEN 30904
30903 IF I5 >= O2 THEN 30905
30904 RETURN
30905 LET I6 = 1
30906 RETURN
30907 REM ---- 30908: I9 = the fusion the node X (I5: 30910) belongs to, by its innermost ancestor with a role: 2, 7 or 8 that node, 3 or 6 its unit's first statement (Y(.,2)); 0 none
30908 LET I5 = X
30910 LET I9 = 0
30911 LET I4 = W(I5)
30912 IF I4 = 0 THEN 30922
30913 IF ABS(Y(I4, 1) - 4.5) = 1.5 THEN 30920
30914 IF Y(I4, 1) = 2 THEN 30921
30915 IF Y(I4, 1) >= 7 THEN 30921
30916 LET I5 = I4
30917 GOTO 30911
30920 LET I4 = Y(I4, 2)
30921 LET I9 = I4
30922 RETURN
40053 LET I9 = X
