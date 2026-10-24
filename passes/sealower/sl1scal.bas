3130 REM ==== the nodes (state 0) and their resume points ---- constants: li / lf into the dest or a new register (rules 1, 3) ----------------------
3140 GOSUB 7468
3150 GOSUB 7865
3155 LET L1$ = "li" & FNR$(D2) & " " & S$(H(X, 0))
3170 GOTO 3290
3175 GOSUB 7468
3185 GOSUB 7865
3190 LET L1$ = "li" & FNR$(D2) & " " & STR$(H(X, 5))
3205 GOTO 3290
3210 GOSUB 7461
3220 GOSUB 7865
3225 LET L1$ = "lf" & FNR$(D2) & " " & S$(H(X, 0))
3240 GOTO 3290
3245 REM a string constant: a str data record and la (rule 7)
3250 GOSUB 7466
3260 LET Q3 = 1
3265 GOSUB 42464
3270 GOTO 3295
3290 GOSUB 7695
3295 GOTO 3088
3305 REM ---- lv: no instruction (rule 1), mov into a dest (rule 2), a load for a ref parameter (the register of a local is its own, or the one it names, A(.,3): sea.hirl T1, T3, 30 (1))
3310 LET A1 = H(X, 5)
3312 IF V(A1, 0) = 1 THEN 40700
3315 IF A(G(F0, 0) + A1, 2) = 1 THEN 3385
3320 LET R9 = A(G(F0, 0) + A1, 3)
3321 IF R9 > 0 THEN 3325
3322 LET R9 = A1
3325 IF D > 0 THEN 3352
3330 IF H(X, 6) = 0 THEN 3090
3335 REM a snapshot (rule 12): mov T L into a new register
3340 LET C1 = V(A1, 1)
3345 GOSUB 7420
3350 LET D = N2
3351 GOTO 3355
3352 IF R9 = A1 THEN 3355
3353 REM a local that names the dest itself (T3) needs no mov
3354 IF R9 = D THEN 3090
3355 LET L1$ = "mov" & FNR$(D) & FNR$(R9)
3360 GOSUB 7620
3375 LET R9 = D
3380 GOTO 16450
3385 LET T1 = A(G(F0, 0) + A1, 1)
3390 GOSUB 7395
3395 GOSUB 7470
3400 LET Z3 = 0
3405 LET L1$ = SEG$("ldildfldp", 3 * V(D2, 1) - 2, 3 * V(D2, 1)) & FNR$(D2) & FNR$(A1) & " - 0 " & STR$(Z3)
3410 GOSUB 7695
3420 LET R9 = D2
3425 GOTO 16450
3430 REM ---- cvt: itof (rule 1) --------------------------------------------------------------------
3435 LET S = 1
3440 GOTO 7370
3445 GOSUB 7461
3455 LET L1$ = "itof" & FNR$(D2) & FNR$(R9)
3460 GOSUB 7620
3475 GOTO 3088
3485 REM ---- un: inegc (i64, checked), fneg, bnot (rule 1) -----------------------------------------
3490 LET S = 2
3495 GOTO 7370
3500 GOSUB 7391
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
3560 GOTO 3088
3570 REM ---- bin: left, right, one instruction (rules 1, 11); && and || by rule 3 -------------------
3575 IF H(X, 5) = 16 THEN 3820
3580 IF H(X, 5) = 17 THEN 3820
3585 LET S = 3
3590 GOTO 7370
3595 LET W(W0 + 3) = R9
3600 LET S = 4
3605 GOTO 7368
3620 LET A1 = W(W0 + 3)
3625 LET A2 = R9
3630 LET A3 = H(X, 5)
3635 GOSUB 7393
3645 LET C2 = C1
3650 GOSUB 7391
3660 GOSUB 7470
3665 LET V2 = D2
3670 LET V3 = A1
3675 LET V4 = A2
3680 IF A3 > 18 THEN 2360
3685 ON A3 GOTO 3690, 3690, 3690, 3720, 3735, 8505, 2360, 3760, 3760, 3760, 3760, 3760, 3760, 3785, 3795, 2360, 2360, 42200
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
3760 IF C2 = 3 THEN 42200
3762 LET O$ = "icmp " & S$(H(X, 0))
3765 IF C2 = 1 THEN 3800
3770 IF C2 <> 2 THEN 2360
3775 LET O$ = "fcmp " & S$(H(X, 0))
3780 GOTO 3800
3785 LET O$ = "iand"
3790 GOTO 3800
3795 LET O$ = "ior"
3800 GOSUB 7575
3805 GOTO 3088
3815 REM && / ||: R = a; if (&&) or ifz (||) B R; R = b; endif B; a local dest then gets mov L R
3820 GOSUB 3985
3825 LET W(W0 + 3) = D2
3830 LET S = 5
3835 LET X1 = H(X, 7)
3840 LET D1 = D2
3845 GOTO 7380
3850 GOSUB 7885
3855 LET W(W0 + 4) = B7
3860 LET L1$ = "ifz " & STR$(B7)
3865 IF H(X, 5) = 17 THEN 3875
3870 LET L1$ = "if " & STR$(B7)
3875 LET L1$ = L1$ & FNR$(W(W0 + 3))
3890 GOSUB 7695
3895 LET S = 6
3900 LET X1 = H(H(X, 7), 8)
3905 LET D1 = W(W0 + 3)
3910 GOTO 7380
3915 LET L1$ = "endif " & STR$(W(W0 + 4))
3920 GOSUB 7695
3925 GOTO 3935
3930 REM the value R of an ifx / && / ||: a new register, or the given one; a local gets mov L R, except the R of an xblk's ifx value (R12 (a), 33550)
3935 LET R9 = W(W0 + 3)
3940 IF D < 1 THEN 3090
3945 IF D > N7 THEN 3090
3946 GOSUB 33550
3947 IF F3 = 1 THEN 3090
3950 LET L1$ = "mov" & FNR$(D) & FNR$(R9)
3955 GOSUB 7620
3970 LET R9 = D
3975 GOTO 3090
3980 REM 3985: D2 = R, a new register of the node's class unless D is a given new register
3985 LET D2 = D
3990 IF D > N7 THEN 4015
3992 GOSUB 33550
3993 IF F3 = 1 THEN 4015
3995 GOSUB 7391
4005 GOSUB 7420
4010 LET D2 = N2
4015 RETURN
4020 REM ---- ifx: c; if B c; R = then; else B; R = else; endif B (rule 3) ---------------------------
4025 LET S = 7
4027 GOSUB 40770
4030 GOTO 7370
4035 GOSUB 7885
4040 LET W(W0 + 4) = B7
4045 LET L1$ = "if " & STR$(B7) & FNR$(R9)
4065 GOSUB 7695
4068 LET D2 = W(W0 + 5)
4069 IF D2 > 0 THEN 4075
4070 GOSUB 3985
4075 LET W(W0 + 3) = D2
4080 LET S = 8
4085 LET X1 = H(H(X, 7), 8)
4090 LET D1 = D2
4092 IF W(W0 + 5) = 0 THEN 4095
4093 LET D1 = 0
4095 GOTO 7380
4100 LET L1$ = "else " & STR$(W(W0 + 4))
4105 GOSUB 7695
4110 LET S = 9
4115 LET X1 = H(H(H(X, 7), 8), 8)
4120 LET D1 = W(W0 + 3)
4122 IF W(W0 + 5) = 0 THEN 4125
4123 LET D1 = 0
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
4180 GOSUB 7461
4190 IF A3 <> 0 THEN 4230
4195 LET L1$ = "lf" & FNR$(D2) & " #3FF0000000000000"
4200 GOSUB 7670
4220 GOTO 4430
4225 REM A4 = the register of x^|k|: D2 itself for k > 0
4230 LET A4 = D2
4235 IF A3 > 0 THEN 4260
4240 LET A4 = A1
4245 IF A2 = 1 THEN 4370
4250 GOSUB 7420
4255 LET A4 = N2
4260 IF A2 > 1 THEN 4290
4265 LET L1$ = "mov" & FNR$(A4) & FNR$(A1)
4270 GOSUB 7620
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
4380 LET L1$ = "lf" & FNR$(N2) & " #3FF0000000000000"
4385 GOSUB 7670
4405 LET V4 = A4
4410 LET L1$ = "fdiv" & FNR$(D2) & FNR$(N2) & FNR$(V4)
4415 GOSUB 7620
4430 GOTO 3088
4440 REM ---- call: the arguments left to right (rarg by rule 12), call, the reloads (rules 2, 5) frame: x1 = U0 at entry (the arguments are U(x1+1 ..)), x2 = the next argument
4450 IF H(X, 5) > G0 THEN 2360
4452 GOSUB 40850
4455 LET W(W0 + 3) = U0
4460 LET W(W0 + 4) = H(X, 7)
4465 LET X2 = W(W0 + 4)
4470 IF X2 = 0 THEN 17930
4475 IF H(X2, 1) = 11 THEN 4515
4480 LET S = 11
4485 LET X1 = X2
4490 GOTO 7375
4500 LET Q5 = 0
4505 GOTO 4630
4510 REM a rarg of a local L: its ref parameter register, or a slot holding L, reloaded later
4515 LET X3 = H(X2, 7)
4518 IF ABS(H(X3, 1) - 49.5) = 10.5 THEN 53500
4522 IF H(X3, 1) <> 5 THEN 2360
4525 LET A1 = H(X3, 5)
4530 LET R9 = A1
4535 LET Q5 = 0
4540 IF A(G(F0, 0) + A1, 2) = 1 THEN 4630
4542 IF V(A1, 0) = 1 THEN 4630
4545 LET Z1 = E7
4550 IF V(A1, 1) = 1 THEN 4560
4555 LET Z1 = E8
4557 IF V(A1, 1) = 3 THEN 17040
4560 LET Z2 = Z1
4565 GOSUB 7905
4570 GOSUB 7418
4580 LET L1$ = "sa" & FNR$(N2) & " s" & STR$(S5)
4595 GOSUB 7695
4597 GOTO 17070
4600 LET Z3 = 0
4605 LET L1$ = SEG$("stistfstp", 3 * V(A1, 1) - 2, 3 * V(A1, 1)) & FNR$(A1) & FNR$(N2) & " - 0 " & STR$(Z3)
4610 GOSUB 7695
4620 LET R9 = N2
4625 LET Q5 = A1
4630 GOSUB 7966
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
4690 IF D = -2 THEN 4748
4691 IF D < -2 THEN 4748
4695 IF Q6 = 0 THEN 4745
4700 IF Q6 <> 1 THEN 2360
4705 LET C1 = POS("ifp", SEG$(Z5$, 2, 2))
4710 GOSUB 7470
4715 GOSUB 7970
4720 LET U(U0, 1) = D2
4730 LET R9 = D2
4735 LET A2 = U0
4740 GOTO 4760
4745 LET Q6 = 0
4748 GOSUB 40900
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
4815 GOSUB 40930
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
4935 LET V2 = U(I, 2)
4940 LET L1$ = "mov" & FNR$(V2) & FNR$(U(I, 1))
4945 GOSUB 7620
4955 LET U(I, 1) = V2
4960 LET U(I, 2) = 0
4965 NEXT I
4967 GOSUB 18260
4970 LET U0 = W(W0 + 3)
4972 IF D > -3 THEN 4975
4973 LET R9 = U(U0, 1)
4974 LET U0 = U0 - Q6
4975 GOTO 3090
4980 REM ---- lib: printf (rule 8), now (9), f64 and i64 (10), idiv (11); log exp sin cos pow hypot (14)-------------------------
4985 LET K3$ = "|printf |now    |f64    |i64    |idiv   |log    |exp    |sin    |cos    |pow    |hypot  |error  "
4990 LET W2$ = S$(H(X, 0))
4995 GOSUB 1875
5000 IF W2 = 0 THEN 19360
5005 IF H(X, 6) <> VAL(SEG$("101121111221", W2, W2)) THEN 2360
5010 ON W2 GOTO 5020, 5335, 5390, 5390, 5500, 8600, 8600, 8600, 8600, 8600, 8600, 5020
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
5065 GOTO 7361
5080 GOSUB 7966
5086 LET U(U0, 0) = H(W(W0 + 4), 7)
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
5150 GOSUB 7418
5160 LET A2 = N2
5165 LET L1$ = "sa" & FNR$(A2) & " s" & STR$(S5)
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
5235 GOSUB 7418
5245 LET A3 = N2
5250 LET L1$ = "la" & FNR$(A3) & " d" & STR$(D0)
5265 GOSUB 7695
5270 LET Q9 = Y1
5271 IF S$(H(X, 0)) = "printf" THEN 5275
5272 LET Q9 = FNE("ERROR", "")
5275 GOSUB 5590
5280 LET L1$ = L1$ & " " & STR$(LEN(Y$(Y1, 4))) & FNR$(A3) & FNR$(A2)
5310 GOSUB 7695
5311 IF Q9 = Y1 THEN 42900
5315 LET U0 = W(W0 + 3)
5320 GOTO 3081
5330 REM now: rcall of the entry NOW into the dest or a new f register
5335 GOSUB 7461
5345 LET Q9 = Y2
5350 GOSUB 5590
5355 LET L1$ = L1$ & FNR$(D2) & " 0"
5370 GOTO 7662
5385 REM f64(x): itof, or mov for an f64; i64(x): ftoi for an f64, else mov
5390 LET S = 13
5395 GOTO 7370
5400 GOSUB 7393
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
5485 GOTO 3088
5495 REM idiv(a, b): idivf with the node's line as site
5500 LET S = 14
5505 GOTO 7370
5510 LET W(W0 + 3) = R9
5515 LET S = 15
5520 GOTO 7368
5535 GOSUB 7468
5545 LET O$ = "idivf"
5550 LET V2 = D2
5555 LET V3 = W(W0 + 3)
5560 LET V4 = R9
5565 GOSUB 7775
5570 GOSUB 7575
5575 GOTO 3088
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
5675 GOTO 7375
5685 LET S = 17
5690 GOTO 7380
5695 LET W(W0 + 4) = H(W(W0 + 4), 8)
5700 GOTO 5650
5705 REM ---- bind: the value with the local as dest (rule 2; an accumulator's register, R12 (b)) ------
5710 LET S = 18
5712 IF H(X, 6) = 1 THEN 33200
5713 IF V(H(X, 5), 0) = 1 THEN 41000
5715 LET X1 = H(X, 7)
5720 LET D1 = A(G(F0, 0) + H(X, 5), 3)
5721 IF D1 > 0 THEN 5725
5722 LET D1 = H(X, 5)
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
5780 LET U(U0, 1) = M(H(X, 0) + I - 1)
5781 LET T5 = M(T(Z6, 3) + I - 1)
5782 GOSUB 40600
5783 IF F5 = 1 THEN 41070
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
5835 GOTO 15470
5845 REM ---- tasg: rule 2 steps (a)-(d), at 8200 (the call) and 8400 (step (d)) -------------
5850 GOTO 8205
5995 GOTO 8401
6040 REM ---- eval: the expression, a call discarding its results (rule 5) --------------------------
6045 GOTO 15920
6065 REM ---- asg to lv L (rules 2, 12) ------------------------------------------------------------
6070 LET X2 = H(X, 7)
6075 IF H(X2, 1) = 39 THEN 13550
6077 IF H(X2, 1) <> 5 THEN 2360
6080 LET A1 = H(X2, 5)
6085 LET X1 = H(X2, 8)
6090 LET D1 = 0
6092 IF V(A1, 0) = 1 THEN 41050
6095 IF A(G(F0, 0) + A1, 2) = 1 THEN 6205
6097 IF V(A1, 1) = 3 THEN 14830
6100 IF H(X, 5) > 1 THEN 6120
6105 LET S = 22
6110 LET D1 = A(G(F0, 0) + A1, 3)
6111 IF D1 > 0 THEN 6115
6112 LET D1 = A1
6115 GOTO 7380
6120 LET W(W0 + 3) = A1
6125 IF H(X2, 6) = 0 THEN 6170
6130 REM a snapshot of the left operand L (rule 12): mov T L before the value
6135 LET C1 = V(A1, 1)
6140 GOSUB 7420
6145 LET L1$ = "mov" & FNR$(N2) & FNR$(A1)
6150 GOSUB 7620
6161 GOSUB 42280
6165 LET W(W0 + 3) = N2
6170 LET S = 23
6175 GOTO 7380
6180 LET A1 = H(H(X, 7), 5)
6185 LET A2 = W(W0 + 3)
6190 LET C1 = V(A1, 1)
6195 GOTO 6304
6200 REM a ref parameter: set: the value into a new register, stored; op: load, value, op, store
6205 LET T1 = A(G(F0, 0) + A1, 1)
6210 GOSUB 7395
6215 GOSUB 7420
6220 LET W(W0 + 3) = N2
6225 IF H(X, 5) > 1 THEN 6245
6230 LET S = 24
6235 LET D1 = N2
6240 GOTO 7380
6245 LET Z3 = 0
6250 LET L1$ = SEG$("ldildfldp", 3 * V(N2, 1) - 2, 3 * V(N2, 1)) & FNR$(N2) & FNR$(A1) & " - 0 " & STR$(Z3)
6255 GOSUB 7695
6261 GOSUB 42280
6265 LET S = 25
6270 GOTO 7380
6275 LET V2 = W(W0 + 3)
6280 GOTO 6370
6285 LET A2 = W(W0 + 3)
6290 LET C1 = V(A2, 1)
6295 GOSUB 7420
6300 LET A1 = N2
6304 IF C1 = 3 THEN 42192
6305 LET A3 = H(X, 5) - 1
6310 LET O$ = SEG$("faddfsubfmulfdiv", 4 * A3 - 3, 4 * A3)
6315 IF C1 = 2 THEN 6340
6320 IF C1 <> 1 THEN 2360
6325 IF A3 = 4 THEN 2360
6330 LET O$ = SEG$("iaddcisubcimulc", 5 * A3 - 4, 5 * A3)
6335 GOSUB 7775
6340 LET V4 = R9
6345 LET L1$ = O$ & FNR$(A1) & FNR$(A2) & FNR$(V4)
6350 GOSUB 7620
6360 IF A(G(F0, 0) + H(H(X, 7), 5), 2) = 0 THEN 3090
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
6415 LET L1$ = "if " & STR$(B7) & FNR$(R9)
6435 GOSUB 7695
6440 LET S = 27
6445 GOTO 7368
6460 IF H(X, 5) = 0 THEN 6495
6465 LET L1$ = "else " & STR$(W(W0 + 3))
6470 GOSUB 7695
6475 LET S = 28
6480 LET X1 = H(H(H(X, 7), 8), 8)
6485 GOTO 7375
6495 LET L1$ = "endif " & STR$(W(W0 + 3))
6500 GOTO 7664
6510 REM ---- while: do B; c; ifz B2 c; exit B; endif B2; body; enddo B (rule 4) -------------------
6515 GOSUB 7885
6520 LET W(W0 + 3) = B7
6525 LET L1$ = "do " & STR$(B7)
6530 GOSUB 7695
6535 LET S = 29
6540 GOTO 7370
6545 GOSUB 7885
6550 LET L1$ = "ifz " & STR$(B7) & FNR$(R9)
6570 GOSUB 7695
6575 LET L1$ = "exit " & STR$(W(W0 + 3))
6580 GOSUB 7695
6585 LET L1$ = "endif " & STR$(B7)
6590 GOSUB 7695
6595 GOSUB 7985
6600 LET S = 30
6605 GOTO 7368
6620 LET J0 = J0 - 1
6625 LET L1$ = "enddo " & STR$(W(W0 + 3))
6630 GOTO 7664
6640 REM ---- forr: lo, hi, st (or li 1); rcount C E; if B E; loop B2 L lo C st; body; endloop B2; endif B, with B2 = B + 1 (rule 4); break and cont name B2
6650 LET X2 = H(X, 7)
6655 IF H(X2, 1) <> 16 THEN 2365
6660 LET S = 31
6665 GOTO 7361
6680 LET W(W0 + 3) = R9
6685 LET S = 32
6690 LET X1 = H(H(H(X, 7), 7), 8)
6695 GOTO 7375
6705 LET W(W0 + 4) = R9
6710 IF H(H(X, 7), 6) = 0 THEN 6735
6715 LET S = 33
6720 LET X1 = H(H(H(H(X, 7), 7), 8), 8)
6725 GOTO 7375
6735 GOSUB 7416
6745 LET L1$ = "li" & FNR$(N2) & " 1"
6750 GOSUB 7670
6770 LET R9 = N2
6775 LET W(W0 + 5) = R9
6780 GOSUB 7416
6790 LET A1 = N2
6795 GOSUB 7420
6800 LET A2 = N2
6805 LET L1$ = "rcount" & FNR$(A1) & FNR$(A2)
6840 FOR I = 3 TO 5
6845 LET L1$ = L1$ & FNR$(W(W0 + I))
6860 NEXT I
6865 GOSUB 7775
6870 LET L1$ = L1$ & " " & STR$(H(H(X, 7), 5)) & " " & Z9$
6875 LET S7 = 1
6880 GOSUB 7695
6885 GOSUB 7885
6890 LET W(W0 + 4) = B7
6895 LET L1$ = "if " & STR$(B7) & FNR$(A2)
6915 GOSUB 7695
6920 GOSUB 7885
6925 LET L1$ = "loop " & STR$(B7) & FNR$(H(X, 5)) & FNR$(W(W0 + 3)) & FNR$(A1) & FNR$(W(W0 + 5))
6990 GOSUB 7695
6995 LET W(W0 + 3) = B7
7000 GOSUB 7985
7005 LET S = 34
7010 GOTO 7368
7025 LET J0 = J0 - 1
7030 LET L1$ = "endloop " & STR$(W(W0 + 3))
7035 GOSUB 7695
7040 LET L1$ = "endif " & STR$(W(W0 + 4))
7045 GOTO 7664
7055 REM ---- break / cont: exit / next of the innermost loop (rule 4) ------------------------------
7060 LET O$ = "exit "
7065 GOTO 7075
7070 LET O$ = "next "
7075 IF J0 = 0 THEN 2365
7077 LET U4 = J(J0, 3)
7078 GOSUB 10390
7080 LET L1$ = O$ & STR$(J(J0, 1))
7085 GOTO 7664
7095 REM ---- ret k: the values, ret k regs (rule 5) ------------------------------------------------
7100 LET W(W0 + 3) = U0
7105 LET W(W0 + 4) = H(X, 7)
7110 IF W(W0 + 4) = 0 THEN 7155
7115 LET S = 35
7120 LET X1 = W(W0 + 4)
7125 GOSUB 53340
7130 GOTO 7380
7135 GOSUB 41122
7136 GOSUB 41142
7137 IF F5 = 1 THEN 7145
7138 GOSUB 7966
7142 GOSUB 16530
7145 LET W(W0 + 4) = H(W(W0 + 4), 8)
7150 GOTO 7110
7155 GOSUB 16560
7160 GOTO 3090
7165 REM 7170: ret of the registers U(W(W0+3)+1 .. U0); U0 back to W(W0+3)
7170 LET L1$ = ""
7172 LET Z4 = 0
7175 FOR I = W(W0 + 3) + 1 TO U0
7177 IF V(U(I, 1), 0) = 1 THEN 7195
7180 LET L1$ = L1$ & FNR$(U(I, 1))
7192 LET Z4 = Z4 + 1
7195 NEXT I
7197 LET L1$ = "ret " & STR$(Z4) & L1$
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
7252 GOSUB 40595
7254 IF F5 = 1 THEN 41102
7255 GOSUB 7395
7260 GOSUB 7420
7265 GOSUB 7970
7270 LET U(U0, 1) = N2
7280 NEXT I
7285 LET S = 36
7290 LET X1 = X2
7295 LET D1 = -2
7300 GOTO 7380
7305 GOSUB 16560
7310 GOTO 3090
7315 REM ---- block: the statements in order (rule 6: no instruction of its own) -------------------
7320 LET W(W0 + 4) = H(X, 7)
7322 LET W(W0 + 3) = J9
7325 IF W(W0 + 4) = 0 THEN 16620
7330 LET S = 37
7335 GOTO 7366
7350 LET W(W0 + 4) = H(W(W0 + 4), 8)
7355 GOTO 7325
7360 REM ==== helpers of the frame machine ===========================================================
7361 LET X1 = H(X2, 7)
7362 GOTO 7375
7365 REM 7370: lower the first child with dest 0 and resume code S; 7380: X1 with dest D1; 7375: X1 with dest 0; X1 = W(W0 + 4) at 7366, the next sibling of the first child at 7368, the first child of X2 at 7361
7366 LET X1 = W(W0 + 4)
7367 GOTO 7375
7368 LET X1 = H(H(X, 7), 8)
7369 GOTO 7375
7370 LET X1 = H(X, 7)
7375 LET D1 = 0
7380 LET W(W0 + 2) = S
7385 GOTO 3030
7390 REM ---- 7395: C1 = the register class of the scalar type T1 (1 i: bool, i64; 2 f; 3 p: str); 7391: of the type of X, 7393: of its first child's
7391 LET T1 = H(X, 4)
7392 GOTO 7395
7393 LET T1 = H(H(X, 7), 4)
7395 IF T1 < 2 THEN 2360
7400 IF T1 > 5 THEN 9740
7405 LET C1 = VAL(SEG$("1123", T1 - 1, T1 - 1))
7410 RETURN
7411 LET C1 = 2
7412 GOTO 7420
7415 REM ---- 7420: N2 = a new register of class C1; 7418: of class 3 (p), 7416: of class 1 (i), 7411: of class 2 (f) ---
7416 LET C1 = 1
7417 GOTO 7420
7418 LET C1 = 3
7420 LET Q2$ = "registers"
7425 IF V0 >= 199999 THEN 2390
7430 LET V0 = V0 + 1
7435 LET N2 = V0
7440 LET V(N2, 1) = C1
7445 LET V(N2, 2) = 0
7446 LET V(N2, 0) = 0
7450 IF V0 <= V9 THEN 7460
7455 LET V9 = V0
7460 RETURN
7461 LET C1 = 2
7462 GOTO 7470
7465 REM ---- 7470: D2 = the dest D if it is a register, else a new register of class C1; 7468: class 1, 7466: class 3, 7461: class 2
7466 LET C1 = 3
7467 GOTO 7470
7468 LET C1 = 1
7470 LET D2 = D
7475 IF D > 0 THEN 7490
7480 GOSUB 7420
7485 LET D2 = N2
7490 RETURN
7495 REM ---- FNR$(V6) = " " and the register V6 as written: its output number is given on first use (3.6.1); past LIM_LIR_REGS the program is too large (registers) at the node X, reported as 2390 does
7500 DEF FNR$(V6)
7505 IF V(V6, 2) > 0 THEN 7525
7510 IF M7 < R8 THEN 7515
7511 LET A$(1) = "registers"
7512 CALL "dg_compile": P$, H$(), N1, INT(H(X, 2) / 1E9), H(X, 2) - INT(H(X, 2) / 1E9) * 1E9, H(X, 3), "TOO_LARGE", A$(), 1, E(), E$(), E0
7515 LET M7 = M7 + 1
7520 LET V(V6, 2) = M7
7525 LET FNR$ = " " & SEG$("ifp", V(V6, 1), V(V6, 1)) & STR$(V(V6, 2))
7530 FNEND
7535 REM ---- 7540 / 7575: L1$ = O$ and the registers V2 V3 (V4), then the site if S7 = 1; emitted ----
7540 LET L1$ = O$ & FNR$(V2) & FNR$(V3)
7545 GOTO 7620
7575 LET L1$ = O$ & FNR$(V2) & FNR$(V3) & FNR$(V4)
7620 IF S7 = 0 THEN 7695
7625 LET L1$ = L1$ & " " & Z9$
7630 GOTO 7695
7635 REM ---- 7640 / 7650: load into V2 / store V2 through the p register V3 + Z3, by V2's class ----
7640 LET O$ = SEG$("ldildfldp", 3 * V(V2, 1) - 2, 3 * V(V2, 1))
7645 GOTO 7655
7650 LET O$ = SEG$("stistfstp", 3 * V(V2, 1) - 2, 3 * V(V2, 1))
7655 LET L1$ = O$ & FNR$(V2) & FNR$(V3) & " - 0 " & STR$(Z3)
7660 GOTO 7695
7662 GOSUB 7695
7663 GOTO 3088
7664 GOSUB 7695
7665 GOTO 3090
7666 GOSUB 7695
7667 GOTO 19575
7668 GOSUB 7620
7669 GOTO 19575
7670 GOSUB 7865
7671 GOTO 7695
7690 REM ---- 7695: append L1$ to the function's records; S7 = 1 if it ends with a site. 7662 / 7664 / 7666: emit, then resume at 3088 (R9 = D2) / 3090 / 19575; 7668: the site if S7 = 1, emit, 19575; 7670: count an immediate (7865), emit
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
7855 REM ---- 7865 / 7885 / 7905 / 7935: count an li / lf; a new block B7; a new slot S5 of Z1 bytes, alignment Z2; a new data label D0 of kind Q3 for node Q4 -----------------------
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
7965 REM ---- 7970 / 7985: one more entry on U (registers, U(.,2) = 0) / J (open loops, block B7); 7966: push R9 on U (U(U0, 1) = R9)
7966 IF U0 >= 199999 THEN 2365
7967 LET U(U0 + 1, 1) = R9
7970 IF U0 >= 199999 THEN 2365
7975 LET U0 = U0 + 1
7977 LET U(U0, 2) = 0
7980 RETURN
7985 LET J0 = J0 + 1
7990 LET J(J0, 1) = W(W0 + 3)
7992 LET J(J0, 3) = J9
7995 RETURN
7997 REM ---- 8000: the children of X onto U, one value each, with the resume code S (38 40 49), then its continuation (8015); 8005: the next child after a value (R9 pushed); 8007: the next child
8000 LET W(W0 + 3) = U0
8002 LET W(W0 + 4) = H(X, 7)
8004 GOTO 8010
8005 GOSUB 7966
8007 LET W(W0 + 4) = H(W(W0 + 4), 8)
8010 IF W(W0 + 4) > 0 THEN 7366
8015 ON S - 37 GOTO 8627, 2365, 13000, 2365, 2365, 2365, 2365, 2365, 2365, 2365, 2365, 19550
8100 REM ---- reading tasg: n, then one cv flag per target (0, or 1 of a scalar result, R10), in M
8105 LET H(H1, 6) = I(2)
8110 LET H(H1, 0) = M1 + 1
8115 LET Q2$ = "nodes"
8120 IF M1 + I(2) > 199999 THEN 2375
8122 GOSUB 41772
8125 FOR I = 1 TO I(2)
8130 LET M1 = M1 + 1
8135 LET M(M1) = VAL(G$(3 + I))
8140 IF M(M1) > 1 THEN 2360
8141 IF M(M1) = 0 THEN 8145
8142 IF E9 = 0 THEN 8145
8143 IF M(T(E9, 3) + I - 1) > 9 THEN 2360
8145 NEXT I
8150 GOTO 1285
8195 REM ---- tasg (t1 .. tn) = call (rule 2): Ri on U; U(.,2) = -(L + 100000 cv + 200000 if L is a ref parameter) for a component that step (d) finishes (a new register Ri), else 0
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
8265 IF H(X4, 1) <> 19 THEN 8288
8270 LET X4 = H(X4, 7)
8275 IF H(X4, 8) = 0 THEN 8288
8280 LET X4 = H(X4, 8)
8285 GOTO 8275
8288 IF H(X4, 1) = 12 THEN 8295
8290 IF H(X4, 1) <> 10 THEN 2360
8295 FOR I = 1 TO H(X, 6)
8300 GOSUB 7970
8310 LET Q3 = M(H(X, 0) + I - 1)
8315 IF H(X2, 1) = 18 THEN 8375
8320 IF H(X2, 1) = 39 THEN 24040
8322 IF H(X2, 1) <> 5 THEN 2360
8325 LET A1 = H(X2, 5)
8330 LET U(U0, 1) = A1
8335 LET A2 = A1 + 100000 * Q3
8340 IF A(G(F0, 0) + A1, 2) = 0 THEN 8350
8345 LET A2 = A2 + 200000
8347 GOTO 8370
8350 IF Q3 = 1 THEN 8370
8351 IF V(A1, 1) = 3 THEN 8370
8352 REM a local keeps its register unless the call passes it by ref
8355 LET X8 = H(X4, 7)
8357 IF X8 = 0 THEN 8390
8360 IF H(X8, 1) <> 11 THEN 8365
8362 IF H(H(X8, 7), 5) = A1 THEN 8370
8365 LET X8 = H(X8, 8)
8367 GOTO 8357
8370 LET U(U0, 2) = -A2
8375 LET T1 = M(T(Z6, 3) + I - 1)
8376 GOSUB 40595
8378 IF F5 = 1 THEN 41080
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
8401 LET W(W0 + 5) = U0
8403 LET W(W0 + 4) = W(W0 + 3)
8405 LET W(W0 + 4) = W(W0 + 4) + 1
8406 IF W(W0 + 4) > W(W0 + 5) THEN 8482
8407 LET I = W(W0 + 4)
8410 IF U(I, 2) >= 0 THEN 8480
8415 LET A2 = -U(I, 2)
8417 IF A2 >= 400000 THEN 24070
8420 LET A3 = 0
8425 IF A2 < 200000 THEN 8440
8430 LET A3 = 1
8435 LET A2 = A2 - 200000
8440 LET V2 = U(I, 1)
8441 IF V(V2, 0) = 1 THEN 41092
8445 IF A2 < 100000 THEN 8465
8450 LET A2 = A2 - 100000
8452 GOSUB 7411
8456 LET O$ = "itof"
8458 LET V3 = V2
8460 LET V2 = N2
8462 GOSUB 7540
8465 IF A3 = 1 THEN 8473
8466 IF V(A2, 1) = 3 THEN 15630
8467 LET L1$ = "mov" & FNR$(A2) & FNR$(V2)
8468 GOSUB 7620
8472 GOTO 8480
8473 IF V(V2, 1) = 3 THEN 15670
8475 LET V3 = A2
8476 LET Z3 = 0
8477 GOSUB 7650
8480 GOTO 8405
8482 GOSUB 15830
8485 GOTO 3083
8500 REM ---- bin pow (a ^ that is not a powk): rcall sea_pow - 1 d 2 a b into D2 (rule 14) ---------
8505 LET Q1$ = "POW"
8510 GOSUB 8705
8512 IF LEN(Y$(Q9, 4)) <> 2 THEN 2360
8515 GOSUB 5590
8520 LET L1$ = L1$ & FNR$(D2) & " 2" & FNR$(A1) & FNR$(A2)
8565 GOTO 7662
8595 REM ---- lib log exp sin cos pow hypot: the arguments, then one rcall of entry NAME (rule 14)
8600 LET S = 38
8605 GOTO 8000
8627 LET K3$ = "|printf |now    |f64    |i64    |idiv   |log    |exp    |sin    |cos    |pow    |hypot  "
8628 LET W2$ = S$(H(X, 0))
8629 GOSUB 1875
8630 LET Q1$ = SEG$("LOG  EXP  SIN  COS  POW  HYPOT", 5 * W2 - 29, 5 * W2 - 25)
8632 IF SEG$(Q1$, LEN(Q1$), LEN(Q1$)) <> " " THEN 8640
8634 LET Q1$ = SEG$(Q1$, 1, LEN(Q1$) - 1)
8636 GOTO 8632
8640 GOSUB 8705
8645 IF LEN(Y$(Q9, 4)) <> U0 - W(W0 + 3) THEN 2360
8650 GOSUB 7461
8660 GOSUB 5590
8665 LET L1$ = L1$ & FNR$(D2) & " " & STR$(U0 - W(W0 + 3))
8680 FOR I = W(W0 + 3) + 1 TO U0
8682 LET L1$ = L1$ & FNR$(U(I, 1))
8688 NEXT I
8690 GOSUB 7695
8692 LET U0 = W(W0 + 3)
8694 GOTO 3088
8700 REM ---- 8705: Q9 = the row of entry Q1$ in the entries table (an entry of class f results) ----
8705 LET Q9 = FNE(Q1$, " (results f)")
8735 IF Y$(Q9, 5) = "f" THEN 8745
8740 CALL "dg_bug": P$, "entry " & Q1$ & " (results f) is not in the entries table"
8745 RETURN
