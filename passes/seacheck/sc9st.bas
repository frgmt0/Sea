21500 REM ==== sc9st: structs, records, fields, projection of sub-phase 4g-2 (DESIGN 2.6.2 step 4g-2,
21505 REM "Readings fixed by 4g", 3.4.2, 3.5.5; LANGUAGE 4.6, 4.7, 7.3, 8.3; Decision 48, lead decisions
21510 REM L-b, L-c). A struct type (T(t,0) 5: T(t,1) n, T(t,2) sid, T(t,3) its name) or record type (6:
21515 REM T(t,1) n) has its fields in the next ceil(n/4) rows, 4 per row: name (S$ index), type ----
21520 REM ---- fdg: A, B = the name and type of field K (from 1) of struct or record type Q ---------------
21525 SUB "fdg": T(), Q, K, A, B
21530 LET R = Q + 1 + INT((K - 1) / 4)
21535 LET C = 2 * (K - 1 - 4 * INT((K - 1) / 4))
21540 LET A = T(R, C)
21545 LET B = T(R, C + 1)
21550 SUBEND
21555 REM ---- fds: field K of struct or record type Q is named A, of type B -------------------------
21560 SUB "fds": T(), Q, K, A, B
21565 LET R = Q + 1 + INT((K - 1) / 4)
21570 LET C = 2 * (K - 1 - 4 * INT((K - 1) / 4))
21575 LET T(R, C) = A
21580 LET T(R, C + 1) = B
21585 SUBEND
21590 REM ---- fdf: R = the field of type Q named A (an S$ index: names are interned), 0 when none, or
21595 REM when Q is no struct or record type ----------------------------------------------------------
21600 SUB "fdf": T(), Q, A, R
21605 LET R = 0
21610 IF Q < 10 THEN 21645
21615 IF ABS(T(Q, 0) - 5.5) > 1 THEN 21645
21620 FOR K = 1 TO T(Q, 1)
21625 CALL "fdg": T(), Q, K, G, D
21630 IF G <> A THEN 21640
21635 LET R = K
21637 GOTO 21645
21640 NEXT K
21645 SUBEND
21650 REM ---- tynst: R$ = struct or record type Q as error texts write it (DESIGN 2.6.2): a struct's
21655 REM name, a record {name: T, ...}. tyn has no S$: a name is written as the marker byte 1, its S$
21660 REM index, byte 2, which tyx replaces by the name when the diagnostic is written --------------
21665 SUB "tynst": T(), Q, R$
21670 DIM Z(1)
21675 LET Z(0) = 1
21680 LET Z(1) = 1
21685 CHANGE Z TO A$
21690 LET Z(1) = 2
21695 CHANGE Z TO B$
21700 IF T(Q, 0) = 6 THEN 21715
21705 LET R$ = A$ & STR$(T(Q, 3)) & B$
21710 GOTO 21760
21715 LET R$ = "{"
21720 FOR K = 1 TO T(Q, 1)
21725 CALL "fdg": T(), Q, K, G, D
21730 CALL "tyn": T(), D, C$
21735 IF K = 1 THEN 21745
21740 LET R$ = R$ & ", "
21745 LET R$ = R$ & A$ & STR$(G) & B$ & ": " & C$
21750 NEXT K
21755 LET R$ = R$ & "}"
21760 SUBEND
21765 REM ---- tyx: R$ = the substitution A$ of a diagnostic with every name marker of tynst replaced by
21770 REM its name ----------------------------------------------------------------------------------
21775 SUB "tyx": S$(), A$, R$
21780 DIM Z(1)
21785 LET Z(0) = 1
21790 LET Z(1) = 1
21795 CHANGE Z TO B$
21800 LET Z(1) = 2
21805 CHANGE Z TO C$
21810 LET R$ = A$
21815 LET P = POS(R$, B$)
21820 IF P = 0 THEN 21840
21825 LET Q = POS(R$, C$, P)
21830 LET R$ = SEG$(R$, 1, P - 1) & S$(VAL(SEG$(R$, P + 1, Q - 1))) & SEG$(R$, Q + 1, LEN(R$))
21835 GOTO 21815
21840 SUBEND
21845 REM ---- ck_slit: struct literal J (rslit; LANGUAGE 4.6, DESIGN 2.6.2): sid 0 is unknown struct
21850 REM type (229) at the literal; each initializer, in source order, names a field (else unknown
21855 REM field, 206), once (else duplicate field, 205, at the second), and its value converts to the
21860 REM field's type (cv; a [] takes it, LANGUAGE 6.9); then missing field (204, the first field in
21865 REM declaration order without one) at the literal. Its type is the struct's. When the source
21870 REM order of the values differs from the declaration order (M(J,9) 1, DESIGN 3.5.5 "Evaluation
21875 REM order"), every value that is no constant is bound to a .t local (M(init,4) 1) and a constant
21880 REM is written in its declared place (M(first node,8) = -value: em_expr jumps past it) ------
21885 SUB "ck_slit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
21890 LET M(J, 9) = 0
21895 LET M(J, 1) = 0
21900 LET Q = 0
21905 IF N(J, 2) = 0 THEN 21915
21910 LET Q = W(150000 + 9 + N(J, 2))
21915 LET Z = 0
21920 LET E = 0
21925 IF Q > 0 THEN 21935
21930 CALL "er": N(), X(), X$(), J, "UNKNOWN_STRUCT", "", "", "", 0
21935 LET A = N(J, 7)
21940 FOR K = 1 TO N(J, 1)
21945 LET V = N(A, 7)
21950 IF Q = 0 THEN 22020
21955 CALL "fdf": T(), Q, N(A, 6), I
21960 IF I > 0 THEN 21975
21965 CALL "er": N(), X(), X$(), A, "UNKNOWN_FIELD", "", "", "", 0
21970 GOTO 22020
21975 REM an earlier initializer of the same name
21980 LET H = N(J, 7)
21985 IF H = A THEN 22005
21990 IF N(H, 6) = N(A, 6) THEN 22015
21995 LET H = N(H, 8)
22000 GOTO 21985
22005 IF I <> K THEN 22008
22006 GOTO 22009
22008 LET Z = 1
22009 CALL "fdg": T(), Q, I, G, D
22010 CALL "cv": N(), M(), T(), C(), X(), X$(), V, D
22012 GOTO 22030
22015 CALL "er": N(), X(), X$(), A, "DUPLICATE_FIELD", "", "", "", 0
22020 LET E = 1
22025 CALL "fin": N(), M(), C(), X(), X$(), V
22030 LET A = N(A, 8)
22035 NEXT K
22040 IF Q = 0 THEN 22165
22045 IF E = 1 THEN 22100
22050 REM missing field: the first field that no initializer names
22055 FOR I = 1 TO T(Q, 1)
22060 CALL "fdg": T(), Q, I, G, D
22065 LET A = N(J, 7)
22070 FOR K = 1 TO N(J, 1)
22075 IF N(A, 6) = G THEN 22095
22080 LET A = N(A, 8)
22085 NEXT K
22087 CALL "er": N(), X(), X$(), J, "MISSING_FIELD", S$(G), S$(T(Q, 3)), "", 2
22090 GOTO 22100
22095 NEXT I
22100 LET M(J, 1) = Q
22105 IF Z = 0 THEN 22165
22110 LET M(J, 9) = 1
22115 LET A = N(J, 7)
22120 FOR K = 1 TO N(J, 1)
22125 LET V = N(A, 7)
22130 CALL "cst": N(), M(), V, Z
22135 IF Z = 0 THEN 22150
22140 LET M(M(V, 0), 8) = -V
22145 GOTO 22155
22150 LET M(A, 4) = 1
22155 LET A = N(A, 8)
22160 NEXT K
22165 SUBEND
22170 REM ---- cst: Z = 1 when value V is written as one constant leaf (ci cf cb cs, DESIGN 3.5.5
22175 REM "Evaluation order"): a literal or true/false with no cvt, pi inf nan eps, -2^63 ---------
22180 SUB "cst": N(), M(), V, Z
22185 LET Z = 0
22190 LET K = N(V, 0)
22195 IF M(V, 7) <> 0 THEN 22235
22200 IF K = 32 THEN 22225
22205 IF K = 30 THEN 22215
22210 IF ABS(K - 27) > 2 THEN 22235
22212 GOTO 22230
22215 IF M(V, 2) < -4 THEN 22235
22220 IF M(V, 2) > -1 THEN 22235
22222 GOTO 22230
22225 IF M(N(V, 7), 8) >= 0 THEN 22235
22230 LET Z = 1
22235 SUBEND
22240 REM ---- ck_rlit: record literal J (LANGUAGE 4.6, Decision 48, lead decision L-b): a name T, flat,
22245 REM col or row is 222 and a name given twice 205, at the initializer, in source order; each
22250 REM value one value of its own type (an untyped constant i64). Its type is the record type of
22255 REM those names and types in that order, one per structure (DESIGN 3.5.1); 0 after an error ----
22260 SUB "ck_rlit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
22265 LET M(J, 1) = 0
22270 LET Z = 0
22275 LET H1 = N(J, 1)
22280 LET A = N(J, 7)
22285 FOR K = 1 TO H1
22290 LET V = N(A, 7)
22295 IF POS("|T|flat|col|row|", "|" & S$(N(A, 6)) & "|") = 0 THEN 22310
22300 CALL "er": N(), X(), X$(), A, "RESERVED_FIELD", "", "", "", 0
22305 GOTO 22340
22310 LET H = N(J, 7)
22315 IF H = A THEN 22345
22320 IF N(H, 6) = N(A, 6) THEN 22335
22325 LET H = N(H, 8)
22330 GOTO 22315
22335 CALL "er": N(), X(), X$(), A, "DUPLICATE_FIELD", "", "", "", 0
22340 LET Z = 1
22345 CALL "vu": N(), M(), T(), X(), X$(), V, D
22350 CALL "fin": N(), M(), C(), X(), X$(), V
22355 IF D <> 0 THEN 22365
22360 LET Z = 1
22365 LET A = N(A, 8)
22370 NEXT K
22375 IF Z = 1 THEN 22495
22380 REM an existing record type of these names and types, else a new one
22385 LET R = 10
22390 IF R > X(4) THEN 22450
22395 IF T(R, 0) <> 6 THEN 22440
22400 IF T(R, 1) <> H1 THEN 22440
22405 LET A = N(J, 7)
22410 FOR K = 1 TO H1
22415 CALL "fdg": T(), R, K, G, D
22420 IF G <> N(A, 6) THEN 22440
22425 IF D <> M(N(A, 7), 1) THEN 22440
22430 LET A = N(A, 8)
22435 NEXT K
22437 GOTO 22490
22440 CALL "tnext": T(), R
22445 GOTO 22390
22450 CALL "tnew": T(), N(), X(), X$(), 1 + INT((H1 + 3) / 4), R
22455 IF R = 0 THEN 22495
22460 LET T(R, 0) = 6
22465 LET T(R, 1) = H1
22470 LET A = N(J, 7)
22475 FOR K = 1 TO H1
22480 CALL "fds": T(), R, K, N(A, 6), M(N(A, 7), 1)
22485 LET A = N(A, 8)
22487 NEXT K
22490 LET M(J, 1) = R
22495 SUBEND
22500 REM ---- ck_fld: x.name where name is no view (LANGUAGE 4.6, 4.7; lead decision L-c): a field of a
22505 REM struct or record value (N(J,1) its number from 1); on a vector of structs or records the
22510 REM projection of a field of scalar or str type F, the vector F[] (N(J,2) 1), of any other field
22515 REM type 256; anything else (no such field, a matrix of structs, no struct) is 249 with the type -
22520 SUB "ck_fld": N(), M(), T(), C(), S$(), X(), X$(), J
22525 LET A0 = N(J, 7)
22530 CALL "vu": N(), M(), T(), X(), X$(), A0, D
22535 IF D = 0 THEN 22615
22540 CALL "fin": N(), M(), C(), X(), X$(), A0
22545 LET D = M(A0, 1)
22550 CALL "shp": T(), D, E, K, F, A, B
22555 IF K > 1 THEN 22605
22560 CALL "fdf": T(), E, N(J, 6), I
22565 IF I = 0 THEN 22605
22570 CALL "fdg": T(), E, I, G, Q
22575 LET N(J, 1) = I
22580 LET M(J, 1) = Q
22585 IF K = 0 THEN 22615
22590 LET N(J, 2) = 1
22592 IF Q < 2 THEN 22598
22594 IF Q > 5 THEN 22598
22595 CALL "tarr": T(), N(), X(), X$(), 1, Q, 0, 0, M(J, 1)
22596 GOTO 22615
22598 LET M(J, 1) = 0
22599 CALL "tyn": T(), Q, A$
22600 CALL "er": N(), X(), X$(), J, "PROJECTION", S$(N(J, 6)), A$, "", 2
22602 GOTO 22615
22605 CALL "tyn": T(), D, A$
22610 CALL "er": N(), X(), X$(), J, "NO_FIELD", S$(N(J, 6)), A$, "", 2
22615 SUBEND
22620 REM ---- tpath: B = the name at the root of target G (LANGUAGE 7.3, 8.3): through the fields (no
22625 REM projection), the elements (all indices scalar) and, for an assignment (A9 1), a selection or
22630 REM element of the outermost index and a .flat that is its base; else B = 0 (not a target) ----
22635 SUB "tpath": N(), M(), T(), S$(), G, A9, B
22640 LET B = G
22645 LET L = 0
22650 LET K = N(B, 0)
22655 IF K = 30 THEN 22720
22660 IF K = 43 THEN 22690
22665 IF K <> 39 THEN 22715
22670 CALL "elt": T(), M(B, 1), E, K1
22675 IF K1 = 0 THEN 22705
22680 IF A9 * (1 - SGN(L)) = 0 THEN 22715
22685 GOTO 22705
22690 IF N(B, 1) > 0 THEN 22700
22691 IF A9 = 0 THEN 22715
22692 IF L <> 1 THEN 22715
22694 IF N(G, 0) <> 39 THEN 22715
22696 IF S$(N(B, 6)) = "flat" THEN 22705
22698 GOTO 22715
22700 IF N(B, 2) = 1 THEN 22715
22705 LET B = N(B, 7)
22707 LET L = L + 1
22710 GOTO 22650
22715 LET B = 0
22720 SUBEND
22725 REM ---- st_val: the struct types of sea.res (DESIGN 3.4.2 "seacheck reading and validation"): one
22730 REM rtst per entered struct at ids 10, 11, ... in sid order, with the struct's name and its fields'
22735 REM names in order, and no other; Y(s,2) of each struct = its T row. A violation sets X(26) ----
22740 SUB "st_val": N(), Y(), T(), W(), X()
22745 LET C = 0
22750 FOR I = 10 TO X(32)
22755 IF T(W(150000 + I), 0) <> 5 THEN 22765
22760 LET C = C + 1
22765 NEXT I
22770 IF C <> X(33) - X(11) THEN 22835
22775 FOR S = 1 TO C
22780 LET R = W(150000 + 9 + S)
22785 LET I = Y(X(11) + S, 3)
22790 IF T(R, 0) <> 5 THEN 22835
22795 IF T(R, 2) <> S THEN 22835
22800 IF T(R, 3) <> N(I, 6) THEN 22835
22805 IF T(R, 1) <> N(I, 1) THEN 22835
22810 LET Y(X(11) + S, 2) = R
22815 LET G = N(I, 7)
22817 FOR K = 1 TO T(R, 1)
22820 CALL "fdg": T(), R, K, A, B
22822 IF A <> N(G, 6) THEN 22835
22824 LET G = N(G, 8)
22826 NEXT K
22830 NEXT S
22832 GOTO 22840
22835 LET X(26) = 1
22840 SUBEND
22845 REM ---- rdst: the rtst and rtfd records of the type table (sea.res, DESIGN 3.4.2): an rtst takes
22850 REM the next id (V(1)), its sid V(2) and n V(3) fields, which the next n rtfd records give (name
22855 REM H7, type V(1), an id mapped by sc_tfix); H6 the struct's T row, H5 the fields owed, H4 those
22860 REM read. Z = 1 for a violation ----------------------------------------------------------------
22865 SUB "rdst": N(), T(), W(), X(), X$(), V(), K0, H7, H6, H5, H4, Z
22870 LET Z = 0
22875 IF K0 = 69 THEN 22925
22880 IF V(1) <> X(32) + 1 THEN 22940
22885 LET X(19) = 0
22890 CALL "tnew": T(), N(), X(), X$(), 1 + INT((V(3) + 3) / 4), H6
22895 LET X(32) = V(1)
22900 LET W(150000 + V(1)) = H6
22905 LET H5 = V(3)
22910 LET H4 = 0
22915 IF H6 = 0 THEN 22945
22917 LET T(H6, 0) = 5
22918 LET T(H6, 1) = V(3)
22919 LET T(H6, 2) = V(2)
22920 LET T(H6, 3) = H7
22922 GOTO 22945
22925 LET H4 = H4 + 1
22927 LET H5 = H5 - 1
22930 IF H6 = 0 THEN 22945
22935 CALL "fds": T(), H6, H4, H7, V(1)
22937 GOTO 22945
22940 LET Z = 1
22945 SUBEND
22950 REM ---- fdtf: the field types of struct row R, read as ids, become T rows (sc_tfix): 0-9 or an id
22955 REM of the table; Z = 1 for a violation --------------------------------------------------------
22960 SUB "fdtf": T(), W(), X(), R, Z
22965 LET Z = 0
22970 FOR K = 1 TO T(R, 1)
22975 CALL "fdg": T(), R, K, A, B
22980 IF B < 10 THEN 22995
22985 IF B > X(32) THEN 22997
22990 CALL "fds": T(), R, K, A, W(150000 + B)
22995 NEXT K
22996 GOTO 22999
22997 LET Z = 1
22999 SUBEND
23000 REM ---- emtst: the type record of struct or record type Q with id 9 + J (tstruct id name n or trec
23005 REM id n, DESIGN 3.5.1), then its n fd records (name, type) in declaration order -------------
23010 SUB "emtst": T(), W(), X(), S$(), Q, J
23015 LET L$ = "trec " & STR$(9 + J)
23020 IF T(Q, 0) = 6 THEN 23035
23025 CALL "io_esc": S$(T(Q, 3)), 0, A$
23030 LET L$ = "tstruct " & STR$(9 + J) & " " & A$
23035 CALL "wr": X(), L$ & " " & STR$(T(Q, 1))
23040 FOR K = 1 TO T(Q, 1)
23045 CALL "fdg": T(), Q, K, G, D
23050 CALL "tyr": T(), W(), X(), D, B$
23055 CALL "io_esc": S$(G), 0, A$
23060 CALL "wr": X(), "fd " & A$ & " " & B$
23065 NEXT K
23070 SUBEND
23075 REM ---- emdot: the record of dot J (Q$ its position and type): view k, fld i or proj i (i from 0)
23080 SUB "emdot": N(), S$(), X(), J, Q$
23085 IF N(J, 1) > 0 THEN 23100
23090 CALL "wr": X(), "view" & Q$ & " " & S$(N(J, 6))
23095 GOTO 23110
23100 CALL "wr": X(), SEG$("fld proj", 4 * N(J, 2) + 1, 5 * N(J, 2) + 3) & Q$ & " " & STR$(N(J, 1) - 1)
23110 SUBEND
23115 REM ---- emslit: the slit of a struct or record literal J (Q$ its position and type), its values
23120 REM in declaration order (DESIGN 3.5.5). A literal written in another order than the source's
23125 REM (M(J,9) 1) first writes its values in declaration order, each bound one as lv of its .t
23130 REM local, each constant as itself, then the slit and the seq of its bindings at its position --
23135 SUB "emslit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, Q$
23140 LET H = N(J, 1)
23145 IF M(J, 9) = 0 THEN 23215
23150 LET H = T(M(J, 1), 1)
23155 LET B = 0
23160 FOR I = 1 TO H
23165 CALL "fdg": T(), M(J, 1), I, G, D
23170 LET A = N(J, 7)
23175 IF N(A, 6) = G THEN 23190
23180 LET A = N(A, 8)
23185 GOTO 23175
23190 LET V = N(A, 7)
23192 IF M(A, 4) > 0 THEN 23200
23195 CALL "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), V
23197 GOTO 23210
23200 LET B = B + 1
23202 CALL "pos": N(), V, P$
23204 CALL "cty": N(), M(), V, Q
23205 CALL "tyr": T(), W(), X(), Q, A$
23207 CALL "wr": X(), "lv " & P$ & " " & A$ & " " & STR$(X(40) + M(A, 4))
23210 NEXT I
23215 CALL "wr": X(), "slit" & Q$ & " " & STR$(H)
23220 IF M(J, 9) = 0 THEN 23230
23225 CALL "wr": X(), "seq" & Q$ & " " & STR$(B)
23230 SUBEND
23235 REM ---- cty: Q = the type of value V as written, after its cvt, dyn or fix (em_node) ----------
23240 SUB "cty": N(), M(), V, Q
23245 LET Q = M(V, 1)
23250 IF M(V, 7) = 0 THEN 23270
23255 LET Q = 4
23260 IF M(V, 7) = 1 THEN 23285
23265 LET Q = M(V, 7)
23267 GOTO 23285
23270 IF N(V, 0) < 27 THEN 23285
23275 IF N(V, 0) = 31 THEN 23285
23280 IF M(V, 5) < 10 THEN 23285
23282 LET Q = M(V, 5)
23285 SUBEND
23290 REM ---- emtmp: the .t locals of function S (DESIGN 3.5.4, 3.5.5 "Evaluation order"): the values
23295 REM ck_slit bound (M(init,4) > 0), numbered in the order of their bind records (= node order of
23300 REM their init nodes) in the body, from L + 1 (lids after the np + nl of the function), so that
23305 REM M(init,4) = its number; K = their count; Z = 1 also writes their loc records (mut let, the
23310 REM value's type, at the value's position) ------------------------------------------------------
23315 SUB "emtmp": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S, Z, K
23320 LET K = 0
23325 LET I = N(X(17), 7)
23330 IF S = 1 THEN 23350
23335 CALL "kid": N(), Y(S, 3), Y(S, 6) + Y(S, 7) + 1, I
23340 LET G = I
23345 GOTO 23360
23350 IF I = 0 THEN 23420
23352 LET G = I
23354 IF N(I, 0) = 2 THEN 23410
23356 IF N(I, 0) = 3 THEN 23410
23358 IF N(I, 0) = 5 THEN 23410
23360 FOR J = M(G, 0) TO G
23365 IF N(J, 0) <> 48 THEN 23400
23370 IF M(J, 4) = 0 THEN 23400
23375 LET K = K + 1
23380 LET M(J, 4) = K
23385 IF Z = 0 THEN 23400
23387 CALL "cty": N(), M(), N(J, 7), Q
23390 CALL "tyr": T(), W(), X(), Q, A$
23392 CALL "pos": N(), N(J, 7), P$
23395 CALL "wr": X(), "loc .t" & STR$(K) & " " & A$ & " let " & P$
23400 NEXT J
23405 IF S > 1 THEN 23420
23410 LET I = N(I, 8)
23415 GOTO 23350
23420 SUBEND
23425 REM ---- tyrf: the field types of struct or record type Q are numbered (tyr), in declaration order --
23430 SUB "tyrf": T(), W(), X(), Q
23435 FOR K = 1 TO T(Q, 1)
23440 CALL "fdg": T(), Q, K, G, D
23445 CALL "tyr": T(), W(), X(), D, A$
23450 NEXT K
23455 SUBEND
