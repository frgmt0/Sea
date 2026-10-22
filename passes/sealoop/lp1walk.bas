5000 REM ====================================================================================
5005 REM sealoop part 1 (lines 5000-9999): (B) the rewrite walk (DESIGN 3.5.9). Every record of
5010 REM sea.hir in file order; a node's output subtree is the rows H(X,7) .. H(X,8) of the list O
5015 REM (row 0 its head, O9 its tail). A copied record joins the tail. A rewrite inserts its
5020 REM records after the subtree of a child (the cursor C9) or at the tail: in post-order every
5025 REM child's subtree is complete when its parent's record is met. N7 S7 T7 count the nodes,
5030 REM locals and types of sea.hirl as a whole; a rewrite that would exceed SEA_LIM_NODES,
5035 REM SEA_LIM_SYMBOLS or SEA_LIM_TYPES is reported at the position P9$ of the node it
5040 REM implements (status 10). New locals are written @p (p a row of U) and the tptr of element
5045 REM type e ^e in the generated records; lp2out numbers them in file order.
5050 REM ====================================================================================
5055 LET N7 = H0
5060 LET S7 = A0
5065 LET T7 = Y9 - 9
5070 LET O0 = 0
5075 LET O9 = 0
5080 LET O(0, 0) = 0
5085 LET U0 = 0
5090 LET F0 = 0
5095 FOR R1 = 1 TO D0
5100 LET X = P(R1, 1)
5105 LET K = R(P(R1, 0), 0)
5110 IF K < 33 THEN 5145
5115 IF K = 42 THEN 5130
5120 IF K > 38 THEN 5145
5125 REM a declaration (a type, fn par loc end): copied; fn opens the function F0
5130 IF K <> 33 THEN 5136
5133 LET F0 = X
5136 LET C9 = O9
5139 GOSUB 8000
5142 GOTO 5190
5145 IF K = 41 THEN 7000
5150 IF K <> 12 THEN 5160
5155 IF H(X, 6) > 0 THEN 6000
5160 REM ---- any other node: copied after its children ------------------------------------------
5165 LET C9 = O9
5170 GOSUB 8000
5175 LET H(X, 8) = O0
5180 LET H(X, 7) = O0
5185 IF H(X, 3) = 0 THEN 5190
5187 LET H(X, 7) = H(H(X, 3), 7)
5190 NEXT R1
5195 GOTO 10000
5995 REM ==== L1-L3: lib zeros ones filled len rows cols numel (3.5.9) ===========================
6000 LET W2 = H(X, 6)
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
6560 LET H(X, 7) = H(X1, 7)
6565 LET H(X, 8) = O0
6570 GOTO 5190
6595 REM ---- L3 len(v) rows(m) cols(m) numel(a): ext P 3 dim of the operand; numel of a matrix:
6597 REM xblk P 3 1 { tmp A = a } with the value wbin mul (ext 0 of A) (ext 1 of A) ------------
6600 IF H(X, 5) <> 1 THEN 2900
6605 IF H(X, 2) <> 3 THEN 2900
6610 LET T3 = H(X1, 2)
6615 IF T3 <= 9 THEN 2900
6620 LET K3 = T(T3, 1)
6625 IF K3 = 2 THEN 2900
6630 IF W2 = 7 THEN 6655
6635 IF W2 > 4 THEN 6650
6640 IF K3 <> 1 THEN 2900
6645 GOTO 6655
6650 IF K3 <> 3 THEN 2900
6655 LET Z3 = 0
6660 IF W2 <> 6 THEN 6670
6665 LET Z3 = 1
6670 IF W2 <> 7 THEN 6680
6675 IF K3 = 3 THEN 6700
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
6915 IF K3 = 2 THEN 2900
6920 LET C4 = 1 + INT(K3 / 3)
6925 LET E3 = T(T3, 2)
6930 IF E3 < 2 THEN 2900
6935 IF E3 > 4 THEN 2900
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
7045 IF E3 > 4 THEN 2900
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
8059 RETURN
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
8095 REM ---- 8100: U0 = a new local of type U1 (-e: the tptr of e) and mut U2 (0 let, 1 for) of the
8097 REM function F0, made by the rewrite of record R1; it counts against SEA_LIM_SYMBOLS --------
8100 LET S7 = S7 + 1
8105 LET Q2$ = "symbols"
8110 IF S7 > S8 THEN 2930
8115 LET U0 = U0 + 1
8120 LET U(U0, 1) = U1
8125 LET U(U0, 2) = U2
8130 LET U(U0, 3) = R1
8135 LET U(U0, 4) = 0
8140 LET G(F0, 4) = G(F0, 4) + 1
8145 RETURN
8146 REM ---- 8150: the tptr of element type E3 is used; a new type counts against SEA_LIM_TYPES ----
8150 IF Y(E3) > 0 THEN 8175
8155 LET T7 = T7 + 1
8160 LET Q2$ = "types"
8165 IF T7 > T9 - 9 THEN 2930
8170 LET Y(E3) = 1
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
