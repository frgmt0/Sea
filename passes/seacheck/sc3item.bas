3425 REM ---- sc_check: every check of pass 2a (DESIGN 3.5.5 "What pass 2a has checked", phase 1) ---
3430 REM Items first (names, LANGUAGE 7.2: visible everywhere), then signatures, then every const,
3435 REM then the body of every function and of .main. Locals: S symbol, I node, K kind.
3440 SUB "sc_check": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H(), Q()
3445 LET X(3) = 1
3450 LET X(4) = 9
3455 LET X(11) = 0
3460 LET X(12) = 200000
3465 LET X(29) = 0
3470 LET X(30) = 1
3475 LET X(31) = 0
3480 FOR J = 0 TO 9
3485 LET Y(1, J) = 0
3490 NEXT J
3495 LET Y(1, 0) = 1
3500 LET Y(1, 2) = 1
3505 LET Y(1, 5) = 1
3510 REM the items of the program, in stream order; the other children are .main's statements
3515 LET I = N(X(17), 7)
3520 IF I = 0 THEN 3575
3525 LET X(19) = I
3530 LET K = N(I, 0)
3535 IF K = 2 THEN 3560
3540 IF K = 3 THEN 3560
3545 IF K = 5 THEN 3560
3550 LET X(29) = X(29) + 1
3555 GOTO 3565
3560 CALL "ck_item": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
3565 LET I = N(I, 8)
3570 GOTO 3520
3575 LET X(33) = X(3)
3580 FOR S = 2 TO X(33)
3585 IF Y(S, 0) <> 1 THEN 3595
3590 CALL "ck_sig": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3595 NEXT S
3600 CALL "ck_cord": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H(), Q()
3605 FOR S = 2 TO X(33)
3610 IF Y(S, 0) <> 1 THEN 3620
3615 CALL "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3620 NEXT S
3625 CALL "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
3630 SUBEND
3635 REM ---- ck_item: one top-level item I becomes a symbol (fn 1, const 2, struct 3) ---------------
3640 REM A predeclared name is 'redefinition of predeclared name'; a name already taken by an earlier
3645 REM item is 'redefinition' at the later item, which is then not entered (LANGUAGE 3.3, 7.2).
3650 SUB "ck_item": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
3655 LET Q = N(I, 6)
3660 LET K = N(I, 0)
3665 CALL "pdx": X$(), S$(Q), P
3670 IF P = 0 THEN 3680
3675 CALL "er": N(), X(), X$(), I, "PREDECLARED", "", "", "", 0
3680 FOR J = 2 TO X(3)
3685 IF Y(J, 1) <> Q THEN 3700
3690 CALL "er": N(), X(), X$(), I, "REDEFINITION", S$(Q), "", "", 1
3695 GOTO 3815
3700 NEXT J
3705 CALL "nsym": N(), Y(), X(), X$(), I, R
3710 IF R = 0 THEN 3815
3715 LET Y(R, 1) = Q
3720 LET Y(R, 3) = I
3725 IF K = 2 THEN 3785
3730 IF K = 3 THEN 3805
3735 REM fn: fid in stream order, np, nr
3740 LET Y(R, 0) = 1
3745 LET X(30) = X(30) + 1
3750 LET Y(R, 5) = X(30)
3755 LET Y(R, 6) = N(I, 2)
3760 LET Y(R, 7) = N(I, 3)
3765 LET Y(R, 4) = N(I, 1)
3770 IF N(I, 1) = 0 THEN 3815
3775 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "elemental functions", "", "", 1
3780 GOTO 3815
3785 LET Y(R, 0) = 2
3790 LET X(31) = X(31) + 1
3795 LET Y(R, 5) = X(31)
3800 GOTO 3815
3805 LET Y(R, 0) = 3
3810 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "structs", "", "", 1
3815 SUBEND
3820 REM ---- tyof: R = the type written by type node I (phase 1: f64 i64 bool; str is returned as 5
3825 REM and reported by the caller at the node DESIGN 2.6.2 names; others are errors here) ---------
3830 SUB "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I, R
3835 LET R = 0
3840 IF N(I, 1) = 1 THEN 3855
3845 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "arrays", "", "", 1
3850 GOTO 3955
3855 LET B$ = S$(N(I, 6))
3860 LET L0 = LEN(B$)
3865 IF L0 > 6 THEN 3915
3870 IF L0 < 3 THEN 3915
3875 LET P = POS("|f64   |i64   |bool  |str   |Figure|Axes  |Lu    |Chol  |", "|" & SEG$(B$ & "      ", 1, 6) & "|")
3880 IF P = 0 THEN 3915
3885 LET P = (P - 1) / 7 + 1
3890 IF P > 4 THEN 3905
3895 LET R = VAL(SEG$("4325", P, P))
3900 GOTO 3955
3905 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "handle types", "", "", 1
3910 GOTO 3955
3915 REM an identifier: a declared struct (not in phase 1) or no type at all
3920 FOR J = 2 TO X(33)
3925 IF Y(J, 1) <> N(I, 6) THEN 3945
3930 IF Y(J, 0) <> 3 THEN 3945
3935 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "structs", "", "", 1
3940 GOTO 3955
3945 NEXT J
3950 CALL "er": N(), X(), X$(), I, "UNKNOWN_STRUCT", "", "", "", 0
3955 SUBEND
3960 REM ---- ck_sig: the signature of fn S: parameter types in M(param,1), result types in
3965 REM M(type,1), the result type in Y(S,2) (1 none, a type, or a ttuple; 0 after an error) -------
3970 SUB "ck_sig": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3975 DIM U(70)
3980 LET F = Y(S, 3)
3985 LET X(19) = F
3990 LET P0 = Y(S, 6)
3995 LET R0 = Y(S, 7)
4000 LET I = N(F, 7)
4005 FOR J = 1 TO P0
4010 LET Q = N(I, 6)
4015 REM two parameters of one name: at the later one
4020 LET H = N(F, 7)
4025 IF H = I THEN 4055
4030 IF N(H, 6) <> Q THEN 4045
4035 CALL "er": N(), X(), X$(), I, "REDEFINITION", S$(Q), "", "", 1
4040 GOTO 4055
4045 LET H = N(H, 8)
4050 GOTO 4025
4055 CALL "pdx": X$(), S$(Q), P
4060 IF P = 0 THEN 4070
4065 CALL "er": N(), X(), X$(), I, "SHADOWS_PREDECLARED", "", "", "", 0
4070 IF N(I, 2) = 0 THEN 4080
4075 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "default arguments", "", "", 1
4080 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(I, 7), D
4085 IF D <> 5 THEN 4100
4090 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "strings", "", "", 1
4095 LET D = 0
4100 LET M(I, 1) = D
4105 LET I = N(I, 8)
4110 NEXT J
4115 REM the result types follow the parameters
4120 LET Z = 0
4125 FOR J = 1 TO R0
4130 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I, D
4135 IF D <> 5 THEN 4150
4140 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "strings", "", "", 1
4145 LET D = 0
4150 LET M(I, 1) = D
4155 LET U(J) = D
4160 IF D <> 0 THEN 4170
4165 LET Z = 1
4170 LET I = N(I, 8)
4175 NEXT J
4180 LET Y(S, 2) = 1
4185 IF R0 = 0 THEN 4220
4190 LET Y(S, 2) = U(1)
4195 IF R0 = 1 THEN 4220
4200 LET Y(S, 2) = 0
4205 IF Z = 1 THEN 4220
4210 CALL "ttup": T(), N(), X(), X$(), U(), R0, R
4215 LET Y(S, 2) = R
4220 SUBEND
4225 REM ---- ck_const: const item S: its type (LANGUAGE 7.2: i64 when an untyped integer constant
4230 REM and not annotated) and its constant-expression rule; Y(S,4) 1 while checked, 2 done ------
4235 SUB "ck_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
4240 LET Y(S, 4) = 1
4245 LET F = Y(S, 3)
4250 LET X(19) = F
4255 LET E = N(F, 7)
4260 IF N(F, 1) = 0 THEN 4275
4265 LET G = E
4270 LET E = N(E, 8)
4275 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
4280 REM a constant expression: literals, constants, operators, pi inf nan eps, sqrt, pow
4285 FOR J = M(E, 0) TO E
4290 LET K = N(J, 0)
4295 IF K = 25 THEN 4420
4300 IF K = 26 THEN 4420
4305 IF K = 28 THEN 4420
4310 IF K = 29 THEN 4420
4315 IF K = 32 THEN 4420
4320 IF K = 33 THEN 4420
4325 IF K = 34 THEN 4420
4330 IF K = 30 THEN 4370
4335 IF K <> 35 THEN 4405
4340 REM a call of sqrt (itself 'not supported yet: sqrt' until phase 4) or pow (LANGUAGE 7.2)
4345 LET H = N(J, 7)
4350 IF N(H, 0) <> 30 THEN 4405
4355 IF S$(N(H, 6)) = "pow" THEN 4420
4360 IF S$(N(H, 6)) <> "sqrt" THEN 4405
4365 GOTO 4420
4370 IF M(J, 2) = 0 THEN 4420
4375 IF N(N(J, 9), 0) <> 35 THEN 4385
4380 IF N(N(J, 9), 7) = J THEN 4420
4385 IF M(J, 2) < 0 THEN 4400
4390 IF Y(M(J, 2), 0) = 2 THEN 4420
4395 GOTO 4405
4400 IF M(J, 2) >= -4 THEN 4420
4405 IF M(E, 1) = 0 THEN 4425
4410 CALL "er": N(), X(), X$(), E, "NOT_CONSTANT", "", "", "", 0
4415 GOTO 4425
4420 NEXT J
4425 IF N(F, 1) = 0 THEN 4465
4430 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G, D
4435 IF D <> 5 THEN 4450
4440 CALL "er": N(), X(), X$(), G, "NOT_SUPPORTED", "strings", "", "", 1
4445 LET D = 0
4450 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
4455 LET Y(S, 2) = D
4460 GOTO 4490
4465 CALL "vu": N(), M(), T(), X(), X$(), E, D
4470 IF D <> -1 THEN 4485
4475 CALL "stl": N(), M(), C(), X(), X$(), E, 3
4480 LET D = 3
4485 LET Y(S, 2) = D
4490 LET Y(S, 4) = 2
4495 SUBEND
4500 REM ---- ck_fn: the body of fn S (S = 1: .main, the top-level statements). The var rule
4505 REM (Decision 8) is decided by re-running the walk while a candidate gains an f64 store (X(16));
4510 REM each run starts from the error state before the function and the same symbol rows. --------
4515 SUB "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
4520 DIM A$(4)
4525 LET E6 = X(6)
4530 LET E7 = X(7)
4535 LET E8 = X(8)
4540 LET E9 = X(9)
4545 FOR J = 1 TO 4
4550 LET A$(J) = X$(J)
4555 NEXT J
4560 LET S0 = X(3)
4565 LET Y(S, 9) = S0 + 1
4570 LET F = Y(S, 3)
4575 LET X(16) = 0
4580 LET X(3) = S0
4585 LET X(13) = 0
4590 LET X(12) = 200000
4595 LET X(14) = S
4600 LET X(15) = 0
4605 IF S = 1 THEN 4680
4610 REM the parameters are locals 1..np
4615 LET I = N(F, 7)
4620 FOR J = 1 TO Y(S, 6)
4625 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(I, 6), M(I, 1), 4 + N(I, 1), I, 0, R
4630 LET M(I, 2) = R
4635 LET I = N(I, 8)
4640 NEXT J
4645 REM the body is the last child
4650 FOR J = 1 TO Y(S, 7)
4655 LET I = N(I, 8)
4660 NEXT J
4665 LET B = I
4670 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
4675 GOTO 4735
4680 LET X(12) = X(12) - 2
4685 LET W(X(12)) = -1
4690 LET I = N(X(17), 7)
4695 IF I = 0 THEN 4735
4700 LET K = N(I, 0)
4705 IF K = 2 THEN 4725
4710 IF K = 3 THEN 4725
4715 IF K = 5 THEN 4725
4720 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
4725 LET I = N(I, 8)
4730 GOTO 4695
4735 IF X(16) = 0 THEN 4790
4740 IF X(10) = 1 THEN 4790
4745 REM a candidate became f64: the walk is repeated from the state before the function
4750 LET X(6) = E6
4755 LET X(7) = E7
4760 LET X(8) = E8
4765 LET X(9) = E9
4770 FOR J = 1 TO 4
4775 LET X$(J) = A$(J)
4780 NEXT J
4785 GOTO 4575
4790 LET Y(S, 8) = X(3)
4795 IF S = 1 THEN 4815
4800 IF Y(S, 7) = 0 THEN 4815
4805 IF M(B, 9) = 1 THEN 4815
4810 CALL "er": N(), X(), X$(), F, "MISSING_RETURN", "", "", "", 0
4815 SUBEND
4820 REM ---- ck_cord: every const item, each after the constants its expression names (a depth-first
4825 REM order with an explicit stack in W(1..): pairs (const, next node to scan), so chains of any
4830 REM length need no Baysick recursion); each is checked (ck_const) and then evaluated (cval).
4835 REM Y(S,6) 1 on the stack, 2 done; a name of a const still on the stack closes a cycle, which
4840 REM ck_name reports as 'not a constant expression'. -------------------------------------
4845 SUB "ck_cord": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H(), Q()
4850 FOR S0 = 2 TO X(33)
4855 IF Y(S0, 0) <> 2 THEN 5055
4860 IF Y(S0, 6) <> 0 THEN 5055
4865 LET P = 2
4870 LET W(1) = S0
4875 CALL "cexp": N(), Y(), S0, E
4880 LET W(2) = M(E, 0)
4885 LET Y(S0, 6) = 1
4890 IF P = 0 THEN 5055
4895 LET S = W(P - 1)
4900 LET J = W(P)
4905 CALL "cexp": N(), Y(), S, E
4910 IF J > E THEN 4990
4915 IF N(J, 0) <> 30 THEN 4980
4920 CALL "lk": Y(), W(), X(), X$(), S$(), N(J, 6), R
4925 IF R <= 0 THEN 4980
4930 IF Y(R, 0) <> 2 THEN 4980
4935 IF Y(R, 6) <> 0 THEN 4980
4940 REM a constant not yet ordered: it goes first
4945 LET W(P) = J + 1
4950 LET P = P + 2
4955 LET W(P - 1) = R
4960 CALL "cexp": N(), Y(), R, E
4965 LET W(P) = M(E, 0)
4970 LET Y(R, 6) = 1
4975 GOTO 4890
4980 LET J = J + 1
4985 GOTO 4910
4990 LET P = P - 2
4995 LET X(11) = P
5000 LET X9 = X(9)
5005 CALL "ck_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
5010 REM a constant is evaluated (LANGUAGE 7.2) when its check found no error; else it is failed
5015 REM (6): its uses read a poisoned value, so no second error follows from it (cval)
5020 LET Y(S, 7) = 6
5025 IF X(9) > X9 THEN 5040
5030 LET Y(S, 7) = 0
5035 CALL "cval": N(), M(), Y(), C(), W(), X(), X$(), H(), Q(), S
5040 LET X(11) = 0
5045 LET Y(S, 6) = 2
5050 GOTO 4890
5055 NEXT S0
5060 SUBEND
5065 REM ---- cexp: E = the expression node of const item S (after its type, if annotated) ----------
5070 SUB "cexp": N(), Y(), S, E
5075 LET E = N(Y(S, 3), 7)
5080 IF N(Y(S, 3), 1) = 0 THEN 5090
5085 LET E = N(E, 8)
5090 SUBEND
