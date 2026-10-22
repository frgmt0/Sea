4335 REM ---- sc_check: every check of seacheck (DESIGN 3.4.1, 3.5.5 "What pass 2a has checked"). The
4340 REM symbol rows of the entered items come from their replacement records (rows: sc2util), then
4345 REM sea.res is validated (sc_val, which counts the locals of every function), then every const,
4350 REM then the body of every function and of .main. A violation sets X(26) (BAD_RECORD in main).
4355 SUB "sc_check": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
4360 LET X(29) = 0
4365 LET X(26) = 0
4370 LET F1 = 0
4375 LET C1 = 0
4380 LET S1 = 0
4385 REM count the entered items (replacement records) and the top-level statements
4390 LET I = N(X(17), 7)
4395 IF I = 0 THEN 4485
4400 LET K = N(I, 0)
4405 IF K = 2 THEN 4430
4410 IF K = 3 THEN 4430
4415 IF K = 5 THEN 4430
4420 LET X(29) = X(29) + 1
4425 GOTO 4475
4430 CALL "rpl": N(), M(), I, Z
4435 IF Z = 0 THEN 4475
4440 IF K <> 5 THEN 4455
4445 LET F1 = F1 + 1
4450 GOTO 4475
4455 IF K <> 2 THEN 4470
4460 LET C1 = C1 + 1
4465 GOTO 4475
4470 LET S1 = S1 + 1
4475 LET I = N(I, 8)
4480 GOTO 4395
4485 LET X(30) = 1 + F1
4490 LET X(31) = X(30)
4495 LET X(11) = X(31) + C1
4500 LET X(33) = X(11) + S1
4505 IF X(33) > 49999 THEN 4915
4510 FOR S = 1 TO X(33)
4515 FOR J = 0 TO 9
4520 LET Y(S, J) = 0
4525 NEXT J
4530 NEXT S
4535 LET Y(1, 0) = 1
4540 LET Y(1, 2) = 1
4545 LET Y(1, 5) = 1
4550 REM fid, cid and sid dense from 2, 1 and 1 in stream order
4555 LET G1 = 1
4560 LET G2 = 0
4565 LET G3 = 0
4570 FOR J = 100001 TO 149999
4575 LET W(J) = 0
4580 NEXT J
4585 LET I = N(X(17), 7)
4590 IF I = 0 THEN 4780
4595 LET K = N(I, 0)
4600 IF K = 2 THEN 4615
4605 IF K = 3 THEN 4615
4610 IF K <> 5 THEN 4770
4615 REM an item is entered exactly when no earlier item has its name (DESIGN 3.4.1)
4620 CALL "rpl": N(), M(), I, Z
4625 CALL "nmh": W(), N(I, 6), Z, H
4630 IF H = Z THEN 4915
4635 IF Z = 0 THEN 4770
4640 IF K = 5 THEN 4685
4645 IF K = 2 THEN 4735
4650 IF K <> 3 THEN 4770
4655 LET G3 = G3 + 1
4660 IF N(I, 2) <> G3 THEN 4915
4665 LET R = X(11) + G3
4670 LET Y(R, 0) = 3
4675 LET Y(R, 5) = G3
4680 GOTO 4760
4685 LET G1 = G1 + 1
4690 IF M(I, 2) <> G1 THEN 4915
4695 LET R = G1
4700 LET Y(R, 0) = 1
4705 LET Y(R, 5) = G1
4710 LET Y(R, 4) = N(I, 1)
4715 LET Y(R, 6) = N(I, 2)
4720 LET Y(R, 7) = N(I, 3)
4725 LET Y(R, 2) = M(I, 1)
4730 GOTO 4760
4735 LET G2 = G2 + 1
4740 IF N(I, 2) <> G2 THEN 4915
4745 LET R = X(31) + G2
4750 LET Y(R, 0) = 2
4755 LET Y(R, 5) = G2
4760 LET Y(R, 1) = N(I, 6)
4765 LET Y(R, 3) = I
4770 LET I = N(I, 8)
4775 GOTO 4590
4780 CALL "sc_val": N(), M(), Y(), S$(), X(), X$()
4785 IF X(26) = 1 THEN 4920
4790 REM the local rows of each function: its parameters and declared locals (lids 1..Y(S,8))
4795 LET X(3) = X(33)
4800 FOR S = 1 TO X(30)
4805 LET L0 = Y(S, 8)
4810 LET Y(S, 9) = X(3) + 1
4815 LET X(3) = X(3) + L0
4820 LET Y(S, 8) = X(3)
4825 NEXT S
4830 IF X(3) > 49999 THEN 4915
4835 FOR S = X(33) + 1 TO X(3)
4840 FOR J = 0 TO 9
4845 LET Y(S, J) = 0
4850 NEXT J
4855 NEXT S
4860 CALL "ck_cord": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
4865 FOR S = 2 TO X(30)
4870 CALL "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
4875 NEXT S
4880 CALL "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
4885 REM a program without errors has a value for every constant (DESIGN 3.4.1)
4890 IF X(6) <> 0 THEN 4920
4895 FOR S = X(31) + 1 TO X(11)
4900 IF Y(S, 7) = 6 THEN 4915
4905 NEXT S
4910 GOTO 4920
4915 LET X(26) = 1
4920 SUBEND
4925 REM ---- sc_val: what seacheck validates of the tree of sea.res (DESIGN 3.4.1; the records, rerr
4930 REM and rtup were checked while reading). M(i,3) marks the resolved regions (1 a function body
4935 REM or a top-level statement, 2 a const expression) without the skipped ones (match, a for over
4940 REM anything but a range); the replacement records stand exactly there; then the lids of each
4945 REM function (vwalk), whose count is left in Y(S,8). A violation sets X(26). -------------------
4950 SUB "sc_val": N(), M(), Y(), S$(), X(), X$()
4955 FOR I = 1 TO X(1)
4960 LET M(I, 3) = 0
4965 NEXT I
4970 FOR S = 2 TO X(30)
4975 LET F = Y(S, 3)
4980 CALL "kid": N(), F, Y(S, 6) + Y(S, 7) + 1, B
4985 FOR J = M(B, 0) TO B
4990 LET M(J, 3) = 1
4995 NEXT J
5000 NEXT S
5005 LET I = N(X(17), 7)
5010 IF I = 0 THEN 5060
5015 LET K = N(I, 0)
5020 IF K = 2 THEN 5050
5025 IF K = 3 THEN 5050
5030 IF K = 5 THEN 5050
5035 FOR J = M(I, 0) TO I
5040 LET M(J, 3) = 1
5045 NEXT J
5050 LET I = N(I, 8)
5055 GOTO 5010
5060 FOR S = X(31) + 1 TO X(11)
5065 CALL "cexp": N(), Y(), S, E
5070 FOR J = M(E, 0) TO E
5075 LET M(J, 3) = 2
5080 NEXT J
5085 NEXT S
5090 REM the skipped regions: their whole subtree
5095 FOR I = 1 TO X(1)
5100 IF M(I, 3) = 0 THEN 5145
5105 LET K = N(I, 0)
5110 IF K = 19 THEN 5130
5115 IF K <> 18 THEN 5145
5120 IF N(N(I, 7), 0) = 41 THEN 5145
5125 IF N(I, 3) > 0 THEN 5470
5130 FOR J = M(I, 0) TO I
5135 LET M(J, 3) = 0
5140 NEXT J
5145 NEXT I
5150 REM every node: a replacement exactly where one is required
5155 FOR I = 1 TO X(1)
5160 LET K = N(I, 0)
5165 LET G = M(I, 3)
5170 CALL "rpl": N(), M(), I, Z
5175 IF Z = 0 THEN 5235
5180 IF K = 2 THEN 5225
5185 IF K = 3 THEN 5225
5190 IF K = 5 THEN 5225
5195 IF K = 25 THEN 5360
5200 IF G = 0 THEN 5470
5205 IF K = 34 THEN 5360
5210 IF K = 30 THEN 5260
5215 IF G = 2 THEN 5470
5220 GOTO 5360
5225 IF N(I, 9) <> X(17) THEN 5470
5230 GOTO 5360
5235 IF G = 0 THEN 5360
5240 IF K = 30 THEN 5470
5245 IF K = 10 THEN 5470
5250 IF K = 18 THEN 5470
5255 GOTO 5360
5260 REM rname: k 1 loc (not in a const expression), 2 cst, 3 fn, 4 st, 5 pd, 6 none
5265 LET H = N(I, 2)
5270 ON N(I, 1) GOTO 5275, 5290, 5305, 5320, 5335, 5355
5275 IF G = 2 THEN 5470
5280 IF H < 1 THEN 5470
5285 GOTO 5360
5290 IF H < 1 THEN 5470
5295 IF H > X(11) - X(31) THEN 5470
5300 GOTO 5360
5305 IF H < 2 THEN 5470
5310 IF H > X(30) THEN 5470
5315 GOTO 5360
5320 IF H < 1 THEN 5470
5325 IF H > X(33) - X(11) THEN 5470
5330 GOTO 5360
5335 IF H <> 0 THEN 5470
5340 CALL "pdx": X$(), S$(N(I, 6)), P
5345 IF P = 0 THEN 5470
5350 GOTO 5360
5355 IF H <> 0 THEN 5470
5360 NEXT I
5365 REM the lids of each function: dense from np + 1 in source order; every rname loc names one
5370 FOR S = 2 TO X(30)
5375 LET L = Y(S, 6) + 1
5380 LET Z = 0
5385 LET F = Y(S, 3)
5390 CALL "kid": N(), F, Y(S, 6) + Y(S, 7) + 1, B
5395 CALL "vwalk": N(), M(), X(), B, L, Z
5400 IF Z >= L THEN 5470
5405 LET Y(S, 8) = L - 1
5410 NEXT S
5415 LET L = 1
5420 LET Z = 0
5425 LET I = N(X(17), 7)
5430 IF I = 0 THEN 5455
5435 IF M(I, 3) = 0 THEN 5445
5440 CALL "vwalk": N(), M(), X(), I, L, Z
5445 LET I = N(I, 8)
5450 GOTO 5430
5455 IF Z >= L THEN 5470
5460 LET Y(1, 8) = L - 1
5465 GOTO 5475
5470 LET X(26) = 1
5475 FOR I = 1 TO X(1)
5480 LET M(I, 3) = 0
5485 NEXT I
5490 SUBEND
5495 REM ---- vwalk: the subtree I0 in source order (pre-order: a node before its children, a loop
5500 REM variable before its for's range and body); skipped regions (M(i,3) = 0) are not entered.
5505 REM Each rpname and rfor must have lid L (then L + 1); Z = the largest lid an rname loc names --
5510 SUB "vwalk": N(), M(), X(), I0, L, Z
5515 LET I = I0
5520 IF M(I, 3) = 0 THEN 5610
5525 LET K = N(I, 0)
5530 LET H = N(I, 1)
5535 IF K = 10 THEN 5555
5540 IF K = 30 THEN 5580
5545 IF K <> 18 THEN 5595
5550 LET H = N(I, 3)
5555 IF H = 0 THEN 5595
5560 IF H = L THEN 5570
5565 LET X(26) = 1
5570 LET L = L + 1
5575 GOTO 5595
5580 IF H <> 1 THEN 5595
5585 IF N(I, 2) <= Z THEN 5595
5590 LET Z = N(I, 2)
5595 IF N(I, 7) = 0 THEN 5610
5600 LET I = N(I, 7)
5605 GOTO 5520
5610 IF I = I0 THEN 5640
5615 IF N(I, 8) = 0 THEN 5630
5620 LET I = N(I, 8)
5625 GOTO 5520
5630 LET I = N(I, 9)
5635 GOTO 5610
5640 SUBEND
5645 REM ---- tyof: R = the type written by type node I (phase 1: f64 i64 bool; str is returned as 5
5650 REM and reported by the caller at the node DESIGN 2.6.2 names; others are errors here) ---------
5655 SUB "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I, R
5660 LET R = 0
5665 IF N(I, 1) = 1 THEN 5680
5670 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "arrays", "", "", 1
5675 GOTO 5780
5680 LET B$ = S$(N(I, 6))
5685 LET L0 = LEN(B$)
5690 IF L0 > 6 THEN 5740
5695 IF L0 < 3 THEN 5740
5700 LET P = POS("|f64   |i64   |bool  |str   |Figure|Axes  |Lu    |Chol  |", "|" & SEG$(B$ & "      ", 1, 6) & "|")
5705 IF P = 0 THEN 5740
5710 LET P = (P - 1) / 7 + 1
5715 IF P > 4 THEN 5730
5720 LET R = VAL(SEG$("4325", P, P))
5725 GOTO 5780
5730 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "handle types", "", "", 1
5735 GOTO 5780
5740 REM an identifier: a declared struct (not in phase 1) or no type at all
5745 FOR J = 2 TO X(33)
5750 IF Y(J, 1) <> N(I, 6) THEN 5770
5755 IF Y(J, 0) <> 3 THEN 5770
5760 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "structs", "", "", 1
5765 GOTO 5780
5770 NEXT J
5775 CALL "er": N(), X(), X$(), I, "UNKNOWN_STRUCT", "", "", "", 0
5780 SUBEND
5785 REM ---- ck_const: const item S: its type (LANGUAGE 7.2: i64 when an untyped integer constant
5790 REM and not annotated) and its constant-expression rule; Y(S,4) 1 while checked, 2 done ------
5795 SUB "ck_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
5800 LET Y(S, 4) = 1
5805 LET F = Y(S, 3)
5810 LET X(19) = F
5815 LET E = N(F, 7)
5820 IF N(F, 1) = 0 THEN 5835
5825 LET G = E
5830 LET E = N(E, 8)
5835 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5840 REM a constant expression: literals, constants, operators, pi inf nan eps, sqrt, pow
5845 FOR J = M(E, 0) TO E
5850 LET K = N(J, 0)
5855 IF K = 25 THEN 5980
5860 IF K = 26 THEN 5980
5865 IF K = 28 THEN 5980
5870 IF K = 29 THEN 5980
5875 IF K = 32 THEN 5980
5880 IF K = 33 THEN 5980
5885 IF K = 34 THEN 5980
5890 IF K = 30 THEN 5930
5895 IF K <> 35 THEN 5965
5900 REM a call of sqrt (itself 'not supported yet: sqrt' until phase 4) or pow (LANGUAGE 7.2)
5905 LET H = N(J, 7)
5910 IF N(H, 0) <> 30 THEN 5965
5915 IF S$(N(H, 6)) = "pow" THEN 5980
5920 IF S$(N(H, 6)) <> "sqrt" THEN 5965
5925 GOTO 5980
5930 IF M(J, 2) = 0 THEN 5980
5935 IF N(N(J, 9), 0) <> 35 THEN 5945
5940 IF N(N(J, 9), 7) = J THEN 5980
5945 IF M(J, 2) < 0 THEN 5960
5950 IF Y(M(J, 2), 0) = 2 THEN 5980
5955 GOTO 5965
5960 IF M(J, 2) >= -4 THEN 5980
5965 IF M(E, 1) = 0 THEN 5985
5970 CALL "er": N(), X(), X$(), E, "NOT_CONSTANT", "", "", "", 0
5975 GOTO 5985
5980 NEXT J
5985 IF N(F, 1) = 0 THEN 6025
5990 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G, D
5995 IF D <> 5 THEN 6010
6000 CALL "er": N(), X(), X$(), G, "NOT_SUPPORTED", "strings", "", "", 1
6005 LET D = 0
6010 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
6015 LET Y(S, 2) = D
6020 GOTO 6050
6025 CALL "vu": N(), M(), T(), X(), X$(), E, D
6030 IF D <> -1 THEN 6045
6035 CALL "stl": N(), M(), C(), X(), X$(), E, 3
6040 LET D = 3
6045 LET Y(S, 2) = D
6050 LET Y(S, 4) = 2
6055 SUBEND
6060 REM ---- ck_fn: the body of fn S (S = 1: .main, the top-level statements). The var rule
6065 REM (Decision 8) is decided by re-running the walk while a candidate gains an f64 store (X(16));
6070 REM each run starts from the error state before the function; the local rows are fixed (lids). --
6075 SUB "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
6080 DIM A$(4)
6085 LET E6 = X(6)
6090 LET E7 = X(7)
6095 LET E8 = X(8)
6100 LET E9 = X(9)
6105 LET E5 = X(36)
6110 FOR J = 1 TO 4
6115 LET A$(J) = X$(J)
6120 NEXT J
6125 LET F = Y(S, 3)
6130 LET X(16) = 0
6135 LET X(14) = S
6140 LET X(15) = 0
6145 IF S = 1 THEN 6220
6150 REM the parameters are locals 1..np, their types from rfn (in M(param,1))
6155 LET I = N(F, 7)
6160 FOR J = 1 TO Y(S, 6)
6165 CALL "nloc": N(), Y(), X(), X$(), S$(), N(I, 6), M(I, 1), 4 + N(I, 1), I, 0, J, R
6170 LET M(I, 2) = R
6175 LET I = N(I, 8)
6180 NEXT J
6185 REM the body is the last child
6190 FOR J = 1 TO Y(S, 7)
6195 LET I = N(I, 8)
6200 NEXT J
6205 LET B = I
6210 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
6215 GOTO 6265
6220 LET I = N(X(17), 7)
6225 IF I = 0 THEN 6265
6230 LET K = N(I, 0)
6235 IF K = 2 THEN 6255
6240 IF K = 3 THEN 6255
6245 IF K = 5 THEN 6255
6250 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6255 LET I = N(I, 8)
6260 GOTO 6225
6265 IF X(16) = 0 THEN 6325
6270 IF X(10) = 1 THEN 6325
6275 REM a candidate became f64: the walk is repeated from the state before the function
6280 LET X(6) = E6
6285 LET X(7) = E7
6290 LET X(8) = E8
6295 LET X(9) = E9
6300 LET X(36) = E5
6305 FOR J = 1 TO 4
6310 LET X$(J) = A$(J)
6315 NEXT J
6320 GOTO 6130
6325 IF S = 1 THEN 6345
6330 IF Y(S, 7) = 0 THEN 6345
6335 IF M(B, 9) = 1 THEN 6345
6340 CALL "er": N(), X(), X$(), F, "MISSING_RETURN", "", "", "", 0
6345 SUBEND
6350 REM ---- ck_cord: every const item in the constant order (DESIGN 3.4.1 "Constants"): each after
6355 REM the constants its expression names by rname cst (a depth-first order with an explicit stack
6360 REM in W(1..): pairs (const, next node to scan), no Baysick recursion); each is checked
6365 REM (ck_const) and its value decided (Decision 25: cdec). Y(S,6) 1 waiting, 2 done; a name of a
6370 REM waiting const closes a cycle, which ck_name reports as 'not a constant expression'. --------
6375 SUB "ck_cord": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
6380 FOR S0 = X(31) + 1 TO X(11)
6385 IF Y(S0, 6) <> 0 THEN 6640
6390 LET P = 2
6395 LET W(1) = S0
6400 CALL "cexp": N(), Y(), S0, E
6405 LET W(2) = M(E, 0)
6410 LET Y(S0, 6) = 1
6415 IF P = 0 THEN 6640
6420 LET S = W(P - 1)
6425 LET J = W(P)
6430 CALL "cexp": N(), Y(), S, E
6435 IF J > E THEN 6510
6440 IF N(J, 0) <> 30 THEN 6500
6445 IF N(J, 1) <> 2 THEN 6500
6450 LET R = X(31) + N(J, 2)
6455 IF Y(R, 6) <> 0 THEN 6500
6460 REM a constant not yet visited: it goes first
6465 LET W(P) = J + 1
6470 LET P = P + 2
6475 LET W(P - 1) = R
6480 CALL "cexp": N(), Y(), R, E
6485 LET W(P) = M(E, 0)
6490 LET Y(R, 6) = 1
6495 GOTO 6415
6500 LET J = J + 1
6505 GOTO 6435
6510 LET P = P - 2
6515 LET X9 = X(9)
6520 CALL "ck_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
6525 REM Decision 25 (refined): 1. an error in the check, 2. a named constant without a value, the
6530 REM error type for the constant or any node of its expression (a callee name aside, which has
6535 REM none), or a call of a function item (fn pow, fn sqrt): no value (6) and no further error,
6540 REM even where && or || would not reach the node; 3. otherwise seaname's outcome (cdec)
6545 LET Y(S, 7) = 6
6550 IF X(9) > X9 THEN 6630
6555 IF Y(S, 2) = 0 THEN 6630
6560 CALL "cexp": N(), Y(), S, E
6565 FOR J = M(E, 0) TO E
6570 IF N(J, 0) = 35 THEN 6610
6575 IF N(J, 0) <> 30 THEN 6600
6580 IF N(N(J, 9), 0) <> 35 THEN 6590
6585 IF N(N(J, 9), 7) = J THEN 6620
6590 IF N(J, 1) <> 2 THEN 6600
6595 IF Y(X(31) + N(J, 2), 7) = 6 THEN 6630
6600 IF M(J, 1) = 0 THEN 6630
6605 GOTO 6620
6610 IF N(N(J, 7), 1) <> 5 THEN 6630
6615 GOTO 6600
6620 NEXT J
6625 CALL "cdec": N(), M(), Y(), C(), X(), X$(), H(), S
6630 LET Y(S, 6) = 2
6635 GOTO 6415
6640 NEXT S0
6645 SUBEND
6650 REM ---- cdec: the value of const S from its outcome (DESIGN 3.4.1 step 3): rcni for i64, rcnf for
6655 REM f64, rcnb for bool, a value (C row, or the bool itself; the constants limit at the item); or
6660 REM rcne: integer overflow (ovf at add sub mul neg) or division by zero (div0 at mod) at the node
6665 REM of its expression at epos, now. Anything else sets X(26) (BAD_RECORD). -------------------
6670 SUB "cdec": N(), M(), Y(), C(), X(), X$(), H(), S
6675 LET F = Y(S, 3)
6680 LET O = N(F, 3)
6685 LET D = Y(S, 2)
6690 IF O = 4 THEN 6775
6695 IF O = 3 THEN 6755
6700 IF O > 2 THEN 6865
6705 IF D <> O + 2 THEN 6865
6710 LET A3 = INT(M(F, 1) / 65536)
6715 LET A1 = INT(M(F, 2) / 65536)
6720 CALL "cnew": C(), H(), X(), D, A3, M(F, 1) - 65536 * A3, A1, M(F, 2) - 65536 * A1, R
6725 IF R > 0 THEN 6740
6730 CALL "fatal": N(), X(), X$(), F, "constants"
6735 GOTO 6870
6740 LET Y(S, 8) = R
6745 LET Y(S, 7) = O
6750 GOTO 6870
6755 IF D <> 2 THEN 6865
6760 LET Y(S, 8) = M(F, 1)
6765 LET Y(S, 7) = 3
6770 GOTO 6870
6775 CALL "cexp": N(), Y(), S, E
6780 FOR J = M(E, 0) TO E
6785 IF N(J, 4) <> M(F, 1) THEN 6860
6790 IF N(J, 5) <> M(F, 2) THEN 6860
6795 IF N(J, 0) = 32 THEN 6845
6800 IF N(J, 0) <> 34 THEN 6860
6805 IF N(J, 3) = 1 THEN 6860
6810 IF M(F, 4) = 2 THEN 6830
6815 IF N(J, 1) > 3 THEN 6860
6820 CALL "er": N(), X(), X$(), J, "INT_OVERFLOW_C", "", "", "", 0
6825 GOTO 6870
6830 IF N(J, 1) <> 5 THEN 6860
6835 CALL "er": N(), X(), X$(), J, "INT_DIV_ZERO_C", "", "", "", 0
6840 GOTO 6870
6845 IF M(F, 4) <> 1 THEN 6860
6850 CALL "er": N(), X(), X$(), J, "INT_OVERFLOW_C", "", "", "", 0
6855 GOTO 6870
6860 NEXT J
6865 LET X(26) = 1
6870 SUBEND
6875 REM ---- cexp: E = the expression node of const item S (after its type, if annotated) ----------
6880 SUB "cexp": N(), Y(), S, E
6885 LET E = N(Y(S, 3), 7)
6890 IF N(Y(S, 3), 1) = 0 THEN 6900
6895 LET E = N(E, 8)
6900 SUBEND
6905 REM ---- rpl: Z = 1 when node I is a replacement record of sea.res (DESIGN 3.4.1), recognised by
6910 REM its new fields (layout: sc2util): an entered item (its fid, cid or sid), rname (its k),
6915 REM rpname and rfor (their lid), rint, rpowk ---------------------------------------------------
6920 SUB "rpl": N(), M(), I, Z
6925 LET Z = 0
6930 LET K = N(I, 0)
6935 IF K = 5 THEN 6985
6940 IF K = 25 THEN 7010
6945 IF K = 2 THEN 6995
6950 IF K = 3 THEN 6995
6955 IF K = 30 THEN 7005
6960 IF K = 10 THEN 7005
6965 IF K = 18 THEN 6975
6970 IF K <> 34 THEN 7015
6975 IF N(I, 3) > 0 THEN 7010
6980 GOTO 7015
6985 IF M(I, 2) > 0 THEN 7010
6990 GOTO 7015
6995 IF N(I, 2) > 0 THEN 7010
7000 GOTO 7015
7005 IF N(I, 1) = 0 THEN 7015
7010 LET Z = 1
7015 SUBEND
7020 REM ---- nmh: R = 1 if name Q (S$ index) is in the table of entered item names, a hash in
7025 REM W(100001..149999) (at most 49999 items, X(33)); A = 1 adds it when absent -------------
7030 SUB "nmh": W(), Q, A, R
7035 LET R = 0
7040 LET P = Q - 49999 * INT(Q / 49999) + 100001
7045 IF W(P) = 0 THEN 7085
7050 IF W(P) = Q THEN 7075
7055 LET P = P + 1
7060 IF P <= 149999 THEN 7045
7065 LET P = 100001
7070 GOTO 7045
7075 LET R = 1
7080 GOTO 7095
7085 IF A = 0 THEN 7095
7090 LET W(P) = Q
7095 SUBEND
