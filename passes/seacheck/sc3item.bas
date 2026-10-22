4760 REM ---- sc_check: every check of seacheck (DESIGN 3.4.1, 3.5.5 "What pass 2a has checked"). The
4765 REM symbol rows of the entered items come from their replacement records (rows: sc2util), then
4770 REM sea.res is validated (sc_val, which counts the locals of every function), then every const,
4775 REM then the body of every function and of .main. A violation sets X(26) (BAD_RECORD in main).
4780 SUB "sc_check": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
4785 LET X(29) = 0
4790 LET X(26) = 0
4795 LET F1 = 0
4800 LET C1 = 0
4805 LET S1 = 0
4810 REM count the entered items (replacement records) and the top-level statements
4815 LET I = N(X(17), 7)
4820 IF I = 0 THEN 4910
4825 LET K = N(I, 0)
4830 IF K = 2 THEN 4855
4835 IF K = 3 THEN 4855
4840 IF K = 5 THEN 4855
4845 LET X(29) = X(29) + 1
4850 GOTO 4900
4855 CALL "rpl": N(), M(), I, Z
4860 IF Z = 0 THEN 4900
4865 IF K <> 5 THEN 4880
4870 LET F1 = F1 + 1
4875 GOTO 4900
4880 IF K <> 2 THEN 4895
4885 LET C1 = C1 + 1
4890 GOTO 4900
4895 LET S1 = S1 + 1
4900 LET I = N(I, 8)
4905 GOTO 4820
4910 LET X(30) = 1 + F1
4915 LET X(31) = X(30)
4920 LET X(11) = X(31) + C1
4925 LET X(33) = X(11) + S1
4930 IF X(33) > 49999 THEN 5340
4935 FOR S = 1 TO X(33)
4940 FOR J = 0 TO 9
4945 LET Y(S, J) = 0
4950 NEXT J
4955 NEXT S
4960 LET Y(1, 0) = 1
4965 LET Y(1, 2) = 1
4970 LET Y(1, 5) = 1
4975 REM fid, cid and sid dense from 2, 1 and 1 in stream order
4980 LET G1 = 1
4985 LET G2 = 0
4990 LET G3 = 0
4995 FOR J = 100001 TO 149999
5000 LET W(J) = 0
5005 NEXT J
5010 LET I = N(X(17), 7)
5015 IF I = 0 THEN 5205
5020 LET K = N(I, 0)
5025 IF K = 2 THEN 5040
5030 IF K = 3 THEN 5040
5035 IF K <> 5 THEN 5195
5040 REM an item is entered exactly when no earlier item has its name (DESIGN 3.4.1)
5045 CALL "rpl": N(), M(), I, Z
5050 CALL "nmh": W(), N(I, 6), Z, H
5055 IF H = Z THEN 5340
5060 IF Z = 0 THEN 5195
5065 IF K = 5 THEN 5110
5070 IF K = 2 THEN 5160
5075 IF K <> 3 THEN 5195
5080 LET G3 = G3 + 1
5085 IF N(I, 2) <> G3 THEN 5340
5090 LET R = X(11) + G3
5095 LET Y(R, 0) = 3
5100 LET Y(R, 5) = G3
5105 GOTO 5185
5110 LET G1 = G1 + 1
5115 IF M(I, 2) <> G1 THEN 5340
5120 LET R = G1
5125 LET Y(R, 0) = 1
5130 LET Y(R, 5) = G1
5135 LET Y(R, 4) = N(I, 1)
5140 LET Y(R, 6) = N(I, 2)
5145 LET Y(R, 7) = N(I, 3)
5150 LET Y(R, 2) = M(I, 1)
5155 GOTO 5185
5160 LET G2 = G2 + 1
5165 IF N(I, 2) <> G2 THEN 5340
5170 LET R = X(31) + G2
5175 LET Y(R, 0) = 2
5180 LET Y(R, 5) = G2
5185 LET Y(R, 1) = N(I, 6)
5190 LET Y(R, 3) = I
5195 LET I = N(I, 8)
5200 GOTO 5015
5205 CALL "sc_val": N(), M(), Y(), S$(), X(), X$()
5210 IF X(26) = 1 THEN 5345
5215 REM the local rows of each function: its parameters and declared locals (lids 1..Y(S,8))
5220 LET X(3) = X(33)
5225 FOR S = 1 TO X(30)
5230 LET L0 = Y(S, 8)
5235 LET Y(S, 9) = X(3) + 1
5240 LET X(3) = X(3) + L0
5245 LET Y(S, 8) = X(3)
5250 NEXT S
5255 IF X(3) > 49999 THEN 5340
5260 FOR S = X(33) + 1 TO X(3)
5265 FOR J = 0 TO 9
5270 LET Y(S, J) = 0
5275 NEXT J
5280 NEXT S
5285 CALL "ck_cord": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
5290 FOR S = 2 TO X(30)
5295 CALL "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
5300 NEXT S
5305 CALL "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
5310 REM a program without errors has a value for every constant (DESIGN 3.4.1)
5315 IF X(6) <> 0 THEN 5345
5320 FOR S = X(31) + 1 TO X(11)
5325 IF Y(S, 7) = 6 THEN 5340
5330 NEXT S
5335 GOTO 5345
5340 LET X(26) = 1
5345 SUBEND
5350 REM ---- sc_val: what seacheck validates of the tree of sea.res (DESIGN 3.4.1, 3.4.2; the records,
5355 REM rerr and the type table were checked while reading). M(i,3) marks the resolved regions (1 a
5360 REM function body or a top-level statement, 2 a const expression) without the skipped ones
5365 REM (from 4d only match), and 3 the type nodes of the entered items (parameter and result
5370 REM types, struct field types, const annotations); the replacement records stand exactly there (every type node
5375 REM there an rtype, none elsewhere); then the lids of each function (vwalk), whose count is
5380 REM left in Y(S,8). A violation sets X(26). --------------------------------------------------
5385 SUB "sc_val": N(), M(), Y(), S$(), X(), X$()
5390 FOR I = 1 TO X(1)
5395 LET M(I, 3) = 0
5400 NEXT I
5405 FOR S = 2 TO X(30)
5410 LET F = Y(S, 3)
5415 CALL "kid": N(), F, Y(S, 6) + Y(S, 7) + 1, B
5420 FOR J = M(B, 0) TO B
5425 LET M(J, 3) = 1
5430 NEXT J
5435 NEXT S
5440 LET I = N(X(17), 7)
5445 IF I = 0 THEN 5495
5450 LET K = N(I, 0)
5455 IF K = 2 THEN 5485
5460 IF K = 3 THEN 5485
5465 IF K = 5 THEN 5485
5470 FOR J = M(I, 0) TO I
5475 LET M(J, 3) = 1
5480 NEXT J
5485 LET I = N(I, 8)
5490 GOTO 5445
5495 FOR S = X(31) + 1 TO X(11)
5500 CALL "cexp": N(), Y(), S, E
5505 FOR J = M(E, 0) TO E
5510 LET M(J, 3) = 2
5515 NEXT J
5520 NEXT S
5525 REM the skipped regions (a match): their whole subtree
5530 FOR I = 1 TO X(1)
5535 IF M(I, 3) = 0 THEN 5560
5540 IF N(I, 0) <> 19 THEN 5560
5545 FOR J = M(I, 0) TO I
5550 LET M(J, 3) = 0
5555 NEXT J
5560 NEXT I
5565 REM the type nodes of the entered items: each parameter's first child, the result types
5570 FOR S = 2 TO X(30)
5575 LET H = N(Y(S, 3), 7)
5580 FOR K = 1 TO Y(S, 6) + Y(S, 7)
5585 LET B = H
5590 IF K > Y(S, 6) THEN 5600
5595 LET B = N(H, 7)
5600 FOR J = M(B, 0) TO B
5605 LET M(J, 3) = 3
5610 NEXT J
5615 LET H = N(H, 8)
5620 NEXT K
5625 NEXT S
5630 FOR S = X(31) + 1 TO X(11)
5635 IF N(Y(S, 3), 1) = 0 THEN 5660
5640 LET B = N(Y(S, 3), 7)
5645 FOR J = M(B, 0) TO B
5650 LET M(J, 3) = 3
5655 NEXT J
5660 NEXT S
5665 REM the field types of the entered structs: each field's child
5670 FOR S = X(11) + 1 TO X(33)
5675 LET H = N(Y(S, 3), 7)
5680 IF H = 0 THEN 5715
5685 LET B = N(H, 7)
5690 FOR J = M(B, 0) TO B
5695 LET M(J, 3) = 3
5700 NEXT J
5705 LET H = N(H, 8)
5710 GOTO 5680
5715 NEXT S
5720 REM every node: a replacement exactly where one is required
5725 FOR I = 1 TO X(1)
5730 LET K = N(I, 0)
5735 LET G = M(I, 3)
5740 CALL "rpl": N(), M(), I, Z
5745 IF Z = 0 THEN 5820
5750 IF K = 2 THEN 5810
5755 IF K = 3 THEN 5810
5760 IF K = 5 THEN 5810
5765 IF K = 25 THEN 5950
5770 IF G = 0 THEN 6060
5775 IF K = 34 THEN 5950
5780 IF K = 30 THEN 5850
5785 IF K = 7 THEN 5800
5790 IF G > 1 THEN 6060
5795 GOTO 5950
5800 IF G = 2 THEN 6060
5805 GOTO 5950
5810 IF N(I, 9) <> X(17) THEN 6060
5815 GOTO 5950
5820 IF G = 0 THEN 5950
5825 IF K = 30 THEN 6060
5830 IF K = 10 THEN 6060
5835 IF K = 18 THEN 6060
5840 IF K = 7 THEN 6060
5845 GOTO 5950
5850 REM rname: k 1 loc (not in a const expression or a signature), 2 cst, 3 fn, 4 st, 5 pd, 6 none
5855 LET H = N(I, 2)
5860 ON N(I, 1) GOTO 5865, 5880, 5895, 5910, 5925, 5945
5865 IF G > 1 THEN 6060
5870 IF H < 1 THEN 6060
5875 GOTO 5950
5880 IF H < 1 THEN 6060
5885 IF H > X(11) - X(31) THEN 6060
5890 GOTO 5950
5895 IF H < 2 THEN 6060
5900 IF H > X(30) THEN 6060
5905 GOTO 5950
5910 IF H < 1 THEN 6060
5915 IF H > X(33) - X(11) THEN 6060
5920 GOTO 5950
5925 IF H <> 0 THEN 6060
5930 CALL "pdx": X$(), S$(N(I, 6)), P
5935 IF P = 0 THEN 6060
5940 GOTO 5950
5945 IF H <> 0 THEN 6060
5950 NEXT I
5955 REM the lids of each function: dense from np + 1 in source order; every rname loc names one
5960 FOR S = 2 TO X(30)
5965 LET L = Y(S, 6) + 1
5970 LET Z = 0
5975 LET F = Y(S, 3)
5980 CALL "kid": N(), F, Y(S, 6) + Y(S, 7) + 1, B
5985 CALL "vwalk": N(), M(), X(), B, L, Z
5990 IF Z >= L THEN 6060
5995 LET Y(S, 8) = L - 1
6000 NEXT S
6005 LET L = 1
6010 LET Z = 0
6015 LET I = N(X(17), 7)
6020 IF I = 0 THEN 6045
6025 IF M(I, 3) = 0 THEN 6035
6030 CALL "vwalk": N(), M(), X(), I, L, Z
6035 LET I = N(I, 8)
6040 GOTO 6020
6045 IF Z >= L THEN 6060
6050 LET Y(1, 8) = L - 1
6055 GOTO 6065
6060 LET X(26) = 1
6065 FOR I = 1 TO X(1)
6070 LET M(I, 3) = 0
6075 NEXT I
6080 SUBEND
6085 REM ---- vwalk: the subtree I0 in source order (pre-order: a node before its children, a loop
6090 REM variable before its for's range and body); skipped regions (M(i,3) = 0) are not entered.
6095 REM Each rpname and rfor must have lid L (then L + 1); Z = the largest lid an rname loc names --
6100 SUB "vwalk": N(), M(), X(), I0, L, Z
6105 LET I = I0
6110 IF M(I, 3) = 0 THEN 6200
6115 LET K = N(I, 0)
6120 LET H = N(I, 1)
6125 IF K = 10 THEN 6145
6130 IF K = 30 THEN 6170
6135 IF K <> 18 THEN 6185
6140 LET H = N(I, 3)
6145 IF H = 0 THEN 6185
6150 IF H = L THEN 6160
6155 LET X(26) = 1
6160 LET L = L + 1
6165 GOTO 6185
6170 IF H <> 1 THEN 6185
6175 IF N(I, 2) <= Z THEN 6185
6180 LET Z = N(I, 2)
6185 IF N(I, 7) = 0 THEN 6200
6190 LET I = N(I, 7)
6195 GOTO 6110
6200 IF I = I0 THEN 6230
6205 IF N(I, 8) = 0 THEN 6220
6210 LET I = N(I, 8)
6215 GOTO 6110
6220 LET I = N(I, 9)
6225 GOTO 6200
6230 SUBEND
6235 REM ---- tyof: R = the type of type node I, which seaname resolved: its rtype's ty (0 after
6240 REM seaname's error at it, DESIGN 3.4.2) ---------------------------------------------------
6245 SUB "tyof": N(), I, R
6250 LET R = N(I, 3) - 1
6255 SUBEND
6260 REM ---- ck_const: const item S: its type (LANGUAGE 7.2: i64 when an untyped integer constant
6265 REM and not annotated) and its constant-expression rule; Y(S,4) 1 while checked, 2 done ------
6270 SUB "ck_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
6275 LET Y(S, 4) = 1
6280 LET F = Y(S, 3)
6285 LET X(19) = F
6290 LET E = N(F, 7)
6295 IF N(F, 1) = 0 THEN 6310
6300 LET G = E
6305 LET E = N(E, 8)
6310 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6315 REM a constant expression: literals, constants, operators, pi inf nan eps, sqrt, pow
6320 FOR J = M(E, 0) TO E
6325 LET K = N(J, 0)
6330 IF K = 25 THEN 6455
6335 IF K = 26 THEN 6455
6340 IF K = 28 THEN 6455
6345 IF K = 29 THEN 6455
6350 IF K = 32 THEN 6455
6355 IF K = 33 THEN 6455
6360 IF K = 34 THEN 6455
6365 IF K = 30 THEN 6405
6370 IF K <> 35 THEN 6440
6375 REM a call of sqrt or pow (LANGUAGE 7.2)
6380 LET H = N(J, 7)
6385 IF N(H, 0) <> 30 THEN 6440
6390 IF S$(N(H, 6)) = "pow" THEN 6455
6395 IF S$(N(H, 6)) <> "sqrt" THEN 6440
6400 GOTO 6455
6405 IF M(J, 2) = 0 THEN 6455
6410 IF N(N(J, 9), 0) <> 35 THEN 6420
6415 IF N(N(J, 9), 7) = J THEN 6455
6420 IF M(J, 2) < 0 THEN 6435
6425 IF Y(M(J, 2), 0) = 2 THEN 6455
6430 GOTO 6440
6435 IF M(J, 2) >= -4 THEN 6455
6440 IF M(E, 1) = 0 THEN 6460
6445 CALL "er": N(), X(), X$(), E, "NOT_CONSTANT", "", "", "", 0
6450 GOTO 6460
6455 NEXT J
6460 IF N(F, 1) = 0 THEN 6500
6465 CALL "tyof": N(), G, D
6470 IF D <> 5 THEN 6485
6475 CALL "er": N(), X(), X$(), G, "NOT_SUPPORTED", "strings", "", "", 1
6480 LET D = 0
6485 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
6490 LET Y(S, 2) = D
6495 GOTO 6525
6500 CALL "vu": N(), M(), T(), X(), X$(), E, D
6505 IF D <> -1 THEN 6520
6510 CALL "stl": N(), M(), C(), X(), X$(), E, 3
6515 LET D = 3
6520 LET Y(S, 2) = D
6525 LET Y(S, 4) = 2
6530 SUBEND
6535 REM ---- ck_fn: the body of fn S (S = 1: .main, the top-level statements). The var rule
6540 REM (Decision 8) is decided by re-running the walk while a candidate gains an f64 store (X(16));
6545 REM each run starts from the error state before the function; the local rows are fixed (lids). --
6550 SUB "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
6555 DIM A$(4)
6560 LET E6 = X(6)
6565 LET E7 = X(7)
6570 LET E8 = X(8)
6575 LET E9 = X(9)
6580 LET E5 = X(36)
6585 FOR J = 1 TO 4
6590 LET A$(J) = X$(J)
6595 NEXT J
6600 LET F = Y(S, 3)
6605 LET X(16) = 0
6610 LET X(14) = S
6615 LET X(15) = 0
6620 IF S = 1 THEN 6695
6625 REM the parameters are locals 1..np, their types from rfn (in M(param,1))
6630 LET I = N(F, 7)
6635 FOR J = 1 TO Y(S, 6)
6640 CALL "nloc": N(), Y(), T(), X(), X$(), S$(), N(I, 6), M(I, 1), 4 + N(I, 1), I, 0, J, R
6645 LET M(I, 2) = R
6650 LET I = N(I, 8)
6655 NEXT J
6660 REM the body is the last child
6665 FOR J = 1 TO Y(S, 7)
6670 LET I = N(I, 8)
6675 NEXT J
6680 LET B = I
6685 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
6690 GOTO 6740
6695 LET I = N(X(17), 7)
6700 IF I = 0 THEN 6740
6705 LET K = N(I, 0)
6710 IF K = 2 THEN 6730
6715 IF K = 3 THEN 6730
6720 IF K = 5 THEN 6730
6725 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6730 LET I = N(I, 8)
6735 GOTO 6700
6740 IF X(16) = 0 THEN 6800
6745 IF X(10) = 1 THEN 6800
6750 REM a candidate became f64: the walk is repeated from the state before the function
6755 LET X(6) = E6
6760 LET X(7) = E7
6765 LET X(8) = E8
6770 LET X(9) = E9
6775 LET X(36) = E5
6780 FOR J = 1 TO 4
6785 LET X$(J) = A$(J)
6790 NEXT J
6795 GOTO 6605
6800 IF S = 1 THEN 6820
6805 IF Y(S, 7) = 0 THEN 6820
6810 IF M(B, 9) = 1 THEN 6820
6815 CALL "er": N(), X(), X$(), F, "MISSING_RETURN", "", "", "", 0
6820 SUBEND
6825 REM ---- ck_cord: every const item in the constant order (DESIGN 3.4.1 "Constants"): each after
6830 REM the constants its expression names by rname cst (a depth-first order with an explicit stack
6835 REM in W(1..): pairs (const, next node to scan), no Baysick recursion); each is checked
6840 REM (ck_const) and its value decided (Decision 25: cdec). Y(S,6) 1 waiting, 2 done; a name of a
6845 REM waiting const closes a cycle, which ck_name reports as 'not a constant expression'. --------
6850 SUB "ck_cord": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
6855 FOR S0 = X(31) + 1 TO X(11)
6860 IF Y(S0, 6) <> 0 THEN 7115
6865 LET P = 2
6870 LET W(1) = S0
6875 CALL "cexp": N(), Y(), S0, E
6880 LET W(2) = M(E, 0)
6885 LET Y(S0, 6) = 1
6890 IF P = 0 THEN 7115
6895 LET S = W(P - 1)
6900 LET J = W(P)
6905 CALL "cexp": N(), Y(), S, E
6910 IF J > E THEN 6985
6915 IF N(J, 0) <> 30 THEN 6975
6920 IF N(J, 1) <> 2 THEN 6975
6925 LET R = X(31) + N(J, 2)
6930 IF Y(R, 6) <> 0 THEN 6975
6935 REM a constant not yet visited: it goes first
6940 LET W(P) = J + 1
6945 LET P = P + 2
6950 LET W(P - 1) = R
6955 CALL "cexp": N(), Y(), R, E
6960 LET W(P) = M(E, 0)
6965 LET Y(R, 6) = 1
6970 GOTO 6890
6975 LET J = J + 1
6980 GOTO 6910
6985 LET P = P - 2
6990 LET X9 = X(9)
6995 CALL "ck_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
7000 REM Decision 25 (refined): 1. an error in the check, 2. a named constant without a value, the
7005 REM error type for the constant or any node of its expression (a callee name aside, which has
7010 REM none), or a call of a function item (fn pow, fn sqrt): no value (6) and no further error,
7015 REM even where && or || would not reach the node; 3. otherwise seaname's outcome (cdec)
7020 LET Y(S, 7) = 6
7025 IF X(9) > X9 THEN 7105
7030 IF Y(S, 2) = 0 THEN 7105
7035 CALL "cexp": N(), Y(), S, E
7040 FOR J = M(E, 0) TO E
7045 IF N(J, 0) = 35 THEN 7085
7050 IF N(J, 0) <> 30 THEN 7075
7055 IF N(N(J, 9), 0) <> 35 THEN 7065
7060 IF N(N(J, 9), 7) = J THEN 7095
7065 IF N(J, 1) <> 2 THEN 7075
7070 IF Y(X(31) + N(J, 2), 7) = 6 THEN 7105
7075 IF M(J, 1) = 0 THEN 7105
7080 GOTO 7095
7085 IF N(N(J, 7), 1) <> 5 THEN 7105
7090 GOTO 7075
7095 NEXT J
7100 CALL "cdec": N(), M(), Y(), C(), X(), X$(), H(), S
7105 LET Y(S, 6) = 2
7110 GOTO 6890
7115 NEXT S0
7120 SUBEND
7125 REM ---- cdec: the value of const S from its outcome (DESIGN 3.4.1 step 3): rcni for i64, rcnf for
7130 REM f64, rcnb for bool, a value (C row, or the bool itself; the constants limit at the item); or
7135 REM rcne: integer overflow (ovf at add sub mul neg) or division by zero (div0 at mod) at the node
7140 REM of its expression at epos, now. Anything else sets X(26) (BAD_RECORD). -------------------
7145 SUB "cdec": N(), M(), Y(), C(), X(), X$(), H(), S
7150 LET F = Y(S, 3)
7155 LET O = N(F, 3)
7160 LET D = Y(S, 2)
7165 IF O = 4 THEN 7250
7170 IF O = 3 THEN 7230
7175 IF O > 2 THEN 7340
7180 IF D <> O + 2 THEN 7340
7185 LET A3 = INT(M(F, 1) / 65536)
7190 LET A1 = INT(M(F, 2) / 65536)
7195 CALL "cnew": C(), H(), X(), D, A3, M(F, 1) - 65536 * A3, A1, M(F, 2) - 65536 * A1, R
7200 IF R > 0 THEN 7215
7205 CALL "fatal": N(), X(), X$(), F, "constants"
7210 GOTO 7345
7215 LET Y(S, 8) = R
7220 LET Y(S, 7) = O
7225 GOTO 7345
7230 IF D <> 2 THEN 7340
7235 LET Y(S, 8) = M(F, 1)
7240 LET Y(S, 7) = 3
7245 GOTO 7345
7250 CALL "cexp": N(), Y(), S, E
7255 FOR J = M(E, 0) TO E
7260 IF N(J, 4) <> M(F, 1) THEN 7335
7265 IF N(J, 5) <> M(F, 2) THEN 7335
7270 IF N(J, 0) = 32 THEN 7320
7275 IF N(J, 0) <> 34 THEN 7335
7280 IF N(J, 3) = 1 THEN 7335
7285 IF M(F, 4) = 2 THEN 7305
7290 IF N(J, 1) > 3 THEN 7335
7295 CALL "er": N(), X(), X$(), J, "INT_OVERFLOW_C", "", "", "", 0
7300 GOTO 7345
7305 IF N(J, 1) <> 5 THEN 7335
7310 CALL "er": N(), X(), X$(), J, "INT_DIV_ZERO_C", "", "", "", 0
7315 GOTO 7345
7320 IF M(F, 4) <> 1 THEN 7335
7325 CALL "er": N(), X(), X$(), J, "INT_OVERFLOW_C", "", "", "", 0
7330 GOTO 7345
7335 NEXT J
7340 LET X(26) = 1
7345 SUBEND
7350 REM ---- cexp: E = the expression node of const item S (after its type, if annotated) ----------
7355 SUB "cexp": N(), Y(), S, E
7360 LET E = N(Y(S, 3), 7)
7365 IF N(Y(S, 3), 1) = 0 THEN 7375
7370 LET E = N(E, 8)
7375 SUBEND
7380 REM ---- rpl: Z = 1 when node I is a replacement record of sea.res (DESIGN 3.4.1), recognised by
7385 REM its new fields (layout: sc2util): an entered item (its fid, cid or sid), rname (its k),
7390 REM rpname and rfor (their lid), rint, rpowk, rtype (its ty + 1) ------------------------------
7395 SUB "rpl": N(), M(), I, Z
7400 LET Z = 0
7405 LET K = N(I, 0)
7410 IF K = 5 THEN 7465
7415 IF K = 25 THEN 7490
7420 IF K = 2 THEN 7475
7425 IF K = 3 THEN 7475
7430 IF K = 30 THEN 7485
7435 IF K = 10 THEN 7485
7440 IF K = 18 THEN 7455
7445 IF K = 7 THEN 7455
7450 IF K <> 34 THEN 7495
7455 IF N(I, 3) > 0 THEN 7490
7460 GOTO 7495
7465 IF M(I, 2) > 0 THEN 7490
7470 GOTO 7495
7475 IF N(I, 2) > 0 THEN 7490
7480 GOTO 7495
7485 IF N(I, 1) = 0 THEN 7495
7490 LET Z = 1
7495 SUBEND
7500 REM ---- nmh: R = 1 if name Q (S$ index) is in the table of entered item names, a hash in
7505 REM W(100001..149999) (at most 49999 items, X(33)); A = 1 adds it when absent -------------
7510 SUB "nmh": W(), Q, A, R
7515 LET R = 0
7520 LET P = Q - 49999 * INT(Q / 49999) + 100001
7525 IF W(P) = 0 THEN 7565
7530 IF W(P) = Q THEN 7555
7535 LET P = P + 1
7540 IF P <= 149999 THEN 7525
7545 LET P = 100001
7550 GOTO 7525
7555 LET R = 1
7560 GOTO 7575
7565 IF A = 0 THEN 7575
7570 LET W(P) = Q
7575 SUBEND
