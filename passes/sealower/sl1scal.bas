3130 REM ==== the nodes (state 0) and their resume points ============================================
3135 REM ---- constants: li / lf into the dest or a new register (rules 1, 3) ----------------------
3140 LET C1 = 1
3145 GOSUB 7470
3150 GOSUB 7865
3155 LET V1 = D2
3160 GOSUB 7500
3165 LET L1$ = "li " & Z$ & " " & S$(H(X, 0))
3170 GOTO 3290
3175 LET C1 = 1
3180 GOSUB 7470
3185 GOSUB 7865
3190 LET V1 = D2
3195 GOSUB 7500
3200 LET L1$ = "li " & Z$ & " " & STR$(H(X, 5))
3205 GOTO 3290
3210 LET C1 = 2
3215 GOSUB 7470
3220 GOSUB 7865
3225 LET V1 = D2
3230 GOSUB 7500
3235 LET L1$ = "lf " & Z$ & " " & S$(H(X, 0))
3240 GOTO 3290
3245 REM a string constant: a str data record and la (rule 7)
3250 LET C1 = 3
3255 GOSUB 7470
3260 LET Q3 = 1
3265 LET Q4 = X
3270 GOSUB 7935
3275 LET V1 = D2
3280 GOSUB 7500
3285 LET L1$ = "la " & Z$ & " d" & STR$(D0)
3290 GOSUB 7695
3295 LET R9 = D2
3300 GOTO 3090
3305 REM ---- lv: no instruction (rule 1), mov into a dest (rule 2), a load for a ref parameter -----
3310 LET A1 = H(X, 5)
3315 IF V(A1, 1) = 3 THEN 3385
3320 LET R9 = A1
3325 IF D > 0 THEN 3355
3330 IF H(X, 6) = 0 THEN 3090
3335 REM a snapshot (rule 12): mov T L into a new register
3340 LET C1 = V(A1, 1)
3345 GOSUB 7420
3350 LET D = N2
3355 LET O$ = "mov"
3360 LET V2 = D
3365 LET V3 = A1
3370 GOSUB 7540
3375 LET R9 = D
3380 GOTO 3090
3385 LET T1 = A(G(F0, 0) + A1, 1)
3390 GOSUB 7395
3395 GOSUB 7470
3400 LET V2 = D2
3405 LET V3 = A1
3410 LET Z3 = 0
3415 GOSUB 7640
3420 LET R9 = D2
3425 GOTO 3090
3430 REM ---- cvt: itof (rule 1) --------------------------------------------------------------------
3435 LET S = 1
3440 GOTO 7370
3445 LET C1 = 2
3450 GOSUB 7470
3455 LET O$ = "itof"
3460 LET V2 = D2
3465 LET V3 = R9
3470 GOSUB 7540
3475 LET R9 = D2
3480 GOTO 3090
3485 REM ---- un: inegc (i64, checked), fneg, bnot (rule 1) -----------------------------------------
3490 LET S = 2
3495 GOTO 7370
3500 LET T1 = H(X, 4)
3505 GOSUB 7395
3510 GOSUB 7470
3515 LET V2 = D2
3520 LET V3 = R9
3525 LET O$ = "bnot"
3530 IF H(X, 5) = 2 THEN 3555
3535 LET O$ = "fneg"
3540 IF C1 = 2 THEN 3555
3545 LET O$ = "inegc"
3550 GOSUB 7775
3555 GOSUB 7540
3560 LET R9 = D2
3565 GOTO 3090
3570 REM ---- bin: left, right, one instruction (rules 1, 11); && and || by rule 3 -------------------
3575 IF H(X, 5) = 16 THEN 3820
3580 IF H(X, 5) = 17 THEN 3820
3585 LET S = 3
3590 GOTO 7370
3595 LET W(W0 + 3) = R9
3600 LET S = 4
3605 LET X1 = H(H(X, 7), 8)
3610 LET D1 = 0
3615 GOTO 7380
3620 LET A1 = W(W0 + 3)
3625 LET A2 = R9
3630 LET A3 = H(X, 5)
3635 LET T1 = H(H(X, 7), 4)
3640 GOSUB 7395
3645 LET C2 = C1
3650 LET T1 = H(X, 4)
3655 GOSUB 7395
3660 GOSUB 7470
3665 LET V2 = D2
3670 LET V3 = A1
3675 LET V4 = A2
3680 IF A3 > 18 THEN 2360
3685 ON A3 GOTO 3690, 3690, 3690, 3720, 3735, 8505, 2360, 3760, 3760, 3760, 3760, 3760, 3760, 3785, 3795, 2360, 2360, 2360
3690 LET O$ = SEG$("faddfsubfmul", 4 * A3 - 3, 4 * A3)
3695 IF C2 = 2 THEN 3800
3700 IF C2 <> 1 THEN 2360
3705 LET O$ = SEG$("iaddcisubcimulc", 5 * A3 - 4, 5 * A3)
3710 GOSUB 7775
3715 GOTO 3800
3720 IF C2 <> 2 THEN 2360
3725 LET O$ = "fdiv"
3730 GOTO 3800
3735 IF C2 <> 1 THEN 2360
3740 IF H(H(X, 7), 4) <> 3 THEN 2360
3745 LET O$ = "imodf"
3750 GOSUB 7775
3755 GOTO 3800
3760 LET O$ = "icmp " & S$(H(X, 0))
3765 IF C2 = 1 THEN 3800
3770 IF C2 <> 2 THEN 2360
3775 LET O$ = "fcmp " & S$(H(X, 0))
3780 GOTO 3800
3785 LET O$ = "iand"
3790 GOTO 3800
3795 LET O$ = "ior"
3800 GOSUB 7575
3805 LET R9 = D2
3810 GOTO 3090
3815 REM && / ||: R = a; if (&&) or ifz (||) B R; R = b; endif B; a local dest then gets mov L R
3820 GOSUB 3985
3825 LET W(W0 + 3) = D2
3830 LET S = 5
3835 LET X1 = H(X, 7)
3840 LET D1 = D2
3845 GOTO 7380
3850 GOSUB 7885
3855 LET W(W0 + 4) = B7
3860 LET L1$ = "ifz " & STR$(B7) & " "
3865 IF H(X, 5) = 17 THEN 3875
3870 LET L1$ = "if " & STR$(B7) & " "
3875 LET V1 = W(W0 + 3)
3880 GOSUB 7500
3885 LET L1$ = L1$ & Z$
3890 GOSUB 7695
3895 LET S = 6
3900 LET X1 = H(H(X, 7), 8)
3905 LET D1 = W(W0 + 3)
3910 GOTO 7380
3915 LET L1$ = "endif " & STR$(W(W0 + 4))
3920 GOSUB 7695
3925 GOTO 3935
3930 REM the value R of an ifx / && / ||: a new register, or the given one; a local gets mov L R
3935 LET R9 = W(W0 + 3)
3940 IF D < 1 THEN 3090
3945 IF D > N7 THEN 3090
3950 LET O$ = "mov"
3955 LET V2 = D
3960 LET V3 = R9
3965 GOSUB 7540
3970 LET R9 = D
3975 GOTO 3090
3980 REM 3985: D2 = R, a new register of the node's class unless D is a given new register
3985 LET D2 = D
3990 IF D > N7 THEN 4015
3995 LET T1 = H(X, 4)
4000 GOSUB 7395
4005 GOSUB 7420
4010 LET D2 = N2
4015 RETURN
4020 REM ---- ifx: c; if B c; R = then; else B; R = else; endif B (rule 3) ---------------------------
4025 LET S = 7
4030 GOTO 7370
4035 GOSUB 7885
4040 LET W(W0 + 4) = B7
4045 LET L1$ = "if " & STR$(B7) & " "
4050 LET V1 = R9
4055 GOSUB 7500
4060 LET L1$ = L1$ & Z$
4065 GOSUB 7695
4070 GOSUB 3985
4075 LET W(W0 + 3) = D2
4080 LET S = 8
4085 LET X1 = H(H(X, 7), 8)
4090 LET D1 = D2
4095 GOTO 7380
4100 LET L1$ = "else " & STR$(W(W0 + 4))
4105 GOSUB 7695
4110 LET S = 9
4115 LET X1 = H(H(H(X, 7), 8), 8)
4120 LET D1 = W(W0 + 3)
4125 GOTO 7380
4130 LET L1$ = "endif " & STR$(W(W0 + 4))
4135 GOSUB 7695
4140 GOTO 3935
4145 REM ---- powk: x^0 = 1, x^1 = x, x^2 = x*x, x^3 = (x*x)*x, x^4 = (x*x)*(x*x), x^-k = 1/x^k --
4150 LET S = 10
4155 GOTO 7370
4160 LET A1 = R9
4165 LET A3 = H(X, 5)
4170 LET A2 = ABS(A3)
4175 IF A2 > 4 THEN 2360
4180 LET C1 = 2
4185 GOSUB 7470
4190 IF A3 <> 0 THEN 4230
4195 LET V1 = D2
4200 GOSUB 7500
4205 GOSUB 7865
4210 LET L1$ = "lf " & Z$ & " #3FF0000000000000"
4215 GOSUB 7695
4220 GOTO 4430
4225 REM A4 = the register of x^|k|: D2 itself for k > 0
4230 LET A4 = D2
4235 IF A3 > 0 THEN 4260
4240 LET A4 = A1
4245 IF A2 = 1 THEN 4370
4250 GOSUB 7420
4255 LET A4 = N2
4260 IF A2 > 1 THEN 4290
4265 LET O$ = "mov"
4270 LET V2 = A4
4275 LET V3 = A1
4280 GOSUB 7540
4285 GOTO 4370
4290 LET O$ = "fmul"
4295 LET V2 = A4
4300 IF A2 = 2 THEN 4315
4305 GOSUB 7420
4310 LET V2 = N2
4315 LET V3 = A1
4320 LET V4 = A1
4325 GOSUB 7575
4330 IF A2 = 2 THEN 4370
4335 LET V3 = V2
4340 LET V4 = A1
4345 IF A2 = 3 THEN 4355
4350 LET V4 = V2
4355 LET V2 = A4
4360 GOSUB 7575
4365 REM a negative k: 1 / x^|k|
4370 IF A3 > 0 THEN 4430
4375 GOSUB 7420
4380 LET V1 = N2
4385 GOSUB 7500
4390 GOSUB 7865
4395 LET L1$ = "lf " & Z$ & " #3FF0000000000000"
4400 GOSUB 7695
4405 LET O$ = "fdiv"
4410 LET V2 = D2
4415 LET V3 = N2
4420 LET V4 = A4
4425 GOSUB 7575
4430 LET R9 = D2
4435 GOTO 3090
4440 REM ---- call: the arguments left to right (rarg by rule 12), call, the reloads (rules 2, 5) ---
4445 REM frame: x1 = U0 at entry (the arguments are U(x1+1 ..)), x2 = the next argument
4450 IF H(X, 5) > G0 THEN 2360
4455 LET W(W0 + 3) = U0
4460 LET W(W0 + 4) = H(X, 7)
4465 LET X2 = W(W0 + 4)
4470 IF X2 = 0 THEN 4660
4475 IF H(X2, 1) = 11 THEN 4515
4480 LET S = 11
4485 LET X1 = X2
4490 LET D1 = 0
4495 GOTO 7380
4500 LET Q5 = 0
4505 GOTO 4630
4510 REM a rarg of a local L: its ref parameter register, or a slot holding L, reloaded later
4515 LET X3 = H(X2, 7)
4520 IF H(X3, 1) <> 5 THEN 2360
4525 LET A1 = H(X3, 5)
4530 LET R9 = A1
4535 LET Q5 = 0
4540 IF V(A1, 1) = 3 THEN 4630
4545 LET Z1 = E7
4550 IF V(A1, 1) = 1 THEN 4560
4555 LET Z1 = E8
4560 LET Z2 = Z1
4565 GOSUB 7905
4570 LET C1 = 3
4575 GOSUB 7420
4580 LET V1 = N2
4585 GOSUB 7500
4590 LET L1$ = "sa " & Z$ & " s" & STR$(S5)
4595 GOSUB 7695
4600 LET V2 = A1
4605 LET V3 = N2
4610 LET Z3 = 0
4615 GOSUB 7650
4620 LET R9 = N2
4625 LET Q5 = A1
4630 GOSUB 7970
4635 LET U(U0, 1) = R9
4640 LET U(U0, 2) = Q5
4645 LET W(W0 + 4) = H(W(W0 + 4), 8)
4650 GOTO 4465
4655 REM the call record; a result register that is also reloaded gets a new register, moved after
4660 LET A1 = W(W0 + 3)
4665 LET T1 = G(H(X, 5), 3)
4670 GOSUB 2935
4675 LET Q6 = Z5
4680 LET R9 = 0
4685 IF D = -1 THEN 4745
4690 IF D = -2 THEN 4750
4695 IF Q6 = 0 THEN 4745
4700 IF Q6 <> 1 THEN 2360
4705 LET C1 = POS("ifp", SEG$(Z5$, 2, 2))
4710 GOSUB 7470
4715 GOSUB 7970
4720 LET U(U0, 1) = D2
4725 LET U(U0, 2) = 0
4730 LET R9 = D2
4735 LET A2 = U0
4740 GOTO 4760
4745 LET Q6 = 0
4750 LET A2 = A1
4755 REM the results are U(A2-Q6+1 .. A2), the arguments U(W(W0+3)+1 .. W(W0+3)+n)
4760 FOR I = A2 - Q6 + 1 TO A2
4765 LET A3 = U(I, 1)
4770 IF A3 > N7 THEN 4810
4775 FOR X6 = W(W0 + 3) + 1 TO W(W0 + 3) + H(X, 6)
4780 IF U(X6, 2) <> A3 THEN 4805
4785 LET C1 = V(A3, 1)
4790 GOSUB 7420
4795 LET U(I, 1) = N2
4800 LET U(I, 2) = A3
4805 NEXT X6
4810 NEXT I
4815 LET L1$ = "call " & S$(G(H(X, 5), 1)) & " " & STR$(Q6)
4820 FOR I = A2 - Q6 + 1 TO A2
4825 LET V1 = U(I, 1)
4830 GOSUB 7500
4835 LET L1$ = L1$ & " " & Z$
4840 NEXT I
4845 LET L1$ = L1$ & " " & STR$(H(X, 6))
4850 FOR I = W(W0 + 3) + 1 TO W(W0 + 3) + H(X, 6)
4855 LET V1 = U(I, 1)
4860 GOSUB 7500
4865 LET L1$ = L1$ & " " & Z$
4870 NEXT I
4875 GOSUB 7695
4880 REM rule 12: reload each slot argument's local, in argument order
4885 FOR I = W(W0 + 3) + 1 TO W(W0 + 3) + H(X, 6)
4890 IF U(I, 2) = 0 THEN 4915
4895 LET V2 = U(I, 2)
4900 LET V3 = U(I, 1)
4905 LET Z3 = 0
4910 GOSUB 7640
4915 NEXT I
4920 REM then the results that had to wait for the reloads
4925 FOR I = A2 - Q6 + 1 TO A2
4930 IF U(I, 2) <= 0 THEN 4965
4935 LET O$ = "mov"
4940 LET V2 = U(I, 2)
4945 LET V3 = U(I, 1)
4950 GOSUB 7540
4955 LET U(I, 1) = V2
4960 LET U(I, 2) = 0
4965 NEXT I
4970 LET U0 = W(W0 + 3)
4975 GOTO 3090
4980 REM ---- lib: printf (rule 8), now (9), f64 and i64 (10), idiv (11); log exp sin cos pow hypot (14)-------------------------
4985 LET K3$ = "|printf |now    |f64    |i64    |idiv   |log    |exp    |sin    |cos    |pow    |hypot  "
4990 LET W2$ = S$(H(X, 0))
4995 GOSUB 1875
5000 IF W2 = 0 THEN 2360
5005 IF H(X, 6) <> VAL(SEG$("10112111122", W2, W2)) THEN 2360
5010 ON W2 GOTO 5020, 5335, 5390, 5390, 5500, 8600, 8600, 8600, 8600, 8600, 8600
5015 REM printf: frame x1 = U0 at entry, x2 = the next piece of the fmt
5020 LET X2 = H(X, 7)
5025 IF H(X2, 1) <> 13 THEN 2365
5030 LET W(W0 + 3) = U0
5035 LET W(W0 + 4) = H(X2, 7)
5040 LET X2 = W(W0 + 4)
5045 IF X2 = 0 THEN 5120
5050 IF H(X2, 1) = 14 THEN 5105
5055 IF H(X2, 1) <> 15 THEN 2365
5060 LET S = 12
5065 LET X1 = H(X2, 7)
5070 LET D1 = 0
5075 GOTO 7380
5080 GOSUB 7970
5085 LET U(U0, 1) = R9
5090 LET T1 = H(H(W(W0 + 4), 7), 4)
5095 GOSUB 7395
5100 LET U(U0, 2) = C1
5105 LET W(W0 + 4) = H(W(W0 + 4), 8)
5110 GOTO 5040
5115 REM the slot of SLOT_SIZE * max(n, 1) bytes, one store per argument, la of the fmt, rcall
5120 LET A1 = U0 - W(W0 + 3)
5125 LET Z1 = Z7 * A1
5130 IF A1 > 0 THEN 5140
5135 LET Z1 = Z7
5140 LET Z2 = Z7
5145 GOSUB 7905
5150 LET C1 = 3
5155 GOSUB 7420
5160 LET A2 = N2
5165 LET V1 = A2
5170 GOSUB 7500
5175 LET L1$ = "sa " & Z$ & " s" & STR$(S5)
5180 GOSUB 7695
5185 FOR I = 1 TO A1
5190 LET V2 = U(W(W0 + 3) + I, 1)
5195 LET V3 = A2
5200 LET Z3 = Z7 * (I - 1)
5205 LET O$ = SEG$("stistfstp", 3 * U(W(W0 + 3) + I, 2) - 2, 3 * U(W(W0 + 3) + I, 2))
5210 GOSUB 7655
5215 NEXT I
5220 LET Q3 = 2
5225 LET Q4 = H(X, 7)
5230 GOSUB 7935
5235 LET C1 = 3
5240 GOSUB 7420
5245 LET A3 = N2
5250 LET V1 = A3
5255 GOSUB 7500
5260 LET L1$ = "la " & Z$ & " d" & STR$(D0)
5265 GOSUB 7695
5270 LET Q9 = Y1
5275 GOSUB 5590
5280 LET V1 = A3
5285 GOSUB 7500
5290 LET L1$ = L1$ & " " & STR$(LEN(Y$(Y1, 4))) & " " & Z$
5295 LET V1 = A2
5300 GOSUB 7500
5305 LET L1$ = L1$ & " " & Z$
5310 GOSUB 7695
5315 LET U0 = W(W0 + 3)
5320 LET R9 = 0
5325 GOTO 3090
5330 REM now: rcall of the entry NOW into the dest or a new f register
5335 LET C1 = 2
5340 GOSUB 7470
5345 LET Q9 = Y2
5350 GOSUB 5590
5355 LET V1 = D2
5360 GOSUB 7500
5365 LET L1$ = L1$ & " " & Z$ & " 0"
5370 GOSUB 7695
5375 LET R9 = D2
5380 GOTO 3090
5385 REM f64(x): itof, or mov for an f64; i64(x): ftoi for an f64, else mov
5390 LET S = 13
5395 GOTO 7370
5400 LET T1 = H(H(X, 7), 4)
5405 GOSUB 7395
5410 LET C2 = C1
5415 LET C1 = 1
5420 IF S$(H(X, 0)) = "i64" THEN 5430
5425 LET C1 = 2
5430 GOSUB 7470
5435 LET V2 = D2
5440 LET V3 = R9
5445 LET O$ = "mov"
5450 IF C1 = C2 THEN 5480
5455 IF C2 = 3 THEN 2360
5460 LET O$ = "itof"
5465 IF C1 = 2 THEN 5480
5470 LET O$ = "ftoi"
5475 GOSUB 7775
5480 GOSUB 7540
5485 LET R9 = D2
5490 GOTO 3090
5495 REM idiv(a, b): idivf with the node's line as site
5500 LET S = 14
5505 GOTO 7370
5510 LET W(W0 + 3) = R9
5515 LET S = 15
5520 LET X1 = H(H(X, 7), 8)
5525 LET D1 = 0
5530 GOTO 7380
5535 LET C1 = 1
5540 GOSUB 7470
5545 LET O$ = "idivf"
5550 LET V2 = D2
5555 LET V3 = W(W0 + 3)
5560 LET V4 = R9
5565 GOSUB 7775
5570 GOSUB 7575
5575 LET R9 = D2
5580 GOTO 3090
5585 REM 5590: L1$ = "rcall <symbol> <site or -> <nr>" of entry row Q9; its results go after it
5590 LET L1$ = "rcall " & Y$(Q9, 2) & " -"
5592 LET S7 = 1
5595 IF Y$(Q9, 3) <> "S" THEN 5615
5600 GOSUB 7775
5605 LET L1$ = "rcall " & Y$(Q9, 2) & " " & Z9$
5610 LET S7 = 1
5615 LET Z4 = LEN(Y$(Q9, 5))
5620 IF Y$(Q9, 5) <> "-" THEN 5630
5625 LET Z4 = 0
5630 LET L1$ = L1$ & " " & STR$(Z4)
5635 RETURN
5640 REM ---- seq: the bind nodes in order, then the value in the seq's place (rule 5) -------------
5645 LET W(W0 + 4) = H(X, 7)
5650 LET X2 = W(W0 + 4)
5655 LET X1 = X2
5660 LET D1 = D
5665 IF H(X2, 8) = 0 THEN 5685
5670 LET S = 16
5675 LET D1 = 0
5680 GOTO 7380
5685 LET S = 17
5690 GOTO 7380
5695 LET W(W0 + 4) = H(W(W0 + 4), 8)
5700 GOTO 5650
5705 REM ---- bind: the value with the local as dest (rule 2) ---------------------------------------
5710 LET S = 18
5715 LET X1 = H(X, 7)
5720 LET D1 = H(X, 5)
5725 GOTO 7380
5730 REM ---- tbind: the result registers on U (locals, or new for -), then the call (rule 2) -------
5735 LET X2 = H(X, 7)
5740 LET W(W0 + 3) = U0
5745 LET Z6 = H(X2, 4)
5750 IF Z6 <= 9 THEN 2360
5755 IF T(Z6, 1) <> 2 THEN 2360
5760 IF T(Z6, 2) <> H(X, 6) THEN 2360
5765 FOR I = 1 TO H(X, 6)
5770 GOSUB 7970
5775 LET U(U0, 2) = 0
5780 LET U(U0, 1) = M(H(X, 0) + I - 1)
5785 IF U(U0, 1) > 0 THEN 5810
5790 LET T1 = M(T(Z6, 3) + I - 1)
5795 GOSUB 7395
5800 GOSUB 7420
5805 LET U(U0, 1) = N2
5810 NEXT I
5815 LET S = 19
5820 LET X1 = X2
5825 LET D1 = -2
5830 GOTO 7380
5835 LET U0 = W(W0 + 3)
5840 GOTO 3090
5845 REM ---- tasg: rule 2 steps (a)-(d), at 8200 (the call) and 8400 (step (d)) -------------
5850 GOTO 8205
5995 GOTO 8405
6040 REM ---- eval: the expression, a call discarding its results (rule 5) --------------------------
6045 LET S = 21
6050 LET X1 = H(X, 7)
6055 LET D1 = -1
6060 GOTO 7380
6065 REM ---- asg to lv L (rules 2, 12) ------------------------------------------------------------
6070 LET X2 = H(X, 7)
6075 IF H(X2, 1) <> 5 THEN 2360
6080 LET A1 = H(X2, 5)
6085 LET X1 = H(X2, 8)
6090 LET D1 = 0
6095 IF V(A1, 1) = 3 THEN 6205
6100 IF H(X, 5) > 1 THEN 6120
6105 LET S = 22
6110 LET D1 = A1
6115 GOTO 7380
6120 LET W(W0 + 3) = A1
6125 IF H(X2, 6) = 0 THEN 6170
6130 REM a snapshot of the left operand L (rule 12): mov T L before the value
6135 LET C1 = V(A1, 1)
6140 GOSUB 7420
6145 LET O$ = "mov"
6150 LET V2 = N2
6155 LET V3 = A1
6160 GOSUB 7540
6165 LET W(W0 + 3) = N2
6170 LET S = 23
6175 GOTO 7380
6180 LET A1 = H(H(X, 7), 5)
6185 LET A2 = W(W0 + 3)
6190 LET C1 = V(A1, 1)
6195 GOTO 6305
6200 REM a ref parameter: set: the value into a new register, stored; op: load, value, op, store
6205 LET T1 = A(G(F0, 0) + A1, 1)
6210 GOSUB 7395
6215 GOSUB 7420
6220 LET W(W0 + 3) = N2
6225 IF H(X, 5) > 1 THEN 6245
6230 LET S = 24
6235 LET D1 = N2
6240 GOTO 7380
6245 LET V2 = N2
6250 LET V3 = A1
6255 LET Z3 = 0
6260 GOSUB 7640
6265 LET S = 25
6270 GOTO 7380
6275 LET V2 = W(W0 + 3)
6280 GOTO 6370
6285 LET A2 = W(W0 + 3)
6290 LET C1 = V(A2, 1)
6295 GOSUB 7420
6300 LET A1 = N2
6305 LET A3 = H(X, 5) - 1
6310 LET O$ = SEG$("faddfsubfmulfdiv", 4 * A3 - 3, 4 * A3)
6315 IF C1 = 2 THEN 6340
6320 IF C1 <> 1 THEN 2360
6325 IF A3 = 4 THEN 2360
6330 LET O$ = SEG$("iaddcisubcimulc", 5 * A3 - 4, 5 * A3)
6335 GOSUB 7775
6340 LET V2 = A1
6345 LET V3 = A2
6350 LET V4 = R9
6355 GOSUB 7575
6360 IF V(H(H(X, 7), 5), 1) <> 3 THEN 3090
6365 LET V2 = A1
6370 LET V3 = H(H(X, 7), 5)
6375 LET Z3 = 0
6380 GOSUB 7650
6385 GOTO 3090
6390 REM ---- if: c; if B c; then; [else B; else]; endif B (rule 4) --------------------------------
6395 LET S = 26
6400 GOTO 7370
6405 GOSUB 7885
6410 LET W(W0 + 3) = B7
6415 LET L1$ = "if " & STR$(B7) & " "
6420 LET V1 = R9
6425 GOSUB 7500
6430 LET L1$ = L1$ & Z$
6435 GOSUB 7695
6440 LET S = 27
6445 LET X1 = H(H(X, 7), 8)
6450 LET D1 = 0
6455 GOTO 7380
6460 IF H(X, 5) = 0 THEN 6495
6465 LET L1$ = "else " & STR$(W(W0 + 3))
6470 GOSUB 7695
6475 LET S = 28
6480 LET X1 = H(H(H(X, 7), 8), 8)
6485 LET D1 = 0
6490 GOTO 7380
6495 LET L1$ = "endif " & STR$(W(W0 + 3))
6500 GOSUB 7695
6505 GOTO 3090
6510 REM ---- while: do B; c; ifz B2 c; exit B; endif B2; body; enddo B (rule 4) -------------------
6515 GOSUB 7885
6520 LET W(W0 + 3) = B7
6525 LET L1$ = "do " & STR$(B7)
6530 GOSUB 7695
6535 LET S = 29
6540 GOTO 7370
6545 GOSUB 7885
6550 LET L1$ = "ifz " & STR$(B7) & " "
6555 LET V1 = R9
6560 GOSUB 7500
6565 LET L1$ = L1$ & Z$
6570 GOSUB 7695
6575 LET L1$ = "exit " & STR$(W(W0 + 3))
6580 GOSUB 7695
6585 LET L1$ = "endif " & STR$(B7)
6590 GOSUB 7695
6595 GOSUB 7985
6600 LET S = 30
6605 LET X1 = H(H(X, 7), 8)
6610 LET D1 = 0
6615 GOTO 7380
6620 LET J0 = J0 - 1
6625 LET L1$ = "enddo " & STR$(W(W0 + 3))
6630 GOSUB 7695
6635 GOTO 3090
6640 REM ---- forr: lo, hi, st (or li 1); rcount C E; if B E; loop B2 L lo C st; body; endloop B2;
6645 REM endif B, with B2 = B + 1 (rule 4); break and cont name B2
6650 LET X2 = H(X, 7)
6655 IF H(X2, 1) <> 16 THEN 2365
6660 LET S = 31
6665 LET X1 = H(X2, 7)
6670 LET D1 = 0
6675 GOTO 7380
6680 LET W(W0 + 3) = R9
6685 LET S = 32
6690 LET X1 = H(H(H(X, 7), 7), 8)
6695 LET D1 = 0
6700 GOTO 7380
6705 LET W(W0 + 4) = R9
6710 IF H(H(X, 7), 6) = 0 THEN 6735
6715 LET S = 33
6720 LET X1 = H(H(H(H(X, 7), 7), 8), 8)
6725 LET D1 = 0
6730 GOTO 7380
6735 LET C1 = 1
6740 GOSUB 7420
6745 LET V1 = N2
6750 GOSUB 7500
6755 GOSUB 7865
6760 LET L1$ = "li " & Z$ & " 1"
6765 GOSUB 7695
6770 LET R9 = N2
6775 LET W(W0 + 5) = R9
6780 LET C1 = 1
6785 GOSUB 7420
6790 LET A1 = N2
6795 GOSUB 7420
6800 LET A2 = N2
6805 LET L1$ = "rcount"
6810 LET V1 = A1
6815 GOSUB 7500
6820 LET L1$ = L1$ & " " & Z$
6825 LET V1 = A2
6830 GOSUB 7500
6835 LET L1$ = L1$ & " " & Z$
6840 FOR I = 3 TO 5
6845 LET V1 = W(W0 + I)
6850 GOSUB 7500
6855 LET L1$ = L1$ & " " & Z$
6860 NEXT I
6865 GOSUB 7775
6870 LET L1$ = L1$ & " " & STR$(H(H(X, 7), 5)) & " " & Z9$
6875 LET S7 = 1
6880 GOSUB 7695
6885 GOSUB 7885
6890 LET W(W0 + 4) = B7
6895 LET L1$ = "if " & STR$(B7) & " "
6900 LET V1 = A2
6905 GOSUB 7500
6910 LET L1$ = L1$ & Z$
6915 GOSUB 7695
6920 GOSUB 7885
6925 LET L1$ = "loop " & STR$(B7)
6930 LET V1 = H(X, 5)
6935 GOSUB 7500
6940 LET L1$ = L1$ & " " & Z$
6945 LET V1 = W(W0 + 3)
6950 GOSUB 7500
6955 LET L1$ = L1$ & " " & Z$
6960 LET V1 = A1
6965 GOSUB 7500
6970 LET L1$ = L1$ & " " & Z$
6975 LET V1 = W(W0 + 5)
6980 GOSUB 7500
6985 LET L1$ = L1$ & " " & Z$
6990 GOSUB 7695
6995 LET W(W0 + 3) = B7
7000 GOSUB 7985
7005 LET S = 34
7010 LET X1 = H(H(X, 7), 8)
7015 LET D1 = 0
7020 GOTO 7380
7025 LET J0 = J0 - 1
7030 LET L1$ = "endloop " & STR$(W(W0 + 3))
7035 GOSUB 7695
7040 LET L1$ = "endif " & STR$(W(W0 + 4))
7045 GOSUB 7695
7050 GOTO 3090
7055 REM ---- break / cont: exit / next of the innermost loop (rule 4) ------------------------------
7060 LET L1$ = "exit "
7065 GOTO 7075
7070 LET L1$ = "next "
7075 IF J0 = 0 THEN 2365
7080 LET L1$ = L1$ & STR$(J(J0))
7085 GOSUB 7695
7090 GOTO 3090
7095 REM ---- ret k: the values, ret k regs (rule 5) ------------------------------------------------
7100 LET W(W0 + 3) = U0
7105 LET W(W0 + 4) = H(X, 7)
7110 IF W(W0 + 4) = 0 THEN 7155
7115 LET S = 35
7120 LET X1 = W(W0 + 4)
7125 LET D1 = 0
7130 GOTO 7380
7135 GOSUB 7970
7140 LET U(U0, 1) = R9
7145 LET W(W0 + 4) = H(W(W0 + 4), 8)
7150 GOTO 7110
7155 GOSUB 7170
7160 GOTO 3090
7165 REM 7170: ret of the registers U(W(W0+3)+1 .. U0); U0 back to W(W0+3)
7170 LET L1$ = "ret " & STR$(U0 - W(W0 + 3))
7175 FOR I = W(W0 + 3) + 1 TO U0
7180 LET V1 = U(I, 1)
7185 GOSUB 7500
7190 LET L1$ = L1$ & " " & Z$
7195 NEXT I
7200 GOSUB 7695
7205 LET U0 = W(W0 + 3)
7210 RETURN
7215 REM ---- tret: the call with a new register per result, ret of them (rule 5) ----------------
7220 LET X2 = H(X, 7)
7225 LET W(W0 + 3) = U0
7230 LET Z6 = H(X2, 4)
7235 IF Z6 <= 9 THEN 2360
7240 IF T(Z6, 1) <> 2 THEN 2360
7245 FOR I = 1 TO T(Z6, 2)
7250 LET T1 = M(T(Z6, 3) + I - 1)
7255 GOSUB 7395
7260 GOSUB 7420
7265 GOSUB 7970
7270 LET U(U0, 1) = N2
7275 LET U(U0, 2) = 0
7280 NEXT I
7285 LET S = 36
7290 LET X1 = X2
7295 LET D1 = -2
7300 GOTO 7380
7305 GOSUB 7170
7310 GOTO 3090
7315 REM ---- block: the statements in order (rule 6: no instruction of its own) -------------------
7320 LET W(W0 + 4) = H(X, 7)
7325 IF W(W0 + 4) = 0 THEN 3090
7330 LET S = 37
7335 LET X1 = W(W0 + 4)
7340 LET D1 = 0
7345 GOTO 7380
7350 LET W(W0 + 4) = H(W(W0 + 4), 8)
7355 GOTO 7325
7360 REM ==== helpers of the frame machine ===========================================================
7365 REM 7370: lower the first child with dest 0 and resume code S; 7380: X1 with dest D1
7370 LET X1 = H(X, 7)
7375 LET D1 = 0
7380 LET W(W0 + 2) = S
7385 GOTO 3030
7390 REM ---- 7395: C1 = the register class of the scalar type T1 (1 i: bool, i64; 2 f; 3 p: str) ---
7395 IF T1 < 2 THEN 2360
7400 IF T1 > 5 THEN 2360
7405 LET C1 = VAL(SEG$("1123", T1 - 1, T1 - 1))
7410 RETURN
7415 REM ---- 7420: N2 = a new register of class C1 -------------------------------------------------
7420 LET Q2$ = "registers"
7425 IF V0 >= 199999 THEN 2390
7430 LET V0 = V0 + 1
7435 LET N2 = V0
7440 LET V(N2, 1) = C1
7445 LET V(N2, 2) = 0
7450 IF V0 <= V9 THEN 7460
7455 LET V9 = V0
7460 RETURN
7465 REM ---- 7470: D2 = the dest D if it is a register, else a new register of class C1 ------------
7470 LET D2 = D
7475 IF D > 0 THEN 7490
7480 GOSUB 7420
7485 LET D2 = N2
7490 RETURN
7495 REM ---- 7500: Z$ = the register V1 as written: its output number is given on first use (3.6.1)
7500 IF V(V1, 2) > 0 THEN 7525
7505 LET Q2$ = "registers"
7510 IF M7 >= R8 THEN 2390
7515 LET M7 = M7 + 1
7520 LET V(V1, 2) = M7
7525 LET Z$ = SEG$("ifp", V(V1, 1), V(V1, 1)) & STR$(V(V1, 2))
7530 RETURN
7535 REM ---- 7540 / 7575: L1$ = O$ and the registers V2 V3 (V4), then the site if S7 = 1; emitted ----
7540 LET V1 = V2
7545 GOSUB 7500
7550 LET L1$ = O$ & " " & Z$
7555 LET V1 = V3
7560 GOSUB 7500
7565 LET L1$ = L1$ & " " & Z$
7570 GOTO 7620
7575 LET V1 = V2
7580 GOSUB 7500
7585 LET L1$ = O$ & " " & Z$
7590 LET V1 = V3
7595 GOSUB 7500
7600 LET L1$ = L1$ & " " & Z$
7605 LET V1 = V4
7610 GOSUB 7500
7615 LET L1$ = L1$ & " " & Z$
7620 IF S7 = 0 THEN 7695
7625 LET L1$ = L1$ & " " & Z9$
7630 GOTO 7695
7635 REM ---- 7640 / 7650: load into V2 / store V2 through the p register V3 + Z3, by V2's class ----
7640 LET O$ = SEG$("ldildfldp", 3 * V(V2, 1) - 2, 3 * V(V2, 1))
7645 GOTO 7655
7650 LET O$ = SEG$("stistfstp", 3 * V(V2, 1) - 2, 3 * V(V2, 1))
7655 LET V1 = V2
7660 GOSUB 7500
7665 LET L1$ = O$ & " " & Z$
7670 LET V1 = V3
7675 GOSUB 7500
7680 LET L1$ = L1$ & " " & Z$ & " - 0 " & STR$(Z3)
7685 GOTO 7695
7690 REM ---- 7695: append L1$ to the function's records; S7 = 1 if it ends with a site ----------
7695 LET Q2$ = "instructions"
7700 IF L0 >= I9 THEN 2390
7705 LET L0 = L0 + 1
7710 LET L$(L0) = L1$
7715 LET P2 = 0
7720 LET Z4 = 0
7725 LET P2 = POS(L1$, " ", P2 + 1)
7730 IF P2 = 0 THEN 7745
7735 LET Z4 = Z4 + 1
7740 GOTO 7725
7745 LET O7 = O7 + Z4 - S7
7750 LET S7 = 0
7755 LET Q2$ = "operands"
7760 IF O7 > O9 THEN 2390
7765 RETURN
7770 REM ---- 7775: Z9$ = the site F:L of node X, S7 = 1; 7795: count the distinct site K8 (2.7)
7775 LET F1 = INT(H(X, 2) / 1E9)
7780 LET L1 = H(X, 2) - F1 * 1E9
7785 LET Z9$ = STR$(F1) & ":" & STR$(L1)
7790 LET S7 = 1
7792 LET K8 = H(X, 2)
7795 LET Z4 = K8 - INT(K8 / 131071) * 131071
7800 IF P(Z4) = 0 THEN 7830
7805 IF P(Z4) = K8 + 1 THEN 7850
7810 LET Z4 = Z4 + 1
7815 IF Z4 < 131071 THEN 7800
7820 LET Z4 = 0
7825 GOTO 7800
7830 LET Q2$ = "sites"
7835 IF S8 >= Z8 THEN 2390
7840 LET S8 = S8 + 1
7845 LET P(Z4) = K8 + 1
7850 RETURN
7855 REM ---- 7865 / 7885 / 7905 / 7935: count an li / lf; a new block B7; a new slot S5 of Z1
7860 REM bytes, alignment Z2; a new data label D0 of kind Q3 for node Q4 -----------------------
7865 LET Q2$ = "immediates"
7870 IF Q7 >= M9 THEN 2390
7875 LET Q7 = Q7 + 1
7880 RETURN
7885 LET Q2$ = "blocks"
7890 IF B7 >= B9 THEN 2390
7895 LET B7 = B7 + 1
7900 RETURN
7905 LET Q2$ = "slots"
7910 IF S5 >= S9 THEN 2390
7915 LET S5 = S5 + 1
7920 LET B(S5, 1) = Z1
7925 LET B(S5, 2) = Z2
7930 RETURN
7935 LET Q2$ = "labels"
7940 IF D0 >= D9 THEN 2390
7945 LET D0 = D0 + 1
7950 LET D(D0, 1) = Q3
7955 LET D(D0, 2) = Q4
7960 RETURN
7965 REM ---- 7970 / 7985: one more entry on U (registers) / J (open loops, block B7) ---------
7970 IF U0 >= 199999 THEN 2365
7975 LET U0 = U0 + 1
7980 RETURN
7985 LET J0 = J0 + 1
7990 LET J(J0) = W(W0 + 3)
7995 RETURN
8100 REM ---- reading tasg: n, then one cv flag (0 or 1) per target, kept in M from H(H1, 0) ------
8105 LET H(H1, 6) = I(2)
8110 LET H(H1, 0) = M1 + 1
8115 LET Q2$ = "nodes"
8120 IF M1 + I(2) > 199999 THEN 2375
8125 FOR I = 1 TO I(2)
8130 LET M1 = M1 + 1
8135 LET M(M1) = VAL(G$(3 + I))
8140 IF M(M1) > 1 THEN 2360
8145 NEXT I
8150 GOTO 1285
8195 REM ---- tasg (t1 .. tn) = call (rule 2): Ri on U; U(.,2) = -(L + 100000 cv + 200000 if L is a
8200 REM ref parameter) for a component that step (d) finishes (a new register Ri), else 0
8205 LET W(W0 + 3) = U0
8210 LET X2 = H(X, 7)
8215 LET X3 = X2
8220 FOR I = 1 TO H(X, 6)
8225 LET X3 = H(X3, 8)
8230 NEXT I
8235 LET Z6 = H(X3, 4)
8240 IF Z6 <= 9 THEN 2360
8245 IF T(Z6, 1) <> 2 THEN 2360
8250 IF T(Z6, 2) <> H(X, 6) THEN 2360
8255 REM X4 = the call (the value of a seq)
8260 LET X4 = X3
8265 IF H(X4, 1) <> 19 THEN 8290
8270 LET X4 = H(X4, 7)
8275 IF H(X4, 8) = 0 THEN 8290
8280 LET X4 = H(X4, 8)
8285 GOTO 8275
8290 IF H(X4, 1) <> 10 THEN 2360
8295 FOR I = 1 TO H(X, 6)
8300 GOSUB 7970
8305 LET U(U0, 2) = 0
8310 LET Q3 = M(H(X, 0) + I - 1)
8315 IF H(X2, 1) = 18 THEN 8375
8320 IF H(X2, 1) <> 5 THEN 2360
8325 LET A1 = H(X2, 5)
8330 LET U(U0, 1) = A1
8335 LET A2 = A1 + 100000 * Q3
8340 IF V(A1, 1) <> 3 THEN 8350
8345 LET A2 = A2 + 200000
8347 GOTO 8370
8350 IF Q3 = 1 THEN 8370
8352 REM a local keeps its register unless the call passes it by ref
8355 LET X8 = H(X4, 7)
8357 IF X8 = 0 THEN 8390
8360 IF H(X8, 1) <> 11 THEN 8365
8362 IF H(H(X8, 7), 5) = A1 THEN 8370
8365 LET X8 = H(X8, 8)
8367 GOTO 8357
8370 LET U(U0, 2) = -A2
8375 LET T1 = M(T(Z6, 3) + I - 1)
8380 GOSUB 7395
8382 GOSUB 7420
8385 LET U(U0, 1) = N2
8390 LET X2 = H(X2, 8)
8392 NEXT I
8394 LET S = 20
8396 LET X1 = X3
8397 LET D1 = -2
8398 GOTO 7380
8400 REM step (d), components in order: itof F Ri if cv is 1 (V = F, else V = Ri), then mov L V or sti/stf V P
8405 FOR I = W(W0 + 3) + 1 TO U0
8410 IF U(I, 2) >= 0 THEN 8480
8415 LET A2 = -U(I, 2)
8420 LET A3 = 0
8425 IF A2 < 200000 THEN 8440
8430 LET A3 = 1
8435 LET A2 = A2 - 200000
8440 LET V2 = U(I, 1)
8445 IF A2 < 100000 THEN 8465
8450 LET A2 = A2 - 100000
8452 LET C1 = 2
8454 GOSUB 7420
8456 LET O$ = "itof"
8458 LET V3 = V2
8460 LET V2 = N2
8462 GOSUB 7540
8465 IF A3 = 1 THEN 8475
8467 LET O$ = "mov"
8468 LET V3 = V2
8469 LET V2 = A2
8470 GOSUB 7540
8472 GOTO 8480
8475 LET V3 = A2
8476 LET Z3 = 0
8477 GOSUB 7650
8480 NEXT I
8485 LET U0 = W(W0 + 3)
8490 GOTO 3090
8500 REM ---- bin pow (a ^ that is not a powk): rcall sea_pow - 1 d 2 a b into D2 (rule 14) ---------
8505 LET Q1$ = "POW"
8510 GOSUB 8705
8512 IF LEN(Y$(Q9, 4)) <> 2 THEN 2360
8515 GOSUB 5590
8520 LET V1 = D2
8525 GOSUB 7500
8530 LET L1$ = L1$ & " " & Z$ & " 2"
8535 LET V1 = A1
8540 GOSUB 7500
8545 LET L1$ = L1$ & " " & Z$
8550 LET V1 = A2
8555 GOSUB 7500
8560 LET L1$ = L1$ & " " & Z$
8565 GOSUB 7695
8570 LET R9 = D2
8575 GOTO 3090
8595 REM ---- lib log exp sin cos pow hypot: the arguments, then one rcall of entry NAME (rule 14)
8600 LET W(W0 + 3) = U0
8605 LET W(W0 + 4) = H(X, 7)
8610 IF W(W0 + 4) = 0 THEN 8627
8612 LET S = 38
8614 LET X1 = W(W0 + 4)
8616 LET D1 = 0
8618 GOTO 7380
8620 GOSUB 7970
8622 LET U(U0, 1) = R9
8624 LET W(W0 + 4) = H(W(W0 + 4), 8)
8626 GOTO 8610
8627 LET K3$ = "|printf |now    |f64    |i64    |idiv   |log    |exp    |sin    |cos    |pow    |hypot  "
8628 LET W2$ = S$(H(X, 0))
8629 GOSUB 1875
8630 LET Q1$ = SEG$("LOG  EXP  SIN  COS  POW  HYPOT", 5 * W2 - 29, 5 * W2 - 25)
8632 IF SEG$(Q1$, LEN(Q1$), LEN(Q1$)) <> " " THEN 8640
8634 LET Q1$ = SEG$(Q1$, 1, LEN(Q1$) - 1)
8636 GOTO 8632
8640 GOSUB 8705
8645 IF LEN(Y$(Q9, 4)) <> U0 - W(W0 + 3) THEN 2360
8650 LET C1 = 2
8655 GOSUB 7470
8660 GOSUB 5590
8665 LET V1 = D2
8670 GOSUB 7500
8675 LET L1$ = L1$ & " " & Z$ & " " & STR$(U0 - W(W0 + 3))
8680 FOR I = W(W0 + 3) + 1 TO U0
8682 LET V1 = U(I, 1)
8684 GOSUB 7500
8686 LET L1$ = L1$ & " " & Z$
8688 NEXT I
8690 GOSUB 7695
8692 LET U0 = W(W0 + 3)
8694 LET R9 = D2
8696 GOTO 3090
8700 REM ---- 8705: Q9 = the row of entry Q1$ in the entries table (an entry of class f results) ----
8705 LET Q9 = 0
8710 FOR I = 1 TO Y0
8715 IF Y$(I, 1) <> Q1$ THEN 8725
8720 LET Q9 = I
8725 NEXT I
8730 IF Q9 = 0 THEN 8740
8735 IF Y$(Q9, 5) = "f" THEN 8745
8740 CALL "dg_bug": P$, "entry " & Q1$ & " (results f) is not in the entries table"
8745 RETURN
