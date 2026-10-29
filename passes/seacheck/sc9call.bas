23500 REM ==== sc9call: the calls of sub-phase 6b (DESIGN 2.11.2 "Readings fixed by phase 6", 3.5.4,
23505 REM 3.5.5 "Evaluation order"; LANGUAGE 8.1, 10.10, 11.2; Decisions 91, 93, lead decisions L-bw,
23510 REM L-bx, L-by, L-cp): named and default arguments of Sea functions (the prelude's included), the
23515 REM default values checked as constants, and the output calls print and make_dir ------------
23520 REM ---- ck_dflt: the default value of every parameter of every entered fn, in item order, where
23525 REM the const items are checked (after ck_cord, before the bodies; Decision 91): each exactly as
23530 REM the value of a const item annotated with its parameter's type: 237 (cex), 201 (cv); then,
23535 REM without an error and when it names no constant without a value and no node has the error
23540 REM type (cval, Decision 25), its i64 operations are evaluated exactly (dimv), each maximal i64
23545 REM operation in evaluation order: 260 or 261 at the first operator node that fails ----------
23550 SUB "ck_dflt": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
23555 FOR S = 2 TO X(30)
23560 LET P = N(Y(S, 3), 7)
23565 FOR K = 1 TO Y(S, 6)
23570 IF N(P, 2) = 0 THEN 23690
23575 LET E = N(N(P, 7), 8)
23580 LET X(19) = P
23585 LET X9 = X(9)
23590 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
23595 CALL "cex": N(), M(), Y(), S$(), E, Z
23600 IF Z = 1 THEN 23615
23605 IF M(E, 1) = 0 THEN 23615
23610 CALL "er": N(), X(), X$(), E, "NOT_CONSTANT", "", "", "", 0
23615 LET D = M(P, 1)
23620 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
23625 CALL "fin": N(), M(), C(), X(), X$(), E
23630 IF X(9) > X9 THEN 23690
23635 IF D = 0 THEN 23690
23640 CALL "cval": N(), M(), Y(), X(), E, Z
23645 IF Z = 0 THEN 23690
23650 REM the roots of the i64 operations (a neg or bin of type i64 whose parent is none)
23655 FOR J = M(E, 0) TO E
23660 IF M(J, 1) <> 3 THEN 23685
23662 IF ABS(N(J, 0) - 33) <> 1 THEN 23685
23664 IF J = E THEN 23670
23666 IF M(N(J, 9), 1) <> 3 THEN 23670
23668 IF ABS(N(N(J, 9), 0) - 33) = 1 THEN 23685
23670 CALL "dimv": N(), M(), Y(), C(), J, R, J9
23672 IF R < 3 THEN 23685
23674 LET A$ = "INT_OVERFLOW_C"
23676 IF R = 3 THEN 23680
23678 LET A$ = "INT_DIV_ZERO_C"
23680 CALL "er": N(), X(), X$(), J9, A$, "", "", "", 0
23682 GOTO 23690
23685 NEXT J
23690 LET P = N(P, 8)
23695 NEXT K
23700 NEXT S
23705 SUBEND
23710 REM ---- cval: Z = 1 when the constant expression E (of a const item or a default) may be
23715 REM evaluated (DESIGN 3.4.1 step 2, Decision 25 as refined): it names no constant without a value
23720 REM (Y(s,7) 6), calls no function item (a call of pow or sqrt whose callee is no rname pd) and no
23725 REM node of it has the error type (a callee name aside, which has none); else Z = 0 ----------
23730 SUB "cval": N(), M(), Y(), X(), E, Z
23735 LET Z = 0
23740 FOR J = M(E, 0) TO E
23745 IF N(J, 0) = 35 THEN 23780
23750 IF N(J, 0) <> 30 THEN 23770
23755 IF N(N(J, 9), 0) <> 35 THEN 23763
23760 IF N(N(J, 9), 7) = J THEN 23790
23763 IF N(J, 1) <> 2 THEN 23770
23765 IF Y(X(31) + N(J, 2), 7) = 6 THEN 23800
23770 IF M(J, 1) = 0 THEN 23800
23775 GOTO 23790
23780 IF N(N(J, 7), 1) <> 5 THEN 23800
23785 GOTO 23770
23790 NEXT J
23795 LET Z = 1
23800 SUBEND
23805 REM ---- ck_ucall: call J of Sea function R (LANGUAGE 8.1, 8.3, 4.2; DESIGN 2.11.2): the positional
23810 REM arguments first (more than np is 242 at the call), each checked by carg; then the named ones,
23815 REM in source order, each value and then its narg: a name no parameter has is 224 at the narg (the
23820 REM value settled); a ref parameter's is 254 at the value (Decision 93); else the value converts
23825 REM to the parameter's type (cv); a parameter already given is 225 at the narg, only for a value
23830 REM without an error (its own, M(narg,3) > M(first node,3), or of cv), as in 4f; then the call:
23835 REM a parameter neither given nor with a default is 226 at the call (not after a 224 in it: the
23837 REM unknown name may be the parameter meant, implementer reading), and a ref argument must not
23840 REM share its root with another argument (LANGUAGE 8.3). Writing (em_uarg): a call with a named or
23845 REM an omitted argument has its callee jump to the call (M(callee,8) = -J); when the source order
23850 REM of its arguments differs from their parameter order (L-cp), M(J,9) = 1 + the number of values
23855 REM bound to .t locals, each marked M(value,6) 1 (DESIGN 3.5.5 "Evaluation order"; rmk for the
23860 REM index expressions of a ref argument); else M(J,9) = 0. Q(k) the node of parameter k, G(k)
23865 REM the argument that gives it (0 none) ---------------------------------------------------------
23870 SUB "ck_ucall": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, R
23875 DIM Q(64), G(64)
23880 LET H = N(J, 1)
23885 LET P0 = Y(R, 6)
23890 LET M(J, 1) = 1
23895 IF Y(R, 7) = 0 THEN 23905
23900 LET M(J, 1) = Y(R, 2)
23905 LET M(J, 9) = 0
23910 LET P = N(Y(R, 3), 7)
23915 FOR K = 1 TO P0
23920 LET Q(K) = P
23925 LET G(K) = 0
23930 LET P = N(P, 8)
23935 NEXT K
23940 REM H1 the positional arguments (pass 1 put every named one after them, error 115)
23945 LET H1 = 0
23950 LET A = N(N(J, 7), 8)
23955 IF A = 0 THEN 23975
23960 IF N(A, 0) = 36 THEN 23975
23965 LET H1 = H1 + 1
23970 LET A = N(A, 8)
23972 GOTO 23955
23975 IF H1 <= P0 THEN 23985
23980 CALL "er": N(), X(), X$(), J, "TOO_MANY_ARGS", "", "", "", 0
23985 LET Z8 = 0
23990 LET Z9 = 0
23992 LET Z6 = 0
23995 LET A = N(N(J, 7), 8)
24000 FOR I = 1 TO H
24005 IF I > H1 THEN 24040
24010 IF I <= P0 THEN 24025
24015 CALL "fin": N(), M(), C(), X(), X$(), A
24020 GOTO 24145
24025 LET G(I) = A
24030 LET Z8 = I
24035 CALL "carg": N(), M(), Y(), T(), C(), S$(), X(), X$(), A, Q(I)
24037 GOTO 24145
24040 REM a named argument: the parameter of its name (names are interned: one S$ index each)
24045 LET V = N(A, 7)
24050 LET K = 0
24055 FOR K1 = 1 TO P0
24060 IF N(Q(K1), 6) <> N(A, 6) THEN 24070
24065 LET K = K1
24070 NEXT K1
24075 IF K > 0 THEN 24095
24080 CALL "er": N(), X(), X$(), A, "UNKNOWN_PARAM", "", "", "", 0
24082 LET Z6 = 1
24085 CALL "fin": N(), M(), C(), X(), X$(), V
24090 GOTO 24145
24095 LET P = Q(K)
24100 LET E1 = X(9)
24105 IF N(P, 1) = 0 THEN 24120
24110 CALL "er": N(), X(), X$(), V, "REF_NEEDED", S$(N(P, 6)), "", "", 1
24115 CALL "fin": N(), M(), C(), X(), X$(), V
24117 GOTO 24125
24120 CALL "cv": N(), M(), T(), C(), X(), X$(), V, M(P, 1)
24125 IF G(K) = 0 THEN 24137
24127 IF X(9) > E1 THEN 24145
24130 IF M(A, 3) > M(M(V, 0), 3) THEN 24145
24132 CALL "er": N(), X(), X$(), A, "PARAM_TWICE", "", "", "", 0
24135 GOTO 24145
24137 LET G(K) = A
24139 IF K > Z8 THEN 24143
24141 LET Z9 = 1
24143 LET Z8 = K
24145 LET A = N(A, 8)
24150 NEXT I
24155 REM a parameter given neither positionally nor by name and without a default
24160 LET Z7 = 0
24165 FOR K = 1 TO P0
24170 IF G(K) > 0 THEN 24195
24175 LET Z7 = 1
24180 IF N(Q(K), 2) = 1 THEN 24195
24182 IF Z6 = 1 THEN 24195
24185 CALL "er": N(), X(), X$(), J, "MISSING_ARG", "", "", "", 0
24190 GOTO 24200
24195 NEXT K
24200 REM a ref argument must not share its root variable with another argument (LANGUAGE 8.3)
24205 LET A = N(N(J, 7), 8)
24210 FOR I = 1 TO H
24215 IF N(A, 0) <> 37 THEN 24265
24220 CALL "root": N(), M(), Y(), A, S
24225 IF S = 0 THEN 24265
24230 LET B = N(N(J, 7), 8)
24235 IF B = 0 THEN 24265
24240 IF B = A THEN 24260
24245 CALL "root": N(), M(), Y(), B, S1
24250 IF S1 <> S THEN 24260
24255 CALL "er": N(), X(), X$(), A, "REF_ALIAS", "", "", "", 0
24257 GOTO 24275
24260 LET B = N(B, 8)
24262 GOTO 24235
24265 LET A = N(A, 8)
24270 NEXT I
24275 REM the writing of a call with a named or an omitted argument (em_uarg)
24280 IF H + Z7 = H1 THEN 24345
24285 LET M(N(J, 7), 8) = -J
24290 IF Z9 = 0 THEN 24345
24295 LET B = 0
24300 LET A = N(N(J, 7), 8)
24305 FOR I = 1 TO H
24310 LET V = A
24315 IF N(A, 0) <> 36 THEN 24322
24320 LET V = N(A, 7)
24322 IF N(V, 0) <> 37 THEN 24328
24324 CALL "rmk": N(), M(), V, B
24326 GOTO 24338
24328 CALL "cst": N(), M(), V, Z
24330 LET M(V, 6) = 1 - Z
24335 LET B = B + 1 - Z
24338 LET A = N(A, 8)
24340 NEXT I
24342 LET M(J, 9) = 1 + B
24345 SUBEND
24350 REM ---- carg: positional argument A of parameter node P (LANGUAGE 8.1, 8.3): a value parameter
24355 REM takes a value that converts to its type (no ref, 255); a ref parameter a ref argument (else
24360 REM 254) whose target is a var or a ref parameter of the caller, or a field or element of one
24365 REM (else 227), of the parameter's type (201; a var-rule candidate for an f64 parameter is an f64
24370 REM store, Decision 8) ---------------------------------------------------------------------
24375 SUB "carg": N(), M(), Y(), T(), C(), S$(), X(), X$(), A, P
24380 LET D = M(P, 1)
24385 LET K = N(A, 0)
24390 IF N(P, 1) = 1 THEN 24420
24395 IF K <> 37 THEN 24410
24400 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", S$(N(P, 6)), "", "", 1
24405 GOTO 24530
24410 CALL "cv": N(), M(), T(), C(), X(), X$(), A, D
24415 GOTO 24530
24420 IF K = 37 THEN 24435
24425 CALL "er": N(), X(), X$(), A, "REF_NEEDED", S$(N(P, 6)), "", "", 1
24430 GOTO 24530
24435 LET G = N(A, 7)
24440 LET B = G
24445 IF N(G, 0) = 30 THEN 24470
24450 IF M(G, 1) = 0 THEN 24530
24455 REM a field or an element of a var or ref parameter, through fields and elements; a selection
24460 REM or a projection is no ref target (LANGUAGE 8.3)
24465 CALL "tpath": N(), M(), T(), S$(), G, 0, B
24467 IF B = 0 THEN 24495
24470 REM a name: undeclared (reported at the name), else it must be a var or a ref parameter;
24475 REM a function, struct, constant, predeclared name or handle type is no ref target
24480 LET S = M(B, 2)
24485 IF S = 0 THEN 24530
24487 IF S < 0 THEN 24495
24489 IF Y(S, 0) <> 4 THEN 24495
24491 IF Y(S, 4) = 2 THEN 24500
24493 IF Y(S, 4) = 5 THEN 24500
24495 CALL "er": N(), X(), X$(), A, "REF_TARGET", "", "", "", 0
24497 GOTO 24530
24500 IF D = 0 THEN 24530
24502 IF M(G, 1) = D THEN 24530
24504 IF B <> G THEN 24520
24506 IF Y(S, 6) = 0 THEN 24520
24508 IF D <> 4 THEN 24520
24510 IF M(G, 1) <> 3 THEN 24520
24512 CALL "cand": M(), Y(), X(), S
24515 GOTO 24530
24520 CALL "tyn": T(), D, A$
24522 CALL "tyn": T(), M(G, 1), B$
24525 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
24530 SUBEND
24535 REM ---- rmk: the index expressions of the target of ref argument V that are no constant (cst)
24540 REM are bound to .t locals (DESIGN 3.5.5 "Evaluation order"): M(x,6) 1, B counts them. An index
24545 REM expression holding a $ of its own index (a dol claimed by that idx, DESIGN 3.5.5) is written in
24550 REM place: a dol may not stand outside the indices of its idx (implementer reading) ----------
24555 SUB "rmk": N(), M(), V, B
24560 LET G = N(V, 7)
24565 IF N(G, 0) = 43 THEN 24630
24570 IF N(G, 0) <> 39 THEN 24640
24575 LET X1 = N(N(G, 7), 8)
24580 IF X1 = 0 THEN 24630
24585 CALL "cst": N(), M(), X1, Z
24590 IF Z = 1 THEN 24620
24595 FOR J = M(X1, 0) TO X1
24600 IF N(J, 0) <> 31 THEN 24612
24602 LET Q = J
24604 LET Q1 = N(Q, 9)
24606 IF N(Q1, 0) <> 39 THEN 24608
24607 IF N(Q1, 7) <> Q THEN 24610
24608 LET Q = Q1
24609 GOTO 24604
24610 IF Q1 = G THEN 24618
24612 NEXT J
24614 LET Z = 0
24616 GOTO 24620
24618 LET Z = 1
24620 LET M(X1, 6) = 1 - Z
24622 LET B = B + 1 - Z
24625 LET X1 = N(X1, 8)
24627 GOTO 24580
24630 LET G = N(G, 7)
24635 GOTO 24565
24640 SUBEND
24645 REM ---- lout: print(s) and make_dir(path) (LANGUAGE 10.10, 11.2; DESIGN 2.11.2): one str, type
24650 REM void; no ref argument (255); with no argument error any other number or type of arguments is
24655 REM 'no overload of ... accepts (...)' (243) at the call, the types as written (a named one as
24660 REM name: T, 224 at its narg already leaving it an error) -----------------------------------
24665 SUB "lout": N(), M(), T(), C(), S$(), X(), X$(), J, L$
24670 LET M(J, 1) = 1
24675 LET E = 0
24680 LET B$ = ""
24685 LET A = N(N(J, 7), 8)
24690 FOR I = 1 TO N(J, 1)
24695 IF N(A, 0) <> 37 THEN 24710
24700 CALL "er": N(), X(), X$(), A, "REF_UNEXPECTED", L$, "", "", 1
24705 LET E = 1
24707 GOTO 24730
24710 CALL "vu": N(), M(), T(), X(), X$(), A, Q
24715 IF Q <> 0 THEN 24725
24720 LET E = 1
24725 CALL "fin": N(), M(), C(), X(), X$(), A
24730 CALL "tyn": T(), M(A, 1), A$
24735 IF N(A, 0) <> 36 THEN 24745
24740 LET A$ = S$(N(A, 6)) & ": " & A$
24745 IF I = 1 THEN 24755
24750 LET B$ = B$ & ", "
24755 LET B$ = B$ & A$
24760 LET A = N(A, 8)
24765 NEXT I
24770 IF E = 1 THEN 24795
24775 IF N(J, 1) <> 1 THEN 24790
24780 IF M(N(N(J, 7), 8), 1) = 5 THEN 24795
24790 CALL "er": N(), X(), X$(), J, "NO_OVERLOAD", L$, B$, "", 2
24795 SUBEND
24800 REM ---- em_uarg: the arguments of call J written with em_ucall's marks (DESIGN 3.5.4, 3.5.5):
24805 REM when it is reordered (M(J,9) > 0) first the bound values in source order, each followed by
24810 REM its bind (embd), the index expressions of a ref argument's target among them; then one
24815 REM argument per parameter in parameter order: a bound value as lv of its .t local, a ref
24820 REM argument with its bound indices as lv (X(41), erep), any other value as written, an omitted
24825 REM one as a copy of the parameter's default with the default's own positions. em_node then
24830 REM writes the call (np arguments) and, when reordered, its seq --------------------------------
24835 SUB "em_uarg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
24837 LET X9 = X(41)
24838 LET X(41) = 0
24840 LET R = M(N(J, 7), 2)
24845 LET H = N(J, 1)
24850 IF M(J, 9) = 0 THEN 24925
24855 LET A = N(N(J, 7), 8)
24860 FOR I = 1 TO H
24865 LET V = A
24870 IF N(A, 0) <> 36 THEN 24880
24875 LET V = N(A, 7)
24880 IF N(V, 0) = 37 THEN 24895
24885 IF M(V, 6) = 0 THEN 24918
24890 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), V
24892 GOTO 24918
24895 FOR J1 = M(V, 0) TO V
24900 IF M(J1, 6) = 0 THEN 24915
24902 CALL "onp": N(), V, J1, Z
24905 IF Z = 0 THEN 24915
24910 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J1
24915 NEXT J1
24918 LET A = N(A, 8)
24920 NEXT I
24925 LET P = N(Y(R, 3), 7)
24930 FOR K = 1 TO Y(R, 6)
24935 LET V = N(N(P, 7), 8)
24940 LET A = N(N(J, 7), 8)
24945 FOR I = 1 TO H
24950 IF N(A, 0) = 36 THEN 24960
24952 IF I = K THEN 24965
24955 GOTO 24970
24960 IF N(A, 6) <> N(P, 6) THEN 24970
24962 LET A = N(A, 7)
24965 LET V = A
24967 LET I = H
24970 LET A = N(A, 8)
24975 NEXT I
24980 IF M(V, 6) = 0 THEN 24990
24985 CALL "emlv": N(), M(), T(), W(), X(), V
24987 GOTO 25005
24990 IF N(V, 0) <> 37 THEN 24997
24995 LET X(41) = M(J, 9)
24997 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), V
25000 LET X(41) = 0
25005 LET P = N(P, 8)
25010 NEXT K
25012 LET X(41) = X9
25015 SUBEND
25020 REM ---- onp: Z = 1 when node J1 is an index expression of an idx on the target path of ref
25025 REM argument V (the path: V's child, then the base of each index or dot), else 0 -------------
25030 SUB "onp": N(), V, J1, Z
25035 LET Z = 0
25040 LET Q1 = N(J1, 9)
25045 IF N(Q1, 0) <> 39 THEN 25080
25050 IF N(Q1, 7) = J1 THEN 25080
25055 LET G = N(V, 7)
25060 IF G = Q1 THEN 25075
25065 IF ABS(N(G, 0) - 41) <> 2 THEN 25080
25070 LET G = N(G, 7)
25072 GOTO 25060
25075 LET Z = 1
25080 SUBEND
25085 REM ---- erep: in ref argument E written with bound indices (X(41) > 0, em_uarg), G = the largest
25090 REM node whose subtree starts at node J, lies within E and is a bound index expression of E's
25095 REM target path (M(g,6) > 0, onp), written as lv of its .t local (emlv); 0 when there is none -
25100 SUB "erep": N(), M(), T(), W(), X(), J, E, G
25105 LET G = 0
25107 IF N(E, 0) <> 37 THEN 25150
25110 LET Q = J
25115 IF Q > E THEN 25140
25120 IF M(Q, 0) <> J THEN 25140
25125 IF M(Q, 6) = 0 THEN 25132
25127 CALL "onp": N(), E, Q, Z
25128 IF Z = 0 THEN 25132
25130 LET G = Q
25132 LET Q = N(Q, 9)
25135 GOTO 25115
25140 IF G = 0 THEN 25150
25145 CALL "emlv": N(), M(), T(), W(), X(), G
25150 SUBEND
25155 REM ---- emlv: bound value V written as lv of its .t local (its position, its type as written) --
25160 SUB "emlv": N(), M(), T(), W(), X(), V
25165 CALL "pos": N(), V, P$
25170 CALL "cty": N(), M(), V, Q
25175 CALL "tyr": T(), W(), X(), Q, A$
25180 CALL "wr": X(), "lv " & P$ & " " & A$ & " " & STR$(X(40) + M(V, 6))
25185 SUBEND
25190 REM ---- embd: after node J, the bind of its .t local: a struct literal's bound initializer (M(J,4),
25195 REM the value its child) or a bound argument (M(J,6), the node itself; DESIGN 3.5.5) ----------
25200 SUB "embd": N(), M(), X(), J
25205 IF N(J, 0) <> 48 THEN 25225
25210 IF M(J, 4) = 0 THEN 25225
25215 CALL "pos": N(), N(J, 7), P$
25220 CALL "wr": X(), "bind " & P$ & " " & STR$(X(40) + M(J, 4))
25225 IF M(J, 6) = 0 THEN 25240
25230 CALL "pos": N(), J, P$
25235 CALL "wr": X(), "bind " & P$ & " " & STR$(X(40) + M(J, 6))
25240 SUBEND
