26000 REM ==== sc9plot: the 21 plotting calls of phase 9 (DESIGN 2.14.2 "Signatures", 2.14.4 "seacheck";
26005 REM LANGUAGE 12; lead decisions L-kg, L-kx): the class table, the options, the overloads and the
26010 REM written form (every parameter, defaults as constants, the temporaries of evaluation order) ====
26015 REM ---- pcls: Z = the class of library function L$ when it is one of the 21 plotting calls (32
26020 REM figure ... 52 axis_equal, DESIGN 2.14.4), else 0. Slots of 12 bytes, so "|name " is aligned ---
26025 SUB "pcls": L$, Z
26030 LET Z = 0
26035 LET Q$ = "|figure     |panel      |twin_y     |save_svg   |plot       |xline      |bar        |barh       "
26040 LET Q$ = Q$ & "|contour    |image      |xlabel     |ylabel     |title      |legend     |grid       |xlim       "
26045 LET Q$ = Q$ & "|ylim       |x_ticks    |y_ticks    |y_reverse  |axis_equal "
26050 LET P = POS(Q$, "|" & L$ & " ")
26055 IF P = 0 THEN 26065
26060 LET Z = 32 + (P - 1) / 12
26065 SUBEND
26070 REM ---- psig: the signature of plotting class Z (DESIGN 2.14.2's table, by its group G): C$ the
26075 REM codes of the parameters in order (h Figure, a Axes, i i64, f f64, b bool, s str, v f64[], m
26080 REM f64[,], S str[]), the first N1 positional, the rest options (named only); P$ their names,
26085 REM blank-separated; D$ the options' defaults as sea.hir1 writes their constants, |-separated (a ci
26090 REM value, cf bits, cb 0 or 1, an escaped cs) ---------------------------------------------------
26095 SUB "psig": Z, C$, N1, P$, D$
26100 LET G = VAL(SEG$("010203040506070809101111111213141415150303", 2 * Z - 63, 2 * Z - 62))
26105 LET C$ = "ii/sii   hii/ii   a/       hs/      avv/ssfs af/ss    avv/fss  av/fss   avvm/ibs avvm/b   as/      a/s      a/b      aff/     aS/      "
26110 LET C$ = SEG$(C$, 9 * G - 8, 9 * G)
26115 LET C$ = SEG$(C$, 1, POS(C$, " ") - 1)
26120 LET N1 = POS(C$, "/") - 1
26125 LET C$ = SEG$(C$, 1, N1) & SEG$(C$, N1 + 2, LEN(C$))
26130 LET P$ = "nrows ncols name width height  fig row col rowspan colspan    ax                             "
26135 LET P$ = P$ & "fig path                       ax x y style label width color ax x style color               "
26140 LET P$ = P$ & "ax x h width label color       ax h width label color         ax x y Z levels labels color   "
26145 LET P$ = P$ & "ax x y Z colorbar              ax s                           ax loc                         "
26150 LET P$ = P$ & "ax on                          ax lo hi                       ax labels                      "
26155 LET P$ = SEG$(P$, 31 * G - 30, 31 * G)
26160 LET D$ = "%|960|720              1|1                                                                  "
26165 LET D$ = D$ & "-|%|#3FF0000000000000|%--|%                   #3FE999999999999A|%|%  #3FE999999999999A|%|%  "
26170 LET D$ = D$ & "10|0|%                 0                                             northeast              1"
26175 LET D$ = SEG$(D$, 23 * G - 22, 23 * G) & " "
26180 LET D$ = SEG$(D$, 1, POS(D$, " ") - 1)
26185 SUBEND
26190 REM ---- pfw: A$ = field K (from 1) of F$, the fields separated by the byte G$ ----------------------
26195 SUB "pfw": F$, G$, K, A$
26200 LET A$ = F$ & G$
26205 LET B = 1
26210 FOR I = 2 TO K
26215 LET B = POS(A$, G$, B) + 1
26220 NEXT I
26225 LET A$ = SEG$(A$, B, POS(A$, G$, B) - 1)
26230 SUBEND
26235 REM ---- popt: K = the parameter (N1 + 1 ... N2) of names P$ that is the option named S$(W), else 0 -
26240 SUB "popt": S$(), P$, N2, N1, W, K
26245 LET K = 0
26250 FOR I = N1 + 1 TO N2
26255 CALL "pfw": P$, " ", I, A$
26260 IF A$ <> S$(W) THEN 26270
26265 LET K = I
26270 NEXT I
26275 SUBEND
26280 REM ---- pnarg: named argument J (name: value) of a call of plotting class Z, from ck_narg (DESIGN
26285 REM 2.14.4: each value, then its narg): a name that is no option of the call is 224 at the narg (the
26290 REM value settled, fin); an untyped constant value takes the option's type (f64 for an f option, else
26295 REM i64); then, after a value without an error, a name the call gave before is 225 at the second
26300 REM narg. M(J,1) = the value's type (0 after an error); ck_plot judges it with the call -----------
26305 SUB "pnarg": N(), M(), Y(), T(), C(), S$(), X(), X$(), J, Z
26310 LET M(J, 1) = 0
26315 LET V = N(J, 7)
26320 CALL "psig": Z, C$, N1, P$, D$
26325 CALL "popt": S$(), P$, LEN(C$), N1, N(J, 6), K
26330 IF K > 0 THEN 26350
26335 CALL "er": N(), X(), X$(), J, "UNKNOWN_PARAM", "", "", "", 0
26340 CALL "fin": N(), M(), C(), X(), X$(), V
26345 GOTO 26425
26350 CALL "vu": N(), M(), T(), X(), X$(), V, D
26355 IF D = 0 THEN 26425
26360 IF D <> -1 THEN 26375
26365 CALL "stl": N(), M(), C(), X(), X$(), V, 3 + POS(SEG$(C$, K, K) & " ", "f")
26370 LET D = M(V, 1)
26375 REM after its value: a name the call gave before (interned: one S$ index per name)
26380 LET A = N(N(N(J, 9), 7), 8)
26385 IF A = J THEN 26420
26390 IF N(A, 0) <> 36 THEN 26410
26395 IF N(A, 6) <> N(J, 6) THEN 26410
26400 CALL "er": N(), X(), X$(), J, "PARAM_TWICE", "", "", "", 0
26405 GOTO 26425
26410 LET A = N(A, 8)
26415 GOTO 26385
26420 LET M(J, 1) = D
26425 SUBEND
26430 REM ---- ck_plot: call J of plotting class Z, from ck_lib (DESIGN 2.14.2, 2.14.4; L-kg). The type is
26435 REM fixed: Figure for figure, Axes for panel and twin_y, else 1 (no value), after an error too. The
26440 REM arguments in source order: a ref one is 255 naming its positional parameter (past them only counted: 243);
26445 REM an untyped constant takes the type of its positional parameter (f64 for an f one, else i64), an
26450 REM untyped literal array is f64 at a v or m parameter (rtf); a named one was judged by pnarg. With
26455 REM no argument error: other than N1 positional arguments, or an argument whose type its parameter
26460 REM does not take (ptyp, which marks the conversions), is no overload (Z9 = 1: ck_lib reports 243,
26465 REM the types as written). Then the writing: when the named options are not in parameter order
26470 REM (L-cp), every argument that is no constant (cst) is bound to a .t local (M(value,6) 1) and
26475 REM M(J,9) = 11 + their count, else M(J,9) = 10; the callee jumps to the call (em_plot) ----------
26480 SUB "ck_plot": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, Z, Z9
26485 LET Z9 = 0
26490 CALL "psig": Z, C$, N1, P$, D$
26495 LET N2 = LEN(C$)
26500 LET M(J, 1) = 1
26505 IF Z > 34 THEN 26515
26510 LET M(J, 1) = 7 - INT(1 / (Z - 31))
26515 REM a ref argument past the positional parameters is counted only: 243 by the count below
26520 LET E = 0
26525 LET H1 = 0
26530 LET A = N(N(J, 7), 8)
26535 FOR I = 1 TO N(J, 1)
26540 IF N(A, 0) <> 36 THEN 26560
26545 IF M(A, 1) <> 0 THEN 26670
26550 LET E = 1
26555 GOTO 26670
26560 LET H1 = H1 + 1
26565 IF N(A, 0) <> 37 THEN 26600
26570 IF I > N1 THEN 26670
26580 CALL "pfw": P$, " ", I, A$
26585 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", A$, "", "", 1
26590 LET E = 1
26595 GOTO 26670
26600 CALL "vu": N(), M(), T(), X(), X$(), A, Q
26605 IF Q <> 0 THEN 26620
26610 LET E = 1
26615 GOTO 26670
26620 LET C1$ = ""
26625 IF I > N1 THEN 26635
26630 LET C1$ = SEG$(C$, I, I)
26635 IF Q <> -1 THEN 26650
26640 CALL "stl": N(), M(), C(), X(), X$(), A, 3 + POS(C1$ & " ", "f")
26645 GOTO 26670
26650 IF M(A, 4) <> 2 THEN 26670
26655 IF C1$ = "v" THEN 26665
26660 IF C1$ <> "m" THEN 26670
26665 CALL "rtf": N(), M(), T(), X(), X$(), A
26670 LET A = N(A, 8)
26675 NEXT I
26680 IF E = 1 THEN 26860
26685 IF H1 <> N1 THEN 26855
26690 REM the types, each argument against its parameter (a named one: its option, popt); R9 = 1 when
26695 REM the parameters given are not in increasing order (named options out of their order)
26700 LET A = N(N(J, 7), 8)
26705 LET K2 = 0
26710 LET R9 = 0
26715 FOR I = 1 TO N(J, 1)
26720 LET V = A
26725 LET K = I
26730 IF N(A, 0) <> 36 THEN 26745
26735 LET V = N(A, 7)
26740 CALL "popt": S$(), P$, N2, N1, N(A, 6), K
26745 CALL "ptyp": N(), M(), T(), X(), X$(), V, SEG$(C$, K, K), Q
26750 IF Q = 0 THEN 26855
26755 IF K > K2 THEN 26765
26760 LET R9 = 1
26765 LET K2 = K
26770 LET A = N(A, 8)
26775 NEXT I
26780 LET B = 0
26785 IF R9 = 0 THEN 26840
26790 LET A = N(N(J, 7), 8)
26795 FOR I = 1 TO N(J, 1)
26800 LET V = A
26805 IF N(A, 0) <> 36 THEN 26815
26810 LET V = N(A, 7)
26815 CALL "cst": N(), M(), V, Q
26820 LET M(V, 6) = 1 - Q
26825 LET B = B + 1 - Q
26830 LET A = N(A, 8)
26835 NEXT I
26840 LET M(J, 9) = 10 + R9 * (1 + B)
26845 LET M(N(J, 7), 8) = -J
26850 GOTO 26860
26855 LET Z9 = 1
26860 SUBEND
26865 REM ---- ptyp: Q = 1 when value V (no error) is taken by a parameter of code C$ (psig): a handle of
26870 REM exactly its type, an i64, bool or str scalar; an f64 scalar or an i64 one converted (acv); a v
26875 REM or m an f64 or i64 vector or matrix (converted, element by element) and an S a str vector, a
26880 REM fixed-size one then made dynamic (M(V,5), a dyn at the call, lpos; as L-jq). Else Q = 0 ------
26885 SUB "ptyp": N(), M(), T(), X(), X$(), V, C$, Q
26890 LET Q = 0
26895 LET T1 = M(V, 1)
26900 LET K = POS("habisfvmS", C$)
26905 IF K > 5 THEN 26925
26910 IF T1 <> VAL(SEG$("67235", K, K)) THEN 27000
26915 LET Q = 1
26920 GOTO 27000
26925 IF K > 6 THEN 26955
26930 IF T1 = 4 THEN 26945
26935 IF T1 <> 3 THEN 27000
26940 CALL "acv": N(), M(), T(), X(), X$(), V
26945 LET Q = 1
26950 GOTO 27000
26955 CALL "shp": T(), T1, E, K1, F, A0, B0
26960 IF K1 <> VAL(SEG$("121", K - 6, K - 6)) THEN 27000
26965 LET E1 = 4 + INT(K / 9)
26970 IF E = E1 THEN 26985
26975 IF E1 * 10 + E <> 43 THEN 27000
26980 CALL "acv": N(), M(), T(), X(), X$(), V
26985 IF F = 0 THEN 26995
26990 CALL "tarr": T(), N(), X(), X$(), K1, E1, 0, 0, M(V, 5)
26995 LET Q = 1
27000 SUBEND
27005 REM ---- em_plot: plotting call J written (DESIGN 2.14.4 "Written form", 3.5.5 "Evaluation order"),
27010 REM reached through its callee's jump (em_expr): when reordered (M(J,9) > 10) first the bound values
27015 REM in source order, each followed by its bind; then one argument per parameter in the table's
27020 REM order: a bound value as lv of its .t local (emlv), any other as written, an omitted option as its
27025 REM default constant at the call's position; then lib NAME n (n every parameter), the seq of the
27030 REM M(J,9) - 11 bindings of a reordered call, and the call's own bind when it is bound (embd) ------
27035 SUB "em_plot": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
27040 LET L$ = S$(N(N(J, 7), 6))
27045 CALL "pcls": L$, Z
27050 CALL "psig": Z, C$, N1, P$, D$
27055 IF M(J, 9) = 10 THEN 27105
27060 LET A = N(N(J, 7), 8)
27065 FOR I = 1 TO N(J, 1)
27070 LET V = A
27075 IF N(A, 0) <> 36 THEN 27085
27080 LET V = N(A, 7)
27085 IF M(V, 6) = 0 THEN 27095
27090 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), V
27095 LET A = N(A, 8)
27100 NEXT I
27105 CALL "pos": N(), J, Q$
27110 FOR K = 1 TO LEN(C$)
27115 REM V = the argument of parameter K (the K-th positional one, or the option's narg), else 0
27120 LET V = 0
27125 LET A = N(N(J, 7), 8)
27130 FOR I = 1 TO N(J, 1)
27135 LET K1 = I
27140 IF N(A, 0) <> 36 THEN 27150
27145 CALL "popt": S$(), P$, LEN(C$), N1, N(A, 6), K1
27150 IF K1 <> K THEN 27160
27155 LET V = A
27160 LET A = N(A, 8)
27165 NEXT I
27170 IF V = 0 THEN 27210
27175 IF N(V, 0) <> 36 THEN 27185
27180 LET V = N(V, 7)
27185 IF M(V, 6) = 0 THEN 27200
27190 CALL "emlv": N(), M(), T(), W(), X(), V
27195 GOTO 27225
27200 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), V
27205 GOTO 27225
27210 CALL "pfw": D$, "|", K - N1, A$
27215 LET K1 = POS("ifbs", SEG$(C$, K, K))
27220 CALL "wr": X(), SEG$("cicfcbcs", 2 * K1 - 1, 2 * K1) & " " & Q$ & " " & SEG$("3425", K1, K1) & " " & A$
27225 NEXT K
27230 CALL "tyr": T(), W(), X(), M(J, 1), A$
27235 CALL "wr": X(), "lib " & Q$ & " " & A$ & " " & L$ & " " & STR$(LEN(C$))
27240 IF M(J, 9) = 10 THEN 27250
27245 CALL "wr": X(), "seq " & Q$ & " " & A$ & " " & STR$(M(J, 9) - 11)
27250 CALL "embd": N(), M(), X(), J
27255 SUBEND
