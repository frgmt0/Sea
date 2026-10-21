3225 REM ---- sc_check: every check of pass 2a (DESIGN 3.5.5 "What pass 2a has checked", phase 1) ---
3230 REM Items first (names, LANGUAGE 7.2: visible everywhere), then signatures, then every const,
3235 REM then the body of every function and of .main. Locals: S symbol, I node, K kind.
3240 SUB "sc_check": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
3245 LET X(3) = 1
3250 LET X(4) = 9
3255 LET X(11) = 0
3260 LET X(12) = 200000
3265 LET X(29) = 0
3270 LET X(30) = 1
3275 LET X(31) = 0
3280 FOR J = 0 TO 9
3285 LET Y(1, J) = 0
3290 NEXT J
3295 LET Y(1, 0) = 1
3300 LET Y(1, 2) = 1
3305 LET Y(1, 5) = 1
3310 REM the items of the program, in stream order; the other children are .main's statements
3315 LET I = N(X(17), 7)
3320 IF I = 0 THEN 3375
3325 LET X(19) = I
3330 LET K = N(I, 0)
3335 IF K = 2 THEN 3360
3340 IF K = 3 THEN 3360
3345 IF K = 5 THEN 3360
3350 LET X(29) = X(29) + 1
3355 GOTO 3365
3360 CALL "ck_item": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
3365 LET I = N(I, 8)
3370 GOTO 3320
3375 LET X(33) = X(3)
3380 FOR S = 2 TO X(33)
3385 IF Y(S, 0) <> 1 THEN 3395
3390 CALL "ck_sig": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3395 NEXT S
3400 CALL "ck_cord": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
3405 FOR S = 2 TO X(33)
3410 IF Y(S, 0) <> 1 THEN 3420
3415 CALL "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3420 NEXT S
3425 CALL "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
3430 SUBEND
3435 REM ---- ck_item: one top-level item I becomes a symbol (fn 1, const 2, struct 3) ---------------
3440 REM A predeclared name is 'redefinition of predeclared name'; a name already taken by an earlier
3445 REM item is 'redefinition' at the later item, which is then not entered (LANGUAGE 3.3, 7.2).
3450 SUB "ck_item": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
3455 LET Q = N(I, 6)
3460 LET K = N(I, 0)
3465 CALL "pdx": X$(), S$(Q), P
3470 IF P = 0 THEN 3480
3475 CALL "er": N(), X(), X$(), I, "PREDECLARED", "", "", "", 0
3480 FOR J = 2 TO X(3)
3485 IF Y(J, 1) <> Q THEN 3500
3490 CALL "er": N(), X(), X$(), I, "REDEFINITION", S$(Q), "", "", 1
3495 GOTO 3615
3500 NEXT J
3505 CALL "nsym": N(), Y(), X(), X$(), R
3510 IF R = 0 THEN 3615
3515 LET Y(R, 1) = Q
3520 LET Y(R, 3) = I
3525 IF K = 2 THEN 3585
3530 IF K = 3 THEN 3605
3535 REM fn: fid in stream order, np, nr
3540 LET Y(R, 0) = 1
3545 LET X(30) = X(30) + 1
3550 LET Y(R, 5) = X(30)
3555 LET Y(R, 6) = N(I, 2)
3560 LET Y(R, 7) = N(I, 3)
3565 LET Y(R, 4) = N(I, 1)
3570 IF N(I, 1) = 0 THEN 3615
3575 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "elemental functions", "", "", 1
3580 GOTO 3615
3585 LET Y(R, 0) = 2
3590 LET X(31) = X(31) + 1
3595 LET Y(R, 5) = X(31)
3600 GOTO 3615
3605 LET Y(R, 0) = 3
3610 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "structs", "", "", 1
3615 SUBEND
3620 REM ---- tyof: R = the type written by type node I (phase 1: f64 i64 bool; str is returned as 5
3625 REM and reported by the caller at the node DESIGN 2.6.2 names; others are errors here) ---------
3630 SUB "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I, R
3635 LET R = 0
3640 IF N(I, 1) = 1 THEN 3655
3645 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "arrays", "", "", 1
3650 GOTO 3755
3655 LET B$ = S$(N(I, 6))
3660 LET L0 = LEN(B$)
3665 IF L0 > 6 THEN 3715
3670 IF L0 < 3 THEN 3715
3675 LET P = POS("|f64   |i64   |bool  |str   |Figure|Axes  |Lu    |Chol  |", "|" & SEG$(B$ & "      ", 1, 6) & "|")
3680 IF P = 0 THEN 3715
3685 LET P = (P - 1) / 7 + 1
3690 IF P > 4 THEN 3705
3695 LET R = VAL(SEG$("4325", P, P))
3700 GOTO 3755
3705 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "handle types", "", "", 1
3710 GOTO 3755
3715 REM an identifier: a declared struct (not in phase 1) or no type at all
3720 FOR J = 2 TO X(33)
3725 IF Y(J, 1) <> N(I, 6) THEN 3745
3730 IF Y(J, 0) <> 3 THEN 3745
3735 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "structs", "", "", 1
3740 GOTO 3755
3745 NEXT J
3750 CALL "er": N(), X(), X$(), I, "UNKNOWN_STRUCT", "", "", "", 0
3755 SUBEND
3760 REM ---- ck_sig: the signature of fn S: parameter types in M(param,1), result types in
3765 REM M(type,1), the result type in Y(S,2) (1 none, a type, or a ttuple; 0 after an error) -------
3770 SUB "ck_sig": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3775 DIM U(70)
3780 LET F = Y(S, 3)
3785 LET X(19) = F
3790 LET P0 = Y(S, 6)
3795 LET R0 = Y(S, 7)
3800 LET I = N(F, 7)
3805 FOR J = 1 TO P0
3810 LET Q = N(I, 6)
3815 REM two parameters of one name: at the later one
3820 LET H = N(F, 7)
3825 IF H = I THEN 3855
3830 IF N(H, 6) <> Q THEN 3845
3835 CALL "er": N(), X(), X$(), I, "REDEFINITION", S$(Q), "", "", 1
3840 GOTO 3855
3845 LET H = N(H, 8)
3850 GOTO 3825
3855 CALL "pdx": X$(), S$(Q), P
3860 IF P = 0 THEN 3870
3865 CALL "er": N(), X(), X$(), I, "SHADOWS_PREDECLARED", "", "", "", 0
3870 IF N(I, 2) = 0 THEN 3880
3875 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "default arguments", "", "", 1
3880 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(I, 7), D
3885 IF D <> 5 THEN 3900
3890 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "strings", "", "", 1
3895 LET D = 0
3900 LET M(I, 1) = D
3905 LET I = N(I, 8)
3910 NEXT J
3915 REM the result types follow the parameters
3920 LET Z = 0
3925 FOR J = 1 TO R0
3930 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I, D
3935 IF D <> 5 THEN 3950
3940 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "strings", "", "", 1
3945 LET D = 0
3950 LET M(I, 1) = D
3955 LET U(J) = D
3960 IF D <> 0 THEN 3970
3965 LET Z = 1
3970 LET I = N(I, 8)
3975 NEXT J
3980 LET Y(S, 2) = 1
3985 IF R0 = 0 THEN 4020
3990 LET Y(S, 2) = U(1)
3995 IF R0 = 1 THEN 4020
4000 LET Y(S, 2) = 0
4005 IF Z = 1 THEN 4020
4010 CALL "ttup": T(), N(), X(), X$(), U(), R0, R
4015 LET Y(S, 2) = R
4020 SUBEND
4025 REM ---- ck_const: const item S: its type (LANGUAGE 7.2: i64 when an untyped integer constant
4030 REM and not annotated) and its constant-expression rule; Y(S,4) 1 while checked, 2 done ------
4035 SUB "ck_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
4040 LET Y(S, 4) = 1
4045 LET F = Y(S, 3)
4050 LET X(19) = F
4055 LET E = N(F, 7)
4060 IF N(F, 1) = 0 THEN 4075
4065 LET G = E
4070 LET E = N(E, 8)
4075 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
4080 REM a constant expression: literals, constants, operators, pi inf nan eps, sqrt
4085 FOR J = M(E, 0) TO E
4090 LET K = N(J, 0)
4095 IF K = 25 THEN 4215
4100 IF K = 26 THEN 4215
4105 IF K = 28 THEN 4215
4110 IF K = 29 THEN 4215
4115 IF K = 32 THEN 4215
4120 IF K = 33 THEN 4215
4125 IF K = 34 THEN 4215
4130 IF K = 30 THEN 4165
4135 IF K <> 35 THEN 4200
4140 REM a call of sqrt (itself 'not supported yet: sqrt' in phase 1)
4145 LET H = N(J, 7)
4150 IF N(H, 0) <> 30 THEN 4200
4155 IF S$(N(H, 6)) <> "sqrt" THEN 4200
4160 GOTO 4215
4165 IF M(J, 2) = 0 THEN 4215
4170 IF N(N(J, 9), 0) <> 35 THEN 4180
4175 IF N(N(J, 9), 7) = J THEN 4215
4180 IF M(J, 2) < 0 THEN 4195
4185 IF Y(M(J, 2), 0) = 2 THEN 4215
4190 GOTO 4200
4195 IF M(J, 2) >= -4 THEN 4215
4200 IF M(E, 1) = 0 THEN 4220
4205 CALL "er": N(), X(), X$(), E, "NOT_CONSTANT", "", "", "", 0
4210 GOTO 4220
4215 NEXT J
4220 IF N(F, 1) = 0 THEN 4260
4225 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G, D
4230 IF D <> 5 THEN 4245
4235 CALL "er": N(), X(), X$(), G, "NOT_SUPPORTED", "strings", "", "", 1
4240 LET D = 0
4245 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
4250 LET Y(S, 2) = D
4255 GOTO 4285
4260 CALL "vu": N(), M(), T(), X(), X$(), E, D
4265 IF D <> -1 THEN 4280
4270 CALL "stl": N(), M(), C(), X(), X$(), E, 3
4275 LET D = 3
4280 LET Y(S, 2) = D
4285 LET Y(S, 4) = 2
4290 SUBEND
4295 REM ---- ck_fn: the body of fn S (S = 1: .main, the top-level statements). The var rule
4300 REM (Decision 8) is decided by re-running the walk while a candidate gains an f64 store (X(16));
4305 REM each run starts from the error state before the function and the same symbol rows. --------
4310 SUB "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
4315 DIM A$(4)
4320 LET E6 = X(6)
4325 LET E7 = X(7)
4330 LET E8 = X(8)
4335 LET E9 = X(9)
4340 FOR J = 1 TO 4
4345 LET A$(J) = X$(J)
4350 NEXT J
4355 LET S0 = X(3)
4360 LET Y(S, 9) = S0 + 1
4365 LET F = Y(S, 3)
4370 LET X(16) = 0
4375 LET X(3) = S0
4380 LET X(13) = 0
4385 LET X(12) = 200000
4390 LET X(14) = S
4395 LET X(15) = 0
4400 IF S = 1 THEN 4475
4405 REM the parameters are locals 1..np
4410 LET I = N(F, 7)
4415 FOR J = 1 TO Y(S, 6)
4420 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(I, 6), M(I, 1), 4 + N(I, 1), I, 0, R
4425 LET M(I, 2) = R
4430 LET I = N(I, 8)
4435 NEXT J
4440 REM the body is the last child
4445 FOR J = 1 TO Y(S, 7)
4450 LET I = N(I, 8)
4455 NEXT J
4460 LET B = I
4465 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
4470 GOTO 4530
4475 LET X(12) = X(12) - 2
4480 LET W(X(12)) = -1
4485 LET I = N(X(17), 7)
4490 IF I = 0 THEN 4530
4495 LET K = N(I, 0)
4500 IF K = 2 THEN 4520
4505 IF K = 3 THEN 4520
4510 IF K = 5 THEN 4520
4515 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
4520 LET I = N(I, 8)
4525 GOTO 4490
4530 IF X(16) = 0 THEN 4585
4535 IF X(10) = 1 THEN 4585
4540 REM a candidate became f64: the walk is repeated from the state before the function
4545 LET X(6) = E6
4550 LET X(7) = E7
4555 LET X(8) = E8
4560 LET X(9) = E9
4565 FOR J = 1 TO 4
4570 LET X$(J) = A$(J)
4575 NEXT J
4580 GOTO 4370
4585 LET Y(S, 8) = X(3)
4590 IF S = 1 THEN 4610
4595 IF Y(S, 7) = 0 THEN 4610
4600 IF M(B, 9) = 1 THEN 4610
4605 CALL "er": N(), X(), X$(), F, "MISSING_RETURN", "", "", "", 0
4610 SUBEND
4615 REM ---- ck_cord: every const item, each after the constants its expression names (a depth-first
4620 REM order with an explicit stack in W(1..): pairs (const, next node to scan), so chains of any
4625 REM length need no Baysick recursion); each is checked (ck_const) and then evaluated (cval).
4630 REM Y(S,6) 1 on the stack, 2 done; a name of a const still on the stack closes a cycle, which
4635 REM ck_name reports as 'not a constant expression'. -------------------------------------
4640 SUB "ck_cord": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
4645 FOR S0 = 2 TO X(33)
4650 IF Y(S0, 0) <> 2 THEN 4820
4655 IF Y(S0, 6) <> 0 THEN 4820
4660 LET P = 2
4665 LET W(1) = S0
4670 CALL "cexp": N(), Y(), S0, E
4675 LET W(2) = M(E, 0)
4680 LET Y(S0, 6) = 1
4685 IF P = 0 THEN 4820
4690 LET S = W(P - 1)
4695 LET J = W(P)
4700 CALL "cexp": N(), Y(), S, E
4705 IF J > E THEN 4785
4710 IF N(J, 0) <> 30 THEN 4775
4715 CALL "lk": Y(), W(), X(), X$(), S$(), N(J, 6), R
4720 IF R <= 0 THEN 4775
4725 IF Y(R, 0) <> 2 THEN 4775
4730 IF Y(R, 6) <> 0 THEN 4775
4735 REM a constant not yet ordered: it goes first
4740 LET W(P) = J + 1
4745 LET P = P + 2
4750 LET W(P - 1) = R
4755 CALL "cexp": N(), Y(), R, E
4760 LET W(P) = M(E, 0)
4765 LET Y(R, 6) = 1
4770 GOTO 4685
4775 LET J = J + 1
4780 GOTO 4705
4785 LET P = P - 2
4790 LET X(11) = P
4795 CALL "ck_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
4800 CALL "cval": N(), M(), Y(), C(), W(), X(), X$(), H(), S
4805 LET X(11) = 0
4810 LET Y(S, 6) = 2
4815 GOTO 4685
4820 NEXT S0
4825 SUBEND
4830 REM ---- cexp: E = the expression node of const item S (after its type, if annotated) ----------
4835 SUB "cexp": N(), Y(), S, E
4840 LET E = N(Y(S, 3), 7)
4845 IF N(Y(S, 3), 1) = 0 THEN 4855
4850 LET E = N(E, 8)
4855 SUBEND
