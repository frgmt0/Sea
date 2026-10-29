16500 REM ---- the array typing of sub-phase 4e (DESIGN 2.6.2 step 4e, 3.5.5 "Phase-4 notes"): shapes,
16505 REM broadcasting and the static shape errors, array literals and [], views, the implicit dyn and
16510 REM fix, selection stores and compound assignment of arrays, the elemental library calls --------
16515 REM ---- shp: the shape of type Q: E its element type, K its rank (0 for no array), F 1 when
16520 REM fixed-size, then A B its extents (n or r, c) ------------------------------------------------
16525 SUB "shp": T(), Q, E, K, F, A, B
16530 LET E = Q
16535 LET K = 0
16540 LET F = 0
16545 LET A = 0
16550 LET B = 0
16555 IF Q < 10 THEN 16600
16560 IF T(Q, 0) > 4 THEN 16600
16565 LET K = T(Q, 0) - 2 * INT((T(Q, 0) - 1) / 2)
16570 LET E = T(Q, 1)
16575 IF T(Q, 0) < 3 THEN 16600
16580 LET F = 1
16585 LET A = T(Q, 2)
16590 IF K = 1 THEN 16600
16595 LET B = T(Q, 3)
16600 SUBEND
16605 REM ---- sht: R$ = the shape of rank K with extents A, B as error texts write it: a vector N, a
16610 REM matrix RxC (DESIGN 2.6.2, args letter h) --------------------------------------------------
16615 SUB "sht": K, A, B, R$
16620 LET R$ = STR$(A)
16625 IF K = 1 THEN 16635
16630 LET R$ = R$ & "x" & STR$(B)
16635 SUBEND
16640 REM ---- trel: R = the type of the shape of Q with the element type E (E itself for a scalar Q) --
16645 SUB "trel": T(), N(), X(), X$(), Q, E, R
16650 CALL "shp": T(), Q, E0, K, F, A, B
16655 LET R = E
16660 IF K = 0 THEN 16670
16665 CALL "tarr": T(), N(), X(), X$(), K + 2 * F, E, A, B, R
16670 SUBEND
16675 REM ---- acv: argument or operand A is converted from i64 to f64 (LANGUAGE 4.2): a scalar cvt
16680 REM (M(A,7) 1), or element by element to the f64 array of its shape (M(A,7) that type) ------
16685 SUB "acv": N(), M(), T(), X(), X$(), A
16690 LET M(A, 7) = 1
16695 IF M(A, 1) < 10 THEN 16705
16700 CALL "trel": T(), N(), X(), X$(), M(A, 1), 4, M(A, 7)
16705 SUBEND
16710 REM ---- bcs: one operand of type Q joins the broadcast of LANGUAGE 6.3, combined left to right,
16715 REM scalars skipped (DESIGN 3.5.5 "Static shapes"): Z(1) the rank so far (0 none), Z(2) Z(3) the
16720 REM combined extents (-1 unknown), Z(4) 1 while every array operand is fixed-size. R = 1 a
16725 REM vector with a matrix, R = 2 a static shape mismatch: A$ the shape combined so far (an
16730 REM unknown extent written as the operand's), B$ the operand's ----------------------------------
16735 SUB "bcs": T(), Z(), Q, R, A$, B$
16740 LET R = 0
16745 CALL "shp": T(), Q, E, K, F, A, B
16750 IF K = 0 THEN 16925
16755 IF Z(1) > 0 THEN 16800
16760 REM the first array operand: its extents are known when it is fixed-size
16765 LET Z(1) = K
16770 LET Z(4) = F
16775 LET Z(2) = F * A + F - 1
16780 LET Z(3) = F * B + F - 1
16785 GOTO 16925
16800 IF K = Z(1) THEN 16815
16805 LET R = 1
16810 GOTO 16925
16815 IF F = 1 THEN 16850
16820 REM a dynamic operand keeps a known extent other than 1, every other one becomes unknown
16825 LET Z(4) = 0
16830 FOR D = 2 TO K + 1
16835 IF Z(D) <> 1 THEN 16845
16840 LET Z(D) = -1
16845 NEXT D
16847 GOTO 16925
16850 REM a fixed-size operand: the texts first, then each dimension against the combined extent
16855 LET V1 = Z(2)
16860 IF V1 >= 0 THEN 16870
16865 LET V1 = A
16870 LET V2 = Z(3)
16875 IF V2 >= 0 THEN 16885
16880 LET V2 = B
16885 CALL "sht": K, V1, V2, A$
16890 CALL "sht": K, A, B, B$
16895 LET V = A
16900 FOR D = 2 TO K + 1
16902 IF Z(D) >= 0 THEN 16910
16904 REM unknown: an extent other than 1 makes it known again
16906 IF V = 1 THEN 16922
16908 LET Z(D) = V
16909 GOTO 16922
16910 IF Z(D) = V THEN 16922
16912 IF K = 1 THEN 16920
16914 IF V = 1 THEN 16922
16916 IF Z(D) <> 1 THEN 16920
16918 LET Z(D) = V
16919 GOTO 16922
16920 LET R = 2
16922 LET V = B
16923 NEXT D
16925 SUBEND
16930 REM ---- bres: R = the result type of a broadcast Z (bcs) with element type E: E for scalars only,
16935 REM fixed-size exactly when every array operand is (LANGUAGE 6.3, DESIGN 3.5.5) ------------
16940 SUB "bres": T(), N(), X(), X$(), Z(), E, R
16945 LET R = E
16950 IF Z(1) = 0 THEN 16960
16955 CALL "tarr": T(), N(), X(), X$(), Z(1) + 2 * Z(4), E, Z(2), Z(3), R
16960 SUBEND
16965 REM ---- bop: binary element-wise operator J with operands A, B, at least one an array, whose
16970 REM element result type M(J,1) is decided: the broadcast shape (202, 217 at the operator), and
16975 REM every converted array operand converted element by element ------------------------------
16980 SUB "bop": N(), M(), T(), X(), X$(), J, A, B
16985 DIM Z(4)
16990 LET Z(1) = 0
16995 LET Z(4) = 1
17000 CALL "bcs": T(), Z(), M(A, 1), R, A$, B$
17005 CALL "bcs": T(), Z(), M(B, 1), R, A$, B$
17010 IF R = 0 THEN 17035
17015 LET M(J, 1) = 0
17020 IF R = 2 THEN 17030
17025 CALL "er": N(), X(), X$(), J, "VEC_MAT", "", "", "", 0
17027 GOTO 17060
17030 CALL "er": N(), X(), X$(), J, "SHAPE_MISMATCH_C", A$, B$, "", 2
17032 GOTO 17060
17035 CALL "bres": T(), N(), X(), X$(), Z(), M(J, 1), R
17040 LET M(J, 1) = R
17045 IF M(A, 7) <> 1 THEN 17052
17050 CALL "acv": N(), M(), T(), X(), X$(), A
17052 IF M(B, 7) <> 1 THEN 17060
17055 CALL "acv": N(), M(), T(), X(), X$(), B
17060 SUBEND
17065 REM ---- afit: the value I of type Q (rank and element type of D) stored as type D: a dyn or a fix
17070 REM (M(I,5) = D) where one is fixed-size and the other dynamic, 217 where both are fixed-size
17075 REM with other extents (the target's shape first, DESIGN 3.5.5) ---------------------------------
17080 SUB "afit": N(), M(), T(), X(), X$(), I, Q, D
17085 IF Q = D THEN 17125
17090 CALL "shp": T(), Q, E1, K1, F1, A1, B1
17095 CALL "shp": T(), D, E, K, F, A, B
17100 IF F1 + F = 0 THEN 17125
17105 IF F1 + F = 1 THEN 17120
17110 CALL "sht": K, A, B, A$
17112 CALL "sht": K, A1, B1, B$
17115 CALL "er": N(), X(), X$(), I, "SHAPE_MISMATCH_C", A$, B$, "", 2
17117 GOTO 17125
17120 LET M(I, 5) = D
17125 SUBEND
17130 REM ---- eset: [] at I takes the type D of its context (LANGUAGE 6.9): a vector or matrix type
17135 REM itself; a fixed-size type with elements is 217 (its shape vs 0 or 0x0); a scalar type gives
17140 REM no array type: 252 at the [] ---------------------------------------------------------------
17145 SUB "eset": N(), M(), T(), X(), X$(), I, D
17150 LET M(I, 4) = 0
17155 IF D = 0 THEN 17205
17160 CALL "shp": T(), D, E, K, F, A, B
17165 IF K > 0 THEN 17180
17170 CALL "er": N(), X(), X$(), I, "CANNOT_INFER", "", "", "", 0
17175 GOTO 17205
17180 IF F * A * (B + 2 - K) = 0 THEN 17200
17185 CALL "sht": K, A, B, A$
17190 CALL "sht": K, 0, 0, B$
17195 CALL "er": N(), X(), X$(), I, "SHAPE_MISMATCH_C", A$, B$, "", 2
17197 GOTO 17205
17200 LET M(I, 1) = D
17205 SUBEND
17210 REM ---- rtf: the array literal I whose elements were all untyped integer constants (M(I,4) 2)
17215 REM is in an f64 context (LANGUAGE 4.2 (b), (f)): its untyped nodes (M(j,4) 3) become f64, each
17220 REM literal exact in f64 (214), and its rows and nested literals the f64 arrays of their shapes -
17225 SUB "rtf": N(), M(), T(), X(), X$(), I
17230 FOR J = M(I, 0) TO I
17235 IF N(J, 0) = 44 THEN 17270
17240 IF N(J, 0) = 45 THEN 17270
17245 IF M(J, 4) <> 3 THEN 17285
17250 LET M(J, 4) = 0
17252 LET M(J, 1) = 4
17255 IF N(J, 0) <> 25 THEN 17285
17260 IF N(J, 3) = 1 THEN 17285
17265 CALL "er": N(), X(), X$(), J, "NOT_EXACT_F64", "", "", "", 0
17267 GOTO 17285
17270 LET M(J, 4) = 0
17275 IF M(J, 1) < 10 THEN 17285
17280 CALL "trel": T(), N(), X(), X$(), M(J, 1), 4, M(J, 1)
17285 NEXT J
17290 SUBEND
17295 REM ---- ectx: Z = 1 when the [] at J stands where LANGUAGE 6.9 gives it a type (Decision 36): the
17300 REM value of an annotated let/var of one name or _, of an assignment =, an argument of a value
17305 REM parameter of a user function, a return of the function's result count, an arm of an if
17310 REM expression (ck_ifx), a field of a struct literal (4g-2) -------------------------------------
17315 SUB "ectx": N(), M(), Y(), X(), J, Z
17320 LET Z = 0
17325 LET P = N(J, 9)
17330 LET K = N(P, 0)
17335 IF K = 8 THEN 17370
17340 IF K = 9 THEN 17370
17345 IF K = 13 THEN 17390
17350 IF K = 49 THEN 17400
17355 IF K = 23 THEN 17410
17360 IF K = 35 THEN 17440
17362 IF K = 48 THEN 17435
17365 GOTO 17525
17370 IF N(P, 1) <> 1 THEN 17525
17375 IF N(N(P, 7), 0) = 12 THEN 17525
17380 IF N(J, 8) <> 0 THEN 17525
17385 GOTO 17520
17390 IF N(P, 1) <> 1 THEN 17525
17395 IF N(P, 7) = J THEN 17525
17398 GOTO 17520
17400 IF N(P, 7) = J THEN 17525
17405 GOTO 17520
17410 LET R0 = Y(X(14), 7)
17415 LET H = N(P, 1)
17420 IF H <> R0 THEN 17525
17425 IF H > 0 THEN 17520
17430 GOTO 17525
17435 REM a field value of a struct literal (4g-2; not of a record literal)
17436 IF N(N(P, 9), 0) = 46 THEN 17520
17437 GOTO 17525
17440 REM an argument of a call: of a user function, with a value parameter in its place
17445 LET G = N(P, 7)
17450 IF G = J THEN 17525
17455 IF N(G, 0) <> 30 THEN 17525
17460 LET R = M(G, 2)
17465 IF R <= 0 THEN 17525
17470 IF Y(R, 0) <> 1 THEN 17525
17475 LET Q = N(Y(R, 3), 7)
17480 LET H = N(G, 8)
17485 FOR I = 1 TO Y(R, 6)
17490 IF H = J THEN 17510
17495 LET H = N(H, 8)
17500 LET Q = N(Q, 8)
17505 NEXT I
17507 GOTO 17525
17510 IF N(Q, 1) = 1 THEN 17525
17520 LET Z = 1
17525 SUBEND
17530 REM ---- ck_arr: array literal J (LANGUAGE 6.9, 4.5, Decision 20): the common element type of its
17535 REM elements (201 at the first that does not combine), str and struct elements always dynamic (S9);
17540 REM rows of scalars: T[n] / T[r,c] up to LIM_FIXED_ELEMS elements, else T[] / T[,] (219 for a
17545 REM ragged one); with an array element a concatenation (220, and 217 when every part is fixed);
17550 REM each row has the type of its horizontal join; elements of another element type are converted.
17555 REM [] waits for its context (M(J,4) 5) or is 252. Locals: G the element type (99 none, -1
17560 REM untyped), U9 untyped, C9 a concatenation, F9 every part fixed, W row, X element ---------
17565 SUB "ck_arr": N(), M(), Y(), T(), C(), X(), X$(), J
17570 LET R0 = N(J, 1)
17575 IF R0 > 0 THEN 17605
17580 CALL "ectx": N(), M(), Y(), X(), J, Z
17585 IF Z = 0 THEN 17595
17590 LET M(J, 4) = 5
17592 GOTO 18395
17595 CALL "er": N(), X(), X$(), J, "CANNOT_INFER", "", "", "", 0
17600 GOTO 18395
17605 REM pass 1: the element types
17610 LET G = 99
17615 LET C9 = 0
17620 LET S9 = 0
17625 LET Z9 = 0
17630 LET M9 = 0
17635 LET F9 = 1
17640 LET W = N(J, 7)
17645 FOR R = 1 TO R0
17650 LET X1 = N(W, 7)
17655 FOR H = 1 TO N(W, 1)
17660 CALL "vu": N(), M(), T(), X(), X$(), X1, V
17665 IF V <> 0 THEN 17675
17670 LET Z9 = 1
17672 GOTO 17760
17675 CALL "shp": T(), V, E, K, F, A, B
17680 IF K = 0 THEN 17695
17685 LET C9 = 1
17690 LET F9 = F9 * F
17695 IF E = 5 THEN 17700
17697 IF E < 10 THEN 17705
17700 LET S9 = 1
17705 IF G = 99 THEN 17758
17710 IF G = E THEN 17760
17715 IF E = -1 THEN 17740
17720 IF G = -1 THEN 17745
17725 IF G + E <> 7 THEN 17750
17730 IF G * E <> 12 THEN 17750
17735 LET G = 4
17737 GOTO 17760
17740 IF G = 3 THEN 17760
17742 IF G = 4 THEN 17760
17743 GOTO 17750
17745 IF E = 3 THEN 17758
17747 IF E = 4 THEN 17758
17750 IF M9 > 0 THEN 17760
17752 REM the first element that does not combine with those before it (expected: their type)
17753 LET M9 = X1
17754 CALL "tyn": T(), G, A$
17756 CALL "tyn": T(), E, B$
17757 GOTO 17760
17758 LET G = E
17760 LET X1 = N(X1, 8)
17765 NEXT H
17770 LET W = N(W, 8)
17775 NEXT R
17780 REM str, struct or record elements: a dynamic literal whatever its size (LANGUAGE 6.9, Decision 20)
17785 LET F9 = F9 * (1 - S9)
17795 IF M9 = 0 THEN 17810
17800 CALL "er": N(), X(), X$(), M9, "TYPE_MISMATCH", A$, B$, "", 2
17805 GOTO 18395
17810 IF Z9 = 1 THEN 18395
17815 REM pass 2: the untyped elements take the element type (all untyped: i64, marked for rtf), an
17820 REM i64 element or part of an f64 literal is converted
17825 LET U9 = 0
17830 IF G <> -1 THEN 17845
17835 LET G = 3
17840 LET U9 = 1
17845 LET W = N(J, 7)
17850 FOR R = 1 TO R0
17855 LET X1 = N(W, 7)
17860 FOR H = 1 TO N(W, 1)
17865 IF M(X1, 1) <> -1 THEN 17900
17870 IF U9 = 0 THEN 17890
17875 FOR Q = M(X1, 0) TO X1
17880 IF M(Q, 1) <> -1 THEN 17887
17885 LET M(Q, 4) = 3
17887 NEXT Q
17890 CALL "stl": N(), M(), C(), X(), X$(), X1, G
17895 GOTO 17935
17900 IF G <> 4 THEN 17935
17905 IF M(X1, 4) <> 2 THEN 17920
17910 CALL "rtf": N(), M(), T(), X(), X$(), X1
17915 GOTO 17935
17920 CALL "elt": T(), M(X1, 1), E, K
17925 IF E <> 3 THEN 17935
17930 CALL "acv": N(), M(), T(), X(), X$(), X1
17935 LET X1 = N(X1, 8)
17940 NEXT H
17945 LET W = N(W, 8)
17950 NEXT R
17955 IF C9 = 1 THEN 18050
17960 REM rows of scalars: every row of the first row's length
17965 LET W = N(J, 7)
17970 LET C0 = N(W, 1)
17975 FOR R = 1 TO R0
17980 IF N(W, 1) = C0 THEN 17995
17985 CALL "er": N(), X(), X$(), W, "RAGGED", "", "", "", 0
17990 GOTO 18395
17995 LET W = N(W, 8)
18000 NEXT R
18005 CALL "fxk": X(), 1, 1 - S9, C0, K
18010 CALL "tarr": T(), N(), X(), X$(), K, G, C0, 0, Q
18015 LET W = N(J, 7)
18020 FOR R = 1 TO R0
18025 LET M(W, 1) = Q
18030 LET W = N(W, 8)
18035 NEXT R
18040 IF R0 = 1 THEN 18385
18042 CALL "fxk": X(), 2, 1 - S9, R0 * C0, K
18045 CALL "tarr": T(), N(), X(), X$(), K, G, R0, C0, Q
18047 GOTO 18385
18050 REM a concatenation: each row's horizontal join, then the rows stacked (Rs x Cs so far); a
18055 REM vector row counts as 1 x n; the static checks only when every part is fixed-size
18060 LET W = N(J, 7)
18065 FOR R = 1 TO R0
18070 REM V8 a vector part, M8 a matrix part, L the length of a vector row, R1 x C1 the joined
18072 REM matrix row so far (a scalar is 1 x 1), Y8 the first part whose rows differ (217)
18075 LET V8 = 0
18080 LET M8 = 0
18085 LET L = 0
18090 LET P8 = 0
18095 LET Y8 = 0
18100 LET X1 = N(W, 7)
18105 FOR H = 1 TO N(W, 1)
18110 CALL "shp": T(), M(X1, 1), E, K, F, A, B
18115 IF K <> 1 THEN 18125
18120 LET V8 = 1
18122 LET L = L + A
18124 GOTO 18190
18125 IF K = 2 THEN 18140
18130 LET A = 1
18135 LET B = 1
18140 LET M8 = M8 + K / 2
18145 LET L = L + A * B
18150 IF P8 = 1 THEN 18160
18152 LET P8 = 1
18154 LET R1 = A
18156 LET C1 = 0
18158 GOTO 18185
18160 IF F9 = 0 THEN 18185
18165 IF A = R1 THEN 18185
18170 IF Y8 > 0 THEN 18185
18175 LET Y8 = X1
18180 CALL "sht": 2, R1, C1, A$
18182 CALL "sht": 2, A, B, B$
18185 LET C1 = C1 + B
18190 LET X1 = N(X1, 8)
18195 NEXT H
18200 IF V8 * M8 = 0 THEN 18212
18205 CALL "er": N(), X(), X$(), W, "USE_ROW_COL", "", "", "", 0
18210 GOTO 18395
18212 IF Y8 = 0 THEN 18215
18213 CALL "er": N(), X(), X$(), Y8, "SHAPE_MISMATCH_C", A$, B$, "", 2
18214 GOTO 18395
18215 IF M8 > 0 THEN 18250
18220 REM a vector row: T[L] when every part is fixed and L is at most LIM_FIXED_ELEMS
18225 CALL "fxk": X(), 1, F9, L, K
18230 CALL "tarr": T(), N(), X(), X$(), K, G, L, 0, Q
18235 LET R1 = 1
18240 LET C1 = L
18245 GOTO 18265
18250 CALL "fxk": X(), 2, F9, R1 * C1, K
18255 CALL "tarr": T(), N(), X(), X$(), K, G, R1, C1, Q
18265 LET M(W, 1) = Q
18270 IF R0 = 1 THEN 18385
18275 IF R > 1 THEN 18295
18280 LET R2 = R1
18285 LET C2 = C1
18290 GOTO 18330
18295 IF F9 = 0 THEN 18325
18300 IF C1 = C2 THEN 18325
18305 CALL "sht": 2, R2, C2, A$
18310 CALL "sht": 2, R1, C1, B$
18315 CALL "er": N(), X(), X$(), W, "SHAPE_MISMATCH_C", A$, B$, "", 2
18320 GOTO 18395
18325 LET R2 = R2 + R1
18330 LET W = N(W, 8)
18335 NEXT R
18340 IF R0 = 1 THEN 18385
18345 CALL "fxk": X(), 2, F9, R2 * C2, K
18350 CALL "tarr": T(), N(), X(), X$(), K, G, R2, C2, Q
18385 LET M(J, 1) = Q
18390 LET M(J, 4) = 2 * U9
18395 SUBEND
18400 REM ---- ck_dot: x.name (LANGUAGE 5.6): a view .T .flat .col .row of an array (fixed-size exactly
18405 REM when the operand is); 218 for .T of a vector, 257 for another rank or no array; any other
18410 REM name is a field or projection (ck_fld, 4g-2; N(J,1) the field, N(J,2) 1 a projection) -----
18415 SUB "ck_dot": N(), M(), T(), C(), S$(), X(), X$(), J
18420 LET Q$ = S$(N(J, 6))
18422 LET N(J, 1) = 0
18423 LET N(J, 2) = 0
18425 LET V = 0
18430 IF LEN(Q$) > 4 THEN 18440
18435 LET V = POS("|T|flat|col|row|", "|" & Q$ & "|")
18440 IF V > 0 THEN 18455
18445 CALL "ck_fld": N(), M(), T(), C(), S$(), X(), X$(), J
18450 GOTO 18565
18455 LET A0 = N(J, 7)
18460 CALL "vu": N(), M(), T(), X(), X$(), A0, D
18465 IF D = 0 THEN 18565
18470 CALL "fin": N(), M(), C(), X(), X$(), A0
18475 LET D = M(A0, 1)
18480 CALL "shp": T(), D, E, K, F, A, B
18485 IF K = 0 THEN 18555
18490 REM V: 1 T, 3 flat, 8 col, 12 row (places in the word list)
18495 IF V > 1 THEN 18515
18500 IF K = 2 THEN 18510
18505 CALL "er": N(), X(), X$(), J, "NO_TRANSPOSE", "", "", "", 0
18507 GOTO 18565
18510 CALL "tarr": T(), N(), X(), X$(), 2 + 2 * F, E, B, A, R
18512 GOTO 18560
18515 IF V > 3 THEN 18530
18520 IF K = 1 THEN 18555
18525 CALL "tarr": T(), N(), X(), X$(), 1 + 2 * F, E, A * B, 0, R
18527 GOTO 18560
18530 IF K = 2 THEN 18555
18535 IF V > 8 THEN 18550
18540 CALL "tarr": T(), N(), X(), X$(), 2 + 2 * F, E, A, 1, R
18545 GOTO 18560
18550 CALL "tarr": T(), N(), X(), X$(), 2 + 2 * F, E, 1, A, R
18552 GOTO 18560
18555 CALL "tyn": T(), D, A$
18557 CALL "er": N(), X(), X$(), J, "VIEW_RANK", Q$, A$, "", 2
18558 GOTO 18565
18560 LET M(J, 1) = R
18565 SUBEND
18570 REM ---- csel: the value I of a selection store x[sel] = e (LANGUAGE 5.5), D the selection's type:
18575 REM a scalar converts to the element type; an array of the selection's rank keeps its shape (no
18580 REM dyn or fix, DESIGN 3.5.5), its elements converted from i64 to f64; [] takes D ------------
18585 SUB "csel": N(), M(), T(), C(), X(), X$(), I, D
18590 CALL "vu": N(), M(), T(), X(), X$(), I, V
18595 CALL "elt": T(), D, E, K
18600 IF M(I, 4) <> 5 THEN 18605
18602 CALL "cv": N(), M(), T(), C(), X(), X$(), I, D
18603 GOTO 18670
18605 CALL "elt": T(), V, E1, K1
18610 IF K1 > 0 THEN 18625
18615 CALL "cv": N(), M(), T(), C(), X(), X$(), I, E
18620 GOTO 18670
18625 IF K1 <> K THEN 18660
18630 IF M(I, 4) <> 2 THEN 18645
18635 IF E <> 4 THEN 18645
18640 CALL "rtf": N(), M(), T(), X(), X$(), I
18642 LET E1 = 4
18645 IF E1 = E THEN 18670
18650 IF E1 <> 3 THEN 18660
18652 IF E <> 4 THEN 18660
18655 CALL "acv": N(), M(), T(), X(), X$(), I
18657 GOTO 18670
18660 CALL "tyn": T(), D, A$
18662 CALL "tyn": T(), M(I, 1), B$
18665 CALL "er": N(), X(), X$(), I, "TYPE_MISMATCH", A$, B$, "", 2
18670 SUBEND
18675 REM ---- aop: x op= e with an array target or value (LANGUAGE 5.5, 6.3, rule 15 (i)): D the
18680 REM target's type (a selection's is dynamic), V the value's, O the operator. The element types
18685 REM suit the operator (checked by ck_asg); the broadcast of the target with the value (202, 217
18690 REM at the assignment); its element type must be the target's; a fixed-size whole target keeps
18695 REM its shape (217 at the value, the target's shape first) ---------------------------------------
18700 SUB "aop": N(), M(), T(), C(), X(), X$(), I, E, D, V, O
18705 DIM Z(4)
18710 CALL "elt": T(), D, D1, K1
18715 IF V <> -1 THEN 18730
18720 CALL "stl": N(), M(), C(), X(), X$(), E, D1
18725 LET V = M(E, 1)
18730 CALL "elt": T(), V, V1, K2
18735 IF K1 > 0 THEN 18755
18740 CALL "tyn": T(), D, A$
18745 CALL "tyn": T(), V, B$
18750 GOTO 18840
18755 LET Z(1) = 0
18760 LET Z(4) = 1
18765 CALL "bcs": T(), Z(), D, R, A$, B$
18770 CALL "bcs": T(), Z(), V, R, A$, B$
18775 IF R = 0 THEN 18800
18780 IF R = 2 THEN 18792
18785 CALL "er": N(), X(), X$(), I, "VEC_MAT", "", "", "", 0
18790 GOTO 18850
18792 CALL "er": N(), X(), X$(), I, "SHAPE_MISMATCH_C", A$, B$, "", 2
18795 GOTO 18850
18800 REM the result's element type: f64 for / and beside an f64, str for += of str, else i64 (LANGUAGE 6.5)
18805 LET Z0 = 3 + 2 * INT(D1 / 5)
18810 IF O = 5 THEN 18820
18812 IF D1 = 4 THEN 18820
18815 IF V1 <> 4 THEN 18825
18820 LET Z0 = 4
18825 CALL "bres": T(), N(), X(), X$(), Z(), Z0, Q
18830 IF Z0 = D1 THEN 18855
18832 CALL "tyn": T(), D, A$
18835 CALL "tyn": T(), Q, B$
18840 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
18850 GOTO 18890
18855 IF V1 <> 3 THEN 18865
18860 IF Z0 <> 4 THEN 18865
18862 CALL "acv": N(), M(), T(), X(), X$(), E
18865 IF Q = D THEN 18890
18870 CALL "shp": T(), Q, E1, K, F1, A1, B1
18875 CALL "shp": T(), D, E1, K, F, A, B
18880 IF F1 * F = 0 THEN 18890
18882 CALL "sht": K, A, B, A$
18884 CALL "sht": K, A1, B1, B$
18886 CALL "er": N(), X(), X$(), E, "SHAPE_MISMATCH_C", A$, B$, "", 2
18890 SUBEND
18895 REM ---- tcv: component G of a tuple assignment (DESIGN 3.5.5 "Implicit dyn and fix", Decision 37):
18897 REM the result of type D stored into the target of type D0 by the rules of asg set, when either
18899 REM is an array (Z = 1, else Z = 0 and nothing is done; one rank, or a scalar into a selection
18900 REM target, of the target's element type or i64 into f64): the cv of the tasg row in M(G,4) (1 i64 to
18901 REM f64, 2 dyn, 4 fix; a selection target adds no 2 or 4), 217 at G when both are fixed-size with
18903 REM other extents (the target's shape first), 201 at G when there is no conversion -------------
18905 SUB "tcv": N(), M(), T(), X(), X$(), G, D, D0, Z
18906 LET Z = 0
18907 CALL "shp": T(), D, E, K, F, A, B
18908 CALL "shp": T(), D0, E0, K0, F0, A0, B0
18909 IF K + K0 = 0 THEN 18945
18910 LET Z = 1
18911 IF K = K0 THEN 18913
18912 IF K * 100 + N(G, 0) <> 39 THEN 18940
18913 LET C = 0
18914 IF E = E0 THEN 18919
18915 IF E <> 3 THEN 18940
18916 IF E0 <> 4 THEN 18940
18917 LET C = 1
18919 REM a selection target: its shape is checked against the selection at run time (rule 21)
18920 IF N(G, 0) = 39 THEN 18930
18921 IF F + F0 = 0 THEN 18930
18922 IF F + F0 = 1 THEN 18928
18923 REM both fixed-size: the same extents, else 217
18924 IF A <> A0 THEN 18934
18925 IF B <> B0 THEN 18934
18926 GOTO 18930
18928 LET C = C + 2 + 2 * F0
18930 LET M(G, 4) = C
18932 GOTO 18945
18934 CALL "sht": K0, A0, B0, A$
18936 CALL "sht": K, A, B, B$
18937 CALL "er": N(), X(), X$(), G, "SHAPE_MISMATCH_C", A$, B$, "", 2
18938 GOTO 18945
18940 CALL "tyn": T(), D0, A$
18942 CALL "tyn": T(), D, B$
18944 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
18945 SUBEND
18950 REM ---- iarm: the [] arm P of an if expression takes the type of the other arm O when that is an
18955 REM array type (LANGUAGE 6.9), else 252 at the [] (and at O, also a []); nothing after an error --
18960 SUB "iarm": N(), M(), T(), X(), X$(), P, O
18965 IF M(O, 4) <> 5 THEN 18990
18970 CALL "er": N(), X(), X$(), P, "CANNOT_INFER", "", "", "", 0
18975 CALL "er": N(), X(), X$(), O, "CANNOT_INFER", "", "", "", 0
18980 LET M(P, 4) = 0
18985 GOTO 19025
18990 CALL "vu": N(), M(), T(), X(), X$(), O, V
18995 LET M(P, 4) = 0
19000 IF V = 0 THEN 19025
19005 CALL "elt": T(), V, E, K
19010 IF K = 0 THEN 19020
19015 CALL "eset": N(), M(), T(), X(), X$(), P, V
19017 GOTO 19025
19020 CALL "er": N(), X(), X$(), P, "CANNOT_INFER", "", "", "", 0
19025 SUBEND
19030 REM ---- iarr: R = the type of an if expression whose arms A, B have the types G1 <> G2: an untyped
19035 REM literal beside an f64 array is f64 (rtf); arrays of one rank and element type have the
19040 REM dynamic type, a dyn on each fixed-size arm (DESIGN 3.5.5); else R = 0 (a type mismatch) -----
19045 SUB "iarr": N(), M(), T(), X(), X$(), A, B, G1, G2, R
19050 LET R = 0
19055 CALL "shp": T(), G1, E1, K1, F1, A1, B1
19060 CALL "shp": T(), G2, E2, K2, F2, A2, B2
19065 IF K1 * K2 = 0 THEN 19140
19070 IF K1 <> K2 THEN 19140
19075 IF M(A, 4) <> 2 THEN 19095
19080 IF E2 <> 4 THEN 19095
19085 CALL "rtf": N(), M(), T(), X(), X$(), A
19090 LET E1 = 4
19095 IF M(B, 4) <> 2 THEN 19115
19100 IF E1 <> 4 THEN 19115
19105 CALL "rtf": N(), M(), T(), X(), X$(), B
19110 LET E2 = 4
19115 IF E1 <> E2 THEN 19140
19120 IF M(A, 1) = M(B, 1) THEN 19138
19122 CALL "tarr": T(), N(), X(), X$(), K1, E1, 0, 0, R
19125 IF F1 = 0 THEN 19132
19130 LET M(A, 5) = R
19132 IF F2 = 0 THEN 19140
19135 LET M(B, 5) = R
19137 GOTO 19140
19138 LET R = M(A, 1)
19140 SUBEND
19145 REM ---- lbc: the elemental library call J (class Z, scalar result type D) with the argument
19150 REM types U(1..H): with an array argument the broadcast of its arguments (202,
19155 REM 217 at the call) of element type D; ind2sub (from phase 6 also with an array r, L-cl) gives
19160 REM two i64 arrays of the broadcast shape of r and k ------------------------------------------
19165 SUB "lbc": N(), M(), T(), X(), X$(), J, Z, D, U(), H
19170 DIM G(4), V(2)
19190 LET G(1) = 0
19195 LET G(4) = 1
19200 FOR I = 1 TO H
19205 CALL "bcs": T(), G(), U(I), R, A$, B$
19210 IF R > 0 THEN 19225
19215 NEXT I
19220 GOTO 19265
19225 LET D = 0
19230 IF R = 2 THEN 19245
19235 CALL "er": N(), X(), X$(), J, "VEC_MAT", "", "", "", 0
19240 GOTO 19300
19245 CALL "er": N(), X(), X$(), J, "SHAPE_MISMATCH_C", A$, B$, "", 2
19250 GOTO 19300
19265 IF Z = 9 THEN 19282
19267 IF G(1) = 0 THEN 19300
19275 CALL "bres": T(), N(), X(), X$(), G(), D, Q
19277 LET D = Q
19280 GOTO 19300
19282 LET V(1) = 3
19283 IF G(1) = 0 THEN 19290
19285 CALL "bres": T(), N(), X(), X$(), G(), 3, V(1)
19290 LET V(2) = V(1)
19295 CALL "ttup": T(), N(), X(), X$(), V(), 2, D
19300 SUBEND
19305 REM ---- fxk: R = the array kind of an array literal or one of its rows of rank K (1 vector, 2
19310 REM matrix) with P elements: fixed-size (K + 2) when F is 1 and P is at most LIM_FIXED_ELEMS ---
19315 SUB "fxk": X(), K, F, P, R
19320 LET R = K
19325 IF F = 0 THEN 19340
19330 IF P > X(39) THEN 19340
19335 LET R = K + 2
19340 SUBEND
