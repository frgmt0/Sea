3380 REM ---- sc_check: every check of pass 2a (DESIGN 3.5.5 "What pass 2a has checked", phase 1) ---
3385 REM Items first (names, LANGUAGE 7.2: visible everywhere), then signatures, then every const,
3390 REM then the body of every function and of .main. Locals: S symbol, I node, K kind.
3395 SUB "sc_check": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
3400 LET X(3) = 1
3405 LET X(4) = 9
3410 LET X(11) = 0
3415 LET X(12) = 200000
3420 LET X(29) = 0
3425 LET X(30) = 1
3430 LET X(31) = 0
3435 FOR J = 0 TO 9
3440 LET Y(1, J) = 0
3445 NEXT J
3450 LET Y(1, 0) = 1
3455 LET Y(1, 2) = 1
3460 LET Y(1, 5) = 1
3465 REM the items of the program, in stream order; the other children are .main's statements
3470 LET I = N(X(17), 7)
3475 IF I = 0 THEN 3530
3480 LET X(19) = I
3485 LET K = N(I, 0)
3490 IF K = 2 THEN 3515
3495 IF K = 3 THEN 3515
3500 IF K = 5 THEN 3515
3505 LET X(29) = X(29) + 1
3510 GOTO 3520
3515 CALL "ck_item": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
3520 LET I = N(I, 8)
3525 GOTO 3475
3530 LET X(33) = X(3)
3535 FOR S = 2 TO X(33)
3540 IF Y(S, 0) <> 1 THEN 3550
3545 CALL "ck_sig": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3550 NEXT S
3555 CALL "ck_cord": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
3560 FOR S = 2 TO X(33)
3565 IF Y(S, 0) <> 1 THEN 3575
3570 CALL "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3575 NEXT S
3580 CALL "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
3585 SUBEND
3590 REM ---- ck_item: one top-level item I becomes a symbol (fn 1, const 2, struct 3) ---------------
3595 REM A predeclared name is 'redefinition of predeclared name'; a name already taken by an earlier
3600 REM item is 'redefinition' at the later item, which is then not entered (LANGUAGE 3.3, 7.2).
3605 SUB "ck_item": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
3610 LET Q = N(I, 6)
3615 LET K = N(I, 0)
3620 CALL "pdx": X$(), S$(Q), P
3625 IF P = 0 THEN 3635
3630 CALL "er": N(), X(), X$(), I, "PREDECLARED", "", "", "", 0
3635 FOR J = 2 TO X(3)
3640 IF Y(J, 1) <> Q THEN 3655
3645 CALL "er": N(), X(), X$(), I, "REDEFINITION", S$(Q), "", "", 1
3650 GOTO 3770
3655 NEXT J
3660 CALL "nsym": N(), Y(), X(), X$(), I, R
3665 IF R = 0 THEN 3770
3670 LET Y(R, 1) = Q
3675 LET Y(R, 3) = I
3680 IF K = 2 THEN 3740
3685 IF K = 3 THEN 3760
3690 REM fn: fid in stream order, np, nr
3695 LET Y(R, 0) = 1
3700 LET X(30) = X(30) + 1
3705 LET Y(R, 5) = X(30)
3710 LET Y(R, 6) = N(I, 2)
3715 LET Y(R, 7) = N(I, 3)
3720 LET Y(R, 4) = N(I, 1)
3725 IF N(I, 1) = 0 THEN 3770
3730 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "elemental functions", "", "", 1
3735 GOTO 3770
3740 LET Y(R, 0) = 2
3745 LET X(31) = X(31) + 1
3750 LET Y(R, 5) = X(31)
3755 GOTO 3770
3760 LET Y(R, 0) = 3
3765 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "structs", "", "", 1
3770 SUBEND
3775 REM ---- tyof: R = the type written by type node I (phase 1: f64 i64 bool; str is returned as 5
3780 REM and reported by the caller at the node DESIGN 2.6.2 names; others are errors here) ---------
3785 SUB "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I, R
3790 LET R = 0
3795 IF N(I, 1) = 1 THEN 3810
3800 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "arrays", "", "", 1
3805 GOTO 3910
3810 LET B$ = S$(N(I, 6))
3815 LET L0 = LEN(B$)
3820 IF L0 > 6 THEN 3870
3825 IF L0 < 3 THEN 3870
3830 LET P = POS("|f64   |i64   |bool  |str   |Figure|Axes  |Lu    |Chol  |", "|" & SEG$(B$ & "      ", 1, 6) & "|")
3835 IF P = 0 THEN 3870
3840 LET P = (P - 1) / 7 + 1
3845 IF P > 4 THEN 3860
3850 LET R = VAL(SEG$("4325", P, P))
3855 GOTO 3910
3860 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "handle types", "", "", 1
3865 GOTO 3910
3870 REM an identifier: a declared struct (not in phase 1) or no type at all
3875 FOR J = 2 TO X(33)
3880 IF Y(J, 1) <> N(I, 6) THEN 3900
3885 IF Y(J, 0) <> 3 THEN 3900
3890 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "structs", "", "", 1
3895 GOTO 3910
3900 NEXT J
3905 CALL "er": N(), X(), X$(), I, "UNKNOWN_STRUCT", "", "", "", 0
3910 SUBEND
3915 REM ---- ck_sig: the signature of fn S: parameter types in M(param,1), result types in
3920 REM M(type,1), the result type in Y(S,2) (1 none, a type, or a ttuple; 0 after an error) -------
3925 SUB "ck_sig": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3930 DIM U(70)
3935 LET F = Y(S, 3)
3940 LET X(19) = F
3945 LET P0 = Y(S, 6)
3950 LET R0 = Y(S, 7)
3955 LET I = N(F, 7)
3960 FOR J = 1 TO P0
3965 LET Q = N(I, 6)
3970 REM two parameters of one name: at the later one
3975 LET H = N(F, 7)
3980 IF H = I THEN 4010
3985 IF N(H, 6) <> Q THEN 4000
3990 CALL "er": N(), X(), X$(), I, "REDEFINITION", S$(Q), "", "", 1
3995 GOTO 4010
4000 LET H = N(H, 8)
4005 GOTO 3980
4010 CALL "pdx": X$(), S$(Q), P
4015 IF P = 0 THEN 4025
4020 CALL "er": N(), X(), X$(), I, "SHADOWS_PREDECLARED", "", "", "", 0
4025 IF N(I, 2) = 0 THEN 4035
4030 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "default arguments", "", "", 1
4035 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(I, 7), D
4040 IF D <> 5 THEN 4055
4045 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "strings", "", "", 1
4050 LET D = 0
4055 LET M(I, 1) = D
4060 LET I = N(I, 8)
4065 NEXT J
4070 REM the result types follow the parameters
4075 LET Z = 0
4080 FOR J = 1 TO R0
4085 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I, D
4090 IF D <> 5 THEN 4105
4095 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "strings", "", "", 1
4100 LET D = 0
4105 LET M(I, 1) = D
4110 LET U(J) = D
4115 IF D <> 0 THEN 4125
4120 LET Z = 1
4125 LET I = N(I, 8)
4130 NEXT J
4135 LET Y(S, 2) = 1
4140 IF R0 = 0 THEN 4175
4145 LET Y(S, 2) = U(1)
4150 IF R0 = 1 THEN 4175
4155 LET Y(S, 2) = 0
4160 IF Z = 1 THEN 4175
4165 CALL "ttup": T(), N(), X(), X$(), U(), R0, R
4170 LET Y(S, 2) = R
4175 SUBEND
4180 REM ---- ck_const: const item S: its type (LANGUAGE 7.2: i64 when an untyped integer constant
4185 REM and not annotated) and its constant-expression rule; Y(S,4) 1 while checked, 2 done ------
4190 SUB "ck_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
4195 LET Y(S, 4) = 1
4200 LET F = Y(S, 3)
4205 LET X(19) = F
4210 LET E = N(F, 7)
4215 IF N(F, 1) = 0 THEN 4230
4220 LET G = E
4225 LET E = N(E, 8)
4230 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
4235 REM a constant expression: literals, constants, operators, pi inf nan eps, sqrt
4240 FOR J = M(E, 0) TO E
4245 LET K = N(J, 0)
4250 IF K = 25 THEN 4370
4255 IF K = 26 THEN 4370
4260 IF K = 28 THEN 4370
4265 IF K = 29 THEN 4370
4270 IF K = 32 THEN 4370
4275 IF K = 33 THEN 4370
4280 IF K = 34 THEN 4370
4285 IF K = 30 THEN 4320
4290 IF K <> 35 THEN 4355
4295 REM a call of sqrt (itself 'not supported yet: sqrt' in phase 1)
4300 LET H = N(J, 7)
4305 IF N(H, 0) <> 30 THEN 4355
4310 IF S$(N(H, 6)) <> "sqrt" THEN 4355
4315 GOTO 4370
4320 IF M(J, 2) = 0 THEN 4370
4325 IF N(N(J, 9), 0) <> 35 THEN 4335
4330 IF N(N(J, 9), 7) = J THEN 4370
4335 IF M(J, 2) < 0 THEN 4350
4340 IF Y(M(J, 2), 0) = 2 THEN 4370
4345 GOTO 4355
4350 IF M(J, 2) >= -4 THEN 4370
4355 IF M(E, 1) = 0 THEN 4375
4360 CALL "er": N(), X(), X$(), E, "NOT_CONSTANT", "", "", "", 0
4365 GOTO 4375
4370 NEXT J
4375 IF N(F, 1) = 0 THEN 4415
4380 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G, D
4385 IF D <> 5 THEN 4400
4390 CALL "er": N(), X(), X$(), G, "NOT_SUPPORTED", "strings", "", "", 1
4395 LET D = 0
4400 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
4405 LET Y(S, 2) = D
4410 GOTO 4440
4415 CALL "vu": N(), M(), T(), X(), X$(), E, D
4420 IF D <> -1 THEN 4435
4425 CALL "stl": N(), M(), C(), X(), X$(), E, 3
4430 LET D = 3
4435 LET Y(S, 2) = D
4440 LET Y(S, 4) = 2
4445 SUBEND
4450 REM ---- ck_fn: the body of fn S (S = 1: .main, the top-level statements). The var rule
4455 REM (Decision 8) is decided by re-running the walk while a candidate gains an f64 store (X(16));
4460 REM each run starts from the error state before the function and the same symbol rows. --------
4465 SUB "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
4470 DIM A$(4)
4475 LET E6 = X(6)
4480 LET E7 = X(7)
4485 LET E8 = X(8)
4490 LET E9 = X(9)
4495 FOR J = 1 TO 4
4500 LET A$(J) = X$(J)
4505 NEXT J
4510 LET S0 = X(3)
4515 LET Y(S, 9) = S0 + 1
4520 LET F = Y(S, 3)
4525 LET X(16) = 0
4530 LET X(3) = S0
4535 LET X(13) = 0
4540 LET X(12) = 200000
4545 LET X(14) = S
4550 LET X(15) = 0
4555 IF S = 1 THEN 4630
4560 REM the parameters are locals 1..np
4565 LET I = N(F, 7)
4570 FOR J = 1 TO Y(S, 6)
4575 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(I, 6), M(I, 1), 4 + N(I, 1), I, 0, R
4580 LET M(I, 2) = R
4585 LET I = N(I, 8)
4590 NEXT J
4595 REM the body is the last child
4600 FOR J = 1 TO Y(S, 7)
4605 LET I = N(I, 8)
4610 NEXT J
4615 LET B = I
4620 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
4625 GOTO 4685
4630 LET X(12) = X(12) - 2
4635 LET W(X(12)) = -1
4640 LET I = N(X(17), 7)
4645 IF I = 0 THEN 4685
4650 LET K = N(I, 0)
4655 IF K = 2 THEN 4675
4660 IF K = 3 THEN 4675
4665 IF K = 5 THEN 4675
4670 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
4675 LET I = N(I, 8)
4680 GOTO 4645
4685 IF X(16) = 0 THEN 4740
4690 IF X(10) = 1 THEN 4740
4695 REM a candidate became f64: the walk is repeated from the state before the function
4700 LET X(6) = E6
4705 LET X(7) = E7
4710 LET X(8) = E8
4715 LET X(9) = E9
4720 FOR J = 1 TO 4
4725 LET X$(J) = A$(J)
4730 NEXT J
4735 GOTO 4525
4740 LET Y(S, 8) = X(3)
4745 IF S = 1 THEN 4765
4750 IF Y(S, 7) = 0 THEN 4765
4755 IF M(B, 9) = 1 THEN 4765
4760 CALL "er": N(), X(), X$(), F, "MISSING_RETURN", "", "", "", 0
4765 SUBEND
4770 REM ---- ck_cord: every const item, each after the constants its expression names (a depth-first
4775 REM order with an explicit stack in W(1..): pairs (const, next node to scan), so chains of any
4780 REM length need no Baysick recursion); each is checked (ck_const) and then evaluated (cval).
4785 REM Y(S,6) 1 on the stack, 2 done; a name of a const still on the stack closes a cycle, which
4790 REM ck_name reports as 'not a constant expression'. -------------------------------------
4795 SUB "ck_cord": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
4800 FOR S0 = 2 TO X(33)
4805 IF Y(S0, 0) <> 2 THEN 5005
4810 IF Y(S0, 6) <> 0 THEN 5005
4815 LET P = 2
4820 LET W(1) = S0
4825 CALL "cexp": N(), Y(), S0, E
4830 LET W(2) = M(E, 0)
4835 LET Y(S0, 6) = 1
4840 IF P = 0 THEN 5005
4845 LET S = W(P - 1)
4850 LET J = W(P)
4855 CALL "cexp": N(), Y(), S, E
4860 IF J > E THEN 4940
4865 IF N(J, 0) <> 30 THEN 4930
4870 CALL "lk": Y(), W(), X(), X$(), S$(), N(J, 6), R
4875 IF R <= 0 THEN 4930
4880 IF Y(R, 0) <> 2 THEN 4930
4885 IF Y(R, 6) <> 0 THEN 4930
4890 REM a constant not yet ordered: it goes first
4895 LET W(P) = J + 1
4900 LET P = P + 2
4905 LET W(P - 1) = R
4910 CALL "cexp": N(), Y(), R, E
4915 LET W(P) = M(E, 0)
4920 LET Y(R, 6) = 1
4925 GOTO 4840
4930 LET J = J + 1
4935 GOTO 4860
4940 LET P = P - 2
4945 LET X(11) = P
4950 LET X9 = X(9)
4955 CALL "ck_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
4960 REM a constant is evaluated (LANGUAGE 7.2) when its check found no error; else it is failed
4965 REM (6): its uses read a poisoned value, so no second error follows from it (cval)
4970 LET Y(S, 7) = 6
4975 IF X(9) > X9 THEN 4990
4980 LET Y(S, 7) = 0
4985 CALL "cval": N(), M(), Y(), C(), W(), X(), X$(), H(), S
4990 LET X(11) = 0
4995 LET Y(S, 6) = 2
5000 GOTO 4840
5005 NEXT S0
5010 SUBEND
5015 REM ---- cexp: E = the expression node of const item S (after its type, if annotated) ----------
5020 SUB "cexp": N(), Y(), S, E
5025 LET E = N(Y(S, 3), 7)
5030 IF N(Y(S, 3), 1) = 0 THEN 5040
5035 LET E = N(E, 8)
5040 SUBEND
