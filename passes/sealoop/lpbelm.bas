55000 REM ====================================================================================
55001 REM sealoop part 11 (lines 55000-59999): L19, the elemental application (DESIGN 2.11.4;
55002 REM Decision 84, L-ck), with the 6c parts of the reader (inst) and of L20 (emap, kind elem).
55003 REM L20 (lpainl) writes an emap P T iid n (instance I of the elem function F) as emap P T iid
55004 REM n+1 with the children tmp P A1 ... tmp P An (step (1)) and the inline xblk of the element
55005 REM call: for each parameter i a placeholder lv P pi Ai (pi its type) under tmp P Ei, the copy
55006 REM of F's body, iblk, xblk. The walk rewrites it: at the emap (k = 1, a value) into an xblk;
55007 REM at the tbind, tasg, tret or eval holding it (or a seq holding it, whose binds become
55008 REM statements) into L11's statement forms. Each argument of an elemental parameter with an
55009 REM array type is an operand of L7's slots (a its A, b its placeholder, which becomes the
55010 REM element eld x K); 20150's steps (2)-(6) run with A3 = 1, (3) (5) (6) here (55900 55920
55011 REM 55940). D(j,1) the home of result j (0: discarded), D(j,0) its data; I8 the emap, I9 its
55012 REM inline xblk, I7 the seq or 0, L6 the holder's kind (0 none), L5 k, U3 the kept results,
55013 REM J0 n, F4 R4 the broadcast's fixed and rank, G4 L0 its static extents (rows, cols).
55014 REM Script names: U a result's home, V its data, f an element result (V(21) V(22) V(32)).
55015 REM ---- the emap X: deferred to its holder statement, else the value of k = 1 -----------------
55016 IF A2 = 0 THEN 2900
55018 LET X5 = W(X)
55020 IF H(X5, 1) <> 19 THEN 55026
55022 IF H(X, 4) > 0 THEN 55026
55024 LET X5 = W(X5)
55026 IF POS("|21|22|24|31|", "|" & STR$(H(X5, 1)) & "|") > 0 THEN 5170
55028 LET I8 = X
55030 LET I7 = 0
55032 LET L6 = 0
55034 GOTO 55200
55175 REM ---- a tbind, tasg, tret (5713) or eval (code 22) X whose value X5 is an emap or a seq of one;
55176 REM an eval of ind2sub with an array r goes to L-cl (56100) with every result discarded
55180 LET X5 = X1
55182 IF H(X5, 1) = 12 THEN 56100
55190 LET I7 = 0
55191 LET I8 = X5
55192 IF H(X5, 1) <> 19 THEN 55198
55193 LET I7 = X5
55194 LET I8 = H(X5, 3)
55195 IF H(I8, 4) = 0 THEN 55198
55196 LET I8 = H(I8, 4)
55197 GOTO 55195
55198 IF H(I8, 1) <> 64 THEN 5714
55199 LET L6 = K
55200 REM ---- L19: P, n, k and the result types (Y6 the emap's type) ---------------------------------
55201 LET A7 = 0
55202 LET R2 = H(I8, 6)
55204 GOSUB 8400
55206 LET R7 = R2
55208 LET I9 = H(I8, 3)
55210 LET J0 = 0
55212 IF H(I9, 4) = 0 THEN 55218
55214 LET J0 = J0 + 1
55215 LET I9 = H(I9, 4)
55216 GOTO 55212
55218 IF H(I9, 1) <> 60 THEN 2900
55220 LET Y6 = H(I8, 2)
55222 LET L5 = 0
55224 IF Y6 = 1 THEN 55238
55226 LET L5 = 1
55228 IF Y6 <= 9 THEN 2900
55230 IF T(Y6, 1) > 0 THEN 55238
55232 LET T4 = Y6
55234 GOSUB 51770
55235 LET F9 = 3
55236 GOSUB 8440
55237 LET L5 = VAL(F9$)
55238 IF L5 > 64 THEN 2900
55240 IF L6 > 0 THEN 55244
55242 IF L5 <> 1 THEN 2900
55243 REM the kept results: none under an eval, not a - of a tbind nor a skip of a tasg
55244 LET U3 = 0
55246 LET X3 = H(X, 3)
55248 FOR W4 = 1 TO L5
55250 LET D(W4, 1) = 0
55252 IF L6 = 22 THEN 55268
55254 IF L6 <> 24 THEN 55257
55255 IF H(X3, 1) = 18 THEN 55266
55256 GOTO 55263
55257 IF L6 <> 21 THEN 55263
55258 LET R2 = H(X, 6)
55260 LET F9 = 3 + W4
55261 GOSUB 8440
55262 IF F9$ = "-" THEN 55268
55263 LET D(W4, 1) = 1
55264 LET U3 = U3 + 1
55265 IF L6 <> 24 THEN 55268
55266 LET X3 = H(X3, 4)
55268 NEXT W4
55269 IF A7 = 1 THEN 56150
55270 LET N4 = 0
55272 LET F4 = 1
55274 LET G4 = 1
55276 LET L0 = 1
55278 LET X3 = H(I8, 3)
55280 LET X4 = H(I9, 3)
55282 FOR W4 = 1 TO J0
55284 IF H(X4, 1) <> 59 THEN 2900
55286 LET X2 = H(X4, 3)
55288 IF H(X2, 1) <> 5 THEN 2900
55290 LET Y7 = H(H(X3, 3), 2)
55292 GOSUB 8700
55294 IF R5 = 0 THEN 55318
55296 IF H(X2, 2) > 9 THEN 55318
55298 IF E5 <> H(X2, 2) THEN 2900
55300 LET N4 = N4 + 1
55302 IF N4 > 63 THEN 2900
55304 LET Q0 = 100 + 25 * N4
55306 LET Z1$ = O$(H(X3, 8))
55308 LET V(Q0 + 1) = VAL(SEG$(Z1$, POS(Z1$, "@") + 1, LEN(Z1$)))
55310 LET V(Q0 + 2) = X2
55312 LET R4 = R5
55313 LET F4 = F4 * F5
55314 IF T(Y7, 0) < 2 THEN 55316
55315 LET G4 = T(Y7, 0)
55316 IF T(Y7, 4) < 2 THEN 55318
55317 LET L0 = T(Y7, 4)
55318 LET X3 = H(X3, 4)
55319 LET X4 = H(X4, 4)
55320 NEXT W4
55322 IF N4 = 0 THEN 2900
55323 REM the block of the rewrite (an xblk, a block, or the statements in place of a tbind)
55324 GOSUB 9115
55326 LET M(Z0, 1) = J0
55328 IF I7 = 0 THEN 55344
55329 REM a seq's binds become statements: its record row is dropped
55330 LET X5 = H(I7, 8)
55332 LET O(H(I9, 8), 0) = O(X5, 0)
55334 IF O9 <> X5 THEN 55338
55336 LET O9 = H(I9, 8)
55338 LET N7 = N7 - 1
55340 LET R2 = H(I7, 6)
55341 LET F9 = 4
55342 GOSUB 8440
55343 LET M(Z0, 1) = M(Z0, 1) + VAL(F9$)
55344 IF L6 <> 24 THEN 55355
55345 REM a tasg: its targets' rows are cut off, put back for the stores (G7 the first)
55346 LET X5 = I8
55348 IF I7 = 0 THEN 55351
55350 LET X5 = I7
55351 LET G7 = O(H(X, 0), 0)
55352 LET G8 = H(X5, 0)
55353 LET O(H(X, 0), 0) = O(G8, 0)
55354 LET O(G8, 0) = 0
55355 IF A7 = 1 THEN 56200
55356 LET C9 = H(I9, 0)
55358 LET T6 = 0
55360 LET A3 = 1
55362 GOSUB 20155
55364 LET A3 = 0
55365 IF A7 = 1 THEN 56250
55366 FOR K8 = 1 TO N4
55368 LET Q0 = 100 + 25 * K8
55370 LET R3 = H(V(Q0 + 2), 7)
55372 LET C9 = H(I9, 0)
55374 IF O(C9, 0) = R3 THEN 55380
55376 LET C9 = O(C9, 0)
55378 GOTO 55374
55380 LET S$ = "L x,L K,eld P %e %u 0"
55382 IF R4 = 1 THEN 55386
55384 LET S$ = "L x,L K,L s,wbin P 3 mul,L L,L j,wbin P 3 mul,wbin P 3 add,eld P %e %u 0"
55386 GOSUB 9000
55388 LET O(C9, 0) = O(R3, 0)
55390 LET N7 = N7 - 1
55392 NEXT K8
55393 REM after the inline call: eval (nothing kept), est (k = 1) or L12's tbind and the ests
55394 LET C9 = H(I9, 8)
55396 LET K8 = 0
55398 LET S$ = "eval P"
55400 IF U3 = 0 THEN 55458
55402 IF L5 > 1 THEN 55416
55404 LET V(22) = D(1, 0)
55406 LET S$ = ""
55408 LET U1 = Y6
55410 GOSUB 55980
55412 GOTO 55458
55414 REM k >= 2: block { tbind P k of new .l locals Ej (- discarded), the est of each kept Ej }
55416 GOSUB 9115
55418 LET Y9$ = "tbind " & P9$ & " " & STR$(L5)
55420 LET U7 = U0 + 1
55422 FOR W4 = 1 TO L5
55424 IF D(W4, 1) > 0 THEN 55428
55426 LET Y9$ = Y9$ & " -"
55427 GOTO 55436
55428 GOSUB 55990
55430 LET U1 = T(U1, 2)
55432 LET U2 = 0
55433 GOSUB 8100
55434 LET Y9$ = Y9$ & " @" & STR$(U0)
55436 NEXT W4
55438 LET Z$ = Y9$
55440 GOSUB 8050
55442 LET M(Z0, 1) = M(Z0, 1) + 1
55444 FOR W4 = 1 TO L5
55446 IF D(W4, 1) = 0 THEN 55455
55448 LET V(32) = U7
55449 LET U7 = U7 + 1
55450 LET V(22) = D(W4, 0)
55451 GOSUB 55990
55452 LET S$ = "L f,"
55453 GOSUB 55980
55454 GOSUB 9000
55455 NEXT W4
55456 LET S$ = "}"
55458 GOSUB 9000
55460 LET S$ = ")"
55462 IF R4 = 1 THEN 55466
55464 LET S$ = "),)"
55466 GOSUB 9000
55468 IF L6 > 0 THEN 55478
55469 REM (5) k = 1: the value lv R1, the xblk closed
55470 LET V(21) = D(1, 1)
55472 LET S$ = "L U,]"
55474 GOSUB 9000
55476 GOTO 55536
55477 REM (5) a tbind: its kept locals bound from the Rj, in place (the block's n grows)
55478 IF L6 <> 21 THEN 55500
55480 FOR W4 = 1 TO L5
55482 IF D(W4, 1) = 0 THEN 55496
55484 LET V(21) = D(W4, 1)
55486 LET S$ = "L U"
55488 GOSUB 9000
55490 LET R2 = H(X, 6)
55491 LET F9 = 3 + W4
55492 GOSUB 8440
55493 LET Z$ = "bind " & P9$ & " " & F9$
55494 GOSUB 8050
55496 NEXT W4
55497 LET H(W(X), 5) = H(W(X), 5) + M(Z0, 1) - 1
55498 LET Z0 = Z0 - 1
55499 GOTO 55536
55500 IF L6 <> 31 THEN 55514
55501 REM a tret: ret P k of the Rj; an eval: nothing kept; then the block closed
55502 FOR W4 = 1 TO L5
55504 LET V(21) = D(W4, 1)
55506 LET S$ = "L U"
55508 GOSUB 9000
55510 NEXT W4
55511 LET Z$ = "ret " & P9$ & " " & STR$(L5)
55512 GOSUB 8050
55514 IF L6 <> 24 THEN 55532
55515 REM a tasg: each target's rows back at the tail, then its store of Rj by its cv (rule 15 (j))
55516 LET X3 = H(X, 3)
55517 LET W4 = 1
55518 LET P4 = O(H(X3, 8), 0)
55519 IF H(X3, 1) <> 18 THEN 55522
55520 LET N7 = N7 - 1
55521 GOTO 55528
55522 LET P6 = O9
55523 LET O(O9, 0) = G7
55524 LET O9 = H(X3, 8)
55525 LET O(O9, 0) = 0
55526 LET W3 = D(W4, 1)
55527 GOSUB 55995
55528 LET G7 = P4
55529 LET X3 = H(X3, 4)
55530 LET W4 = W4 + 1
55531 IF H(X3, 4) > 0 THEN 55518
55532 LET K8 = 0
55533 LET S$ = "}"
55534 GOSUB 9000
55536 LET N7 = N7 - 1
55538 GOTO 5180
55595 REM ==== L20 and L19 in the stream (lpainl) ====================================================
55596 REM ---- 55600: the emap X: H(X,5) the row of its inst (the same ty and n, n = np of F, F of
55597 REM kind elem); each argument of the instance's type, of an elemental parameter (bool, i64,
55598 REM f64) that type or an array of it, of a uniform one exactly its type; at least one argument
55599 REM of an elemental parameter is an array (J9)
55600 LET R2 = H(X, 6)
55602 LET F9 = 4
55604 GOSUB 8440
55606 LET Z1$ = "inst " & F9$ & " "
55608 LET R2 = 0
55610 LET R2 = R2 + 1
55612 IF R2 > D0 THEN 2900
55614 IF SEG$(D$(R2), 1, LEN(Z1$)) <> Z1$ THEN 55610
55616 LET H(X, 5) = R2
55618 LET F9 = 3
55620 GOSUB 8440
55622 LET Y1 = VAL(F9$)
55624 IF Y1 > G0 THEN 2900
55626 LET F9 = 4
55628 GOSUB 8440
55630 LET Z1$ = F9$
55632 LET F9 = 5
55634 GOSUB 8440
55636 LET Z2$ = F9$
55638 LET R2 = H(X, 6)
55640 LET F9 = 3
55642 GOSUB 8440
55644 IF F9$ <> Z1$ THEN 2900
55646 LET F9 = 5
55648 GOSUB 8440
55649 IF F9$ <> Z2$ THEN 2900
55651 IF VAL(F9$) <> G(Y1, 2) THEN 2900
55653 LET R2 = G(Y1, 6)
55654 LET F9 = 4
55655 GOSUB 8440
55656 IF F9$ <> "elem" THEN 2900
55658 LET J9 = 0
55659 LET X1 = H(X, 3)
55660 FOR Y4 = 1 TO G(Y1, 2)
55661 LET R2 = H(X, 5)
55662 LET F9 = 5 + Y4
55663 GOSUB 8440
55664 LET Y7 = H(X1, 2)
55665 IF VAL(F9$) <> Y7 THEN 2900
55666 LET N5 = A(G(Y1, 1) + Y4)
55667 IF Y7 = N5 THEN 55674
55668 IF N5 < 2 THEN 2900
55669 IF N5 > 4 THEN 2900
55670 IF Y7 <= 9 THEN 2900
55671 IF T(Y7, 1) = 0 THEN 2900
55672 IF T(Y7, 2) <> N5 THEN 2900
55673 LET J9 = 1
55674 LET X1 = H(X1, 4)
55675 NEXT Y4
55676 IF J9 = 0 THEN 2900
55677 GOTO 50114
55689 REM ---- 55690: an argument whose type is not its parameter's: only of an emap (checked above)
55690 IF H(X, 1) <> 64 THEN 2900
55692 GOTO 50433
55698 REM ---- 55700: after an emap's argument tmps, each parameter's placeholder lv P pi Ai (the
55699 REM argument's local) and its tmp P Ei (Ei a new .p of pi); F's parameters read as the Ei
55700 LET X1 = H(X, 3)
55702 FOR Y4 = 1 TO G(Y1, 2)
55704 LET Z$ = "lv " & A2$ & " " & STR$(A(G(Y1, 1) + Y4)) & " " & STR$(H(X1, 0))
55706 GOSUB 51950
55708 LET Z$ = "loc .p " & STR$(A(G(Y1, 1) + Y4)) & " let " & A2$
55710 GOSUB 51800
55712 LET Z$ = "tmp " & A2$ & " " & STR$(H6)
55714 GOSUB 51950
55716 LET H(X1, 0) = H6
55718 LET X1 = H(X1, 4)
55720 NEXT Y4
55722 GOTO 50454
55748 REM ---- 55750: after the inline xblk of an emap: emap P T iid n+1 (its value, the walk's L19)
55750 LET R2 = H(X, 6)
55752 LET F9 = 3
55754 GOSUB 8440
55756 LET Z1$ = F9$
55757 LET F9 = 4
55758 GOSUB 8440
55759 LET Z1$ = Z1$ & " " & F9$
55762 LET F9 = 5
55764 GOSUB 8440
55766 LET Z$ = "emap " & A2$ & " " & Z1$ & " " & STR$(VAL(F9$) + 1)
55768 GOSUB 51950
55770 GOTO 50233
55788 REM ---- 55790: the iblk and xblk of an emap's element call take F's result type
55790 LET R2 = G(Y1, 6)
55792 LET F9 = 5
55794 GOTO 50221
55866 REM ---- 55870 (reader): an inst record: before the functions, iids from 1 in order (A5 the last)
55870 IF G0 > 0 THEN 2900
55872 IF I(1) <> A5 + 1 THEN 2900
55874 LET A5 = I(1)
55876 GOTO 1290
55895 REM ==== 20150's steps under L19 (A3 = 1; else the script S$, as before) ==========================
55896 REM ---- 55900 (3): the home of each kept result (its type in %0), then of a fixed-size
55897 REM broadcast its extents: the first kept home's, or with none the static ones
55900 IF A3 = 0 THEN 9000
55902 LET U9 = 0
55904 FOR W4 = 1 TO L5
55906 IF D(W4, 1) = 0 THEN 55926
55908 GOSUB 55990
55910 LET V(53) = U1
55912 LET S$ = "anew P %0 0 0,= U"
55914 IF F4 = 1 THEN 55920
55916 LET S$ = "L G,anew P %0 0 1,= U"
55918 IF R4 = 1 THEN 55920
55919 LET S$ = "L R,L C,anew P %0 0 2,= U"
55920 GOSUB 9000
55922 LET D(W4, 1) = V(21)
55924 IF U9 > 0 THEN 55926
55925 LET U9 = W4
55926 NEXT W4
55928 IF F4 = 0 THEN 55946
55930 IF U9 = 0 THEN 55940
55932 LET V(21) = D(U9, 1)
55934 LET S$ = "X U 0,= G"
55936 IF R4 = 1 THEN 9000
55938 LET S$ = "X U 0,= R,X U 1,= C"
55939 GOTO 9000
55940 LET S$ = "C " & STR$(G4) & ",= G"
55942 IF R4 = 1 THEN 9000
55944 LET S$ = "C " & STR$(G4) & ",= R,C " & STR$(L0) & ",= C"
55945 GOTO 9000
55946 RETURN
55948 REM ---- 55950 (5): the data of each kept result (D(j,0))
55950 IF A3 = 0 THEN 9000
55952 FOR W4 = 1 TO L5
55954 IF D(W4, 1) = 0 THEN 55960
55956 LET V(21) = D(W4, 1)
55957 LET S$ = "D U,= V"
55958 GOSUB 9000
55959 LET D(W4, 0) = V(22)
55960 NEXT W4
55962 RETURN
55964 REM ---- 55966 (6): the nest opened; under L19 its body is written by the caller
55966 GOSUB 9000
55968 IF A3 = 0 THEN 20257
55970 RETURN
55978 REM ---- 55980: S$ (an element value's lv) & the store est P size 0 into V at the position (U1 the
55979 REM result's array type); 55990: U1 = the type of result W4 of the emap's type Y6
55980 LET Z1$ = "L V,L K,"
55982 IF R4 = 1 THEN 55985
55984 LET Z1$ = "L V,L K,L L,L R,wbin P 3 mul,wbin P 3 add,"
55985 LET S$ = S$ & Z1$ & "est P " & STR$(S(T(U1, 2))) & " 0"
55986 RETURN
55990 IF L5 > 1 THEN 30950
55992 LET U1 = Y6
55994 RETURN
55995 REM ---- 55995: the store of the result W4 (local W3) into the target X3 by its cv (30300)
55996 LET R2 = H(X, 6)
55997 LET F9 = 3 + W4
55998 GOSUB 8440
55999 LET W6 = VAL(F9$)
56000 GOTO 30300
56095 REM ==== L-cl: a tbind, tasg, tret or eval X of ind2sub(r, k) with an array r (5710; DESIGN 2.11.4):
56096 REM L19's steps (1)-(5) with A7 = 1, two results, the arguments tmp a of the slots 1 (r) and 2
56097 REM (k), and the element body block { tmp d = r's element, tmp g = k's, tmp f = bin mod g d,
56098 REM tmp h = lib idiv g d (rule 36's imodf, idivf), the est of f and of h when kept }; the lib row, copied by 5322, dropped
56100 IF H(H(X5, 3), 2) <= 9 THEN 5714
56101 IF T(H(H(X5, 3), 2), 1) = 0 THEN 5714
56102 LET R2 = H(X5, 6)
56103 LET F9 = 4
56104 GOSUB 8440
56105 IF F9$ <> "ind2sub" THEN 5714
56106 LET I8 = X5
56107 LET I7 = 0
56108 LET L6 = K
56109 LET A7 = 1
56110 GOSUB 8400
56111 LET R7 = R2
56112 LET Y6 = H(X5, 2)
56113 LET L5 = 2
56114 LET J0 = 0
56115 LET X4 = H(H(I8, 3), 4)
56116 LET O(H(X4, 8), 0) = O(H(I8, 8), 0)
56117 IF O9 <> H(I8, 8) THEN 56119
56118 LET O9 = H(X4, 8)
56119 LET N7 = N7 - 1
56120 GOTO 55244
56148 REM ---- the shape of the broadcast of r and k (55269)
56150 LET N4 = 2
56152 LET F4 = 1
56154 LET G4 = 1
56156 LET L0 = 1
56158 LET X4 = H(I8, 3)
56160 FOR W4 = 1 TO 2
56162 LET Y7 = H(X4, 2)
56164 GOSUB 8700
56166 IF R5 = 0 THEN 56176
56168 LET R4 = R5
56170 LET F4 = F4 * F5
56171 IF T(Y7, 0) < 2 THEN 56173
56172 LET G4 = T(Y7, 0)
56173 IF T(Y7, 4) < 2 THEN 56176
56174 LET L0 = T(Y7, 4)
56176 LET X4 = H(X4, 4)
56178 NEXT W4
56180 GOTO 55324
56198 REM ---- step (1): tmp a of r and of k, after each one's subtree (55355)
56200 LET X4 = H(I8, 3)
56202 FOR K8 = 1 TO 2
56204 LET S$ = "= a"
56206 GOSUB 8900
56208 LET X4 = H(X4, 4)
56210 NEXT K8
56212 GOTO 55358
56248 REM ---- the element body (55365)
56250 GOSUB 9115
56252 FOR K8 = 1 TO 2
56254 LET Q0 = 100 + 25 * K8
56256 LET S$ = "L a,= q"
56258 IF V(Q0 + 6) = 0 THEN 56266
56260 LET S$ = "L x,L K,eld P %e %u 0,= q"
56262 IF R4 = 1 THEN 56266
56264 LET S$ = "L x,L K,L s,wbin P 3 mul,L L,L j,wbin P 3 mul,wbin P 3 add,eld P %e %u 0,= q"
56266 GOSUB 9000
56268 NEXT K8
56270 LET V(30) = V(134)
56272 LET V(33) = V(159)
56274 LET K8 = 0
56276 LET S$ = "L g,L d,bin P 3 mod,= f,L g,L d,lib P 3 idiv 2,= h"
56278 GOSUB 9000
56280 FOR W4 = 1 TO 2
56282 IF D(W4, 1) = 0 THEN 56292
56284 LET V(22) = D(W4, 0)
56286 LET S$ = SEG$("L f,L h,", 4 * W4 - 3, 4 * W4)
56288 GOSUB 55990
56290 GOSUB 55980
56291 GOSUB 9000
56292 NEXT W4
56294 LET S$ = "}"
56296 GOTO 55458
