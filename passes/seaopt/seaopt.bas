100 REM ====================================================================================
105 REM seaopt -- pass 3b: sea.lir1 -> sea.lir (DESIGN 2.1, 3.6, 3.6.5). Lines 100-59999.
110 REM Built as DESIGN 2.6.3 says: this file, the modules io diag tables, the DATA blocks errors
115 REM exits consts entries records, then 99999 END (passes/seaopt/build.list).
120 REM
125 REM PHASE 1 (DESIGN 3.6.5, 8): the pass reads sea.lir1, validates it, enforces the LIR capacity
130 REM limits and writes it as sea.lir without transforming anything. The header records are copied
135 REM (3.2: a pass copies those of its input). What is validated: every record against passes.txt
140 REM (set L only: sea.lir1 has no vector class and no LF record), register classes and numbering
145 REM in order of first appearance (3.6.1), data labels in order of first reference (3.6.2), block
150 REM numbering and nesting, exit/next naming an enclosing loop or do, slot numbering, chk naming a
155 REM run-time error, rcall naming an entry of rt.inc with its site, argument and result classes,
160 REM the sub-records of fmt and dat, functions then data, and #end last. A malformed input is an
165 REM internal error (status 11, 2.2): exactly one line, "seaopt: " and the text of BAD_RECORD from
170 REM errors.inc (M$ says what failed, for a reader of this file only). A capacity limit (2.6.1) is the
175 REM compile error "program too large: <word>" at the position of the func record (2.6.2).
180 REM
185 REM FLOW. Per function: read every record into the tables below (the main loop, one record per
190 REM round), and at endfunc write the function from the tables. Phase 5 puts its transformations
195 REM between the two, in front of the call of the writer at endfunc; the writer rebuilds
200 REM every record from the tables, so a transformation only edits the tables. The data records
205 REM follow the functions, are validated as read, hold no table row and are copied unchanged.
210 REM
215 REM TABLES (DESIGN 2.7), all reset by the func record. Operand values are plain numbers.
220 REM   I(n,1..4) instruction n (1..I9; row 0 is the func record): record row in the passes.txt
225 REM             table Q (so Q$(I(n,1)) is the opcode), index in O of its first operand,
230 REM             operand count, site (F*1E9+L, 0 = none; the site field is not in O)
235 REM   O(k)      operand fields of the instructions in record order (the repeated ones expanded),
240 REM             k = 1.. (at most O9, the limit of operands); the func record's fields are in M(1..I(0,3)),
245 REM             outside the limit; per field type:
250 REM               u: the value, -1 for an absent (-) field; reg: the register number, 0 = absent;
255 REM               li/lf v (i, f): a row of C; off (i): its value (|v| <= 2^53); s: a row of S$; pos: F*1E9+L, C;
260 REM               lab, slot, blk: the number; an enumeration: the position of its word (1..)
265 REM   R(r,1..7) register r (1..R9): class (1 i, 2 f, 3 p, 4 x, 5 y, 6 m), then six columns
270 REM             for phase 5 (first definition, last use, interval start and end, machine
275 REM             register, spill slot), 0 now
280 REM   K(b,1..4) block b (1..B9, in order of opening): kind (1 loop, 2 do, 3 if, 4 ifz), the
285 REM             instruction that opens it, its else (0: none), the instruction that closes it
290 REM   K(10000+s,1..4)  slot s (1..S9): size, alignment, frame offset (0 now), 0
295 REM   C(r,1..4) the four 16-bit limbs of an i or f field, most significant first (r = 1..M9)
300 REM   S$(r)     the distinct strings of the compilation (escaped, interned: P its hash table), r = 1..A3
305 REM   X(h)      hash set of the distinct sites F*1E9+L of the compilation (instruction sites
308 REM   (per compilation) H(sid) the func of name sid, V$(f) its result classes "/" parameter classes,
309 REM   U$ the forward calls "sid:results/arguments" (hash set) checked at #end, M6 funcs of kind main
310 REM             and func positions), counted against the limit of sites
315 REM Other state: Q Q$ F F$ N N$ W$ Z the record and enumeration tables of passes.txt (tb_records),
320 REM E E$ the error table, J J$ the limits, Y Y$ the entries of rt.inc, D D$ the exit statuses,
325 REM B special code of each record row (below), A the rows of set L, T the open blocks, U the u
330 REM fields of the current record, L four limbs, G$ the fields of the current line, H$ #file paths.
335 REM Special codes B(row): 30 str 31 fmt 32 ftext 33 fconv 34 dat 35 dvi 36 dvf 37 func 38 slot
340 REM   39 endfunc 40 loop 41 endloop 42 do 43 enddo 44 if / ifz 45 else 46 endif 47 exit 48 next
345 REM   50 chk 51 rcall 52 mov 53 ret 54 call; 0 every other instruction.
350 REM State: M8 0 outside a function, 1 after func (slots allowed), 2 in code, 3 in the data.
355 REM ====================================================================================
360 FILES "sea.lir1"; "sea.lir"
365 DIM E(299), E$(299,5), N(39,2), N$(39), W$(299), Q(399,9), Q$(399), F(1499,3), F$(1499), Z(8)
370 DIM J(299,4), J$(299), Y(399), Y$(399,5), D(39), D$(39), B(399), A(399)
375 DIM I(199999,4), O(799999), R(99999,7), K(19999,4), C(199999,4), S$(199999)
380 DIM X(131071), T(10000), G$(300), U(40), L(4), H$(100), A$(2)
382 DIM M(301), P(262143), H(199999), V$(49999), U$(131071)
385 LET P$ = "seaopt"
390 REM ---- the tables of the contract files, in the order of the DATA blocks -------------------
395 CALL "tb_errors": P$, E(), E$(), 299, E0
400 CALL "tb_exits": P$, E(), E$(), E0, D(), D$(), 39, N5
405 CALL "tb_consts": P$, E(), E$(), E0, J(), J$(), 299, N6
410 CALL "tb_entries": P$, E(), E$(), E0, Y(), Y$(), 399, N7
415 LET Z(1) = 39
420 LET Z(2) = 299
425 LET Z(3) = 399
430 LET Z(4) = 1499
435 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), Q(), Q$(), F(), F$(), Z()
440 REM ---- the limits (limits.inc), against the sizes of the DIMs above ------------------------
445 LET Z$ = "FILE_VERSION"
450 GOSUB 2310
455 LET V9 = V
460 LET Z$ = "LIM_LIR_INSTRS"
465 GOSUB 2310
470 LET I9 = V
475 LET Z$ = "LIM_LIR_OPERANDS"
480 GOSUB 2310
485 LET O9 = V
490 LET Z$ = "LIM_LIR_REGS"
495 GOSUB 2310
500 LET R9 = V
505 LET Z$ = "LIM_LIR_BLOCKS"
510 GOSUB 2310
515 LET B9 = V
520 LET Z$ = "LIM_LIR_SLOTS"
525 GOSUB 2310
530 LET S9 = V
535 LET Z$ = "LIM_LIR_IMMS"
540 GOSUB 2310
545 LET M9 = V
550 LET Z$ = "LIM_LIR_LABELS"
555 GOSUB 2310
560 LET Q9 = V
565 LET Z$ = "LIM_LIR_SITES"
570 GOSUB 2310
575 LET S8 = V
580 LET M$ = "a LIR limit is larger than the arrays of seaopt"
585 IF I9 > 199999 THEN 2205
590 IF O9 > 799999 THEN 2205
595 IF R9 > 99999 THEN 2205
600 IF B9 > 9999 THEN 2205
605 IF S9 > 9999 THEN 2205
610 IF M9 > 199999 THEN 2205
615 IF S8 > 60000 THEN 2205
620 REM ---- the rows of set L and the special code of every record row ---------------------------
625 LET K1$ = "|str=30|fmt=31|ftext=32|fconv=33|dat=34|dvi=35|dvf=36|func=37|slot=38|endfunc=39|loop=40|endloop=41|"
630 LET K2$ = "|do=42|enddo=43|if=44|ifz=44|else=45|endif=46|exit=47|next=48|chk=50|rcall=51|mov=52|ret=53|call=54|"
635 LET A8 = 0
640 FOR I1 = 1 TO Z(7)
645 LET B(I1) = 0
650 IF Q(I1, 1) <> 5 THEN 705
655 LET A8 = A8 + 1
660 LET A(A8) = I1
665 LET K3$ = "|" & Q$(I1) & "="
670 LET P1 = POS(K1$, K3$)
675 IF P1 > 0 THEN 700
680 LET P1 = POS(K2$, K3$)
685 IF P1 = 0 THEN 705
690 LET B(I1) = VAL(SEG$(K2$, P1 + LEN(K3$), P1 + LEN(K3$) + 1))
695 GOTO 705
700 LET B(I1) = VAL(SEG$(K1$, P1 + LEN(K3$), P1 + LEN(K3$) + 1))
705 NEXT I1
710 REM ---- header: copied to sea.lir ----------------------------------------------------------
715 CALL "io_hdr": 1, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), V9, T$, H$(), 100, N1, L$
720 LET L0 = N1 + 3
725 SCRATCH #2
730 CALL "io_hdr_put": 2, V9, T$, H$(), N1
735 REM ---- one record per round: L$ is line L0 -------------------------------------------------
740 LET D$ = "BAD_RECORD"
745 CALL "io_plain": L$, O1
750 LET M$ = "a byte outside 0x20-0x7E"
755 IF O1 = 0 THEN 2180
760 CALL "io_split": L$, G$(), 300, C0
765 LET M$ = "empty record, a blank at its start or end, two blanks in a row, or more than 300 fields"
770 IF C0 < 1 THEN 2180
775 IF G$(1) = "#end" THEN 2085
780 REM the record row: the opcode among the rows of set L
785 LET I0 = 0
790 FOR I1 = 1 TO A8
795 IF Q$(A(I1)) <> G$(1) THEN 810
800 LET I0 = A(I1)
805 GOTO 825
810 NEXT I1
815 LET M$ = "unknown opcode '" & G$(1) & "' for format lir1"
820 GOTO 2180
825 LET Y0 = B(I0)
830 LET D7 = 0
835 IF Y0 = 37 THEN 880
840 IF Y0 = 38 THEN 970
845 IF Y0 = 39 THEN 1055
850 IF Y0 = 0 THEN 995
855 IF Y0 >= 40 THEN 995
860 REM a data record (str fmt dat and their sub-records): validated, copied as read, never stored
865 LET D7 = 1
870 GOTO 1055
875 REM ---- func: starts a function, numbers restart from 1 ---------------------------------------
880 LET M$ = "func inside a function, or after the data records"
885 IF M8 <> 0 THEN 2180
890 LET M8 = 1
895 LET M7 = 0
900 LET S6 = 0
905 LET B1 = 0
910 LET B2 = 0
915 LET A0 = 0
920 LET A1 = 0
925 LET A2 = 0
930 LET A5 = 0
931 LET Y1$ = ""
932 LET Y2$ = ""
935 LET F7 = 0
940 LET F8 = 0
945 LET F9 = 0
950 LET I(0, 1) = I0
955 LET I(0, 2) = 1
960 LET I(0, 4) = 0
965 GOTO 1055
970 LET M$ = "slot record not directly after func"
975 IF M8 <> 1 THEN 2180
980 LET D7 = 2
985 GOTO 1055
990 REM ---- an instruction (including the block records): only inside a function ----------------
995 LET M$ = "instruction outside a function"
1000 IF M8 = 0 THEN 2180
1005 LET M$ = "instruction after the data records"
1010 IF M8 = 3 THEN 2180
1015 LET M8 = 2
1020 LET A0 = A0 + 1
1025 IF A0 > I9 THEN 2220
1030 LET I(A0, 1) = I0
1035 LET I(A0, 2) = A1 + 1
1040 LET I(A0, 3) = 0
1045 LET I(A0, 4) = 0
1050 REM ---- the fields: types, counts and the repeated fields -----------------------------------
1055 LET T0 = 1
1060 FOR J1 = 1 TO Q(I0, 4)
1065 LET B0 = Q(I0, 3) + J1 - 1
1070 LET U(J1) = 0
1075 LET X0 = 1
1080 IF F(B0, 3) = 0 THEN 1090
1085 LET X0 = U(F(B0, 3))
1090 FOR X1 = 1 TO X0
1095 LET T0 = T0 + 1
1100 LET M$ = "too few fields: " & F$(B0) & " is missing"
1105 IF T0 > C0 THEN 2180
1110 LET Z$ = G$(T0)
1115 LET T1 = F(B0, 1)
1120 LET O2 = F(B0, 2)
1125 GOSUB 2350
1127 GOSUB 3900
1130 IF D7 > 0 THEN 1140
1135 GOSUB 3050
1140 NEXT X1
1145 NEXT J1
1150 LET M$ = "too many fields"
1155 IF T0 < C0 THEN 2180
1160 REM ---- what the record means -----------------------------------------------------------------
1165 LET D$ = "BAD_RECORD"
1170 IF Y0 = 37 THEN 1205
1175 IF Y0 = 38 THEN 1220
1180 IF Y0 = 39 THEN 1290
1185 IF Y0 = 0 THEN 1335
1190 IF Y0 >= 40 THEN 1335
1195 GOTO 1860
1200 REM ---- func: all its fields are stored in row 0 ------------------------------------------------
1205 GOTO 4400
1210 GOTO 2060
1215 REM ---- slot id size align: recorded in K, rows 10000 + s -----------------------------------------
1220 LET S6 = S6 + 1
1225 IF S6 > S9 THEN 2260
1230 LET W1 = 1
1235 IF W1 >= U(3) THEN 1250
1240 LET W1 = W1 * 2
1245 GOTO 1235
1250 LET M$ = "slot alignment " & STR$(U(3)) & " is not a power of two"
1255 IF W1 <> U(3) THEN 2180
1260 LET K(10000 + S6, 1) = U(2)
1265 LET K(10000 + S6, 2) = U(3)
1270 LET K(10000 + S6, 3) = 0
1275 LET K(10000 + S6, 4) = 0
1280 GOTO 2060
1285 REM ---- endfunc: the function is complete, write it ------------------------------------------------
1290 LET M$ = "endfunc outside a function"
1295 IF M8 = 0 THEN 2180
1300 IF M8 = 3 THEN 2180
1305 LET M$ = "endfunc with open blocks"
1310 IF B1 > 0 THEN 2180
1315 GOSUB 3285
1320 LET M8 = 0
1325 GOTO 2060
1330 REM ---- an instruction: operand count, then the checks of its kind ----------------------------------
1335 LET I(A0, 3) = A1 - I(A0, 2) + 1
1340 IF Y0 = 51 THEN 1680
1345 IF Y0 = 52 THEN 1655
1346 IF Y0 = 50 THEN 4500
1347 IF Y0 = 53 THEN 4520
1348 IF Y0 = 54 THEN 4560
1350 IF Y0 < 40 THEN 2060
1355 IF Y0 > 48 THEN 2060
1360 LET V = U(1)
1365 REM loop, do, if, ifz open block V; blocks are numbered from 1 in order of opening
1370 IF Y0 = 40 THEN 1475
1375 IF Y0 = 42 THEN 1475
1380 IF Y0 = 44 THEN 1475
1385 IF Y0 = 45 THEN 1575
1390 IF Y0 = 47 THEN 1615
1395 IF Y0 = 48 THEN 1615
1400 REM endloop, enddo, endif: close the innermost block, which must be of that kind and number
1405 LET M$ = "end of block " & STR$(V) & " does not match the innermost open block"
1410 IF B1 = 0 THEN 2180
1415 IF T(B1) <> V THEN 2180
1420 LET W1 = K(V, 1)
1425 IF Y0 = 41 THEN 1445
1430 IF Y0 = 43 THEN 1455
1435 IF W1 < 3 THEN 2180
1440 GOTO 1460
1445 IF W1 <> 1 THEN 2180
1450 GOTO 1460
1455 IF W1 <> 2 THEN 2180
1460 LET K(V, 4) = A0
1465 LET B1 = B1 - 1
1470 GOTO 2060
1475 LET M$ = "block " & STR$(V) & " opened where " & STR$(B2 + 1) & " was expected (blocks count from 1)"
1480 IF V <> B2 + 1 THEN 2180
1485 LET B2 = V
1490 IF B2 > B9 THEN 2250
1495 LET B1 = B1 + 1
1500 LET T(B1) = V
1505 LET K(V, 1) = 3
1510 IF Y0 = 40 THEN 1535
1515 IF Y0 = 42 THEN 1545
1520 IF Q$(I0) <> "ifz" THEN 1550
1525 LET K(V, 1) = 4
1530 GOTO 1550
1535 LET K(V, 1) = 1
1540 GOTO 1550
1545 LET K(V, 1) = 2
1550 LET K(V, 2) = A0
1555 LET K(V, 3) = 0
1560 LET K(V, 4) = 0
1565 GOTO 2060
1570 REM else: the innermost open block is an if or ifz without else
1575 LET M$ = "else without an open if of the same number"
1580 IF B1 = 0 THEN 2180
1585 IF T(B1) <> V THEN 2180
1590 IF K(V, 1) < 3 THEN 2180
1595 IF K(V, 3) <> 0 THEN 2180
1600 LET K(V, 3) = A0
1605 GOTO 2060
1610 REM exit, next: V names an enclosing loop or do (kind 1 or 2)
1615 LET M$ = "exit / next names block " & STR$(V) & ", which is not an open loop or do"
1620 FOR W1 = B1 TO 1 STEP -1
1625 IF T(W1) <> V THEN 1640
1630 IF K(V, 1) > 2 THEN 2180
1635 GOTO 2060
1640 NEXT W1
1645 GOTO 2180
1650 REM mov d a: the same class (3.6.4)
1655 LET P1 = I(A0, 2)
1660 LET M$ = "mov of registers of different classes"
1665 IF R(O(P1), 1) <> R(O(P1 + 1), 1) THEN 2180
1670 GOTO 2060
1675 REM rcall entry site nr d.. na a..: an entry of rt.inc, its site, result and argument classes
1680 LET P1 = I(A0, 2)
1685 LET Z$ = S$(O(P1))
1690 LET W0 = 0
1695 FOR W1 = 1 TO N7
1700 IF Y$(W1, 2) <> Z$ THEN 1715
1705 LET W0 = W1
1710 GOTO 1730
1715 NEXT W1
1720 LET M$ = "rcall names '" & Z$ & "', which rt.inc does not list as an entry point"
1725 GOTO 2180
1730 LET M$ = "rcall " & Z$ & ": the site must be present exactly for an entry that can fail"
1735 IF Y$(W0, 3) = "S" THEN 1750
1740 IF I(A0, 4) <> 0 THEN 2180
1745 GOTO 1755
1750 IF I(A0, 4) = 0 THEN 2180
1755 LET R1$ = Y$(W0, 5)
1760 LET P2 = P1 + 1
1765 LET M$ = "rcall " & Z$ & ": results do not match the entry (" & R1$ & ")"
1770 GOSUB 1805
1775 LET R1$ = Y$(W0, 4)
1780 LET M$ = "rcall " & Z$ & ": arguments do not match the entry (" & R1$ & ")"
1785 GOSUB 1805
1790 GOTO 2060
1795 REM rcl: O(P2) is a count, then that many registers; R1$ lists their classes ("-": none);
1800 REM P2 ends on the next field. Fails with M$.
1805 LET W2 = LEN(R1$)
1810 IF R1$ = "-" THEN 1820
1815 GOTO 1825
1820 LET W2 = 0
1825 IF O(P2) <> W2 THEN 2180
1830 FOR W3 = 1 TO W2
1835 IF POS("ifpxym", SEG$(R1$, W3, W3)) <> R(O(P2 + W3), 1) THEN 2180
1840 NEXT W3
1845 LET P2 = P2 + W2 + 1
1850 RETURN
1855 REM ---- data records: str fmt dat and their sub-records ftext fconv dvi dvf ----------------------------
1860 IF X9 = 0 THEN 1935
1865 LET M$ = "ftext / fconv records expected after fmt"
1870 IF Z8 > 0 THEN 1890
1875 IF Y0 = 32 THEN 1925
1880 IF Y0 = 33 THEN 1925
1885 GOTO 2180
1890 LET M$ = "dvi records expected after dat of i64 or bool"
1895 IF Z8 > 1 THEN 1910
1900 IF Y0 = 35 THEN 1925
1905 GOTO 2180
1910 LET M$ = "dvf records expected after dat of f64"
1915 IF Y0 = 36 THEN 1925
1920 GOTO 2180
1925 LET X9 = X9 - 1
1930 GOTO 2060
1935 LET M$ = "ftext, fconv, dvi or dvf record outside its fmt or dat"
1940 IF Y0 = 30 THEN 1965
1945 IF Y0 = 31 THEN 1965
1950 IF Y0 = 34 THEN 1965
1955 GOTO 2180
1960 REM str, fmt, dat: after the last function; labels d1, d2, ... in order
1965 LET M$ = "data record inside a function"
1970 IF M8 = 1 THEN 2180
1975 IF M8 = 2 THEN 2180
1980 LET M8 = 3
1985 LET V = U(1)
1990 LET M$ = "data label d" & STR$(V) & " where d" & STR$(D8 + 1) & " was expected"
1995 IF V <> D8 + 1 THEN 2180
2000 LET D8 = V
2005 IF D8 > Q9 THEN 2280
2010 IF Y0 = 30 THEN 2060
2015 IF Y0 = 31 THEN 2045
2020 LET X9 = U(3)
2025 LET Z8 = 2
2030 IF E1$ = "f64" THEN 2060
2035 LET Z8 = 1
2040 GOTO 2060
2045 LET X9 = U(2)
2050 LET Z8 = 0
2055 REM ---- next record: a data record is copied as read -------------------------------------------------
2060 IF D7 <> 1 THEN 2070
2065 CALL "io_put": 2, L$
2070 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
2075 GOTO 740
2080 REM ---- #end: nothing may be open, nothing may follow ------------------------------------------------
2085 LET M$ = "#end carries fields"
2090 IF C0 <> 1 THEN 2180
2095 LET D$ = "BAD_RECORD"
2100 LET M$ = "a function is not closed by endfunc"
2105 IF M8 = 1 THEN 2180
2110 IF M8 = 2 THEN 2180
2115 LET M$ = "sub-records of the last fmt or dat are missing"
2120 IF X9 > 0 THEN 2180
2125 LET M$ = "data label d" & STR$(R8) & " is used but only " & STR$(D8) & " are defined"
2130 IF R8 > D8 THEN 2180
2135 REM lir1 numbers data labels by first reference, so none is without a user (3.6.2)
2140 LET M$ = "data label d" & STR$(D8) & " is defined but no instruction uses it (lir1 numbers labels by first use; " & STR$(R8) & " are used)"
2145 IF R8 < D8 THEN 2180
2146 LET M$ = "the file has " & STR$(M6) & " funcs of kind main, not one"
2147 IF M6 <> 1 THEN 2180
2148 GOSUB 4970
2160 CALL "io_end": 1, P$, E(), E$(), E0
2165 CALL "io_fin": 2
2170 STOP
2175 REM ---- failure: say where, then the internal error of errors.inc (status 11) ----------------------------
2180 CALL "dg_internal": P$, D$, E(), E$(), E0
2195 STOP 11
2200 REM ---- a pass bug, not a bad input -------------------------------------------------------------------------
2205 CALL "dg_bug": P$, M$
2210 STOP 11
2215 REM ---- capacity limits: "program too large: <word>" at the position of the func record ----------------------
2220 LET A$(1) = "instructions"
2225 GOTO 2295
2230 LET A$(1) = "operands"
2235 GOTO 2295
2240 LET A$(1) = "registers"
2245 GOTO 2295
2250 LET A$(1) = "blocks"
2255 GOTO 2295
2260 LET A$(1) = "slots"
2265 GOTO 2295
2270 LET A$(1) = "immediates"
2275 GOTO 2295
2280 LET A$(1) = "labels"
2285 GOTO 2295
2290 LET A$(1) = "sites"
2295 CALL "dg_compile": P$, H$(), N1, F7, F8, F9, "TOO_LARGE", A$(), 1, E(), E$(), E0
2300 STOP 10
2305 REM ---- subroutine: V = the constant named Z$ of limits.inc ----------------------------------------------
2310 CALL "tb_cval": J(), J$(), N6, Z$, V, T
2315 IF T = 0 THEN 2330
2320 LET M$ = "constant " & Z$ & " is not in the consts table"
2325 GOTO 2205
2330 RETURN
2335 REM ---- subroutine chk: validate the field Z$ of type T1 (optional if O2 = 1) -----------------------------------
2340 REM Result: V (u, lab, slot, blk, reg: the number; an enumeration: the position of its word),
2345 REM L(1..4) (i, f), F1 L1 C1 (pos, site), A9 = 1 for an absent field (V = -1 for u, else 0).
2350 LET B$ = "field " & F$(B0) & " ('" & Z$ & "')"
2355 LET M$ = B$
2360 LET A9 = 0
2365 IF O2 = 0 THEN 2400
2370 IF Z$ <> "-" THEN 2400
2375 LET A9 = 1
2380 LET V = 0
2385 IF T1 <> 1 THEN 2395
2390 LET V = -1
2395 RETURN
2400 IF T1 >= 100 THEN 2975
2405 ON T1 GOTO 2415, 2440, 2455, 2475, 2530, 2540, 2590, 2640, 2640, 2640, 2640, 2640, 2655, 2685, 2755, 2825, 2825, 2825, 2825, 2825, 2825, 2825
2410 REM u: unsigned decimal
2415 CALL "io_u": Z$, V, T
2420 IF T <> 0 THEN 3015
2425 LET U(J1) = V
2430 RETURN
2435 REM i: decimal, or hex for |v| >= 1E9; f: # and 16 hex digits; both leave the limbs in L
2440 CALL "io_i": Z$, V, K1, L(), T
2445 IF T <> 0 THEN 3015
2450 RETURN
2455 CALL "io_f": Z$, L(), T
2460 IF T <> 0 THEN 3015
2465 RETURN
2470 REM s: escaped string; a chk record names an error of errors.inc with phase R
2475 CALL "io_unesc": Z$, 0, R1$, T
2480 IF T <> 0 THEN 3015
2485 IF Y0 <> 50 THEN 2395
2490 IF F$(B0) <> "err" THEN 2395
2495 CALL "dg_find": R1$, E$(), E0, W1
2500 LET M$ = B$ & " is not a name of the error table"
2505 IF W1 = 0 THEN 2180
2510 LET M$ = B$ & " (a chk names a run-time error)"
2515 IF E$(W1, 2) <> "R" THEN 2180
2516 GOSUB 4700
2520 RETURN
2525 REM pos F:L:C and site F:L: the file index must name a #file record; the func record sets F7 F8 F9
2530 CALL "io_pos": Z$, F1, L1, C1, T
2535 GOTO 2545
2540 CALL "io_site": Z$, F1, L1, T
2545 IF T <> 0 THEN 3015
2550 LET M$ = B$ & " names file " & STR$(F1) & " but the header has " & STR$(N1) & " #file records"
2555 IF F1 >= N1 THEN 2180
2560 IF Y0 <> 37 THEN 2395
2565 LET F7 = F1
2570 LET F8 = L1
2575 LET F9 = C1
2580 RETURN
2585 REM fl: - or the letters l p s z a, each at most once, in this order (data fconv records)
2590 IF Z$ = "-" THEN 2395
2595 LET P1 = 0
2600 FOR W1 = 1 TO LEN(Z$)
2605 LET X2 = POS("lpsza", SEG$(Z$, W1, W1))
2610 IF X2 = 0 THEN 3015
2615 IF X2 <= P1 THEN 3015
2620 LET P1 = X2
2625 NEXT W1
2630 RETURN
2635 REM a field type that has no place in a LIR record (ty lid fid cid iid): passes.txt and this pass disagree
2640 LET M$ = "passes.txt gives record " & Q$(I0) & " a field type seaopt does not know"
2645 GOTO 2205
2650 REM blk: a block number from 1 (nesting is checked per record)
2655 CALL "io_u": Z$, V, T
2660 IF T <> 0 THEN 3015
2665 IF V < 1 THEN 3015
2670 LET U(J1) = V
2675 RETURN
2680 REM lab: d and a number; instructions use labels in order of first reference (lir1)
2685 IF LEN(Z$) < 2 THEN 3015
2690 IF SEG$(Z$, 1, 1) <> "d" THEN 3015
2695 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), V, T
2700 IF T <> 0 THEN 3015
2705 IF V < 1 THEN 3015
2710 LET U(J1) = V
2715 IF D7 = 1 THEN 2395
2720 LET M$ = B$ & " is used before d" & STR$(R8 + 1) & " (lir1 numbers labels by first use)"
2725 IF V > R8 + 1 THEN 2180
2730 IF V <= R8 THEN 2395
2735 LET R8 = V
2740 IF R8 > Q9 THEN 2280
2745 RETURN
2750 REM slot: s and a number; defined in order by slot records, used by instructions
2755 IF LEN(Z$) < 2 THEN 3015
2760 IF SEG$(Z$, 1, 1) <> "s" THEN 3015
2765 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), V, T
2770 IF T <> 0 THEN 3015
2775 IF V < 1 THEN 3015
2780 LET U(J1) = V
2785 IF Y0 = 38 THEN 2805
2790 LET M$ = B$ & " names a slot that func has not declared (" & STR$(S6) & " so far)"
2795 IF V > S6 THEN 2180
2800 RETURN
2805 LET M$ = B$ & " where s" & STR$(S6 + 1) & " was expected (slots count from 1)"
2810 IF V <> S6 + 1 THEN 2180
2815 RETURN
2820 REM reg, ri rf rp rx ry rm: a class letter and a number; numbers in order of first appearance
2825 IF LEN(Z$) < 2 THEN 3015
2830 LET X2 = POS("ifpxym", SEG$(Z$, 1, 1))
2835 IF X2 = 0 THEN 3015
2840 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), V, T
2845 IF T <> 0 THEN 3015
2850 IF V < 1 THEN 3015
2855 IF T1 = 16 THEN 2875
2860 IF X2 = T1 - 16 THEN 2875
2865 LET M$ = B$ & " has the wrong register class here"
2870 GOTO 2180
2875 LET M$ = B$ & " has a vector or mask class, which sea.lir1 does not use"
2880 IF X2 > 3 THEN 2180
2885 IF V <= M7 THEN 2955
2890 LET M$ = B$ & " is not the next register (" & STR$(M7 + 1) & " is: numbers follow first appearance)"
2895 IF V <> M7 + 1 THEN 2180
2900 IF V > R9 THEN 2240
2905 REM a new register: class from its letter, the phase-5 columns zero
2910 LET M7 = V
2915 LET R(V, 1) = X2
2920 LET R(V, 2) = 0
2925 LET R(V, 3) = 0
2930 LET R(V, 4) = 0
2935 LET R(V, 5) = 0
2940 LET R(V, 6) = 0
2945 LET R(V, 7) = 0
2950 RETURN
2955 LET M$ = B$ & " was used before with another class"
2960 IF R(V, 1) <> X2 THEN 2180
2965 RETURN
2970 REM an enumeration: a word listed in passes.txt (an elt field is remembered for dat)
2975 LET X2 = T1 - 100
2980 CALL "tb_word": N(), W$(), X2, Z$, W1
2985 IF W1 = 0 THEN 3015
2990 LET V = W1
2995 IF F$(B0) <> "elt" THEN 2395
3000 LET E1$ = Z$
3005 RETURN
3010 REM the field is not valid for its type
3015 IF T1 >= 100 THEN 3030
3020 LET M$ = B$ & " is not a valid " & SEG$("u    i    f    s    pos  site fl   ty   lid  fid  cid  iid  blk  lab  slot reg  ri   rf   rp   rx   ry   rm   ", 5 * T1 - 4, 5 * T1)
3025 GOTO 2180
3030 LET M$ = B$ & " is not a word of enumeration " & N$(T1 - 100)
3035 GOTO 2180
3040 REM ---- subroutine sto: store the validated field into the tables ------------------------------------------------
3045 REM site: into I(A0,4); pos: two operands; s: a row of S$; i and f: a row of C; the rest: V itself.
3050 LET V1 = V
3055 IF T1 = 6 THEN 3100
3060 IF T1 = 5 THEN 3130
3065 IF T1 = 4 THEN 3160
3070 IF T1 = 2 THEN 3176
3075 IF T1 = 3 THEN 3180
3080 IF Y0 = 37 THEN 3093
3081 LET A1 = A1 + 1
3085 IF A1 > O9 THEN 2230
3090 LET O(A1) = V1
3091 RETURN
3093 LET A5 = A5 + 1
3094 LET M(A5) = V1
3095 RETURN
3100 IF A9 = 1 THEN 3120
3105 LET I(A0, 4) = F1 * 1E9 + L1
3110 LET K5 = I(A0, 4)
3115 GOTO 3220
3120 LET I(A0, 4) = 0
3125 RETURN
3130 LET V1 = F1 * 1E9 + L1
3135 GOSUB 3080
3140 LET V1 = C1
3145 GOSUB 3080
3150 LET K5 = F1 * 1E9 + L1
3155 GOTO 3220
3160 GOSUB 5000
3165 LET V1 = Q2
3170 GOTO 3080
3176 IF F$(B0) <> "off" THEN 3180
3177 GOSUB 5100
3178 GOTO 3080
3180 LET A2 = A2 + 1
3185 IF A2 > M9 THEN 2270
3190 FOR W1 = 1 TO 4
3195 LET C(A2, W1) = L(W1)
3200 NEXT W1
3205 LET V1 = A2
3210 GOTO 3080
3215 REM site K5 (F*1E9+L) into the hash set of the compilation; more than the limit is an error
3220 LET K4 = K5 - INT(K5 / 131071) * 131071
3225 IF X(K4) = 0 THEN 3255
3230 IF X(K4) = K5 THEN 3270
3235 LET K4 = K4 + 1
3240 IF K4 <= 131071 THEN 3225
3245 LET K4 = 0
3250 GOTO 3225
3255 LET X(K4) = K5
3260 LET A4 = A4 + 1
3265 IF A4 > S8 THEN 2290
3270 RETURN
3275 REM ---- subroutine wfunc: write the function held in the tables ------------------------------------------------------
3280 REM row 0 is the func record, then the slots, then the instructions 1..A0, then endfunc
3285 LET N9 = 0
3290 GOSUB 3340
3295 FOR W5 = 1 TO S6
3300 CALL "io_put": 2, "slot s" & STR$(W5) & " " & STR$(K(10000 + W5, 1)) & " " & STR$(K(10000 + W5, 2))
3305 NEXT W5
3310 FOR N9 = 1 TO A0
3315 GOSUB 3340
3320 NEXT N9
3325 CALL "io_put": 2, "endfunc"
3330 RETURN
3335 REM wrec: write record N9 (a row of I): the opcode, then every field by its type in passes.txt
3340 LET W0 = I(N9, 1)
3345 LET B$ = Q$(W0)
3350 LET P1 = I(N9, 2)
3355 FOR W1 = 1 TO Q(W0, 4)
3360 LET W2 = Q(W0, 3) + W1 - 1
3365 LET U(W1) = 0
3370 LET W3 = 1
3375 IF F(W2, 3) = 0 THEN 3385
3380 LET W3 = U(F(W2, 3))
3385 FOR W4 = 1 TO W3
3390 GOSUB 3425
3395 LET B$ = B$ & " " & S1$
3400 NEXT W4
3405 NEXT W1
3410 CALL "io_put": 2, B$
3415 RETURN
3420 REM wtok: S1$ = the next field, T1 its type; P1 advances over its operands
3425 LET T1 = F(W2, 1)
3427 GOSUB 3815
3430 IF T1 >= 100 THEN 3565
3435 ON T1 GOTO 3440, 3702, 3665, 3550, 3585, 3610, 3805, 3805, 3805, 3805, 3805, 3805, 3475, 3490, 3505, 3520, 3520, 3520, 3520, 3520, 3520, 3520
3440 LET V = Q0
3445 LET P1 = P1 + 1
3450 LET U(W1) = V
3455 LET S1$ = "-"
3460 IF V < 0 THEN 3545
3465 LET S1$ = STR$(V)
3470 RETURN
3475 LET S1$ = STR$(O(P1))
3476 LET S1$ = STR$(Q0)
3480 LET P1 = P1 + 1
3485 RETURN
3490 LET S1$ = "d" & STR$(Q0)
3495 LET P1 = P1 + 1
3500 RETURN
3505 LET S1$ = "s" & STR$(Q0)
3510 LET P1 = P1 + 1
3515 RETURN
3520 LET V = Q0
3525 LET P1 = P1 + 1
3530 LET S1$ = "-"
3535 IF V = 0 THEN 3545
3540 LET S1$ = SEG$("ifpxym", R(V, 1), R(V, 1)) & STR$(V)
3545 RETURN
3550 LET S1$ = S$(Q0)
3555 LET P1 = P1 + 1
3560 RETURN
3565 LET S1$ = W$(N(T1 - 100, 1) + Q0 - 1)
3570 LET P1 = P1 + 1
3575 RETURN
3580 REM pos F:L:C and site F:L (F*1E9+L, 0: absent)
3585 LET W6 = Q0
3590 LET W7 = Q1
3595 LET P1 = P1 + 2
3600 LET S1$ = ""
3605 GOTO 3635
3610 LET W6 = I(N9, 4)
3615 LET W7 = 0
3620 LET S1$ = "-"
3625 IF W6 = 0 THEN 3545
3630 LET S1$ = ""
3635 LET W8 = INT(W6 / 1E9)
3640 LET S1$ = STR$(W8) & ":" & STR$(W6 - W8 * 1E9)
3645 IF W7 = 0 THEN 3545
3650 LET S1$ = S1$ & ":" & STR$(W7)
3655 RETURN
3660 REM f: always # and 16 hex digits of the limbs
3665 LET W6 = Q0
3670 LET P1 = P1 + 1
3675 FOR W8 = 1 TO 4
3680 LET L(W8) = C(W6, W8)
3685 NEXT W8
3690 CALL "io_hex": L(), S1$
3695 RETURN
3700 REM i: decimal if |v| <= 999999999, else the hex form of the limbs (3.1)
3702 IF F$(W2) = "off" THEN 3850
3705 LET W6 = Q0
3710 LET P1 = P1 + 1
3715 FOR W8 = 1 TO 4
3720 LET L(W8) = C(W6, W8)
3725 NEXT W8
3730 LET W7 = L(3) * 65536 + L(4)
3735 IF L(1) = 0 THEN 3770
3740 IF L(1) <> 65535 THEN 3790
3745 IF L(2) <> 65535 THEN 3790
3750 LET W7 = 65536 * 65536 - W7
3755 IF W7 > 999999999 THEN 3790
3760 LET S1$ = "-" & STR$(W7)
3765 RETURN
3770 IF L(2) <> 0 THEN 3790
3775 IF W7 > 999999999 THEN 3790
3780 LET S1$ = STR$(W7)
3785 RETURN
3790 CALL "io_hex": L(), S1$
3795 RETURN
3800 REM a field type that LIR records do not have
3805 LET M$ = "passes.txt gives record " & Q$(W0) & " a field type seaopt does not know"
3810 GOTO 2205
3812 REM ---- 3815: Q0 Q1 = the operand value at P1 and the next one (record N9; row 0, the func record, is in M) ----
3815 IF N9 = 0 THEN 3835
3820 LET Q0 = O(P1)
3825 LET Q1 = 0
3830 RETURN
3835 LET Q0 = M(P1)
3840 LET Q1 = M(P1 + 1)
3845 RETURN
3848 REM ---- 3850: an off field (its exact value Q0): decimal for |v| <= 999999999, else # and 16 hex digits ----
3850 LET W6 = Q0
3852 LET P1 = P1 + 1
3854 IF ABS(W6) > 999999999 THEN 3860
3856 LET S1$ = STR$(W6)
3858 RETURN
3860 LET W7 = ABS(W6)
3862 FOR W8 = 4 TO 1 STEP -1
3864 LET L(W8) = W7 - INT(W7 / 65536) * 65536
3866 LET W7 = INT(W7 / 65536)
3868 NEXT W8
3870 IF W6 > 0 THEN 3890
3872 FOR W8 = 1 TO 4
3874 LET L(W8) = 65535 - L(W8)
3876 NEXT W8
3878 LET W8 = 4
3880 LET L(W8) = L(W8) + 1
3882 IF L(W8) < 65536 THEN 3890
3884 LET L(W8) = 0
3886 LET W8 = W8 - 1
3888 GOTO 3880
3890 CALL "io_hex": L(), S1$
3892 RETURN
3897 REM ---- 3900: the checks of one validated field beyond its type (DESIGN 3.6.5), called after 2350 ----
3900 IF A9 = 1 THEN 3995
3905 IF Y0 <> 37 THEN 3940
3910 IF F$(B0) <> "par" THEN 3925
3915 LET M$ = B$ & " is parameter " & STR$(X1) & ", so it must be register " & STR$(X1)
3918 IF V <> X1 THEN 2180
3920 LET Y2$ = Y2$ & SEG$("ifp", X2, X2)
3922 GOTO 3995
3925 IF F$(B0) <> "cls" THEN 3995
3930 LET Y1$ = Y1$ & Z$
3935 GOTO 3995
3940 IF Y0 <> 33 THEN 3965
3945 IF F$(B0) <> "conv" THEN 3950
3947 LET G1$ = Z$
3950 IF F$(B0) <> "cls" THEN 3995
3952 LET M$ = "fconv " & G1$ & " with class " & Z$ & " (class p exactly for conversion s)"
3954 IF G1$ = "s" THEN 3960
3956 IF Z$ = "p" THEN 2180
3958 GOTO 3995
3960 IF Z$ <> "p" THEN 2180
3962 GOTO 3995
3965 IF T1 <> 1 THEN 3975
3967 IF F$(B0) = "incl" THEN 3971
3968 IF F$(B0) <> "dim" THEN 3995
3971 LET M$ = B$ & " must be 0 or 1"
3972 IF V > 1 THEN 2180
3973 GOTO 3995
3975 IF T1 < 16 THEN 3995
3977 IF T1 > 22 THEN 3995
3979 IF F$(B0) = "d" THEN 3985
3981 IF F$(B0) = "e" THEN 3985
3983 IF F$(B0) <> "ind" THEN 3995
3985 LET M$ = B$ & " is written inside a loop whose induction register it is"
3987 FOR Q1 = 1 TO B1
3989 IF K(T(Q1), 1) <> 1 THEN 3993
3991 IF O(I(K(T(Q1), 2), 2) + 1) = V THEN 2180
3993 NEXT Q1
3995 RETURN
4395 REM ---- 4400: func: .main, a unique name, the signature its calls must match (DESIGN 3.6.5) ----
4400 LET I(0, 3) = A5
4405 LET Q2 = M(1)
4410 LET M$ = "func " & S$(Q2) & ": kind main exactly for the name .main, which has no results"
4415 IF M(2) = 1 THEN 4440
4420 IF LEN(S$(Q2)) <> 5 THEN 4455
4425 IF S$(Q2) = ".main" THEN 2180
4430 GOTO 4455
4440 IF LEN(S$(Q2)) <> 5 THEN 2180
4442 IF S$(Q2) <> ".main" THEN 2180
4444 IF LEN(Y1$) > 0 THEN 2180
4446 LET M6 = M6 + 1
4448 LET M$ = "a second func of kind main"
4450 IF M6 > 1 THEN 2180
4455 LET M$ = "func " & S$(Q2) & " is defined twice"
4460 IF H(Q2) <> 0 THEN 2180
4465 LET F6 = F6 + 1
4470 LET M$ = "more than 49999 functions"
4475 IF F6 > 49999 THEN 2180
4480 LET H(Q2) = F6
4485 LET V$(F6) = Y1$ & "/" & Y2$
4490 GOTO 2060
4495 REM ---- 4500: chk: n = the argument slots of its error (C3, from 4700) ----
4500 LET M$ = "chk names an error whose arguments take " & STR$(C3) & " slots, but n = " & STR$(U(4))
4505 IF U(4) <> C3 THEN 2180
4510 GOTO 2060
4515 REM ---- 4520: ret: the results of the func, in number and class ----
4520 LET P1 = I(A0, 2)
4525 LET M$ = "ret does not return the results of its func (" & Y1$ & ")"
4530 IF O(P1) <> LEN(Y1$) THEN 2180
4535 FOR Q3 = 1 TO O(P1)
4540 IF R(O(P1 + Q3), 1) <> POS("ifp", SEG$(Y1$, Q3, Q3)) THEN 2180
4545 NEXT Q3
4550 GOTO 2060
4555 REM ---- 4560: call: its signature R2$ = result classes "/" argument classes, against the func (4800) or deferred ----
4560 LET P1 = I(A0, 2)
4565 LET Q2 = O(P1)
4570 LET R2$ = ""
4575 LET P2 = P1 + 1
4580 FOR Q3 = 1 TO O(P2)
4585 LET R2$ = R2$ & SEG$("ifp", R(O(P2 + Q3), 1), R(O(P2 + Q3), 1))
4590 NEXT Q3
4595 LET R2$ = R2$ & "/"
4600 LET P2 = P2 + O(P2) + 1
4605 FOR Q3 = 1 TO O(P2)
4610 LET R2$ = R2$ & SEG$("ifp", R(O(P2 + Q3), 1), R(O(P2 + Q3), 1))
4615 NEXT Q3
4620 IF H(Q2) = 0 THEN 4640
4625 GOSUB 4800
4630 LET M$ = "call " & S$(Q2) & " (" & R2$ & ") does not match its func (" & V$(H(Q2)) & ")"
4632 IF Q5 = 0 THEN 2180
4635 GOTO 2060
4640 LET Z$ = STR$(Q2) & ":" & R2$
4642 GOSUB 4930
4645 GOTO 2060
4695 REM ---- 4700: C3 = the argument slots of error row W1: one per args letter, two for h (DESIGN 2.6.2) ----
4700 LET C3 = 0
4705 LET R2$ = E$(W1, 4)
4710 IF R2$ = "-" THEN 4740
4715 FOR Q3 = 1 TO LEN(R2$)
4720 LET C3 = C3 + 1
4725 IF SEG$(R2$, Q3, Q3) <> "h" THEN 4735
4730 LET C3 = C3 + 1
4735 NEXT Q3
4740 RETURN
4795 REM ---- 4800: Q5 = 1 if the call signature R2$ matches func H(Q2): all its results, or none ----
4800 LET Q5 = 0
4805 LET R3$ = V$(H(Q2))
4810 IF LEN(R2$) <> LEN(R3$) THEN 4825
4815 IF R2$ = R3$ THEN 4840
4825 LET R3$ = SEG$(R3$, POS(R3$, "/"), LEN(R3$))
4830 IF LEN(R2$) <> LEN(R3$) THEN 4845
4835 IF R2$ <> R3$ THEN 4845
4840 LET Q5 = 1
4845 RETURN
4895 REM ---- 4900: H1 = a hash of Z$ modulo H2 ----
4900 LET H1 = 0
4905 FOR Q4 = 1 TO LEN(Z$)
4910 LET H1 = H1 * 31 + ASC(SEG$(Z$, Q4, Q4))
4915 LET H1 = H1 - INT(H1 / H2) * H2
4920 NEXT Q4
4925 RETURN
4928 REM ---- 4930: Z$ joins the set U$ of forward calls ----
4930 LET H2 = 131071
4932 GOSUB 4900
4934 IF LEN(U$(H1)) = 0 THEN 4950
4936 IF LEN(U$(H1)) <> LEN(Z$) THEN 4940
4938 IF U$(H1) = Z$ THEN 4960
4940 LET H1 = H1 + 1
4942 IF H1 < 131071 THEN 4934
4944 LET H1 = 0
4946 GOTO 4934
4950 LET Q6 = Q6 + 1
4952 LET M$ = "more distinct forward calls than seaopt holds"
4954 IF Q6 > 131000 THEN 2180
4956 LET U$(H1) = Z$
4960 RETURN
4965 REM ---- 4970: at #end every forward call names a func of the file and matches it (4800) ----
4970 FOR Q3 = 0 TO 131070
4972 IF LEN(U$(Q3)) = 0 THEN 4990
4974 LET Q4 = POS(U$(Q3), ":")
4976 LET Q2 = VAL(SEG$(U$(Q3), 1, Q4 - 1))
4978 LET R2$ = SEG$(U$(Q3), Q4 + 1, LEN(U$(Q3)))
4980 LET M$ = "call of " & S$(Q2) & ", which no func defines"
4982 IF H(Q2) = 0 THEN 2180
4984 GOSUB 4800
4986 LET M$ = "call " & S$(Q2) & " does not match its func"
4988 IF Q5 = 0 THEN 2180
4990 NEXT Q3
4992 RETURN
4995 REM ---- 5000: Q2 = the row of S$ that holds Z$ (interned, DESIGN 2.7; a new row if absent) ----
5000 LET H2 = 262139
5005 GOSUB 4900
5010 IF P(H1) = 0 THEN 5040
5015 LET Q2 = P(H1)
5020 IF LEN(S$(Q2)) <> LEN(Z$) THEN 5030
5025 IF S$(Q2) = Z$ THEN 5060
5030 LET H1 = H1 + 1
5032 IF H1 < 262139 THEN 5010
5034 LET H1 = 0
5036 GOTO 5010
5040 LET A3 = A3 + 1
5045 LET M$ = "more than 199999 distinct strings"
5050 IF A3 > 199999 THEN 2180
5052 LET S$(A3) = Z$
5054 LET P(H1) = A3
5056 LET Q2 = A3
5060 RETURN
5095 REM ---- 5100: V1 = the exact value of an off field (io_i left K1 V L()); |v| above 2^53 is BAD_RECORD ----
5100 LET V1 = V
5105 IF K1 = 0 THEN 5160
5110 LET M$ = B$ & " is an offset beyond 2^53 in magnitude"
5115 IF L(1) < 32768 THEN 5145
5125 IF 65535 - L(1) >= 32 THEN 2180
5130 LET V1 = -((((65535 - L(1)) * 65536 + 65535 - L(2)) * 65536 + 65535 - L(3)) * 65536 + 65535 - L(4) + 1)
5140 GOTO 5160
5145 IF L(1) >= 32 THEN 2180
5150 LET V1 = ((L(1) * 65536 + L(2)) * 65536 + L(3)) * 65536 + L(4)
5160 RETURN
