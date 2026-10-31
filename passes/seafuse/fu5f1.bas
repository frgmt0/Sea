40000 REM ====================================================================================
40002 REM seafuse part 5 (lines 40000-49999): F1, the fusion of one element-wise tree (DESIGN
40004 REM 2.12.4 F1 with F4's folded views and selections and F5's emap nodes). The tree of root R8
40006 REM (its nodes and leaves in post-order are the ids from its first node to R8 with Y(.,2) = R8
40008 REM or Y(.,7) = R8): (1) the leaf and check phase (40100): each leaf a tmp right after its
40010 REM subtree (a folded leaf its base and IX 1, IX 2 at the idx's position), each node's checks
40012 REM as L7 (2) writes them, at the node's position, after its last operand (the extents of a
40014 REM leaf loaded at its node, a folded selection's kept extents by IX 3, an inner node's
40016 REM combined shape standing for it); (3) RES; (4) the data and the nest (40700): a vector
40018 REM loop(N; I), a matrix the plain copy (loop(NN; I), or mloop with a folded leaf) and the
40020 REM broadcast copy under if (tmp p, L-ep), the body F (40800) stored by est; (6) lv RES.
40022 REM Slots (fu1walk 9000, from 200; Y(X,3) a node's): a its tmp (of a folded leaf the base B),
40024 REM x its data, n or r c its extents (of a node its combined shape), s j (t) its strides, e u
40026 REM its element type and size, k its rank, Y 1 if fixed, l its leaf kind, q a view's code or
40028 REM a selection's index count; a selection's index d in the slot after it + d (q its kind 1 S
40030 REM 2 R 3 A 4 V, j its dimension, I, a b c l e, W, X its extent, N the kept one, n w the NW
40032 REM and DW of IX 2, x the DW of the nest). Globals: d the base B, G or R C the space (the
40034 REM shape so far in a node's checks), O ci 1, Z SHAPE_VEC (once per tree: Z7, Z8), Q RES, D
40036 REM DR, K L the loop locals I J, p the plain copy's test, m NN, h i g a folded read's s t X0.
40038 REM U$ the position P of the statement (R9 its record), Q9 the copy (1 vector, 2 plain
40040 REM linear, 3 plain mloop, 4 broadcast mloop). Entry 40050: the root X of a tree fused in
40042 REM place, an xblk at P in place of its subtree.
40050 LET R8 = X
40051 LET X8 = X
40052 GOSUB 40925
40054 LET R2 = H(X, 6)
40055 GOSUB 8400
40056 LET Q9$ = P9$
40057 LET R2 = C6
40058 GOSUB 8400
40059 LET U$ = P9$
40060 LET R9 = C6
40061 LET R7 = C6
40062 LET S0 = 199
40064 LET Z7 = 0
40066 LET Z8 = 0
40067 GOSUB 41260
40068 GOSUB 9115
40070 GOSUB 40100
40072 GOSUB 40600
40074 LET K8 = 0
40076 LET S$ = "L Q,]"
40078 GOSUB 9000
40080 LET N7 = N7 - 1
40082 GOTO 5190
40095 REM ---- 40100: (1) the leaf and check phase of tree R8, in post-order (D1)
40100 LET X6 = R8
40102 GOSUB 30660
40104 FOR D1 = X7 TO R8
40106 IF Y(D1, 7) <> R8 THEN 40110
40108 GOSUB 40200
40110 IF Y(D1, 0) = 0 THEN 40114
40111 IF Y(D1, 2) <> R8 THEN 40114
40112 GOSUB 40450
40114 NEXT D1
40116 RETURN
40195 REM ---- 40200: the leaf D1: its slot; a tmp after its subtree (at P), a view's base (at the
40196 REM view's position), a selection's base and IX 1, IX 2 (at the idx's, an rcnt at its rng's)
40200 LET D3 = D1
40202 GOSUB 40900
40204 LET V(Q0 + 7) = Y(D1, 4)
40206 LET P9$ = U$
40208 LET X4 = D1
40210 LET S$ = "= a"
40212 ON Y(D1, 4) GOTO 8900, 8900, 40220, 40240, 40214, 56000, 8900, 56050
40213 REM a kind-5 leaf: no tmp; the extents of the root of the statement it reads
40214 LET C5 = 100 + 25 * V(3000 + 20 * Y(D1, 5) + 11)
40215 LET V(Q0 + 8) = V(C5 + 8)
40216 LET V(Q0 + 10) = V(C5 + 10)
40217 LET V(Q0 + 3) = V(C5 + 3)
40218 GOTO 40298
40219 REM a view: tmp of its operand
40220 LET V(Q0 + 9) = Y(D1, 5)
40222 LET X4 = H(D1, 3)
40230 GOSUB 8900
40232 GOTO 40296
40239 REM a selection: tmp B (Y(D1,6), shared with the dols it claims), IX 1, IX 2
40240 LET X8 = D1
40242 GOSUB 40950
40244 LET R2 = H(D1, 6)
40246 GOSUB 8400
40248 LET Y8$ = P9$
40249 LET P9$ = U$
40250 LET V(Q0 + 1) = Y(D1, 6)
40252 LET V(30) = Y(D1, 6)
40254 LET C9 = H(H(D1, 3), 8)
40256 LET Z$ = "tmp " & P9$ & " @" & STR$(Y(D1, 6))
40258 GOSUB 8050
40260 LET D4 = 0
40262 LET X8 = H(H(D1, 3), 4)
40264 LET D4 = D4 + 1
40266 LET K8 = Y(D1, 3) + D4
40268 LET Q0 = 100 + 25 * K8
40270 LET V(Q0 + 5) = D4 - 1
40272 LET C5 = 4
40273 IF H(X8, 2) <> 3 THEN 40275
40274 LET C5 = 1
40275 IF H(X8, 1) <> 16 THEN 40277
40276 LET C5 = 2
40277 IF H(X8, 1) <> 46 THEN 40279
40278 LET C5 = 3
40279 GOSUB 41370
40280 GOSUB 40300
40282 LET X8 = H(X8, 4)
40284 IF X8 > 0 THEN 40264
40286 LET V(100 + 25 * Y(D1, 3) + 9) = D4
40287 LET Q9$ = Y8$
40288 FOR D4 = 1 TO V(100 + 25 * Y(D1, 3) + 9)
40290 LET K8 = Y(D1, 3) + D4
40292 GOSUB 40360
40294 NEXT D4
40296 LET P9$ = U$
40297 LET R7 = R9
40298 RETURN
40299 REM ---- 40300: IX 1 of the index X8 (slot K8): S tmp I, R tmp a b c and rcnt l e, V tmp W
40300 LET X4 = X8
40302 ON V(Q0 + 9) GOTO 40304, 40310, 40398, 40306, 40308, 40308
40304 LET S$ = "= I"
40305 GOTO 8900
40306 LET S$ = "= W"
40307 GOTO 8900
40308 LET S$ = "= M"
40309 GOTO 8900
40310 LET R6 = H(X8, 6)
40312 LET R2 = R6
40314 GOSUB 8400
40316 LET Q9$ = P9$
40317 LET P9$ = U$
40322 LET X4 = H(X8, 3)
40324 LET S$ = "= a"
40325 GOSUB 8900
40326 LET X4 = H(X4, 4)
40327 LET S$ = "= b"
40328 GOSUB 8900
40329 LET S$ = "C 1,= c,"
40330 IF H(X4, 4) = 0 THEN 40335
40331 LET X4 = H(X4, 4)
40332 LET S$ = "= c"
40333 GOSUB 8900
40334 LET S$ = ""
40335 LET R2 = R6
40336 LET F9 = 4
40337 GOSUB 8440
40338 LET S$ = S$ & "L a,L b,L c,R " & F9$ & " l e"
40339 GOTO 9000
40359 REM ---- 40360: IX 2 of the index of slot K8: the extent X of its dimension of B, its check
40360 LET Q0 = 100 + 25 * K8
40362 LET S$ = "X d " & STR$(V(Q0 + 5)) & ",= X"
40364 ON V(Q0 + 9) GOTO 40366, 40368, 40372, 40370, 41380, 41386
40366 LET S$ = S$ & ",L I,L X,chkb Q %j"
40367 GOTO 9000
40368 LET S$ = S$ & ",L e,?,L a,L X,chkb Q %j,L a,L l,L c,wbin P 3 mul,wbin P 3 add,L X,chkb Q %j,)"
40369 GOTO 9000
40370 LET S$ = S$ & ",X W 0,= n,D W,= w,( n k,L w,L k,eld P 3 %3 0,L X,chkb Q %j,)"
40372 GOTO 9000
40375 REM ---- 40380: the extents of the array leaf of slot K8 at its node: a whole array's, a view's
40376 REM (.T swapped, .flat rows * cols, .col (ext 0, 1), .row (1, ext 0)), a selection's kept ones
40377 REM (IX 3: R the count, A its X, V its NW) into n (one kept) or r c
40380 LET Q0 = 100 + 25 * K8
40382 ON V(Q0 + 7) GOTO 40398, 40384, 40388, 40400, 40398, 56070, 40398, 56070
40384 LET S$ = "X a 0,= n"
40385 IF V(Q0 + 6) = 1 THEN 9000
40386 LET S$ = "X a 0,= r,X a 1,= c"
40387 GOTO 9000
40388 ON V(Q0 + 9) GOTO 40389, 40391, 40393, 40395
40389 LET S$ = "X a 1,= r,X a 0,= c"
40390 GOTO 9000
40391 LET S$ = "X a 0,= r,X a 1,= c,L r,L c,wbin P 3 mul,= n"
40392 GOTO 9000
40393 LET S$ = "X a 0,= r,C 1,= c"
40394 GOTO 9000
40395 LET S$ = "C 1,= r,X a 0,= c"
40396 GOTO 9000
40398 RETURN
40399 REM a selection: IX 3 of each index (slot K8 + d), the kept extents in order into n r, c
40400 LET D7 = K8
40402 LET D6 = 0
40404 FOR D4 = 1 TO V(Q0 + 9)
40406 LET K8 = D7 + D4
40408 LET Q0 = 100 + 25 * K8
40410 ON V(Q0 + 9) GOTO 40430, 40412, 40416, 40418, 41390, 41390
40412 LET S$ = "C 1,= r,L l,L r,wbin P 3 add,= t,C 0,= s,L e,L t,L s,lib P 3 where 3,= N"
40414 GOSUB 9000
40415 GOTO 40420
40416 LET V(Q0 + 18) = V(Q0 + 20)
40417 GOTO 40420
40418 LET V(Q0 + 18) = V(Q0 + 8)
40420 LET D6 = D6 + 1
40422 IF D6 = 2 THEN 40428
40424 LET V(100 + 25 * D7 + 8) = V(Q0 + 18)
40426 LET V(100 + 25 * D7 + 10) = V(Q0 + 18)
40427 GOTO 40430
40428 LET V(100 + 25 * D7 + 3) = V(Q0 + 18)
40430 NEXT D4
40432 LET K8 = D7
40434 LET Q0 = 100 + 25 * K8
40436 RETURN
40445 REM ---- 40450: the node D1 (an inner node or the root): its slot; at its position, after its
40446 REM last operand: the extents of its array leaves (of a fixed node only the matrices'), then
40447 REM L7 (2)'s checks of a dynamic node, folded left to right from the first array operand (G,
40448 REM or R and C, the shape so far); its combined shape into n or r c (a fixed node that is not
40449 REM the root and whose parent is dynamic: its static extents, ci)
40450 LET D3 = D1
40452 GOSUB 40900
40454 LET D5 = K8
40456 LET R2 = H(D1, 6)
40458 GOSUB 8400
40459 LET Q9$ = P9$
40460 LET P9$ = U$
40461 LET R4 = V(Q0 + 6)
40462 LET F4 = V(Q0 + 21)
40464 LET K9 = 0
40465 GOSUB 41415
40466 LET X8 = H(D1, 3)
40468 IF X8 = 0 THEN 40520
40470 IF Y(X8, 4) = 1 THEN 40516
40472 IF Y(X8, 4) = 7 THEN 40516
40474 LET K8 = Y(X8, 3)
40476 LET Q0 = 100 + 25 * K8
40486 IF K9 > 0 THEN 40496
40488 LET K9 = K8
40490 GOSUB 56080
40492 LET V(18) = V(Q0 + 10)
40494 LET V(3) = V(Q0 + 3)
40495 GOTO 40516
40496 IF F4 = 1 THEN 40516
40498 IF R4 = 2 THEN 40510
40499 GOSUB 56084
40500 LET S$ = "L G,L " & N1$ & ",bin P 2 ne,= S,"
40502 IF Z8 = 1 THEN 40506
40504 LET S$ = S$ & "ci P 3 %6,= Z,"
40506 LET S$ = S$ & "L S,L G,L Z,L " & N1$ & ",L Z,chk Q SHAPE_MISMATCH 4"
40507 LET Z8 = 1
40508 GOSUB 9000
40509 GOTO 40516
40510 GOSUB 21290
40511 LET S$ = S$ & "L R,L r,bin P 2 eq,B A,L R,L O,bin P 2 eq,= B,L r,L O,bin P 2 eq,= E,L A,L A,L B,bin P 2 bor"
40512 LET S$ = S$ & ",asg P set,L A,L A,L E,bin P 2 bor,asg P set,L C,L c,bin P 2 eq,B F,L C,L O,bin P 2 eq,= H"
40513 LET S$ = S$ & ",L c,L O,bin P 2 eq,= J,L F,L F,L H,bin P 2 bor,asg P set,L F,L F,L J,bin P 2 bor,asg P set"
40514 LET S$ = S$ & ",L A,L A,L F,bin P 2 band,asg P set,L A,un P 2 not,= S,L S,L R,L C,L r,L c,chk Q SHAPE_MISMATCH 4"
40515 GOSUB 21280
40516 LET X8 = H(X8, 4)
40518 GOTO 40468
40520 LET K8 = D5
40522 LET Q0 = 100 + 25 * K8
40524 IF F4 = 1 THEN 40532
40526 LET V(Q0 + 8) = V(7)
40528 LET V(Q0 + 10) = V(18)
40530 LET V(Q0 + 3) = V(3)
40531 GOTO 40546
40532 IF D1 = R8 THEN 40546
40534 IF T(H(W(D1), 2), 3) = 1 THEN 40546
40536 LET T6 = H(D1, 2)
40538 LET S$ = "C " & STR$(T(T6, 0)) & ",= n"
40540 IF R4 = 1 THEN 40544
40542 LET S$ = "C " & STR$(T(T6, 0)) & ",= r,C " & STR$(T(T6, 4)) & ",= c"
40544 GOSUB 9000
40546 LET P9$ = U$
40548 RETURN
40595 REM ---- 40600: (3) RES of the root's type (%0) with the space G or R C (a fixed one: its home,
40596 REM then its extents), (4) the data of RES and of each array leaf in leaf order, the nest
40600 LET R2 = H(R8, 6)
40601 GOSUB 8400
40602 LET Q9$ = P9$
40603 LET P9$ = U$
40604 GOSUB 40990
40605 LET S$ = "L G,anew Q %0 0 1,= Q"
40606 IF R4 = 1 THEN 40608
40607 LET S$ = "L R,L C,anew Q %0 0 2,= Q"
40608 IF F4 = 0 THEN 40616
40610 LET S$ = "anew Q %0 0 0,= Q,X Q 0,= G"
40612 IF R4 = 1 THEN 40616
40614 LET S$ = "anew Q %0 0 0,= Q,X Q 0,= R,X Q 1,= C"
40616 LET K8 = 0
40618 GOSUB 9000
40620 LET S$ = "D Q,= D"
40622 GOSUB 9000
40624 GOSUB 40640
40626 LET K8 = 0
40628 GOTO 40700
40635 REM ---- 40640: the data of the array leaves of tree R8 in leaf order (a folded leaf's base,
40636 REM then the DW of each index vector, L5's order)
40640 LET A9 = 1
40642 GOTO 41100
40667 REM ---- 40668: the DW of the index vector of slot K8
40668 LET S$ = "D W,= x"
40669 GOTO 9000
40695 REM ---- 40700: the nest (Q8 the store: 0 est into D), vector: loop(G; K); matrix: when a leaf
40696 REM may broadcast (B8), tmp p and if (lv p) { the plain copy } { the strides, the broadcast copy } (an O
40697 REM made in the broadcast arm is local to it: Z7 restored after it, D8)
40700 LET K8 = 0
40702 IF R4 = 2 THEN 40712
40704 LET S$ = "( G K"
40706 GOSUB 9000
40708 LET Q9 = 1
40709 GOSUB 40780
40710 LET S$ = ")"
40711 GOTO 9000
40712 GOSUB 40970
40714 IF B8 = 0 THEN 40720
40716 LET S$ = "L p,?"
40718 GOSUB 9000
40720 LET Q9 = 3
40722 LET S$ = "( C L,( R K"
40724 IF F8 > 0 THEN 40728
40725 LET Q9 = 2
40726 LET S$ = "L R,L C,wbin P 3 mul,= m,( m K"
40728 GOSUB 9000
40729 GOSUB 40780
40730 LET S$ = "),)"
40731 IF Q9 = 3 THEN 40733
40732 LET S$ = ")"
40733 GOSUB 9000
40734 IF B8 = 0 THEN 40758
40736 LET S$ = "|"
40738 GOSUB 9000
40739 LET D8 = Z7
40740 GOSUB 40760
40742 LET S$ = "( C L,( R K"
40744 GOSUB 9000
40746 LET Q9 = 4
40748 GOSUB 40780
40750 LET S$ = "),),)"
40752 GOSUB 9000
40754 LET Z7 = D8
40758 RETURN
40759 REM ---- 40760: the broadcast strides of each array leaf (tmp O at its first use, 21290): a whole
40760 REM array's s t j (L7 (4)), a folded leaf's s t
40761 LET A9 = 2
40762 GOSUB 41100
40763 LET K8 = 0
40764 RETURN
40779 REM ---- 40780: the body of copy Q9: F (40800), then the stores (Q8 0: est P s 0 F (lv D) index)
40780 IF Q8 > 0 THEN 41197
40781 GOSUB 40800
40782 LET K8 = 0
40784 LET S$ = "L D,L K,est P %5 0"
40785 IF Q9 < 3 THEN 9000
40786 LET S$ = "L D,L K,L L,L R,wbin P 3 mul,wbin P 3 add,est P %5 0"
40788 GOTO 9000
40795 REM ---- 40800: F of tree R8 in copy Q9, in post-order: each leaf's element (40820), each node's
40796 REM scalar operation (40880: its record with the element type; an emap's per-element call)
40800 LET X6 = R8
40802 GOSUB 30660
40804 FOR D2 = X7 TO R8
40806 IF Y(D2, 7) <> R8 THEN 40810
40808 GOSUB 40820
40810 IF Y(D2, 0) = 0 THEN 40814
40811 IF Y(D2, 2) <> R8 THEN 40814
40812 GOSUB 40880
40814 NEXT D2
40816 LET P9$ = U$
40818 RETURN
40819 REM ---- 40820: the element of leaf D2 in copy Q9 (a scalar lv a; an array eld at its index)
40820 LET K8 = Y(D2, 3)
40822 LET Q0 = 100 + 25 * K8
40824 LET P9$ = U$
40826 LET S$ = "L a"
40828 ON V(Q0 + 7) GOTO 9000, 40830, 40840, 40850, 40829, 40830, 9000, 40829
40829 IF Q8 <> 2 THEN 9000
40830 LET S$ = "L K|L K|L K,L L,L R,wbin P 3 mul,wbin P 3 add|L K,L s,wbin P 3 mul,L L,L j,wbin P 3 mul,wbin P 3 add"
40831 LET C8 = Q9
40832 GOSUB 40960
40833 LET S$ = "L x," & S$
40836 LET S$ = S$ & ",eld P %e %u 0"
40837 GOTO 9000
40839 REM a view: 41280
40840 GOTO 41280
40850 REM a selection: data(B), each index's position (the kept ones at i, then j), lin with X0, eld
40851 LET S$ = "L x"
40852 GOSUB 9000
40853 LET V(34) = V(Q0 + 11)
40854 LET V(35) = V(Q0 + 12)
40855 LET D5 = K8
40856 LET D6 = 0
40857 FOR D4 = 1 TO V(Q0 + 9)
40858 LET K8 = D5 + D4
40859 LET Q0 = 100 + 25 * K8
40860 GOSUB 41310
40861 IF V(Q0 + 9) = 1 THEN 40865
40862 LET D6 = D6 + 1
40863 IF D6 = 1 THEN 40865
40864 LET I1$ = J1$
40865 LET S$ = "L I|L a," & I1$ & ",L c,wbin P 3 mul,wbin P 3 add|" & I1$ & "|L x," & I1$ & ",eld P 3 %3 0"
40866 LET C8 = V(Q0 + 9)
40867 GOSUB 40960
40868 IF D4 = 1 THEN 40871
40869 LET S$ = S$ & ",L g,wbin P 3 mul,wbin P 3 add"
40870 GOTO 40872
40871 LET V(33) = V(Q0 + 20)
40872 GOSUB 9000
40873 NEXT D4
40874 LET K8 = D5
40875 LET Q0 = 100 + 25 * K8
40876 LET S$ = "eld P %e %u 0"
40877 GOTO 9000
40879 REM ---- 40880: the scalar operation of node D2 (its own position): its record with the element
40880 REM type, or an emap's call P ty1 fid n of its elemental function (ty1 the callee's result type)
40881 LET R2 = H(D2, 6)
40882 IF H(D2, 1) = 64 THEN 40890
40883 LET Z$ = D$(R2)
40884 LET F9 = 3
40885 GOSUB 8440
40886 LET F9$ = STR$(T(H(D2, 2), 2))
40887 GOSUB 8470
40888 GOTO 8050
40890 GOSUB 8400
40891 LET F9 = 5
40892 GOSUB 8440
40893 LET Z1$ = F9$
40894 LET R2 = G(H(D2, 5), 6)
40895 GOSUB 8440
40896 LET Z$ = "call " & P9$ & " " & F9$ & " " & STR$(H(D2, 5)) & " " & Z1$
40898 GOTO 8050
40899 REM ---- 40900: a new slot K8 (Q0) for node D3, cleared, with its type's e u k Y (a selection
40900 REM leaf also the slots of its indices)
40901 LET S0 = S0 + 1
40902 IF S0 + 3 < 1390 THEN 40904
40903 CALL "dg_bug": P$, "the slots of a fused unit are full"
40904 LET K8 = S0
40905 LET Y(D3, 3) = K8
40906 FOR C5 = 100 + 25 * K8 TO 175 + 25 * K8
40907 LET V(C5) = 0
40908 NEXT C5
40909 IF Y(D3, 4) <> 4 THEN 40911
40910 LET S0 = S0 + 2
40911 LET Q0 = 100 + 25 * K8
40912 LET Y7 = H(D3, 2)
40913 GOSUB 41408
40914 LET V(Q0 + 4) = E5
40915 LET V(Q0 + 6) = R5
40916 LET V(Q0 + 21) = F5
40917 IF R5 = 0 THEN 40920
40918 GOSUB 8730
40919 LET V(Q0 + 13) = V5
40920 RETURN
40924 REM ---- 40925: C6 = the record of the statement holding node X8 (its ancestor in a block; R9 in a concatenation, G3)
40925 IF G3 = 1 THEN 40932
40926 LET C5 = X8
40927 IF H(W(C5), 1) = 32 THEN 40930
40928 LET C5 = W(C5)
40929 IF C5 > 0 THEN 40927
40930 LET C6 = H(C5, 6)
40931 RETURN
40932 LET C6 = R9
40933 RETURN
40935 REM ---- 40940: I1$ J1$ = the row and column indices of a folded leaf in copy Q9 (the broadcast
40936 REM copy's scaled by the leaf's s t, in a selection's index slots by the globals h i)
40940 LET I1$ = "L K"
40941 LET J1$ = "L L"
40942 IF Q9 < 4 THEN 40948
40943 LET I1$ = "L K,L s,wbin P 3 mul"
40944 LET J1$ = "L L,L t,wbin P 3 mul"
40945 IF V(Q0 + 7) > 0 THEN 40948
40946 LET I1$ = "L K,L h,wbin P 3 mul"
40947 LET J1$ = "L L,L i,wbin P 3 mul"
40948 RETURN
40949 REM ---- 40950: the local of the base B of the folded idx X8 (Y(X8,6)), made at the first need
40950 IF Y(X8, 6) > 0 THEN 40959
40951 LET C7 = R7
40952 GOSUB 40925
40953 LET R7 = C6
40954 LET U1 = H(H(X8, 3), 2)
40955 LET U2 = 0
40956 GOSUB 8100
40957 LET Y(X8, 6) = U0
40958 LET R7 = C7
40959 RETURN
40960 FOR C5 = 2 TO C8
40961 LET C6 = POS(S$, "|")
40962 IF C6 = 0 THEN 40964
40963 LET S$ = SEG$(S$, C6 + 1, LEN(S$))
40964 NEXT C5
40965 LET C6 = POS(S$ & "|", "|")
40966 LET S$ = SEG$(S$, 1, C6 - 1)
40967 RETURN
40968 REM ---- 40970: B8 = 1 when an array leaf may broadcast (a dynamic space, or a leaf that is not
40969 REM fixed with the space's static shape); then the test p of the plain copy written
40970 LET B8 = F4
40971 LET A9 = 3
40972 GOSUB 41100
40973 LET B8 = 1 - B8
40974 IF B8 = 0 THEN 41020
40975 LET C7 = 0
40976 LET A9 = 4
40977 GOSUB 41100
40978 GOTO 41020
40990 REM ---- 40990: of the root R8: T6 its type (%0), R4 rank, F4 fixed, its element size (%5), the
40991 REM space G or R C from its slot
40992 GOSUB 41410
40993 LET K8 = Y(R8, 3)
40994 LET Q0 = 100 + 25 * K8
40995 LET R4 = V(Q0 + 6)
40996 LET F4 = V(Q0 + 21)
40997 LET V(53) = T6
40998 LET V(58) = V(Q0 + 13)
40999 LET V(7) = V(Q0 + 8)
41000 LET V(18) = V(Q0 + 10)
41002 LET V(3) = V(Q0 + 3)
41004 RETURN
41009 REM ---- 41010: the next conjunct of p: bin eq of leaf D2's extents with the space's (C7 so far)
41010 LET K8 = Y(D2, 3)
41012 LET S$ = "L r,L R,bin P 2 eq,L c,L C,bin P 2 eq,bin P 2 band"
41014 IF C7 = 0 THEN 41017
41016 LET S$ = "L r,L R,bin P 2 eq,bin P 2 band,L c,L C,bin P 2 eq,bin P 2 band"
41017 LET C7 = 1
41018 GOTO 9000
41020 LET K8 = 0
41022 LET S$ = "= p"
41024 IF B8 = 1 THEN 9000
41026 RETURN
41095 REM ---- 41100: for each array leaf D2 of the trees of statements E8 ... E9 (fu6grp's table; an
41096 REM expression tree is statement 1), in leaf order, the action A9: 1 its data (41130), 2 its
41097 REM broadcast strides (41150), 3 B8 = 0 when it may broadcast (41170), 4 its conjunct of p
41098 REM (41010); a kind-5 leaf is an array leaf only in the split copy (Q8 = 2)
41100 FOR E1 = E8 TO E9
41102 LET R8 = V(3000 + 20 * E1 + 3)
41104 LET X6 = R8
41106 GOSUB 30660
41108 FOR D2 = X7 TO R8
41110 IF Y(D2, 7) <> R8 THEN 41120
41112 LET C5 = Y(D2, 4)
41114 IF ABS(C5 - 3) <= 1 THEN 41118
41115 IF C5 = 6 THEN 41118
41116 IF (C5 * 10 + Q8 - 52) * (C5 * 10 + Q8 - 82) <> 0 THEN 41340
41118 GOSUB 41126
41120 NEXT D2
41122 NEXT E1
41124 RETURN
41126 ON A9 GOTO 41130, 41151, 41170, 41010
41129 REM 41130: the data of leaf D2 (a folded leaf's base, then each index vector's DW; a kind-5
41130 REM leaf's statement's array; a leaf reading a target of the unit its O, R-f)
41131 LET C6 = 0
41132 LET K8 = Y(D2, 3)
41133 LET Q0 = 100 + 25 * K8
41134 IF ABS(C5 - 6.5) <> 1.5 THEN 41137
41135 IF C5 * 10 + Q8 = 81 THEN 41350
41136 GOSUB 52680
41137 IF C5 <> 2 THEN 41140
41138 GOSUB 51700
41139 LET V(Q0 + 18) = C6
41140 LET S$ = "D N,= x"
41141 IF C6 > 0 THEN 9000
41142 LET S$ = "D a,= x"
41143 GOSUB 9000
41144 IF Y(D2, 4) <> 4 THEN 41350
41145 FOR D4 = 1 TO V(100 + 25 * Y(D2, 3) + 9)
41146 LET K8 = Y(D2, 3) + D4
41147 IF V(100 + 25 * K8 + 9) <> 4 THEN 41149
41148 GOSUB 40668
41149 NEXT D4
41150 RETURN
41151 LET K8 = Y(D2, 3)
41152 GOSUB 21290
41153 LET S$ = S$ & "L r,L O,bin P 2 ne,= s,L c,L O,bin P 2 ne,= t"
41154 LET C4 = C5 * 10 + V(100 + 25 * K8 + 9)
41155 IF C5 = 4 THEN 9000
41156 IF ABS(C4 - 31.5) = .5 THEN 9000
41157 LET S$ = S$ & ",L t,L r,wbin P 3 mul,= j"
41158 GOTO 9000
41170 IF V(100 + 25 * Y(D2, 3) + 21) = 0 THEN 41174
41172 IF T(H(D2, 2), 0) * 1000000 + T(H(D2, 2), 4) = T(T6, 0) * 1000000 + T(T6, 4) THEN 41176
41174 LET B8 = 0
41176 RETURN
41195 REM ---- 41197: the body of a unit's copy (Q8 1 fused: each statement's F bound to its Ei, then
41196 REM the stores of its stored locals and targets; 2 split: statement E8's F stored; a tbind's: R-m, 52560)
41197 LET K7 = 0
41200 FOR E1 = E8 TO E9
41201 IF V(3000 + 20 * E1 + 2) * 10 + Q8 = 22 THEN 41214
41202 LET R8 = V(3000 + 20 * E1 + 3)
41203 IF Q8 = 1 THEN 41240
41204 GOSUB 40800
41205 IF V(3000 + 20 * E1 + 17) > 0 THEN 52560
41206 IF Q8 = 2 THEN 41214
41208 LET K8 = Y(R8, 3)
41210 LET L8 = V(100 + 25 * K8 + 4)
41212 LET S$ = "B " & SEG$("MbMM", V(3000 + 20 * E1 + 2), V(3000 + 20 * E1 + 2))
41213 GOSUB 9000
41214 NEXT E1
41216 FOR E1 = E8 TO E9
41218 IF V(3000 + 20 * E1 + 10) = 0 THEN 41232
41220 LET K8 = Y(V(3000 + 20 * E1 + 3), 3)
41221 LET V(58) = V(100 + 25 * K8 + 13)
41222 LET S$ = "L M,L w,L K"
41223 IF Q8 = 2 THEN 41227
41224 IF Q9 < 3 THEN 41226
41225 LET S$ = S$ & ",L L,L R,wbin P 3 mul,wbin P 3 add"
41226 GOTO 41229
41227 LET S$ = "L w,L K"
41228 GOTO 41224
41229 LET S$ = S$ & ",est P %5 0"
41231 GOSUB 9000
41232 NEXT E1
41234 GOSUB 56720
41235 GOTO 52660
41238 REM ---- 41240: in the fused copy, each kind-5 or kind-8 leaf of tree R8 reads the element Ei bound for
41239 REM the statement it reads (its root slot's M), then F
41240 LET X6 = R8
41242 GOSUB 30660
41244 FOR D2 = X7 TO R8
41246 IF Y(D2, 7) * 10 + ABS(Y(D2, 4) - 6.5) <> R8 * 10 + 1.5 THEN 41250
41248 GOSUB 52672
41250 NEXT D2
41252 GOTO 41204
41258 REM ---- 41260: an expression tree is the one statement of its copy (no unit: no O, no kind-5
41259 REM leaf), F8 its folded leaves
41260 LET V(3023) = R8
41262 LET E8 = 1
41264 LET E9 = 1
41266 LET Q8 = 0
41268 LET H6 = 0
41270 LET F8 = Y(R8, 6)
41272 RETURN
41276 REM ---- 41280: the element of the folded view leaf (slot K8) in copy Q9: .T B at lin(j, i, rows
41277 REM of B, its c); .flat at K; .col at i, .row at j (in the broadcast copy at lin(I s, J t, r)
41278 REM through its strides s j as a whole array, D3)
41280 LET C5 = V(Q0 + 9)
41282 GOSUB 40940
41284 LET S$ = "L x," & J1$ & "," & I1$ & ",L c,wbin P 3 mul,wbin P 3 add"
41286 IF C5 = 1 THEN 40836
41288 LET S$ = "L x,L K"
41290 IF C5 = 2 THEN 40836
41292 LET S$ = "L x,L K,L s,wbin P 3 mul,L L,L j,wbin P 3 mul,wbin P 3 add"
41294 IF Q9 = 4 THEN 40836
41296 LET S$ = "L x," & I1$
41298 IF C5 = 3 THEN 40836
41300 LET S$ = "L x," & J1$
41302 GOTO 40836
41308 REM ---- 41310: I1$ J1$ of a selection's index slot (40850): its globals h i in the broadcast copy
41309 REM (the slot's own l, its count, is no leaf kind: 40945 is for a leaf's slot)
41310 LET I1$ = "L K"
41312 LET J1$ = "L L"
41314 IF Q9 < 4 THEN 41318
41316 LET I1$ = "L K,L h,wbin P 3 mul"
41317 LET J1$ = "L L,L i,wbin P 3 mul"
41318 RETURN
41338 REM ---- 41340: (41116) a kind-8 leaf in the fused copy is a data leaf for its mask only (A9 = 1)
41340 IF C5 * 100 + Q8 * 10 + A9 <> 811 THEN 41120
41342 GOTO 41118
41348 REM ---- 41350: after a mask selection's base data, its mask's data w when it is the first mask
41349 REM selection of its tree (R-r: loaded once, with the first mask leaf; R-h)
41350 IF ABS(Y(D2, 4) - 7) <> 1 THEN 41360
41352 FOR C7 = X7 TO D2 - 1
41354 IF Y(C7, 7) * 10 + ABS(Y(C7, 4) - 7) = R8 * 10 + 1 THEN 41360
41356 NEXT C7
41357 LET K8 = Y(D2, 3)
41358 LET S$ = "D M,= w"
41359 GOTO 9000
41360 RETURN
41368 REM ---- 41370: (40279) the kind C5 of the index X8 into its slot: a bool vector M (5), a bool
41369 REM matrix MM (6), of an L6 store (52000; a folded leaf's indices are S R A V)
41370 IF C5 * 10 + SGN(H(X8, 2) - 9) <> 41 THEN 41376
41372 IF T(H(X8, 2), 2) <> 2 THEN 41376
41374 LET C5 = 4 + T(H(X8, 2), 1)
41376 LET V(Q0 + 9) = C5
41378 RETURN
41379 REM ---- 41380: IX 2 of an M (its NM n, S, vchk with Z); 41386: of an MM (X0 X1 r c, RM CM I W, mchk, NN n)
41380 LET S$ = S$ & ",X M 0,= n,L X,L n,bin P 2 ne,= S,"
41381 IF Z8 = 1 THEN 41383
41382 LET S$ = S$ & "ci P 3 %6,= Z,"
41383 LET S$ = S$ & "L S,L X,L Z,L n,L Z,chk Q SHAPE_MISMATCH 4"
41384 LET Z8 = 1
41385 GOTO 9000
41386 LET S$ = "X d 0,= r,X d 1,= c,X M 0,= I,X M 1,= W,L r,L I,bin P 2 ne,= s,L c,L W,bin P 2 ne,= t,L s,L t,bin P 2 bor,= S,L S,L r,L c,L I,L W,chk Q SHAPE_MISMATCH 4,L r,L c,wbin P 3 mul,= n"
41388 GOTO 9000
41389 REM ---- 41390: IX 3 of an M or MM: its count N over X (MM: NN n), DM w
41390 LET S$ = "C 0,B N,D M,= w,( X K,L N,L N,L w,L K,eld P 2 %2 0,wbin P 3 add,asg P set,)"
41392 IF V(Q0 + 9) = 5 THEN 41396
41394 LET S$ = "C 0,B N,D M,= w,( n K,L N,L N,L w,L K,eld P 2 %2 0,wbin P 3 add,asg P set,)"
41396 GOSUB 9000
41398 GOTO 40420
41399 REM ---- 41400: Y7 = the space type of type Y7 (of a ttuple, a k >= 2 emap's (F5): its first component); 41408: then 8700; 41410: T6 of the root R8; 41413: Y7 of R8
41400 IF Y7 <= 9 THEN 41406
41402 IF T(Y7, 1) > 0 THEN 41406
41404 LET Y7 = T(Y7, 3)
41406 RETURN
41408 GOSUB 41400
41409 GOTO 8700
41410 GOSUB 41413
41411 LET T6 = Y7
41412 RETURN
41413 LET Y7 = H(R8, 2)
41414 GOTO 41400
41415 REM ---- 41416: (40465) the extents of node D1's array leaves of tree R8 loaded first, all of them, before its checks (R-b, L7 (2))
41416 LET X8 = H(D1, 3)
41417 IF X8 = 0 THEN 41427
41418 IF Y(X8, 4) = 1 THEN 41425
41419 IF Y(X8, 4) = 7 THEN 41425
41420 IF Y(X8, 7) <> R8 THEN 41425
41421 LET K8 = Y(X8, 3)
41422 LET Q0 = 100 + 25 * K8
41423 IF F4 * V(Q0 + 6) = 1 THEN 41425
41424 GOSUB 40380
41425 LET X8 = H(X8, 4)
41426 GOTO 41417
41427 RETURN
