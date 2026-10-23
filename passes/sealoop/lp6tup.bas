30000 REM ====================================================================================
30002 REM sealoop part 6 (lines 30000-34999): L12, tuple assignment through .l locals (DESIGN
30004 REM 3.5.9 L12, Decision 37). The tasg X (P its position) becomes block P m: tbind P n of new
30006 REM .l locals L1 ... Ln (- for a skip), then for each target that is not a skip in order the
30008 REM store of lv Li, converted by its cv (1 cvt f64, 2 dyn, 4 fix), as any asg: L6 for a
30010 REM selection or .flat target, L7 for the cvt of an array, L10 for dyn and fix. D(i,0) holds
30012 REM Li (a row of U, 0 for a skip). Variables: W3 W4 W6 W8 W9 T8, the predicate O1-O5.
30014 REM ====================================================================================
30095 REM ==== L12: the tasg X, first child X1 ======================================================
30100 LET R2 = H(X, 6)
30102 GOSUB 8400
30104 LET F9 = 3
30106 GOSUB 8440
30108 LET W9 = VAL(F9$)
30110 REM the call: the last child; the targets' rows are cut off (put back for their stores)
30112 LET W6 = X1
30114 IF H(W6, 4) = 0 THEN 30120
30116 LET W6 = H(W6, 4)
30118 GOTO 30114
30120 LET Y6 = H(W6, 2)
30122 LET G8 = H(W6, 0)
30124 LET O(H(X, 0), 0) = O(G8, 0)
30126 LET O(G8, 0) = 0
30128 GOSUB 9115
30130 LET C9 = O9
30132 REM (1) tbind P n of the new locals, the block's first statement
30134 LET Y9$ = "tbind " & P9$ & " " & STR$(W9)
30136 LET W8 = X1
30138 FOR W4 = 1 TO W9
30140 LET D(W4, 0) = 0
30142 IF H(W8, 1) <> 18 THEN 30148
30144 LET Y9$ = Y9$ & " -"
30146 GOTO 30158
30148 GOSUB 30950
30150 LET U2 = 0
30152 GOSUB 8100
30154 LET D(W4, 0) = U0
30156 LET Y9$ = Y9$ & " @" & STR$(U0)
30158 LET W8 = H(W8, 4)
30160 NEXT W4
30162 LET Z$ = Y9$
30164 GOSUB 8050
30166 LET M(Z0, 1) = M(Z0, 1) + 1
30168 REM (2) each target that is not a skip: its rows back at the tail, then its store
30170 LET W8 = X1
30172 FOR W4 = 1 TO W9
30174 IF D(W4, 0) > 0 THEN 30180
30176 LET N7 = N7 - 1
30178 GOTO 30204
30180 LET R7 = R1
30182 LET R2 = H(X, 6)
30184 GOSUB 8400
30186 LET F9 = 3 + W4
30188 GOSUB 8440
30190 LET P6 = O9
30192 LET O(O9, 0) = H(W8, 7)
30194 LET O9 = H(W8, 8)
30196 LET O(O9, 0) = 0
30198 LET X3 = W8
30200 LET W3 = D(W4, 0)
30201 LET W6 = VAL(F9$)
30202 GOSUB 30300
30204 LET W8 = H(W8, 4)
30206 NEXT W4
30208 LET K8 = 0
30210 LET S$ = "}"
30212 GOSUB 9000
30214 LET N7 = N7 - 1
30216 GOTO 5180
30295 REM ---- 30300: the store to target X3 (its rows at the tail, P6 the row before them) of the
30296 REM local W3 (script name T) converted by cv W6, written at P9$; W6 becomes the value's type
30300 LET C9 = O9
30302 LET C7 = 0
30304 IF H(X3, 1) <> 39 THEN 30310
30306 LET Y5 = X3
30308 GOSUB 15030
30310 LET T8 = H(X3, 2)
30312 LET V(20) = W3
30314 LET K8 = 0
30316 LET S$ = "L T"
30318 IF W6 = 0 THEN 30330
30320 LET S$ = "L T,cvt P 4"
30322 IF U(W3, 1) <= 9 THEN 30328
30324 IF W6 - 2 * INT(W6 / 2) = 1 THEN 30400
30326 IF W6 = 2 THEN 30440
30327 GOTO 30460
30328 LET W6 = 4
30329 GOTO 30332
30330 LET W6 = U(W3, 1)
30332 IF C7 = 2 THEN 30340
30334 LET S$ = S$ & ",asg P set"
30336 GOTO 9000
30340 GOSUB 9000
30342 LET V6 = W6
30344 LET V5 = 0
30346 LET O6$ = "set"
30348 GOTO 16100
30395 REM ---- the cvt of an array: L7 into the target's type (with a fix: tmp A, its shape check first)
30400 GOSUB 9115
30402 LET T6 = T8
30404 IF W6 < 4 THEN 30416
30406 LET Y7 = T8
30408 GOSUB 8700
30412 GOSUB 20580
30413 LET S$ = "L T,= A," & S$
30414 GOSUB 9000
30415 LET V(20) = V(1)
30416 LET K8 = 1
30418 LET S$ = "L T,= a"
30420 GOSUB 9000
30422 LET N4 = 1
30424 LET T6 = T8
30426 LET Z6$ = "cvt " & P9$ & " 4"
30428 GOSUB 20150
30430 LET S$ = "L Q,]"
30432 LET W6 = T8
30434 GOTO 30332
30435 REM ---- dyn (L10) of the fixed-size local (tmp S) into the dynamic target type
30440 GOSUB 9115
30442 LET Y7 = U(W3, 1)
30444 GOSUB 8700
30446 LET V(53) = T8
30450 LET S$ = "L T,= S,X S 0,= R,L R,anew P %0 0 1,= A"
30452 IF R5 = 1 THEN 30456
30454 LET S$ = "L T,= S,X S 0,= R,X S 1,= C,L R,L C,anew P %0 0 2,= A"
30456 LET S$ = S$ & ",D A,= D,C " & STR$(B5) & ",= K,L D,D S,L K,mcpy P,L A,]"
30458 GOTO 30432
30459 REM ---- fix (L10) of the dynamic local (tmp A) into the fixed-size target type, its shape checked
30460 GOSUB 9115
30462 LET T6 = T8
30464 LET Y7 = T8
30466 GOSUB 8700
30468 LET V(53) = T8
30472 GOSUB 20580
30474 LET S$ = "L T,= A," & S$ & ",anew P %0 0 0,= V,D A,= D,C " & STR$(B5) & ",= K,D V,L D,L K,mcpy P,L V,]"
30476 GOTO 30432
30885 REM ---- 30890: Y8 = 1 if the tasg O5 (X5 its last child) is rewritten by L11 or L12
30890 GOSUB 5750
30892 IF Y8 = 0 THEN 30900
30894 RETURN
30895 REM ---- 30900: Y8 = 1 if L12 rewrites the tasg O5: a target an L6 store target (an idx with a
30896 REM range, :, index vector or mask index, or a view base), a cv with bit 2 or 4, or bit 1 of an
30897 REM array target (variables O1-O4; R2 kept)
30900 LET Y8 = 0
30902 LET O4 = R2
30904 LET R2 = H(O5, 6)
30906 LET O1 = H(O5, 3)
30908 LET O2 = 0
30910 IF H(O1, 4) = 0 THEN 30940
30912 LET O2 = O2 + 1
30914 LET F9 = 3 + O2
30916 GOSUB 8440
30918 IF VAL(F9$) >= 2 THEN 30938
30920 IF VAL(F9$) = 0 THEN 30924
30922 IF H(O1, 2) > 9 THEN 30938
30924 IF H(O1, 1) <> 39 THEN 30936
30926 LET O3 = H(O1, 3)
30928 IF H(O3, 1) = 45 THEN 30938
30930 LET O3 = H(O3, 4)
30931 IF O3 = 0 THEN 30936
30932 IF H(O3, 1) = 16 THEN 30938
30933 IF H(O3, 1) = 46 THEN 30938
30934 IF H(O3, 2) <= 9 THEN 30930
30935 GOTO 30938
30936 LET O1 = H(O1, 4)
30937 GOTO 30910
30938 LET Y8 = 1
30940 LET R2 = O4
30942 RETURN
30945 REM ---- 30950: U1 = the type of result W4 of the call of tuple type Y6 (its ttuple record)
30950 LET U1 = T(Y6, 2 + W4)
30952 IF W4 <= 2 THEN 30968
30954 LET R2 = 0
30956 LET R2 = R2 + 1
30957 IF R2 > D0 THEN 2900
30958 IF SEG$(D$(R2), 1, 7) <> "ttuple " THEN 30956
30960 LET F9 = 2
30962 GOSUB 8440
30963 IF VAL(F9$) <> Y6 THEN 30956
30964 LET F9 = 3 + W4
30965 GOSUB 8440
30966 LET U1 = VAL(F9$)
30968 RETURN
