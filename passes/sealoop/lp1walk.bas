5000 REM ====================================================================================
5005 REM sealoop part 1 (lines 5000-9999): (B) the rewrite walk (DESIGN 3.5.9). Every record of
5010 REM sea.hir in file order; a node's output subtree is the rows H(X,7) .. H(X,8) of the list O
5015 REM (row 0 its head, O9 its tail), H(X,0) the row before it. A copied record joins the tail.
5020 REM A rewrite writes its records after the subtree of a child (the cursor C9), before the
5025 REM first one (after H(X,0)) or at the tail: in post-order every child's subtree is complete
5030 REM when its parent's record is met; a store moves rows (L6, L9, L11). N7 S7 T7 count the
5035 REM nodes, locals and types of sea.hirl as a whole; a rewrite that would exceed SEA_LIM_NODES,
5040 REM SEA_LIM_SYMBOLS or SEA_LIM_TYPES is reported at the position P9$ of the node it
5045 REM implements (status 10). New locals are written @p (p a row of U) and the tptr of element
5050 REM type e ^e in the generated records; lp2out numbers them in file order.
5055 LET N7 = H0
5060 LET S7 = A0
5065 LET T7 = Y9 - 9
5070 LET O0 = 0
5075 LET O9 = 0
5076 FOR X = 10 TO Y9
5077 IF C(X, 0) <> 4 THEN 5079
5078 LET S(X) = C(X, 1)
5079 NEXT X
5080 LET O(0, 0) = 0
5085 LET U0 = 0
5088 LET F0 = 0
5090 LET Z0 = 0
5091 LET V(55) = S(2)
5092 LET V(56) = S(3)
5093 LET V(57) = S(4)
5094 REM the dispatch of a node by kind (two digits per kind; 5149)
5095 LET Q4$ = "01010101011111111101010301010104010101011322121301010101010113140101010101010806020110100705090501011516010101181719200101010121"
5096 REM the parents in W (the tree stack is free now; a body block has 0)
5097 FOR X = 1 TO H0
5098 LET W(X) = 0
5099 NEXT X
5100 FOR X = 1 TO H0
5101 LET X1 = H(X, 3)
5102 IF X1 = 0 THEN 5106
5103 LET W(X1) = X
5104 LET X1 = H(X1, 4)
5105 GOTO 5102
5106 NEXT X
5110 FOR R1 = 1 TO D0
5112 LET X = P(R1, 1)
5114 LET R7 = R1
5116 LET K = R(P(R1, 0), 0)
5118 IF K < 33 THEN 5135
5119 IF K > 55 THEN 5135
5120 IF K = 42 THEN 5126
5121 IF K > 52 THEN 5126
5122 IF K > 50 THEN 5135
5123 IF K > 48 THEN 5126
5124 IF K > 38 THEN 5135
5126 REM a declaration (a type, fn par loc end): copied; fn opens the function F0
5128 IF K <> 33 THEN 5131
5130 LET F0 = X
5131 LET C9 = O9
5132 GOSUB 8000
5133 GOTO 5195
5135 REM ---- a node: H(X,0) the output row before its subtree; dispatched by kind (Q4$)
5137 LET H(X, 0) = O9
5139 LET X1 = H(X, 3)
5141 IF X1 = 0 THEN 5145
5143 LET H(X, 0) = H(X1, 0)
5145 LET C9 = O9
5147 LET K4 = VAL(SEG$(Q4$, 2 * K - 1, 2 * K))
5149 ON K4 GOTO 5160, 7000, 5300, 5350, 5170, 5400, 5450, 5500, 25000, 20500, 5550, 5600, 5700, 5800, 40000, 40200, 45030, 45100, 45150, 50800, 55000, 55180
5160 REM ---- copied after its children
5162 GOSUB 8000
5164 GOTO 5180
5170 REM ---- not written (an index's rng or all, a row, a folded view, a store's target idx)
5172 LET N7 = N7 - 1
5180 REM ---- every node: the first and last output rows of its subtree
5182 LET H(X, 7) = O(H(X, 0), 0)
5184 LET H(X, 8) = O9
5195 NEXT R1
5197 GOTO 10000
5295 REM ---- lib: L1-L3 (zeros ... numel), L7 (elemental, an array argument), L11's ind2sub ----------
5300 LET R2 = H(X, 6)
5302 LET F9 = 4
5304 GOSUB 8440
5306 LET W2 = POS(K3$, "|" & F9$ & " ")
5308 IF W2 = 0 THEN 5313
5310 LET W2 = (W2 - 1) / 8 + 1
5312 GOTO 6005
5313 IF POS(K5$, "|" & F9$ & " ") + POS(F9$, ".dim") > 0 THEN 35000
5314 IF F9$ <> "ind2sub" THEN 5324
5316 LET X5 = X
5318 GOSUB 5750
5320 IF Y8 = 1 THEN 5170
5322 GOTO 5160
5324 IF POS(K4$, "|" & F9$ & "|") = 0 THEN 5160
5326 IF H(X, 5) > 1 THEN 5550
5328 IF F9$ = "min" THEN 5160
5330 IF F9$ = "max" THEN 5160
5332 GOTO 5550
5345 REM ---- rng: an index (skipped: its idx reads it), a forr's range (copied), else L8 ---------------
5350 LET X5 = W(X)
5352 IF H(X5, 1) <> 39 THEN 5356
5354 IF H(X5, 3) <> X THEN 5170
5356 IF H(X5, 1) = 27 THEN 5160
5358 GOTO 20000
5395 REM ---- dol: claimed by a rewritten idx Y5, the extent of its dimension (IX 1), else copied ---
5400 LET Y5 = H(X, 5)
5402 IF Y5 <= X THEN 5160
5404 GOSUB 15030
5406 IF C7 = 0 THEN 5160
5408 LET R2 = H(X, 6)
5410 GOSUB 8400
5412 LET F9 = 4
5414 GOSUB 8440
5416 LET D7 = VAL(F9$)
5418 GOSUB 15100
5420 LET Z9$ = ""
5422 GOSUB 15200
5424 LET K8 = 0
5425 GOSUB 5432
5426 GOSUB 9000
5427 LET X8$ = ""
5428 LET N7 = N7 - 1
5429 LET F6 = 0
5430 GOTO 5180
5432 LET R2 = H(Y5, 6)
5434 GOSUB 8400
5436 LET X8$ = P9$
5438 LET R2 = H(X, 6)
5440 GOTO 8400
5445 REM ---- view: the folded base of an idx (skipped), else materialized (L10) --------------------
5450 LET Y5 = W(X)
5452 IF H(Y5, 1) <> 39 THEN 20600
5454 IF H(Y5, 3) <> X THEN 20600
5456 GOSUB 15060
5458 IF V0 = 0 THEN 20600
5460 GOTO 5170
5495 REM ---- idx: copied (scalar indices), L5, or the target of an L6 store (skipped) -------------
5500 LET Y5 = X
5502 GOSUB 15030
5504 ON C7 + 1 GOTO 5160, 15400, 5170, 5170
5545 REM ---- bin un cvt powk, elemental lib: L7 when an operand is an array --------------------------
5550 LET X5 = X1
5552 IF X5 = 0 THEN 5160
5554 IF H(X5, 2) > 9 THEN 20100
5556 LET X5 = H(X5, 4)
5558 GOTO 5552
5595 REM ---- asg: L6 (a selection or .flat target), a compound store of a whole array, or copied ----
5600 LET X5 = X1
5601 IF H(X5, 1) = 56 THEN 40500
5602 IF H(X5, 1) <> 39 THEN 5610
5604 LET Y5 = X5
5606 GOSUB 15030
5608 IF C7 = 2 THEN 16000
5609 IF C7 = 3 THEN 40500
5610 LET R2 = H(X, 6)
5612 LET F9 = 3
5614 GOSUB 8440
5616 IF F9$ = "set" THEN 5160
5618 IF H(X5, 1) <> 5 THEN 5160
5620 IF H(X5, 2) <= 9 THEN 5160
5622 GOTO 20300
5695 REM ---- tbind tasg tret: L11 when the last child is ind2sub with a scalar r and an array k; L12
5700 LET X5 = X1
5702 IF H(X5, 4) = 0 THEN 5706
5704 LET X5 = H(X5, 4)
5705 GOTO 5702
5706 IF H(X5, 1) <> 12 THEN 5713
5708 GOSUB 5750
5710 IF Y8 = 0 THEN 56100
5712 GOTO 20800
5713 IF H(X5, 1) > 18 THEN 55190
5714 IF K <> 24 THEN 5160
5716 LET O5 = X
5717 GOSUB 30900
5718 IF Y8 = 0 THEN 5160
5719 GOTO 30100
5745 REM ---- 5750: Y8 = 1 if the lib X5 is L11's: ind2sub(r, k), r a scalar, k an array, the last
5747 REM child of a tbind, tasg or tret
5750 LET Y8 = 0
5752 LET R2 = H(X5, 6)
5754 LET F9 = 4
5756 GOSUB 8440
5758 IF F9$ <> "ind2sub" THEN 5778
5760 LET Q3 = H(W(X5), 1)
5762 IF Q3 = 21 THEN 5768
5764 IF Q3 = 24 THEN 5768
5766 IF Q3 <> 31 THEN 5778
5768 IF H(X5, 4) > 0 THEN 5778
5770 IF H(H(X5, 3), 2) > 9 THEN 5778
5772 IF H(H(H(X5, 3), 4), 2) <= 9 THEN 5778
5774 LET Y8 = 1
5778 RETURN
5795 REM ---- block: copied, its n grown by the statements L11 put in place of a tbind (H(X,5)) ------
5800 IF H(X, 5) = 0 THEN 5160
5802 LET R2 = H(X, 6)
5804 LET Z$ = D$(R2)
5806 LET F9 = 3
5808 GOSUB 8440
5810 LET F9$ = STR$(VAL(F9$) + H(X, 5))
5812 GOSUB 8470
5814 GOSUB 8050
5816 LET N7 = N7 - 1
5818 GOTO 5180
5995 REM ==== L1-L3: lib zeros ones filled len rows cols numel (3.5.9) ===========================
6005 LET R2 = R1
6010 GOSUB 8400
6015 LET X1 = H(X, 3)
6020 LET X2 = 0
6025 IF X1 = 0 THEN 6040
6030 LET X2 = H(X1, 4)
6040 LET U2 = 0
6045 REM the lib node itself is replaced: it no longer counts
6050 LET N7 = N7 - 1
6055 IF W2 > 3 THEN 6600
6060 GOSUB 6900
6065 IF W2 > 1 THEN 6100
6070 REM ---- L1 zeros(r [, c]) of type T: anew P T 1 k, its children the extents ----------------
6075 LET C9 = O9
6080 LET Z$ = "anew " & P9$ & " " & STR$(T3) & " 1 " & STR$(C4)
6085 GOSUB 8050
6090 GOTO 6560
6095 REM ---- L2 ones(r [, c]) / filled(v, r [, c]) of type T, element E: xblk P T n of the
6097 REM statements [tmp V = v] tmp R [tmp C] tmp A = anew, [tmp N = R * C], [tmp V = 1 of E],
6098 REM tmp D = adat A, loop(N; K) { est V D K }, and its value lv A (n = 6 vector, 8 matrix)
6100 LET X4 = X1
6105 IF W2 = 2 THEN 6140
6110 LET U1 = E3
6115 GOSUB 8100
6120 LET M1 = U0
6125 LET C9 = H(X1, 8)
6130 LET V1 = M1
6135 GOSUB 8250
6137 LET X4 = X2
6140 LET U1 = 3
6145 GOSUB 8100
6150 LET M2 = U0
6155 LET C9 = H(X4, 8)
6160 LET V1 = M2
6165 GOSUB 8250
6170 LET M5 = M2
6175 IF C4 = 1 THEN 6205
6180 GOSUB 8100
6185 LET M3 = U0
6190 LET C9 = H(H(X4, 4), 8)
6195 LET V1 = M3
6200 GOSUB 8250
6205 REM the new array, uncleared: every element is stored before any is read (4.8)
6210 LET C9 = O9
6215 LET V1 = M2
6220 GOSUB 8200
6225 IF C4 = 1 THEN 6240
6230 LET V1 = M3
6235 GOSUB 8200
6240 LET Z$ = "anew " & P9$ & " " & STR$(T3) & " 0 " & STR$(C4)
6245 GOSUB 8050
6250 LET U1 = T3
6255 GOSUB 8100
6260 LET M4 = U0
6265 LET V1 = M4
6270 GOSUB 8250
6275 IF C4 = 1 THEN 6330
6280 REM a matrix: the element count N = R * C
6285 LET U1 = 3
6290 GOSUB 8100
6295 LET M5 = U0
6300 LET V1 = M2
6305 GOSUB 8200
6310 LET V1 = M3
6315 GOSUB 8200
6320 LET Z$ = "wbin " & P9$ & " 3 mul"
6322 GOSUB 8050
6325 LET V1 = M5
6327 GOSUB 8250
6330 IF W2 = 3 THEN 6380
6335 REM ones: V = the constant 1 of the element type (cb, ci or cf)
6340 LET U1 = E3
6345 GOSUB 8100
6350 LET M1 = U0
6355 LET Z$ = "cb " & P9$ & " 2 1"
6360 IF E3 = 2 THEN 6372
6365 LET Z$ = "ci " & P9$ & " 3 1"
6370 IF E3 = 3 THEN 6372
6371 LET Z$ = "cf " & P9$ & " 4 #3FF0000000000000"
6372 GOSUB 8050
6375 LET V1 = M1
6377 GOSUB 8250
6380 REM D = the address of the elements
6385 LET U1 = -E3
6390 GOSUB 8100
6395 LET M6 = U0
6400 GOSUB 8150
6405 LET V1 = M4
6410 GOSUB 8200
6415 LET Z$ = "adat " & P9$ & " ^" & STR$(E3)
6420 GOSUB 8050
6425 LET V1 = M6
6430 GOSUB 8250
6435 REM loop(N; K): tmp Z = 0, if N > Z { tmp O = 1, tmp L = N - O, hloop K Z L O { est } }
6440 GOSUB 8500
6442 GOSUB 8540
6445 LET V1 = M1
6450 GOSUB 8200
6455 LET V1 = M6
6460 GOSUB 8200
6465 LET V1 = M0
6470 GOSUB 8200
6475 LET Z$ = "est " & P9$ & " " & STR$(S(E3)) & " 0"
6480 GOSUB 8050
6485 LET Z$ = "block " & P9$ & " 1"
6490 GOSUB 8050
6495 LET Z$ = "hloop " & P9$ & " @" & STR$(M0)
6500 GOSUB 8050
6505 LET Z$ = "block " & P9$ & " 3"
6510 GOSUB 8050
6515 LET Z$ = "if " & P9$ & " 0"
6520 GOSUB 8050
6525 REM the value: lv A
6530 LET V1 = M4
6535 GOSUB 8200
6540 LET Z$ = "xblk " & P9$ & " " & STR$(T3) & " " & STR$(4 + 2 * C4)
6545 GOSUB 8050
6555 REM ---- the rewritten node's output subtree: from its first child's to the last record ----
6560 GOTO 5180
6595 REM ---- L3 len(v) rows(m) cols(m) numel(a): ext P 3 dim of the operand; numel of a matrix:
6597 REM xblk P 3 1 { tmp A = a } with the value wbin mul (ext 0 of A) (ext 1 of A) ------------
6600 IF H(X, 5) <> 1 THEN 2900
6605 IF H(X, 2) <> 3 THEN 2900
6610 LET T3 = H(X1, 2)
6612 REM len of a str (4g-1): ext P 3 0
6613 IF T3 <> 5 THEN 6615
6614 IF W2 = 4 THEN 6655
6615 IF T3 <= 9 THEN 2900
6620 LET K3 = T(T3, 1)
6625 IF K3 = 0 THEN 2900
6630 IF W2 = 7 THEN 6655
6635 IF W2 > 4 THEN 6650
6640 IF K3 <> 1 THEN 2900
6645 GOTO 6655
6650 IF K3 <> 2 THEN 2900
6655 LET Z3 = 0
6660 IF W2 <> 6 THEN 6670
6665 LET Z3 = 1
6670 IF W2 <> 7 THEN 6680
6675 IF K3 = 2 THEN 6700
6680 LET C9 = O9
6685 LET Z$ = "ext " & P9$ & " 3 " & STR$(Z3)
6690 GOSUB 8050
6695 GOTO 6560
6700 LET U1 = T3
6705 GOSUB 8100
6710 LET M4 = U0
6715 LET C9 = O9
6720 LET V1 = M4
6725 GOSUB 8250
6730 FOR Z3 = 0 TO 1
6735 LET V1 = M4
6740 GOSUB 8200
6745 LET Z$ = "ext " & P9$ & " 3 " & STR$(Z3)
6750 GOSUB 8050
6755 NEXT Z3
6760 LET Z$ = "wbin " & P9$ & " 3 mul"
6765 GOSUB 8050
6770 LET Z$ = "xblk " & P9$ & " 3 1"
6775 GOSUB 8050
6780 GOTO 6560
6895 REM ---- 6900: zeros ones filled: T3 = the type (a vector or matrix), C4 its rank, E3 its
6897 REM element (bool i64 f64); n = the rank (+ 1 for filled); extents i64; filled's value of E3
6900 LET T3 = H(X, 2)
6905 IF T3 <= 9 THEN 2900
6910 LET K3 = T(T3, 1)
6915 IF K3 = 0 THEN 2900
6920 LET C4 = K3
6925 LET E3 = T(T3, 2)
6930 IF E3 < 2 THEN 2900
6935 IF E3 <= 5 THEN 6940
6936 IF W2 <> 3 THEN 2900
6937 IF C(E3, 0) <> 4 THEN 2900
6940 LET J5 = C4
6945 IF W2 <> 3 THEN 6955
6950 LET J5 = C4 + 1
6955 IF H(X, 5) <> J5 THEN 2900
6960 LET X4 = X1
6965 IF W2 <> 3 THEN 6985
6970 IF H(X1, 2) <> E3 THEN 2900
6975 LET X4 = X2
6985 IF H(X4, 2) <> 3 THEN 2900
6990 IF C4 = 1 THEN 6998
6995 IF H(H(X4, 4), 2) <> 3 THEN 2900
6998 RETURN
7000 REM ==== L4 fore X v body (3.5.9): block P 4 { bind H = v; tmp N = ext 0 of H; tmp Z = 0;
7001 REM if N > Z { tmp D = adat H; tmp O = 1; tmp L = N - O; hloop K Z L O { tmp X = eld D K;
7002 REM body } } }: the chain up to tmp X goes between v and the body, the rest after the body
7003 LET R2 = R1
7005 GOSUB 8400
7010 LET X1 = H(X, 3)
7015 LET X2 = H(X1, 4)
7020 LET T3 = H(X1, 2)
7025 IF T3 <= 9 THEN 2900
7030 IF T(T3, 1) <> 1 THEN 2900
7035 LET E3 = T(T3, 2)
7040 IF E3 < 2 THEN 2900
7045 IF E3 <= 5 THEN 7050
7046 IF C(E3, 0) <> 4 THEN 2900
7050 LET V3 = H(X, 5)
7055 IF A(G(F0, 1) + V3) <> E3 THEN 2900
7060 IF H(X2, 1) <> 32 THEN 2900
7065 LET N7 = N7 - 1
7070 LET U2 = 0
7075 LET C9 = H(X1, 8)
7080 REM bind H = v (H a new local of v's type: the vector the loop holds, rule 30)
7085 LET U1 = T3
7090 GOSUB 8100
7095 LET M4 = U0
7100 LET Z$ = "bind " & P9$ & " @" & STR$(M4)
7105 GOSUB 8050
7110 REM tmp N = ext P 3 0 (lv H)
7115 LET U1 = 3
7120 GOSUB 8100
7125 LET M5 = U0
7130 LET V1 = M4
7135 GOSUB 8200
7140 LET Z$ = "ext " & P9$ & " 3 0"
7145 GOSUB 8050
7150 LET V1 = M5
7155 GOSUB 8250
7160 REM tmp Z = ci 0, the condition N > Z
7165 GOSUB 8500
7225 REM the if block: tmp D = adat (lv H), tmp O = ci 1, tmp L = wbin sub (lv N) (lv O)
7230 LET U1 = -E3
7235 GOSUB 8100
7240 LET M6 = U0
7245 GOSUB 8150
7250 LET V1 = M4
7255 GOSUB 8200
7260 LET Z$ = "adat " & P9$ & " ^" & STR$(E3)
7265 GOSUB 8050
7270 LET V1 = M6
7275 GOSUB 8250
7280 GOSUB 8540
7285 REM the hloop's block: tmp X = eld P E s 0 (lv D) (lv K), then the fore's own body
7290 LET V1 = M6
7295 GOSUB 8200
7300 LET V1 = M0
7305 GOSUB 8200
7310 LET Z$ = "eld " & P9$ & " " & STR$(E3) & " " & STR$(S(E3)) & " 0"
7315 GOSUB 8050
7320 LET Z$ = "tmp " & P9$ & " " & STR$(V3)
7325 GOSUB 8050
7330 REM after the body (the tail): the hloop's block, the hloop, the if's block, the if, the block
7335 LET C9 = O9
7340 LET Z$ = "block " & P9$ & " 2"
7345 GOSUB 8050
7350 LET Z$ = "hloop " & P9$ & " @" & STR$(M0)
7355 GOSUB 8050
7360 LET Z$ = "block " & P9$ & " 4"
7365 GOSUB 8050
7370 LET Z$ = "if " & P9$ & " 0"
7375 GOSUB 8050
7380 LET Z$ = "block " & P9$ & " 4"
7385 GOSUB 8050
7390 GOTO 6560
7995 REM ==== helpers of the walk ==================================================================
7996 REM ---- 8000: a copy of the record R1 in a new row after the cursor C9 (which moves to it) ----
8000 GOSUB 8060
8005 LET O(O0, 1) = R1
8010 RETURN
8045 REM ---- 8050: the generated node Z$ after the cursor; it counts against SEA_LIM_NODES -------
8050 LET N7 = N7 + 1
8052 LET Q2$ = "nodes"
8054 IF N7 > N8 THEN 2930
8056 GOSUB 8060
8057 LET O(O0, 1) = 0
8058 LET O$(O0) = Z$
8059 GOTO 8080
8060 REM ---- 8060: a new row O0 linked after C9; the cursor moves to it (the tail too, if C9 was it)
8062 IF O0 < 449999 THEN 8066
8064 CALL "dg_bug": P$, "the output list is full"
8066 LET O0 = O0 + 1
8068 LET O(O0, 0) = O(C9, 0)
8070 LET O(C9, 0) = O0
8072 IF C9 <> O9 THEN 8076
8074 LET O9 = O0
8076 LET C9 = O0
8078 RETURN
8079 REM ---- 8080: a statement counts in the innermost block a script has open (lp1walk 9000)
8080 IF Z0 = 0 THEN 8086
8081 LET J3 = POS(Z$, " ")
8082 IF POS("|tmp|bind|est|chkb|chk|if|cow|mcpy|asg|eval|hloop|rcnt|ret|", "|" & SEG$(Z$, 1, J3 - 1) & "|") = 0 THEN 8086
8084 LET M(Z0, 1) = M(Z0, 1) + 1
8086 RETURN
8095 REM ---- 8100: U0 = a new local of type U1 (-e: the tptr of e) and mut U2 (0 let, 1 for) of the
8097 REM function F0, its loc pos that of record R7; it counts against SEA_LIM_SYMBOLS --------
8100 LET S7 = S7 + 1
8105 LET Q2$ = "symbols"
8110 IF S7 > S8 THEN 2930
8115 LET U0 = U0 + 1
8120 LET U(U0, 1) = U1
8125 LET U(U0, 2) = U2
8130 LET U(U0, 3) = R7
8135 LET U(U0, 4) = 0
8140 LET G(F0, 4) = G(F0, 4) + 1
8145 RETURN
8146 REM ---- 8150: the tptr of element type E3 is used; a new type counts against SEA_LIM_TYPES ----
8150 IF C(E3, 6) > 0 THEN 8175
8155 LET T7 = T7 + 1
8160 LET Q2$ = "types"
8165 IF T7 > T9 - 9 THEN 2930
8170 LET C(E3, 6) = 1
8175 RETURN
8195 REM ---- 8200: lv P <its type> @V1 of the new local V1 ---------------------------------------
8200 LET Z$ = STR$(U(V1, 1))
8205 IF U(V1, 1) > 0 THEN 8215
8210 LET Z$ = "^" & STR$(-U(V1, 1))
8215 LET Z$ = "lv " & P9$ & " " & Z$ & " @" & STR$(V1)
8220 GOTO 8050
8245 REM ---- 8250: tmp P @V1 (its child is the subtree before it) -------------------------------
8250 LET Z$ = "tmp " & P9$ & " @" & STR$(V1)
8255 GOTO 8050
8295 REM ---- 8300: ci P 3 V2 -----------------------------------------------------------------------
8300 LET Z$ = "ci " & P9$ & " 3 " & STR$(V2)
8305 GOTO 8050
8395 REM ---- 8400: P9$ = the position field of record R2 ------------------------------------------
8400 LET J3 = POS(D$(R2), " ")
8405 LET J4 = POS(D$(R2), " ", J3 + 1)
8410 LET P9$ = SEG$(D$(R2), J3 + 1, J4 - 1)
8415 RETURN
8435 REM ---- 8440: F9$ = field F9 of the record D$(R2); J3, J4 the blanks around it ---------------
8440 LET J3 = 0
8442 FOR J4 = 2 TO F9
8444 LET J3 = POS(D$(R2), " ", J3 + 1)
8446 NEXT J4
8448 LET J4 = POS(D$(R2), " ", J3 + 1)
8450 IF J4 > 0 THEN 8454
8452 LET J4 = LEN(D$(R2)) + 1
8454 LET F9$ = SEG$(D$(R2), J3 + 1, J4 - 1)
8456 RETURN
8465 REM ---- 8470: Z$ (= D$(R2), after 8440) with that field replaced by F9$ -------------------------
8470 LET Z$ = SEG$(Z$, 1, J3) & F9$ & SEG$(Z$, J4, LEN(Z$))
8472 RETURN
8495 REM ---- 8500: the start of loop(N; K) of 3.5.9, N = M5: tmp Z = ci 0 and the if condition
8497 REM bin gt (lv N) (lv Z); M7 = Z
8500 LET U1 = 3
8505 GOSUB 8100
8510 LET M7 = U0
8515 LET V2 = 0
8520 GOSUB 8300
8522 LET V1 = M7
8524 GOSUB 8250
8526 LET V1 = M5
8527 GOSUB 8200
8528 LET V1 = M7
8529 GOSUB 8200
8532 LET Z$ = "bin " & P9$ & " 2 gt"
8534 GOTO 8050
8535 REM ---- 8540: in the if block of loop(N; K): tmp O = ci 1, tmp L = wbin sub (lv N) (lv O),
8537 REM then the hloop's first three children lv Z, lv L, lv O; M8 = O, M9 = L, M0 = K (mut for)
8540 LET U1 = 3
8545 GOSUB 8100
8550 LET M8 = U0
8555 LET V2 = 1
8560 GOSUB 8300
8565 LET V1 = M8
8570 GOSUB 8250
8575 GOSUB 8100
8580 LET M9 = U0
8585 LET V1 = M5
8590 GOSUB 8200
8595 LET V1 = M8
8600 GOSUB 8200
8605 LET Z$ = "wbin " & P9$ & " 3 sub"
8610 GOSUB 8050
8615 LET V1 = M9
8620 GOSUB 8250
8625 LET V1 = M7
8630 GOSUB 8200
8635 LET V1 = M9
8640 GOSUB 8200
8645 LET V1 = M8
8650 GOSUB 8200
8655 LET U2 = 1
8660 GOSUB 8100
8665 LET M0 = U0
8670 LET U2 = 0
8675 RETURN
8695 REM ---- 8700: of type Y7: R5 rank (0 a scalar or a ttuple), F5 fixed, E5 element, B5 bytes ---
8700 LET R5 = 0
8702 LET F5 = 0
8704 LET E5 = Y7
8706 LET B5 = 0
8708 IF Y7 <= 9 THEN 8722
8710 LET R5 = T(Y7, 1)
8712 LET E5 = T(Y7, 2)
8714 IF R5 = 0 THEN 8722
8716 LET F5 = T(Y7, 3)
8718 IF F5 = 0 THEN 8722
8720 LET B5 = T(Y7, 0) * T(Y7, 4) * S(E5)
8722 RETURN
8895 REM ---- 8900: the script S$ right after the subtree of node X4 (L8 its type: tmp of it) -------
8900 LET C9 = H(X4, 8)
8902 LET L8 = H(X4, 2)
8904 GOTO 9000
8990 REM ==== 9000: the script interpreter ========================================================
8991 REM S$ holds records separated by commas, each written after the cursor C9 at P9$ (an rcnt at
8992 REM Q9$) by 8050, which counts the statements of the innermost open block M(Z0,1). A name is one
8993 REM character: of Z5$ a variable of the slot K8 (V(100 + 25*K8 + i)), else of Z4$ (V(i), the
8994 REM digits %0 ... %9 numbers); its value is a row of U or -lid (a local of sea.hir). Commands:
8995 REM L x lv;  = x tmp, B x bind (x a new let local of the last type L8);  C v ci;  X x d ext;
8996 REM D x adat;  K x x a new hloop local, its block opened;  ( N K loop(N; K);  [ E A L S K
8997 REM rloop(E, A, L, S; K); ? an if's block; ) closes a loop or an if, > a loop in no if; {
8998 REM a block or xblk, } closes it as a block, ] as an xblk; R i l e rcnt; else a record (P Q the
8999 REM positions, @x a local, ^x the tptr of x's element (^d of element d), %x a number).
9000 LET S1 = 1
9002 LET S2 = POS(S$, ",", S1)
9004 IF S2 > 0 THEN 9008
9006 LET S2 = LEN(S$) + 1
9008 LET S3$ = SEG$(S$, S1, S2 - 1)
9010 LET S1 = S2 + 1
9012 GOSUB 9020
9014 IF S1 <= LEN(S$) THEN 9002
9016 RETURN
9018 REM ---- 9020: one record S3$ (its command, the variable S5$ it names)
9020 LET S4$ = SEG$(S3$, 1, 1)
9022 LET S5$ = SEG$(S3$, 3, 3)
9024 LET S3 = POS("L=BCXDK(?)[{}]R>", S4$)
9026 IF S3 = 0 THEN 9200
9028 IF S3 > 7 THEN 9034
9030 IF S3 = 4 THEN 9034
9032 GOSUB 9300
9034 ON S3 GOTO 9040, 9050, 9050, 9070, 9075, 9080, 9060, 9090, 9110, 9120, 9100, 9115, 9140, 9150, 9160, 9187
9038 REM L x: lv of x (L8 = its type); B with a field root (F6): its chain (lp9agg 45940)
9040 IF S5 = 2 THEN 9047
9041 GOSUB 9325
9042 LET Z$ = "lv " & P9$ & " " & S9$ & " " & S8$
9044 LET L8 = S4
9046 GOTO 8050
9047 IF F6 = 0 THEN 9041
9048 GOTO 45940
9049 REM = x, B x: a new let local of the last type, named by a tmp, bound by a bind
9050 LET U1 = L8
9051 LET U2 = 0
9052 GOSUB 8100
9053 LET V(S5) = U0
9054 LET Z$ = "tmp "
9055 IF S3 = 2 THEN 9057
9056 LET Z$ = "bind "
9057 LET Z$ = Z$ & P9$ & " @" & STR$(U0)
9058 GOTO 8050
9059 REM K x: a new hloop local (i64, mut for); the loop's block is opened (M(Z0,2) = x)
9060 LET U1 = 3
9061 LET U2 = 1
9062 GOSUB 8100
9063 LET U2 = 0
9064 LET V(S5) = U0
9065 LET Z0 = Z0 + 1
9066 LET M(Z0, 1) = 0
9067 LET M(Z0, 2) = U0
9068 RETURN
9069 REM C v: ci v; X x d: lv x, ext d
9070 LET Z$ = "ci " & P9$ & " 3 " & SEG$(S3$, 3, LEN(S3$))
9071 LET L8 = 3
9072 GOTO 8050
9075 GOSUB 9180
9076 LET Z$ = "ext " & S7$ & " 3 " & SEG$(S3$, 5, 5)
9077 LET L8 = 3
9078 GOTO 8050
9079 REM D x: lv x, adat of the tptr of its element type
9080 GOSUB 9040
9081 GOSUB 9340
9082 GOSUB 8150
9083 LET Z$ = "adat " & P9$ & " ^" & STR$(E3)
9084 LET L8 = -E3
9085 GOTO 8050
9089 REM ( N K: loop(N; K) of 3.5.9, expanded in place (the names 7 8 9 are its Z O L)
9090 LET S6$ = SEG$(S3$, 5, 5)
9091 LET S$ = "C 0,= 7,L " & S5$ & ",L 7,bin P 2 gt,?,C 1,= 8,L " & S5$ & ",L 8,wbin P 3 sub,= 9,L 7,L 9,L 8,K " & S6$ & "," & SEG$(S$, S1, LEN(S$))
9092 LET S1 = 1
9093 RETURN
9099 REM [ E A L S K: rloop(E, A, L, S; K) of 3.5.9, expanded in place
9100 LET S$ = "L " & S5$ & ",?,L " & SEG$(S3$, 5, 5) & ",L " & SEG$(S3$, 7, 7) & ",L " & SEG$(S3$, 9, 9) & ",K " & SEG$(S3$, 11, 11) & "," & SEG$(S$, S1, LEN(S$))
9101 LET S1 = 1
9102 RETURN
9109 REM ? and {: a block opened (an if's; a block or an xblk the script writes)
9110 LET S6 = 0
9111 GOTO 9116
9115 LET S6 = -1
9116 LET Z0 = Z0 + 1
9117 LET M(Z0, 1) = 0
9118 LET M(Z0, 2) = S6
9119 RETURN
9120 REM ): a loop closed (block, hloop, the if's block, if) or an if (block, if)
9121 LET S6 = M(Z0, 2)
9122 GOSUB 9135
9123 IF S6 = 0 THEN 9127
9124 LET Z$ = "hloop " & P9$ & " @" & STR$(S6)
9125 GOSUB 8050
9126 GOSUB 9135
9127 LET Z$ = "if " & P9$ & " 0"
9128 GOTO 8050
9134 REM ---- 9135: block P n of the innermost open block, which is closed
9135 LET Z$ = "block " & P9$ & " " & STR$(M(Z0, 1))
9136 LET Z0 = Z0 - 1
9137 GOTO 8050
9139 REM }: closed as a block (a statement of the enclosing block); ]: as an xblk of type L8
9140 GOSUB 9135
9141 IF Z0 = 0 THEN 9143
9142 LET M(Z0, 1) = M(Z0, 1) + 1
9143 RETURN
9150 LET Z$ = "xblk " & P9$ & " " & STR$(L8) & " " & STR$(M(Z0, 1))
9151 LET Z0 = Z0 - 1
9152 GOTO 8050
9159 REM R i l e: rcnt (Q9$) of incl i into new locals l (i64), e (bool); their loc pos R6's
9160 LET S6 = R7
9161 LET R7 = R6
9162 LET S5$ = SEG$(S3$, 5, 5)
9163 GOSUB 9300
9164 LET U1 = 3
9165 GOSUB 8100
9166 LET V(S5) = U0
9167 LET S8$ = "rcnt " & Q9$ & " " & SEG$(S3$, 3, 3) & " @" & STR$(U0)
9168 LET S5$ = SEG$(S3$, 7, 7)
9169 GOSUB 9300
9170 LET U1 = 2
9171 GOSUB 8100
9172 LET V(S5) = U0
9173 LET R7 = S6
9174 LET Z$ = S8$ & " @" & STR$(U0)
9175 GOTO 8050
9178 REM ---- 9180: the lv of an ext at X8$ (a claimed dol: the idx's position) if set, else at P9$
9180 LET S7$ = P9$
9181 IF LEN(X8$) = 0 THEN 9183
9182 LET P9$ = X8$
9183 GOSUB 9040
9184 LET P9$ = S7$
9185 RETURN
9186 REM >: a loop closed that stands in no if (sum8, L13): block, hloop
9187 LET S6 = M(Z0, 2)
9188 GOSUB 9135
9189 LET Z$ = "hloop " & P9$ & " @" & STR$(S6)
9190 GOTO 8050
9195 REM ---- 9200: a record, its fields substituted (L8 = the third field when it is a type)
9200 LET Z$ = ""
9201 LET Q6 = 1
9202 LET Q5 = 0
9203 LET Q7 = POS(S3$, " ", Q6)
9204 IF Q7 > 0 THEN 9206
9205 LET Q7 = LEN(S3$) + 1
9206 LET S6$ = SEG$(S3$, Q6, Q7 - 1)
9207 LET Q5 = Q5 + 1
9208 LET S5$ = SEG$(S6$, 2, 2)
9209 LET S3 = POS("PQ@^%", SEG$(S6$, 1, 1))
9210 IF S3 = 0 THEN 9240
9211 IF S3 > 2 THEN 9218
9212 IF LEN(S6$) > 1 THEN 9240
9213 LET S6$ = P9$
9214 IF S3 = 1 THEN 9240
9215 LET S6$ = Q9$
9216 GOTO 9240
9218 IF S3 <> 4 THEN 9224
9219 IF POS("0123456789", S5$) = 0 THEN 9224
9220 LET E3 = VAL(S5$)
9221 GOSUB 8150
9222 GOTO 9240
9224 GOSUB 9300
9225 IF S3 = 5 THEN 9234
9226 GOSUB 9325
9227 LET S6$ = S8$
9228 IF S3 = 3 THEN 9240
9229 GOSUB 9340
9230 GOSUB 8150
9231 LET S6$ = "^" & STR$(E3)
9232 GOTO 9240
9234 LET S6$ = STR$(V(S5))
9240 IF Q5 = 1 THEN 9244
9241 LET Z$ = Z$ & " " & S6$
9242 GOTO 9245
9244 LET Z$ = S6$
9245 IF Q5 <> 3 THEN 9250
9246 IF SEG$(S6$, 1, 1) <> "^" THEN 9248
9247 LET L8 = -VAL(SEG$(S6$, 2, LEN(S6$)))
9248 IF POS("-0123456789", SEG$(S6$, 1, 1)) = 0 THEN 9250
9249 LET L8 = VAL(S6$)
9250 LET Q6 = Q7 + 1
9251 IF Q6 <= LEN(S3$) THEN 9203
9252 GOTO 8050
9295 REM ---- 9300: S5 = the index in V of the name S5$ (Z5$: of the slot K8; Z4$: global) -----------
9300 LET S5 = POS(Z5$, S5$)
9301 IF S5 = 0 THEN 9304
9302 LET S5 = 100 + 25 * K8 + S5
9303 RETURN
9304 LET S5 = POS(Z4$, S5$)
9305 IF S5 > 0 THEN 9303
9306 CALL "dg_bug": P$, "bad script name " & S5$
9320 REM ---- 9325: the local V(S5): S4 its type, S9$ that as a field, S8$ the local as a field
9325 LET S6 = V(S5)
9326 IF S6 <> 0 THEN 9328
9327 CALL "dg_bug": P$, "script name " & S5$ & " is unset"
9328 IF S6 < 0 THEN 9334
9329 LET S4 = U(S6, 1)
9330 LET S8$ = "@" & STR$(S6)
9331 GOTO 9336
9334 LET S4 = A(G(F0, 1) - S6)
9335 LET S8$ = STR$(-S6)
9336 LET S9$ = STR$(S4)
9337 IF S4 > 0 THEN 9339
9338 LET S9$ = "^" & STR$(-S4)
9339 RETURN
9340 REM ---- 9340: E3 = the element type of type S4 (of a tptr, a scalar itself, of an array; F8 ^1: 4)
9341 LET E3 = S4
9342 IF S4 > 0 THEN 9344
9343 LET E3 = -S4
9344 IF E3 <= 9 THEN 9346
9345 LET E3 = T(E3, 2)
9346 IF E3 <> 1 THEN 9348
9347 LET E3 = 4
9348 RETURN
