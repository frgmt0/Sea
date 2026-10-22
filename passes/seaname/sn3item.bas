3425 REM ---- sn_check: the work of seaname (DESIGN 3.4.1): the items in stream order (names, LANGUAGE
3430 REM 7.2: visible everywhere), the signatures of the entered functions, every entered const in
3435 REM the constant order (typed path, value), then the resolution walk of the body of every
3440 REM entered fn in fid order and of .main (the symbols limit counts in this order). Locals: S I K.
3445 SUB "sn_check": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H(), Q()
3450 LET X(3) = 1
3455 LET X(4) = 9
3460 LET X(11) = 0
3465 LET X(12) = 200000
3470 LET X(30) = 1
3475 LET X(31) = 0
3480 LET X(42) = 0
3485 FOR J = 0 TO 9
3490 LET Y(1, J) = 0
3495 NEXT J
3500 LET Y(1, 0) = 1
3505 LET Y(1, 2) = 1
3507 LET Y(1, 5) = 1
3510 REM the items of the program, in stream order; the other children are .main's statements
3515 LET I = N(X(17), 7)
3520 IF I = 0 THEN 3575
3525 LET X(19) = I
3530 LET K = N(I, 0)
3535 IF K = 2 THEN 3560
3540 IF K = 3 THEN 3560
3545 IF K <> 5 THEN 3565
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
3615 CALL "rs_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3620 NEXT S
3625 CALL "rs_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
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
3722 LET M(I, 2) = R
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
3806 LET X(42) = X(42) + 1
3807 LET Y(R, 5) = X(42)
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
4225 REM ---- sn_const: const item S on its well-typed path (DESIGN 3.4.1 "Constants"): resolve and
4230 REM type its expression (rs_expr), then its annotation (f64 i64 bool) or the i64 of an untyped
4235 REM constant (LANGUAGE 7.2); evaluated (cval) only when nothing failed (X(40), fl), its type is
4240 REM not the error type, and it names no constant without a value (Decision 25); else Y(S,7) 6.
4245 SUB "sn_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), Q(), S
4250 LET F = Y(S, 3)
4255 LET X(19) = F
4260 CALL "cexp": N(), Y(), S, E
4265 LET X0 = X(40)
4270 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
4275 IF N(F, 1) = 0 THEN 4310
4280 REM an annotation: a scalar f64, i64 or bool; any other fails the typed path
4285 CALL "cty": N(), S$(), N(F, 7), D
4290 IF D > 0 THEN 4300
4295 CALL "fl": X()
4300 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
4305 GOTO 4330
4310 CALL "vu": N(), M(), T(), X(), X$(), E, D
4315 IF D <> -1 THEN 4330
4320 CALL "stl": N(), M(), C(), X(), X$(), E, 3
4325 LET D = 3
4330 LET Y(S, 2) = D
4335 LET Y(S, 7) = 6
4340 IF X(40) > X0 THEN 4355
4345 IF D = 0 THEN 4355
4350 CALL "cval": N(), M(), Y(), C(), W(), X(), X$(), Q(), S
4355 SUBEND
4360 REM ---- cty: D = the type written by the type node G of a const if seaname can use it (a scalar
4365 REM f64, i64 or bool: 4, 3, 2), else 0 (seacheck reports the annotation's errors) ----------
4370 SUB "cty": N(), S$(), G, D
4375 LET D = 0
4380 IF N(G, 1) <> 1 THEN 4415
4385 LET B$ = S$(N(G, 6))
4390 IF LEN(B$) < 3 THEN 4415
4395 IF LEN(B$) > 4 THEN 4415
4400 LET P = POS("|f64 |i64 |bool|", "|" & SEG$(B$ & " ", 1, 4) & "|")
4405 IF P = 0 THEN 4415
4410 LET D = VAL(SEG$("432", (P + 4) / 5, (P + 4) / 5))
4415 SUBEND
4820 REM ---- ck_cord: every const item, each after the constants its expression names (a depth-first
4825 REM order with an explicit stack in W(1..): pairs (const, next node to scan), so chains of any
4830 REM length need no Baysick recursion); each is typed and evaluated when its scan ends (sn_const).
4835 REM Y(S,6) 1 waiting (on the stack), 2 done; a name of a waiting const has no value (rs_name).
4845 SUB "ck_cord": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H(), Q()
4850 FOR S0 = 2 TO X(33)
4855 IF Y(S0, 0) <> 2 THEN 5105
4860 IF Y(S0, 6) <> 0 THEN 5105
4865 LET P = 2
4870 LET W(1) = S0
4875 CALL "cexp": N(), Y(), S0, E
4880 LET W(2) = M(E, 0)
4885 LET Y(S0, 6) = 1
4890 IF P = 0 THEN 5105
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
5005 CALL "sn_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), Q(), S
5090 LET X(11) = 0
5095 LET Y(S, 6) = 2
5100 GOTO 4890
5105 NEXT S0
5110 SUBEND
5115 REM ---- cexp: E = the expression node of const item S (after its type, if annotated) ----------
5120 SUB "cexp": N(), Y(), S, E
5125 LET E = N(Y(S, 3), 7)
5130 IF N(Y(S, 3), 1) = 0 THEN 5140
5135 LET E = N(E, 8)
5140 SUBEND
