5000 REM ====================================================================================
5005 REM seafuse part 1 (lines 5000-9999): (B) the walk. Every record of sea.hir in file order;
5010 REM a node's output subtree is the rows H(X,7) .. H(X,8) of the list O (row 0 its head, O9
5015 REM its tail), H(X,0) the row before it. A copied record joins the tail; L19 (fu3elm) writes
5020 REM its records after the subtree of an argument (the cursor C9) or at the tail, and moves
5025 REM the rows of a tasg's targets. N7 S7 T7 count the nodes, locals and types of sea.hirf as a
5030 REM whole; a rewrite that would exceed SEA_LIM_NODES, SEA_LIM_SYMBOLS or SEA_LIM_TYPES is
5035 REM reported at the position P9$ of the emap or lib it implements (status 10). New locals are
5040 REM written @u (u a row of U), the tptr of element type e ^e; fu2out numbers them.
5045 LET N7 = H0
5050 LET S7 = A0
5055 LET T7 = Y9 - 9
5060 LET O0 = 0
5065 LET O9 = 0
5070 LET O(0, 0) = 0
5075 LET U0 = 0
5080 LET F0 = 0
5085 LET Z0 = 0
5090 REM the parents in W (the tree stack is free now; a body block has 0)
5092 FOR X = 1 TO H0
5094 LET W(X) = 0
5096 NEXT X
5098 FOR X = 1 TO H0
5100 LET X1 = H(X, 3)
5102 IF X1 = 0 THEN 5110
5104 LET W(X1) = X
5106 LET X1 = H(X1, 4)
5108 GOTO 5102
5110 NEXT X
5112 GOSUB 30000
5115 FOR R1 = 1 TO D0
5120 LET X = P(R1, 1)
5125 LET R7 = R1
5130 LET K = R(P(R1, 0), 0)
5135 IF K = 63 THEN 5195
5140 IF K < 33 THEN 5160
5142 IF K > 55 THEN 5160
5144 IF K = 42 THEN 5150
5146 IF K > 48 THEN 5150
5148 IF K > 38 THEN 5160
5150 REM a declaration (a type, fn par loc end): copied; fn opens the function F0
5152 IF K <> 33 THEN 5156
5154 LET F0 = X
5156 LET C9 = O9
5158 GOSUB 8000
5159 GOTO 5195
5160 REM ---- a node: H(X,0) the output row before its subtree; L19's nodes, else copied
5162 LET H(X, 0) = O9
5164 LET X1 = H(X, 3)
5166 IF X1 = 0 THEN 5170
5168 LET H(X, 0) = H(X1, 0)
5170 LET C9 = O9
5171 IF Y(X, 1) > 0 THEN 30800
5172 IF K = 64 THEN 5300
5174 IF K = 12 THEN 5400
5176 IF K = 22 THEN 5500
5178 IF K = 32 THEN 5600
5180 IF POS("|21|24|31|", "|" & STR$(K) & "|") > 0 THEN 5450
5182 REM ---- copied after its children
5184 GOSUB 8000
5186 GOTO 5190
5187 REM ---- not written (an emap or ind2sub that its holder statement rewrites)
5188 LET N7 = N7 - 1
5189 REM ---- every node: a limit passed inside its fusion runs the walk again (fu0main 2940); the first and last output rows of its subtree
5190 IF O1 = 1 THEN 2940
5191 LET I9 = 0
5192 LET H(X, 7) = O(H(X, 0), 0)
5194 LET H(X, 8) = O9
5195 NEXT R1
5197 GOTO 10000
5295 REM ---- emap X: validated (20900); deferred to the tbind, eval, tasg or tret holding it as its
5296 REM last child (directly or as the value of a seq), else the value of k = 1 (L19 here)
5300 GOSUB 20900
5302 GOSUB 5700
5304 IF Y8 = 1 THEN 5188
5306 LET I8 = X
5308 LET I7 = 0
5310 LET L6 = 0
5312 LET A7 = 0
5314 GOTO 20000
5395 REM ---- lib: ind2sub with an array r, the last child of a holder: L-cl there (not written)
5400 LET X5 = X
5401 GOSUB 5750
5402 IF Y8 = 0 THEN 5184
5404 LET X5 = W(X)
5406 IF POS("|21|22|24|31|", "|" & STR$(H(X5, 1)) & "|") = 0 THEN 5184
5408 IF H(X, 4) = 0 THEN 5188
5410 GOTO 5184
5445 REM ---- tbind tasg tret: L19 when the last child is an emap (or a seq of one), L-cl an ind2sub
5450 LET X5 = X1
5452 IF H(X5, 4) = 0 THEN 5460
5454 LET X5 = H(X5, 4)
5456 GOTO 5452
5460 LET L6 = K
5462 LET I7 = 0
5464 LET I8 = X5
5466 LET A7 = 0
5468 IF H(X5, 1) <> 12 THEN 5476
5470 LET X5 = I8
5471 GOSUB 5750
5472 IF Y8 = 0 THEN 5184
5474 LET A7 = 1
5475 GOTO 20000
5476 IF H(X5, 1) <> 19 THEN 5486
5478 LET I7 = X5
5480 LET I8 = H(X5, 3)
5482 IF H(I8, 4) = 0 THEN 5486
5484 LET I8 = H(I8, 4)
5485 GOTO 5482
5486 IF H(I8, 1) <> 64 THEN 5184
5488 GOTO 20000
5495 REM ---- eval: its child as a holder's last child
5500 LET X5 = X1
5502 GOTO 5460
5595 REM ---- block: copied, its n grown by the statements L19 put in place of a tbind (H(X,5)) ----
5600 IF H(X, 5) = 0 THEN 5184
5602 LET R2 = H(X, 6)
5604 LET Z$ = D$(R2)
5606 LET F9 = 3
5608 GOSUB 8440
5610 LET F9$ = STR$(VAL(F9$) + H(X, 5))
5612 GOSUB 8470
5614 GOSUB 8050
5616 LET N7 = N7 - 1
5618 GOTO 5190
5695 REM ---- 5700: Y8 = 1 if the emap X is the last child of a tbind, eval, tasg or tret, or of a
5697 REM seq that is such a last child (X5 the holder)
5700 LET Y8 = 0
5702 IF H(X, 4) > 0 THEN 5718
5704 LET X5 = W(X)
5706 IF H(X5, 1) <> 19 THEN 5714
5708 IF H(X5, 4) > 0 THEN 5718
5710 LET X5 = W(X5)
5714 IF POS("|21|22|24|31|", "|" & STR$(H(X5, 1)) & "|") = 0 THEN 5718
5716 LET Y8 = 1
5718 RETURN
5745 REM ---- 5750: Y8 = 1 if the lib X5 is ind2sub(r, k) with an array r (L-cl); n checked
5750 LET Y8 = 0
5752 LET R2 = H(X5, 6)
5754 LET F9 = 4
5756 GOSUB 8440
5758 IF F9$ <> "ind2sub" THEN 5768
5760 IF H(H(X5, 3), 2) <= 9 THEN 5768
5762 IF T(H(H(X5, 3), 2), 1) = 0 THEN 5768
5764 IF H(H(H(X5, 3), 4), 4) > 0 THEN 2900
5766 LET Y8 = 1
5768 RETURN
7995 REM ==== helpers of the walk ==================================================================
7996 REM ---- 8000: a copy of the record R1 in a new row after the cursor C9 (which moves to it) ----
8000 GOSUB 8060
8005 LET O(O0, 1) = R1
8010 RETURN
8045 REM ---- 8050: the generated node Z$ after the cursor; it counts against SEA_LIM_NODES -------
8050 LET N7 = N7 + 1
8052 LET Q2$ = "nodes"
8054 IF N7 <= N8 THEN 8056
8055 GOSUB 8088
8056 GOSUB 8060
8057 LET O(O0, 1) = 0
8058 LET O$(O0) = Z$
8059 GOTO 8080
8060 REM ---- 8060: a new row O0 linked after C9; the cursor moves to it (the tail too, if C9 was it)
8062 IF O0 < 449999 THEN 8066
8063 IF O1 = 1 THEN 8078
8064 CALL "dg_bug": P$, "the output list is full"
8066 LET O0 = O0 + 1
8068 LET O(O0, 0) = O(C9, 0)
8070 LET O(C9, 0) = O0
8072 IF C9 <> O9 THEN 8076
8074 LET O9 = O0
8076 LET C9 = O0
8078 RETURN
8079 REM ---- 8080: a statement counts in the innermost block a script has open (9000)
8080 IF Z0 = 0 THEN 8086
8081 LET J3 = POS(Z$, " ")
8082 IF POS("|tmp|bind|est|chkb|chk|if|cow|mcpy|asg|eval|hloop|rcnt|ret|", "|" & SEG$(Z$, 1, J3 - 1) & "|") = 0 THEN 8086
8084 LET M(Z0, 1) = M(Z0, 1) + 1
8086 RETURN
8087 REM ---- 8088: (8054 8110 8165, fu6grp 52214, fu7red 55652) a limit passed: outside a fusion (I9 = 0) reported (2930); inside one O1 = 1
8088 IF I9 = 0 THEN 2930
8089 IF O1 = 1 THEN 8093
8090 LET O1 = 1
8091 LET O3$ = P9$
8092 LET O4$ = Q2$
8093 RETURN
8094 REM (the first position and name kept, O3$ O4$) and the fusion runs to its end, its output discarded at 5190 (no GOSUB is left pending)
8095 REM ---- 8100: U0 = a new local of type U1 (-e: the tptr of e) and mut U2 (0 let, 1 for) of the
8097 REM function F0, its loc pos that of record R7; it counts against SEA_LIM_SYMBOLS --------
8100 LET S7 = S7 + 1
8105 LET Q2$ = "symbols"
8110 IF S7 <= S8 THEN 8115
8111 GOSUB 8088
8112 IF U0 < 49999 THEN 8115
8113 RETURN
8115 LET U0 = U0 + 1
8120 LET U(U0, 1) = U1
8125 LET U(U0, 2) = U2
8130 LET U(U0, 3) = R7
8135 LET U(U0, 4) = 0
8140 LET G(F0, 4) = G(F0, 4) + 1
8145 RETURN
8146 REM ---- 8150: the tptr of element type E3 is used (logged in I7$ for a walk run again, 2940); a new type counts against SEA_LIM_TYPES ----
8150 IF C(E3, 6) > 0 THEN 8175
8155 LET T7 = T7 + 1
8160 LET Q2$ = "types"
8165 IF T7 <= T9 - 9 THEN 8170
8166 GOSUB 8088
8170 LET C(E3, 6) = 1
8172 LET I7$ = I7$ & "|" & STR$(E3)
8175 RETURN
8395 REM ---- 8400: P9$ = the position field of record R2 ------------------------------------------
8400 LET J3 = POS(D$(R2), " ")
8405 LET J4 = POS(D$(R2), " ", J3 + 1)
8407 IF J4 > 0 THEN 8410
8408 LET J4 = LEN(D$(R2)) + 1
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
8720 LET B5 = T(Y7, 0) * T(Y7, 4) * V(53 + E5)
8722 RETURN
8725 REM ---- 8730: the size of the bool, i64 or f64 element E5 in V5 (any other: bad record) -------
8730 IF E5 < 2 THEN 2900
8732 IF E5 > 4 THEN 2900
8734 LET V5 = V(53 + E5)
8736 RETURN
8895 REM ---- 8900: the script S$ right after the subtree of node X4 (L8 its type: tmp of it) -------
8900 IF H4 > 0 THEN 8906
8901 LET C9 = H(X4, 8)
8902 LET L8 = H(X4, 2)
8904 GOTO 9000
8906 GOSUB 52200
8908 GOTO 8902
8990 REM ==== 9000: the script interpreter ========================================================
8991 REM S$ holds records separated by commas, each written after the cursor C9 at P9$ by 8050,
8992 REM which counts the statements of the innermost open block M(Z0,1). A name is one character:
8993 REM of Z5$ a variable of the slot K8 (V(100 + 25*K8 + i)), else of Z4$ (V(i), the digits %0
8994 REM ... %9 numbers); its value is a row of U. Commands: L x lv;  = x tmp, B x bind (x a new let
8995 REM local of the last type L8);  C v ci;  X x d ext;  D x adat;  K x a new hloop local, its
8996 REM block opened;  ( N K loop(N; K) of 3.5.9;  ? an if's block;  ) closes a loop or an if;  {
8997 REM a block or xblk, } closes it as a block, ] as an xblk; else a record (P the position, @x a
8998 REM local, ^x the tptr of x's element (^d of element d), %x a number).
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
9024 LET S3 = POS("L=BCXDK(?){}]R|>", S4$)
9026 IF S3 = 0 THEN 9200
9028 IF S3 = 4 THEN 9034
9030 IF S3 > 7 THEN 9034
9032 GOSUB 9300
9034 ON S3 GOTO 9040, 9050, 9050, 9070, 9075, 9080, 9060, 9090, 9110, 9120, 9115, 9140, 9150, 9160, 9190, 9180
9038 REM L x: lv of x (L8 = its type)
9040 GOSUB 9325
9042 LET Z$ = "lv " & P9$ & " " & S9$ & " " & S8$
9044 LET L8 = S4
9046 GOTO 8050
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
9075 GOSUB 9040
9076 LET Z$ = "ext " & P9$ & " 3 " & SEG$(S3$, 5, 5)
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
9124 IF S6 < 0 THEN 9131
9125 LET Z$ = "hloop " & P9$ & " @" & STR$(S6)
9126 GOSUB 9133
9127 LET Z$ = "if " & P9$ & " 0"
9128 GOTO 8050
9129 REM ---- 9131: an else arm closed (M = -2): if P 1; 9133: a record, then the block closed
9131 LET Z$ = "if " & P9$ & " 1"
9132 GOTO 8050
9133 GOSUB 8050
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
9159 REM R i l e: rcnt (at Q9$) of incl i into new locals l (i64), e (bool); their loc pos R6's
9160 LET S6 = R7
9161 LET R7 = R6
9162 LET S5$ = SEG$(S3$, 5, 5)
9163 GOSUB 9300
9164 LET U1 = 3
9165 LET U2 = 0
9166 GOSUB 8100
9167 LET V(S5) = U0
9168 LET S8$ = "rcnt " & Q9$ & " " & SEG$(S3$, 3, 3) & " @" & STR$(U0)
9169 LET S5$ = SEG$(S3$, 7, 7)
9170 GOSUB 9300
9171 LET U1 = 2
9172 GOSUB 8100
9173 LET V(S5) = U0
9174 LET R7 = S6
9175 LET Z$ = S8$ & " @" & STR$(U0)
9176 GOTO 8050
9179 REM >: a loop closed that stands in no if (sum8): block, hloop
9180 LET S6 = M(Z0, 2)
9181 GOSUB 9135
9182 LET Z$ = "hloop " & P9$ & " @" & STR$(S6)
9183 GOTO 8050
9189 REM |: the then-block of an if closed, its else-block opened (M(Z0,2) = -2, closed by ')')
9190 GOSUB 9135
9191 LET Z0 = Z0 + 1
9192 LET M(Z0, 1) = 0
9193 LET M(Z0, 2) = -2
9194 RETURN
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
9209 LET S3 = POS("P@^%Q", SEG$(S6$, 1, 1))
9210 IF S3 = 0 THEN 9240
9211 IF S3 = 5 THEN 9255
9212 IF S3 > 1 THEN 9218
9213 IF LEN(S6$) > 1 THEN 9240
9214 LET S6$ = P9$
9215 GOTO 9240
9218 IF S3 <> 3 THEN 9224
9219 IF POS("0123456789", S5$) = 0 THEN 9224
9220 LET E3 = VAL(S5$)
9221 GOSUB 8150
9222 GOTO 9240
9224 GOSUB 9300
9225 IF S3 = 4 THEN 9234
9226 GOSUB 9325
9227 LET S6$ = S8$
9228 IF S3 = 2 THEN 9240
9229 GOSUB 9340
9230 GOSUB 8150
9231 LET S6$ = "^" & STR$(E3)
9232 GOTO 9240
9234 LET S6$ = STR$(V(S5))
9235 IF S5 <> 54 THEN 9240
9236 IF V(S5) <> -20008 THEN 9240
9237 LET S6$ = "^20008"
9238 GOTO 9240
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
9254 REM a Q field: the position Q9$ (a chk's or chkb's node, an rcnt's rng, RES's root)
9255 IF LEN(S6$) > 1 THEN 9240
9256 LET S6$ = Q9$
9257 GOTO 9240
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
9326 IF S6 > 0 THEN 9329
9327 IF S6 < 0 THEN 9332
9328 CALL "dg_bug": P$, "script name " & S5$ & " is unset"
9329 LET S4 = U(S6, 1)
9330 LET S8$ = "@" & STR$(S6)
9331 GOTO 9336
9332 LET S4 = A(G(F0, 1) - S6)
9333 LET S8$ = STR$(-S6)
9336 LET S9$ = STR$(S4)
9337 IF S4 > 0 THEN 9339
9338 LET S9$ = "^" & STR$(-S4)
9339 RETURN
9340 REM ---- 9340: E3 = the element type of type S4 (of a tptr, a scalar itself, of an array)
9341 LET E3 = S4
9342 IF S4 > 0 THEN 9344
9343 LET E3 = -S4
9344 IF E3 <= 9 THEN 9348
9345 LET E3 = T(E3, 2)
9348 RETURN
