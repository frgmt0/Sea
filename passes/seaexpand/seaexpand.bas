10 REM ====================================================================================
15 REM seaexpand -- pass 2b: sea.hir1 -> sea.hir (docs/DESIGN.md 2.1, 3.5.6, 3.5.7, 2.8)
20 REM A Baysick program built like every pass (DESIGN 2.6.3): this file (lines 1-59999), the
25 REM modules io diag tables limb f64emu, the DATA blocks errors exits consts records, END.
40 REM
45 REM WHAT IT DOES (DESIGN 3.5.7, the steps that apply to phase 1)
47 REM  0 validation first: every field against passes.txt (enum words tb_word, positions io_pos,
48 REM    bytes 0x20-0x7E io_plain), the types of every node it folds, a cref's type = its cn's
50 REM  1 constant substitution: each cref becomes a copy of its constant's leaf (pass 2a wrote it),
55 REM    at the position of the cref; the cn records are not written. A cref in a function
57 REM    may name a cn written later: every cn precedes the functions, and its child is one leaf
58 REM    (ci cf cb cs, DESIGN 3.5.2), so the pool holds one record per cid, written by the cn
60 REM  2 folding, bottom-up, only subtrees that are constant on their own, for ANY operand values
65 REM    (no guard, DESIGN 2.8: inf, nan, overflow, underflow are exact in f64emu): f64 add sub
70 REM    mul div (FEADD FESUB FEMUL FEDIV), powk k (the pinned FEMULs, then FEDIV for k < 0),
75 REM    un neg (FENEG / LMNEG), lib sqrt (FESQR), i64 add sub mul (LMADD LMSUB LMMUL; an
80 REM    overflow stays for run time), cvt of an i64 constant (FEFRI, ties to even). A folded
85 REM    subtree is one ci/cf at its root's position. Never folded: comparisons, logic, %, pow,
90 REM    i64 division, anything transcendental, conversion to i64.
92 REM  3 (6c) elemental instantiation, at #end over every function in file order (5340): a call of an
93 REM    elem function with an array argument at an elemental (f64 i64 bool) parameter becomes an emap of
94 REM    the instance of its argument types (3.5.3), same position, type, arguments; G12 (2.11.3) checks
95 REM    its count and types against the parameters, and (implementer reading) its type against the results
96 REM  5 reachability from .main through call records and the instances of emap records; functions and
97 REM    instances renumbered densely in their old order; types renumbered by first reference (3.5.1:
98 REM    the inst records first, then the functions); unreferenced types dropped
105 REM  4 (6d) write_json expansion, in the stream (5700, 6000): an eval of lib write_json(path, value) at P becomes
106 REM    block P: bind J1 = path; bind J2 = value; jopen (lv J1); emit(lv J2); jclose, every new node at P; emit by
107 REM    type (JSON scalars f64 i64 bool str: jval; struct/record: jobj, jkey + emit(fld) per field, jend; vectors
108 REM    and matrices of JSON scalars: jvec / jmat, through a dyn when fixed-size (L-ce); a vector of structs: jarr,
109 REM    fore K, jend; a matrix of structs: the guarded forr R / forr C form, empty -> [] (L-cv)). The .j locals
110 REM    (lids after the par, loc and .t locals) are numbered in the file order of their declaring bind/fore/forr
111 REM    records (3.5.4) and written after the function's last loc record, its nl raised (5850, 5860, 5880).
115 REM The fn kinds elem (6c) and inl (6b) are kept unchanged.
121 REM Phase 4d (G12, 3.5.7): array type records (element a scalar, str or struct; fixed extents fit LIM_FIXED_ELEMS),
122 REM idx (n = rank of the base, or 1 for a bool-matrix mask; index kinds of LANGUAGE 5.2), dol (claimed by the idx it
123 REM sits in, dim < n; none left at a function end), fore (vector iterable, loop variable of the element type) are
124 REM validated (BAD_RECORD) and copied; array records otherwise pass through the generic path (4500-4966).
125 REM
126 REM Phase 4e (G12): view (the operand's rank), arr (row children), row (n >= 1), dyn and fix (the corresponding
127 REM fixed and dynamic types), the target of an asg (an lv, idx or view flat tree of an lv) are validated (5000-5158).
128 REM Phase 4g-1 (G12): match (a str scrutinee, arm children, the last arm _) and arm (k cs patterns) (5160-5185).
129 REM Phase 4g-2 (G12): fld and proj (the field exists; proj of a scalar or str field of a vector), slit (n = fields) (5186-5234).
130 REM TABLES  (arrays one letter; DIM below)
135 REM  E E$ errors  N N$ W$ enums  R R$ records  F F$ fields  Z counts  C C$ constants
140 REM  V special code of a record row, A its ty field index, B the rows of sea.hir1 (sets H H1)
145 REM  G$ fields of the current record  U their u values  H$ #file paths
150 REM  O$ out records  M out kind(0) high32(1) low32(2) row(3): kind 1 ci 2 cf 3 call 0 other
155 REM  S stack of subtree starts (post-order trees)  Q$ J the const pool (the leaf of cid i in row i:
160 REM  text, M-like)  L per cid: pool rows 0-1, ty 2  T P K$ Y$ types (kind, offset, count,
165 REM  extents; component ids; field names; struct names)  K function table (elem 1 (0), first record,
170 REM  last record, new fid)  Y new type id  O old type id of each new id  D work stack  X elemental
172 REM  instances (fid, rty, n, the P row before its argument types, new iid); P after the type components
173 REM  also holds each call's argument types (from X7), M(.,2) of a call the P row before them
174 REM  (M kind 4: an emap, M(.,1) its instance)
175 REM
180 REM SCALARS  P$ pass name  L$ record  L0 its line  C0 its fields  I0 its row  Y0 its code
185 REM  S0 stack depth  O0 out records  N9 cn count  S7 T7 LIM_SYMBOLS LIM_TYPES  T9 types  F6 functions  F7 inside a function
190 REM  F5 a function was seen  X8 fd records owed  S3 start of the node being made  K1 kind
195 REM  A3-A0 B3-B0 R3-R0 limbs of operands and result  T$ text  Z8$ last position
200 REM special codes of V: 1-7 tvec tmat tfvec tfmat tstruct trec ttuple, 8 fd, 9 cn, 11 fn,
205 REM  12 par, 13 loc, 14 end, 15 ci, 16 cf, 17 cref, 18 cvt, 19 un, 20 bin, 21 call, 22 lib, 23 powk,
207 REM  24 dol, 25 fore, 26 idx, 27 view, 28 arr, 29 row, 30 dyn, 31 fix, 32 asg, 33 match, 34 arm, 35 fld,
208 REM  36 proj, 37 slit, 38 eval
209 REM (6d) G H Q I$ V$: loop placeholders + block counters, per fn .j locals (V$ row, count, par+loc), tasks, pool, .j locs (5700-6996)
210 REM ====================================================================================
215 FILES "sea.hir1"; "sea.hir"
220 DIM E(299), E$(299,5), N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), Z(8)
225 DIM C(299,4), C$(299), G$(300), U(300), H$(100), V(399), A(399), B(399), A$(1)
230 DIM M(249999,3), O$(249999), S(249999)
235 DIM T(20010,5), P(399999), K$(399999), Y$(20010), Y(20010), D(50010,1), K(50010,3), O(20010)
240 DIM J(49999,3), Q$(49999), L(49999,2), X(49999,4)
242 DIM G(49999,2), H(50010,2), Q(49999,4), I$(99999), V$(49999)
245 LET P$ = "seaexpand"
250 REM ---- the tables ---------------------------------------------------------------------
255 CALL "tb_errors": P$, E(), E$(), 299, E0
260 CALL "tb_exits": P$, E(), E$(), E0, Y(), Y$(), 39, N6
265 CALL "tb_consts": P$, E(), E$(), E0, C(), C$(), 299, N5
270 LET Z(1) = 39
275 LET Z(2) = 299
280 LET Z(3) = 399
285 LET Z(4) = 1499
290 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), R(), R$(), F(), F$(), Z()
295 FOR I = 1 TO N6
300 LET Y(I) = 0
305 LET Y$(I) = ""
310 NEXT I
315 CALL "tb_cval": C(), C$(), N5, "FILE_VERSION", V9, W1
320 IF W1 = 0 THEN 330
325 CALL "dg_bug": P$, "constant FILE_VERSION is not in the consts table"
330 REM LIM_POWK: the largest |k| of a powk (LANGUAGE 6.5); LIM_SYMBOLS, LIM_TYPES for the capacity checks (4400)
331 CALL "tb_cval": C(), C$(), N5, "LIM_POWK", V8, W1
332 IF W1 = 0 THEN 335
333 CALL "dg_bug": P$, "constant LIM_POWK is not in the consts table"
334 REM special code and ty field index of each record row of the HIR files (sets H and H1)
335 LET K1$ = "|tvec=01|tmat=02|tfvec=03|tfmat=04|tstruct=05|trec=06|ttuple=07|fd=08|cn=09|fn=11|par=12|loc=13|end=14|"
340 LET K2$ = "|ci=15|cf=16|cref=17|cvt=18|un=19|bin=20|call=21|lib=22|powk=23|dol=24|fore=25|idx=26|"
342 LET K2$ = K2$ & "view=27|arr=28|row=29|dyn=30|fix=31|asg=32|"
341 GOSUB 4400
343 LET K2$ = K2$ & "match=33|arm=34|fld=35|proj=36|slit=37|eval=38|"
345 LET N2 = 0
350 LET R5 = 0
355 LET R6 = 0
360 FOR I = 1 TO Z(7)
365 LET V(I) = 0
370 LET A(I) = 0
375 IF R(I, 1) < 2 THEN 475
380 IF R(I, 1) > 3 THEN 475
385 LET N2 = N2 + 1
390 LET B(N2) = I
395 LET W1 = POS(K1$, "|" & R$(I) & "=")
400 IF W1 > 0 THEN 425
405 LET W1 = POS(K2$, "|" & R$(I) & "=")
410 IF W1 = 0 THEN 430
415 LET V(I) = VAL(SEG$(K2$, W1 + LEN(R$(I)) + 2, W1 + LEN(R$(I)) + 3))
420 GOTO 430
425 LET V(I) = VAL(SEG$(K1$, W1 + LEN(R$(I)) + 2, W1 + LEN(R$(I)) + 3))
430 IF V(I) <> 15 THEN 440
435 LET R5 = I
440 IF V(I) <> 16 THEN 450
445 LET R6 = I
450 FOR J1 = 1 TO R(I, 4)
455 IF F(R(I, 3) + J1 - 1, 1) = 8 THEN 470
460 NEXT J1
465 GOTO 475
470 LET A(I) = J1
475 NEXT I
480 IF R5 > 0 THEN 490
485 CALL "dg_bug": P$, "record ci is not in the records table"
490 IF R6 > 0 THEN 500
495 CALL "dg_bug": P$, "record cf is not in the records table"
500 REM ---- the header: io_hdr leaves the first body record in L$ (line N1 + 3) ----
505 CALL "io_hdr": 1, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), V9, G0$, H$(), 100, N1, L$
510 LET L0 = N1 + 3
515 REM ---- one record per round: L$ is line L0 -------------------------------------------------
520 LET Z8$ = STR$(N1 - 1) & ":1:1"
525 LET O0 = 0
530 LET S0 = 0
535 LET D$ = "BAD_RECORD"
536 CALL "io_plain": L$, W1
537 LET M$ = "a byte outside 0x20-0x7E"
538 IF W1 = 0 THEN 2915
539 LET Z7$ = ""
540 CALL "io_split": L$, G$(), 300, C0
545 LET M$ = "empty record, a blank at its start or end, two blanks in a row, or too many fields"
550 IF C0 < 1 THEN 2915
555 IF G$(1) = "#end" THEN 2245
560 LET I0 = 0
565 FOR I = 1 TO N2
570 IF R$(B(I)) <> G$(1) THEN 585
575 LET I0 = B(I)
580 GOTO 600
585 NEXT I
590 LET M$ = "unknown opcode '" & G$(1) & "' for sea.hir1"
595 GOTO 2915
600 LET Y0 = V(I0)
601 REM (6d) a lib write_json is the child of an eval: the record after it must be that eval (5700)
602 LET M$ = "a lib write_json that is not the child of an eval"
603 IF J9 = 0 THEN 605
604 IF Y0 <> 38 THEN 2915
605 REM the u-like fields: U(j) = the value of the j-th field, tokens counted with the repeats
610 LET T0 = 1
615 FOR J1 = 1 TO R(I0, 4)
620 LET B0 = R(I0, 3) + J1 - 1
625 LET U(J1) = 0
630 LET X0 = 1
635 IF F(B0, 3) = 0 THEN 645
640 LET X0 = U(F(B0, 3))
645 FOR X1 = 1 TO X0
650 LET T0 = T0 + 1
655 IF T0 <= C0 THEN 670
660 LET M$ = "too few fields: " & F$(B0) & " is missing"
665 GOTO 2915
670 GOSUB 3600
720 NEXT X1
725 NEXT J1
730 LET M$ = "too many fields"
735 IF T0 < C0 THEN 2915
740 LET Z7 = 0
745 IF LEN(Z7$) = 0 THEN 760
748 LET Z7 = 1
750 LET Z8$ = Z7$
760 IF X8 = 0 THEN 775
765 LET M$ = "fd record expected after tstruct / trec"
770 IF Y0 <> 8 THEN 2915
775 IF Y0 = 0 THEN 900
780 IF Y0 < 8 THEN 1935
785 IF Y0 = 8 THEN 2190
790 IF Y0 = 15 THEN 935
795 IF Y0 = 16 THEN 965
800 IF Y0 = 17 THEN 1015
805 IF Y0 = 18 THEN 1455
810 IF Y0 = 19 THEN 1500
815 IF Y0 = 20 THEN 1585
820 IF Y0 = 21 THEN 1885
825 IF Y0 = 22 THEN 1800
826 IF Y0 = 23 THEN 1700
827 IF Y0 = 24 THEN 4600
828 IF Y0 = 25 THEN 4650
829 IF Y0 = 26 THEN 4700
830 IF Y0 = 9 THEN 1115
831 IF Y0 > 26 THEN 5000
835 IF Y0 = 11 THEN 1260
840 IF Y0 = 14 THEN 1375
845 REM par (12) and loc (13): declarations of the open function, no node
850 LET M$ = "par or loc outside a function"
855 IF F7 = 0 THEN 2915
860 LET M$ = "more par and loc records than np + nl"
865 IF X9 = 0 THEN 2915
870 LET X9 = X9 - 1
875 LET K1 = 0
880 LET T$ = L$
885 GOSUB 3070
890 GOTO 1920
895 REM ---- generic node: pop the children, append, push -----------------------------------------
900 GOSUB 2980
905 LET K1 = 0
910 LET T$ = L$
915 GOSUB 3070
920 GOSUB 3150
925 GOTO 1920
930 REM ---- ci / cf: a constant leaf, its bits kept for folding -----------------------------------
935 LET S3 = O0 + 1
940 CALL "LMRD": G$(4), R3, R2, R1, R0, W1
945 LET M$ = "bad i64 field"
950 IF W1 <> 0 THEN 2915
955 LET K1 = 1
960 GOTO 986
965 LET S3 = O0 + 1
970 CALL "LMRF": G$(4), R3, R2, R1, R0, W1
975 LET M$ = "bad f64 field"
980 IF W1 <> 0 THEN 2915
985 LET K1 = 2
986 LET M$ = "a ci not typed i64 (3) or a cf not typed f64 (4)"
987 IF U(2) <> 2 + K1 THEN 2915
990 LET T$ = L$
995 GOSUB 3070
1000 GOSUB 3150
1005 GOTO 1920
1010 REM ---- cref: a copy of the constant's leaf at the position of the cref ---------------------------
1015 LET D$ = "BAD_TREE"
1020 LET M$ = "cref names a constant that is not defined"
1025 IF U(3) < 1 THEN 2915
1030 IF U(3) > N9 THEN 2915
1032 LET D$ = "BAD_RECORD"
1033 LET M$ = "cref of type " & STR$(U(2)) & " names a constant of type " & STR$(L(U(3), 2))
1034 IF U(2) <> L(U(3), 2) THEN 2915
1035 LET S3 = O0 + 1
1040 LET Z$ = G$(2)
1045 FOR K9 = L(U(3), 0) TO L(U(3), 1)
1050 LET T$ = Q$(K9)
1055 GOSUB 3320
1060 LET K1 = J(K9, 0)
1065 LET I0 = J(K9, 3)
1070 LET R3 = INT(J(K9, 1) / 65536)
1075 LET R2 = J(K9, 1) - R3 * 65536
1080 LET R1 = INT(J(K9, 2) / 65536)
1085 LET R0 = J(K9, 2) - R1 * 65536
1090 GOSUB 3070
1095 NEXT K9
1100 GOSUB 3150
1105 GOTO 1920
1110 REM ---- cn: its value, one leaf (3.5.2), moves to the constant pool, nothing is written -----------
1115 LET M$ = "cn after the first function"
1120 IF F5 = 1 THEN 2915
1125 GOSUB 2980
1130 LET D$ = "BAD_TREE"
1135 LET M$ = "cn does not follow exactly its value, one ci cf cb or cs leaf"
1140 IF S0 <> 0 THEN 2915
1141 IF O0 <> S3 THEN 2915
1142 IF POS("|ci|cf|cb|cs|", "|" & P7$ & "|") = 0 THEN 2915
1145 LET D$ = "BAD_RECORD"
1150 LET M$ = "cn ids are not 1, 2, ..."
1155 IF U(1) <> N9 + 1 THEN 2915
1156 LET T$ = O$(S3)
1157 LET T1 = 3
1158 GOSUB 3345
1159 LET M$ = "the value of cn " & STR$(U(1)) & " is typed " & Z$ & ", the cn " & STR$(U(3))
1160 IF VAL(Z$) <> U(3) THEN 2915
1161 LET W9$ = "symbols"
1162 IF U(1) > S7 THEN 2925
1165 LET N9 = U(1)
1170 LET L(N9, 2) = U(3)
1175 LET L(N9, 0) = N9
1180 LET L(N9, 1) = N9
1195 LET Q$(N9) = O$(S3)
1200 LET J(N9, 0) = M(S3, 0)
1205 LET J(N9, 1) = M(S3, 1)
1210 LET J(N9, 2) = M(S3, 2)
1215 LET J(N9, 3) = M(S3, 3)
1245 LET O0 = S3 - 1
1250 GOTO 1920
1255 REM ---- fn: opens a function; its records stay in O$ until the reachable ones are written -------
1260 LET M$ = "fn inside a function"
1265 IF F7 = 1 THEN 2915
1270 LET D$ = "BAD_TREE"
1275 LET M$ = "nodes left on the stack at fn"
1280 IF S0 <> 0 THEN 2915
1285 LET D$ = "BAD_RECORD"
1290 LET M$ = "fn ids are not 1, 2, ..."
1295 IF U(1) <> F6 + 1 THEN 2915
1310 LET W9$ = "symbols"
1315 IF F6 >= S7 THEN 2925
1320 LET F6 = F6 + 1
1325 LET F5 = 1
1330 LET F7 = 1
1335 LET X9 = U(5) + U(6)
1336 LET H3 = X9
1337 LET H(F6, 0) = V0 + 1
1338 LET H(F6, 1) = 0
1339 LET H(F6, 2) = X9
1340 LET K(F6, 1) = O0 + 1
1345 LET K(F6, 3) = 0
1346 REM an elemental function (kind elem) is marked for step 3 (5340)
1347 LET K(F6, 0) = 0
1348 IF G$(4) <> "elem" THEN 1350
1349 LET K(F6, 0) = 1
1350 LET K1 = 0
1355 LET T$ = L$
1360 GOSUB 3070
1365 GOTO 1920
1370 REM ---- end: the body block is the last node of the function ------------------------------------
1375 LET M$ = "end outside a function"
1380 IF F7 = 0 THEN 2915
1385 GOSUB 2980
1390 LET D$ = "BAD_TREE"
1395 LET M$ = "the body of a function is not one block"
1400 IF S0 <> 0 THEN 2915
1405 LET D$ = "BAD_RECORD"
1410 LET M$ = "fewer par and loc records than np + nl"
1415 IF X9 <> 0 THEN 2915
1416 LET M$ = "a dollar outside the indices of an idx"
1417 GOSUB 4560
1420 LET K1 = 0
1425 LET T$ = L$
1430 GOSUB 3070
1435 LET K(F6, 2) = O0
1440 LET F7 = 0
1445 GOTO 1920
1450 REM ---- cvt: i64 constant -> f64 (nearest, ties to even) ----------------------------------------
1455 GOSUB 2980
1460 IF O0 <> S3 THEN 905
1465 IF M(O0, 0) = 0 THEN 905
1466 IF M(O0, 0) = 3 THEN 905
1467 LET M$ = "cvt of a constant that is not an i64 constant, or not typed f64"
1468 IF M(O0, 0) <> 1 THEN 2915
1469 IF U(2) <> 4 THEN 2915
1470 LET D1 = O0
1475 GOSUB 3180
1480 CALL "FEFRI": A3, A2, A1, A0, R3, R2, R1, R0, W1
1485 LET K1 = 2
1490 GOTO 1915
1495 REM ---- un neg of a constant: i64 unless it overflows, f64 always (a sign flip) ------------------
1500 GOSUB 2980
1505 IF G$(4) <> "neg" THEN 905
1510 IF O0 <> S3 THEN 905
1515 LET K1 = M(O0, 0)
1520 IF K1 = 0 THEN 905
1525 IF K1 > 2 THEN 905
1526 LET M$ = "un neg typed " & STR$(U(2)) & " of a constant of another type"
1527 IF U(2) <> 2 + K1 THEN 2915
1530 LET D1 = O0
1535 GOSUB 3180
1540 IF K1 = 2 THEN 1570
1545 CALL "LMNEG": A3, A2, A1, A0, R3, R2, R1, R0, W1
1550 IF W1 = 1 THEN 905
1555 GOTO 1915
1570 CALL "FENEG": A3, A2, A1, A0, R3, R2, R1, R0
1575 GOTO 1915
1580 REM ---- bin add sub mul div of two constants: f64 always, i64 add sub mul unless it overflows -----
1585 GOSUB 2980
1590 LET P2 = INT((POS("|add|sub|mul|div|", "|" & G$(4) & "|") + 3) / 4)
1595 IF P2 = 0 THEN 905
1600 IF O0 - S3 <> 1 THEN 905
1605 LET K1 = M(S3, 0)
1610 IF K1 = 0 THEN 905
1615 IF K1 > 2 THEN 905
1616 IF M(O0, 0) = 0 THEN 905
1617 IF M(O0, 0) > 2 THEN 905
1618 LET M$ = "bin " & G$(4) & " typed " & STR$(U(2)) & ": its constant operands do not have the operation's types"
1620 IF M(O0, 0) <> K1 THEN 2915
1621 IF U(2) <> 2 + K1 THEN 2915
1622 IF K1 = 2 THEN 1625
1623 IF P2 = 4 THEN 2915
1625 LET D1 = S3
1630 GOSUB 3180
1635 LET D1 = O0
1640 GOSUB 3215
1645 IF K1 = 2 THEN 1730
1655 IF P2 = 2 THEN 1675
1660 IF P2 = 3 THEN 1685
1665 CALL "LMADD": A3, A2, A1, A0, B3, B2, B1, B0, R3, R2, R1, R0, W1
1670 GOTO 1690
1675 CALL "LMSUB": A3, A2, A1, A0, B3, B2, B1, B0, R3, R2, R1, R0, W1
1680 GOTO 1690
1685 CALL "LMMUL": A3, A2, A1, A0, B3, B2, B1, B0, R3, R2, R1, R0, W1
1690 IF W1 = 1 THEN 905
1695 GOTO 1915
1698 REM ---- powk k of an f64 constant: the pinned multiplications (3555) ------------------------------------
1700 GOSUB 2980
1702 IF O0 <> S3 THEN 905
1704 LET K1 = M(O0, 0)
1706 IF K1 = 0 THEN 905
1708 IF K1 = 3 THEN 905
1710 LET M$ = "powk of a constant that is not an f64 constant, not typed f64, or with |k| above LIM_POWK"
1712 IF K1 <> 2 THEN 2915
1714 IF U(2) <> 4 THEN 2915
1716 CALL "LMRD": G$(4), B3, B2, B1, B0, W1
1718 CALL "LMTON": B3, B2, B1, B0, P2, W1
1720 IF W1 <> 0 THEN 2915
1722 IF ABS(P2) > V8 THEN 2915
1724 LET D1 = O0
1725 GOSUB 3180
1726 GOSUB 3555
1728 GOTO 1915
1730 IF P2 = 2 THEN 1755
1735 IF P2 = 3 THEN 1765
1740 IF P2 = 4 THEN 1775
1745 CALL "FEADD": A3, A2, A1, A0, B3, B2, B1, B0, R3, R2, R1, R0
1750 GOTO 1915
1755 CALL "FESUB": A3, A2, A1, A0, B3, B2, B1, B0, R3, R2, R1, R0
1760 GOTO 1915
1765 CALL "FEMUL": A3, A2, A1, A0, B3, B2, B1, B0, R3, R2, R1, R0
1770 GOTO 1915
1775 CALL "FEDIV": A3, A2, A1, A0, B3, B2, B1, B0, R3, R2, R1, R0
1780 GOTO 1915
1795 REM ---- lib: sqrt of a constant folds (any value); write_json waits for its eval (5700) -----------------------
1800 IF G$(4) <> "write_json" THEN 1810
1801 REM (6d) lib write_json: two arguments, type void; J3 = the value's first record, J9 = 1 until its eval (5700)
1802 LET M$ = "a lib write_json without exactly two arguments, or not typed void (1)"
1803 IF U(4) <> 2 THEN 2915
1804 IF U(2) <> 1 THEN 2915
1805 GOSUB 2980
1806 LET J3 = S(S0 + 2)
1807 LET J9 = 1
1808 GOTO 905
1810 GOSUB 2980
1815 IF G$(4) <> "sqrt" THEN 905
1820 IF U(4) <> 1 THEN 905
1825 IF O0 <> S3 THEN 905
1830 IF M(O0, 0) = 0 THEN 905
1831 IF M(O0, 0) = 3 THEN 905
1832 LET M$ = "lib sqrt of a constant that is not an f64 constant, or not typed f64"
1833 IF M(O0, 0) <> 2 THEN 2915
1834 IF U(2) <> 4 THEN 2915
1835 LET D1 = O0
1840 GOSUB 3180
1865 CALL "FESQR": A3, A2, A1, A0, R3, R2, R1, R0
1870 LET K1 = 2
1875 GOTO 1915
1880 REM ---- call: kind 3, the callee in M(.,1) ------------------------------------------------------------
1885 GOSUB 2980
1887 GOSUB 5300
1890 LET K1 = 3
1895 LET T$ = L$
1900 GOSUB 3070
1902 LET M(O0, 2) = X2
1905 GOSUB 3150
1910 GOTO 1920
1915 GOSUB 3255
1920 LET P7$ = G$(1)
1921 GOSUB 2965
1925 GOTO 535
1930 REM ---- type records: kept in the tables T P K$ Y$ until the numbering ------------------------------------
1935 LET M$ = "type record after the first function"
1940 IF F5 = 1 THEN 2915
1945 LET M$ = "type record after a constant"
1950 IF N9 > 0 THEN 2915
1955 LET M$ = "type ids are not 10, 11, ..."
1960 IF U(1) <> 10 + T9 THEN 2915
1965 LET W9$ = "types"
1970 IF U(1) > 9 + T7 THEN 2925
1975 LET T9 = T9 + 1
1980 LET I9 = U(1)
1985 LET T(I9, 1) = Y0
1990 LET T(I9, 2) = P9 + 1
1995 LET T(I9, 3) = 1
2000 LET W9 = U(2)
2005 ON Y0 GOTO 2010, 2010, 2025, 2035, 2050, 2065, 2110
2010 LET P9 = P9 + 1
2015 LET P(P9) = W9
2020 GOTO 2170
2025 LET T(I9, 4) = U(3)
2030 GOTO 2010
2035 LET T(I9, 4) = U(3)
2040 LET T(I9, 5) = U(4)
2045 GOTO 2010
2050 LET W9 = U(3)
2055 LET Y$(I9) = G$(3)
2060 GOTO 2075
2065 LET Y$(I9) = "%"
2070 LET W9 = U(2)
2075 LET T(I9, 3) = W9
2080 LET X8 = W9
2085 LET F4 = P9 + 1
2090 LET P9 = P9 + W9
2095 LET W9$ = "types"
2100 IF P9 > 399999 THEN 2925
2105 GOTO 1920
2110 LET T(I9, 3) = W9
2115 LET W9$ = "types"
2120 IF P9 + W9 > 399999 THEN 2925
2125 LET M$ = "a type component is not an earlier type"
2130 FOR K9 = 1 TO W9
2135 CALL "io_u": G$(3 + K9), W1, W2
2140 IF W1 < 1 THEN 2915
2145 IF W1 >= I9 THEN 2915
2150 LET P(P9 + K9) = W1
2155 NEXT K9
2160 LET P9 = P9 + W9
2165 GOTO 1920
2170 LET M$ = "a type component is not an earlier type"
2175 IF P(P9) < 1 THEN 2915
2180 IF P(P9) >= I9 THEN 2915
2185 GOTO 4500
2190 LET M$ = "fd without a tstruct / trec that owes it"
2195 IF X8 = 0 THEN 2915
2200 LET M$ = "a type component is not an earlier type"
2205 IF U(2) < 1 THEN 2915
2210 IF U(2) >= 9 + T9 THEN 2915
2215 LET P(F4) = U(2)
2220 LET K$(F4) = G$(2)
2225 LET F4 = F4 + 1
2230 LET X8 = X8 - 1
2235 GOTO 1920
2240 REM ---- #end: reachability, numbering, output ----------------------------------------------------------------
2245 LET M$ = "#end carries fields"
2250 IF C0 <> 1 THEN 2915
2255 LET D$ = "BAD_TREE"
2260 LET M$ = "nodes left on the stack at #end"
2265 IF S0 > 0 THEN 2915
2270 LET D$ = "BAD_RECORD"
2275 LET M$ = "a function is not closed by end"
2280 IF F7 = 1 THEN 2915
2285 LET M$ = "fd records missing after the last tstruct / trec"
2290 IF X8 > 0 THEN 2915
2295 LET M$ = "no function"
2300 IF F6 < 1 THEN 2915
2305 CALL "io_end": 1, P$, E(), E$(), E0
2306 GOSUB 5340
2310 REM reachable functions: marked in K(.,3), worklist in D(.,0); an emap marks its instance in X(.,4) and keeps its function
2315 LET K(1, 3) = 1
2320 LET D(1, 0) = 1
2325 LET W1 = 1
2330 IF W1 = 0 THEN 2410
2335 LET F1 = D(W1, 0)
2340 LET W1 = W1 - 1
2345 FOR I2 = K(F1, 1) TO K(F1, 2)
2350 IF M(I2, 0) = 3 THEN 2355
2351 IF M(I2, 0) <> 4 THEN 2400
2352 LET X(M(I2, 1), 4) = 1
2353 LET W2 = X(M(I2, 1), 0)
2354 GOTO 2380
2355 LET W2 = M(I2, 1)
2360 LET D$ = "BAD_TREE"
2365 LET M$ = "call of function " & STR$(W2) & " but the file has " & STR$(F6)
2370 IF W2 < 1 THEN 2915
2375 IF W2 > F6 THEN 2915
2380 IF K(W2, 3) = 1 THEN 2400
2385 LET K(W2, 3) = 1
2390 LET W1 = W1 + 1
2395 LET D(W1, 0) = W2
2400 NEXT I2
2405 GOTO 2330
2410 REM new function ids, dense in the old order
2415 LET N8 = 0
2420 FOR I = 1 TO F6
2425 IF K(I, 3) = 0 THEN 2440
2430 LET N8 = N8 + 1
2435 LET K(I, 3) = N8
2440 NEXT I
2441 REM new instance ids, dense in the old order (the kept functions' emaps marked them)
2442 LET I3 = 0
2443 FOR I = 1 TO X4
2444 IF X(I, 4) = 0 THEN 2447
2445 LET I3 = I3 + 1
2446 LET X(I, 4) = I3
2447 NEXT I
2448 REM type numbering: the first reference in the inst records, then in the records of the kept functions (3.5.1)
2450 LET N8 = 0
2451 FOR I = 1 TO X4
2452 IF X(I, 4) = 0 THEN 2454
2453 GOSUB 5470
2454 NEXT I
2455 FOR F1 = 1 TO F6
2460 IF K(F1, 3) = 0 THEN 2535
2465 FOR I2 = K(F1, 1) TO K(F1, 2)
2470 LET I0 = M(I2, 3)
2475 IF A(I0) = 0 THEN 2530
2480 LET T$ = O$(I2)
2485 LET T1 = A(I0) + 1
2490 GOSUB 3345
2495 LET W3 = VAL(Z$)
2500 IF W3 < 10 THEN 2530
2505 LET D$ = "BAD_TREE"
2510 LET M$ = "type " & Z$ & " is not in the type table"
2515 IF W3 > 9 + T9 THEN 2915
2520 IF Y(W3) <> 0 THEN 2530
2525 GOSUB 3435
2530 GOSUB 5880
2531 NEXT I2
2535 NEXT F1
2540 REM ---- write sea.hir -------------------------------------------------------------------------------------------
2545 SCRATCH #2
2550 CALL "io_hdr_put": 2, V9, G0$, H$(), N1
2555 FOR K5 = 1 TO N8
2560 LET O1 = O(K5)
2565 LET I9 = 9 + K5
2570 LET K3 = T(O1, 1)
2575 ON K3 GOTO 2580, 2590, 2615, 2640, 2665, 2675, 2685
2580 LET T$ = "tvec "
2585 GOTO 2595
2590 LET T$ = "tmat "
2595 LET W1 = P(T(O1, 2))
2600 GOSUB 3415
2605 LET T$ = T$ & STR$(I9) & " " & STR$(W1)
2610 GOTO 2715
2615 LET T$ = "tfvec "
2620 LET W1 = P(T(O1, 2))
2625 GOSUB 3415
2630 LET T$ = T$ & STR$(I9) & " " & STR$(W1) & " " & STR$(T(O1, 4))
2635 GOTO 2715
2640 LET T$ = "tfmat "
2645 LET W1 = P(T(O1, 2))
2650 GOSUB 3415
2655 LET T$ = T$ & STR$(I9) & " " & STR$(W1) & " " & STR$(T(O1, 4)) & " " & STR$(T(O1, 5))
2660 GOTO 2715
2665 LET T$ = "tstruct " & STR$(I9) & " " & Y$(O1) & " " & STR$(T(O1, 3))
2670 GOTO 2715
2675 LET T$ = "trec " & STR$(I9) & " " & STR$(T(O1, 3))
2680 GOTO 2715
2685 LET T$ = "ttuple " & STR$(I9) & " " & STR$(T(O1, 3))
2690 FOR K4 = 0 TO T(O1, 3) - 1
2695 LET W1 = P(T(O1, 2) + K4)
2700 GOSUB 3415
2705 LET T$ = T$ & " " & STR$(W1)
2710 NEXT K4
2715 CALL "io_put": 2, T$
2720 IF K3 < 5 THEN 2755
2725 IF K3 > 6 THEN 2755
2730 FOR K4 = 0 TO T(O1, 3) - 1
2735 LET W1 = P(T(O1, 2) + K4)
2740 GOSUB 3415
2745 CALL "io_put": 2, "fd " & K$(T(O1, 2) + K4) & " " & STR$(W1)
2750 NEXT K4
2755 NEXT K5
2756 FOR I = 1 TO X4
2757 IF X(I, 4) = 0 THEN 2759
2758 GOSUB 5560
2759 NEXT I
2760 REM the kept functions, with their new function and type ids
2765 FOR F1 = 1 TO F6
2770 IF K(F1, 3) = 0 THEN 2895
2775 FOR I2 = K(F1, 1) TO K(F1, 2)
2780 LET T$ = O$(I2)
2785 LET I0 = M(I2, 3)
2790 LET Y0 = V(I0)
2795 IF Y0 = 11 THEN 2850
2800 IF Y0 = 21 THEN 2870
2805 IF A(I0) = 0 THEN 2840
2810 LET T1 = A(I0) + 1
2815 GOSUB 3345
2820 LET W1 = VAL(Z$)
2825 GOSUB 3415
2830 LET Z9$ = STR$(W1)
2835 GOSUB 3395
2840 CALL "io_put": 2, T$
2845 GOTO 2890
2850 LET T1 = 2
2855 LET Z9$ = STR$(K(F1, 3))
2860 GOSUB 3395
2862 IF H(F1, 1) > 0 THEN 5850
2865 GOTO 2805
2870 IF M(I2, 0) = 4 THEN 5580
2872 LET T1 = 4
2875 LET Z9$ = STR$(K(M(I2, 1), 3))
2880 GOSUB 3395
2885 GOTO 2805
2890 GOSUB 5860
2891 NEXT I2
2895 NEXT F1
2900 CALL "io_fin": 2
2905 STOP
2910 REM ---- failure: say where, then the internal error of errors.inc (status 11) -------------------------------------
2915 CALL "dg_internal": P$, D$, E(), E$(), E0
2920 REM ---- a capacity limit (DESIGN 2.7): program too large: W9$, at the last position seen -------------------------------
2925 LET A$(1) = W9$
2926 IF Z7 = 1 THEN 2930
2928 GOSUB 4300
2930 CALL "io_pos": Z8$, W4, W5, W6, W7
2935 IF W7 = 0 THEN 2955
2940 LET W4 = N1 - 1
2945 LET W5 = 1
2950 LET W6 = 1
2955 CALL "dg_compile": P$, H$(), N1, W4, W5, W6, "TOO_LARGE", A$(), 1, E(), E$(), E0
2960 REM ---- 2965: the next record of sea.hir1 into L$ (L0 counts the lines) ----
2965 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
2970 RETURN
2975 REM ---- 2980: P1 = the nodes the record pops; S0 shrinks; S3 = where the new node starts ----------------------------
2980 LET P1 = 0
2985 FOR W1 = 1 TO R(I0, 5)
2990 LET W2 = R(I0, 5 + W1)
2995 IF W2 < 0 THEN 3010
3000 LET P1 = P1 + W2
3005 GOTO 3015
3010 LET P1 = P1 + U(-W2)
3015 NEXT W1
3020 IF S0 >= P1 THEN 3040
3025 LET D$ = "BAD_TREE"
3030 LET M$ = "the record pops " & STR$(P1) & " nodes but the stack holds " & STR$(S0)
3035 GOTO 2915
3040 LET S0 = S0 - P1
3045 LET S3 = O0 + 1
3050 IF P1 = 0 THEN 3060
3055 LET S3 = S(S0 + 1)
3060 RETURN
3065 REM ---- 3070: append T$ with kind K1, row I0 and the limbs R3..R0 (kinds 1, 2); kind 3 takes U(3) -----------------
3070 LET O0 = O0 + 1
3075 LET W9$ = "nodes"
3080 IF O0 > 249999 THEN 2925
3085 LET O$(O0) = T$
3090 LET M(O0, 0) = K1
3095 LET M(O0, 1) = 0
3100 LET M(O0, 2) = 0
3105 LET M(O0, 3) = I0
3110 IF K1 = 0 THEN 3140
3115 IF K1 = 3 THEN 3135
3120 LET M(O0, 1) = R3 * 65536 + R2
3125 LET M(O0, 2) = R1 * 65536 + R0
3130 GOTO 3140
3135 LET M(O0, 1) = U(3)
3140 RETURN
3145 REM ---- 3150: the node that starts at S3 joins the stack ---------------------------------------------------------------
3150 LET S0 = S0 + 1
3155 LET W9$ = "nodes"
3160 IF S0 > 249999 THEN 2925
3165 LET S(S0) = S3
3170 RETURN
3175 REM ---- 3180 / 3215: the limbs of out node D1 into A3..A0 / B3..B0 ----------------------------------------------------------
3180 LET W6 = M(D1, 1)
3185 LET A3 = INT(W6 / 65536)
3190 LET A2 = W6 - A3 * 65536
3195 LET W6 = M(D1, 2)
3200 LET A1 = INT(W6 / 65536)
3205 LET A0 = W6 - A1 * 65536
3210 RETURN
3215 LET W6 = M(D1, 1)
3220 LET B3 = INT(W6 / 65536)
3225 LET B2 = W6 - B3 * 65536
3230 LET W6 = M(D1, 2)
3235 LET B1 = INT(W6 / 65536)
3240 LET B0 = W6 - B1 * 65536
3245 RETURN
3250 REM ---- 3255: the subtree that starts at S3 becomes one ci / cf (kind K1, limbs R3..R0) at the record's position ---------
3255 IF K1 = 2 THEN 3280
3260 CALL "LMFMT": R3, R2, R1, R0, S$
3265 LET T$ = "ci " & G$(2) & " " & G$(3) & " " & S$
3270 LET I0 = R5
3275 GOTO 3295
3280 CALL "LMHEX": R3, R2, R1, R0, S$
3285 LET T$ = "cf " & G$(2) & " " & G$(3) & " " & S$
3290 LET I0 = R6
3295 LET O0 = S3 - 1
3300 GOSUB 3070
3305 GOSUB 3150
3310 RETURN
3315 REM ---- 3320: the position field of T$ becomes Z$ ------------------------------------------------------------------------------
3320 LET P2 = POS(T$, " ")
3325 LET P3 = POS(T$, " ", P2 + 1)
3330 LET T$ = SEG$(T$, 1, P2) & Z$ & SEG$(T$, P3, LEN(T$))
3335 RETURN
3340 REM ---- 3345: token T1 (1 = the opcode) of T$ into Z$; S1 its first byte, E1 the byte after it ------------------------------------
3345 LET S1 = 1
3350 FOR W2 = 2 TO T1
3355 LET S1 = POS(T$, " ", S1) + 1
3360 NEXT W2
3365 LET E1 = POS(T$, " ", S1)
3370 IF E1 > 0 THEN 3380
3375 LET E1 = LEN(T$) + 1
3380 LET Z$ = SEG$(T$, S1, E1 - 1)
3385 RETURN
3390 REM ---- 3395: token T1 of T$ is replaced by Z9$ -------------------------------------------------------------------------------------
3395 GOSUB 3345
3400 LET T$ = SEG$(T$, 1, S1 - 1) & Z9$ & SEG$(T$, E1, LEN(T$))
3405 RETURN
3410 REM ---- 3415: W1 = the new id of the old type id W1 (ids below 10 stay) ---------------------------------------------------------------
3415 IF W1 < 10 THEN 3425
3420 LET W1 = Y(W1)
3425 RETURN
3430 REM ---- 3435: number type W3 and, first, its components (an iterative depth-first walk, D = work stack) ------------------------------
3435 LET W4 = 1
3440 LET D(1, 0) = W3
3445 LET D(1, 1) = 0
3450 LET U1 = D(W4, 0)
3455 LET K9 = D(W4, 1)
3460 IF K9 >= T(U1, 3) THEN 3520
3465 LET D(W4, 1) = K9 + 1
3470 LET W5 = P(T(U1, 2) + K9)
3475 IF W5 < 10 THEN 3450
3480 IF Y(W5) <> 0 THEN 3450
3485 LET W4 = W4 + 1
3490 LET D$ = "BAD_TREE"
3495 LET M$ = "the type table nests too deeply or refers to itself"
3500 IF W4 > 50000 THEN 2915
3505 LET D(W4, 0) = W5
3510 LET D(W4, 1) = 0
3515 GOTO 3450
3520 LET N8 = N8 + 1
3525 LET Y(U1) = 9 + N8
3530 LET O(N8) = U1
3535 LET W4 = W4 - 1
3540 IF W4 > 0 THEN 3450
3545 RETURN
3550 REM ---- 3555: R = A ^ P2 by the pinned multiplications of LANGUAGE 6.5, each rounded (FEMUL, FEDIV) ----
3555 LET W2 = ABS(P2)
3557 IF W2 > 0 THEN 3567
3559 LET R3 = 16368
3561 LET R2 = 0
3563 LET R1 = 0
3565 LET R0 = 0
3566 RETURN
3567 LET R3 = A3
3568 LET R2 = A2
3569 LET R1 = A1
3570 LET R0 = A0
3571 IF W2 = 1 THEN 3590
3572 CALL "FEMUL": A3, A2, A1, A0, A3, A2, A1, A0, R3, R2, R1, R0
3573 IF W2 = 2 THEN 3590
3574 IF W2 = 4 THEN 3577
3575 CALL "FEMUL": R3, R2, R1, R0, A3, A2, A1, A0, R3, R2, R1, R0
3576 GOTO 3590
3577 CALL "FEMUL": R3, R2, R1, R0, R3, R2, R1, R0, R3, R2, R1, R0
3590 IF P2 > 0 THEN 3595
3592 CALL "FEDIV": 16368, 0, 0, 0, R3, R2, R1, R0, R3, R2, R1, R0
3595 RETURN
3598 REM ---- 3600: field G$(T0) (row B0 of F) valid for its type (passes.txt, DESIGN 3.1, 3.5.7); u-like values into U(J1) ----
3600 LET Z$ = G$(T0)
3605 LET W1 = F(B0, 1)
3610 LET M$ = "field " & F$(B0) & " ('" & Z$ & "') is not valid for its type"
3615 IF F(B0, 2) = 0 THEN 3625
3620 IF Z$ = "-" THEN 3845
3625 IF W1 >= 100 THEN 3720
3630 IF W1 = 1 THEN 3680
3635 IF W1 = 2 THEN 3735
3640 IF W1 = 3 THEN 3745
3645 IF W1 = 4 THEN 3755
3650 IF W1 = 5 THEN 3700
3655 IF W1 = 7 THEN 3770
3660 IF W1 < 8 THEN 2915
3665 IF W1 > 12 THEN 2915
3680 CALL "io_u": Z$, W2, W3
3685 IF W3 <> 0 THEN 2915
3690 LET U(J1) = W2
3691 REM a tasg cv is a sum of 1 (i64 to f64), 2 (dyn) or 4 (fix), never both 2 and 4 (Decision 37)
3692 IF W1 <> 1 THEN 3845
3694 IF F$(B0) <> "cv" THEN 3845
3696 IF W2 > 5 THEN 2915
3698 GOTO 3845
3700 CALL "io_pos": Z$, W4, W5, W6, W3
3705 IF W3 <> 0 THEN 2915
3710 IF W4 >= N1 THEN 2915
3712 IF LEN(Z7$) > 0 THEN 3845
3714 LET Z7$ = Z$
3716 GOTO 3845
3720 CALL "tb_word": N(), W$(), W1 - 100, Z$, W2
3725 IF W2 = 0 THEN 2915
3730 GOTO 3845
3735 CALL "LMRD": Z$, W2, W3, W4, W5, W6
3740 GOTO 3760
3745 CALL "LMRF": Z$, W2, W3, W4, W5, W6
3750 GOTO 3760
3755 CALL "io_unesc": Z$, 0, Y1$, W6
3760 IF W6 <> 0 THEN 2915
3765 GOTO 3845
3770 IF Z$ = "-" THEN 3845
3775 LET W2 = 0
3780 FOR W3 = 1 TO LEN(Z$)
3785 LET W4 = POS("lpsza", SEG$(Z$, W3, W3))
3790 IF W4 = 0 THEN 2915
3795 IF W4 <= W2 THEN 2915
3800 LET W2 = W4
3805 NEXT W3
3845 RETURN
4295 REM ---- 4300: the record at fault has no pos: the position of the next record with one (DESIGN 2.6.2, 'here') ----
4300 IF G$(1) = "#end" THEN 4396
4315 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
4320 CALL "io_split": L$, G$(), 300, C0
4325 IF C0 < 1 THEN 4395
4330 IF G$(1) = "#end" THEN 4396
4335 LET I0 = 0
4340 FOR I = 1 TO N2
4345 IF R$(B(I)) <> G$(1) THEN 4355
4350 LET I0 = B(I)
4355 NEXT I
4360 IF I0 = 0 THEN 4395
4362 LET T0 = 1
4364 FOR J1 = 1 TO R(I0, 4)
4366 LET B0 = R(I0, 3) + J1 - 1
4368 LET U(J1) = 0
4370 LET X0 = 1
4372 IF F(B0, 3) = 0 THEN 4376
4374 LET X0 = U(F(B0, 3))
4376 IF F(B0, 1) <> 5 THEN 4382
4378 IF T0 + 1 > C0 THEN 4395
4379 CALL "io_pos": G$(T0 + 1), W4, W5, W6, W3
4380 IF W3 = 0 THEN 4392
4381 GOTO 4395
4382 IF F(B0, 1) <> 1 THEN 4388
4383 IF T0 + 1 > C0 THEN 4395
4384 CALL "io_u": G$(T0 + 1), W2, W3
4386 LET U(J1) = W2
4388 LET T0 = T0 + X0
4390 NEXT J1
4391 GOTO 4300
4392 LET Z8$ = G$(T0 + 1)
4395 RETURN
4396 LET Z8$ = STR$(N1 - 1) & ":1:1"
4397 RETURN
4398 REM ---- 4400: S7 T7 = LIM_SYMBOLS LIM_TYPES (limits.inc), within the DIMs of K L J Q$ and T Y O ----
4400 CALL "tb_cval": C(), C$(), N5, "LIM_SYMBOLS", S7, W1
4405 IF W1 <> 0 THEN 4440
4410 CALL "tb_cval": C(), C$(), N5, "LIM_TYPES", T7, W1
4415 IF W1 <> 0 THEN 4440
4416 CALL "tb_cval": C(), C$(), N5, "LIM_FIXED_ELEMS", H2, W1
4417 IF W1 <> 0 THEN 4440
4420 IF S7 > 49999 THEN 4445
4425 IF T7 + 9 > 20009 THEN 4445
4430 RETURN
4440 CALL "dg_bug": P$, "LIM_SYMBOLS, LIM_TYPES or LIM_FIXED_ELEMS is not in the consts table"
4445 CALL "dg_bug": P$, "LIM_SYMBOLS or LIM_TYPES is larger than the arrays of seaexpand"
4450 REM ---- 4500: phase 4 type records tvec tmat tfvec tfmat: the element type is a scalar, str or struct, a fixed extent fits ----
4500 LET M$ = "an array's element type is not a scalar, str or struct (a handle, an array or a tuple)"
4502 LET Q1 = U(2)
4504 IF Q1 < 2 THEN 2915
4506 IF Q1 <= 5 THEN 4516
4508 IF Q1 < 10 THEN 2915
4510 IF T(Q1, 1) = 5 THEN 4516
4512 IF T(Q1, 1) <> 6 THEN 2915
4516 IF Y0 < 3 THEN 1920
4518 LET M$ = "a fixed-size array has more than LIM_FIXED_ELEMS elements"
4520 LET Q2 = U(3)
4522 IF Y0 <> 4 THEN 4526
4524 LET Q2 = U(3) * U(4)
4526 IF Q2 > H2 THEN 2915
4528 GOTO 1920
4550 REM ---- 4560: at the end of a function every dol was inside the indices of an idx (claimed at that idx, 4700) ----
4560 FOR Q3 = K(F6, 1) TO O0
4562 IF M(Q3, 0) <> 0 THEN 4570
4564 IF V(M(Q3, 3)) <> 24 THEN 4570
4566 IF M(Q3, 2) = 0 THEN 2915
4570 NEXT Q3
4572 RETURN
4595 REM ---- 4600: dol, a leaf; M(.,1) = dim + 1, M(.,2) = 1 once an idx has claimed it ----
4600 GOSUB 2980
4602 LET K1 = 0
4604 LET T$ = L$
4606 GOSUB 3070
4608 GOSUB 3150
4610 LET M(O0, 1) = U(3) + 1
4612 GOTO 1920
4645 REM ---- 4650: fore, the iterable is a vector and the loop variable (a local of the function) has its element type ----
4650 LET M$ = "fore outside a function"
4652 IF F7 = 0 THEN 2915
4654 GOSUB 2980
4656 LET Q4 = S(S0 + 2) - 1
4658 GOSUB 4900
4660 GOSUB 4950
4662 LET M$ = "fore over something that is not a vector"
4664 IF Q6 = 1 THEN 4668
4666 IF Q6 <> 3 THEN 2915
4668 LET M$ = "the loop variable of a fore is not a local, or not of the element type"
4670 IF U(2) < 1 THEN 2915
4672 IF U(2) > H3 THEN 2915
4674 LET T$ = O$(K(F6, 1) + U(2))
4676 LET T1 = 3
4678 GOSUB 3345
4680 IF VAL(Z$) <> Q7 THEN 2915
4682 LET K1 = 0
4684 LET T$ = L$
4686 GOSUB 3070
4688 GOSUB 3150
4690 GOTO 1920
4695 REM ---- 4700: idx, n = the rank of the base (or 1 for a mask of a matrix), indices of the kinds of LANGUAGE 5.2; claims the dols;
4697 REM M(.,1) of the idx = the root of its base (for the asg target check, 5100) ----
4700 GOSUB 2980
4702 LET Q1 = U(3)
4704 LET M$ = "idx with n not 1 or 2"
4706 IF Q1 < 1 THEN 2915
4708 IF Q1 > 2 THEN 2915
4710 LET Q4 = S(S0 + 2) - 1
4711 LET Q0 = Q4
4712 GOSUB 4900
4714 GOSUB 4950
4716 LET M$ = "idx of something that is not a vector or a matrix"
4718 LET Q8 = 1
4720 IF Q6 = 1 THEN 4732
4722 IF Q6 = 3 THEN 4732
4724 LET Q8 = 2
4726 IF Q6 = 2 THEN 4732
4728 IF Q6 = 4 THEN 4732
4730 GOTO 2915
4732 LET M$ = "idx with more indices than its base has dimensions"
4734 IF Q1 > Q8 THEN 2915
4736 LET Q9 = 0
4738 IF Q1 < Q8 THEN 4742
4740 GOTO 4744
4742 LET Q9 = 1
4744 LET M$ = "an index of an idx is not an i64, a range, :, an i64 vector or a bool vector (a bool matrix for a mask)"
4746 FOR Q2 = 1 TO Q1
4748 LET Q4 = O0
4750 IF Q2 >= Q1 THEN 4754
4752 LET Q4 = S(S0 + 2 + Q2) - 1
4754 IF Q9 = 1 THEN 4760
4756 IF SEG$(O$(Q4), 1, 4) = "all " THEN 4790
4760 GOSUB 4900
4762 GOSUB 4950
4763 LET M$ = "an index of an idx is not an i64, a range, : , an i64 vector or a bool vector (a bool matrix for a mask)"
4764 IF Q9 = 1 THEN 4780
4766 IF Q5 = 3 THEN 4790
4768 IF Q6 = 1 THEN 4772
4770 IF Q6 <> 3 THEN 2915
4772 IF Q7 = 2 THEN 4790
4774 IF Q7 = 3 THEN 4790
4776 GOTO 2915
4780 IF Q6 = 2 THEN 4784
4782 IF Q6 <> 4 THEN 2915
4784 IF Q7 <> 2 THEN 2915
4790 NEXT Q2
4792 LET M$ = "a dollar names a dimension the idx does not have"
4794 FOR Q3 = S(S0 + 2) TO O0
4796 IF M(Q3, 0) <> 0 THEN 4806
4798 IF V(M(Q3, 3)) <> 24 THEN 4806
4800 IF M(Q3, 2) = 1 THEN 4806
4802 IF M(Q3, 1) - 1 >= Q1 THEN 2915
4804 LET M(Q3, 2) = 1
4806 NEXT Q3
4808 LET K1 = 0
4810 LET T$ = L$
4812 GOSUB 3070
4813 LET M(O0, 1) = Q0
4814 GOSUB 3150
4816 GOTO 1920
4895 REM ---- 4900: Q5 = the type id of the out node Q4 (the field its record's ty names) ----
4900 LET Q5 = M(Q4, 3)
4902 LET M$ = "a node of an idx, of a fore or a call argument has no type"
4904 IF A(Q5) = 0 THEN 2915
4906 LET T$ = O$(Q4)
4908 LET T1 = A(Q5) + 1
4910 GOSUB 3345
4912 LET Q5 = VAL(Z$)
4914 RETURN
4945 REM ---- 4950: Q6 = the kind of type Q5 (0 scalar, 1-4 tvec tmat tfvec tfmat, 5-7 tstruct trec ttuple), Q7 = its element type ----
4950 LET Q6 = 0
4952 LET Q7 = 0
4954 IF Q5 < 10 THEN 4966
4956 LET M$ = "a type id that is not in the type table"
4958 IF Q5 > 9 + T9 THEN 2915
4960 LET Q6 = T(Q5, 1)
4962 IF Q6 > 4 THEN 4966
4964 LET Q7 = P(T(Q5, 2))
4966 RETURN
4995 REM ---- 5000: phase 4e (G12, DESIGN 3.5.7): view, arr, row, dyn, fix, the target tree of an asg; Q4 the last child's root ----
5000 GOSUB 2980
5002 LET Q4 = O0
5004 ON Y0 - 26 GOTO 5010, 5040, 5060, 5070, 5070, 5100, 5160, 5180, 5190, 5190, 5222, 5700
5010 REM view: .T and .flat of a matrix, .col and .row of a vector (fixed-size or dynamic, LANGUAGE 5.6)
5012 GOSUB 4900
5014 GOSUB 4950
5016 LET M$ = "a view of an operand that does not have the rank its kind requires"
5018 LET Q8 = 2
5020 IF G$(4) = "T" THEN 5026
5022 IF G$(4) = "flat" THEN 5026
5024 LET Q8 = 1
5026 IF Q6 = Q8 THEN 5150
5028 IF Q6 = Q8 + 2 THEN 5150
5030 GOTO 2915
5040 REM arr: r >= 0 children, each a row (child k's root: the record before child k + 1 starts)
5042 LET M$ = "an arr child that is not a row"
5044 FOR Q2 = 1 TO U(3)
5046 LET Q4 = O0
5048 IF Q2 >= U(3) THEN 5052
5050 LET Q4 = S(S0 + 1 + Q2) - 1
5052 IF SEG$(O$(Q4), 1, 4) <> "row " THEN 2915
5054 NEXT Q2
5056 GOTO 5150
5060 REM row: n >= 1 elements
5062 LET M$ = "a row without elements"
5064 IF U(3) < 1 THEN 2915
5066 GOTO 5150
5070 REM dyn: a fixed-size array to the dynamic type of its rank and element type; fix: the reverse
5072 GOSUB 4900
5074 GOSUB 4950
5076 LET Q1 = Q6
5078 LET Q2 = Q7
5080 LET Q5 = U(2)
5082 GOSUB 4950
5084 LET M$ = "a dyn or fix whose operand and result types do not correspond"
5086 IF Q2 <> Q7 THEN 2915
5088 IF Q1 * Q6 = 0 THEN 2915
5090 IF Y0 = 30 THEN 5096
5092 IF Q6 = Q1 + 2 THEN 5150
5094 GOTO 2915
5096 IF Q1 = Q6 + 2 THEN 5150
5098 GOTO 2915
5100 REM asg: its target is an lv, an idx of a target, a view flat of a target (a fld path is 4g's), down to an lv
5102 LET Q4 = S(S0 + 2) - 1
5104 LET M$ = "an asg target that is not an lv, idx or view flat tree of an lv"
5106 LET T$ = O$(Q4)
5108 IF SEG$(T$, 1, 3) = "lv " THEN 5150
5110 IF SEG$(T$, 1, 4) = "idx " THEN 5124
5112 IF SEG$(T$, 1, 4) = "fld " THEN 5128
5114 IF SEG$(T$, 1, 5) <> "view " THEN 2915
5116 LET T1 = 4
5118 GOSUB 3345
5120 IF Z$ <> "flat" THEN 2915
5122 GOTO 5128
5124 LET Q4 = M(Q4, 1)
5126 GOTO 5106
5128 LET Q4 = Q4 - 1
5130 GOTO 5106
5150 LET K1 = 0
5152 LET T$ = L$
5154 GOSUB 3070
5156 GOSUB 3150
5158 GOTO 1920
5160 REM match (4g-1, G12): a str scrutinee, n >= 1 children that are arms, the last one _ (k = 0)
5161 LET M$ = "a match whose scrutinee is not a str, a child that is not an arm, or no final _ arm"
5162 LET Q4 = S(S0 + 2) - 1
5163 GOSUB 4900
5164 IF Q5 <> 5 THEN 2915
5165 IF U(2) < 1 THEN 2915
5166 FOR Q2 = 2 TO U(2) + 1
5167 LET Q4 = O0
5168 IF Q2 > U(2) THEN 5170
5169 LET Q4 = S(S0 + 1 + Q2) - 1
5170 IF SEG$(O$(Q4), 1, 4) <> "arm " THEN 2915
5171 NEXT Q2
5172 LET T$ = O$(O0)
5173 LET T1 = 3
5174 GOSUB 3345
5175 IF Z$ <> "0" THEN 2915
5176 GOTO 5150
5180 REM arm (4g-1, G12): its k patterns are cs leaves, then its block
5181 LET M$ = "an arm pattern that is not a cs"
5182 FOR Q2 = 1 TO U(2)
5183 IF SEG$(O$(S(S0 + 1 + Q2) - 1), 1, 3) <> "cs " THEN 2915
5184 NEXT Q2
5185 GOTO 5150
5186 REM fld and proj (4g-2, G12): field i of the operand's struct or record type exists and ty is its type (fld);
5187 REM the operand is a vector of structs or records, field i is a scalar or str and ty the vector of that type (proj)
5190 LET M$ = "a fld or proj of a field that does not exist, or of a type that does not correspond"
5192 GOSUB 4900
5194 GOSUB 4950
5196 IF Y0 = 35 THEN 5204
5198 IF Q6 = 1 THEN 5202
5200 IF Q6 <> 3 THEN 2915
5202 LET Q5 = Q7
5203 GOSUB 4950
5204 IF Q6 < 5 THEN 2915
5206 IF Q6 > 6 THEN 2915
5208 IF U(3) >= T(Q5, 3) THEN 2915
5210 LET Q1 = P(T(Q5, 2) + U(3))
5212 LET Q7 = U(2)
5213 IF Y0 = 35 THEN 5219
5214 IF Q1 < 2 THEN 2915
5215 IF Q1 > 5 THEN 2915
5216 LET Q5 = U(2)
5217 GOSUB 4950
5218 IF Q6 <> 1 THEN 2915
5219 IF Q1 <> Q7 THEN 2915
5220 GOTO 5150
5221 REM slit (4g-2, G12): ty is a struct or record type with as many fields as the slit has values
5222 LET M$ = "a slit whose type is not a struct or record, or with a value count unlike its field count"
5224 LET Q5 = U(2)
5226 GOSUB 4950
5228 IF Q6 < 5 THEN 2915
5230 IF Q6 > 6 THEN 2915
5232 IF U(3) <> T(Q5, 3) THEN 2915
5234 GOTO 5150
5295 REM ---- 5300 (6c): the argument types of the call being read into P(X2 + 1 ... X2 + n), past the type components (X7 the top) ----
5300 IF X7 >= P9 THEN 5304
5302 LET X7 = P9
5304 LET X2 = X7
5306 LET W9$ = "nodes"
5308 IF X7 + U(4) > 399999 THEN 2925
5310 FOR X3 = 1 TO U(4)
5312 REM argument X3's root: the record before argument X3 + 1 starts; the last one's is the newest record
5314 LET Q4 = O0
5316 IF X3 >= U(4) THEN 5320
5318 LET Q4 = S(S0 + 1 + X3) - 1
5320 GOSUB 4900
5322 LET P(X7 + X3) = Q5
5324 NEXT X3
5326 LET X7 = X7 + U(4)
5328 RETURN
5335 REM ---- 5340 (6c, step 3 of 3.5.7): every call, in file order, of an elem function with an array argument at an elemental
5336 REM parameter (f64 i64 bool, LANGUAGE 8.5) becomes an emap: M kind 4, M(.,1) its instance (X: fid, rty, n, P row, new id;
5337 REM X4 instances), shared by equal fid and argument types (3.5.3); G12 (2.11.3): count, argument and result types ----
5340 LET X4 = 0
5342 FOR F1 = 1 TO F6
5344 FOR I2 = K(F1, 1) TO K(F1, 2)
5346 IF M(I2, 0) <> 3 THEN 5456
5348 LET W2 = M(I2, 1)
5350 LET D$ = "BAD_TREE"
5352 LET M$ = "call of function " & STR$(W2) & " but the file has " & STR$(F6)
5354 IF W2 < 1 THEN 2915
5356 IF W2 > F6 THEN 2915
5358 IF K(W2, 0) = 0 THEN 5456
5360 LET H5 = W2
5362 REM H5 the callee (3345 takes W2); G5 G6 the call's n and ty, G8 the P row before its argument types; G9 the callee's fn record, G7 its np, H7 its rty
5364 LET T$ = O$(I2)
5366 LET T1 = 5
5368 GOSUB 3345
5370 LET G5 = VAL(Z$)
5372 LET T1 = 3
5374 GOSUB 3345
5376 LET G6 = VAL(Z$)
5378 LET G8 = M(I2, 2)
5380 LET G9 = K(H5, 1)
5382 LET T$ = O$(G9)
5384 LET T1 = 6
5386 GOSUB 3345
5388 LET G7 = VAL(Z$)
5390 LET T1 = 5
5392 GOSUB 3345
5394 LET H7 = VAL(Z$)
5396 REM G1 = 1 when an argument at an elemental parameter is an array; else the call stays an ordinary call
5398 LET G1 = 0
5400 FOR G2 = 1 TO G5
5401 IF G2 > G7 THEN 5410
5402 LET Q5 = P(G8 + G2)
5403 GOSUB 4950
5404 IF Q6 = 0 THEN 5410
5405 IF Q6 > 4 THEN 5410
5406 GOSUB 5460
5407 IF H4 < 2 THEN 5410
5408 IF H4 > 4 THEN 5410
5409 LET G1 = 1
5410 NEXT G2
5412 IF G1 = 0 THEN 5456
5414 LET D$ = "BAD_RECORD"
5416 LET M$ = "an elemental call with array arguments whose argument count is not its function's parameter count"
5418 IF G5 <> G7 THEN 2915
5420 REM each argument against its parameter: a val parameter; uniform exactly its type, elemental the scalar or an array of it
5421 REM (G3 the rank shared by the array arguments, LANGUAGE 6.3: a vector with a matrix is pass 2a's 202)
5422 LET G3 = 0
5424 FOR G2 = 1 TO G5
5426 LET M$ = "an elemental call's argument does not fit its parameter (elemental: the scalar or an array of it; uniform: its type)"
5427 LET I1$ = M$
5428 GOSUB 5460
5430 IF Z$ <> "val" THEN 2915
5432 LET Q5 = P(G8 + G2)
5434 IF Q5 = H4 THEN 5444
5436 IF H4 < 2 THEN 2915
5438 IF H4 > 4 THEN 2915
5440 LET H8 = H4
5442 GOSUB 5483
5444 NEXT G2
5446 LET M$ = "the type of an elemental call with array arguments does not correspond to its function's results"
5448 GOSUB 5500
5450 GOSUB 5600
5456 NEXT I2
5457 NEXT F1
5458 RETURN
5459 REM ---- 5460: H4 = the type of parameter G2 of the callee (fn record G9), Z$ its mode ----
5460 LET T$ = O$(G9 + G2)
5462 LET T1 = 3
5464 GOSUB 3345
5466 LET H4 = VAL(Z$)
5467 LET T1 = 4
5468 GOSUB 3345
5469 RETURN
5470 REM ---- 5470: number the types of instance I (rty, then its argument types) not yet numbered (3435) ----
5471 LET W3 = X(I, 1)
5472 GOSUB 5477
5473 FOR G2 = 1 TO X(I, 2)
5474 LET W3 = P(X(I, 3) + G2)
5475 GOSUB 5477
5476 NEXT G2
5477 IF W3 < 10 THEN 5482
5478 LET D$ = "BAD_TREE"
5479 LET M$ = "type " & STR$(W3) & " is not in the type table"
5480 IF W3 > 9 + T9 THEN 2915
5481 IF Y(W3) = 0 THEN 3435
5482 RETURN
5483 REM ---- 5483: type Q5 is an array (fixed-size or dynamic) of element type H8 and of the rank G3 (set by the first; I1$ the message) ----
5484 GOSUB 4950
5485 LET M$ = I1$
5486 IF Q6 = 0 THEN 2915
5487 IF Q6 > 4 THEN 2915
5488 IF Q7 <> H8 THEN 2915
5489 LET H6 = Q6 - 2 * INT((Q6 - 1) / 2)
5490 IF G3 > 0 THEN 5492
5491 LET G3 = H6
5492 IF H6 <> G3 THEN 2915
5493 RETURN
5499 REM ---- 5500 (implementer reading of 3.5.3's rty): the call's type G6 is void for no result (Decision 92), else each result as an array ----
5500 LET I1$ = M$
5502 IF H7 <> 1 THEN 5508
5504 IF G6 <> 1 THEN 2915
5506 RETURN
5508 IF H7 < 2 THEN 2915
5510 IF H7 > 4 THEN 5518
5512 LET H8 = H7
5514 LET Q5 = G6
5516 GOTO 5483
5518 LET Q5 = H7
5520 GOSUB 4950
5522 LET M$ = I1$
5524 IF Q6 <> 7 THEN 2915
5526 LET Q5 = G6
5528 GOSUB 4950
5530 LET M$ = I1$
5532 IF Q6 <> 7 THEN 2915
5534 IF T(G6, 3) <> T(H7, 3) THEN 2915
5536 FOR G4 = 0 TO T(H7, 3) - 1
5538 LET H8 = P(T(H7, 2) + G4)
5540 IF H8 < 2 THEN 2915
5542 IF H8 > 4 THEN 2915
5544 LET Q5 = P(T(G6, 2) + G4)
5546 GOSUB 5483
5548 NEXT G4
5550 RETURN
5559 REM ---- 5560: the inst record of instance I, with its new instance, function and type ids (3.5.3) ----
5560 LET W1 = X(I, 1)
5562 GOSUB 3415
5564 LET T$ = "inst " & STR$(X(I, 4)) & " " & STR$(K(X(I, 0), 3)) & " " & STR$(W1) & " " & STR$(X(I, 2))
5566 FOR G2 = 1 TO X(I, 2)
5568 LET W1 = P(X(I, 3) + G2)
5570 GOSUB 3415
5572 LET T$ = T$ & " " & STR$(W1)
5574 NEXT G2
5576 CALL "io_put": 2, T$
5578 RETURN
5579 REM ---- 5580: an emap (M kind 4): the call record T$ written as emap with its instance's new id in place of the fid ----
5580 LET T$ = "emap" & SEG$(T$, 5, LEN(T$))
5582 LET T1 = 4
5584 LET Z9$ = STR$(X(M(I2, 1), 4))
5586 GOSUB 3395
5588 GOTO 2805
5599 REM ---- 5600: the instance of call I2 (function H5, n G5, argument types after P row G8, type G6): an equal one, else a new one ----
5600 LET H9 = 0
5602 FOR G2 = 1 TO X4
5604 IF H9 > 0 THEN 5620
5606 IF X(G2, 0) <> H5 THEN 5620
5608 LET I1 = 1
5610 FOR G4 = 1 TO G5
5612 IF P(X(G2, 3) + G4) = P(G8 + G4) THEN 5616
5614 LET I1 = 0
5616 NEXT G4
5618 IF I1 = 0 THEN 5620
5619 LET H9 = G2
5620 NEXT G2
5622 IF H9 = 0 THEN 5630
5624 LET M$ = "two applications of an elemental function with the same argument types and different types"
5626 IF X(H9, 1) <> G6 THEN 2915
5628 GOTO 5660
5630 LET X4 = X4 + 1
5632 IF X4 <= S7 THEN 5646
5634 REM more instances than LIM_SYMBOLS: program too large, at the call
5636 LET W9$ = "symbols"
5638 LET T$ = O$(I2)
5640 LET T1 = 2
5642 GOSUB 3345
5643 LET Z8$ = Z$
5644 LET Z7 = 1
5645 GOTO 2925
5646 LET X(X4, 0) = H5
5648 LET X(X4, 1) = G6
5650 LET X(X4, 2) = G5
5652 LET X(X4, 3) = G8
5654 LET X(X4, 4) = 0
5656 LET H9 = X4
5660 LET M(I2, 0) = 4
5662 LET M(I2, 1) = H9
5664 RETURN
5695 REM ---- 5700 (6d, step 4 of 3.5.7): an eval whose child is a lib write_json (J9 = 1: the lib is the newest record O0, its
5696 REM path the records S3 ... J3 - 1, its value J3 ... O0 - 1) becomes block P: bind J1 = path; bind J2 = value; jopen (lv J1);
5697 REM emit(lv J2); jclose, every new node at the eval's position P (E2$); any other eval is copied (5150) ----
5700 IF J9 = 0 THEN 5150
5702 LET J9 = 0
5704 LET E2$ = G$(2)
5706 LET J2 = S3
5708 LET J4 = O0
5710 REM the path's root is the record before the value, the value's root the record before the lib
5712 LET Q4 = J3 - 1
5714 GOSUB 4900
5716 LET M$ = "the path of a write_json is not a str"
5718 IF Q5 <> 5 THEN 2915
5720 LET Q4 = J4 - 1
5722 GOSUB 4900
5724 LET J6 = Q5
5726 REM the .j locals J1 (the path, lid J7) and J2 (the value, lid J7 + 1), mut let, declared by their binds (6880)
5728 LET J7 = H(F6, 2) + H(F6, 1) + 1
5730 LET C7 = 5
5732 LET C8$ = "let"
5734 GOSUB 6880
5736 LET C7 = J6
5738 GOSUB 6880
5740 REM the value's records move up one row (into the lib's row); the bind of J1 takes the value's first row
5742 FOR D7 = J4 - 1 TO J3 STEP -1
5744 LET O$(D7 + 1) = O$(D7)
5746 FOR D6 = 0 TO 3
5748 LET M(D7 + 1, D6) = M(D7, D6)
5750 NEXT D6
5752 NEXT D7
5754 LET T$ = "bind " & E2$ & " " & STR$(J7)
5756 GOSUB 6900
5758 LET O$(J3) = T$
5760 LET M(J3, 0) = 0
5762 LET M(J3, 1) = 0
5764 LET M(J3, 2) = 0
5766 LET M(J3, 3) = I0
5768 REM then bind J2, jopen (lv J1): three statements of the block so far (counter 1, G(1,1))
5770 LET T$ = "bind " & E2$ & " " & STR$(J7 + 1)
5772 GOSUB 6800
5774 LET T$ = "lv " & E2$ & " 5 " & STR$(J7)
5776 GOSUB 6800
5778 LET T$ = "jopen " & E2$
5780 GOSUB 6800
5782 LET E5 = 1
5784 LET G(1, 1) = 3
5786 REM the task stack (E3), the expression pool (E4) and the placeholder locals (E6) start empty; the first task emit(lv J2)
5788 LET E3 = 0
5790 LET E4 = 0
5792 LET E6 = 0
5794 LET T$ = "lv " & E2$ & " " & STR$(J6) & " " & STR$(J7 + 1)
5796 GOSUB 6870
5798 LET C2 = 1
5800 LET C3 = E4
5802 LET C4 = 1
5804 LET C5 = J6
5806 GOSUB 6940
5808 GOSUB 6000
5810 REM jclose ends the block; its statement count is counter 1
5812 LET T$ = "jclose " & E2$
5814 GOSUB 6800
5816 LET T$ = "block " & E2$ & " " & STR$(G(1, 1) + 1)
5818 GOSUB 6800
5820 REM the lv of a loop local written before its fore / forr has a placeholder ~q: its lid G(q,0), known now (from bind J2 on)
5822 FOR D7 = J4 + 1 TO O0
5824 IF SEG$(O$(D7), 1, 3) <> "lv " THEN 5830
5826 LET W1 = POS(O$(D7), "~")
5828 IF W1 = 0 THEN 5830
5829 LET O$(D7) = SEG$(O$(D7), 1, W1 - 1) & STR$(G(VAL(SEG$(O$(D7), W1 + 1, LEN(O$(D7)))), 0))
5830 NEXT D7
5838 LET S3 = J2
5839 GOSUB 3150
5840 GOTO 1920
5845 REM ---- 5850 (6d): the fn record of function F1 with .j locals: nl (token 7) raised by their count H(F1,1) ----
5850 LET T1 = 7
5852 GOSUB 3345
5854 LET Z9$ = STR$(VAL(Z$) + H(F1, 1))
5856 GOSUB 3395
5858 GOTO 2805
5859 REM ---- 5860 (6d): after the last par / loc record of function F1 (row I2), its .j loc records, their types renumbered ----
5860 IF I2 <> K(F1, 1) + H(F1, 2) THEN 5878
5862 FOR D8 = H(F1, 0) TO H(F1, 0) + H(F1, 1) - 1
5864 LET T$ = V$(D8)
5866 LET T1 = 3
5868 GOSUB 3345
5870 LET W1 = VAL(Z$)
5872 GOSUB 3415
5874 LET Z9$ = STR$(W1)
5875 GOSUB 3395
5876 CALL "io_put": 2, T$
5877 NEXT D8
5878 RETURN
5879 REM ---- 5880 (6d): type numbering (3.5.1) of the .j loc records of function F1, at their place after its last par / loc ----
5880 IF I2 <> K(F1, 1) + H(F1, 2) THEN 5898
5882 FOR D8 = H(F1, 0) TO H(F1, 0) + H(F1, 1) - 1
5884 LET T$ = V$(D8)
5886 LET T1 = 3
5888 GOSUB 3345
5890 LET W3 = VAL(Z$)
5892 IF W3 < 10 THEN 5896
5894 IF Y(W3) <> 0 THEN 5896
5895 GOSUB 3435
5896 NEXT D8
5898 RETURN
5995 REM ---- 6000 (6d): the task loop of emit (3.5.7 step 4), until the task stack E3 is empty. A task Q(k,0..4): 1 emit (pool rows
5996 REM Q1 ... Q1 + Q2 - 1 = the expression e, Q3 its type), 2 out (pool row Q1, one statement), 3 close a loop (Q3 the placeholder
5997 REM of its local, Q4 1 fore, 2 forr), 4 close an if; the pool is a stack too: a popped task's rows end it. G(E5,1) counts the
5998 REM statements of the innermost open block ----
6000 IF E3 = 0 THEN 6098
6002 LET D2 = Q(E3, 0)
6004 LET D3 = Q(E3, 1)
6006 LET D4 = Q(E3, 2)
6008 LET D5 = Q(E3, 3)
6010 LET D9 = Q(E3, 4)
6012 LET E3 = E3 - 1
6014 LET E4 = D3 + D4 - 1
6016 ON D2 GOTO 6100, 6020, 6030, 6060
6020 REM out: one statement of the innermost block
6022 LET T$ = I$(D3)
6024 GOSUB 6800
6026 LET G(E5, 1) = G(E5, 1) + 1
6028 GOTO 6000
6030 REM close a loop: its body block, then the fore / forr that declares the .j local of placeholder D5 (6880), one statement
6032 LET T$ = "block " & E2$ & " " & STR$(G(E5, 1))
6034 GOSUB 6800
6036 LET E5 = E5 - 1
6038 LET C7 = G(D5, 2)
6040 LET C8$ = "for"
6042 GOSUB 6880
6044 LET G(D5, 0) = D0
6046 LET T$ = "forr "
6048 IF D9 = 2 THEN 6052
6050 LET T$ = "fore "
6052 LET T$ = T$ & E2$ & " " & STR$(D0)
6054 GOSUB 6800
6056 LET G(E5, 1) = G(E5, 1) + 1
6058 GOTO 6000
6060 REM close an if: its else block, then the if (e 1), one statement
6062 LET T$ = "block " & E2$ & " " & STR$(G(E5, 1))
6064 GOSUB 6800
6066 LET E5 = E5 - 1
6068 LET T$ = "if " & E2$ & " 1"
6070 GOSUB 6800
6072 LET G(E5, 1) = G(E5, 1) + 1
6074 GOTO 6000
6098 RETURN
6100 REM emit(e) of type D5, e the pool rows D3 ... D3 + D4 - 1, by the kind of the type (4950: F8 the kind, F9 the element type)
6102 LET Q5 = D5
6104 GOSUB 4950
6106 LET F8 = Q6
6108 LET F9 = Q7
6110 LET M$ = "write_json of a value whose type has no JSON form (void, a handle or a tuple)"
6112 IF F8 = 0 THEN 6120
6114 IF F8 > 6 THEN 2915
6116 IF F8 > 4 THEN 6200
6118 IF F9 >= 10 THEN 6300
6119 GOTO 6150
6120 REM a JSON scalar (bool i64 f64 str): jval e
6122 IF D5 < 2 THEN 2915
6124 IF D5 > 5 THEN 2915
6126 GOSUB 6850
6128 LET T$ = "jval " & E2$
6130 GOSUB 6800
6132 LET G(E5, 1) = G(E5, 1) + 1
6134 GOTO 6000
6150 REM a vector / matrix of JSON scalars: jvec e / jmat e; a fixed-size one through a dyn to the dynamic type (L-ce, 6700)
6152 GOSUB 6850
6154 IF F8 < 3 THEN 6164
6156 LET E7 = F8 - 2
6158 LET E8 = F9
6160 GOSUB 6700
6162 LET T$ = "dyn " & E2$ & " " & STR$(E9)
6163 GOSUB 6800
6164 LET T$ = "jvec " & E2$
6166 IF F8 = 1 THEN 6172
6168 IF F8 = 3 THEN 6172
6170 LET T$ = "jmat " & E2$
6172 GOSUB 6800
6174 LET G(E5, 1) = G(E5, 1) + 1
6176 GOTO 6000
6200 REM a struct or record: jobj, then per field i jkey <name> and emit(fld e i), then jend (pushed in reverse, jend first)
6202 LET T$ = "jobj " & E2$
6204 GOSUB 6800
6206 LET G(E5, 1) = G(E5, 1) + 1
6208 LET T$ = "jend " & E2$
6210 GOSUB 6890
6212 FOR D8 = T(D5, 3) - 1 TO 0 STEP -1
6214 LET C3 = E4 + 1
6216 GOSUB 6860
6218 LET C5 = P(T(D5, 2) + D8)
6220 LET T$ = "fld " & E2$ & " " & STR$(C5) & " " & STR$(D8)
6222 GOSUB 6870
6224 LET C2 = 1
6226 LET C4 = D4 + 1
6228 GOSUB 6940
6230 LET T$ = "jkey " & E2$ & " " & K$(T(D5, 2) + D8)
6232 GOSUB 6890
6234 NEXT D8
6236 GOTO 6000
6300 REM a vector (here) or a matrix (6400) of structs or records
6302 IF F8 = 2 THEN 6400
6304 IF F8 = 4 THEN 6400
6306 REM vector: jarr, fore K in e { emit(lv K) }, jend; K a placeholder (the element type) until its fore is written
6308 LET C7 = F9
6310 GOSUB 6960
6312 LET T$ = "jarr " & E2$
6314 GOSUB 6800
6316 LET G(E5, 1) = G(E5, 1) + 1
6318 GOSUB 6850
6320 GOSUB 6970
6322 LET T$ = "jend " & E2$
6324 GOSUB 6890
6326 LET C2 = 3
6328 LET C3 = E4 + 1
6330 LET C4 = 0
6332 LET C5 = E6
6334 LET C6 = 1
6336 GOSUB 6940
6338 LET T$ = "lv " & E2$ & " " & STR$(F9) & " ~" & STR$(E6)
6340 GOSUB 6870
6342 LET C2 = 1
6344 LET C3 = E4
6346 LET C4 = 1
6348 LET C5 = F9
6350 GOSUB 6940
6352 GOTO 6000
6400 REM matrix: if (rows(e) == 0 || cols(e) == 0) { jarr; jend } else { jarr; forr R in 0..rows(e) { jarr; forr C in
6401 REM 0..cols(e) { emit(idx e (lv R) (lv C)) }; jend }; jend } (L-cv); R (B4) and C (B5) i64 placeholders, B6 the type i64[]
6402 LET C7 = 3
6404 GOSUB 6960
6406 LET B4 = E6
6408 GOSUB 6960
6410 LET B5 = E6
6412 LET E7 = 1
6414 LET E8 = 3
6416 GOSUB 6700
6418 LET B6 = E9
6420 REM the condition rows(e) == 0 || cols(e) == 0
6422 GOSUB 6850
6424 LET T$ = "lib " & E2$ & " 3 rows 1"
6426 GOSUB 6800
6428 GOSUB 6992
6430 GOSUB 6850
6432 LET T$ = "lib " & E2$ & " 3 cols 1"
6434 GOSUB 6800
6436 GOSUB 6992
6438 LET T$ = "bin " & E2$ & " 2 or"
6440 GOSUB 6800
6442 REM the then block: jarr; jend
6444 LET T$ = "jarr " & E2$
6446 GOSUB 6800
6448 LET T$ = "jend " & E2$
6450 GOSUB 6800
6452 LET T$ = "block " & E2$ & " 2"
6454 GOSUB 6800
6456 REM the else block: jarr, forr R's range 0..rows(e); R's body: jarr, forr C's range 0..cols(e); C's body
6458 GOSUB 6970
6460 LET C9$ = "rows"
6462 GOSUB 6980
6464 GOSUB 6970
6466 LET C9$ = "cols"
6468 GOSUB 6980
6470 GOSUB 6970
6472 REM pushed in reverse: close the if, jend, close R, jend, close C, emit(idx e (lv R) (lv C)) of the element type F9
6474 LET C2 = 4
6475 LET C3 = E4 + 1
6476 LET C4 = 0
6477 GOSUB 6940
6478 LET T$ = "jend " & E2$
6479 GOSUB 6890
6480 LET C2 = 3
6481 LET C3 = E4 + 1
6482 LET C4 = 0
6483 LET C5 = B4
6484 LET C6 = 2
6485 GOSUB 6940
6486 LET T$ = "jend " & E2$
6487 GOSUB 6890
6488 LET C2 = 3
6489 LET C3 = E4 + 1
6490 LET C4 = 0
6491 LET C5 = B5
6492 GOSUB 6940
6493 LET C3 = E4 + 1
6494 GOSUB 6860
6495 LET T$ = "lv " & E2$ & " 3 ~" & STR$(B4)
6496 GOSUB 6870
6497 LET T$ = "lv " & E2$ & " 3 ~" & STR$(B5)
6498 GOSUB 6870
6499 LET T$ = "idx " & E2$ & " " & STR$(F9) & " 2"
6500 GOSUB 6870
6502 LET C2 = 1
6504 LET C4 = D4 + 3
6506 LET C5 = F9
6508 GOSUB 6940
6510 GOTO 6000
6695 REM ---- 6700 (6d): E9 = the type of kind E7 (1 tvec, 2 tmat) with element type E8: the existing one, else a new one (3.5.1:
6696 REM step 5 numbers it by first reference); its component goes after the type components and the call argument types ----
6700 LET E9 = 0
6702 FOR B7 = 10 TO 9 + T9
6704 IF E9 > 0 THEN 6710
6706 IF T(B7, 1) <> E7 THEN 6710
6708 IF P(T(B7, 2)) <> E8 THEN 6710
6709 LET E9 = B7
6710 NEXT B7
6712 IF E9 > 0 THEN 6738
6714 LET W9$ = "types"
6716 IF T9 >= T7 THEN 2925
6718 LET B8 = P9
6720 IF X7 <= B8 THEN 6724
6722 LET B8 = X7
6724 LET B8 = B8 + 1
6726 IF B8 > 399999 THEN 2925
6728 LET P(B8) = E8
6729 LET P9 = B8
6730 LET T9 = T9 + 1
6732 LET E9 = 9 + T9
6734 LET T(E9, 1) = E7
6735 LET T(E9, 2) = B8
6736 LET T(E9, 3) = 1
6738 RETURN
6795 REM ---- 6800 (6d): append the new record T$ (no stack entry: the whole block is one node, 5838); 6900 finds its row ----
6800 GOSUB 6900
6802 LET K1 = 0
6804 GOSUB 3070
6806 RETURN
6845 REM ---- 6850: append the expression e (pool rows D3 ... D3 + D4 - 1); 6860: copy it to the top of the pool ----
6850 FOR C1 = D3 TO D3 + D4 - 1
6852 LET T$ = I$(C1)
6854 GOSUB 6800
6856 NEXT C1
6858 RETURN
6860 FOR C1 = D3 TO D3 + D4 - 1
6862 LET T$ = I$(C1)
6864 GOSUB 6870
6866 NEXT C1
6868 RETURN
6869 REM ---- 6870: T$ onto the pool (row E4) ----
6870 LET W9$ = "nodes"
6871 IF E4 >= 99999 THEN 2925
6872 LET E4 = E4 + 1
6873 LET I$(E4) = T$
6874 RETURN
6875 REM ---- 6880: a new .j local of type C7, mut C8$, at P: its lid D0 (after the par, loc and .t locals and the earlier .j ones,
6876 REM in the order of the declaring records, 3.5.4), its loc record in V$ (written by 5860); against LIM_SYMBOLS ----
6880 LET W9$ = "symbols"
6881 IF V0 >= S7 THEN 2925
6882 LET V0 = V0 + 1
6883 LET H(F6, 1) = H(F6, 1) + 1
6884 LET D0 = H(F6, 2) + H(F6, 1)
6885 LET V$(V0) = "loc .j" & STR$(H(F6, 1)) & " " & STR$(C7) & " " & C8$ & " " & E2$
6886 RETURN
6889 REM ---- 6890: an out task of the statement T$ ----
6890 GOSUB 6870
6891 LET C2 = 2
6892 LET C3 = E4
6893 LET C4 = 1
6894 GOSUB 6940
6895 RETURN
6899 REM ---- 6900: I0 = the row of T$'s opcode in the records table (set H or HF) ----
6900 LET I0 = 0
6902 LET B9$ = SEG$(T$, 1, POS(T$, " ") - 1)
6904 FOR B9 = 1 TO Z(7)
6906 IF I0 > 0 THEN 6914
6908 IF R$(B9) <> B9$ THEN 6914
6910 IF R(B9, 1) = 2 THEN 6913
6911 IF R(B9, 1) <> 4 THEN 6914
6913 LET I0 = B9
6914 NEXT B9
6916 IF I0 > 0 THEN 6920
6918 CALL "dg_bug": P$, "record " & B9$ & " is not in the records table"
6920 RETURN
6939 REM ---- 6940: push the task C2 (C3 C4 C5 C6) ----
6940 LET W9$ = "nodes"
6942 IF E3 >= 49999 THEN 2925
6944 LET E3 = E3 + 1
6946 LET Q(E3, 0) = C2
6948 LET Q(E3, 1) = C3
6950 LET Q(E3, 2) = C4
6952 LET Q(E3, 3) = C5
6954 LET Q(E3, 4) = C6
6956 RETURN
6959 REM ---- 6960: a new placeholder loop local of type C7 (E6), its lid unknown until its loop record (6030) ----
6960 LET W9$ = "nodes"
6962 IF E6 >= 49999 THEN 2925
6964 LET E6 = E6 + 1
6966 LET G(E6, 0) = 0
6968 LET G(E6, 2) = C7
6969 RETURN
6970 REM ---- 6970: open a block: a new statement counter ----
6971 LET W9$ = "nodes"
6972 IF E5 >= 49999 THEN 2925
6974 LET E5 = E5 + 1
6976 LET G(E5, 1) = 0
6978 RETURN
6979 REM ---- 6980: jarr (one statement), then the range 0..C9$(e) of a forr (rng: i64[] B6, exclusive, no step) ----
6980 LET T$ = "jarr " & E2$
6981 GOSUB 6800
6982 LET G(E5, 1) = G(E5, 1) + 1
6983 LET T$ = "ci " & E2$ & " 3 0"
6984 GOSUB 6800
6985 GOSUB 6850
6986 LET T$ = "lib " & E2$ & " 3 " & C9$ & " 1"
6987 GOSUB 6800
6988 LET T$ = "rng " & E2$ & " " & STR$(B6) & " 0 0"
6989 GOSUB 6800
6990 RETURN
6991 REM ---- 6992: == 0 of the i64 just appended (ci 0, bin eq of type bool) ----
6992 LET T$ = "ci " & E2$ & " 3 0"
6993 GOSUB 6800
6994 LET T$ = "bin " & E2$ & " 2 eq"
6995 GOSUB 6800
6996 RETURN
