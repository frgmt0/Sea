40000 REM ====================================================================================
40002 REM sealower part 4 (lines 40000-49999): sub-phase 4e (DESIGN 3.5.9 R1-R11 and the validation of sea.hirl; 3.6.6 "Lowering of the sea.hirl records" 82-87; rule 27 for fixed-size f64, i64 and bool arrays; rule 12's grouping of the statements of
40004 REM L6 and L11). Node kinds 53 chkb 54 chk 55 rcnt 56 cow 57 mcpy 58 cdat; types 41 tfvec 59 tfmat (T kind 5, 6: T(.,2) elt, T(.,3) n or rows, T(.,0) 1 or cols). Fields: chkb H5 dim; chk H0 err, H6 n; rcnt H5 incl, H6 l, H0 e; cdat H4 ty, H6 n.
40006 REM A fixed-size value is the address of its home: a p register marked V(.,0) = 1 (a local or parameter of a fixed type, an R1 slot, a hidden result address N7+1 .. N7+H7, 3.6.3); homes hold no counts in 4e. A call whose fixed results it
40008 REM provides itself runs in mode D = -3 (a value: its home on U) or -4 (eval, discarded). J(.,0) of a scope entry: 0 a bound local, 1 an owned R11 tmp, 2 the anchor of a seq's .t.
40022 REM ====================================================================================
40028 REM ---- reading tfvec id elt n / tfmat id elt r c (types, ids in order, 3.5.1) -------------
40030 IF G0 > 0 THEN 2360
40032 IF Y7 = 1 THEN 40062
40034 GOSUB 1303
40038 IF Y9 > T9 THEN 1282
40044 IF I(2) < 2 THEN 2360
40045 IF T(I(2), 1) = 7 THEN 40048
40046 IF I(2) > 5 THEN 2360
40048 LET T(Y9, 1) = 5 + INT(K / 59)
40050 LET T(Y9, 2) = I(2)
40052 LET T(Y9, 3) = I(3)
40054 LET T(Y9, 0) = 1
40056 IF K = 41 THEN 40059
40058 LET T(Y9, 0) = I(4)
40059 GOSUB 52890
40060 GOTO 1285
40061 REM after a tptr (R14): only the type F8, tfvec of f64 with n 8, when the table has none yet
40062 IF K <> 41 THEN 2360
40064 IF I(2) <> 4 THEN 2360
40066 IF I(3) <> 8 THEN 2360
40068 FOR E6 = 10 TO Y9
40070 IF T(E6, 1) <> 5 THEN 40076
40072 IF T(E6, 2) <> 4 THEN 40076
40074 IF T(E6, 3) = 8 THEN 2360
40076 NEXT E6
40078 GOTO 40034
40090 REM ---- 40100 (R10, every node H1 of kind K just read): a rng only as a forr's range; no array operand of cvt un bin powk lib; no array index of an idx; no asg op to an array; an idx of an array base has as many indices as the base has
40091 REM dimensions (else bad tree)
40100 LET E9 = H(H1, 7)
40102 IF E9 = 0 THEN 40127
40104 IF H(E9, 1) <> 16 THEN 40108
40106 IF K <> 27 THEN 2360
40108 LET E3 = H(E9, 4)
40109 IF ABS(K - 23.5) = .5 THEN 42640
40110 GOSUB 30900
40112 IF E4 = 0 THEN 40124
40114 IF K = 39 THEN 40122
40116 IF K = 12 THEN 40162
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
40161 REM a lib with an array operand: only sort and argsort (R16)
40162 IF POS("|sort|argsort|", "|" & G$(4) & "|") = 0 THEN 2360
40164 GOTO 40124
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
40240 REM ---- rcnt incl l e: l (type 3) and e (type 2, R6) distinct, written only by it (A(.,0)); lo, hi, st of type 3
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
40287 IF H(E2, 1) = 60 THEN 52500
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
40390 REM ==== the checks of a function just read (from 31000) ---- 40400: rule 12's groups. A block whose statements are all at its own position and whose blocks outside xblks are too (an rcnt has its rng's; L6, L11's block) is one statement:
40391 REM H(block,0) = the first node of its subtree. A run of two or more bind and tmp statements of one block at one position (L11 in place of a tbind) is one statement: H(last,0) likewise
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
40480 REM ---- 40490 (a bind of a .l local E2, R8): a scalar anywhere (A(.,4) = 5: declared by a bind); a dynamic array only directly in a block (rule 30 (1): H(E2,6) = 1); a fixed-size one only in L4 (first of a block of 4)
40490 LET E3 = A(E1 + E4, 1)
40492 GOSUB 30900
40494 IF E3 <= 4 THEN 40515
40495 IF E3 <= 9 THEN 40514
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
40515 IF A(E1 + H(E2, 5), 4) <> 1 THEN 40514
40516 LET A(E1 + H(E2, 5), 4) = 5
40517 RETURN
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
40540 REM ---- 40550 (an asg E2, from 31123; back to 31040): to a .l local only with op set, of a scalar local declared by a bind (R8)
40550 LET O1 = H(E2, 7)
40552 IF H(O1, 1) <> 5 THEN 40564
40554 LET O1 = H(O1, 5)
40556 IF A(E1 + O1, 4) - 2 * INT(A(E1 + O1, 4) / 2) = 0 THEN 40564
40558 IF A(E1 + O1, 4) <> 5 THEN 2360
40560 IF H(E2, 5) <> 1 THEN 2360
40562 IF A(E1 + O1, 1) > 4 THEN 2360
40563 GOTO 40566
40564 GOTO 31040
40565 REM its value a wbin, bin or un (R8) or a scalar lib where (R15)
40566 LET O1 = H(H(E2, 7), 8)
40568 IF H(O1, 1) = 7 THEN 40564
40570 IF H(O1, 1) = 8 THEN 40564
40572 IF H(O1, 1) = 51 THEN 40564
40574 IF H(O1, 1) <> 12 THEN 2360
40576 IF S$(H(O1, 0)) <> "where" THEN 2360
40578 GOTO 40564
40590 REM ==== fixed-size values (rule 27) ---- 40600: F5 = 1 if the type T5 is fixed-size, a struct or a record (an aggregate); then F8 = its size in bytes (4.8, layout); 40595: of T5 = T1, 40592: of the type of X
40592 LET T5 = H(X, 4)
40593 GOTO 40600
40595 LET T5 = T1
40600 LET F5 = 0
40602 IF T5 <= 9 THEN 40620
40604 IF T(T5, 1) < 5 THEN 40620
40606 LET F5 = 1
40608 LET F8 = O(T5, 1)
40620 RETURN
40622 LET D3 = 0
40623 GOTO 40630
40628 REM ---- 40630: D2 = a new home of the fixed type T5 (rule 27 (a), R1): sa into D3 (a register), or into a new p register when D3 = 0 (40622: with D3 = 0); slot sK of the size rounded up to the slot word
40630 GOSUB 40600
40632 LET Z1 = Z7 * INT((F8 + Z7 - 1) / Z7)
40634 IF Z1 > 0 THEN 40638
40636 LET Z1 = Z7
40638 LET Z2 = Z7
40640 GOSUB 7905
40642 LET D2 = D3
40644 IF D3 > 0 THEN 40650
40646 GOSUB 7418
40648 LET D2 = N2
40650 LET V(D2, 0) = 1
40651 LET V(D2, 3) = T5
40652 LET L1$ = "sa" & FNR$(D2) & " s" & STR$(S5)
40658 GOTO 7695
40660 REM ---- 40670: copy (rule 27 (c), (d)) of the fixed type T5 from V3 to V2: li N size, mcopy ---
40670 GOSUB 40600
40672 LET Z3 = F8
40674 GOSUB 10590
40676 LET V4 = N2
40678 LET O$ = "mcopy"
40680 GOTO 7575
40690 REM ---- lv of a fixed local or parameter (a ref one too, rule 31): its register is the home; a rule-12 copy is a new home (rule 12 (c))
40700 LET R9 = A(G(F0, 0) + A1, 3)
40702 IF R9 > 0 THEN 40706
40704 LET R9 = A1
40706 IF H(X, 6) = 0 THEN 3090
40708 LET D2 = R9
40710 GOSUB 50400
40712 GOTO 3088
40730 REM ---- 40740 (every node, 3071): a node of a fixed type other than a call or seq is lowered without a destination (R9: an xblk keeps its own home; a bind or asg copies)
40740 IF D < 1 THEN 40752
40742 IF H(X, 1) = 10 THEN 40752
40744 IF H(X, 1) = 19 THEN 40752
40745 IF H(X, 1) = 61 THEN 40752
40746 GOSUB 40592
40749 IF F5 = 0 THEN 40752
40750 LET D = 0
40751 LET W(W0 + 1) = 0
40752 RETURN
40760 REM ---- 40770: ifx of a fixed type (rule 27 (k)): its home, sa before the condition (x3) ----
40770 GOSUB 40592
40774 IF F5 = 0 THEN 40780
40776 GOSUB 40622
40778 LET W(W0 + 5) = D2
40780 RETURN
40782 REM each arm's value is copied into the home (then 4100, else 4130)
40784 LET V2 = W(W0 + 3)
40786 LET V3 = R9
40787 LET X0 = H(H(X, 7), 8)
40788 LET T5 = H(X, 4)
40789 IF S = 8 THEN 40791
40790 LET X0 = H(X0, 8)
40791 GOSUB 52950
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
40840 REM ---- 40850 (a call, before its arguments): the homes of its fixed results (rule 27 (l)) unless its parent gives them (D = -2): a bind's local (D > 0), else new homes
40850 IF D = -2 THEN 40888
40852 LET T1 = G(H(X, 5), 3)
40854 GOSUB 40810
40856 IF N5 = 0 THEN 40888
40858 IF D < 1 THEN 40868
40860 GOSUB 7970
40862 LET U(U0, 1) = D
40866 LET D = 0
40867 GOTO 40884
40868 FOR O8 = 1 TO M5
40870 LET T5 = T1
40872 IF M5 = 1 THEN 40876
40874 LET T5 = M(T(T1, 3) + O8 - 1)
40876 GOSUB 40600
40878 IF F5 = 0 THEN 40883
40879 GOSUB 40622
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
40920 REM ---- 40930: L1$ = the call record: nr (0 when discarded), the register results, na, the hidden result addresses (V(.,0) = 1) in result order, then the arguments (3.6.3)
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
40950 LET L1$ = L1$ & FNR$(U(I, 1))
40954 NEXT I
40956 LET L1$ = L1$ & " " & STR$(H(X, 6) + N5)
40958 FOR I = A2 - Q6 + 1 TO A2
40960 IF V(U(I, 1), 0) = 0 THEN 40966
40962 LET L1$ = L1$ & FNR$(U(I, 1))
40966 NEXT I
40968 FOR I = W(W0 + 3) + 1 TO W(W0 + 3) + H(X, 6)
40970 LET L1$ = L1$ & FNR$(U(I, 1))
40976 NEXT I
40978 RETURN
40990 REM ---- bind of a fixed local (rule 27 (b); rule 30 (1) of L4): sa of its slot, then the value written into it: a call (through seqs) gets it as its hidden result address, else a copy
41000 LET T5 = A(G(F0, 0) + H(X, 5), 1)
41002 LET D3 = H(X, 5)
41004 GOSUB 40630
41006 LET I2 = H(X, 7)
41008 GOSUB 51400
41010 LET O5 = I2
41016 LET D1 = 0
41017 IF H(O5, 1) = 61 THEN 41020
41018 IF H(O5, 1) <> 10 THEN 41022
41020 LET D1 = H(X, 5)
41022 LET S = 66
41024 LET X1 = H(X, 7)
41026 GOTO 7380
41028 IF R9 = H(X, 5) THEN 41038
41030 LET V2 = H(X, 5)
41032 LET T5 = A(G(F0, 0) + V2, 1)
41034 LET V3 = R9
41035 LET X0 = H(X, 7)
41036 GOSUB 52950
41038 GOTO 52900
41040 REM ---- asg set to a fixed local or ref parameter (rule 27 (d)): the value (its own home, or a borrowed address), then li N size, mcopy H V N
41050 IF H(X, 5) > 1 THEN 2360
41052 LET S = 67
41054 GOTO 7380
41056 GOTO 53200
41060 REM ---- tbind and tasg components, tret, eval: homes of fixed results (rule 27 (l)) tbind: the local's slot (written in place), or a temporary home for _
41070 LET D3 = U(U0, 1)
41072 GOSUB 40630
41074 LET U(U0, 1) = D2
41076 GOTO 5810
41078 REM tasg (a temporary home, stored by step (d)) and eval (released by nothing: no counts)
41080 GOSUB 41086
41082 GOTO 8385
41084 GOSUB 41086
41085 GOTO 16140
41086 GOSUB 40622
41088 LET N2 = D2
41089 RETURN
41090 REM tasg step (d): the home V2 copied into the target local or ref parameter A2
41092 LET V1 = A2
41093 GOSUB 10140
41094 LET V3 = U(I, 1)
41095 LET V2 = A2
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
41118 REM ---- 41120 (ret, before each value; 41122 after it): F5, N2 its hidden address; 41142 (after): a fixed result R9 is copied into it (rule 27 (h)) before the releases, F5 = 1; x3 counts the values
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
41141 RETURN
41142 IF F5 = 0 THEN 41152
41143 IF R9 = N2 THEN 41150
41144 LET V2 = N2
41145 LET V(N2, 3) = T5
41146 LET V3 = R9
41147 LET X0 = W(W0 + 4)
41148 GOSUB 52950
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
41202 LET F9$ = F9$ & FNR$(N7 + O6)
41208 NEXT O6
41210 RETURN
41220 REM ---- fixed bases of rules 18, 19, 31 and $ (li extents, the home as data, no cow) 41230: T6 = the type of the base node O5, F6 = 1 if it is fixed-size
41230 LET T6 = H(O5, 4)
41232 LET T5 = T6
41234 GOSUB 40600
41236 LET F6 = F5
41238 RETURN
41240 REM 10680 for F6 = 1: N2 = li of the extent of dimension Z3
41242 LET Z3 = T(T6, 3 * (1 - Z3))
41244 GOTO 10590
41248 REM 10740 for F6 = 1: the data is the home itself; 11690: no copy on write
41250 LET N2 = V3
41252 RETURN
41260 REM ---- ext of a fixed array (T6 its type) and $ of a fixed base: li of the static extent of dimension H(X,5) into D2
41270 LET O5 = H(X, 7)
41272 GOTO 41230
41280 LET L1$ = "li" & FNR$(D2) & " " & STR$(T(T6, 3 * (1 - H(X, 5))))
41282 GOSUB 7865
41288 GOTO 7662
41294 REM adat of a fixed array (R2): no instruction, its register is the operand's
41296 LET R9 = E2
41298 GOTO 3090
41300 REM ---- anew of a fixed type (R1): a new home into the destination ------------------------------
41302 GOSUB 40592
41306 IF F5 = 0 THEN 33000
41308 LET D3 = D
41310 GOSUB 40630
41312 LET R9 = D2
41314 LET U0 = E1
41316 GOTO 3090
41320 REM ---- 41330 (tmp, child E2): F5 = 1 if it names its child's register: a fixed value (R9), or an adat of a fixed array (R2)
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
41390 REM ==== the records 82-87 (from 32000 and 32432) ---- chkb dim: chkb I E dim site ---------------------------------------------------------
41400 LET V2 = U(E1 + 1, 1)
41402 LET V3 = U(E1 + 2, 1)
41404 LET Z3 = H(X, 5)
41406 GOSUB 10810
41408 GOTO 41444
41410 REM ---- chk err n: chk C err site n A1 .. An -----------------------------------------------
41412 LET L1$ = "chk" & FNR$(U(E1 + 1, 1)) & " " & S$(H(X, 0))
41418 GOSUB 7775
41420 LET L1$ = L1$ & " " & Z9$ & " " & STR$(H(X, 6))
41422 FOR O6 = E1 + 2 TO U0
41424 LET L1$ = L1$ & FNR$(U(O6, 1))
41430 NEXT O6
41432 GOSUB 7695
41434 GOTO 41444
41436 REM ---- mcpy: mcopy D S N --------------------------------------------------------------------
41437 LET T3 = T(H(H(X, 7), 4), 2)
41438 LET O$ = "mcopy"
41439 GOSUB 9802
41440 IF U3 = 1 THEN 42700
41441 GOSUB 41490
41442 IF V4 = 0 THEN 2360
41443 GOSUB 7575
41444 LET U0 = E1
41446 GOTO 3081
41450 REM ---- rcnt incl l e: rcount L E lo hi st incl site, L and E the registers of l and e --------
41452 LET L1$ = "rcount" & FNR$(H(X, 6)) & FNR$(H(X, 0))
41466 FOR O6 = E1 + 1 TO E1 + 3
41468 LET L1$ = L1$ & FNR$(U(O6, 1))
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
41500 REM ---- cow of lv L: cow(L) of rule 19, the register form or the memory form of a ref parameter; its lv is not lowered (the store's reads of the target are not copied, rule 12)
41502 LET A1 = H(H(X, 7), 5)
41503 IF H(H(X, 7), 1) = 60 THEN 52400
41504 LET C7 = 0
41506 LET C8 = A(G(F0, 0) + A1, 3)
41508 IF C8 > 0 THEN 41512
41510 LET C8 = A1
41512 IF A(G(F0, 0) + A1, 2) = 0 THEN 41516
41514 LET C7 = A1
41516 LET F6 = 0
41518 GOSUB 11690
41519 GOSUB 52420
41520 GOTO 3081
41530 REM ---- cdat: a dat data record of its constants (R4) and la P dN into the destination -------
41532 LET Q3 = 3
41534 LET Q4 = X
41536 GOSUB 7935
41538 GOSUB 7466
41542 LET L1$ = "la" & FNR$(D2) & " d" & STR$(D0)
41548 GOTO 7662
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
41592 IF ABS(H(X, 1) - 48.5) = .5 THEN 41596
41593 IF H(X, 1) = 57 THEN 41596
41594 IF H(X, 1) > 49 THEN 32410
41596 IF H(W(W0 + 4), 1) <> 1 THEN 32410
41598 LET R9 = 0
41599 GOTO 32420
41600 GOSUB 51100
41602 LET L1$ = L1$ & " - 0 " & STR$(M4)
41604 GOTO 7695
41630 REM ==== R11 and the block end ---- 41640 (a tmp done, register its local's): directly in a block and in no xblk, an owned one is a temporary of the block (R11), J(.,0) = 1; the .t locals of a seq it binds wait for its release at the block's
41631 REM end (attached below it; a borrowed tmp leaves an anchor, J(.,0) = 2)
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
41680 REM ---- 41690 (rule 16 (a), R11): the end of block frame W0 above scope height U4: first its owned tmps in record order, then its bound locals in reverse order, each followed by the entries attached below it (J(.,4) = W0, the .t locals of a
41681 REM seq it binds) in their order
41690 FOR K6 = U4 + 1 TO J9
41692 IF J(K6, 0) = 0 THEN 41698
41694 IF J(K6, 0) = 2 THEN 41697
41695 GOSUB 10135
41697 GOSUB 41720
41698 NEXT K6
41700 FOR K6 = J9 TO U4 + 1 STEP -1
41702 IF J(K6, 0) > 0 THEN 41710
41704 IF J(K6, 4) <> 0 THEN 41710
41706 GOSUB 10135
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
41789 REM ---- 41791 (a tbind E2, from 31100): one of .l locals only as the first statement of a block (L12, R8); each .l local it binds is marked A(.,4) + 8 (R25)
41791 LET O3 = 0
41792 FOR O1 = 1 TO H(E2, 6)
41794 LET O4 = M(H(E2, 0) + O1 - 1)
41796 IF O4 = 0 THEN 41804
41798 IF A(E1 + O4, 4) - 2 * INT(A(E1 + O4, 4) / 2) = 0 THEN 41804
41799 LET A(E1 + O4, 4) = A(E1 + O4, 4) + 8
41800 LET O3 = -1
41804 NEXT O1
41806 IF O3 >= 0 THEN 41814
41808 GOSUB 40520
41810 IF H(O2, 1) <> 32 THEN 2360
41812 IF H(O2, 7) <> E2 THEN 2360
41814 RETURN
41990 REM ==== sub-phase 4g-1 (DESIGN 3.5.9 R17, R20, R22, R25; 3.6.6 rules 12, 15, 16, 32, 34, 35). R22 is 10390's: an owned R11 tmp is on J ---- 42000 (est or asg X, value X0 in R9): moved, Z0 = 1 (R17 (b): lv of an owned tmp of the est's block,
41991 REM J(.,0) = 1; R25: lv of an L12 tbind's .l local, A(.,4) >= 8, J(.,0) = 0; J entry set 2, read nowhere after), else 10230
42000 LET Z0 = 0
42002 LET L6 = 1
42004 IF H(X0, 1) <> 5 THEN 42044
42006 LET L3 = H(X0, 5)
42008 LET L4 = G(F0, 0) + L3
42012 IF A(L4, 0) > 0 THEN 42018
42014 IF A(L4, 4) < 8 THEN 42044
42016 LET L6 = 0
42018 LET L8 = W0 - 12 + 6 * (L6 + (1 - L6) * INT(ABS(H(X, 1) - 49) / 26))
42020 IF L6 * (H(X, 1) - 49) <> 0 THEN 42044
42022 IF H(W(W0 - 6), 1) <> 32 THEN 42044
42024 IF H(W(L8), 1) <> 32 THEN 42044
42026 LET L4 = L3 + (A(L4, 3) - L3) * SGN(A(L4, 3))
42032 FOR K6 = J9 TO W(L8 + 3) + 1 STEP -1
42034 IF J(K6, 0) + 10 * J(K6, 2) <> L6 + 10 * L4 THEN 42040
42036 LET J(K6, 0) = 2
42038 LET Z0 = 1
42040 NEXT K6
42042 IF Z0 = 1 THEN 42050
42044 IF L6 + ABS(H(X, 1) - 49) = 0 THEN 2360
42046 GOTO 10230
42050 FOR K6 = X + 1 TO G(F0, 8)
42052 IF H(K6, 1) <> 5 THEN 42056
42054 IF H(K6, 5) = L3 THEN 2360
42056 NEXT K6
42058 RETURN
42090 REM ---- 42100: rcall of the entry Q1$ into D2 with the Z5 (0-2) arguments V3 V4 ------------
42100 LET Q9 = FNE(Q1$, "")
42102 GOSUB 5590
42104 LET L1$ = L1$ & FNR$(D2) & " " & STR$(Z5)
42110 IF Z5 = 0 THEN 7695
42112 LET L1$ = L1$ & FNR$(V3)
42118 IF Z5 = 1 THEN 7695
42120 LET L1$ = L1$ & FNR$(V4)
42126 GOTO 7695
42190 REM ---- bin cat / comparison of str A1 A2 (rule 32) into D2, the temporary operands released (15 (b)); 42192 (from 6304): str += (15 (i)), cat into a new R, then stored
42192 LET A1 = A2
42194 LET A2 = R9
42196 LET A3 = 18
42197 GOSUB 7420
42198 LET D2 = N2
42200 LET V3 = A1
42202 LET V4 = A2
42204 LET Z5 = 2
42206 LET Q1$ = "STR_CAT"
42208 LET D4 = D2
42210 IF A3 = 18 THEN 42220
42212 LET Q1$ = "STR_CMP"
42216 GOSUB 7420
42218 LET D2 = N2
42220 GOSUB 42100
42222 IF A3 = 18 THEN 42236
42224 GOSUB 10585
42228 LET V4 = N2
42230 LET L1$ = "icmp " & S$(H(X, 0)) & FNR$(D4) & FNR$(D2) & FNR$(V4)
42232 GOSUB 7620
42236 LET D2 = D4
42238 LET X0 = H(X, 7)
42240 LET R0 = A1
42242 GOSUB 10080
42244 LET X0 = H(X0, 8)
42246 LET R0 = A2
42248 GOSUB 10080
42250 IF H(X, 1) = 8 THEN 3805
42252 LET W(W0 + 3) = D2
42254 LET A1 = H(H(X, 7), 5)
42256 IF A(G(F0, 0) + A1, 2) = 1 THEN 15080
42258 GOTO 14920
42270 REM ---- 42280: a str read N2 copied before a ref call (rule 12 (a), (b)) is retained ---------
42280 IF H(H(X, 7), 6) + C1 <> 4 THEN 10120
42282 LET V1 = N2
42284 GOTO 10180
42390 REM ---- lib str, lower, args (rules 32, 35; W2 23-25, argument U(Z6+1)): an rcall into D2; str of a bool la T, la F (str true, false), psel (borrowed)
42400 GOSUB 7466
42404 LET V3 = U(Z6 + 1, 1)
42406 LET Z5 = H(X, 6)
42408 LET D5 = W2 - 21
42410 IF W2 > 23 THEN 42414
42412 LET D5 = H(H(X, 7), 4) - 2
42414 IF D5 = 0 THEN 42440
42416 LET Q1$ = SEG$("STR_I64  STR_F64  STR_LOWERARGS     ", 9 * D5 - 8, 9 * D5)
42424 GOSUB 42100
42426 LET X0 = H(X, 7)
42428 LET R0 = V3
42430 GOSUB 10080
42432 GOTO 19575
42440 LET D4 = D2
42442 FOR Q3 = 4 TO 5
42444 GOSUB 42461
42446 LET V4 = V5
42448 LET V5 = D2
42450 NEXT Q3
42452 LET L1$ = "psel" & FNR$(D4) & FNR$(V3) & FNR$(V4) & FNR$(V5)
42454 GOSUB 7695
42458 LET R9 = D4
42460 GOTO 19580
42461 GOSUB 7420
42462 LET D2 = N2
42464 LET Q4 = X
42466 GOSUB 7935
42468 LET L1$ = "la" & FNR$(D2) & " d" & STR$(D0)
42474 GOTO 7695
42479 IF D(I, 1) = 6 THEN 52750
42480 CALL "io_put": 2, "str d" & STR$(I) & " " & SEG$("truefalse", 4 * D(I, 1) - 15, 5 * D(I, 1) - 16)
42482 GOTO 1825
42590 REM ---- 42620 (9890): str of a bool is borrowed, a str element (flagged H(P4,5) = 1 by 53300 when read before a ref call of its root, consumed after it) owned when flagged or of an owned array (15 (f)); 42640 (40109): no asg or tasg target
42591 REM that L17 rewrites, an element of a type that holds counts
42620 IF S$(H(P5, 0)) <> "str" THEN 10050
42622 IF H(H(P5, 7), 4) = 2 THEN 10060
42624 GOTO 10050
42630 IF H(P5, 5) = 1 THEN 10050
42632 LET P5 = H(P5, 7)
42634 GOTO 9910
42640 IF H(E9, 8) = 0 THEN 40110
42641 LET I2 = E9
42642 IF H(I2, 1) = 60 THEN 2360
42643 IF H(I2, 1) <> 39 THEN 40110
42644 LET T3 = H(I2, 4)
42645 IF I2 <> E9 THEN 42649
42646 GOSUB 9802
42647 IF U3 = 1 THEN 2360
42648 IF T(T3, 1) = 7 THEN 2360
42649 LET I2 = H(I2, 7)
42650 GOTO 42642
42651 REM ---- 42652 (of 9890): an eld P5 is owned when rule 12 (b) flagged it (H6 = 1) or its address is adat (lv T), T a tmp whose child is owned (rule 15 (f)); a non-tmp T (A(.,0) = 0) reaches node 0, whose kind and type are 0
42652 IF H(P5, 6) = 1 THEN 10050
42654 LET P5 = H(H(P5, 7), 7)
42660 IF H(P5, 1) <> 5 THEN 10060
42661 LET P5 = A(G(F0, 0) + H(P5, 5), 0)
42663 LET P5 = H(P5, 7)
42664 GOTO 9910
42665 REM ---- 42666 (of the eld X in D2): retain D2 right after its load when 9890 calls the eld owned
42666 LET X0 = X
42668 GOSUB 9890
42670 IF Z0 = 0 THEN 10060
42671 IF V(D2, 0) = 1 THEN 50400
42672 LET V1 = D2
42674 GOTO 10180
42690 REM ---- mcpy into counted elements (R20): the element count n (a ci: li B n*size; else li S size, imul B N S), mcopy, then the retains of the reference values of the n elements (53000; unrolled for a ci, else in loop(n; K)); none for a moved
42691 REM source (53100)
42700 LET D4 = U(E1 + 1, 1)
42701 LET D5 = U(E1 + 2, 1)
42702 LET D7 = U(E1 + 3, 1)
42703 LET I7 = T(H(H(X, 7), 4), 2)
42704 LET M3 = O(I7, 1)
42705 LET Z3 = M3
42706 IF D7 > 0 THEN 42710
42707 CALL "io_i": S$(H(H(H(H(X, 7), 8), 8), 0)), J2, K9, L(), T
42708 LET Z3 = J2 * M3
42710 GOSUB 10590
42711 LET V4 = N2
42712 IF D7 = 0 THEN 42720
42714 LET O$ = "imul"
42715 LET V3 = D7
42716 GOSUB 42795
42718 LET V4 = V2
42720 LET L1$ = "mcopy" & FNR$(D4) & FNR$(D5) & FNR$(V4)
42721 GOSUB 7620
42724 GOSUB 53100
42725 IF Z0 = 1 THEN 41444
42726 LET J3 = 0
42727 IF D7 > 0 THEN 42740
42728 LET M2 = 0
42729 FOR J1 = 1 TO J2
42730 GOSUB 53000
42731 LET J3 = J3 + M3
42732 NEXT J1
42733 GOTO 41444
42740 GOSUB 10585
42742 LET D6 = N2
42744 LET O$ = "icmp gt"
42746 LET V3 = D7
42747 LET V4 = D6
42748 GOSUB 42795
42749 GOSUB 7885
42750 LET D8 = B7
42751 LET L1$ = "if " & STR$(B7) & FNR$(V2)
42754 GOSUB 7695
42755 LET Z3 = 1
42756 GOSUB 10590
42757 LET V5 = N2
42759 LET O$ = "isub"
42761 LET V4 = V5
42762 GOSUB 42795
42763 LET V4 = V2
42764 GOSUB 7420
42765 LET V2 = N2
42766 LET V3 = D6
42767 GOSUB 7885
42768 LET O$ = "loop " & STR$(B7)
42769 GOSUB 11530
42770 LET M2 = V2
42771 GOSUB 53000
42780 LET L1$ = "endloop " & STR$(D8 + 1)
42781 GOSUB 7695
42782 LET L1$ = "endif " & STR$(D8)
42783 GOSUB 7695
42784 GOTO 41444
42794 REM ---- 42795: O$ into a new register V2 of class C1, of V3 V4 -------------------------------
42795 GOSUB 7420
42796 LET V2 = N2
42797 GOTO 7575
42798 REM ---- est of a reference (32918): into a fresh address (lv D of a tmp D = adat (lv A), A's tmp an anew before D's in its xblk or block) initializing (R5); else replacing (R17 (a)): ldp O, stp, release O (32929)
42800 GOSUB 51200
42802 IF W4 = 1 THEN 32922
42830 GOSUB 7418
42834 LET D4 = N2
42836 LET O$ = "ldp"
42838 LET V2 = N2
42840 LET V3 = E3
42842 LET V4 = E4
42844 GOSUB 32950
42846 LET O$ = "stp"
42848 GOTO 32922
42850 LET V1 = D4
42852 GOSUB 10140
42854 GOTO 32930
42890 REM ---- printf (from 5311): its owned str arguments released after the rcall, in order (15 (b)), not after error (rule 34)
42900 FOR K7 = W(W0 + 3) + 1 TO U0
42902 LET X0 = U(K7, 0)
42904 LET R0 = U(K7, 1)
42906 GOSUB 10080
42908 NEXT K7
42910 GOTO 5315
42911 REM ---- 42920 (of 23645): the root read J5 bound by tmp P4 or read by adat P4: rule 12 (b) flags (H6 = 1) each reference eld at adat (J5 or lv P4) read before the rarg and consumed after it
42920 LET Y8 = P4
42922 LET Y8 = Y8 + 1
42924 IF Y8 >= N4 THEN 23650
42926 IF H(Y8, 1) <> 48 THEN 42922
42930 LET P5 = H(H(Y8, 7), 7)
42935 IF P5 = J5 THEN 42940
42936 IF H(P5, 1) + 100 * H(P4, 1) <> 4405 THEN 42922
42938 IF H(P5, 5) <> H(P4, 5) THEN 42922
42940 LET U5 = Y8
42942 GOSUB 23360
42944 IF U6 >= K4 THEN 42922
42946 LET P5 = Y8
42948 GOSUB 42960
42950 IF U6 <= K4 THEN 42922
42952 LET H(Y8, 6) = 1
42954 GOTO 42922
42958 REM ---- 42960: U6 = the rank of the consumer of node P5, through an xblk it is the value of and an fconv; a tmp counts as read after the rarg (K4 + 1)
42960 LET P6 = P5
42962 GOSUB 23780
42964 IF ABS(H(P5, 1) - 29) = 14 THEN 42960
42966 LET U5 = P5
42968 IF H(P5, 1) <> 44 THEN 23360
42970 LET U6 = K4 + 1
42972 RETURN
