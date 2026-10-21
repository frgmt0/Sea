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
95 REM  5 reachability from .main through call records; functions renumbered densely in their
100 REM    old order; types renumbered by first reference (3.5.1); unreferenced types dropped
105 REM Steps 3 (elemental instantiation) and 4 (write_json expansion) belong to later phases
110 REM (DESIGN 8, phase 6): pass 2a rejects elemental functions and write_json as not supported
115 REM yet, so no emap, elem function or lib write_json can reach this pass in phase 1. Such a
120 REM record is reported as an internal error (BAD_RECORD), never passed on.
125 REM
130 REM TABLES  (arrays one letter; DIM below)
135 REM  E E$ errors  N N$ W$ enums  R R$ records  F F$ fields  Z counts  C C$ constants
140 REM  V special code of a record row, A its ty field index, B the rows of sea.hir1 (sets H H1)
145 REM  G$ fields of the current record  U their u values  H$ #file paths
150 REM  O$ out records  M out kind(0) high32(1) low32(2) row(3): kind 1 ci 2 cf 3 call 0 other
155 REM  S stack of subtree starts (post-order trees)  Q$ J the const pool (the leaf of cid i in row i:
160 REM  text, M-like)  L per cid: pool rows 0-1, ty 2  T P K$ Y$ types (kind, offset, count,
165 REM  extents; component ids; field names; struct names)  K function table (first record, last
170 REM  record, new fid)  Y new type id  O old type id of each new id  D work stack
175 REM
180 REM SCALARS  P$ pass name  L$ record  L0 its line  C0 its fields  I0 its row  Y0 its code
185 REM  S0 stack depth  O0 out records  N9 cn count  S7 T7 LIM_SYMBOLS LIM_TYPES  T9 types  F6 functions  F7 inside a function
190 REM  F5 a function was seen  X8 fd records owed  S3 start of the node being made  K1 kind
195 REM  A3-A0 B3-B0 R3-R0 limbs of operands and result  T$ text  Z8$ last position
200 REM special codes of V: 1-7 tvec tmat tfvec tfmat tstruct trec ttuple, 8 fd, 9 cn, 11 fn,
205 REM  12 par, 13 loc, 14 end, 15 ci, 16 cf, 17 cref, 18 cvt, 19 un, 20 bin, 21 call, 22 lib, 23 powk
210 REM ====================================================================================
215 FILES "sea.hir1"; "sea.hir"
220 DIM E(299), E$(299,5), N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), Z(8)
225 DIM C(299,4), C$(299), G$(300), U(300), H$(100), V(399), A(399), B(399), A$(1)
230 DIM M(249999,3), O$(249999), S(249999)
235 DIM T(20010,5), P(399999), K$(399999), Y$(20010), Y(20010), D(50010,1), K(50010,3), O(20010)
240 DIM J(49999,3), Q$(49999), L(49999,2)
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
340 LET K2$ = "|ci=15|cf=16|cref=17|cvt=18|un=19|bin=20|call=21|lib=22|powk=23|"
341 GOSUB 4400
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
830 IF Y0 = 9 THEN 1115
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
1300 LET M$ = "elemental functions are a later phase: pass 2a rejects them, so pass 2b never sees one in phase 1"
1305 IF G$(4) = "elem" THEN 2915
1310 LET W9$ = "symbols"
1315 IF F6 >= S7 THEN 2925
1320 LET F6 = F6 + 1
1325 LET F5 = 1
1330 LET F7 = 1
1335 LET X9 = U(5) + U(6)
1340 LET K(F6, 1) = O0 + 1
1345 LET K(F6, 3) = 0
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
1795 REM ---- lib: sqrt of a constant folds (any value); write_json is a later phase -----------------------
1800 LET M$ = "write_json expansion is a later phase: pass 2a rejects it, so pass 2b never sees it in phase 1"
1805 IF G$(4) = "write_json" THEN 2915
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
1890 LET K1 = 3
1895 LET T$ = L$
1900 GOSUB 3070
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
2185 GOTO 1920
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
2310 REM reachable functions: marked in K(.,3), worklist in D(.,0)
2315 LET K(1, 3) = 1
2320 LET D(1, 0) = 1
2325 LET W1 = 1
2330 IF W1 = 0 THEN 2410
2335 LET F1 = D(W1, 0)
2340 LET W1 = W1 - 1
2345 FOR I2 = K(F1, 1) TO K(F1, 2)
2350 IF M(I2, 0) <> 3 THEN 2400
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
2445 REM type numbering: the first reference in the records of the kept functions (3.5.1)
2450 LET N8 = 0
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
2530 NEXT I2
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
2865 GOTO 2805
2870 LET T1 = 4
2875 LET Z9$ = STR$(K(M(I2, 1), 3))
2880 GOSUB 3395
2885 GOTO 2805
2890 NEXT I2
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
3692 IF W1 <> 1 THEN 3845
3694 IF F$(B0) <> "cv" THEN 3845
3696 IF W2 > 1 THEN 2915
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
4420 IF S7 > 49999 THEN 4445
4425 IF T7 + 9 > 20009 THEN 4445
4430 RETURN
4440 CALL "dg_bug": P$, "LIM_SYMBOLS or LIM_TYPES is not in the consts table"
4445 CALL "dg_bug": P$, "LIM_SYMBOLS or LIM_TYPES is larger than the arrays of seaexpand"
