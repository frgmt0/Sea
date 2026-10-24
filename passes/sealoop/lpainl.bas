50000 REM ====================================================================================
50002 REM sealoop part 10 (lines 50000-54999): L18, the inlining of prelude calls (DESIGN 3.5.9
50004 REM "What sealoop rewrites in 4h", 3.5.4, 3.6.6 rule 37; Decisions 53-57, L-u, L-v). A function
50006 REM whose fn pos is in file 0 of a stream of several files is a prelude function. After (A),
50008 REM if there is one, the records are rebuilt into the list O (text O$): each call of a prelude
50010 REM function F becomes its arguments, each followed by tmp P q (q a new local .p of the
50012 REM parameter's type), a copy of F's body (every node at P, the call's position; ret as iret;
50014 REM F's parameters read as the q, its other locals as new locals .i; a prelude call in the
50016 REM copy inlined the same way, D55), iblk P ty k and xblk P ty n; the prelude functions are
50018 REM dropped and the fids renumbered (G(F,0): the new fid, 0 for a prelude function). The .p
50020 REM and .i loc records follow the function's own (cursor L3), its nl grown at its end. Then
50022 REM (A) reads the new list again (A2 = 1); the walk makes each .p tmp a .l local (50800, U(p,0)
50024 REM the .p's entry of A); lp2out numbers the .i locals after the .l ones in the order of their
50026 REM declaring records (A(entry) = 100000 + i, above every type id) and rewrites the lids
50028 REM (52500). State: L4 the depth of the copy, per level s M(s,0) the call, M(s,1) the .i base,
50030 REM M(s,2) the row; H(X,8) of a prelude call its callee, H(X,7) the last row of node X in O,
50032 REM H(X,0) the .p of an argument; H9 S9 the nodes and locals of sea.hirl (SEA_LIM_NODES,
50034 REM SEA_LIM_SYMBOLS, reported at P, A2$). H6 the last lid of the function, H5 its new ones.
50036 REM ---- the functions: new fids; a prelude function validated, its nodes and locals uncounted
50040 LET A4 = 0
50042 LET H9 = H0
50044 LET S9 = A0
50046 FOR Y1 = 1 TO G0
50048 LET G(Y1, 0) = Y1 - A4
50050 LET R2 = G(Y1, 6)
50052 LET F9 = 8
50054 GOSUB 8440
50056 IF N1 < 2 THEN 50090
50058 IF SEG$(F9$, 1, 2) <> "0:" THEN 50090
50060 LET A4 = A4 + 1
50062 LET G(Y1, 0) = 0
50066 GOSUB 51600
50068 LET H9 = H9 - Y4 + R2 + G(Y1, 2) + G(Y1, 3) + 1
50070 LET S9 = S9 - G(Y1, 2) - G(Y1, 3)
50071 REM no tret, no ref parameter, a result type of 3.5.9 (kind elem: 1450)
50072 FOR R0 = R2 + 1 TO Y4
50074 IF R(P(R0, 0), 0) = 31 THEN 2900
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
50104 IF H(X, 1) <> 10 THEN 50115
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
50214 LET L4 = L4 - 1
50215 LET R0 = M(L4, 2)
50216 LET R2 = H(X, 6)
50218 LET F9 = 3
50220 GOSUB 8440
50222 LET T4 = VAL(F9$)
50224 GOSUB 51700
50226 LET Z$ = "iblk " & A2$ & " " & STR$(T4) & " " & STR$(T5)
50228 GOSUB 51950
50230 LET Z$ = "xblk " & A2$ & " " & STR$(T4) & " " & STR$(G(Y1, 2))
50232 GOSUB 51950
50234 GOTO 50330
50300 REM ---- a node: a prelude call inlined (50400); else copied (in a copy by 52500, fid renumbered)
50302 LET X = P(R0, 1)
50304 IF H(X, 8) > 0 THEN 50400
50306 LET Z$ = D$(R0)
50308 IF L4 = 0 THEN 50316
50310 GOSUB 52500
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
50400 REM ---- L18 (1)-(5) at the call X (row R0) of the prelude function Y1: n = np, no cycle
50402 LET Y1 = H(X, 8)
50404 LET R2 = R0
50406 LET F9 = 5
50408 GOSUB 8440
50410 IF VAL(F9$) <> G(Y1, 2) THEN 2900
50412 FOR Y4 = 1 TO L4
50414 IF H(M(Y4, 0), 8) = Y1 THEN 2900
50416 NEXT Y4
50418 IF L4 > 0 THEN 50426
50420 GOSUB 8400
50422 LET A2$ = P9$
50424 LET H9 = H9 - 1
50426 REM each argument (of its parameter's type) followed by tmp P q, q a new local .p
50428 LET X1 = H(X, 3)
50430 FOR Y4 = 1 TO G(Y1, 2)
50432 IF H(X1, 2) <> A(G(Y1, 1) + Y4) THEN 2900
50434 LET Z$ = "loc .p " & STR$(H(X1, 2)) & " let " & A2$
50436 GOSUB 51800
50438 LET H(X1, 0) = H6
50440 LET Z$ = "tmp " & A2$ & " " & STR$(H6)
50442 GOSUB 51960
50444 LET C9 = H(X1, 7)
50446 GOSUB 51910
50448 LET X1 = H(X1, 4)
50450 NEXT Y4
50452 REM a new local .i for each other local of F (its type and mut, pos P), from M(s,1) + 1 on
50454 LET U4 = H6
50456 FOR Y4 = 1 TO G(Y1, 3)
50458 LET R2 = G(Y1, 6) + G(Y1, 2) + Y4
50460 LET F9 = 5
50462 GOSUB 8440
50464 LET Z$ = "loc .i" & SEG$(D$(R2), POS(D$(R2), " ", 5), J3) & A2$
50466 GOSUB 51800
50468 NEXT Y4
50469 LET M(L4, 2) = R0
50470 LET L4 = L4 + 1
50472 LET M(L4, 0) = X
50474 LET M(L4, 1) = U4
50476 LET M(L4, 2) = G(Y1, 6) + G(Y1, 2) + G(Y1, 3)
50478 GOTO 50140
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
50728 CALL "ly_init": C(), K(), K$(), K0, T9, A9, P$
50730 LET J8 = 0
50740 REM ---- the next record of the new stream (from 1290)
50742 LET J8 = O(J8, 0)
50744 LET L$ = O$(J8)
50746 GOTO 550
50800 REM ---- the walk: tmp P q of a .p local q becomes tmp P @p of a new .l local p (3.5.9 L18)
50802 LET R2 = R1
50804 LET F9 = 3
50806 GOSUB 8440
50808 LET Y1 = VAL(F9$)
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
51700 REM ---- 51700: T5 = the result count k of type T4 (0 void, n a ttuple, else 1), which must be
51702 REM a scalar, str, a dynamic array or a ttuple of those (3.5.9 "What the passes validate")
51704 LET T5 = 0
51706 IF T4 = 1 THEN 51742
51708 LET T5 = 1
51710 LET U6 = T4
51712 IF T4 <= 9 THEN 51740
51714 IF T(T4, 1) > 0 THEN 51740
51716 IF T(T4, 2) > 0 THEN 2900
51718 LET R2 = 0
51720 LET R2 = R2 + 1
51721 IF R2 > D0 THEN 2900
51722 IF SEG$(D$(R2), 1, 8 + LEN(STR$(T4))) <> "ttuple " & STR$(T4) & " " THEN 51720
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
51750 REM ---- 51750: type U6 must be bool, i64, f64, str or a dynamic array
51752 IF U6 < 2 THEN 2900
51754 IF U6 <= 5 THEN 51762
51756 IF U6 <= 9 THEN 2900
51758 IF T(U6, 1) = 0 THEN 2900
51760 IF T(U6, 3) > 0 THEN 2900
51762 RETURN
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
52200 REM ---- 52200 (lp2out, A2 = 1): the record R1 written, but not a .p or .i loc (52400, 10500)
52202 LET Z$ = D$(R1)
52204 IF K <> 35 THEN 52208
52206 IF POS("|.p |.i |", "|" & SEG$(Z$, 5, 7) & "|") > 0 THEN 10300
52208 LET V4 = 1
52210 GOSUB 52500
52212 LET Z1$ = Z$
52214 GOSUB 10805
52216 CALL "io_put": 2, Z$
52218 GOTO 10300
52300 REM ---- 52300: the generated record of row J as written (10800), its lids rewritten if A2 = 1
52302 LET Z1$ = O$(J)
52304 IF A2 = 0 THEN 10805
52306 LET Z$ = Z1$
52308 LET V4 = 1
52310 GOSUB 52500
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
52500 REM ---- 52500: the record Z$ rewritten. V4 0: a node of the copy of level L4 (pos P, ret as
52502 REM iret, a call's fid renumbered, F's parameters the .p and its locals the .i from M(s,1) + 1);
52504 REM 1: as written (a .p as @p, an .i numbered after the .l locals); 2: the .i it declares
52506 REM numbered, Z$ kept. Lid fields (passes.txt): lv 4, bind forr fore tmp 3, tbind 4 on.
52508 LET J2 = POS(Z$ & " ", " ")
52510 LET J2 = POS("|lv=4|bind=3|forr=3|fore=3|tmp=3|tbind=4|", "|" & SEG$(Z$, 1, J2 - 1) & "=")
52512 IF V4 = 0 THEN 52520
52514 IF J2 = 0 THEN 52590
52516 IF V4 = 1 THEN 52520
52518 IF SEG$(Z$, 1, 3) = "lv " THEN 52590
52520 CALL "io_split": Z$, G$(), 300, C0
52522 IF V4 > 0 THEN 52534
52524 LET G$(2) = A2$
52526 IF G$(1) <> "ret" THEN 52530
52528 LET G$(1) = "iret"
52530 IF G$(1) <> "call" THEN 52534
52532 LET G$(4) = STR$(G(VAL(G$(4)), 0))
52534 IF J2 = 0 THEN 52580
52536 LET T4 = VAL(SEG$("|lv=4|bind=3|forr=3|fore=3|tmp=3|tbind=4|", J2 + LEN(G$(1)) + 2, J2 + LEN(G$(1)) + 2))
52538 LET T5 = T4
52540 IF G$(1) <> "tbind" THEN 52546
52542 LET T5 = C0
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
