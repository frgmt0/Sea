2890 REM ---- sc_check: every check of pass 2a (DESIGN 3.5.5 "What pass 2a has checked", phase 1) ---
2895 REM Items first (names, LANGUAGE 7.2: visible everywhere), then signatures, then every const,
2900 REM then the body of every function and of .main. Locals: S symbol, I node, K kind.
2905 SUB "sc_check": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
2910 LET X(3) = 1
2915 LET X(4) = 9
2920 LET X(11) = 0
2925 LET X(12) = 200000
2930 LET X(29) = 0
2935 LET X(30) = 1
2940 LET X(31) = 0
2945 FOR J = 0 TO 9
2950 LET Y(1, J) = 0
2955 NEXT J
2960 LET Y(1, 0) = 1
2965 LET Y(1, 2) = 1
2970 LET Y(1, 5) = 1
2975 REM the items of the program, in stream order; the other children are .main's statements
2980 LET I = N(X(17), 7)
2985 IF I = 0 THEN 3040
2990 LET X(19) = I
2995 LET K = N(I, 0)
3000 IF K = 2 THEN 3025
3005 IF K = 3 THEN 3025
3010 IF K = 5 THEN 3025
3015 LET X(29) = X(29) + 1
3020 GOTO 3030
3025 CALL "ck_item": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
3030 LET I = N(I, 8)
3035 GOTO 2985
3040 LET X(33) = X(3)
3045 FOR S = 2 TO X(33)
3050 IF Y(S, 0) <> 1 THEN 3060
3055 CALL "ck_sig": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3060 NEXT S
3065 FOR S = 2 TO X(33)
3070 IF Y(S, 0) <> 2 THEN 3085
3075 IF Y(S, 4) <> 0 THEN 3085
3080 CALL "ck_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3085 NEXT S
3090 FOR S = 2 TO X(33)
3095 IF Y(S, 0) <> 1 THEN 3105
3100 CALL "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3105 NEXT S
3110 CALL "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
3115 SUBEND
3120 REM ---- ck_item: one top-level item I becomes a symbol (fn 1, const 2, struct 3) ---------------
3125 REM A predeclared name is 'redefinition of predeclared name'; a name already taken by an earlier
3130 REM item is 'redefinition' at the later item, which is then not entered (LANGUAGE 3.3, 7.2).
3135 SUB "ck_item": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
3140 LET Q = N(I, 6)
3145 LET K = N(I, 0)
3150 CALL "pdx": X$(), S$(Q), P
3155 IF P = 0 THEN 3165
3160 CALL "er": N(), X(), X$(), I, "PREDECLARED", "", "", "", 0
3165 FOR J = 2 TO X(3)
3170 IF Y(J, 1) <> Q THEN 3185
3175 CALL "er": N(), X(), X$(), I, "REDEFINITION", S$(Q), "", "", 1
3180 GOTO 3300
3185 NEXT J
3190 CALL "nsym": N(), Y(), X(), X$(), R
3195 IF R = 0 THEN 3300
3200 LET Y(R, 1) = Q
3205 LET Y(R, 3) = I
3210 IF K = 2 THEN 3270
3215 IF K = 3 THEN 3290
3220 REM fn: fid in stream order, np, nr
3225 LET Y(R, 0) = 1
3230 LET X(30) = X(30) + 1
3235 LET Y(R, 5) = X(30)
3240 LET Y(R, 6) = N(I, 2)
3245 LET Y(R, 7) = N(I, 3)
3250 LET Y(R, 4) = N(I, 1)
3255 IF N(I, 1) = 0 THEN 3300
3260 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "elemental functions", "", "", 1
3265 GOTO 3300
3270 LET Y(R, 0) = 2
3275 LET X(31) = X(31) + 1
3280 LET Y(R, 5) = X(31)
3285 GOTO 3300
3290 LET Y(R, 0) = 3
3295 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "structs", "", "", 1
3300 SUBEND
3305 REM ---- tyof: R = the type written by type node I (phase 1: f64 i64 bool; str is returned as 5
3310 REM and reported by the caller at the node DESIGN 2.6.2 names; others are errors here) ---------
3315 SUB "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I, R
3320 LET R = 0
3325 IF N(I, 1) = 1 THEN 3340
3330 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "arrays", "", "", 1
3335 GOTO 3440
3340 LET B$ = S$(N(I, 6))
3345 LET L0 = LEN(B$)
3350 IF L0 > 6 THEN 3400
3355 IF L0 < 3 THEN 3400
3360 LET P = POS("|f64   |i64   |bool  |str   |Figure|Axes  |Lu    |Chol  |", "|" & SEG$(B$ & "      ", 1, 6) & "|")
3365 IF P = 0 THEN 3400
3370 LET P = (P - 1) / 7 + 1
3375 IF P > 4 THEN 3390
3380 LET R = VAL(SEG$("4325", P, P))
3385 GOTO 3440
3390 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "handle types", "", "", 1
3395 GOTO 3440
3400 REM an identifier: a declared struct (not in phase 1) or no type at all
3405 FOR J = 2 TO X(33)
3410 IF Y(J, 1) <> N(I, 6) THEN 3430
3415 IF Y(J, 0) <> 3 THEN 3430
3420 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "structs", "", "", 1
3425 GOTO 3440
3430 NEXT J
3435 CALL "er": N(), X(), X$(), I, "UNKNOWN_STRUCT", "", "", "", 0
3440 SUBEND
3445 REM ---- ck_sig: the signature of fn S: parameter types in M(param,1), result types in
3450 REM M(type,1), the result type in Y(S,2) (1 none, a type, or a ttuple; 0 after an error) -------
3455 SUB "ck_sig": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3460 DIM U(70)
3465 LET F = Y(S, 3)
3470 LET X(19) = F
3475 LET P0 = Y(S, 6)
3480 LET R0 = Y(S, 7)
3485 LET I = N(F, 7)
3490 FOR J = 1 TO P0
3495 LET Q = N(I, 6)
3500 REM two parameters of one name: at the later one
3505 LET H = N(F, 7)
3510 IF H = I THEN 3540
3515 IF N(H, 6) <> Q THEN 3530
3520 CALL "er": N(), X(), X$(), I, "REDEFINITION", S$(Q), "", "", 1
3525 GOTO 3540
3530 LET H = N(H, 8)
3535 GOTO 3510
3540 CALL "pdx": X$(), S$(Q), P
3545 IF P = 0 THEN 3555
3550 CALL "er": N(), X(), X$(), I, "SHADOWS_PREDECLARED", "", "", "", 0
3555 IF N(I, 2) = 0 THEN 3565
3560 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "default arguments", "", "", 1
3565 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(I, 7), D
3570 IF D <> 5 THEN 3585
3575 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "strings", "", "", 1
3580 LET D = 0
3585 LET M(I, 1) = D
3590 LET I = N(I, 8)
3595 NEXT J
3600 REM the result types follow the parameters
3605 LET Z = 0
3610 FOR J = 1 TO R0
3615 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I, D
3620 IF D <> 5 THEN 3635
3625 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "strings", "", "", 1
3630 LET D = 0
3635 LET M(I, 1) = D
3640 LET U(J) = D
3645 IF D <> 0 THEN 3655
3650 LET Z = 1
3655 LET I = N(I, 8)
3660 NEXT J
3665 LET Y(S, 2) = 1
3670 IF R0 = 0 THEN 3705
3675 LET Y(S, 2) = U(1)
3680 IF R0 = 1 THEN 3705
3685 LET Y(S, 2) = 0
3690 IF Z = 1 THEN 3705
3695 CALL "ttup": T(), N(), X(), X$(), U(), R0, R
3700 LET Y(S, 2) = R
3705 SUBEND
3710 REM ---- ck_const: const item S: its type (LANGUAGE 7.2: i64 when an untyped integer constant
3715 REM and not annotated) and its constant-expression rule; Y(S,4) 1 while checked, 2 done ------
3720 SUB "ck_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3725 LET Y(S, 4) = 1
3730 LET F = Y(S, 3)
3735 LET X(19) = F
3740 LET E = N(F, 7)
3745 IF N(F, 1) = 0 THEN 3760
3750 LET G = E
3755 LET E = N(E, 8)
3760 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
3765 REM a constant expression: literals, constants, operators, pi inf nan eps, sqrt
3770 FOR J = M(E, 0) TO E
3775 LET K = N(J, 0)
3780 IF K = 25 THEN 3900
3785 IF K = 26 THEN 3900
3790 IF K = 28 THEN 3900
3795 IF K = 29 THEN 3900
3800 IF K = 32 THEN 3900
3805 IF K = 33 THEN 3900
3810 IF K = 34 THEN 3900
3815 IF K = 30 THEN 3850
3820 IF K <> 35 THEN 3885
3825 REM a call of sqrt (itself 'not supported yet: sqrt' in phase 1)
3830 LET H = N(J, 7)
3835 IF N(H, 0) <> 30 THEN 3885
3840 IF S$(N(H, 6)) <> "sqrt" THEN 3885
3845 GOTO 3900
3850 IF M(J, 2) = 0 THEN 3900
3855 IF N(N(J, 9), 0) <> 35 THEN 3865
3860 IF N(N(J, 9), 7) = J THEN 3900
3865 IF M(J, 2) < 0 THEN 3880
3870 IF Y(M(J, 2), 0) = 2 THEN 3900
3875 GOTO 3885
3880 IF M(J, 2) >= -4 THEN 3900
3885 IF M(E, 1) = 0 THEN 3905
3890 CALL "er": N(), X(), X$(), E, "NOT_CONSTANT", "", "", "", 0
3895 GOTO 3905
3900 NEXT J
3905 IF N(F, 1) = 0 THEN 3945
3910 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G, D
3915 IF D <> 5 THEN 3930
3920 CALL "er": N(), X(), X$(), G, "NOT_SUPPORTED", "strings", "", "", 1
3925 LET D = 0
3930 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
3935 LET Y(S, 2) = D
3940 GOTO 3970
3945 CALL "vu": N(), M(), T(), X(), X$(), E, D
3950 IF D <> -1 THEN 3965
3955 CALL "stl": N(), M(), C(), X(), X$(), E, 3
3960 LET D = 3
3965 LET Y(S, 2) = D
3970 LET Y(S, 4) = 2
3975 SUBEND
3980 REM ---- ck_fn: the body of fn S (S = 1: .main, the top-level statements). The var rule
3985 REM (Decision 8) is decided by re-running the walk while a candidate gains an f64 store (X(16));
3990 REM each run starts from the error state before the function and the same symbol rows. --------
3995 SUB "ck_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
4000 DIM A$(4)
4005 LET E6 = X(6)
4010 LET E7 = X(7)
4015 LET E8 = X(8)
4020 LET E9 = X(9)
4025 FOR J = 1 TO 4
4030 LET A$(J) = X$(J)
4035 NEXT J
4040 LET S0 = X(3)
4045 LET Y(S, 9) = S0 + 1
4050 LET F = Y(S, 3)
4055 LET X(16) = 0
4060 LET X(3) = S0
4065 LET X(13) = 0
4070 LET X(12) = 200000
4075 LET X(14) = S
4080 LET X(15) = 0
4085 IF S = 1 THEN 4160
4090 REM the parameters are locals 1..np
4095 LET I = N(F, 7)
4100 FOR J = 1 TO Y(S, 6)
4105 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(I, 6), M(I, 1), 4 + N(I, 1), I, 0, R
4110 LET M(I, 2) = R
4115 LET I = N(I, 8)
4120 NEXT J
4125 REM the body is the last child
4130 FOR J = 1 TO Y(S, 7)
4135 LET I = N(I, 8)
4140 NEXT J
4145 LET B = I
4150 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
4155 GOTO 4215
4160 LET X(12) = X(12) - 2
4165 LET W(X(12)) = -1
4170 LET I = N(X(17), 7)
4175 IF I = 0 THEN 4215
4180 LET K = N(I, 0)
4185 IF K = 2 THEN 4205
4190 IF K = 3 THEN 4205
4195 IF K = 5 THEN 4205
4200 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
4205 LET I = N(I, 8)
4210 GOTO 4175
4215 IF X(16) = 0 THEN 4270
4220 IF X(10) = 1 THEN 4270
4225 REM a candidate became f64: the walk is repeated from the state before the function
4230 LET X(6) = E6
4235 LET X(7) = E7
4240 LET X(8) = E8
4245 LET X(9) = E9
4250 FOR J = 1 TO 4
4255 LET X$(J) = A$(J)
4260 NEXT J
4265 GOTO 4055
4270 LET Y(S, 8) = X(3)
4275 IF S = 1 THEN 4295
4280 IF Y(S, 7) = 0 THEN 4295
4285 IF M(B, 9) = 1 THEN 4295
4290 CALL "er": N(), X(), X$(), F, "MISSING_RETURN", "", "", "", 0
4295 SUBEND
