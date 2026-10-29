50000 REM ====================================================================================
50002 REM sealoop part 10 (lines 50000-54999): L18, the inlining of prelude calls (DESIGN 3.5.9
50004 REM "What sealoop rewrites in 4h", 3.5.4, 3.6.6 rule 37; Decisions 53-57, L-u, L-v), and from
50005 REM 6b L20, the inlining of the calls of fn kind inl (DESIGN 2.11.4; Decision 83, L-cf, L-cg).
50006 REM A function whose fn pos is in file 0 of a stream of several files is a prelude function.
50007 REM 6c: kind elem as inl (7b: seafuse's L19 writes the element calls, inlined as any call).
50008 REM After (A), if there is one or an inl function, the records are rebuilt into the list O
50010 REM (text O$): each call of such a function F becomes its arguments, each followed by tmp P
50012 REM q (q a new local .p of the parameter's type, .q for a ref parameter, whose argument is
50014 REM the rarg as written), a copy of F's body (L18: every node at P, the call's position;
50015 REM L20: every node at its own position; ret as iret; L20: tret C as tbind P' k of new .i
50016 REM locals of C, their lv and iret P' k, P' its own position; F's parameters read as the q,
50017 REM its other locals as new locals .i; a call of such a function in the copy inlined the same
50018 REM way, D55), iblk P ty k and xblk P ty n; those functions are dropped and the fids
50019 REM renumbered (G(F,0): the new fid, 0 for a prelude function, -1 for an inl one). The .p
50020 REM and .i loc records follow the function's own (cursor L3), its nl grown at its end. Then
50022 REM (A) reads the new list again (A2 = 1); the walk makes each .p tmp a .l local (50800, U(p,0)
50024 REM the .p's entry of A); lp2out numbers the .i locals after the .l ones in the order of their
50026 REM declaring records (A(entry) = 100000 + i, above every type id) and rewrites the lids
50028 REM (52500). State: L4 the depth of the copy, per level s M(s,0) the call, M(s,1) the .i base,
50030 REM M(s,2) the row, M(s,3) the row whose pos is the level's P (negative for an inl callee,
50031 REM whose copy keeps its positions; a prelude call inside a prelude copy takes the outer P);
50032 REM H(X,8) of such a call its callee, H(X,7) the last row of node X in O, H(X,0) the .p of
50033 REM an argument; H9 S9 the nodes and locals of sea.hirl (SEA_LIM_NODES, SEA_LIM_SYMBOLS,
50034 REM reported at P, A2$). H6 the last lid of the function, H5 its new ones. V5 1 for inl.
50036 REM ---- the functions: new fids; a dropped function validated, its nodes and locals uncounted
50040 LET A4 = 0
50042 LET H9 = H0
50044 LET S9 = A0
50046 FOR Y1 = 1 TO G0
50048 LET G(Y1, 0) = Y1 - A4
50050 LET R2 = G(Y1, 6)
50052 LET F9 = 4
50054 GOSUB 8440
50055 LET Z1$ = F9$
50056 LET F9 = 8
50057 GOSUB 8440
50058 LET V5 = 0
50059 IF N1 < 2 THEN 50061
50060 IF SEG$(F9$, 1, 2) = "0:" THEN 50064
50061 IF POS("|inl|elem|", "|" & Z1$ & "|") = 0 THEN 50090
50062 LET V5 = 1
50063 REM a prelude function (V5 0) or an inl one (V5 1) is dropped
50064 LET A4 = A4 + 1
50065 LET G(Y1, 0) = -V5
50066 GOSUB 51600
50068 LET H9 = H9 - Y4 + R2 + G(Y1, 2) + G(Y1, 3) + 1
50070 LET S9 = S9 - G(Y1, 2) - G(Y1, 3)
50071 IF V5 = 1 THEN 50090
50072 REM a prelude function: kind fn, no tret, no ref parameter, a result type of 3.5.9
50073 IF Z1$ <> "fn" THEN 2900
50074 FOR R0 = R2 + 1 TO Y4
50075 IF R(P(R0, 0), 0) = 31 THEN 2900
50076 IF SEG$(D$(R0), 1, 4) <> "par " THEN 50080
50078 IF SEG$(D$(R0), LEN(D$(R0)) - 3, LEN(D$(R0))) = " ref" THEN 2900
50080 NEXT R0
50082 LET F9 = 5
50084 GOSUB 8440
50086 LET T4 = VAL(F9$)
50088 GOSUB 51700
50090 NEXT Y1
50092 IF A4 > 0 THEN 50100
50094 FOR Y1 = 1 TO G0
50096 LET G(Y1, 0) = 0
50098 NEXT Y1
50099 GOTO 5000
50100 REM ---- each call of a prelude function: H(X,8) its callee
50102 FOR X = 1 TO H0
50105 IF H(X, 1) <> 10 THEN 50115
50106 LET R2 = H(X, 6)
50108 LET F9 = 4
50110 GOSUB 8440
50111 LET Y1 = VAL(F9$)
50112 IF Y1 > G0 THEN 2900
50113 IF G(Y1, 0) > 0 THEN 50115
50114 LET H(X, 8) = Y1
50115 NEXT X
50120 REM ---- the new stream: the records in order (L4 = 0), or the rows of the copy of level L4
50122 LET O0 = 0
50124 LET O9 = 0
50126 LET O(0, 0) = 0
50128 LET L4 = 0
50130 LET R0 = 0
50132 LET V4 = 0
50140 IF L4 > 0 THEN 50200
50142 LET R0 = R0 + 1
50144 IF R0 > D0 THEN 50700
50146 LET K = R(P(R0, 0), 0)
50148 IF K = 33 THEN 50160
50150 IF K = 36 THEN 50186
50152 IF P(R0, 1) > 0 THEN 50300
50154 LET Z$ = D$(R0)
50156 GOSUB 51900
50158 GOTO 50140
50160 REM fn: a prelude function skipped to its end; else it and its par and loc records copied
50162 LET Y1 = P(R0, 1)
50164 IF G(Y1, 0) > 0 THEN 50170
50166 GOSUB 51600
50168 LET R0 = Y4
50169 GOTO 50140
50170 LET H7 = R0
50172 LET H5 = 0
50174 LET H6 = G(Y1, 2) + G(Y1, 3)
50176 FOR Y4 = H7 TO H7 + H6
50177 LET Z$ = D$(Y4)
50178 GOSUB 51900
50179 NEXT Y4
50181 LET H4 = O0 - H6
50182 LET R0 = H7 + H6
50183 LET L3 = O9
50184 GOTO 50140
50186 REM end: the fn record with its new fid and nl grown by the .p and .i locals (fields 2, 7)
50188 LET R2 = H7
50190 LET F9 = 7
50192 GOSUB 8440
50193 LET F9$ = STR$(VAL(F9$) + H5)
50194 LET Z$ = D$(H7)
50195 GOSUB 8470
50196 LET J3 = POS(Z$, " ")
50197 LET J4 = POS(Z$, " ", J3 + 1)
50198 LET O$(H4) = SEG$(Z$, 1, J3) & STR$(G(P(H7, 1), 0)) & SEG$(Z$, J4, LEN(Z$))
50199 GOTO 50154
50200 REM the next row of the copy; at F's end record: iblk P ty k and xblk P ty n (the call's value)
50202 LET M(L4, 2) = M(L4, 2) + 1
50204 LET R0 = M(L4, 2)
50206 LET X = M(L4, 0)
50208 LET Y1 = H(X, 8)
50210 GOSUB 51600
50212 IF R0 < Y4 THEN 50300
50213 LET V5 = 0
50214 IF M(L4, 3) > 0 THEN 50216
50215 LET V5 = 1
50216 LET L4 = L4 - 1
50217 LET R0 = M(L4, 2)
50218 LET R2 = H(X, 6)
50219 LET F9 = 3
50221 GOSUB 8440
50222 LET T4 = VAL(F9$)
50224 GOSUB 51700
50226 LET Z$ = "iblk " & A2$ & " " & STR$(T4) & " " & STR$(T5)
50228 GOSUB 51950
50230 LET Z$ = "xblk " & A2$ & " " & STR$(T4) & " " & STR$(G(Y1, 2))
50231 GOSUB 51950
50233 IF L4 = 0 THEN 50330
50234 GOSUB 51650
50235 GOTO 50330
50300 REM ---- a node: a prelude or inl call inlined (50400); else copied (in a copy by 52500, fid
50301 REM renumbered; a tret by 50340, a block with trets by 50480)
50302 LET X = P(R0, 1)
50304 IF H(X, 8) > 0 THEN 50400
50306 LET Z$ = D$(R0)
50308 IF L4 = 0 THEN 50316
50309 IF H(X, 1) = 31 THEN 50340
50310 IF H(X, 1) = 32 THEN 50480
50311 GOSUB 52500
50312 GOSUB 51950
50314 GOTO 50330
50316 IF R(P(R0, 0), 0) <> 10 THEN 50326
50318 LET R2 = R0
50320 LET F9 = 4
50322 GOSUB 8440
50323 LET F9$ = STR$(G(VAL(F9$), 0))
50324 GOSUB 8470
50326 GOSUB 51900
50330 LET H(X, 7) = O0
50332 GOTO 50140
50338 REM ---- L20 (3): a tret C of a copy: tbind P' k of k new .i locals (F's result types, loc pos
50339 REM P) of C, their lv at P' and iret P' k (P' the tret's own position)
50340 LET Y1 = H(M(L4, 0), 8)
50341 LET R2 = G(Y1, 6)
50342 LET F9 = 5
50343 GOSUB 8440
50344 LET T4 = VAL(F9$)
50345 IF T4 <= 9 THEN 2900
50346 IF T(T4, 1) + T(T4, 2) > 0 THEN 2900
50347 GOSUB 51770
50348 LET Y3 = R2
50349 LET F9 = 3
50350 GOSUB 8440
50351 LET T5 = VAL(F9$)
50352 LET R2 = R0
50353 LET F9 = 2
50354 GOSUB 8440
50355 LET Y8$ = F9$
50356 LET Y7$ = "tbind " & Y8$ & " " & STR$(T5)
50357 LET U4 = H6
50358 FOR Y4 = 1 TO T5
50359 LET R2 = Y3
50360 LET F9 = 3 + Y4
50361 GOSUB 8440
50362 LET Z$ = "loc .i " & F9$ & " let " & A2$
50363 GOSUB 51800
50364 LET Y7$ = Y7$ & " " & STR$(H6)
50365 NEXT Y4
50366 LET Z$ = Y7$
50367 GOSUB 51950
50368 FOR Y4 = 1 TO T5
50369 LET R2 = Y3
50370 LET F9 = 3 + Y4
50371 GOSUB 8440
50372 LET Z$ = "lv " & Y8$ & " " & F9$ & " " & STR$(U4 + Y4)
50373 GOSUB 51950
50374 NEXT Y4
50375 LET Z$ = "iret " & Y8$ & " " & STR$(T5)
50376 GOSUB 51950
50377 GOTO 50330
50400 REM ---- L18 / L20 (1)-(5) at the call X (row R0) of the function Y1: n = np, no cycle
50402 LET Y1 = H(X, 8)
50404 LET R2 = R0
50406 LET F9 = 5
50408 GOSUB 8440
50410 IF VAL(F9$) <> G(Y1, 2) THEN 2900
50412 FOR Y4 = 1 TO L4
50414 IF H(M(Y4, 0), 8) = Y1 THEN 2900
50416 NEXT Y4
50419 REM P (A2$): the call's own position, inside a prelude copy that copy's P (Y3 its row)
50420 LET Y3 = R0
50421 IF L4 > 0 THEN 50423
50422 LET H9 = H9 - 1
50423 IF M(L4, 3) <= 0 THEN 50425
50424 LET Y3 = M(L4, 3)
50425 LET R2 = Y3
50426 GOSUB 8400
50427 LET A2$ = P9$
50428 LET X1 = H(X, 3)
50429 REM each argument (of its parameter's type) followed by tmp P q, q a new local .p (a ref
50430 REM parameter's: .q, its argument a rarg, which no other parameter takes)
50431 FOR Y4 = 1 TO G(Y1, 2)
50432 IF H(X1, 2) <> A(G(Y1, 1) + Y4) THEN 2900
50433 LET Z$ = D$(G(Y1, 6) + Y4)
50434 LET Z1$ = ".p "
50435 IF SEG$(Z$, LEN(Z$) - 3, LEN(Z$)) <> " ref" THEN 50437
50436 LET Z1$ = ".q "
50437 IF H(X1, 1) <> 11 THEN 50439
50438 IF Z1$ = ".p " THEN 2900
50439 IF H(X1, 1) = 11 THEN 50441
50440 IF Z1$ = ".q " THEN 2900
50441 LET Z$ = "loc " & Z1$ & STR$(H(X1, 2)) & " let " & A2$
50442 GOSUB 51800
50443 LET H(X1, 0) = H6
50444 LET Z$ = "tmp " & A2$ & " " & STR$(H6)
50445 GOSUB 51960
50446 LET C9 = H(X1, 7)
50447 GOSUB 51910
50448 LET X1 = H(X1, 4)
50450 NEXT Y4
50452 REM a new local .i for each other local of F (its type and mut, pos P), from M(s,1) + 1 on
50454 LET U4 = H6
50456 FOR Y4 = 1 TO G(Y1, 3)
50458 LET R2 = G(Y1, 6) + G(Y1, 2) + Y4
50460 LET F9 = 5
50462 GOSUB 8440
50464 GOSUB 51822
50466 GOSUB 51800
50468 NEXT Y4
50469 LET M(L4, 2) = R0
50470 LET L4 = L4 + 1
50472 LET M(L4, 0) = X
50474 LET M(L4, 1) = U4
50476 LET M(L4, 2) = G(Y1, 6) + G(Y1, 2) + G(Y1, 3)
50477 LET M(L4, 3) = Y3 * (1 - 2 * ABS(G(Y1, 0)))
50478 GOTO 50140
50479 REM ---- a block of a copy: its n grown by one for each tret among its statements (L20 (3))
50480 LET Y3 = 0
50481 LET X1 = H(X, 3)
50482 IF X1 = 0 THEN 50487
50483 IF H(X1, 1) <> 31 THEN 50485
50484 LET Y3 = Y3 + 1
50485 LET X1 = H(X1, 4)
50486 GOTO 50482
50487 IF Y3 = 0 THEN 50311
50488 LET R2 = R0
50489 LET F9 = 3
50490 GOSUB 8440
50491 LET F9$ = STR$(VAL(F9$) + Y3)
50492 GOSUB 8470
50493 GOTO 50311
50700 REM ---- #end; then (A) reads the new stream (A2 = 1, tmp xblk iblk iret known: kinds 59-62)
50702 LET Z$ = "#end"
50704 GOSUB 51900
50706 FOR I = 1 TO Z(7)
50708 IF R(I, 1) <> 7 THEN 50714
50710 LET J2 = POS("|tmp=59|xblk=60|iblk=61|iret=62|", "|" & R$(I) & "=")
50712 IF J2 = 0 THEN 50714
50713 LET R(I, 0) = VAL(SEG$("|tmp=59|xblk=60|iblk=61|iret=62|", J2 + LEN(R$(I)) + 2, J2 + LEN(R$(I)) + 3))
50714 NEXT I
50716 LET A2 = 1
50718 LET D0 = 0
50720 LET H0 = 0
50722 LET G0 = 0
50724 LET A0 = 0
50726 LET Y9 = 9
50727 LET A6 = 0
50728 CALL "ly_init": C(), K(), K$(), K0, T9, A9, P$
50730 LET J8 = 0
50740 REM ---- the next record of the new stream (from 1290)
50742 LET J8 = O(J8, 0)
50744 LET L$ = O$(J8)
50746 GOTO 550
50800 REM ---- the walk: tmp P q of a .p local q becomes tmp P @p of a new .l local p (3.5.9 L18)
50801 REM (7b: a tmp of a .l local of sea.hirf is copied: that local is a new local from its fn, 8730)
50802 LET R2 = R1
50804 LET F9 = 3
50806 GOSUB 8440
50808 LET Y1 = VAL(F9$)
50809 IF SEG$(D$(G(F0, 6) + Y1), 1, 6) = "loc .l" THEN 5160
50810 LET S7 = S7 - 1
50812 LET G(F0, 3) = G(F0, 3) - 1
50814 LET G(F0, 0) = G(F0, 0) - 1
50816 LET U1 = A(G(F0, 1) + Y1)
50818 LET U2 = 0
50820 GOSUB 8100
50822 LET U(U0, 0) = G(F0, 1) + Y1
50824 GOSUB 8400
50826 LET N7 = N7 - 1
50828 LET Z$ = "tmp " & P9$ & " @" & STR$(U0)
50830 GOSUB 8050
50832 GOTO 5180
51600 REM ---- 51600: Y4 = the row of the end record of function Y1 (as read first)
51602 LET Y4 = D0
51604 IF Y1 = G0 THEN 51608
51606 LET Y4 = G(Y1 + 1, 6) - 1
51608 RETURN
51650 REM ---- 51650: A2$ = the P of level L4 (the pos of the row |M(L4,3)|)
51652 LET R2 = ABS(M(L4, 3))
51654 GOSUB 8400
51656 LET A2$ = P9$
51658 RETURN
51700 REM ---- 51700: T5 = the result count k of type T4 (0 void, n a ttuple, else 1); of a prelude
51702 REM function (V5 0) a scalar, str, a dynamic array or a ttuple of those (3.5.9 "What the passes
51703 REM validate"); of an inl one (V5 1) any result type (L20 (4))
51704 LET T5 = 0
51706 IF T4 = 1 THEN 51742
51708 LET T5 = 1
51710 LET U6 = T4
51712 IF T4 <= 9 THEN 51740
51714 IF T(T4, 1) > 0 THEN 51740
51716 IF T(T4, 2) > 0 THEN 51740
51718 GOSUB 51770
51724 LET F9 = 3
51726 GOSUB 8440
51728 LET T5 = VAL(F9$)
51730 FOR Y4 = 1 TO T5
51732 LET F9 = 3 + Y4
51734 GOSUB 8440
51736 LET U6 = VAL(F9$)
51738 GOSUB 51750
51739 NEXT Y4
51740 IF T5 = 1 THEN 51750
51742 RETURN
51750 REM ---- 51750: type U6 must be bool, i64, f64, str or a dynamic array (V5 1: any type)
51751 IF V5 = 1 THEN 51762
51752 IF U6 < 2 THEN 2900
51754 IF U6 <= 5 THEN 51762
51756 IF U6 <= 9 THEN 2900
51758 IF T(U6, 1) = 0 THEN 2900
51760 IF T(U6, 3) > 0 THEN 2900
51762 RETURN
51770 REM ---- 51770: R2 = the row of the ttuple record of type T4
51772 LET R2 = 0
51774 LET R2 = R2 + 1
51776 IF R2 > D0 THEN 2900
51778 IF SEG$(D$(R2), 1, 8 + LEN(STR$(T4))) <> "ttuple " & STR$(T4) & " " THEN 51774
51780 RETURN
51800 REM ---- 51800: a new local (its loc record Z$ at the cursor L3), H6 its lid; SEA_LIM_SYMBOLS
51802 LET H6 = H6 + 1
51804 LET H5 = H5 + 1
51806 LET S9 = S9 + 1
51808 LET Q2$ = "symbols"
51810 IF S9 > S8 THEN 51990
51812 LET C9 = L3
51814 GOSUB 51910
51816 LET L3 = O0
51818 RETURN
51819 REM ---- 51820: Z$ = the loc record of the local R2 of F in a copy: .i, pos P (A2$); 7b: a .l local
51820 REM (seafuse's) a .l local of the caller, renumbered with its own (8730): pos P under L18, its own
51821 REM under L20 (the pos of the old L19 local the copy of its emap made; DESIGN 2.12.3 (4), 109)
51822 LET Z$ = "loc .i" & SEG$(D$(R2), POS(D$(R2), " ", 5), J3) & A2$
51823 IF SEG$(D$(R2), 1, 6) <> "loc .l" THEN 51829
51824 LET Z$ = "loc .l" & SEG$(D$(R2), POS(D$(R2), " ", 5), J3) & A2$
51825 IF G(Y1, 0) = 0 THEN 51829
51826 LET Z$ = "loc .l" & SEG$(D$(R2), POS(D$(R2), " ", 5), LEN(D$(R2)))
51829 RETURN
51895 REM ---- 51900: Z$ at the tail; 51910 after the row C9; 51950 a node at the tail, 51960 its
51896 REM count against SEA_LIM_NODES (reported at P)
51900 LET C9 = O9
51910 GOSUB 8060
51912 LET O$(O0) = Z$
51914 RETURN
51950 GOSUB 51960
51952 GOTO 51900
51960 LET H9 = H9 + 1
51962 LET Q2$ = "nodes"
51964 IF H9 <= N8 THEN 51914
51990 LET P9$ = A2$
51992 GOTO 2930
52000 REM ---- 52000 (lp2out, A2 = 1): A(e) = -p for the .p entry e of each .l local p (50800)
52002 FOR Y4 = 1 TO U0
52004 IF U(Y4, 0) = 0 THEN 52008
52006 LET A(U(Y4, 0)) = -Y4
52008 NEXT Y4
52010 RETURN
52050 REM ---- 52050: of the function F0, D1 = np + its own nl (the lids below the .p and .i); I5 = 0
52052 LET D1 = G(F0, 2) + G(F0, 3) - G(F0, 0)
52054 LET I5 = 0
52056 RETURN
52100 REM ---- 52100: the .i locals the record Z$ declares (bind tbind forr tmp) numbered in turn
52102 IF A2 = 0 THEN 52056
52104 LET V4 = 2
52106 GOTO 52500
52200 REM ---- 52200 (lp2out, A2 + A3 > 0): the record R1 written, but not a .p .i or .l loc (52400, 10500);
52201 REM 7b: its tptr ids of sea.hirf as ^e (10900)
52202 LET Z$ = D$(R1)
52204 IF K <> 35 THEN 52208
52206 IF POS("|.p |.q |.i |", "|" & SEG$(Z$, 5, 7) & "|") > 0 THEN 10300
52207 IF SEG$(Z$, 5, 6) = ".l" THEN 10300
52208 LET V4 = 1
52210 GOSUB 52500
52211 GOSUB 10900
52212 LET Z1$ = Z$
52214 GOSUB 10805
52216 CALL "io_put": 2, Z$
52218 GOTO 10300
52300 REM ---- 52300: the generated record of row J as written (10800), its lids (and 7b tptr ids) rewritten if A2 + A3 > 0
52302 LET Z1$ = O$(J)
52304 IF A2 + A3 = 0 THEN 10805
52306 LET Z$ = Z1$
52308 LET V4 = 1
52310 GOSUB 52500
52311 GOSUB 10900
52312 LET Z1$ = Z$
52314 GOTO 10805
52400 REM ---- 52400: the loc records of the .i locals of F0, in lid order (after the .l locals)
52402 FOR I5 = 1 TO G(F0, 0)
52404 LET U4 = D1
52406 LET U4 = U4 + 1
52408 LET R2 = G(F0, 6) + U4
52410 IF SEG$(D$(R2), 1, 4) = "loc " THEN 52414
52412 CALL "dg_bug": P$, "an .i local has no declaring record"
52414 IF A(G(F0, 1) + U4) <> 100000 + I5 THEN 52406
52416 CALL "io_put": 2, "loc .i" & STR$(I5) & SEG$(D$(R2), 7, LEN(D$(R2)))
52418 NEXT I5
52420 RETURN
52500 REM ---- 52500: the record Z$ rewritten. V4 0: a node of the copy of level L4 (L18 pos P, ret as
52502 REM iret, a call's fid renumbered, F's parameters the .p and its locals the .i from M(s,1) + 1);
52504 REM 1: as written (a .p as @p, an .i numbered after the .l locals); 2: the .i it declares
52506 REM numbered, Z$ kept. Lid fields (passes.txt): lv 4, bind forr fore tmp hloop 3, tbind 4 on, rcnt 4 5.
52508 LET J2 = POS(Z$ & " ", " ")
52510 LET J2 = POS("|lv=4|bind=3|forr=3|fore=3|tmp=3|tbind=4|hloop=3|rcnt=4|", "|" & SEG$(Z$, 1, J2 - 1) & "=")
52512 IF V4 = 0 THEN 52520
52514 IF J2 = 0 THEN 52590
52516 IF V4 = 1 THEN 52520
52518 IF SEG$(Z$, 1, 3) = "lv " THEN 52590
52520 CALL "io_split": Z$, G$(), 300, C0
52522 IF V4 > 0 THEN 52534
52523 IF M(L4, 3) < 0 THEN 52526
52524 LET G$(2) = A2$
52526 IF G$(1) <> "ret" THEN 52530
52528 LET G$(1) = "iret"
52530 IF G$(1) <> "call" THEN 52534
52532 LET G$(4) = STR$(G(VAL(G$(4)), 0))
52534 IF J2 = 0 THEN 52580
52536 LET T4 = VAL(SEG$("|lv=4|bind=3|forr=3|fore=3|tmp=3|tbind=4|hloop=3|rcnt=4|", J2 + LEN(G$(1)) + 2, J2 + LEN(G$(1)) + 2))
52538 LET T5 = T4
52540 IF G$(1) <> "tbind" THEN 52543
52542 LET T5 = C0
52543 IF G$(1) <> "rcnt" THEN 52546
52544 LET T5 = 5
52546 FOR I4 = T4 TO T5
52548 IF POS("0123456789", SEG$(G$(I4), 1, 1)) = 0 THEN 52579
52550 LET U4 = VAL(G$(I4))
52552 IF V4 = 0 THEN 52570
52554 IF U4 <= D1 THEN 52579
52556 LET U6 = A(G(F0, 1) + U4)
52558 IF V4 = 2 THEN 52566
52560 IF U6 >= 0 THEN 52564
52562 LET G$(I4) = "@" & STR$(-U6)
52564 IF U6 <= 100000 THEN 52579
52565 LET G$(I4) = STR$(D1 + G(F0, 4) + U6 - 100000)
52566 IF U6 < 1 THEN 52579
52567 IF U6 > 100000 THEN 52579
52568 LET I5 = I5 + 1
52569 LET A(G(F0, 1) + U4) = 100000 + I5
52570 IF V4 > 0 THEN 52579
52571 LET Y1 = H(M(L4, 0), 8)
52572 LET G$(I4) = STR$(M(L4, 1) + U4 - G(Y1, 2))
52573 IF U4 > G(Y1, 2) THEN 52579
52574 LET X1 = H(M(L4, 0), 3)
52575 FOR U6 = 2 TO U4
52576 LET X1 = H(X1, 4)
52577 NEXT U6
52578 LET G$(I4) = STR$(H(X1, 0))
52579 NEXT I4
52580 IF V4 = 2 THEN 52590
52582 LET Z$ = G$(1)
52584 FOR I4 = 2 TO C0
52586 LET Z$ = Z$ & " " & G$(I4)
52588 NEXT I4
52590 RETURN
