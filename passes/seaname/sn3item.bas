3425 REM ---- sn_check: the work of seaname (DESIGN 3.4.1, 3.4.2): the items in stream order (names,
3430 REM LANGUAGE 7.2: visible everywhere), every entered const in the constant order (typed path,
3435 REM value), the struct fields and signatures, the resolution walk of the body of every entered fn
3440 REM in fid order and of .main (the symbols limit counts in this order), the other type nodes,
3442 REM then the call pre-pass of the LANGUAGE 8.6 classes (sn_cls).
3445 SUB "sn_check": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H(), Q(), G$()
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
3576 CALL "tyst": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
3577 REM the type nodes in the order of DESIGN 3.4.2: scalar const annotations, the constants,
3578 REM the struct fields, the signatures, then (after the walks) every other one in file order
3580 CALL "tyconst": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
3585 CALL "ck_cord": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H(), Q(), G$()
3590 CALL "tyfld": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
3595 FOR S = 2 TO X(33)
3600 IF Y(S, 0) <> 1 THEN 3610
3605 CALL "ck_sig": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3610 NEXT S
3612 FOR S = 2 TO X(33)
3614 IF Y(S, 0) <> 1 THEN 3618
3616 CALL "rs_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3618 NEXT S
3625 CALL "rs_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
3627 CALL "tyfin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
3628 REM the call pre-pass (DESIGN 2.11.2, 2.11.3), after every body is resolved
3629 CALL "sn_cls": N(), M(), Y(), W(), X()
3630 SUBEND
3635 REM ---- ck_item: one top-level item I becomes a symbol (fn 1, const 2, struct 3) ---------------
3638 REM An item of file 0 of a stream of more than one #file (the prelude) is exempt (L-s).
3640 REM A predeclared name is 'redefinition of predeclared name'; a name already taken by an earlier
3645 REM item is 'redefinition' at the later item, which is then not entered (LANGUAGE 3.3, 7.2).
3650 SUB "ck_item": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
3655 LET Q = N(I, 6)
3660 LET K = N(I, 0)
3665 CALL "pdx": X$(), S$(Q), P
3670 IF P = 0 THEN 3680
3672 IF X(44) < 2 THEN 3675
3674 IF N(I, 4) < 1E9 THEN 3680
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
3815 SUBEND
3820 REM ---- tyof: R = the type of type node I of a signature (DESIGN 3.4.2): looked up with no local
3825 REM in scope (tylk) and resolved (tyres, which reports its errors); 0 after an error and for a
3827 REM str type of a fixed shape, which is the phase rule's strings at the node (DESIGN 3.4.2) ----
3830 SUB "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I, R
3835 LET X(12) = 200000
3840 CALL "tylk": N(), M(), Y(), W(), S$(), X(), X$(), I
3845 CALL "tyres": N(), M(), Y(), T(), C(), S$(), X(), X$(), I
3850 LET R = M(I, 1)
3855 SUBEND
3960 REM ---- ck_sig: the signature of fn S: parameter types in M(param,1), result types in
3965 REM M(type,1), the result type in Y(S,2) (1 none, a type, or a ttuple; 0 after an error); the
3967 REM structural checks of the defaults (236, 227) and their names resolved (rsdef; DESIGN 2.11.2) --
3970 SUB "ck_sig": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
3975 DIM U(70)
3980 LET F = Y(S, 3)
3985 LET X(19) = F
3990 LET P0 = Y(S, 6)
3995 LET R0 = Y(S, 7)
4000 LET I = N(F, 7)
4002 LET D9 = 0
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
4070 IF N(I, 2) = 0 THEN 4085
4072 LET D9 = 1
4074 IF N(I, 1) = 0 THEN 4095
4075 REM a ref parameter with a default: 227 at the default expression (LANGUAGE 8.1, L-bw)
4076 CALL "er": N(), X(), X$(), N(N(I, 7), 8), "REF_TARGET", "", "", "", 0
4080 GOTO 4095
4085 REM after a parameter with a default, one without: 236 at its param (L-bx)
4088 IF D9 = 0 THEN 4095
4090 CALL "er": N(), X(), X$(), I, "DEFAULT_MISSING", "", "", "", 0
4095 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(I, 7), D
4100 LET M(I, 1) = D
4102 IF N(I, 2) = 0 THEN 4105
4103 CALL "rsdef": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(N(I, 7), 8), F
4105 LET I = N(I, 8)
4110 NEXT J
4115 REM the result types follow the parameters
4120 LET Z = 0
4125 FOR J = 1 TO R0
4145 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I, D
4150 IF J > 1 THEN 4155
4152 LET V0 = D
4155 LET U(J) = D
4157 IF D < 10 THEN 4160
4158 LET U(J) = T(D, 9)
4160 IF D <> 0 THEN 4170
4165 LET Z = 1
4170 LET I = N(I, 8)
4175 NEXT J
4180 LET Y(S, 2) = 1
4185 IF R0 = 0 THEN 4220
4190 LET Y(S, 2) = V0
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
4245 SUB "sn_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), Q(), G$(), S
4250 LET F = Y(S, 3)
4255 LET X(19) = F
4260 CALL "cexp": N(), Y(), S, E
4265 LET X0 = X(40)
4270 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
4275 IF N(F, 1) = 0 THEN 4310
4280 REM an annotation: a scalar f64, i64 or bool; any other fails the typed path
4285 CALL "cty": N(), M(), N(F, 7), D
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
4350 CALL "cval": N(), M(), Y(), C(), W(), X(), X$(), Q(), S$(), G$(), S
4355 SUBEND
4360 REM ---- cty: D = the type of the annotation G of a const, resolved before the constants (tyconst),
4365 REM if seaname can use it (a scalar f64, i64, bool or str: 4, 3, 2, 5), else 0 -----------------
4370 SUB "cty": N(), M(), G, D
4375 LET D = 0
4380 IF N(G, 1) <> 1 THEN 4415
4385 IF M(G, 1) < 2 THEN 4415
4390 IF M(G, 1) > 5 THEN 4415
4395 LET D = M(G, 1)
4415 SUBEND
4820 REM ---- ck_cord: every const item, each after the constants its expression names (a depth-first
4825 REM order with an explicit stack in W(1..): pairs (const, next node to scan), so chains of any
4830 REM length need no Baysick recursion); each is typed and evaluated when its scan ends (sn_const).
4835 REM Y(S,6) 1 waiting (on the stack), 2 done; a name of a waiting const has no value (rs_name).
4845 SUB "ck_cord": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H(), Q(), G$()
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
4920 CALL "lk": N(), Y(), W(), X(), X$(), S$(), N(J, 6), R
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
5005 CALL "sn_const": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), Q(), G$(), S
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
