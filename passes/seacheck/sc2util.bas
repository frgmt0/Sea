2635 REM ---- table layouts of seacheck ---------------------------------------------------------
2640 REM N(i,0) kind 1-49 (sc_read's list: 1 prog 2 const 3 struct 5 fn 6 param 7 type 8 let 9 var
2645 REM 10 pname 11 pskip 12 ptuple 13 asg 14 tasg 15 cstmt 16 if 17 while 18 for 21 break 22
2650 REM continue 23 return 24 block 25 int 26 float 27 str 28 true 29 false 30 name 32 neg 33 not
2655 REM 34 bin 35 call 37 ref 38 conv 39 index 41 range 49 ifx ...); rtype N(i,3) its T row + 1; N(i,1..3) u and enum fields (for: npos in
2660 REM N(i,1..2)); N(i,4) F*1E9+L; N(i,5) column; N(i,6) string; N(i,7) first child; N(i,8) next
2665 REM sibling; N(i,9) parent. A replacement record of sea.res (DESIGN 3.4.1; rpl) keeps the node
2670 REM kind of the record it replaces and puts its new fields in slots that record leaves free:
2675 REM rfn M(i,1) rty (a T row), M(i,2) fid, its parameter types in M(param,1); rst N(i,2) sid;
2680 REM rcn* N(i,1) t, N(i,2) cid, N(i,3) outcome 1 rcni 2 rcnf 3 rcnb 4 rcne 5 rcn 6 rcns, M(i,1..2) the
2685 REM value's limbs as two 32-bit halves (rcnb: M(i,1) the bool; rcns: its S$ index; rcne: M(i,1..2) epos, M(i,4)
2690 REM 1 ovf 2 div0); rpname N(i,1) lid; rfor N(i,3) lid; rint N(i,1..2) fv as two halves, N(i,3)
2695 REM 1 if fv is not -; rname N(i,1) k (1 loc 2 cst 3 fn 4 st 5 pd 6 none), N(i,2) ref; rpowk
2700 REM N(i,1) 6 (pow), N(i,2) k, N(i,3) 1.
2705 REM M(i,0) first node of the subtree (post-order range M(i,0)..i); M(i,1) type: -1 untyped
2710 REM integer constant, 0 error, 1 void, 2 bool, 3 i64, 4 f64, 5 str, 6-9 handles, >= 10 a T row;
2715 REM M(i,2) symbol (Y row, -p predeclared slot p, 0 none; pname, param, for: the local bound);
2720 REM M(i,3) errors recorded before the node was checked; M(i,4) pname: var rule f64 (1), return:
2725 REM tret (1), tasg target: cv flag (1); M(i,5) C row of a literal; M(i,6) children; M(i,7) cvt
2730 REM to f64 after the node (1); M(i,8) bin: powk k + 10, < 0: writing jumps past node -M(i,8)
2735 REM (em_expr); M(i,9) the statement ends every path with a return (1); dollar: M(i,5) its dim.
2740 REM Y(s,0) 1 fn 2 const 3 struct 4 local; Y(s,1) name; Y(s,2) type (fn: result); Y(s,3) node;
2745 REM Y(s,4) local: 1 let 2 var 3 for 4 par 5 ref par, fn: elemental, const: 0 1 2 (checked);
2750 REM Y(s,5) lid / fid / cid / sid; Y(s,6) local: pname of a var-rule candidate, fn: np, const:
2755 REM ck_cord state; Y(s,7) fn: nr, const: value 0 not decided, 1 i64, 2 f64, 3 bool, 5 str, 6 none;
2760 REM Y(s,8) fn: last local row, const: C row of the value (bool: the value; str: its S$ index); Y(s,9) fn: first
2765 REM local row. Rows: 1 .main, 2..X(30) the entered fns by fid, then the constants by cid
2770 REM (X(31) the row before the first), the structs by sid, X(33) the last item row; a local of
2775 REM function S with lid l is row Y(S,9) - 1 + l (DESIGN 3.4.1: lids come from sea.res).
2780 REM T(t,0) 1 tvec 2 tmat 3 tfvec 4 tfmat 5 struct 6 record (sc9st) 7 ttuple 0 continuation; T(t,1) element or count, T(t,2..3)
2785 REM the extents n or r c of a fixed one; tuple components in the next rows, 9 per row (columns
2787 REM 0-8); T(t,9) the written id (DESIGN 3.5.1). From 4e also: M(i,4) of an array literal 2 (its
2788 REM elements were untyped integer constants: i64 until an f64 context retypes it, sc9arr rtf), of
2789 REM a node of such an element 3, of [] 5 (its type comes from its context, LANGUAGE 6.9); M(i,5) of
2790 REM an array-valued node the dyn/fix target (a T row), M(i,7) >= 10 an element-wise cvt (its type).
2791 REM W(1..) the tree stack of sc_read, then the stack of ck_cord; W(100001..149999) the names
2795 REM of the entered items (nmh); W(150000+id) the T row of rtup id; W(180001..) written types in id order (emission). X(1) nodes X(2) strings X(3) last
2800 REM symbol row X(4) last T row X(5) C rows X(6) key of the first error (0 none) X(7) its node
2805 REM (0: rerr, at X(36) X(37)) X(8) its argument count X(9) errors recorded X(10) capacity
2810 REM overflow X(11) row before the structs X(14) function X(15) loop depth X(16) var rule changed X(17) prog X(18) program
2815 REM file X(19) current node X(20)-X(25) LIM SYMBOLS TYPES CONSTS NODES STRINGS POWK X(27)
2820 REM emission mode X(28) types written X(29) top-level statements X(30) last fn row X(31) row
2825 REM before the constants X(26) a bad record (BAD_RECORD) X(32) last id of the type table of sea.res X(33) last item row X(34) FILE_VERSION X(35)
2830 REM LIM_DEC_FIELD X(36) X(37) the position of the rerr error X(38) types X(39) LIM_FIXED_ELEMS X(40) the
2831 REM lid before the first .t local of the function being written (em_fn; .t local k is lid X(40) + k)
2832 REM X(41) M(J,9) of the call J whose ref argument em_uarg is writing (erep), else 0 X(42) the row
2833 REM of the Sea function whose call ck_ucall is checking (ecv); C(r,0) 3 i64 4 f64,
2835 REM C(r,1..4) limbs; X$(1) error name, X$(2)-X$(4) its arguments, X$(10) predeclared names,
2840 REM X$(11) the target (header).
2845 REM ---- er: record error Q$ at node I (K arguments); the first in source order is kept ------
2850 SUB "er": N(), X(), X$(), I, Q$, A$, B$, C$, K
2855 LET X(9) = X(9) + 1
2860 IF X(10) = 1 THEN 2920
2865 LET Q = N(I, 4) * 10000 + N(I, 5)
2870 IF X(6) = 0 THEN 2880
2875 IF Q >= X(6) THEN 2920
2880 LET X(6) = Q
2885 LET X(7) = I
2890 LET X(36) = 0
2895 LET X(8) = K
2900 LET X$(1) = Q$
2905 LET X$(2) = A$
2910 LET X$(3) = B$
2915 LET X$(4) = C$
2920 SUBEND
2925 REM ---- fatal: a capacity limit of DESIGN 2.7 is exceeded at node I (wins over every error) ---
2930 SUB "fatal": N(), X(), X$(), I, W$
2935 IF X(10) = 1 THEN 2975
2940 LET X(10) = 1
2945 LET X(6) = 1
2950 LET X(7) = I
2955 LET X(36) = 0
2960 LET X(8) = 1
2965 LET X$(1) = "TOO_LARGE"
2970 LET X$(2) = W$
2975 SUBEND
2980 REM ---- intern: R = index of string Q$ in S$ (added if new; 0 if the table is full). G() (399989
2985 REM slots, at most half full) finds strings by a hash of the length and up to 32 bytes ----
2990 SUB "intern": S$(), X(), G(), Q$, R
2995 LET P9 = 399989
3000 LET L0 = LEN(Q$)
3005 LET V = L0 - P9 * INT(L0 / P9)
3010 LET S = 1
3015 IF L0 <= 32 THEN 3025
3020 LET S = INT(L0 / 32)
3025 FOR J = 1 TO L0 STEP S
3030 LET V = V * 263 + ASC(SEG$(Q$, J, J))
3035 LET V = V - P9 * INT(V / P9)
3040 NEXT J
3045 LET Q = V + 1
3050 LET R = G(Q)
3055 IF R = 0 THEN 3090
3060 IF LEN(S$(R)) <> L0 THEN 3070
3065 IF S$(R) = Q$ THEN 3125 ' equal lengths: = is exact
3070 LET Q = Q + 1
3075 IF Q <= P9 THEN 3050
3080 LET Q = 1
3085 GOTO 3050
3090 IF X(2) < X(24) THEN 3105
3095 LET R = 0
3100 GOTO 3125
3105 LET X(2) = X(2) + 1
3110 LET R = X(2)
3115 LET S$(R) = Q$
3120 LET G(Q) = R
3125 SUBEND
3130 REM ---- pdx: R = slot of predeclared name Q$ (1-4 constants, 5-8 handles, 9- functions) -----
3135 SUB "pdx": X$(), Q$, R
3140 LET R = 0
3145 IF LEN(Q$) > 10 THEN 3170
3150 IF LEN(Q$) = 0 THEN 3170
3155 LET P = POS(X$(10), "|" & Q$ & " ")
3160 IF P = 0 THEN 3170
3165 LET R = (P - 1) / 12 + 1
3170 SUBEND
3175 REM ---- nloc: R = the local with lid L of the current function X(14) (its row, DESIGN 3.4.1),
3180 REM named Q, type D, mut U, declared by node I; Z = 1 checks the binding (shadowing a
3185 REM predeclared name, LANGUAGE 3.3) --------------------------------------------------------
3190 SUB "nloc": N(), Y(), T(), X(), X$(), S$(), Q, D, U, I, Z, L, R
3195 LET R = Y(X(14), 9) - 1 + L
3200 FOR J = 0 TO 9
3205 LET Y(R, J) = 0
3210 NEXT J
3215 LET Y(R, 0) = 4
3220 LET Y(R, 1) = Q
3225 LET Y(R, 2) = D
3230 LET Y(R, 3) = I
3235 LET Y(R, 4) = U
3240 LET Y(R, 5) = L
3245 IF Z = 0 THEN 3280
3250 CALL "pdx": X$(), S$(Q), P
3255 IF P = 0 THEN 3280
3260 CALL "er": N(), X(), X$(), I, "SHADOWS_PREDECLARED", "", "", "", 0
3280 SUBEND
3285 REM ---- tyn: R$ = type Q written as in Sea source (DESIGN 2.6.2) -----------------------------
3290 SUB "tyn": T(), Q, R$
3295 IF Q < 10 THEN 3385
3300 IF T(Q, 0) = 1 THEN 3355
3305 IF T(Q, 0) = 2 THEN 3370
3307 IF T(Q, 0) < 5 THEN 3381
3308 IF T(Q, 0) < 7 THEN 3352
3310 LET R$ = "("
3315 FOR J = 1 TO T(Q, 1)
3320 CALL "tyn": T(), T(Q + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)), A$
3325 IF J = 1 THEN 3335
3330 LET R$ = R$ & ", "
3335 LET R$ = R$ & A$
3340 NEXT J
3345 LET R$ = R$ & ")"
3350 GOTO 3440
3352 CALL "tynst": T(), Q, R$
3353 GOTO 3440
3355 CALL "tyn": T(), T(Q, 1), A$
3360 LET R$ = A$ & "[]"
3365 GOTO 3440
3370 CALL "tyn": T(), T(Q, 1), A$
3375 LET R$ = A$ & "[,]"
3380 GOTO 3440
3381 REM a fixed-size array: T[n], T[r,c] (no spaces inside the brackets, DESIGN 2.6.2)
3382 CALL "tyn": T(), T(Q, 1), A$
3383 LET R$ = A$ & "[" & STR$(T(Q, 2)) & SEG$("," & STR$(T(Q, 3)), 1, 99 * (T(Q, 0) - 3)) & "]"
3384 GOTO 3440
3385 LET A$ = "?|void|bool|i64|f64|str|Figure|Axes|Lu|Chol|"
3390 LET S = 1
3395 LET Q1 = Q
3400 IF Q1 >= 0 THEN 3410
3405 LET Q1 = 3
3410 FOR J = 0 TO Q1
3415 LET P = POS(A$, "|", S)
3420 IF J = Q1 THEN 3430
3425 LET S = P + 1
3430 NEXT J
3435 LET R$ = SEG$(A$, S, P - 1)
3440 SUBEND
3445 REM ---- tnew: R = the first of K new cleared T rows for one new type. LIM_TYPES counts types
3450 REM (X(38)), not rows; the rows of T always suffice (sc_lim: 2 per type and one more per 9
3455 REM tuple components, which are type nodes) ------------------------------------------------
3460 SUB "tnew": T(), N(), X(), X$(), K, R
3465 IF X(38) < X(21) THEN 3485
3470 CALL "fatal": N(), X(), X$(), X(19), "types"
3475 LET R = 0
3480 GOTO 3525
3485 LET X(38) = X(38) + 1
3490 LET R = X(4) + 1
3495 LET X(4) = X(4) + K
3500 FOR J = R TO X(4)
3505 FOR H = 0 TO 9
3510 LET T(J, H) = 0
3515 NEXT H
3520 NEXT J
3525 SUBEND
3530 REM ---- tarr: R = the array type K (1 E[], 2 E[,], 3 E[A], 4 E[A,B]) of element E, one id per
3532 REM structure (DESIGN 3.5.1); a dynamic type ignores A and B --------------------------------
3535 SUB "tarr": T(), N(), X(), X$(), K, E, A, B, R
3540 LET R = 10
3545 IF R > X(4) THEN 3570
3550 IF T(R, 0) <> K THEN 3560
3552 IF T(R, 1) <> E THEN 3560
3554 IF K < 3 THEN 3590
3556 IF T(R, 2) <> A THEN 3560
3557 IF K = 3 THEN 3590
3558 IF T(R, 3) = B THEN 3590
3560 CALL "tnext": T(), R
3565 GOTO 3545
3570 CALL "tnew": T(), N(), X(), X$(), 1, R
3575 IF R = 0 THEN 3590
3580 LET T(R, 0) = K
3585 LET T(R, 1) = E
3586 IF K < 3 THEN 3590
3587 LET T(R, 2) = A
3588 LET T(R, 3) = B
3590 SUBEND
3595 REM ---- elt: E = the element type of an array type Q and K its rank (1, 2; fixed-size too); a
3600 REM type that is no array is its own E, with K = 0 ------------------------------------------
3605 SUB "elt": T(), Q, E, K
3610 LET E = Q
3615 LET K = 0
3620 IF Q < 10 THEN 3640
3625 IF T(Q, 0) > 4 THEN 3640
3630 LET K = T(Q, 0) - 2 * INT((T(Q, 0) - 1) / 2)
3635 LET E = T(Q, 1)
3640 SUBEND
3645 REM ---- ttup: R = the tuple of the K types U(1..K) ---------------------------------------------
3650 SUB "ttup": T(), N(), X(), X$(), U(), K, R
3655 LET R = 10
3660 IF R > X(4) THEN 3705
3665 IF T(R, 0) <> 7 THEN 3695
3670 IF T(R, 1) <> K THEN 3695
3675 FOR J = 1 TO K
3680 IF T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) <> U(J) THEN 3695
3685 NEXT J
3690 GOTO 3740
3695 CALL "tnext": T(), R
3700 GOTO 3660
3705 CALL "tnew": T(), N(), X(), X$(), 1 + INT((K + 8) / 9), R
3710 IF R = 0 THEN 3740
3715 LET T(R, 0) = 7
3720 LET T(R, 1) = K
3725 FOR J = 1 TO K
3730 LET T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)) = U(J)
3735 NEXT J
3740 SUBEND
3745 REM ---- stl: an untyped constant subtree I takes type D (f64, else i64); every literal that
3750 REM becomes f64 must be exact (integer constant not exact in f64, LANGUAGE 4.2): rint fv
3755 SUB "stl": N(), M(), C(), X(), X$(), I, D
3760 IF M(I, 1) <> -1 THEN 3820
3765 LET D1 = D
3770 IF D1 = 4 THEN 3780
3775 LET D1 = 3
3780 FOR J = M(I, 0) TO I
3785 IF M(J, 1) <> -1 THEN 3815
3790 LET M(J, 1) = D1
3795 IF D1 <> 4 THEN 3815
3800 IF N(J, 0) <> 25 THEN 3815
3805 IF N(J, 3) = 1 THEN 3815
3810 CALL "er": N(), X(), X$(), J, "NOT_EXACT_F64", "", "", "", 0
3815 NEXT J
3820 SUBEND
3825 REM ---- vu: R = the type of I used as one value; a multiple-result or void call is an error --
3830 SUB "vu": N(), M(), T(), X(), X$(), I, R
3835 LET R = M(I, 1)
3840 IF R < 10 THEN 3865
3845 IF T(R, 0) <> 7 THEN 3880
3850 CALL "er": N(), X(), X$(), I, "MULTI_VALUE", "", "", "", 0
3855 LET R = 0
3860 GOTO 3880
3865 IF R <> 1 THEN 3880
3870 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", "0", "1", "", 2
3875 LET R = 0
3880 SUBEND
3885 REM ---- cv: the value I stored into type D (initialisation, assignment, argument, return;
3890 REM LANGUAGE 4.2, 4.5, 6.9): a [] takes D (eset); untyped constants take D's element type (an
3892 REM untyped literal becomes f64 under an f64 element type, rtf); i64 -> f64 is a cvt, element by
3894 REM element for arrays; then a fixed-size array stored as the dynamic type is a dyn, the reverse a
3896 REM fix, two fixed shapes that differ are 217 (afit); anything else a type mismatch ----------
3900 SUB "cv": N(), M(), T(), C(), X(), X$(), I, D
3902 IF M(I, 4) <> 5 THEN 3905
3903 CALL "eset": N(), M(), T(), X(), X$(), I, D
3904 GOTO 4025
3905 CALL "vu": N(), M(), T(), X(), X$(), I, T1
3910 IF T1 = 0 THEN 4025
3915 IF D = 0 THEN 4025
3920 CALL "elt": T(), D, E, K
3925 IF T1 <> -1 THEN 3940
3930 REM an untyped constant where f64 or an f64 array is expected is f64 (LANGUAGE 4.2 (b))
3935 CALL "stl": N(), M(), C(), X(), X$(), I, E
3937 LET T1 = M(I, 1)
3940 IF M(I, 4) <> 2 THEN 3945
3941 IF E <> 4 THEN 3945
3942 CALL "rtf": N(), M(), T(), X(), X$(), I
3943 LET T1 = M(I, 1)
3945 IF T1 = D THEN 4025
3950 IF T1 <> 3 THEN 3970
3955 IF D <> 4 THEN 4010
3960 LET M(I, 7) = 1
3965 GOTO 4025
3970 REM arrays of one rank: equal elements, or i64 to f64 by an element-wise cvt (LANGUAGE 4.2 (c))
3975 IF K = 0 THEN 4010
3980 CALL "elt": T(), T1, E1, K1
3985 IF K1 <> K THEN 4010
3990 IF E1 = E THEN 4000
3992 IF E1 <> 3 THEN 4010
3994 IF E <> 4 THEN 4010
3996 CALL "trel": T(), N(), X(), X$(), T1, 4, Q
3998 LET M(I, 7) = Q
3999 LET T1 = Q
4000 CALL "afit": N(), M(), T(), X(), X$(), I, T1, D
4005 GOTO 4025
4010 CALL "tyn": T(), D, A$
4015 CALL "tyn": T(), T1, B$
4020 CALL "er": N(), X(), X$(), I, "TYPE_MISMATCH", A$, B$, "", 2
4025 SUBEND
4030 REM ---- cand: an f64 is stored into local R: a var-rule candidate becomes f64 (Decision 8) ----
4035 SUB "cand": M(), Y(), X(), R
4040 IF R <= 0 THEN 4065
4045 IF Y(R, 6) = 0 THEN 4065
4050 IF M(Y(R, 6), 4) = 1 THEN 4065
4055 LET M(Y(R, 6), 4) = 1
4060 LET X(16) = 1
4065 SUBEND
4070 REM ---- resc: R$ = the bytes S$ written back as a string literal's source text (LANGUAGE 3.5):
4075 REM \" \\ \n \t \r \0, other control bytes \xHH, every other byte itself (DESIGN 2.6.2) ----
4080 SUB "resc": S$, R$
4085 DIM B(4100)
4090 LET R$ = ""
4095 LET L0 = LEN(S$)
4100 IF L0 = 0 THEN 4235
4105 CHANGE S$ TO B
4110 FOR J = 1 TO L0
4115 LET C1 = B(J)
4120 IF C1 = 34 THEN 4170
4125 IF C1 = 92 THEN 4170
4130 IF C1 = 10 THEN 4180
4135 IF C1 = 9 THEN 4190
4140 IF C1 = 13 THEN 4200
4145 IF C1 = 0 THEN 4210
4150 IF C1 < 32 THEN 4220
4155 IF C1 = 127 THEN 4220
4160 LET R$ = R$ & SEG$(S$, J, J)
4165 GOTO 4230
4170 LET R$ = R$ & "\" & SEG$(S$, J, J)
4175 GOTO 4230
4180 LET R$ = R$ & "\n"
4185 GOTO 4230
4190 LET R$ = R$ & "\t"
4195 GOTO 4230
4200 LET R$ = R$ & "\r"
4205 GOTO 4230
4210 LET R$ = R$ & "\0"
4215 GOTO 4230
4220 LET H = INT(C1 / 16)
4225 LET R$ = R$ & "\x" & SEG$("0123456789ABCDEF", H + 1, H + 1) & SEG$("0123456789ABCDEF", C1 - 16 * H + 1, C1 - 16 * H + 1)
4230 NEXT J
4235 SUBEND
4240 REM ---- kid: R = child J of node I ----------------------------------------------------------
4245 SUB "kid": N(), I, J, R
4250 LET R = N(I, 7)
4255 FOR H = 2 TO J
4260 LET R = N(R, 8)
4265 NEXT H
4270 SUBEND
4275 REM ---- opn: R$ = binary operator O as written (LANGUAGE 6.1) --------------------------------
4280 SUB "opn": O, R$
4285 LET A$ = "+ - * / % ^ @ == != < <= > >= & | && || "
4290 LET S = 1
4295 FOR J = 1 TO O
4300 LET P = POS(A$, " ", S)
4305 IF J = O THEN 4315
4310 LET S = P + 1
4315 NEXT J
4320 LET R$ = SEG$(A$, S, P - 1)
4325 SUBEND
4330 REM ---- pos: R$ = position F:L:C of node I (DESIGN 3.1) ---------------------------------------
4335 SUB "pos": N(), I, R$
4340 LET F = INT(N(I, 4) / 1E9)
4345 LET R$ = STR$(F) & ":" & STR$(N(I, 4) - F * 1E9) & ":" & STR$(N(I, 5))
4350 SUBEND
4355 REM ---- cnew: R = the C row of value (K, L3..L0), K 3 i64 or 4 f64 in C(r,0): a value already
4360 REM held shares its row (LIM_CONSTS counts distinct values, DESIGN 2.7); 0 when the table is
4365 REM full. H() (39989 slots, at most half full) finds rows by a hash of the value. ----------
4370 SUB "cnew": C(), H(), X(), K, L3, L2, L1, L0, R
4375 LET P9 = 39989
4380 LET V = K * 7 + L3
4385 LET V = V * 65536 + L2
4390 LET V = V - P9 * INT(V / P9)
4395 LET V = V * 65536 + L1
4400 LET V = V - P9 * INT(V / P9)
4405 LET V = V * 65536 + L0
4410 LET V = V - P9 * INT(V / P9)
4415 LET Q = V + 1
4420 LET R = H(Q)
4425 IF R = 0 THEN 4475
4430 IF C(R, 0) <> K THEN 4455
4435 IF C(R, 1) <> L3 THEN 4455
4440 IF C(R, 2) <> L2 THEN 4455
4445 IF C(R, 3) <> L1 THEN 4455
4450 IF C(R, 4) = L0 THEN 4530
4455 LET Q = Q + 1
4460 IF Q <= P9 THEN 4420
4465 LET Q = 1
4470 GOTO 4420
4475 IF X(5) < X(22) THEN 4490
4480 LET R = 0
4485 GOTO 4530
4490 LET X(5) = X(5) + 1
4495 LET R = X(5)
4500 LET C(R, 0) = K
4505 LET C(R, 1) = L3
4510 LET C(R, 2) = L2
4515 LET C(R, 3) = L1
4520 LET C(R, 4) = L0
4525 LET H(Q) = R
4530 SUBEND
4535 REM ---- tnext: R = the T row of the type after the one at row R (a tuple has 1 + ceil(n/9)
4540 REM rows, a struct or record 1 + ceil(n/4): their continuation rows are skipped) ---------
4545 SUB "tnext": T(), R
4550 IF T(R, 0) = 7 THEN 4555
4552 IF ABS(T(R, 0) - 5.5) > 1 THEN 4560
4553 LET R = R + INT((T(R, 1) + 3) / 4)
4554 GOTO 4560
4555 LET R = R + INT((T(R, 1) + 8) / 9)
4560 LET R = R + 1
4565 SUBEND
4570 REM ---- lfmt: R$ = the i64 with limbs A3..A0 (two's complement, most significant first) in
4575 REM decimal (DESIGN 3.1: i fields as written by the passes; |v| >= 1E9 as hex, io_hex) ------
4580 SUB "lfmt": A3, A2, A1, A0, R$
4585 DIM L(4)
4590 LET L(1) = A3
4595 LET L(2) = A2
4600 LET L(3) = A1
4605 LET L(4) = A0
4610 LET G = 0
4615 IF A3 < 32768 THEN 4670
4620 REM negative: the magnitude is the two's complement
4625 LET G = 1
4630 LET C1 = 1
4635 FOR J = 4 TO 1 STEP -1
4640 LET L(J) = 65535 - L(J) + C1
4645 LET C1 = 0
4650 IF L(J) < 65536 THEN 4665
4655 LET L(J) = 0
4660 LET C1 = 1
4665 NEXT J
4670 IF L(1) + L(2) > 0 THEN 4705
4675 LET V = L(3) * 65536 + L(4)
4680 IF V >= 1E9 THEN 4705
4685 LET R$ = STR$(V)
4690 IF G = 0 THEN 4710
4695 LET R$ = "-" & R$
4700 GOTO 4710
4705 CALL "lhex": A3, A2, A1, A0, R$
4710 SUBEND
4715 REM ---- lhex: R$ = # and the 16 upper-case hex digits of limbs A3..A0 (io_hex) --------------
4720 SUB "lhex": A3, A2, A1, A0, R$
4725 DIM L(4)
4730 LET L(1) = A3
4735 LET L(2) = A2
4740 LET L(3) = A1
4745 LET L(4) = A0
4750 CALL "io_hex": L(), R$
4755 SUBEND
