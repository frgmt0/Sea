2340 REM ---- table layouts of seacheck ---------------------------------------------------------
2345 REM N(i,0) kind 1-49 (sc_read's list: 1 prog 2 const 3 struct 5 fn 6 param 7 type 8 let 9 var
2350 REM 10 pname 11 pskip 12 ptuple 13 asg 14 tasg 15 cstmt 16 if 17 while 18 for 21 break 22
2355 REM continue 23 return 24 block 25 int 26 float 27 str 28 true 29 false 30 name 32 neg 33 not
2360 REM 34 bin 35 call 37 ref 38 conv 41 range 49 ifx ...); N(i,1..3) u and enum fields (for: npos in
2365 REM N(i,1..2)); N(i,4) F*1E9+L; N(i,5) column; N(i,6) string; N(i,7) first child; N(i,8) next
2370 REM sibling; N(i,9) parent. A replacement record of sea.res (DESIGN 3.4.1; rpl) keeps the node
2375 REM kind of the record it replaces and puts its new fields in slots that record leaves free:
2380 REM rfn M(i,1) rty (a T row), M(i,2) fid, its parameter types in M(param,1); rst N(i,2) sid;
2385 REM rcn* N(i,1) t, N(i,2) cid, N(i,3) outcome 1 rcni 2 rcnf 3 rcnb 4 rcne 5 rcn, M(i,1..2) the
2390 REM value's limbs as two 32-bit halves (rcnb: M(i,1) the bool; rcne: M(i,1..2) epos, M(i,4)
2395 REM 1 ovf 2 div0); rpname N(i,1) lid; rfor N(i,3) lid; rint N(i,1..2) fv as two halves, N(i,3)
2400 REM 1 if fv is not -; rname N(i,1) k (1 loc 2 cst 3 fn 4 st 5 pd 6 none), N(i,2) ref; rpowk
2405 REM N(i,1) 6 (pow), N(i,2) k, N(i,3) 1.
2410 REM M(i,0) first node of the subtree (post-order range M(i,0)..i); M(i,1) type: -1 untyped
2415 REM integer constant, 0 error, 1 void, 2 bool, 3 i64, 4 f64, 5 str, 6-9 handles, >= 10 a T row;
2420 REM M(i,2) symbol (Y row, -p predeclared slot p, 0 none; pname, param, for: the local bound);
2425 REM M(i,3) errors recorded before the node was checked; M(i,4) pname: var rule f64 (1), return:
2430 REM tret (1), tasg target: cv flag (1); M(i,5) C row of a literal; M(i,6) children; M(i,7) cvt
2435 REM to f64 after the node (1); M(i,8) bin: powk k + 10, < 0: writing jumps past node -M(i,8)
2440 REM (em_expr); M(i,9) the statement ends every path with a return (1).
2445 REM Y(s,0) 1 fn 2 const 3 struct 4 local; Y(s,1) name; Y(s,2) type (fn: result); Y(s,3) node;
2450 REM Y(s,4) local: 1 let 2 var 3 for 4 par 5 ref par, fn: elemental, const: 0 1 2 (checked);
2455 REM Y(s,5) lid / fid / cid / sid; Y(s,6) local: pname of a var-rule candidate, fn: np, const:
2460 REM ck_cord state; Y(s,7) fn: nr, const: value 0 not decided, 1 i64, 2 f64, 3 bool, 6 none;
2465 REM Y(s,8) fn: last local row, const: C row of the value (bool: the value); Y(s,9) fn: first
2470 REM local row. Rows: 1 .main, 2..X(30) the entered fns by fid, then the constants by cid
2475 REM (X(31) the row before the first), the structs by sid, X(33) the last item row; a local of
2480 REM function S with lid l is row Y(S,9) - 1 + l (DESIGN 3.4.1: lids come from sea.res).
2485 REM T(t,0) 1 tvec 7 ttuple 0 continuation; T(t,1) element or count; tuple components in the
2490 REM next rows, 9 per row (columns 0-8); T(t,9) the written id (DESIGN 3.5.1).
2495 REM W(1..) the tree stack of sc_read, then the stack of ck_cord; W(100001..149999) the names
2500 REM of the entered items (nmh); W(150000+id) the T row of rtup id; W(180001..) written types in id order (emission). X(1) nodes X(2) strings X(3) last
2505 REM symbol row X(4) last T row X(5) C rows X(6) key of the first error (0 none) X(7) its node
2510 REM (0: rerr, at X(36) X(37)) X(8) its argument count X(9) errors recorded X(10) capacity
2515 REM overflow X(11) row before the structs X(14) function X(15) loop depth X(16) var rule changed X(17) prog X(18) program
2520 REM file X(19) current node X(20)-X(25) LIM SYMBOLS TYPES CONSTS NODES STRINGS POWK X(27)
2525 REM emission mode X(28) types written X(29) top-level statements X(30) last fn row X(31) row
2530 REM before the constants X(26) a bad record (BAD_RECORD) X(32) last rtup id X(33) last item row X(34) FILE_VERSION X(35)
2535 REM LIM_DEC_FIELD X(36) X(37) the position of the rerr error X(38) types; C(r,0) 3 i64 4 f64,
2540 REM C(r,1..4) limbs; X$(1) error name, X$(2)-X$(4) its arguments, X$(10) predeclared names,
2545 REM X$(11) the target (header).
2550 REM ---- er: record error Q$ at node I (K arguments); the first in source order is kept ------
2555 SUB "er": N(), X(), X$(), I, Q$, A$, B$, C$, K
2560 LET X(9) = X(9) + 1
2565 IF X(10) = 1 THEN 2625
2570 LET Q = N(I, 4) * 10000 + N(I, 5)
2575 IF X(6) = 0 THEN 2585
2580 IF Q >= X(6) THEN 2625
2585 LET X(6) = Q
2590 LET X(7) = I
2595 LET X(36) = 0
2600 LET X(8) = K
2605 LET X$(1) = Q$
2610 LET X$(2) = A$
2615 LET X$(3) = B$
2620 LET X$(4) = C$
2625 SUBEND
2630 REM ---- fatal: a capacity limit of DESIGN 2.7 is exceeded at node I (wins over every error) ---
2635 SUB "fatal": N(), X(), X$(), I, W$
2640 IF X(10) = 1 THEN 2680
2645 LET X(10) = 1
2650 LET X(6) = 1
2655 LET X(7) = I
2660 LET X(36) = 0
2665 LET X(8) = 1
2670 LET X$(1) = "TOO_LARGE"
2675 LET X$(2) = W$
2680 SUBEND
2685 REM ---- intern: R = index of string Q$ in S$ (added if new; 0 if the table is full). G() (399989
2690 REM slots, at most half full) finds strings by a hash of the length and up to 32 bytes ----
2695 SUB "intern": S$(), X(), G(), Q$, R
2700 LET P9 = 399989
2705 LET L0 = LEN(Q$)
2710 LET V = L0 - P9 * INT(L0 / P9)
2715 LET S = 1
2720 IF L0 <= 32 THEN 2730
2725 LET S = INT(L0 / 32)
2730 FOR J = 1 TO L0 STEP S
2735 LET V = V * 263 + ASC(SEG$(Q$, J, J))
2740 LET V = V - P9 * INT(V / P9)
2745 NEXT J
2750 LET Q = V + 1
2755 LET R = G(Q)
2760 IF R = 0 THEN 2795
2765 IF LEN(S$(R)) <> L0 THEN 2775
2770 IF S$(R) = Q$ THEN 2830 ' equal lengths: = is exact
2775 LET Q = Q + 1
2780 IF Q <= P9 THEN 2755
2785 LET Q = 1
2790 GOTO 2755
2795 IF X(2) < X(24) THEN 2810
2800 LET R = 0
2805 GOTO 2830
2810 LET X(2) = X(2) + 1
2815 LET R = X(2)
2820 LET S$(R) = Q$
2825 LET G(Q) = R
2830 SUBEND
2835 REM ---- pdx: R = slot of predeclared name Q$ (1-4 constants, 5-8 handles, 9- functions) -----
2840 SUB "pdx": X$(), Q$, R
2845 LET R = 0
2850 IF LEN(Q$) > 10 THEN 2875
2855 IF LEN(Q$) = 0 THEN 2875
2860 LET P = POS(X$(10), "|" & Q$ & " ")
2865 IF P = 0 THEN 2875
2870 LET R = (P - 1) / 12 + 1
2875 SUBEND
2880 REM ---- nloc: R = the local with lid L of the current function X(14) (its row, DESIGN 3.4.1),
2885 REM named Q, type D, mut U, declared by node I; Z = 1 checks the binding (shadowing a
2890 REM predeclared name, a str local: DESIGN 2.6.2) -------------------------------------------
2895 SUB "nloc": N(), Y(), X(), X$(), S$(), Q, D, U, I, Z, L, R
2900 LET R = Y(X(14), 9) - 1 + L
2905 FOR J = 0 TO 9
2910 LET Y(R, J) = 0
2915 NEXT J
2920 LET Y(R, 0) = 4
2925 LET Y(R, 1) = Q
2930 LET Y(R, 2) = D
2935 LET Y(R, 3) = I
2940 LET Y(R, 4) = U
2945 LET Y(R, 5) = L
2950 IF Z = 0 THEN 2980
2955 CALL "pdx": X$(), S$(Q), P
2960 IF P = 0 THEN 2970
2965 CALL "er": N(), X(), X$(), I, "SHADOWS_PREDECLARED", "", "", "", 0
2970 IF D <> 5 THEN 2980
2975 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "strings", "", "", 1
2980 SUBEND
2985 REM ---- tyn: R$ = type Q written as in Sea source (DESIGN 2.6.2) -----------------------------
2990 SUB "tyn": T(), Q, R$
2995 IF Q < 10 THEN 3065
3000 IF T(Q, 0) = 1 THEN 3050
3005 LET R$ = "("
3010 FOR J = 1 TO T(Q, 1)
3015 CALL "tyn": T(), T(Q + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)), A$
3020 IF J = 1 THEN 3030
3025 LET R$ = R$ & ", "
3030 LET R$ = R$ & A$
3035 NEXT J
3040 LET R$ = R$ & ")"
3045 GOTO 3120
3050 CALL "tyn": T(), T(Q, 1), A$
3055 LET R$ = A$ & "[]"
3060 GOTO 3120
3065 LET A$ = "?|void|bool|i64|f64|str|Figure|Axes|Lu|Chol|"
3070 LET S = 1
3075 LET Q1 = Q
3080 IF Q1 >= 0 THEN 3090
3085 LET Q1 = 3
3090 FOR J = 0 TO Q1
3095 LET P = POS(A$, "|", S)
3100 IF J = Q1 THEN 3110
3105 LET S = P + 1
3110 NEXT J
3115 LET R$ = SEG$(A$, S, P - 1)
3120 SUBEND
3125 REM ---- tnew: R = the first of K new cleared T rows for one new type. LIM_TYPES counts types
3130 REM (X(38)), not rows; the rows of T always suffice (sc_lim: 2 per type and one more per 9
3135 REM tuple components, which are type nodes) ------------------------------------------------
3140 SUB "tnew": T(), N(), X(), X$(), K, R
3145 IF X(38) < X(21) THEN 3165
3150 CALL "fatal": N(), X(), X$(), X(19), "types"
3155 LET R = 0
3160 GOTO 3205
3165 LET X(38) = X(38) + 1
3170 LET R = X(4) + 1
3175 LET X(4) = X(4) + K
3180 FOR J = R TO X(4)
3185 FOR H = 0 TO 9
3190 LET T(J, H) = 0
3195 NEXT H
3200 NEXT J
3205 SUBEND
3210 REM ---- tvec: R = the type E[] (one id per structure, DESIGN 3.5.1) ---------------------------
3215 SUB "tvec": T(), N(), X(), X$(), E, R
3220 LET R = 10
3225 IF R > X(4) THEN 3250
3230 IF T(R, 0) <> 1 THEN 3240
3235 IF T(R, 1) = E THEN 3270
3240 CALL "tnext": T(), R
3245 GOTO 3225
3250 CALL "tnew": T(), N(), X(), X$(), 1, R
3255 IF R = 0 THEN 3270
3260 LET T(R, 0) = 1
3265 LET T(R, 1) = E
3270 SUBEND
3275 REM ---- ttup: R = the tuple of the K types U(1..K) ---------------------------------------------
3280 SUB "ttup": T(), N(), X(), X$(), U(), K, R
3285 LET R = 10
3290 IF R > X(4) THEN 3335
3295 IF T(R, 0) <> 7 THEN 3325
3300 IF T(R, 1) <> K THEN 3325
3305 FOR J = 1 TO K
3310 IF T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) <> U(J) THEN 3325
3315 NEXT J
3320 GOTO 3370
3325 CALL "tnext": T(), R
3330 GOTO 3290
3335 CALL "tnew": T(), N(), X(), X$(), 1 + INT((K + 8) / 9), R
3340 IF R = 0 THEN 3370
3345 LET T(R, 0) = 7
3350 LET T(R, 1) = K
3355 FOR J = 1 TO K
3360 LET T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) = U(J)
3365 NEXT J
3370 SUBEND
3375 REM ---- stl: an untyped constant subtree I takes type D (f64, else i64); every literal that
3380 REM becomes f64 must be exact (integer constant not exact in f64, LANGUAGE 4.2): rint fv
3385 SUB "stl": N(), M(), C(), X(), X$(), I, D
3390 IF M(I, 1) <> -1 THEN 3450
3395 LET D1 = D
3400 IF D1 = 4 THEN 3410
3405 LET D1 = 3
3410 FOR J = M(I, 0) TO I
3415 IF M(J, 1) <> -1 THEN 3445
3420 LET M(J, 1) = D1
3425 IF D1 <> 4 THEN 3445
3430 IF N(J, 0) <> 25 THEN 3445
3435 IF N(J, 3) = 1 THEN 3445
3440 CALL "er": N(), X(), X$(), J, "NOT_EXACT_F64", "", "", "", 0
3445 NEXT J
3450 SUBEND
3455 REM ---- vu: R = the type of I used as one value; a multiple-result or void call is an error --
3460 SUB "vu": N(), M(), T(), X(), X$(), I, R
3465 LET R = M(I, 1)
3470 IF R < 10 THEN 3495
3475 IF T(R, 0) <> 7 THEN 3510
3480 CALL "er": N(), X(), X$(), I, "MULTI_VALUE", "", "", "", 0
3485 LET R = 0
3490 GOTO 3510
3495 IF R <> 1 THEN 3510
3500 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", "0", "1", "", 2
3505 LET R = 0
3510 SUBEND
3515 REM ---- cv: the value I stored into type D (initialisation, assignment, argument, return):
3520 REM untyped constants take D, i64 -> f64 is a cvt, anything else a type mismatch -----------
3525 SUB "cv": N(), M(), T(), C(), X(), X$(), I, D
3530 CALL "vu": N(), M(), T(), X(), X$(), I, T1
3535 IF T1 = 0 THEN 3600
3540 IF D = 0 THEN 3600
3545 IF T1 <> -1 THEN 3560
3550 CALL "stl": N(), M(), C(), X(), X$(), I, D
3555 LET T1 = M(I, 1)
3560 IF T1 = D THEN 3600
3565 IF T1 <> 3 THEN 3585
3570 IF D <> 4 THEN 3585
3575 LET M(I, 7) = 1
3580 GOTO 3600
3585 CALL "tyn": T(), D, A$
3590 CALL "tyn": T(), T1, B$
3595 CALL "er": N(), X(), X$(), I, "TYPE_MISMATCH", A$, B$, "", 2
3600 SUBEND
3605 REM ---- cand: an f64 is stored into local R: a var-rule candidate becomes f64 (Decision 8) ----
3610 SUB "cand": M(), Y(), X(), R
3615 IF R <= 0 THEN 3640
3620 IF Y(R, 6) = 0 THEN 3640
3625 IF M(Y(R, 6), 4) = 1 THEN 3640
3630 LET M(Y(R, 6), 4) = 1
3635 LET X(16) = 1
3640 SUBEND
3645 REM ---- resc: R$ = the bytes S$ written back as a string literal's source text (LANGUAGE 3.5):
3650 REM \" \\ \n \t \r \0, other control bytes \xHH, every other byte itself (DESIGN 2.6.2) ----
3655 SUB "resc": S$, R$
3660 DIM B(4100)
3665 LET R$ = ""
3670 LET L0 = LEN(S$)
3675 IF L0 = 0 THEN 3810
3680 CHANGE S$ TO B
3685 FOR J = 1 TO L0
3690 LET C1 = B(J)
3695 IF C1 = 34 THEN 3745
3700 IF C1 = 92 THEN 3745
3705 IF C1 = 10 THEN 3755
3710 IF C1 = 9 THEN 3765
3715 IF C1 = 13 THEN 3775
3720 IF C1 = 0 THEN 3785
3725 IF C1 < 32 THEN 3795
3730 IF C1 = 127 THEN 3795
3735 LET R$ = R$ & SEG$(S$, J, J)
3740 GOTO 3805
3745 LET R$ = R$ & "\" & SEG$(S$, J, J)
3750 GOTO 3805
3755 LET R$ = R$ & "\n"
3760 GOTO 3805
3765 LET R$ = R$ & "\t"
3770 GOTO 3805
3775 LET R$ = R$ & "\r"
3780 GOTO 3805
3785 LET R$ = R$ & "\0"
3790 GOTO 3805
3795 LET H = INT(C1 / 16)
3800 LET R$ = R$ & "\x" & SEG$("0123456789ABCDEF", H + 1, H + 1) & SEG$("0123456789ABCDEF", C1 - 16 * H + 1, C1 - 16 * H + 1)
3805 NEXT J
3810 SUBEND
3815 REM ---- kid: R = child J of node I ----------------------------------------------------------
3820 SUB "kid": N(), I, J, R
3825 LET R = N(I, 7)
3830 FOR H = 2 TO J
3835 LET R = N(R, 8)
3840 NEXT H
3845 SUBEND
3850 REM ---- opn: R$ = binary operator O as written (LANGUAGE 6.1) --------------------------------
3855 SUB "opn": O, R$
3860 LET A$ = "+ - * / % ^ @ == != < <= > >= & | && || "
3865 LET S = 1
3870 FOR J = 1 TO O
3875 LET P = POS(A$, " ", S)
3880 IF J = O THEN 3890
3885 LET S = P + 1
3890 NEXT J
3895 LET R$ = SEG$(A$, S, P - 1)
3900 SUBEND
3905 REM ---- pos: R$ = position F:L:C of node I (DESIGN 3.1) ---------------------------------------
3910 SUB "pos": N(), I, R$
3915 LET F = INT(N(I, 4) / 1E9)
3920 LET R$ = STR$(F) & ":" & STR$(N(I, 4) - F * 1E9) & ":" & STR$(N(I, 5))
3925 SUBEND
3930 REM ---- cnew: R = the C row of value (K, L3..L0), K 3 i64 or 4 f64 in C(r,0): a value already
3935 REM held shares its row (LIM_CONSTS counts distinct values, DESIGN 2.7); 0 when the table is
3940 REM full. H() (39989 slots, at most half full) finds rows by a hash of the value. ----------
3945 SUB "cnew": C(), H(), X(), K, L3, L2, L1, L0, R
3950 LET P9 = 39989
3955 LET V = K * 7 + L3
3960 LET V = V * 65536 + L2
3965 LET V = V - P9 * INT(V / P9)
3970 LET V = V * 65536 + L1
3975 LET V = V - P9 * INT(V / P9)
3980 LET V = V * 65536 + L0
3985 LET V = V - P9 * INT(V / P9)
3990 LET Q = V + 1
3995 LET R = H(Q)
4000 IF R = 0 THEN 4050
4005 IF C(R, 0) <> K THEN 4030
4010 IF C(R, 1) <> L3 THEN 4030
4015 IF C(R, 2) <> L2 THEN 4030
4020 IF C(R, 3) <> L1 THEN 4030
4025 IF C(R, 4) = L0 THEN 4105
4030 LET Q = Q + 1
4035 IF Q <= P9 THEN 3995
4040 LET Q = 1
4045 GOTO 3995
4050 IF X(5) < X(22) THEN 4065
4055 LET R = 0
4060 GOTO 4105
4065 LET X(5) = X(5) + 1
4070 LET R = X(5)
4075 LET C(R, 0) = K
4080 LET C(R, 1) = L3
4085 LET C(R, 2) = L2
4090 LET C(R, 3) = L1
4095 LET C(R, 4) = L0
4100 LET H(Q) = R
4105 SUBEND
4110 REM ---- tnext: R = the T row of the type after the one at row R (a tuple has 1 + ceil(n/9)
4115 REM rows: its continuation rows are skipped) --------------------------------------------
4120 SUB "tnext": T(), R
4125 IF T(R, 0) <> 7 THEN 4135
4130 LET R = R + INT((T(R, 1) + 8) / 9)
4135 LET R = R + 1
4140 SUBEND
4145 REM ---- lfmt: R$ = the i64 with limbs A3..A0 (two's complement, most significant first) in
4150 REM decimal (DESIGN 3.1: i fields as written by the passes; |v| >= 1E9 as hex, io_hex) ------
4155 SUB "lfmt": A3, A2, A1, A0, R$
4160 DIM L(4)
4165 LET L(1) = A3
4170 LET L(2) = A2
4175 LET L(3) = A1
4180 LET L(4) = A0
4185 LET G = 0
4190 IF A3 < 32768 THEN 4245
4195 REM negative: the magnitude is the two's complement
4200 LET G = 1
4205 LET C1 = 1
4210 FOR J = 4 TO 1 STEP -1
4215 LET L(J) = 65535 - L(J) + C1
4220 LET C1 = 0
4225 IF L(J) < 65536 THEN 4240
4230 LET L(J) = 0
4235 LET C1 = 1
4240 NEXT J
4245 IF L(1) + L(2) > 0 THEN 4280
4250 LET V = L(3) * 65536 + L(4)
4255 IF V >= 1E9 THEN 4280
4260 LET R$ = STR$(V)
4265 IF G = 0 THEN 4285
4270 LET R$ = "-" & R$
4275 GOTO 4285
4280 CALL "lhex": A3, A2, A1, A0, R$
4285 SUBEND
4290 REM ---- lhex: R$ = # and the 16 upper-case hex digits of limbs A3..A0 (io_hex) --------------
4295 SUB "lhex": A3, A2, A1, A0, R$
4300 DIM L(4)
4305 LET L(1) = A3
4310 LET L(2) = A2
4315 LET L(3) = A1
4320 LET L(4) = A0
4325 CALL "io_hex": L(), R$
4330 SUBEND
