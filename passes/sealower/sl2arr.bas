9000 REM ====================================================================================
9010 REM sealower part 2 (lines 9000-29999): phase 4, sub-phase 4d -- dynamic arrays of f64, i64 and bool (DESIGN 3.6.6 rules 12 (phase 4), 15, 16, 18, 19, 31, 36; 17 and 30 are sealoop's from 4e-0, lowered in sl3hirl). Line range of this file:
9020 REM 9000-29999. Ownership (rule 15): 9890 tells an owned reference value by its node (a call, a library call, an ifx, an anew, a seq or xblk of one, a retained snapshot); its consumer releases it. Scope stack (rule 16): J(k,2) the registers of
9025 REM the bound locals that hold counts and of the hidden vectors of element loops (L4's H), J9 entries; J(k,4) = 0, or for the .t local of a seq the frame of the node that consumes the seq's value (released when that node completes). Loop stack:
9030 REM J(j,1) the loop block, J(j,3) the scope height at the loop. An idx node keeps its base register in H(idx,0) for $ (rule 18); a deferred ref argument (rule 31) is flagged H(rarg,0) = 1, its index registers in H(rarg,5) and H(rarg,6).
9110 REM ====================================================================================
9120 REM ---- the constants and entries of phase 4 (called once at the start) --------------
9130 LET G1 = FNQ("ARR_RC")
9160 LET G2 = FNQ("ARR_ROWS")
9190 LET G3 = FNQ("ARR_COLS")
9220 LET G4 = FNQ("ARR_DATA")
9250 LET G5 = FNQ("EK_F64")
9280 LET G6 = FNQ("EK_I64")
9310 LET G7 = FNQ("EK_BOOL")
9340 LET G8 = FNQ("ESIZE_BOOL")
9370 LET G9 = FNQ("ESIZE_PTR")
9400 LET Y3 = FNE("ARR_NEW", "")
9430 LET Y4 = FNE("ARR_NEW_U", "")
9460 LET Y5 = FNE("ARR_UNIQUE", "")
9482 LET H9 = FNQ("STR_LEN")
9487 LET I1 = FNQ("EK_STR")
9490 IF Y$(Y3, 4) <> "iiii" THEN 9550
9500 IF Y$(Y3, 5) <> "p" THEN 9550
9510 IF Y$(Y4, 4) <> "iiii" THEN 9550
9520 IF Y$(Y4, 5) <> "p" THEN 9550
9530 IF Y$(Y5, 4) <> "p" THEN 9550
9540 IF Y$(Y5, 5) = "p" THEN 9555
9550 CALL "dg_bug": P$, "entry ARR_NEW, ARR_NEW_U (iiii, p) or ARR_UNIQUE (p, p) is not as expected"
9555 LET U1 = FNE("ARR_NEW_S", "")
9560 RETURN
9570 REM ---- FNE(Q3$, Q4$) = the row of the entry Q3$ (its last row; the loop clobbers the global I); not there: dg_bug "entry Q3$Q4$ is not ..." -
9580 DEF FNE(Q3$, Q4$)
9590 FOR I = 1 TO Y0
9600 IF Y$(I, 1) <> Q3$ THEN 9620
9610 LET FNE = I
9620 NEXT I
9630 IF FNE > 0 THEN 9650
9640 CALL "dg_bug": P$, "entry " & Q3$ & Q4$ & " is not in the entries table"
9650 FNEND
9660 REM ---- reading: the records idx dol (nodes) and tmat, tptr (types; sea.hirl nodes: 981) ------
9670 IF K = 42 THEN 1310
9672 IF K = 41 THEN 40030
9673 IF K = 59 THEN 40030
9675 IF K = 52 THEN 30100
9676 IF K > 64 THEN 850
9677 IF K > 61 THEN 52850
9680 IF K > 38 THEN 850
9690 GOTO 1300
9700 REM ---- dispatch of the node kinds 39-40 (43-51: sl3hirl) and of the resume codes 39-52 (60-65) -
9705 IF H(X, 1) > 42 THEN 31996
9710 ON H(X, 1) - 38 GOTO 12800, 13290, 2365, 2365
9715 IF S > 59 THEN 32010
9720 ON S - 38 GOTO 12860, 8005, 13620, 13740, 13870, 14270, 53520, 8005, 2365, 2365, 8005, 14900, 24210, 24350
9730 REM ---- class of an array or tptr type (7395 for T1 > 5): p ----------------------------------
9740 IF T1 <= 9 THEN 2360
9750 IF T(T1, 1) = 2 THEN 2360
9770 LET C1 = 3
9780 RETURN
9790 REM ==== small helpers ---- 9802: U3 = 1 if the type T3 holds counts (layout); 9810: if it is a reference type (str, an array, a handle)
9802 LET U3 = 0
9804 IF T3 < 2 THEN 9870
9806 IF O(T3, 3) > 0 THEN 9860
9808 RETURN
9810 LET U3 = 0
9820 IF T3 < 5 THEN 9870
9830 IF T3 <= 9 THEN 9860
9840 IF T(T3, 1) = 1 THEN 9860
9850 IF T(T3, 1) <> 3 THEN 9870
9860 LET U3 = 1
9870 RETURN
9880 REM ---- 9890: Z0 = 1 if node X0 is an owned reference value (rule 15; anew, xblk: 15 (k); an iblk, R26) -----
9890 LET Z0 = 0
9900 LET P5 = X0
9910 LET T3 = H(P5, 4)
9920 GOSUB 9802
9930 IF U3 = 0 THEN 10060
9940 IF H(P5, 1) = 10 THEN 10050
9945 IF H(P5, 1) = 8 THEN 10050
9950 IF H(P5, 1) = 12 THEN 42620
9955 IF H(P5, 1) = 39 THEN 42630
9960 IF H(P5, 1) = 17 THEN 10050
9962 IF H(P5, 1) = 50 THEN 10050
9963 IF H(P5, 1) = 48 THEN 42652
9964 IF H(P5, 1) = 43 THEN 33300
9965 IF H(P5, 1) = 61 THEN 10050
9966 IF H(P5, 1) = 60 THEN 53334
9967 IF H(P5, 1) = 65 THEN 10050
9970 IF H(P5, 1) <> 5 THEN 10000
9980 IF H(P5, 6) = 1 THEN 10050
9990 RETURN
10000 IF H(P5, 1) <> 19 THEN 10060
10010 LET P5 = H(P5, 7)
10020 IF H(P5, 8) = 0 THEN 9910
10030 LET P5 = H(P5, 8)
10040 GOTO 10020
10050 LET Z0 = 1
10060 RETURN
10070 REM ---- 10080: release the value R0 of the child X0 if it is a temporary (rule 15 (b)) ------
10080 GOSUB 9890
10090 IF Z0 = 0 THEN 10120
10100 LET V1 = R0
10110 GOSUB 10140
10120 RETURN
10130 REM ---- 10140 / 10180: release / retain the register V1 (a home: its reference values, 50100); 10135: release J(K6, 2) -
10135 LET V1 = J(K6, 2)
10140 LET L2$ = "release"
10145 IF V(V1, 0) = 1 THEN 50100
10150 LET L1$ = L2$ & FNR$(V1)
10170 GOTO 7695
10180 LET L2$ = "retain"
10190 GOTO 10145
10220 REM ---- 10230: retain R9, the value of child X0, if it is a borrowed reference (rule 15 (a))
10230 LET T3 = H(X0, 4)
10240 GOSUB 9802
10250 IF U3 = 0 THEN 10300
10260 GOSUB 9890
10270 IF Z0 = 1 THEN 10300
10280 LET V1 = R9
10290 GOSUB 10180
10300 RETURN
10310 REM ---- 10320: push the register V1 on the scope stack (rule 16) -------------------------
10320 LET Q2$ = "symbols"
10330 IF J9 >= 59999 THEN 2390
10340 LET J9 = J9 + 1
10350 LET J(J9, 2) = V1
10360 LET J(J9, 4) = 0
10365 LET J(J9, 0) = 0
10370 RETURN
10380 REM ---- 10390: release the scope stack entries J9 down to U4 + 1 (it stays as it is) --------
10390 FOR K6 = J9 TO U4 + 1 STEP -1
10395 IF J(K6, 0) = 2 THEN 10420
10400 GOSUB 10135
10420 NEXT K6
10430 RETURN
10440 REM ---- 10450: the node of frame W0 is done: release the .t locals of the seqs it consumed
10450 IF J9 = 0 THEN 10570
10460 IF J(J9, 4) <> W0 THEN 10570
10470 LET K7 = J9
10480 IF K7 = 0 THEN 10520
10490 IF J(K7, 4) <> W0 THEN 10520
10500 LET K7 = K7 - 1
10510 GOTO 10480
10520 FOR K6 = K7 + 1 TO J9
10530 GOSUB 10135
10550 NEXT K6
10560 LET J9 = K7
10570 RETURN
10580 REM ---- 10590: N2 = a new i register loaded with li Z3; 10585: with li 0 --------------------------
10585 LET Z3 = 0
10590 GOSUB 7416
10610 LET L1$ = "li" & FNR$(N2) & " " & STR$(Z3)
10620 GOSUB 7865
10650 GOTO 7695
10670 REM ---- 10680: N2 = ext(V3, Z3) (rule 17) / 10740: N2 = data(V3) ---------------------------
10680 IF F6 = 1 THEN 41242
10685 GOSUB 7416
10700 LET V2 = N2
10710 LET Z3 = G2 + Z3 * (G3 - G2)
10720 GOTO 7640
10740 IF F6 = 1 THEN 41250
10745 GOSUB 7418
10760 LET V2 = N2
10770 LET Z3 = G4
10780 GOTO 7640
10800 REM ---- 10810: chkb V2 V3 Z3 with the site of node X ---------------------------------------
10810 LET L1$ = "chkb" & FNR$(V2) & FNR$(V3) & " " & STR$(Z3)
10870 GOSUB 7775
10880 LET L1$ = L1$ & " " & Z9$
10890 GOTO 7695
10910 REM ---- 10920: the bounds checks of array R6 for the indices R1 (and R2); R3 = its rows -----
10920 LET V3 = R6
10930 LET Z3 = 0
10940 GOSUB 10680
10950 LET R3 = N2
10960 LET V2 = R1
10970 LET V3 = R3
10980 LET Z3 = 0
10990 GOSUB 10810
11000 IF R2 = 0 THEN 11080
11010 LET V3 = R6
11020 LET Z3 = 1
11030 GOSUB 10680
11040 LET V2 = R2
11050 LET V3 = N2
11060 LET Z3 = 1
11070 GOSUB 10810
11080 RETURN
11090 REM ---- 11100: R5 = the linear index of R1 (and R2, rows R3): imul T I1 E0, iadd X I0 T; 11095: with R4 = N2
11095 LET R4 = N2
11100 LET R5 = R1
11110 IF R2 = 0 THEN 11270
11120 GOSUB 7416
11140 LET V2 = N2
11150 LET L1$ = "imul" & FNR$(V2) & FNR$(R2) & FNR$(R3)
11160 GOSUB 7620
11190 LET R7 = V2
11200 GOSUB 7420
11210 LET R5 = N2
11220 LET V4 = R7
11230 LET L1$ = "iadd" & FNR$(R5) & FNR$(R1) & FNR$(V4)
11240 GOSUB 7620
11270 RETURN
11280 REM ---- 11300: element type T2 -> C3 (1 i64, 2 f64, 3 bool: the letter of SEG$("ifb")), Z3 the scale (the element size)
11300 LET C3 = 1
11310 LET Z3 = E7
11320 IF T2 = 3 THEN 11390
11330 LET C3 = 2
11340 LET Z3 = E8
11350 IF T2 = 4 THEN 11390
11352 LET C3 = 4
11354 LET Z3 = G9
11356 IF T2 = 5 THEN 11390
11360 LET C3 = 3
11370 LET Z3 = G8
11380 IF T2 > 9 THEN 52740
11385 IF T2 <> 2 THEN 2360
11390 RETURN
11400 REM ---- 11410: L1$ = O$ V2 V3 V4 Z3 0 (a load or store at base V3, index V4, scale Z3) ------
11410 LET L1$ = O$ & FNR$(V2) & FNR$(V3) & FNR$(V4) & " " & STR$(Z3) & " " & STR$(M4)
11420 GOTO 7695
11520 REM ---- 11530: L1$ = O$ V2 V3 V4 V5 --------------------------------------------------------
11530 LET L1$ = O$ & FNR$(V2) & FNR$(V3) & FNR$(V4) & FNR$(V5)
11540 GOTO 7695
11670 REM ---- 11690: copy on write (rule 19) of the local array C8 (C7 = 0) or of the array in the memory of the ref parameter C7; C8 = the array afterwards
11690 IF F6 = 1 THEN 41252
11692 IF C7 = 0 THEN 11770
11700 GOSUB 7418
11720 LET C8 = N2
11730 LET L1$ = SEG$("ldildfldp", 3 * V(C8, 1) - 2, 3 * V(C8, 1)) & FNR$(C8) & FNR$(C7) & " - 0 " & STR$(S1)
11740 GOSUB 7695
11770 GOSUB 7416
11790 LET C9 = N2
11800 LET L1$ = SEG$("ldildfldp", 3 * V(C9, 1) - 2, 3 * V(C9, 1)) & FNR$(C9) & FNR$(C8) & " - 0 " & STR$(G1)
11810 GOSUB 7695
11840 LET Z3 = 1
11850 GOSUB 10590
11860 LET V4 = N2
11870 GOSUB 7416
11890 LET V2 = N2
11900 LET L1$ = "icmp ne" & FNR$(V2) & FNR$(C9) & FNR$(V4)
11910 GOSUB 7620
11930 LET C9 = V2
11940 GOSUB 7885
11950 LET C6 = B7
11960 LET L1$ = "if " & STR$(C6) & FNR$(C9)
12000 GOSUB 7695
12010 GOSUB 7418
12030 LET C9 = N2
12040 LET Q9 = Y5
12050 GOSUB 5590
12060 LET L1$ = L1$ & FNR$(C9) & " 1" & FNR$(C8)
12120 GOSUB 7695
12130 IF C7 = 0 THEN 12180
12140 LET Z3 = S1
12150 LET L1$ = SEG$("stistfstp", 3 * V(C9, 1) - 2, 3 * V(C9, 1)) & FNR$(C9) & FNR$(C7) & " - 0 " & STR$(Z3)
12160 GOSUB 7695
12180 LET O$ = "mov"
12190 LET V2 = C8
12200 LET V3 = C9
12210 GOSUB 7540
12220 LET L1$ = "endif " & STR$(C6)
12230 GOTO 7695
12780 REM ==== element reads by scalar indices (rule 18) frame: x1 = U0 at entry (U: the base, then the indices), x2 = the next child
12800 LET W(W0 + 3) = U0
12810 LET W(W0 + 4) = H(X, 7)
12820 LET S = 39
12830 LET X1 = H(X, 7)
12840 GOTO 7375
12860 GOSUB 7966
12890 LET H(X, 0) = R9
12900 LET S = 40
12910 GOTO 8007
13000 LET Z6 = W(W0 + 3)
13010 IF U0 - Z6 <> H(X, 6) + 1 THEN 2365
13020 LET R6 = U(Z6 + 1, 1)
13025 LET O5 = H(X, 7)
13026 GOSUB 41230
13030 LET R1 = U(Z6 + 2, 1)
13040 LET R2 = 0
13050 IF H(X, 6) = 1 THEN 13080
13060 IF H(X, 6) <> 2 THEN 2360
13070 LET R2 = U(Z6 + 3, 1)
13080 GOSUB 10920
13090 LET V3 = R6
13100 GOSUB 10740
13110 GOSUB 11095
13130 LET Q0 = R4
13140 LET M2 = R5
13150 LET X0 = X
13160 LET M8 = H(X, 4)
13170 LET M4 = 0
13180 IF H(W(W0 - 6), 1) = 60 THEN 52200
13190 LET M3 = O(T(H(H(X, 7), 4), 2), 1)
13200 GOSUB 50300
13210 GOSUB 42668
13220 LET R9 = D2
13230 LET U0 = W(W0 + 3)
13240 LET X0 = H(X, 7)
13250 LET R0 = R6
13260 GOSUB 10080
13270 GOTO 3090
13280 REM ---- dol: ext of the base of the innermost enclosing idx, at its place (rule 18) ---------
13290 LET P3 = X + 1
13300 IF P3 > H0 THEN 2365
13310 IF H(P3, 1) <> 39 THEN 13350
13320 LET P4 = P3
13330 GOSUB 13480
13340 IF P4 <= X THEN 13370
13350 LET P3 = P3 + 1
13360 GOTO 13300
13370 IF H(P3, 0) + H(H(P3, 7), 0) = 0 THEN 53760
13380 IF H(X, 5) > H(P3, 6) - 1 THEN 2365
13390 GOSUB 7468
13405 LET O5 = H(P3, 7)
13406 GOSUB 41230
13407 IF F5 = 1 THEN 41280
13410 LET Z3 = G2 + H(X, 5) * (G3 - G2)
13420 LET L1$ = SEG$("ldildfldp", 3 * V(D2, 1) - 2, 3 * V(D2, 1)) & FNR$(D2) & FNR$(H(P3, 0) + H(H(P3, 7), 0) * (1 - SGN(H(P3, 0)))) & " - 0 " & STR$(Z3)
13430 GOTO 7662
13470 REM ---- 13480: P4 = the first node of the subtree of P4 (post-order) ------------------------
13480 IF H(P4, 7) = 0 THEN 13510
13490 LET P4 = H(P4, 7)
13500 GOTO 13480
13510 RETURN
13520 REM ==== element stores by scalar indices and copy on write (rules 19, 15 (i)) frame: x1 = U0 at entry, x3 = the U entries before the indices: set 2 (the value, the base), op 1 (the base); U then holds the indices, and for op the old element T
13550 LET W(W0 + 3) = U0
13560 LET W(W0 + 5) = 2
13570 IF H(X, 5) > 1 THEN 13690
13580 LET S = 41
13590 LET X1 = H(X2, 8)
13600 GOTO 7375
13620 GOSUB 7966
13650 LET S = 42
13660 LET X1 = H(H(X, 7), 7)
13670 GOTO 7375
13690 LET W(W0 + 5) = 1
13700 LET S = 42
13710 GOTO 7361
13740 IF H(H(H(X, 7), 7), 1) <> 5 THEN 2360
13750 GOSUB 7966
13780 LET H(H(X, 7), 0) = R9
13790 LET X1 = H(H(H(X, 7), 7), 8)
13800 FOR I = 1 TO U0 - W(W0 + 3) - W(W0 + 5)
13810 LET X1 = H(X1, 8)
13820 NEXT I
13830 IF X1 = 0 THEN 13910
13840 LET S = 43
13850 GOTO 7375
13870 GOSUB 7966
13900 GOTO 13790
13910 LET Z6 = W(W0 + 3) + W(W0 + 5)
13920 IF U0 - Z6 <> H(H(X, 7), 6) THEN 2365
13930 LET R6 = U(Z6, 1)
13940 LET R1 = U(Z6 + 1, 1)
13950 LET R2 = 0
13960 IF H(H(X, 7), 6) = 1 THEN 13990
13970 IF H(H(X, 7), 6) <> 2 THEN 2360
13980 LET R2 = U(Z6 + 2, 1)
13990 IF H(X, 5) > 1 THEN 14045
14000 LET T4 = U(W(W0 + 3) + 1, 1)
14005 LET Y6 = H(X, 7)
14007 GOSUB 24820
14010 GOSUB 14630
14020 GOTO 3083
14040 REM op: the read into T by rule 18, then the value
14045 LET Y6 = H(X, 7)
14047 GOSUB 24820
14050 GOSUB 10920
14060 LET V3 = R6
14070 GOSUB 10740
14080 GOSUB 11095
14100 LET T2 = H(H(X, 7), 4)
14110 GOSUB 11300
14120 LET C1 = 1 + INT(C3 / 2) - INT(C3 / 3)
14130 GOSUB 7420
14140 LET O$ = "ld" & SEG$("ifb", C3, C3)
14150 LET V2 = N2
14160 LET V3 = R4
14170 LET V4 = R5
14175 LET M4 = 0
14180 GOSUB 11410
14190 GOSUB 7970
14200 LET U(U0, 1) = V2
14220 LET S = 44
14230 GOTO 7368
14260 REM the operation into a new register R (rule 1), then the checks again, cow and the store
14270 LET A2 = U(U0, 1)
14275 LET Y6 = H(X, 7)
14280 GOSUB 7393
14300 LET A3 = H(X, 5) - 1
14310 LET O$ = SEG$("faddfsubfmulfdiv", 4 * A3 - 3, 4 * A3)
14320 IF C1 = 2 THEN 14370
14330 IF C1 <> 1 THEN 2360
14340 IF A3 = 4 THEN 2360
14350 LET O$ = SEG$("iaddcisubcimulc", 5 * A3 - 4, 5 * A3)
14360 GOSUB 7775
14370 GOSUB 7420
14380 LET V2 = N2
14390 LET L1$ = O$ & FNR$(V2) & FNR$(A2) & FNR$(R9)
14400 GOSUB 7620
14420 LET T4 = V2
14430 LET Z6 = W(W0 + 3) + 1
14440 LET R6 = U(Z6, 1)
14450 LET R1 = U(Z6 + 1, 1)
14460 LET R2 = 0
14470 IF H(H(X, 7), 6) = 1 THEN 14490
14480 LET R2 = U(Z6 + 2, 1)
14490 LET A1 = H(H(H(X, 7), 7), 5)
14495 IF V(A1, 0) = 1 THEN 14580
14500 IF A(G(F0, 0) + A1, 2) = 0 THEN 14580
14510 GOSUB 7418
14530 LET R6 = N2
14540 LET L1$ = SEG$("ldildfldp", 3 * V(R6, 1) - 2, 3 * V(R6, 1)) & FNR$(R6) & FNR$(A1) & " - 0 0"
14550 GOSUB 7695
14580 GOSUB 14630
14590 GOTO 3083
14610 REM ---- 14630: (3)-(5) of rule 19: the checks of array R6, cow, data, the linear index and the store of T4 (the base is the lv of a local or of a ref parameter)
14630 LET O5 = H(Y6, 7)
14632 GOSUB 41230
14634 LET A1 = H(H(Y6, 7), 5)
14640 LET C7 = 0
14650 LET C8 = A1
14660 IF A(G(F0, 0) + A1, 2) = 0 THEN 14680
14670 LET C7 = A1
14680 GOSUB 10920
14690 GOSUB 11690
14700 LET V3 = C8
14710 GOSUB 10740
14720 GOSUB 11095
14740 LET T2 = H(Y6, 4)
14750 GOSUB 11300
14760 LET O$ = "st" & SEG$("ifb", C3, C3)
14770 LET V2 = T4
14780 LET V3 = R4
14790 LET V4 = R5
14795 LET M4 = 0
14800 GOTO 11410
14820 REM ==== asg set to a local of a reference type (rule 15 (d)): V, release L, mov L V ==========
14830 IF H(X, 5) > 1 THEN 6120
14840 GOSUB 7418
14860 LET W(W0 + 3) = N2
14870 LET S = 50
14880 LET D1 = N2
14890 GOTO 7380
14900 LET X0 = H(H(X, 7), 8)
14910 GOSUB 42000
14920 LET A1 = H(H(X, 7), 5)
14930 LET V1 = A1
14940 GOSUB 10140
14950 LET L1$ = "mov" & FNR$(A1) & FNR$(W(W0 + 3))
14960 GOSUB 7620
14990 GOTO 3090
15000 REM ---- asg set to a ref parameter P of a reference type (rule 31): ldp O P, stp V P, release O
15010 LET A1 = H(H(X, 7), 5)
15020 LET T3 = A(G(F0, 0) + A1, 1)
15030 GOSUB 9810
15040 IF U3 = 0 THEN 6275
15050 LET X0 = H(H(X, 7), 8)
15060 LET R9 = W(W0 + 3)
15070 GOSUB 42000
15080 GOSUB 7418
15100 LET C8 = N2
15110 LET L1$ = SEG$("ldildfldp", 3 * V(C8, 1) - 2, 3 * V(C8, 1)) & FNR$(C8) & FNR$(A1) & " - 0 0"
15120 GOSUB 7695
15150 LET V2 = W(W0 + 3)
15160 LET V3 = A1
15170 LET Z3 = 0
15180 GOSUB 7650
15190 LET V1 = C8
15200 GOSUB 10140
15210 GOTO 3090
15220 REM ==== bind (rules 15 (a), 16): a borrowed reference is retained; the local is bound ==========
15230 LET A1 = H(X, 5)
15240 LET T3 = A(G(F0, 0) + A1, 1)
15250 GOSUB 9810
15260 IF U3 = 0 THEN 3090
15270 LET X0 = H(X, 7)
15280 LET R9 = A1
15290 GOSUB 10230
15300 IF H(W(W0 - 6), 1) = 19 THEN 3090
15310 GOSUB 10450
15320 LET V1 = A1
15330 GOSUB 10320
15340 GOTO 3090
15350 REM ---- seq done: its .t locals that hold counts wait for the node that consumes its value --
15360 LET P3 = H(X, 7)
15370 IF H(P3, 8) = 0 THEN 3090
15380 LET T3 = A(G(F0, 0) + H(P3, 5), 1)
15390 GOSUB 9802
15400 IF U3 = 0 THEN 15440
15410 LET V1 = H(P3, 5)
15420 GOSUB 10320
15430 GOSUB 33400
15440 LET P3 = H(P3, 8)
15450 GOTO 15370
15460 REM ---- tbind done: a _ result that holds counts is released, the locals are bound ----------
15470 FOR I = W(W0 + 3) + 1 TO U0
15480 LET V1 = U(I, 1)
15490 IF V(V1, 1) <> 3 THEN 15520
15500 IF V1 <= N7 THEN 15520
15510 GOSUB 10140
15520 NEXT I
15530 GOSUB 10450
15540 FOR I = W(W0 + 3) + 1 TO U0
15550 LET V1 = U(I, 1)
15560 IF V(V1, 1) <> 3 THEN 15590
15570 IF V1 > N7 THEN 15590
15580 GOSUB 10320
15590 NEXT I
15600 GOTO 3083
15620 REM ---- tasg: a reference-type local L gets release L before mov L V (rule 15 (d)) --------
15630 LET V1 = A2
15640 GOSUB 10140
15650 GOTO 8467
15660 REM a ref parameter P of a reference type: ldp O P, stp V P, release O (rule 31)
15670 LET C8 = V2
15680 GOSUB 7418
15700 LET C9 = N2
15710 LET L1$ = SEG$("ldildfldp", 3 * V(C9, 1) - 2, 3 * V(C9, 1)) & FNR$(C9) & FNR$(A2) & " - 0 0"
15720 GOSUB 7695
15750 LET Z3 = 0
15760 LET L1$ = SEG$("stistfstp", 3 * V(C8, 1) - 2, 3 * V(C8, 1)) & FNR$(C8) & FNR$(A2) & " - 0 " & STR$(Z3)
15770 GOSUB 7695
15790 LET V1 = C9
15800 GOSUB 10140
15810 GOTO 8480
15820 REM a _ component that holds counts is released after the stores (rule 15 (h))
15830 FOR I = W(W0 + 3) + 1 TO U0
15840 IF U(I, 2) <> 0 THEN 15890
15850 IF U(I, 1) <= N7 THEN 15890
15860 IF V(U(I, 1), 1) <> 3 THEN 15890
15870 LET V1 = U(I, 1)
15880 GOSUB 10140
15890 NEXT I
15900 RETURN
15910 REM ==== eval (rule 15 (h)): an owned result is released after the statement ==================
15920 LET X1 = H(X, 7)
15930 LET W(W0 + 3) = U0
15940 LET D1 = -1
15950 LET T3 = H(X1, 4)
15960 GOSUB 9802
15970 IF U3 = 0 THEN 16000
15980 LET D1 = 0
15990 GOTO 16190
16000 IF T3 <= 9 THEN 16190
16010 IF T(T3, 1) <> 2 THEN 16190
16020 LET Z6 = T3
16030 LET K7 = 0
16040 FOR I = 1 TO T(Z6, 2)
16050 LET T3 = M(T(Z6, 3) + I - 1)
16060 GOSUB 9802
16070 LET K7 = K7 + U3
16080 NEXT I
16090 IF K7 = 0 THEN 16190
16100 FOR I = 1 TO T(Z6, 2)
16110 LET T1 = M(T(Z6, 3) + I - 1)
16112 GOSUB 40595
16116 IF F5 = 1 THEN 41084
16120 GOSUB 7395
16130 GOSUB 7420
16140 GOSUB 7970
16150 LET U(U0, 1) = N2
16170 NEXT I
16180 LET D1 = -2
16190 LET S = 21
16200 GOTO 7380
16210 IF W(W0 + 3) < U0 THEN 16280
16220 LET T3 = H(H(X, 7), 4)
16230 GOSUB 9802
16240 IF U3 = 0 THEN 3090
16250 LET V1 = R9
16260 GOSUB 10140
16270 GOTO 3090
16280 FOR I = W(W0 + 3) + 1 TO U0
16290 IF V(U(I, 1), 1) <> 3 THEN 16320
16300 LET V1 = U(I, 1)
16310 GOSUB 10140
16320 NEXT I
16330 GOTO 3083
16350 REM ==== ifx arms of a reference type are owned in the destination (rule 15 (b)) =============
16360 IF W(W0 + 5) > 0 THEN 40784
16362 LET X0 = H(H(X, 7), 8)
16370 LET R9 = W(W0 + 3)
16380 GOSUB 10230
16390 GOTO 4100
16400 IF W(W0 + 5) > 0 THEN 40784
16402 LET X0 = H(H(H(X, 7), 8), 8)
16410 LET R9 = W(W0 + 3)
16420 GOSUB 10230
16430 GOTO 4130
16440 REM ==== lv: a snapshot of a reference value before a ref call is retained (rule 12 (a), (b))
16450 IF H(X, 6) = 0 THEN 3090
16460 LET T3 = H(X, 4)
16470 GOSUB 9810
16480 IF U3 = 0 THEN 3090
16490 LET V1 = R9
16500 GOSUB 10180
16510 GOTO 3090
16520 REM ==== ret and tret (rule 16 (c)): the values owned, then every bound local released ========
16530 LET X0 = W(W0 + 4)
16540 GOTO 10230
16560 GOSUB 10450
16570 LET U4 = 0
16580 GOSUB 10390
16590 GOTO 7170
16610 REM ==== block end (rule 16 (a), R11): its owned tmps, then its bound locals in reverse (41690); none after a last ret, tret or iret, nor at the end of the body of an iblk with k >= 1 (R29)
16620 LET U4 = W(W0 + 3)
16630 IF J9 = U4 THEN 3090
16635 IF H(W(W0 - 6), 1) + 100 * SGN(H(W(W0 - 6), 6)) = 165 THEN 16730
16640 IF X <> G(F0, 8) THEN 16660
16650 IF G(F0, 3) <> 1 THEN 16730
16660 LET P3 = H(X, 7)
16670 IF H(P3, 8) = 0 THEN 16700
16680 LET P3 = H(P3, 8)
16690 GOTO 16670
16700 IF H(P3, 1) = 30 THEN 16730
16710 IF H(P3, 1) = 31 THEN 16730
16715 IF H(P3, 1) = 66 THEN 16730
16720 GOSUB 41690
16730 LET J9 = U4
16740 GOTO 3090
16750 REM ==== ref arguments (rules 12, 31) ---- 16780: Z0 = 1 if the ref argument X2 with root A1 is deferred: a later argument of the call contains a call that passes the same root by ref (rule 31)
16780 LET Z0 = 0
16790 LET P6 = H(X2 + 1 - SGN(ABS(H(X2 + 1, 1) - 44)), 8)
16800 IF P6 = 0 THEN 16950
16810 LET P4 = P6
16820 GOSUB 13480
16830 LET P8 = P6
16840 IF H(P6, 1) <> 11 THEN 16860
16850 LET P8 = P6 - 1
16860 FOR P9 = P4 TO P8
16870 IF H(P9, 1) <> 11 THEN 16910
16880 LET P3 = P9
16890 GOSUB 16970
16900 IF P3 = A1 THEN 16940
16910 NEXT P9
16920 LET P6 = H(P6, 8)
16930 GOTO 16800
16940 LET Z0 = 1
16950 RETURN
16960 REM ---- 16970: P3 = the root local of the rarg P3 (an lv, or the base lv of an idx or fld path)
16970 LET P3 = H(P3, 7)
16980 IF ABS(H(P3, 1) - 49.5) = 10.5 THEN 16970
17000 IF H(P3, 1) <> 5 THEN 2360
17010 LET P3 = H(P3, 5)
17020 RETURN
17030 REM ---- a local passed by ref: its slot gets a p of SEA_ESIZE_PTR bytes ---------------------
17040 LET Z1 = G9
17050 GOTO 4560
17060 REM ---- a deferred local: the slot now, the store just before the call ---------------------
17070 GOSUB 16780
17080 LET H(X2, 0) = Z0
17090 IF Z0 = 1 THEN 4620
17100 GOTO 4600
17600 REM ---- 17680 (rule 31, 53704): R9 = the address of the element R1 (R2) of the idx X3 after the checks (rows R3) and the cow of its array C8: data, the linear index, li S esize, imul T X S, padd A D T
17680 LET V3 = C8
17690 GOSUB 10740
17700 GOSUB 11095
17720 LET T2 = H(X3, 4)
17730 GOSUB 11300
17740 GOSUB 10590
17750 LET V4 = N2
17760 GOSUB 7416
17780 LET V2 = N2
17790 LET L1$ = "imul" & FNR$(V2) & FNR$(R5) & FNR$(V4)
17800 GOSUB 7620
17820 LET R7 = V2
17830 GOSUB 7418
17850 LET V2 = N2
17860 LET V4 = R7
17870 LET L1$ = "padd" & FNR$(V2) & FNR$(R4) & FNR$(V4)
17880 GOSUB 7620
17900 LET R9 = V2
17910 RETURN
17920 REM ---- just before the call: the rest of each deferred ref argument, in argument order ------
17930 LET X2 = H(X, 7)
17940 LET K7 = W(W0 + 3)
17950 IF X2 = 0 THEN 4660
17960 LET K7 = K7 + 1
17970 IF H(X2, 1) <> 11 THEN 18230
17980 IF H(X2, 0) <> 1 THEN 18230
17990 IF ABS(H(H(X2, 7), 1) - 49.5) = 10.5 THEN 18070
18000 REM a local: the store of its current value into its slot
18010 LET V2 = U(K7, 2)
18020 LET V3 = U(K7, 1)
18030 LET Z3 = 0
18040 GOSUB 7650
18050 GOTO 18230
18060 REM an element or field path: the extents and checks again (the call's line), the cows, the address (53620)
18070 GOSUB 53600
18080 LET J7 = 1
18090 LET J8 = 0
18100 GOSUB 53620
18110 LET U(K7, 1) = R9
18230 LET X2 = H(X2, 8)
18240 GOTO 17950
18250 REM ---- after the call: the temporaries among its arguments are released (rule 15 (b)) ----
18260 LET X0 = H(X, 7)
18270 LET K7 = W(W0 + 3)
18280 IF X0 = 0 THEN 18350
18290 LET K7 = K7 + 1
18300 IF H(X0, 1) = 11 THEN 18330
18310 LET R0 = U(K7, 1)
18320 GOSUB 10080
18330 LET X0 = H(X0, 8)
18340 GOTO 18280
18350 RETURN
19340 REM ==== library functions of 4d (rule 36): the arguments, then the function; zeros ones filled len rows cols numel reach sea.hirl as sealoop's records (3.5.9 L1-L3); sort argsort (R16, rule 24) at 33600. W2 counts from 8 frame: x1 = U0 at
19345 REM entry (the arguments above it), x2 = the next argument, x3 = the function; 19575: the result is D2 (R9 = D2), the arguments popped
19360 LET K4$ = "|abs     |sign    |sqrt    |floor   |ceil    |trunc   |round   |isnan   |min     |max     |where   |ind2sub |sub2ind |sort    |argsort |str     |lower   |args    |print   |make_dir "
19370 LET W2$ = S$(H(X, 0))
19380 LET W2 = INT((POS(K4$, "|" & W2$ & " ") + 8) / 9)
19390 IF W2 = 0 THEN 2360
19395 LET W2 = W2 + 7
19400 IF H(X, 6) < VAL(SEG$("112111111111111223232211011", W2, W2)) THEN 2360
19410 IF H(X, 6) > VAL(SEG$("223111111111111223232211011", W2, W2)) THEN 2360
19420 LET W(W0 + 5) = W2
19430 LET S = 49
19440 GOTO 8000
19550 LET Z6 = W(W0 + 3)
19560 LET W2 = W(W0 + 5)
19570 ON W2 - 7 GOTO 20870, 21210, 22060, 22060, 22060, 22060, 22060, 22190, 22310, 22310, 22600, 22730, 22980, 33600, 33600, 42400, 42400, 42400, 34000, 34000
19575 LET R9 = D2
19580 GOTO 3083
20860 REM ---- the exact math functions on scalars (rule 36) ------------------------------------
20870 LET A1 = U(Z6 + 1, 1)
20880 GOSUB 7393
20900 IF C1 = 1 THEN 20930
20910 LET O$ = "fabs"
20920 GOTO 22090
20930 GOSUB 10585
20950 LET R1 = N2
20960 GOSUB 7416
20980 LET V2 = N2
20990 LET L1$ = "icmp lt" & FNR$(V2) & FNR$(A1) & FNR$(R1)
21000 GOSUB 7620
21030 LET R2 = V2
21040 GOSUB 7420
21050 LET R3 = N2
21060 LET O$ = "inegc"
21070 LET V2 = R3
21080 LET V3 = A1
21090 GOSUB 7775
21100 GOSUB 7540
21110 GOSUB 7468
21130 LET V4 = R3
21140 LET V5 = A1
21150 LET L1$ = "isel" & FNR$(D2) & FNR$(R2) & FNR$(V4) & FNR$(V5)
21160 GOTO 7666
21210 LET A1 = U(Z6 + 1, 1)
21220 GOSUB 7393
21240 IF C1 = 1 THEN 21800
21250 GOSUB 7411
21270 LET R1 = N2
21280 LET L1$ = "lf" & FNR$(R1) & " #0000000000000000"
21290 GOSUB 7670
21330 GOSUB 7420
21340 LET R2 = N2
21350 LET L1$ = "lf" & FNR$(R2) & " #3FF0000000000000"
21360 GOSUB 7670
21400 GOSUB 7420
21410 LET R3 = N2
21420 LET L1$ = "lf" & FNR$(R3) & " #BFF0000000000000"
21430 GOSUB 7670
21470 GOSUB 7416
21490 LET V2 = N2
21500 LET L1$ = "fcmp gt" & FNR$(V2) & FNR$(A1) & FNR$(R1)
21510 GOSUB 7620
21540 LET R4 = V2
21550 GOSUB 7420
21560 LET V2 = N2
21570 LET L1$ = "fcmp lt" & FNR$(V2) & FNR$(A1) & FNR$(R1)
21580 GOSUB 7620
21610 LET R5 = V2
21620 GOSUB 7411
21640 LET V2 = N2
21650 LET L1$ = "fsel" & FNR$(V2) & FNR$(R5) & FNR$(R3) & FNR$(A1)
21660 GOSUB 7695
21700 LET R6 = V2
21710 GOSUB 7470
21720 LET V4 = R2
21730 LET V5 = R6
21740 LET L1$ = "fsel" & FNR$(D2) & FNR$(R4) & FNR$(V4) & FNR$(V5)
21750 GOTO 7666
21800 GOSUB 10585
21820 LET R1 = N2
21830 GOSUB 7416
21850 LET V2 = N2
21860 LET L1$ = "icmp gt" & FNR$(V2) & FNR$(A1) & FNR$(R1)
21870 GOSUB 7620
21900 LET R2 = V2
21910 GOSUB 7420
21920 LET V2 = N2
21930 LET L1$ = "icmp lt" & FNR$(V2) & FNR$(A1) & FNR$(R1)
21940 GOSUB 7620
21970 LET R3 = V2
21980 GOSUB 7470
21990 LET V4 = R3
22000 LET L1$ = "isub" & FNR$(D2) & FNR$(R2) & FNR$(V4)
22010 GOTO 7668
22060 LET O$ = SEG$("fsqrt ffloorfceil ftruncfround", 6 * W2 - 59, 6 * W2 - 54)
22070 IF SEG$(O$, 6, 6) <> " " THEN 22090
22080 LET O$ = SEG$(O$, 1, 5)
22090 LET A1 = U(Z6 + 1, 1)
22100 GOSUB 7393
22120 IF C1 <> 2 THEN 2360
22130 GOSUB 7470
22140 LET L1$ = O$ & FNR$(D2) & FNR$(A1)
22150 GOTO 7668
22190 LET A1 = U(Z6 + 1, 1)
22200 GOSUB 7393
22220 IF C1 <> 2 THEN 2360
22230 GOSUB 7468
22250 LET L1$ = "fnan" & FNR$(D2) & FNR$(A1)
22260 GOTO 7668
22310 LET A1 = U(Z6 + 1, 1)
22320 LET A2 = U(Z6 + 2, 1)
22330 GOSUB 7391
22350 IF C1 = 1 THEN 22440
22360 GOSUB 7470
22370 LET V4 = A2
22380 LET L1$ = SEG$("fminfmax", 4 * W2 - 63, 4 * W2 - 60) & FNR$(D2) & FNR$(A1) & FNR$(V4)
22390 GOTO 7668
22440 GOSUB 7420
22450 LET V2 = N2
22460 LET L1$ = SEG$("icmp lticmp gt", 7 * W2 - 111, 7 * W2 - 105) & FNR$(V2) & FNR$(A2) & FNR$(A1)
22470 GOSUB 7620
22500 LET R1 = V2
22510 GOSUB 7470
22520 LET V4 = A2
22530 LET V5 = A1
22540 LET L1$ = "isel" & FNR$(D2) & FNR$(R1) & FNR$(V4) & FNR$(V5)
22550 GOTO 7666
22600 GOSUB 7391
22620 IF C1 = 3 THEN 2360
22630 GOSUB 7470
22640 LET V4 = U(Z6 + 2, 1)
22650 LET V5 = U(Z6 + 3, 1)
22660 LET L1$ = SEG$("if", C1, C1) & "sel" & FNR$(D2) & FNR$(U(Z6 + 1, 1)) & FNR$(V4) & FNR$(V5)
22670 GOTO 7666
22720 REM ---- ind2sub(r, k): imodf I K R, idivf J K R; its two results as tbind/tasg/tret give them
22730 LET C1 = 1
22740 LET R1 = 0
22750 IF D <> -2 THEN 22790
22760 LET R1 = U(Z6 - 1, 1)
22770 LET R2 = U(Z6, 1)
22780 GOTO 22830
22790 GOSUB 7420
22800 LET R1 = N2
22810 GOSUB 7420
22820 LET R2 = N2
22830 LET O$ = "imodf"
22840 LET V2 = R1
22850 LET V3 = U(Z6 + 2, 1)
22860 LET V4 = U(Z6 + 1, 1)
22870 GOSUB 7775
22880 GOSUB 7575
22890 LET O$ = "idivf"
22900 LET V2 = R2
22910 LET V3 = U(Z6 + 2, 1)
22920 LET V4 = U(Z6 + 1, 1)
22930 GOSUB 7775
22940 GOSUB 7575
22950 LET R9 = 0
22960 GOTO 19580
22970 REM ---- sub2ind(r, i, j): chkb I R 0, imulc T J R, iaddc D I T --------------------------
22980 LET V2 = U(Z6 + 2, 1)
22990 LET V3 = U(Z6 + 1, 1)
23000 LET Z3 = 0
23010 GOSUB 10810
23020 GOSUB 7416
23040 LET O$ = "imulc"
23050 LET V2 = N2
23060 LET V3 = U(Z6 + 3, 1)
23070 LET V4 = U(Z6 + 1, 1)
23080 GOSUB 7775
23090 GOSUB 7575
23100 LET R1 = V2
23110 GOSUB 7468
23130 LET O$ = "iaddc"
23140 LET V2 = D2
23150 LET V3 = U(Z6 + 2, 1)
23160 LET V4 = R1
23170 GOSUB 7775
23180 GOSUB 7575
23190 GOTO 19575
23210 REM ==== the rule-12 pre-pass, phase 4 part ---- 23230 / 23250 (sea.hirl): a tmp is a statement whose expression is its child, an hloop one whose expression is its range (its first three children); an xblk is no statement: its subtree [E6,
23220 REM xblk] belongs to the statement that holds it (2588); an iret is a statement like a ret (6b: inlined bodies are visited, 34700)
23230 IF H(N4, 1) = 44 THEN 2600
23231 IF H(N4, 1) = 66 THEN 2600
23232 IF H(N4, 1) = 45 THEN 2600
23234 IF H(N4, 1) <> 43 THEN 2720
23236 LET P4 = N4
23238 GOSUB 13480
23240 LET E6 = P4
23242 GOTO 2720
23250 IF H(N4, 1) <> 45 THEN 2625
23252 LET B5 = H(H(H(N4, 7), 8), 8)
23254 GOTO 2625
23270 REM ---- 23280: U7 = 1 if N4 is an asg set to an idx (the value is evaluated first, 3.5.5 G1) --
23280 LET U7 = 0
23290 IF H(N4, 1) <> 23 THEN 24600
23300 IF H(N4, 5) <> 1 THEN 23340
23310 IF H(H(N4, 7), 1) <> 39 THEN 23340
23320 LET U7 = 1
23330 LET U8 = H(N4, 7)
23340 RETURN
23350 REM ---- 23360: U6 = the evaluation rank of node U5 in the statement N4 -----------------------
23360 LET U6 = U5
23370 IF U7 = 0 THEN 23430
23380 IF U5 >= N4 THEN 23430
23385 IF U7 = 2 THEN 24700
23390 IF U5 > U8 THEN 23420
23400 LET U6 = U5 + (N4 - 1 - U8)
23410 GOTO 23430
23420 LET U6 = U5 - (U8 - A5 + 1)
23430 RETURN
23440 REM ---- 23450: a rarg of an element path: its root is the base local -----------------------
23450 LET C5 = H(C5, 7)
23455 IF ABS(H(C5, 1) - 49.5) = 10.5 THEN 23450
23460 IF H(C5, 1) <> 5 THEN 2715
23470 GOTO 2665
23480 REM ---- 23490: a ref parameter root: only a reference value needs a snapshot (rule 12 (b)) --
23490 LET T3 = A(G(F0, 0) + L5, 1)
23500 GOSUB 41350
23510 IF U3 = 0 THEN 2715
23520 GOTO 2675
23530 REM ---- 23550: the read J5 of the root L5 before the rarg K5: scalars always, a reference value only when its consumer comes after the call; never the target of a ref argument itself (R30: a tmp of an inline xblk is read by its iblk)
23550 LET U5 = K5
23560 GOSUB 23360
23570 LET K4 = U6
23580 LET U5 = J5
23590 GOSUB 23360
23600 IF U6 >= K4 THEN 2710
23610 LET P6 = J5
23620 GOSUB 23780
23630 LET P4 = P5
23640 IF H(P4, 1) = 11 THEN 2710
23645 IF ABS(H(P4, 1) - 45.5) = 1.5 THEN 42920
23646 IF H(P4, 1) = 60 THEN 53300
23650 IF H(P4, 1) <> 39 THEN 23700
23660 IF H(P4, 7) = J5 THEN 53300
23692 IF P5 <> N4 THEN 23700
23694 IF H(N4, 1) = 24 THEN 2710
23696 IF H(N4, 1) <> 23 THEN 23700
23698 IF H(N4, 7) = P4 THEN 2710
23700 LET T3 = H(J5, 4)
23710 GOSUB 41350
23720 IF U3 = 0 THEN 2705
23730 LET U5 = P4
23731 IF H(P4, 1) <> 44 THEN 23740
23732 LET P6 = P4
23733 IF H(P6, 8) = 0 THEN 23736
23734 LET P6 = H(P6, 8)
23735 GOTO 23733
23736 IF H(P6 + 1, 1) + SGN(H(P6 + 1, 5)) <> 44 THEN 23740
23737 LET U5 = H(P6 + 1, 5)
23740 GOSUB 23360
23750 IF U6 > K4 THEN 2705
23760 GOTO 2710
23770 REM ---- 23780: P5 = the parent of node P6 within the statement N4 --------------------------
23780 FOR P5 = P6 + 1 TO N4
23790 LET P9 = H(P5, 7)
23800 IF P9 = 0 THEN 23840
23810 IF P9 = P6 THEN 23860
23820 LET P9 = H(P9, 8)
23830 GOTO 23800
23840 NEXT P5
23850 GOTO 2365
23860 RETURN
24000 REM ==== tasg to an element by scalar indices (rule 15 (j)): after the call, in target order, the conversion, then the base and indices, the checks, cow and the store of rule 19. Frame (step (d) of 8400): x2 = the component, x3 = U0 before the
24010 REM target's entries. ---- @tsi: the component is an element: a new result register, finished by step (d)
24040 LET A2 = 400000 + 100000 * Q3
24050 GOTO 8370
24060 REM ---- @tel: the conversion of a cv component, then the target's base -----------------
24070 LET A2 = A2 - 400000
24080 LET V2 = U(I, 1)
24090 IF A2 < 100000 THEN 24160
24100 GOSUB 7411
24120 LET O$ = "itof"
24130 LET V3 = V2
24140 LET V2 = N2
24150 GOSUB 7540
24160 LET U(I, 1) = V2
24170 GOSUB 24480
24180 LET S = 51
24190 GOTO 7361
24210 GOSUB 24480
24220 IF H(H(X2, 7), 1) <> 5 THEN 2360
24230 GOSUB 7966
24260 LET H(X2, 0) = R9
24270 GOSUB 24480
24280 LET X1 = H(H(X2, 7), 8)
24290 FOR K7 = 1 TO U0 - W(W0 + 5) - 1
24300 LET X1 = H(X1, 8)
24310 NEXT K7
24320 IF X1 = 0 THEN 24390
24330 LET S = 52
24340 GOTO 7375
24350 GOSUB 7966
24380 GOTO 24270
24390 LET Z6 = W(W0 + 5)
24400 IF U0 - Z6 <> H(X2, 6) + 1 THEN 2365
24410 LET R6 = U(Z6 + 1, 1)
24420 LET R1 = U(Z6 + 2, 1)
24430 LET R2 = 0
24440 IF H(X2, 6) = 1 THEN 24460
24445 IF H(X2, 6) <> 2 THEN 2360
24450 LET R2 = U(Z6 + 3, 1)
24460 LET Y6 = X2
24461 GOSUB 24820
24462 LET T4 = U(W(W0 + 4), 1)
24464 GOSUB 14630
24466 LET U0 = W(W0 + 5)
24468 GOTO 8405
24470 REM ---- 24480: X2 = the target of component W(W0+4) (an idx) ---------------------------
24480 LET X2 = H(X, 7)
24490 FOR K7 = 2 TO W(W0 + 4) - W(W0 + 3)
24500 LET X2 = H(X2, 8)
24510 NEXT K7
24520 IF H(X2, 1) <> 39 THEN 2360
24530 RETURN
24590 REM ---- 24600 (of @evi): a tasg evaluates its call first, then its targets (3.5.5 G1); U7 = 2, U8 = the first node of the call's subtree
24600 IF H(N4, 1) <> 24 THEN 23340
24610 LET P4 = H(N4, 7)
24620 IF H(P4, 8) = 0 THEN 24650
24630 LET P4 = H(P4, 8)
24640 GOTO 24620
24650 GOSUB 13480
24660 LET U7 = 2
24670 LET U8 = P4
24680 RETURN
24690 REM ---- 24700 (of @ev) for a tasg: the call's nodes first, then the targets' nodes
24700 IF U5 < U8 THEN 24730
24710 LET U6 = U5 - (U8 - A5)
24720 RETURN
24730 LET U6 = U5 + (N4 - U8)
24740 RETURN
24800 REM ---- 24820: R6 = the base of the element target Y6 loaded again (ldp) when it is a ref parameter that a ref argument in the indices passes: the checks see the variable (5.5)
24820 LET O5 = H(Y6, 7)
24822 GOSUB 41230
24824 LET P3 = H(Y6, 7)
24830 LET A1 = H(P3, 5)
24835 IF F6 = 1 THEN 24930
24840 IF A(G(F0, 0) + A1, 2) = 0 THEN 24930
24850 FOR P9 = H(Y6, 7) + 1 TO Y6 - 1
24860 IF H(P9, 1) <> 11 THEN 24900
24870 LET P3 = P9
24880 GOSUB 16970
24890 IF P3 = A1 THEN 24910
24900 NEXT P9
24905 RETURN
24910 GOSUB 7418
24920 LET R6 = N2
24922 LET L1$ = SEG$("ldildfldp", 3 * V(R6, 1) - 2, 3 * V(R6, 1)) & FNR$(R6) & FNR$(A1) & " - 0 0"
24924 GOSUB 7695
24930 RETURN
