40000 REM ====================================================================================
40002 REM sealower part 4 (lines 40000-49999): sub-phase 4e (DESIGN 3.5.9 R1-R11 and the validation of
40004 REM sea.hirl; 3.6.6 "Lowering of the sea.hirl records" 82-87; rule 27 for fixed-size f64, i64
40006 REM and bool arrays; rule 12's grouping of the statements of L6 and L11). Node kinds 53 chkb
40008 REM 54 chk 55 rcnt 56 cow 57 mcpy 58 cdat; types 41 tfvec 59 tfmat (T kind 5, 6: T(.,2) elt,
40010 REM T(.,3) n or rows, T(.,0) 1 or cols). Fields: chkb H5 dim; chk H0 err, H6 n; rcnt H5 incl,
40012 REM H6 l, H0 e; cdat H4 ty, H6 n. A fixed-size value is the address of its home: a p register
40014 REM marked V(.,0) = 1 (a local or parameter of a fixed type, an R1 slot, a hidden result
40016 REM address N7+1 .. N7+H7, 3.6.3); homes hold no counts in 4e. A call whose fixed results
40018 REM it provides itself runs in mode D = -3 (a value: its home on U) or -4 (eval, discarded).
40020 REM J(.,0) of a scope entry: 0 a bound local, 1 an owned R11 tmp, 2 the anchor of a seq's .t.
40022 REM ====================================================================================
40028 REM ---- reading tfvec id elt n / tfmat id elt r c (types, ids in order, 3.5.1) -------------
40030 IF G0 > 0 THEN 2360
40032 IF Y7 = 1 THEN 2360
40034 IF I(1) <> Y9 + 1 THEN 2360
40036 LET Y9 = I(1)
40038 IF Y9 <= T9 THEN 40044
40040 LET P8$ = "types"
40042 GOTO 1285
40044 IF I(2) < 2 THEN 2360
40046 IF I(2) > 4 THEN 2360
40048 LET T(Y9, 1) = 5 + INT(K / 59)
40050 LET T(Y9, 2) = I(2)
40052 LET T(Y9, 3) = I(3)
40054 LET T(Y9, 0) = 1
40056 IF K = 41 THEN 1285
40058 LET T(Y9, 0) = I(4)
40060 GOTO 1285
40090 REM ---- 40100 (R10, every node H1 of kind K just read): a rng only as a forr's range; no
40091 REM array operand of cvt un bin powk lib; no array index of an idx; no asg op to an array;
40092 REM an idx of an array base has as many indices as the base has dimensions (else bad tree)
40100 LET E9 = H(H1, 7)
40102 IF E9 = 0 THEN 40127
40104 IF H(E9, 1) <> 16 THEN 40108
40106 IF K <> 27 THEN 2360
40108 LET E3 = H(E9, 4)
40110 GOSUB 30900
40112 IF E4 = 0 THEN 40124
40114 IF K = 39 THEN 40122
40116 IF K = 12 THEN 2360
40118 IF K < 6 THEN 40124
40120 IF K < 10 THEN 2360
40121 GOTO 40124
40122 IF E9 <> H(H1, 7) THEN 2360
40124 LET E9 = H(E9, 8)
40126 GOTO 40102
40127 IF K = 39 THEN 40140
40128 IF K <> 23 THEN 40136
40130 IF G$(3) = "set" THEN 40136
40132 LET E3 = H(H(H1, 7), 4)
40133 GOSUB 30900
40134 IF E4 > 0 THEN 2360
40136 RETURN
40138 REM an idx: E4 = the rank of its base, E3 = its number of indices
40140 LET E9 = H(H1, 7)
40142 LET E3 = H(E9, 4)
40144 GOSUB 30900
40146 IF E4 = 0 THEN 40136
40148 LET E3 = 0
40150 LET E9 = H(E9, 8)
40152 IF E9 = 0 THEN 40158
40154 LET E3 = E3 + 1
40156 GOTO 40150
40158 IF E3 <> E4 THEN 2365
40160 GOTO 40136
40190 REM ---- reading chkb dim: dim 0 or 1, index and extent of type 3 ----------------------------
40200 LET H(H1, 5) = I(2)
40202 IF I(2) > 1 THEN 2360
40204 GOTO 40276
40208 REM ---- chk err n: a type-2 condition; err a run-time error whose arguments take n slots ----
40210 GOSUB 1900
40212 LET S$(S0) = G$(3)
40214 LET H(H1, 0) = S0
40216 LET H(H1, 6) = I(3)
40218 IF H(H(H1, 7), 4) <> 2 THEN 2360
40220 CALL "dg_find": G$(3), E$(), E0, W3
40222 IF W3 = 0 THEN 2360
40224 IF E$(W3, 2) <> "R" THEN 2360
40226 LET E5 = 0
40228 IF E$(W3, 4) = "-" THEN 40236
40230 FOR E6 = 1 TO LEN(E$(W3, 4))
40232 LET E5 = E5 + 1 + POS("h", SEG$(E$(W3, 4), E6, E6))
40234 NEXT E6
40236 IF E5 <> I(3) THEN 2360
40238 GOTO 1285
40240 REM ---- rcnt incl l e: l (type 3) and e (type 2, R6) distinct, written only by it (A(.,0));
40241 REM lo, hi, st of type 3
40242 LET H(H1, 5) = I(2)
40244 LET H(H1, 6) = I(3)
40246 LET H(H1, 0) = I(4)
40248 IF I(2) > 1 THEN 2360
40250 IF I(3) = I(4) THEN 2360
40252 IF A(E1 + I(3), 1) <> 3 THEN 2360
40254 IF A(E1 + I(4), 1) <> 2 THEN 2360
40256 IF A(E1 + I(3), 0) + A(E1 + I(4), 0) <> 0 THEN 2360
40258 LET A(E1 + I(3), 0) = H1
40260 LET A(E1 + I(4), 0) = H1
40262 LET E2 = H(H1, 7)
40264 FOR E6 = 1 TO 3
40266 IF H(E2, 4) <> 3 THEN 2360
40268 LET E2 = H(E2, 8)
40270 NEXT E6
40272 GOTO 1285
40274 REM (chkb) two children of type 3
40276 LET E2 = H(H1, 7)
40278 IF H(E2, 4) <> 3 THEN 2360
40280 IF H(H(E2, 8), 4) <> 3 THEN 2360
40282 GOTO 1285
40284 REM ---- cow: an lv of a local or ref parameter of a dynamic array type -------------------
40286 LET E2 = H(H1, 7)
40288 IF H(E2, 1) <> 5 THEN 2360
40290 LET E3 = H(E2, 4)
40292 GOSUB 30900
40294 IF E4 = 0 THEN 2360
40296 IF T(E3, 1) > 4 THEN 2360
40298 GOTO 1285
40300 REM ---- mcpy: two addresses of a tptr type, a count of type 3 ---------------------------
40302 LET E2 = H(H1, 7)
40304 FOR E6 = 1 TO 2
40306 IF H(E2, 4) <= 9 THEN 2360
40308 IF T(H(E2, 4), 1) <> 4 THEN 2360
40310 LET E2 = H(E2, 8)
40312 NEXT E6
40314 IF H(E2, 4) <> 3 THEN 2360
40316 GOTO 1285
40318 REM ---- cdat ty n: n >= 1 constants (ci cf cb) of the elt of ty, a tptr (R4) -------------
40320 LET H(H1, 4) = I(2)
40322 LET H(H1, 6) = I(3)
40324 IF I(3) = 0 THEN 2360
40326 IF I(2) <= 9 THEN 2360
40328 IF T(I(2), 1) <> 4 THEN 2360
40330 LET E2 = H(H1, 7)
40332 IF E2 = 0 THEN 1285
40334 IF H(E2, 1) > 3 THEN 2360
40336 IF H(E2, 4) <> T(I(2), 2) THEN 2360
40338 LET E2 = H(E2, 8)
40340 GOTO 40332
40342 REM ---- anew of a fixed-size type: r = 0 and z = 0 (R1) -----------------------------------
40344 IF I(3) + I(4) > 0 THEN 2360
40346 GOTO 1285
40390 REM ==== the checks of a function just read (from 31000) ===================================
40391 REM ---- 40400: rule 12's groups. A block whose statements are all at its own position and whose
40392 REM blocks outside xblks are too (an rcnt has its rng's; L6, L11's block) is one statement:
40393 REM H(block,0) = the first node of its subtree. A run of two or more bind and tmp statements of
40394 REM one block at one position (L11 in place of a tbind) is one statement: H(last,0) likewise
40400 FOR E2 = H2 TO H0
40402 IF H(E2, 1) <> 32 THEN 40470
40404 IF H(E2, 6) = 0 THEN 40470
40406 LET O1 = H(E2, 7)
40408 IF O1 = 0 THEN 40416
40409 IF H(O1, 1) = 55 THEN 40412
40410 IF H(O1, 2) + H(O1, 3) * 1E-6 <> H(E2, 2) + H(E2, 3) * 1E-6 THEN 40440
40412 LET O1 = H(O1, 8)
40414 GOTO 40408
40416 LET O3 = E2
40418 IF H(O3, 7) = 0 THEN 40424
40420 LET O3 = H(O3, 7)
40422 GOTO 40418
40424 LET O2 = E2 - 1
40426 IF O2 < O3 THEN 40438
40428 IF H(O2, 1) <> 43 THEN 40434
40430 IF H(O2, 7) = 0 THEN 40437
40431 LET O2 = H(O2, 7)
40432 GOTO 40430
40434 IF H(O2, 1) <> 32 THEN 40437
40435 IF H(O2, 2) + H(O2, 3) * 1E-6 <> H(E2, 2) + H(E2, 3) * 1E-6 THEN 40440
40437 LET O2 = O2 - 1
40438 IF O2 >= O3 THEN 40428
40439 LET H(E2, 0) = O3
40440 IF H(E2, 0) > 0 THEN 40470
40442 LET O1 = H(E2, 7)
40444 LET O4 = 0
40446 IF O1 = 0 THEN 40470
40448 IF H(O1, 1) = 20 THEN 40454
40450 IF H(O1, 1) <> 44 THEN 40466
40454 IF O4 = 0 THEN 40464
40456 IF H(O1, 2) + H(O1, 3) * 1E-6 <> H(O4, 2) + H(O4, 3) * 1E-6 THEN 40464
40458 LET O3 = O4
40459 IF H(O3, 7) = 0 THEN 40462
40460 LET O3 = H(O3, 7)
40461 GOTO 40459
40462 LET H(O1, 0) = O3
40463 GOTO 40467
40464 LET O4 = O1
40465 GOTO 40467
40466 LET O4 = 0
40467 LET O1 = H(O1, 8)
40468 GOTO 40446
40470 NEXT E2
40472 RETURN
40480 REM ---- 40490 (a bind of a .l local E2, R8): a scalar anywhere; a dynamic array only directly
40481 REM in a block (rule 30 (1): H(E2,6) = 1); a fixed-size one only in L4 (first of a block of 4)
40490 LET E3 = A(E1 + E4, 1)
40492 GOSUB 30900
40494 IF E3 <= 9 THEN 40514
40496 IF T(E3, 1) = 4 THEN 2360
40498 IF E4 = 0 THEN 40514
40500 GOSUB 40520
40502 IF H(O2, 1) <> 32 THEN 2360
40504 IF T(E3, 1) > 4 THEN 40510
40506 LET H(E2, 6) = 1
40508 GOTO 40514
40510 IF H(O2, 6) <> 4 THEN 2360
40512 IF H(O2, 7) <> E2 THEN 2360
40514 RETURN
40518 REM ---- 40520: O2 = the parent of node E2 (0: none) --------------------------------------
40520 FOR O2 = E2 + 1 TO H0
40522 LET O3 = H(O2, 7)
40524 IF O3 = 0 THEN 40530
40526 IF O3 = E2 THEN 40538
40528 LET O3 = H(O3, 8)
40529 GOTO 40524
40530 NEXT O2
40532 LET O2 = 0
40538 RETURN
40540 REM ---- 40550 (an asg E2, from 31123; back to 31040): to a .l local only with op set, of a scalar let local (R8) -------
40550 LET O1 = H(E2, 7)
40552 IF H(O1, 1) <> 5 THEN 40564
40554 LET O1 = H(O1, 5)
40556 IF A(E1 + O1, 4) - 2 * INT(A(E1 + O1, 4) / 2) = 0 THEN 40564
40558 IF A(E1 + O1, 4) <> 1 THEN 2360
40560 IF H(E2, 5) <> 1 THEN 2360
40562 IF A(E1 + O1, 1) > 4 THEN 2360
40564 GOTO 31040
40590 REM ==== fixed-size values (rule 27) ===============================================================
40591 REM ---- 40600: F5 = 1 if the type T5 is fixed-size; then F8 = its size in bytes (4.8) -------
40600 LET F5 = 0
40602 IF T5 <= 9 THEN 40620
40604 IF T(T5, 1) < 5 THEN 40620
40606 LET F5 = 1
40608 LET F8 = E8
40610 IF T(T5, 2) = 4 THEN 40618
40612 LET F8 = E7
40614 IF T(T5, 2) = 3 THEN 40618
40616 LET F8 = G8
40618 LET F8 = F8 * T(T5, 3) * T(T5, 0)
40620 RETURN
40628 REM ---- 40630: D2 = a new home of the fixed type T5 (rule 27 (a), R1): sa into D3 (a register),
40629 REM or into a new p register when D3 = 0; slot sK of the size rounded up to the slot word
40630 GOSUB 40600
40632 LET Z1 = Z7 * INT((F8 + Z7 - 1) / Z7)
40634 IF Z1 > 0 THEN 40638
40636 LET Z1 = Z7
40638 LET Z2 = Z7
40640 GOSUB 7905
40642 LET D2 = D3
40644 IF D3 > 0 THEN 40650
40646 LET C1 = 3
40647 GOSUB 7420
40648 LET D2 = N2
40650 LET V(D2, 0) = 1
40652 LET V1 = D2
40654 GOSUB 7500
40656 LET L1$ = "sa " & Z$ & " s" & STR$(S5)
40658 GOSUB 7695
40659 RETURN
40660 REM ---- 40670: copy (rule 27 (c), (d)) of the fixed type T5 from V3 to V2: li N size, mcopy ---
40670 GOSUB 40600
40672 LET Z3 = F8
40674 GOSUB 10590
40676 LET V4 = N2
40678 LET O$ = "mcopy"
40680 GOSUB 7575
40682 RETURN
40690 REM ---- lv of a fixed local or parameter (a ref one too, rule 31): its register is the home;
40691 REM a rule-12 copy is a new home (rule 12 (c))
40700 LET R9 = A(G(F0, 0) + A1, 3)
40702 IF R9 > 0 THEN 40706
40704 LET R9 = A1
40706 IF H(X, 6) = 0 THEN 3090
40708 LET T5 = H(X, 4)
40710 LET D3 = 0
40712 GOSUB 40630
40714 LET V2 = D2
40716 LET V3 = R9
40718 GOSUB 40670
40720 LET R9 = V2
40722 GOTO 3090
40730 REM ---- 40740 (every node, 3071): a node of a fixed type other than a call or seq is lowered
40731 REM without a destination (R9: an xblk keeps its own home; a bind or asg copies)
40740 IF D < 1 THEN 40752
40742 IF H(X, 1) = 10 THEN 40752
40744 IF H(X, 1) = 19 THEN 40752
40746 LET T5 = H(X, 4)
40748 GOSUB 40600
40749 IF F5 = 0 THEN 40752
40750 LET D = 0
40751 LET W(W0 + 1) = 0
40752 RETURN
40760 REM ---- 40770: ifx of a fixed type (rule 27 (k)): its home, sa before the condition (x3) ----
40770 LET T5 = H(X, 4)
40772 GOSUB 40600
40774 IF F5 = 0 THEN 40780
40776 LET D3 = 0
40777 GOSUB 40630
40778 LET W(W0 + 5) = D2
40780 RETURN
40782 REM each arm's value is copied into the home (then 4100, else 4130)
40784 LET V2 = W(W0 + 3)
40786 LET V3 = R9
40788 LET T5 = H(X, 4)
40790 GOSUB 40670
40792 IF S = 8 THEN 4100
40794 GOTO 4130
40800 REM ---- 40810: N5 = the fixed results and M5 = all results of the type T1 ------------------
40810 LET N5 = 0
40812 LET M5 = 0
40814 IF T1 = 1 THEN 40838
40816 LET M5 = 1
40818 LET T5 = T1
40820 IF T1 <= 9 THEN 40834
40822 IF T(T1, 1) <> 2 THEN 40834
40824 LET M5 = T(T1, 2)
40826 FOR O6 = 1 TO M5
40828 LET T5 = M(T(T1, 3) + O6 - 1)
40830 GOSUB 40600
40831 LET N5 = N5 + F5
40832 NEXT O6
40833 GOTO 40838
40834 GOSUB 40600
40836 LET N5 = F5
40838 RETURN
40840 REM ---- 40850 (a call, before its arguments): the homes of its fixed results (rule 27 (l))
40841 REM unless its parent gives them (D = -2): a bind's local (D > 0), else new homes
40850 IF D = -2 THEN 40888
40852 LET T1 = G(H(X, 5), 3)
40854 GOSUB 40810
40856 IF N5 = 0 THEN 40888
40858 IF D < 1 THEN 40868
40860 GOSUB 7970
40862 LET U(U0, 1) = D
40864 LET U(U0, 2) = 0
40866 LET D = 0
40867 GOTO 40884
40868 FOR O8 = 1 TO M5
40870 LET T5 = T1
40872 IF M5 = 1 THEN 40876
40874 LET T5 = M(T(T1, 3) + O8 - 1)
40876 GOSUB 40600
40878 IF F5 = 0 THEN 40883
40879 LET D3 = 0
40880 GOSUB 40630
40881 GOSUB 7970
40882 LET U(U0, 1) = D2
40883 NEXT O8
40884 LET D = D - 3
40887 LET W(W0 + 1) = D
40888 RETURN
40890 REM ---- 40900: Q6 = the result entries on U: all components (D = -2), the homes (D < -2) ---
40900 IF D > -2 THEN 40912
40902 LET T1 = G(H(X, 5), 3)
40904 GOSUB 40810
40906 LET Q6 = M5
40908 IF D = -2 THEN 40912
40910 LET Q6 = N5
40912 RETURN
40920 REM ---- 40930: L1$ = the call record: nr (0 when discarded), the register results, na, the
40921 REM hidden result addresses (V(.,0) = 1) in result order, then the arguments (3.6.3)
40930 LET M5 = Z5
40932 IF D = -1 THEN 40936
40934 IF D > -3 THEN 40938
40936 LET M5 = 0
40938 LET L1$ = "call " & S$(G(H(X, 5), 1)) & " " & STR$(M5)
40940 LET N5 = 0
40942 FOR I = A2 - Q6 + 1 TO A2
40944 IF V(U(I, 1), 0) = 0 THEN 40948
40945 LET N5 = N5 + 1
40946 GOTO 40954
40948 IF M5 = 0 THEN 40954
40950 LET V1 = U(I, 1)
40951 GOSUB 7500
40952 LET L1$ = L1$ & " " & Z$
40954 NEXT I
40956 LET L1$ = L1$ & " " & STR$(H(X, 6) + N5)
40958 FOR I = A2 - Q6 + 1 TO A2
40960 IF V(U(I, 1), 0) = 0 THEN 40966
40962 LET V1 = U(I, 1)
40963 GOSUB 7500
40964 LET L1$ = L1$ & " " & Z$
40966 NEXT I
40968 FOR I = W(W0 + 3) + 1 TO W(W0 + 3) + H(X, 6)
40970 LET V1 = U(I, 1)
40972 GOSUB 7500
40974 LET L1$ = L1$ & " " & Z$
40976 NEXT I
40978 RETURN
40990 REM ---- bind of a fixed local (rule 27 (b); rule 30 (1) of L4): sa of its slot, then the value
40991 REM written into it: a call (through seqs) gets it as its hidden result address, else a copy
41000 LET T5 = A(G(F0, 0) + H(X, 5), 1)
41002 LET D3 = H(X, 5)
41004 GOSUB 40630
41006 LET O5 = H(X, 7)
41008 IF H(O5, 1) <> 19 THEN 41016
41010 LET O5 = H(O5, 7)
41012 IF H(O5, 8) = 0 THEN 41008
41014 LET O5 = H(O5, 8)
41015 GOTO 41012
41016 LET D1 = 0
41018 IF H(O5, 1) <> 10 THEN 41022
41020 LET D1 = H(X, 5)
41022 LET S = 66
41024 LET X1 = H(X, 7)
41026 GOTO 7380
41028 IF R9 = H(X, 5) THEN 3090
41030 LET V2 = H(X, 5)
41032 LET T5 = A(G(F0, 0) + V2, 1)
41034 LET V3 = R9
41036 GOSUB 40670
41038 GOTO 3090
41040 REM ---- asg set to a fixed local or ref parameter (rule 27 (d)): the value (its own home, or a
41041 REM borrowed address), then li N size, mcopy H V N
41050 IF H(X, 5) > 1 THEN 2360
41052 LET S = 67
41054 GOTO 7380
41056 LET V2 = H(H(X, 7), 5)
41058 GOTO 41032
41060 REM ---- tbind and tasg components, tret, eval: homes of fixed results (rule 27 (l)) ----------
41061 REM tbind: the local's slot (written in place), or a temporary home for _
41070 LET D3 = U(U0, 1)
41072 GOSUB 40630
41074 LET U(U0, 1) = D2
41076 GOTO 5810
41078 REM tasg (a temporary home, stored by step (d)) and eval (released by nothing: no counts)
41080 GOSUB 41086
41082 GOTO 8385
41084 GOSUB 41086
41085 GOTO 16140
41086 LET D3 = 0
41087 GOSUB 40630
41088 LET N2 = D2
41089 RETURN
41090 REM tasg step (d): the home V2 copied into the target local or ref parameter A2
41092 LET V3 = V2
41094 LET V2 = A2
41096 LET T5 = A(G(F0, 0) + A2, 1)
41098 GOSUB 40670
41099 GOTO 8480
41100 REM tret: the function's own hidden result address of the fixed component I
41102 LET N2 = N7
41104 FOR O6 = 1 TO I
41106 LET T5 = M(T(Z6, 3) + O6 - 1)
41108 GOSUB 40600
41110 LET N2 = N2 + F5
41112 NEXT O6
41114 GOTO 7265
41118 REM ---- 41120 (ret, each value R9): a fixed result is copied into its hidden address (rule 27
41119 REM (h)) before the releases, F5 = 1; x3 counts the values
41120 LET W(W0 + 5) = W(W0 + 5) + 1
41122 LET T1 = G(F0, 3)
41124 LET N2 = N7
41126 FOR O6 = 1 TO W(W0 + 5)
41128 LET T5 = T1
41130 IF T1 <= 9 THEN 41136
41132 IF T(T1, 1) <> 2 THEN 41136
41134 LET T5 = M(T(T1, 3) + O6 - 1)
41136 GOSUB 40600
41138 LET N2 = N2 + F5
41140 NEXT O6
41142 IF F5 = 0 THEN 41152
41144 LET V2 = N2
41146 LET V3 = R9
41148 GOSUB 40670
41150 LET F5 = 1
41152 RETURN
41160 REM ---- 41170 (function start): H7 hidden result addresses, registers N7+1 .. N7+H7 ----------
41170 LET T1 = G(F0, 3)
41172 GOSUB 40810
41174 LET H7 = N5
41176 FOR O6 = 1 TO H7
41178 LET V(N7 + O6, 1) = 3
41180 LET V(N7 + O6, 2) = 0
41182 LET V(N7 + O6, 0) = 1
41184 NEXT O6
41186 LET V0 = N7 + H7
41188 LET V9 = V0
41190 RETURN
41194 REM ---- 41200 (the func record): the hidden result addresses before the parameters ------------
41200 FOR O6 = 1 TO H7
41202 LET V1 = N7 + O6
41204 GOSUB 7500
41206 LET F9$ = F9$ & " " & Z$
41208 NEXT O6
41210 RETURN
41220 REM ---- fixed bases of rules 18, 19, 31 and $ (li extents, the home as data, no cow) --------
41221 REM 41230: T6 = the type of the base node O5, F6 = 1 if it is fixed-size
41230 LET T6 = H(O5, 4)
41232 LET T5 = T6
41234 GOSUB 40600
41236 LET F6 = F5
41238 RETURN
41240 REM 10680 for F6 = 1: N2 = li of the extent of dimension Z3
41242 LET Z3 = T(T6, 3 * (1 - Z3))
41244 GOSUB 10590
41246 RETURN
41248 REM 10740 for F6 = 1: the data is the home itself; 11690: no copy on write
41250 LET N2 = V3
41252 RETURN
41260 REM ---- ext of a fixed array (T6 its type) and $ of a fixed base: li of the static extent of
41261 REM dimension H(X,5) into D2
41270 LET O5 = H(X, 7)
41272 GOSUB 41230
41274 RETURN
41280 LET V1 = D2
41282 GOSUB 7500
41284 GOSUB 7865
41286 LET L1$ = "li " & Z$ & " " & STR$(T(T6, 3 * (1 - H(X, 5))))
41288 GOSUB 7695
41290 LET R9 = D2
41292 GOTO 3090
41294 REM adat of a fixed array (R2): no instruction, its register is the operand's
41296 LET R9 = E2
41298 GOTO 3090
41300 REM ---- anew of a fixed type (R1): a new home into the destination ------------------------------
41302 LET T5 = H(X, 4)
41304 GOSUB 40600
41306 IF F5 = 0 THEN 33000
41308 LET D3 = D
41310 GOSUB 40630
41312 LET R9 = D2
41314 LET U0 = E1
41316 GOTO 3090
41320 REM ---- 41330 (tmp, child E2): F5 = 1 if it names its child's register: a fixed value (R9), or
41321 REM an adat of a fixed array (R2)
41330 LET T5 = H(E2, 4)
41332 GOSUB 40600
41334 IF F5 = 1 THEN 41342
41336 IF H(E2, 1) <> 47 THEN 41342
41338 LET T5 = H(H(E2, 7), 4)
41340 GOSUB 40600
41342 RETURN
41344 REM ---- 41350 (rule 12 pre-pass): U3 = 1 if the type T3 is a reference or fixed-size type --
41350 GOSUB 9810
41352 IF U3 = 1 THEN 41358
41354 LET T5 = T3
41355 GOSUB 40600
41356 LET U3 = F5
41358 RETURN
41390 REM ==== the records 82-87 (from 32000 and 32432) ===========================================
41391 REM ---- chkb dim: chkb I E dim site ---------------------------------------------------------
41400 LET V2 = U(E1 + 1, 1)
41402 LET V3 = U(E1 + 2, 1)
41404 LET Z3 = H(X, 5)
41406 GOSUB 10810
41408 GOTO 41444
41410 REM ---- chk err n: chk C err site n A1 .. An -----------------------------------------------
41412 LET V1 = U(E1 + 1, 1)
41414 GOSUB 7500
41416 LET L1$ = "chk " & Z$ & " " & S$(H(X, 0))
41418 GOSUB 7775
41420 LET L1$ = L1$ & " " & Z9$ & " " & STR$(H(X, 6))
41422 FOR O6 = E1 + 2 TO U0
41424 LET V1 = U(O6, 1)
41426 GOSUB 7500
41428 LET L1$ = L1$ & " " & Z$
41430 NEXT O6
41432 GOSUB 7695
41434 GOTO 41444
41436 REM ---- mcpy: mcopy D S N --------------------------------------------------------------------
41438 LET O$ = "mcopy"
41440 GOSUB 41490
41442 GOSUB 7575
41444 LET U0 = E1
41446 LET R9 = 0
41448 GOTO 3090
41450 REM ---- rcnt incl l e: rcount L E lo hi st incl site, L and E the registers of l and e --------
41452 LET L1$ = "rcount"
41454 LET V1 = H(X, 6)
41456 GOSUB 7500
41458 LET L1$ = L1$ & " " & Z$
41460 LET V1 = H(X, 0)
41462 GOSUB 7500
41464 LET L1$ = L1$ & " " & Z$
41466 FOR O6 = E1 + 1 TO E1 + 3
41468 LET V1 = U(O6, 1)
41470 GOSUB 7500
41472 LET L1$ = L1$ & " " & Z$
41474 NEXT O6
41476 GOSUB 7775
41478 LET L1$ = L1$ & " " & STR$(H(X, 5)) & " " & Z9$
41480 GOSUB 7695
41482 GOTO 41444
41488 REM ---- 41490: V2 V3 V4 = the three entries above E1 ----------------------------------------
41490 LET V2 = U(E1 + 1, 1)
41492 LET V3 = U(E1 + 2, 1)
41494 LET V4 = U(E1 + 3, 1)
41496 RETURN
41500 REM ---- cow of lv L: cow(L) of rule 19, the register form or the memory form of a ref parameter;
41501 REM its lv is not lowered (the store's reads of the target are not copied, rule 12)
41502 LET A1 = H(H(X, 7), 5)
41504 LET C7 = 0
41506 LET C8 = A(G(F0, 0) + A1, 3)
41508 IF C8 > 0 THEN 41512
41510 LET C8 = A1
41512 IF A(G(F0, 0) + A1, 2) = 0 THEN 41516
41514 LET C7 = A1
41516 LET F6 = 0
41518 GOSUB 11690
41520 LET R9 = 0
41522 GOTO 3090
41530 REM ---- cdat: a dat data record of its constants (R4) and la P dN into the destination -------
41532 LET Q3 = 3
41534 LET Q4 = X
41536 GOSUB 7935
41538 LET C1 = 3
41540 GOSUB 7470
41542 LET V1 = D2
41544 GOSUB 7500
41546 LET L1$ = "la " & Z$ & " d" & STR$(D0)
41548 GOSUB 7695
41550 LET R9 = D2
41552 GOTO 3090
41560 REM ---- writing a dat record (label I, node X) and its dvi / dvf records (3.6.2) -------------
41562 LET O$ = "bool"
41564 IF T(H(X, 4), 2) = 2 THEN 41570
41566 LET O$ = "f64"
41568 IF T(H(X, 4), 2) = 4 THEN 41570
41569 LET O$ = "i64"
41570 CALL "io_put": 2, "dat d" & STR$(I) & " " & O$ & " " & STR$(H(X, 6))
41572 LET X2 = H(X, 7)
41574 IF X2 = 0 THEN 1825
41576 IF H(X2, 1) = 3 THEN 41584
41578 LET O$ = "dvi "
41580 IF H(X2, 1) = 1 THEN 41582
41581 LET O$ = "dvf "
41582 CALL "io_put": 2, O$ & S$(H(X2, 0))
41583 GOTO 41586
41584 CALL "io_put": 2, "dvi " & STR$(H(X2, 5))
41586 LET X2 = H(X2, 8)
41588 GOTO 41574
41590 REM ---- eld / est with a ci index (R3): no instruction for it; index - and offset off + k*sc
41592 IF H(X, 1) < 48 THEN 32410
41594 IF H(X, 1) > 49 THEN 32410
41596 IF H(W(W0 + 4), 1) <> 1 THEN 32410
41598 LET R9 = 0
41599 GOTO 32420
41600 LET O4 = H(X, 7)
41602 IF H(O4, 8) = 0 THEN 41606
41603 LET O4 = H(O4, 8)
41604 GOTO 41602
41606 CALL "io_i": S$(H(X, 0)), O6, K9, L(), T
41608 IF K9 <> 0 THEN 2360
41610 CALL "io_i": S$(H(O4, 0)), O8, K9, L(), T
41612 IF K9 <> 0 THEN 2360
41614 LET O6 = O6 + O8 * H(X, 5)
41616 IF ABS(O6) >= 1E9 THEN 2360
41618 LET L1$ = L1$ & " - 0 " & STR$(O6)
41620 GOSUB 7695
41622 RETURN
41630 REM ==== R11 and the block end =========================================================================
41631 REM ---- 41640 (a tmp done, register its local's): directly in a block and in no xblk, an owned
41632 REM one is a temporary of the block (R11), J(.,0) = 1; the .t locals of a seq it binds wait for
41633 REM its release at the block's end (attached below it; a borrowed tmp leaves an anchor, J(.,0) = 2)
41640 IF H(W(W0 - 6), 1) <> 32 THEN 41672
41642 FOR O6 = W0 - 12 TO 6 STEP -6
41644 IF H(W(O6), 1) = 43 THEN 41672
41646 NEXT O6
41648 LET X0 = H(X, 7)
41650 GOSUB 9890
41652 LET O6 = J9
41654 IF O6 = 0 THEN 41662
41656 IF J(O6, 4) <> W0 THEN 41662
41658 LET J(O6, 4) = W0 - 6
41660 LET O6 = O6 - 1
41661 GOTO 41654
41662 IF Z0 = 1 THEN 41664
41663 IF O6 = J9 THEN 41672
41664 LET V1 = A(G(F0, 0) + H(X, 5), 3)
41666 IF V1 > 0 THEN 41669
41668 LET V1 = H(X, 5)
41669 GOSUB 10320
41670 LET J(J9, 0) = 2 - Z0
41672 RETURN
41680 REM ---- 41690 (rule 16 (a), R11): the end of block frame W0 above scope height U4: first its
41681 REM owned tmps in record order, then its bound locals in reverse order, each followed by the
41682 REM entries attached below it (J(.,4) = W0, the .t locals of a seq it binds) in their order
41690 FOR K6 = U4 + 1 TO J9
41692 IF J(K6, 0) = 0 THEN 41698
41694 IF J(K6, 0) = 2 THEN 41697
41695 LET V1 = J(K6, 2)
41696 GOSUB 10140
41697 GOSUB 41720
41698 NEXT K6
41700 FOR K6 = J9 TO U4 + 1 STEP -1
41702 IF J(K6, 0) > 0 THEN 41710
41704 IF J(K6, 4) <> 0 THEN 41710
41706 LET V1 = J(K6, 2)
41707 GOSUB 10140
41708 GOSUB 41720
41710 NEXT K6
41712 RETURN
41718 REM ---- 41720: release the entries attached just below K6, in order ------------------------
41720 LET K7 = K6 - 1
41722 IF K7 <= U4 THEN 41728
41724 IF J(K7, 4) <> W0 THEN 41728
41726 LET K7 = K7 - 1
41727 GOTO 41722
41728 FOR M6 = K7 + 1 TO K6 - 1
41730 LET V1 = J(M6, 2)
41732 GOSUB 10140
41734 NEXT M6
41736 RETURN
41740 REM ---- 41750 (rule 12 pre-pass, statement N4): a group of 40400 is one statement [A5, B5] ----
41750 LET A5 = 0
41752 IF H(N4, 0) = 0 THEN 41766
41754 IF H(N4, 1) = 20 THEN 41760
41756 IF H(N4, 1) = 32 THEN 41760
41758 IF H(N4, 1) <> 44 THEN 41766
41760 LET A5 = H(N4, 0)
41762 LET B5 = N4 - 1
41764 LET E6 = A5
41766 RETURN
41770 REM ---- 41772 (reading a tasg H1): E9 = the ttuple type of its last child, else 0 -----------
41772 LET E9 = H(H1, 7)
41774 IF E9 = 0 THEN 41786
41776 IF H(E9, 8) = 0 THEN 41780
41778 LET E9 = H(E9, 8)
41779 GOTO 41776
41780 LET E9 = H(E9, 4)
41782 IF E9 <= 9 THEN 41786
41784 IF T(E9, 1) = 2 THEN 41788
41786 LET E9 = 0
41788 RETURN
41790 REM ---- 41792 (a tbind E2, from 31100): one of .l locals only as the first statement of a block
41791 REM (L12, R8); O4 = -1 when it binds a .l local
41792 FOR O1 = 1 TO H(E2, 6)
41794 LET O4 = M(H(E2, 0) + O1 - 1)
41796 IF O4 = 0 THEN 41804
41798 IF A(E1 + O4, 4) - 2 * INT(A(E1 + O4, 4) / 2) = 0 THEN 41804
41800 LET O1 = H(E2, 6)
41802 LET O4 = -1
41804 NEXT O1
41806 IF O4 >= 0 THEN 41814
41808 GOSUB 40520
41810 IF H(O2, 1) <> 32 THEN 2360
41812 IF H(O2, 7) <> E2 THEN 2360
41814 RETURN
