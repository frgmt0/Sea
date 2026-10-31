69000 CALL "dg_bug": P$, "control fell into lirrw.bas, which is entered only by GOSUB"
69005 REM ====================================================================================
69010 REM lirrw -- the shared main-program part of the LIR passes (DESIGN 2.6.3; L-bd, L-bi, L-bp):
69015 REM pass 3b's LIR reader, validator and writer (3.6.5: the validation list, the capacity limits,
69020 REM the header records, the renumbering writer) and T10 of 5.8 (clean-up and renumbering), moved
69025 REM out of seaopt unchanged so that seaopt and sealopt read, check, clean and write LIR identically.
69030 REM Lines 69000-81999 (they overlap limb and f64emu, which no LIR pass loads). No DATA, no END, no
69035 REM SUB: main-program lines reached by GOSUB, which reach io diag tables by CALL and never jump to
69040 REM a line of the pass. Line 69000 is a guard: control falling into this part is a pass bug.
69045 REM CONTRACT (passes/lib/API.md "lirrw.bas" has the full text). The pass DIMs exactly
69050 REM   E(299) E$(299,5) N(39,2) N$(39) W$(299) Q(399,9) Q$(399) F(1499,3) F$(1499) Z(8) J(299,4)
69055 REM   J$(299) Y(399) Y$(399,5) D(39) D$(39) B(399) A(399) I(199999,4) O(799999) R(99999,9)
69060 REM   K(19999,4) C(199999,4) S$(199999) X(131071) T(10000) G$(300) U(40) L(4) H$(100) A$(2)
69065 REM   M(301) P(262143) H(199999) V$(49999) U$(131071) G(199999,3) W(199999,4)
69070 REM sets P$ (its name), V8 (its input: 1 sea.lir1, 2 sea.lir2 or sea.lir3, 3 sea.lir; L-bu) and FILES 1 = its input,
69075 REM 2 = its output, and leaves to this part the scalars listed in API.md (any entry may change any).
69076 REM V8 = 1 keeps the two sea.lir1-only label rules (3.6.2: labels numbered by first use, none unused); 2 and 3 drop them.
69077 REM V8 = 3 alone accepts the classes x y m and the set-LF records (2.12.6, Decision 113: sea.lir only); the writer
69078 REM writes them whatever V8 is (seavec reads sea.lir3 with V8 = 2 and writes vector code into sea.lir).
69080 REM It may use R(r,c) for c <> 1, 2 (column 2 is T10's), W between entries, the arrays S and V, other names.
69085 REM TABLES of the current function (reset by its func record; operand values are plain numbers):
69090 REM   I(n,1..4) instruction n (1..A0; row 0 the func record): record row in Q, index in O of its
69095 REM             first operand, operand count, site (F*1E9+L, 0 none); I(n,0) and I(n,1) = 0 (deleted
69100 REM             until the next compaction) are the transformations'; I(n,0) = -1 marks a dead record
69105 REM   O(k)      operands in record order (k = 1..A1; the func record's in M(1..I(0,3))): u the value
69110 REM             (-1 absent), reg the number (0 absent), i f a row of C, off a row of G, s a row of S$,
69115 REM             pos two operands F*1E9+L and C, lab slot blk the number, enumeration the word (1..)
69120 REM   R(r,1)    class of register r (1..M7): 1 i 2 f 3 p (4 x 5 y 6 m); R(r,2) T10's read count (V8 = 3: an
69122 REM             m register's lane count, 2 or 4, from the reader until the next T10)
69125 REM   K(b,1..4) block b (1..B2): kind (1 loop 2 do 3 if 4 ifz), opening, else (0 none), closing
69130 REM   K(10000+s,1..2)  slot s (1..S6): size, alignment; C(r,1..4) 16-bit limbs (1..A2); G(r,0..3)
69135 REM             off limbs (1..A6); per compilation S$ (1..A3, hash P), sites X (A4), funcs H V$ U$ M6
69140 REM Contract tables (header entry): Q Q$ F F$ N N$ W$ Z records and enumerations, E E$ errors,
69145 REM J J$ limits, Y Y$ entries, D D$ exit statuses, A the rows of set L (A8), B their special code;
69150 REM Q(row,6) the internal opcode code, Q(row,7) category (1 pure, 2 iaddc isubc imulc inegc, 3
69155 REM load, 4 store), Q(row,8) memory kind, F(field,0) its role (0 site, 1 read, 2 written, 3 i or
69160 REM f immediate, 4 off, 5 u count, 6 other, 7 pos); the rows E2 li E3 lf E4 mov E5 iadd E6 isub
69165 REM E7 imul E8 ineg E9 iand G2 isar G3 imulh G4 icmp G5 isel G6 fsel G7 psel G8 fmul; the cc
69170 REM words C4-C9 (eq ne lt le gt ge); K6 K7 K8 K9 the header offsets ARR_ROWS COLS DATA RC, K0
69175 REM LIM_EXTENT; Y3-Y9 the S$ rows of ARR_NEW ARR_NEW_U ARR_NEW_S SORT ARGSORT ARGS ARR_UNIQUE;
69180 REM N8 = 1E30, U9 = 2^52, Y2 = 0 (functions so far); limits I9 O9 R9 B9 S9 M9 Q9 S8, version V9.
69185 REM ENTRIES (each GOSUB target ends in RETURN; failures end the pass with its message):
69190 REM   69400 header: the contract tables, limits and codes above; header records copied to file 2;
69195 REM         L$ = the first record after them. Once, first.
69200 REM   69410 read: records up to a complete function (Y0 = 39: it is in the tables, validated) or
69205 REM         up to #end (Y0 = -1); data records are validated and copied to file 2 as read.
69210 REM   69420 end of input (after Y0 = -1): the checks of #end, the #end record written; the pass stops.
69215 REM   69430 write the function held in the tables (renumbered by 69440 first).
69220 REM   69440 T10: clean-up until nothing changes, then registers and blocks renumbered.
69225 REM   69450 compact the deleted instructions away, then 69455; 69455 K of every block from the
69230 REM         records; 69460 I(n,0) = -1 for the dead records, else 0; 69465 registers renumbered.
69235 REM ====================================================================================
69400 IF V8 = 1 THEN 70390
69401 IF V8 = 2 THEN 70390
69402 IF V8 = 3 THEN 70390
69403 CALL "dg_bug": P$, "V8 must be 1 (input sea.lir1), 2 (sea.lir2, sea.lir3) or 3 (sea.lir) before entry 69400"
69410 IF Y0 <> 39 THEN 70740
69412 LET M8 = 0
69414 GOTO 72060
69416 LET Y0 = -1
69418 RETURN
69420 GOTO 72085
69430 GOTO 73285
69440 GOSUB 78965
69442 GOSUB 78680
69444 GOSUB 78770
69446 RETURN
69450 GOTO 77845
69455 GOTO 77945
69460 GOTO 79510
69465 GOTO 78680
70390 REM ---- the tables of the contract files, in the order of the DATA blocks -------------------
70395 CALL "tb_errors": P$, E(), E$(), 299, E0
70400 CALL "tb_exits": P$, E(), E$(), E0, D(), D$(), 39, N5
70405 CALL "tb_consts": P$, E(), E$(), E0, J(), J$(), 299, N6
70410 CALL "tb_entries": P$, E(), E$(), E0, Y(), Y$(), 399, N7
70415 LET Z(1) = 39
70420 LET Z(2) = 299
70425 LET Z(3) = 399
70430 LET Z(4) = 1499
70435 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), Q(), Q$(), F(), F$(), Z()
70440 REM ---- the limits (limits.inc), against the sizes of the DIMs above ------------------------
70445 LET Z$ = "FILE_VERSION"
70450 GOSUB 72310
70455 LET V9 = V
70460 LET Z$ = "LIM_LIR_INSTRS"
70465 GOSUB 72310
70470 LET I9 = V
70475 LET Z$ = "LIM_LIR_OPERANDS"
70480 GOSUB 72310
70485 LET O9 = V
70490 LET Z$ = "LIM_LIR_REGS"
70495 GOSUB 72310
70500 LET R9 = V
70505 LET Z$ = "LIM_LIR_BLOCKS"
70510 GOSUB 72310
70515 LET B9 = V
70520 LET Z$ = "LIM_LIR_SLOTS"
70525 GOSUB 72310
70530 LET S9 = V
70535 LET Z$ = "LIM_LIR_IMMS"
70540 GOSUB 72310
70545 LET M9 = V
70550 LET Z$ = "LIM_LIR_LABELS"
70555 GOSUB 72310
70560 LET Q9 = V
70565 LET Z$ = "LIM_LIR_SITES"
70570 GOSUB 72310
70575 LET S8 = V
70580 LET M$ = "a LIR limit is larger than the arrays of " & P$
70585 IF I9 > 199999 THEN 72205
70590 IF O9 > 799999 THEN 72205
70595 IF R9 > 99999 THEN 72205
70600 IF B9 > 9999 THEN 72205
70605 IF S9 > 9999 THEN 72205
70610 IF M9 > 199999 THEN 72205
70615 IF S8 > 60000 THEN 72205
70620 REM ---- the rows of set L and the special code of every record row ---------------------------
70625 LET K1$ = "|str=30|fmt=31|ftext=32|fconv=33|dat=34|dvi=35|dvf=36|func=37|slot=38|endfunc=39|loop=40|endloop=41|slay=20|soff=21|"
70630 LET K2$ = "|do=42|enddo=43|if=44|ifz=44|else=45|endif=46|exit=47|next=48|chk=50|rcall=51|mov=52|ret=53|call=54|"
70635 LET A8 = 0
70640 FOR I1 = 1 TO Z(7)
70645 LET B(I1) = 0
70650 IF Q(I1, 1) <> 5 THEN 70705
70655 LET A8 = A8 + 1
70660 LET A(A8) = I1
70665 LET K3$ = "|" & Q$(I1) & "="
70670 LET P1 = POS(K1$, K3$)
70675 IF P1 > 0 THEN 70700
70680 LET P1 = POS(K2$, K3$)
70685 IF P1 = 0 THEN 70705
70690 LET B(I1) = VAL(SEG$(K2$, P1 + LEN(K3$), P1 + LEN(K3$) + 1))
70695 GOTO 70705
70700 LET B(I1) = VAL(SEG$(K1$, P1 + LEN(K3$), P1 + LEN(K3$) + 1))
70705 NEXT I1
70707 GOSUB 76105
70710 REM ---- header: copied to sea.lir ----------------------------------------------------------
70715 CALL "io_hdr": 1, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), V9, T$, H$(), 100, N1, L$
70720 LET L0 = N1 + 3
70725 SCRATCH #2
70730 CALL "io_hdr_put": 2, V9, T$, H$(), N1
70732 LET Y0 = 0
70733 RETURN
70735 REM ---- one record per round: L$ is line L0 -------------------------------------------------
70740 LET D$ = "BAD_RECORD"
70745 CALL "io_plain": L$, O1
70750 LET M$ = "a byte outside 0x20-0x7E"
70755 IF O1 = 0 THEN 72180
70760 CALL "io_split": L$, G$(), 300, C0
70765 LET M$ = "empty record, a blank at its start or end, two blanks in a row, or more than 300 fields"
70770 IF C0 < 1 THEN 72180
70775 IF G$(1) = "#end" THEN 69416
70780 REM the record row: the opcode among the rows of set L
70785 LET I0 = 0
70790 FOR I1 = 1 TO A8
70795 IF Q$(A(I1)) <> G$(1) THEN 70810
70800 LET I0 = A(I1)
70805 GOTO 70825
70810 NEXT I1
70815 LET M$ = "unknown opcode '" & G$(1) & "' for format lir1"
70816 IF V8 = 3 THEN 75240
70820 GOTO 72180
70825 LET Y0 = B(I0)
70830 LET D7 = 0
70835 IF Y0 = 37 THEN 70880
70840 IF Y0 = 38 THEN 70970
70845 IF Y0 = 39 THEN 71055
70850 IF Y0 = 0 THEN 70995
70855 IF Y0 >= 40 THEN 70995
70860 REM a data record (str fmt dat and their sub-records): validated, copied as read, never stored
70865 LET D7 = 1
70870 GOTO 71055
70875 REM ---- func: starts a function, numbers restart from 1 ---------------------------------------
70880 LET M$ = "func inside a function, or after the data records"
70885 IF M8 <> 0 THEN 72180
70890 LET M8 = 1
70895 LET M7 = 0
70900 LET S6 = 0
70905 LET B1 = 0
70910 LET B2 = 0
70915 LET A0 = 0
70920 LET A1 = 0
70925 LET A2 = 0
70930 LET A5 = 0
70931 LET Y1$ = ""
70932 LET Y2$ = ""
70933 LET A6 = 0
70935 LET F7 = 0
70940 LET F8 = 0
70945 LET F9 = 0
70950 LET I(0, 1) = I0
70955 LET I(0, 2) = 1
70960 LET I(0, 4) = 0
70965 GOTO 71055
70970 LET M$ = "slot record not directly after func"
70975 IF M8 <> 1 THEN 72180
70980 LET D7 = 2
70985 GOTO 71055
70990 REM ---- an instruction (including the block records): only inside a function ----------------
70995 LET M$ = "instruction outside a function"
71000 IF M8 = 0 THEN 72180
71005 LET M$ = "instruction after the data records"
71010 IF M8 = 3 THEN 72180
71015 LET M8 = 2
71020 LET A0 = A0 + 1
71025 IF A0 > I9 THEN 72220
71030 LET I(A0, 1) = I0
71035 LET I(A0, 2) = A1 + 1
71040 LET I(A0, 3) = 0
71045 LET I(A0, 4) = 0
71050 REM ---- the fields: types, counts and the repeated fields -----------------------------------
71055 LET T0 = 1
71060 FOR J1 = 1 TO Q(I0, 4)
71065 LET B0 = Q(I0, 3) + J1 - 1
71070 LET U(J1) = 0
71075 LET X0 = 1
71080 IF F(B0, 3) = 0 THEN 71090
71085 LET X0 = U(F(B0, 3))
71090 FOR X1 = 1 TO X0
71095 LET T0 = T0 + 1
71100 LET M$ = "too few fields: " & F$(B0) & " is missing"
71105 IF T0 > C0 THEN 72180
71110 LET Z$ = G$(T0)
71115 LET T1 = F(B0, 1)
71120 LET O2 = F(B0, 2)
71125 GOSUB 72350
71127 GOSUB 73900
71130 IF D7 > 0 THEN 71140
71135 GOSUB 73050
71140 NEXT X1
71145 NEXT J1
71150 LET M$ = "too many fields"
71155 IF T0 < C0 THEN 72180
71160 REM ---- what the record means -----------------------------------------------------------------
71165 LET D$ = "BAD_RECORD"
71170 IF Y0 = 37 THEN 71205
71175 IF Y0 = 38 THEN 71220
71180 IF Y0 = 39 THEN 71290
71185 IF Y0 = 0 THEN 71335
71190 IF Y0 >= 40 THEN 71335
71195 GOTO 71860
71200 REM ---- func: all its fields are stored in row 0 ------------------------------------------------
71205 GOTO 74400
71210 GOTO 72060
71215 REM ---- slot id size align: recorded in K, rows 10000 + s -----------------------------------------
71220 LET S6 = S6 + 1
71225 IF S6 > S9 THEN 72260
71230 LET W1 = 1
71235 IF W1 >= U(3) THEN 71250
71240 LET W1 = W1 * 2
71245 GOTO 71235
71250 LET M$ = "slot alignment " & STR$(U(3)) & " is not a power of two"
71255 IF W1 <> U(3) THEN 72180
71260 LET K(10000 + S6, 1) = U(2)
71265 LET K(10000 + S6, 2) = U(3)
71270 LET K(10000 + S6, 3) = 0
71275 LET K(10000 + S6, 4) = 0
71280 GOTO 72060
71285 REM ---- endfunc: the function is complete, write it ------------------------------------------------
71290 LET M$ = "endfunc outside a function"
71295 IF M8 = 0 THEN 72180
71300 IF M8 = 3 THEN 72180
71305 LET M$ = "endfunc with open blocks"
71310 IF B1 > 0 THEN 72180
71312 REM the function is in the tables: back to the pass with Y0 = 39 (it transforms, then writes)
71313 RETURN
71330 REM ---- an instruction: operand count, then the checks of its kind ----------------------------------
71335 LET I(A0, 3) = A1 - I(A0, 2) + 1
71340 IF Y0 = 51 THEN 71680
71345 IF Y0 = 52 THEN 71655
71346 IF Y0 = 50 THEN 74500
71347 IF Y0 = 53 THEN 74520
71348 IF Y0 = 54 THEN 74560
71349 IF Q(I0, 1) = 6 THEN 75300
71350 IF Y0 < 40 THEN 72060
71355 IF Y0 > 48 THEN 72060
71360 LET V = U(1)
71365 REM loop, do, if, ifz open block V; blocks are numbered from 1 in order of opening
71370 IF Y0 = 40 THEN 71475
71375 IF Y0 = 42 THEN 71475
71380 IF Y0 = 44 THEN 71475
71385 IF Y0 = 45 THEN 71575
71390 IF Y0 = 47 THEN 71615
71395 IF Y0 = 48 THEN 71615
71400 REM endloop, enddo, endif: close the innermost block, which must be of that kind and number
71405 LET M$ = "end of block " & STR$(V) & " does not match the innermost open block"
71410 IF B1 = 0 THEN 72180
71415 IF T(B1) <> V THEN 72180
71420 LET W1 = K(V, 1)
71425 IF Y0 = 41 THEN 71445
71430 IF Y0 = 43 THEN 71455
71435 IF W1 < 3 THEN 72180
71440 GOTO 71460
71445 IF W1 <> 1 THEN 72180
71450 GOTO 71460
71455 IF W1 <> 2 THEN 72180
71460 LET K(V, 4) = A0
71465 LET B1 = B1 - 1
71470 GOTO 72060
71475 LET M$ = "block " & STR$(V) & " opened where " & STR$(B2 + 1) & " was expected (blocks count from 1)"
71480 IF V <> B2 + 1 THEN 72180
71485 LET B2 = V
71490 IF B2 > B9 THEN 72250
71495 LET B1 = B1 + 1
71500 LET T(B1) = V
71505 LET K(V, 1) = 3
71510 IF Y0 = 40 THEN 71535
71515 IF Y0 = 42 THEN 71545
71520 IF Q$(I0) <> "ifz" THEN 71550
71525 LET K(V, 1) = 4
71530 GOTO 71550
71535 LET K(V, 1) = 1
71540 GOTO 71550
71545 LET K(V, 1) = 2
71550 LET K(V, 2) = A0
71555 LET K(V, 3) = 0
71560 LET K(V, 4) = 0
71565 GOTO 72060
71570 REM else: the innermost open block is an if or ifz without else
71575 LET M$ = "else without an open if of the same number"
71580 IF B1 = 0 THEN 72180
71585 IF T(B1) <> V THEN 72180
71590 IF K(V, 1) < 3 THEN 72180
71595 IF K(V, 3) <> 0 THEN 72180
71600 LET K(V, 3) = A0
71605 GOTO 72060
71610 REM exit, next: V names an enclosing loop or do (kind 1 or 2)
71615 LET M$ = "exit / next names block " & STR$(V) & ", which is not an open loop or do"
71620 FOR W1 = B1 TO 1 STEP -1
71625 IF T(W1) <> V THEN 71640
71630 IF K(V, 1) > 2 THEN 72180
71635 GOTO 72060
71640 NEXT W1
71645 GOTO 72180
71650 REM mov d a: the same class (3.6.4)
71655 LET P1 = I(A0, 2)
71660 LET M$ = "mov of registers of different classes"
71665 IF R(O(P1), 1) <> R(O(P1 + 1), 1) THEN 72180
71667 IF R(O(P1), 1) = 6 THEN 75285
71670 GOTO 72060
71675 REM rcall entry site nr d.. na a..: an entry of rt.inc, its site, result and argument classes
71680 LET P1 = I(A0, 2)
71685 LET Z$ = S$(O(P1))
71690 LET W0 = 0
71695 FOR W1 = 1 TO N7
71700 IF Y$(W1, 2) <> Z$ THEN 71715
71705 LET W0 = W1
71710 GOTO 71730
71715 NEXT W1
71720 LET M$ = "rcall names '" & Z$ & "', which rt.inc does not list as an entry point"
71725 GOTO 72180
71730 LET M$ = "rcall " & Z$ & ": the site must be present exactly for an entry that can fail"
71735 IF Y$(W0, 3) = "S" THEN 71750
71740 IF I(A0, 4) <> 0 THEN 72180
71745 GOTO 71755
71750 IF I(A0, 4) = 0 THEN 72180
71755 LET R1$ = Y$(W0, 5)
71760 LET P2 = P1 + 1
71765 LET M$ = "rcall " & Z$ & ": results do not match the entry (" & R1$ & ")"
71770 GOSUB 71805
71775 LET R1$ = Y$(W0, 4)
71780 LET M$ = "rcall " & Z$ & ": arguments do not match the entry (" & R1$ & ")"
71785 GOSUB 71805
71790 GOTO 72060
71795 REM rcl: O(P2) is a count, then that many registers; R1$ lists their classes ("-": none);
71800 REM P2 ends on the next field. Fails with M$.
71805 LET W2 = LEN(R1$)
71810 IF R1$ = "-" THEN 71820
71815 GOTO 71825
71820 LET W2 = 0
71825 IF O(P2) <> W2 THEN 72180
71830 FOR W3 = 1 TO W2
71835 IF POS("ifpxym", SEG$(R1$, W3, W3)) <> R(O(P2 + W3), 1) THEN 72180
71840 NEXT W3
71845 LET P2 = P2 + W2 + 1
71850 RETURN
71855 REM ---- data records: str fmt dat and their sub-records ftext fconv dvi dvf ----------------------------
71860 IF X9 = 0 THEN 71935
71861 IF Z8 <> 3 THEN 71865
71862 IF X9 > 0 THEN 75200
71865 LET M$ = "ftext / fconv records expected after fmt"
71870 IF Z8 > 0 THEN 71890
71875 IF Y0 = 32 THEN 71925
71880 IF Y0 = 33 THEN 71925
71885 GOTO 72180
71890 LET M$ = "dvi records expected after dat of i64 or bool"
71895 IF Z8 > 1 THEN 71910
71900 IF Y0 = 35 THEN 71925
71905 GOTO 72180
71910 LET M$ = "dvf records expected after dat of f64"
71915 IF Y0 = 36 THEN 71925
71920 GOTO 72180
71925 LET X9 = X9 - 1
71930 GOTO 72060
71935 LET M$ = "ftext, fconv, dvi or dvf record outside its fmt or dat"
71940 IF Y0 = 30 THEN 71965
71945 IF Y0 = 31 THEN 71965
71950 IF Y0 = 34 THEN 71965
71952 IF Y0 = 20 THEN 71965
71955 GOTO 72180
71960 REM str, fmt, dat: after the last function; labels d1, d2, ... in order
71965 LET M$ = "data record inside a function"
71970 IF M8 = 1 THEN 72180
71975 IF M8 = 2 THEN 72180
71980 LET M8 = 3
71985 LET V = U(1)
71990 LET M$ = "data label d" & STR$(V) & " where d" & STR$(D8 + 1) & " was expected"
71995 IF V <> D8 + 1 THEN 72180
72000 LET D8 = V
72005 IF D8 <= Q9 THEN 72010
72006 IF V8 = 1 THEN 72280
72007 LET M$ = "data label d" & STR$(D8) & " is above the label limit " & STR$(Q9)
72008 GOTO 72180
72010 IF Y0 = 30 THEN 72060
72015 IF Y0 = 31 THEN 72045
72016 IF Y0 = 20 THEN 75220
72020 LET X9 = U(3)
72025 LET Z8 = 2
72030 IF E1$ = "f64" THEN 72060
72035 LET Z8 = 1
72040 GOTO 72060
72045 LET X9 = U(2)
72050 LET Z8 = 0
72055 REM ---- next record: a data record is copied as read -------------------------------------------------
72060 IF D7 <> 1 THEN 72070
72065 CALL "io_put": 2, L$
72070 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
72075 GOTO 70740
72080 REM ---- #end: nothing may be open, nothing may follow ------------------------------------------------
72085 LET M$ = "#end carries fields"
72090 IF C0 <> 1 THEN 72180
72095 LET D$ = "BAD_RECORD"
72100 LET M$ = "a function is not closed by endfunc"
72105 IF M8 = 1 THEN 72180
72110 IF M8 = 2 THEN 72180
72115 LET M$ = "sub-records of the last fmt or dat are missing"
72120 IF X9 > 0 THEN 72180
72125 LET M$ = "data label d" & STR$(R8) & " is used but only " & STR$(D8) & " are defined"
72130 IF R8 > D8 THEN 72180
72135 REM lir1 numbers data labels by first reference, so none is without a user (3.6.2)
72140 LET M$ = "data label d" & STR$(D8) & " is defined but no instruction uses it (lir1 numbers labels by first use; " & STR$(R8) & " are used)"
72143 IF V8 <> 1 THEN 72146
72145 IF R8 < D8 THEN 72180
72146 LET M$ = "the file has " & STR$(M6) & " funcs of kind main, not one"
72147 IF M6 <> 1 THEN 72180
72148 GOSUB 74970
72160 CALL "io_end": 1, P$, E(), E$(), E0
72165 CALL "io_fin": 2
72170 RETURN
72175 REM ---- failure: say where, then the internal error of errors.inc (status 11) ----------------------------
72180 CALL "dg_internal": P$, D$, E(), E$(), E0
72195 STOP 11
72200 REM ---- a pass bug, not a bad input -------------------------------------------------------------------------
72205 CALL "dg_bug": P$, M$
72210 STOP 11
72215 REM ---- capacity limits: "program too large: <word>" at the position of the func record ----------------------
72220 LET A$(1) = "instructions"
72225 GOTO 72295
72230 LET A$(1) = "operands"
72235 GOTO 72295
72240 LET A$(1) = "registers"
72245 GOTO 72295
72250 LET A$(1) = "blocks"
72255 GOTO 72295
72260 LET A$(1) = "slots"
72265 GOTO 72295
72270 LET A$(1) = "immediates"
72275 GOTO 72295
72280 LET A$(1) = "labels"
72285 GOTO 72295
72290 LET A$(1) = "sites"
72295 CALL "dg_compile": P$, H$(), N1, F7, F8, F9, "TOO_LARGE", A$(), 1, E(), E$(), E0
72300 STOP 10
72305 REM ---- subroutine: V = the constant named Z$ of limits.inc ----------------------------------------------
72310 CALL "tb_cval": J(), J$(), N6, Z$, V, T
72315 IF T = 0 THEN 72330
72320 LET M$ = "constant " & Z$ & " is not in the consts table"
72325 GOTO 72205
72330 RETURN
72335 REM ---- subroutine chk: validate the field Z$ of type T1 (optional if O2 = 1) -----------------------------------
72340 REM Result: V (u, lab, slot, blk, reg: the number; an enumeration: the position of its word),
72345 REM L(1..4) (i, f), F1 L1 C1 (pos, site), A9 = 1 for an absent field (V = -1 for u, else 0).
72350 LET B$ = "field " & F$(B0) & " ('" & Z$ & "')"
72355 LET M$ = B$
72360 LET A9 = 0
72365 IF O2 = 0 THEN 72400
72370 IF Z$ <> "-" THEN 72400
72375 LET A9 = 1
72380 LET V = 0
72385 IF T1 <> 1 THEN 72395
72390 LET V = -1
72395 RETURN
72400 IF T1 >= 100 THEN 72975
72405 ON T1 GOTO 72415, 72440, 72455, 72475, 72530, 72540, 72590, 72640, 72640, 72640, 72640, 72640, 72655, 72685, 72755, 72825, 72825, 72825, 72825, 72825, 72825, 72825
72410 REM u: unsigned decimal
72415 CALL "io_u": Z$, V, T
72420 IF T <> 0 THEN 73015
72425 LET U(J1) = V
72430 RETURN
72435 REM i: decimal, or hex for |v| >= 1E9; f: # and 16 hex digits; both leave the limbs in L
72440 CALL "io_i": Z$, V, K1, L(), T
72445 IF T <> 0 THEN 73015
72450 RETURN
72455 CALL "io_f": Z$, L(), T
72460 IF T <> 0 THEN 73015
72465 RETURN
72470 REM s: escaped string; a chk record names an error of errors.inc with phase R
72475 CALL "io_unesc": Z$, 0, R1$, T
72480 IF T <> 0 THEN 73015
72485 IF Y0 <> 50 THEN 72395
72490 IF F$(B0) <> "err" THEN 72395
72495 CALL "dg_find": R1$, E$(), E0, W1
72500 LET M$ = B$ & " is not a name of the error table"
72505 IF W1 = 0 THEN 72180
72510 LET M$ = B$ & " (a chk names a run-time error)"
72515 IF E$(W1, 2) <> "R" THEN 72180
72516 GOSUB 74700
72520 RETURN
72525 REM pos F:L:C and site F:L: the file index must name a #file record; the func record sets F7 F8 F9
72530 CALL "io_pos": Z$, F1, L1, C1, T
72535 GOTO 72545
72540 CALL "io_site": Z$, F1, L1, T
72545 IF T <> 0 THEN 73015
72550 LET M$ = B$ & " names file " & STR$(F1) & " but the header has " & STR$(N1) & " #file records"
72555 IF F1 >= N1 THEN 72180
72560 IF Y0 <> 37 THEN 72395
72565 LET F7 = F1
72570 LET F8 = L1
72575 LET F9 = C1
72580 RETURN
72585 REM fl: - or the letters l p s z a, each at most once, in this order (data fconv records)
72590 IF Z$ = "-" THEN 72395
72595 LET P1 = 0
72600 FOR W1 = 1 TO LEN(Z$)
72605 LET X2 = POS("lpsza", SEG$(Z$, W1, W1))
72610 IF X2 = 0 THEN 73015
72615 IF X2 <= P1 THEN 73015
72620 LET P1 = X2
72625 NEXT W1
72630 RETURN
72635 REM a field type that has no place in a LIR record (ty lid fid cid iid): passes.txt and this pass disagree
72640 LET M$ = "passes.txt gives record " & Q$(I0) & " a field type " & P$ & " does not know"
72645 GOTO 72205
72650 REM blk: a block number from 1 (nesting is checked per record)
72655 CALL "io_u": Z$, V, T
72660 IF T <> 0 THEN 73015
72665 IF V < 1 THEN 73015
72670 LET U(J1) = V
72675 RETURN
72680 REM lab: d and a number; instructions use labels in order of first reference (lir1)
72685 IF LEN(Z$) < 2 THEN 73015
72690 IF SEG$(Z$, 1, 1) <> "d" THEN 73015
72695 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), V, T
72700 IF T <> 0 THEN 73015
72705 IF V < 1 THEN 73015
72710 LET U(J1) = V
72715 IF D7 = 1 THEN 72395
72720 LET M$ = B$ & " is used before d" & STR$(R8 + 1) & " (lir1 numbers labels by first use)"
72722 IF V8 <> 1 THEN 72730
72725 IF V > R8 + 1 THEN 72180
72730 IF V <= R8 THEN 72395
72735 LET R8 = V
72740 IF R8 <= Q9 THEN 72745
72741 IF V8 = 1 THEN 72280
72742 LET M$ = B$ & " is above the label limit " & STR$(Q9)
72743 GOTO 72180
72745 RETURN
72750 REM slot: s and a number; defined in order by slot records, used by instructions
72755 IF LEN(Z$) < 2 THEN 73015
72760 IF SEG$(Z$, 1, 1) <> "s" THEN 73015
72765 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), V, T
72770 IF T <> 0 THEN 73015
72775 IF V < 1 THEN 73015
72780 LET U(J1) = V
72785 IF Y0 = 38 THEN 72805
72790 LET M$ = B$ & " names a slot that func has not declared (" & STR$(S6) & " so far)"
72795 IF V > S6 THEN 72180
72800 RETURN
72805 LET M$ = B$ & " where s" & STR$(S6 + 1) & " was expected (slots count from 1)"
72810 IF V <> S6 + 1 THEN 72180
72815 RETURN
72820 REM reg, ri rf rp rx ry rm: a class letter and a number; numbers in order of first appearance
72825 IF LEN(Z$) < 2 THEN 73015
72830 LET X2 = POS("ifpxym", SEG$(Z$, 1, 1))
72835 IF X2 = 0 THEN 73015
72840 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), V, T
72845 IF T <> 0 THEN 73015
72850 IF V < 1 THEN 73015
72855 IF T1 = 16 THEN 72875
72860 IF X2 = T1 - 16 THEN 72875
72865 LET M$ = B$ & " has the wrong register class here"
72870 GOTO 72180
72875 LET M$ = B$ & " has a vector or mask class, which sea.lir1 does not use"
72880 IF X2 <= 3 THEN 72885
72882 IF V8 < 3 THEN 72180
72885 IF V <= M7 THEN 72955
72890 LET M$ = B$ & " is not the next register (" & STR$(M7 + 1) & " is: numbers follow first appearance)"
72895 IF V <> M7 + 1 THEN 72180
72900 IF V > R9 THEN 72240
72905 REM a new register: class from its letter, the phase-5 columns zero
72910 LET M7 = V
72915 LET R(V, 1) = X2
72920 LET R(V, 2) = 0
72925 LET R(V, 3) = 0
72930 LET R(V, 4) = 0
72935 LET R(V, 5) = 0
72940 LET R(V, 6) = 0
72945 LET R(V, 7) = 0
72950 RETURN
72955 LET M$ = B$ & " was used before with another class"
72960 IF R(V, 1) <> X2 THEN 72180
72965 RETURN
72970 REM an enumeration: a word listed in passes.txt (an elt field is remembered for dat)
72975 LET X2 = T1 - 100
72980 CALL "tb_word": N(), W$(), X2, Z$, W1
72985 IF W1 = 0 THEN 73015
72990 LET V = W1
72995 IF F$(B0) <> "elt" THEN 72395
73000 LET E1$ = Z$
73005 RETURN
73010 REM the field is not valid for its type
73015 IF T1 >= 100 THEN 73030
73020 LET M$ = B$ & " is not a valid " & SEG$("u    i    f    s    pos  site fl   ty   lid  fid  cid  iid  blk  lab  slot reg  ri   rf   rp   rx   ry   rm   ", 5 * T1 - 4, 5 * T1)
73025 GOTO 72180
73030 LET M$ = B$ & " is not a word of enumeration " & N$(T1 - 100)
73035 GOTO 72180
73040 REM ---- subroutine sto: store the validated field into the tables ------------------------------------------------
73045 REM site: into I(A0,4); pos: two operands; s: a row of S$; i and f: a row of C; the rest: V itself.
73050 LET V1 = V
73055 IF T1 = 6 THEN 73100
73060 IF T1 = 5 THEN 73130
73065 IF T1 = 4 THEN 73160
73070 IF T1 = 2 THEN 73176
73075 IF T1 = 3 THEN 73180
73080 IF Y0 = 37 THEN 73093
73081 LET A1 = A1 + 1
73085 IF A1 > O9 THEN 72230
73090 LET O(A1) = V1
73091 RETURN
73093 LET A5 = A5 + 1
73094 LET M(A5) = V1
73095 RETURN
73100 IF A9 = 1 THEN 73120
73105 LET I(A0, 4) = F1 * 1E9 + L1
73110 LET K5 = I(A0, 4)
73115 GOTO 73220
73120 LET I(A0, 4) = 0
73125 RETURN
73130 LET V1 = F1 * 1E9 + L1
73135 GOSUB 73080
73140 LET V1 = C1
73145 GOSUB 73080
73150 LET K5 = F1 * 1E9 + L1
73155 GOTO 73220
73160 GOSUB 75000
73165 LET V1 = Q2
73170 GOTO 73080
73176 IF F$(B0) <> "off" THEN 73180
73177 GOSUB 75100
73178 GOTO 73080
73180 LET A2 = A2 + 1
73185 IF A2 > M9 THEN 72270
73190 FOR W1 = 1 TO 4
73195 LET C(A2, W1) = L(W1)
73200 NEXT W1
73205 LET V1 = A2
73210 GOTO 73080
73215 REM site K5 (F*1E9+L) into the hash set of the compilation; more than the limit is an error
73220 LET K4 = K5 - INT(K5 / 131071) * 131071
73225 IF X(K4) = 0 THEN 73255
73230 IF X(K4) = K5 THEN 73270
73235 LET K4 = K4 + 1
73240 IF K4 <= 131071 THEN 73225
73245 LET K4 = 0
73250 GOTO 73225
73255 LET X(K4) = K5
73260 LET A4 = A4 + 1
73265 IF A4 > S8 THEN 72290
73270 RETURN
73275 REM ---- subroutine wfunc: write the function held in the tables ------------------------------------------------------
73280 REM row 0 is the func record, then the slots, then the instructions 1..A0, then endfunc
73285 LET N9 = 0
73290 GOSUB 73340
73295 FOR W5 = 1 TO S6
73300 CALL "io_put": 2, "slot s" & STR$(W5) & " " & STR$(K(10000 + W5, 1)) & " " & STR$(K(10000 + W5, 2))
73305 NEXT W5
73310 FOR N9 = 1 TO A0
73315 GOSUB 73340
73320 NEXT N9
73325 CALL "io_put": 2, "endfunc"
73330 RETURN
73335 REM wrec: write record N9 (a row of I): the opcode, then every field by its type in passes.txt
73340 LET W0 = I(N9, 1)
73345 LET B$ = Q$(W0)
73350 LET P1 = I(N9, 2)
73355 FOR W1 = 1 TO Q(W0, 4)
73360 LET W2 = Q(W0, 3) + W1 - 1
73365 LET U(W1) = 0
73370 LET W3 = 1
73375 IF F(W2, 3) = 0 THEN 73385
73380 LET W3 = U(F(W2, 3))
73385 FOR W4 = 1 TO W3
73390 GOSUB 73425
73395 LET B$ = B$ & " " & S1$
73400 NEXT W4
73405 NEXT W1
73410 CALL "io_put": 2, B$
73415 RETURN
73420 REM wtok: S1$ = the next field, T1 its type; P1 advances over its operands
73425 LET T1 = F(W2, 1)
73427 GOSUB 73815
73430 IF T1 >= 100 THEN 73565
73435 ON T1 GOTO 73440, 73702, 73665, 73550, 73585, 73610, 73805, 73805, 73805, 73805, 73805, 73805, 73475, 73490, 73505, 73520, 73520, 73520, 73520, 73520, 73520, 73520
73440 LET V = Q0
73445 LET P1 = P1 + 1
73450 LET U(W1) = V
73455 LET S1$ = "-"
73460 IF V < 0 THEN 73545
73465 LET S1$ = STR$(V)
73470 RETURN
73475 LET S1$ = STR$(O(P1))
73476 LET S1$ = STR$(Q0)
73480 LET P1 = P1 + 1
73485 RETURN
73490 LET S1$ = "d" & STR$(Q0)
73495 LET P1 = P1 + 1
73500 RETURN
73505 LET S1$ = "s" & STR$(Q0)
73510 LET P1 = P1 + 1
73515 RETURN
73520 LET V = Q0
73525 LET P1 = P1 + 1
73530 LET S1$ = "-"
73535 IF V = 0 THEN 73545
73540 LET S1$ = SEG$("ifpxym", R(V, 1), R(V, 1)) & STR$(V)
73545 RETURN
73550 LET S1$ = S$(Q0)
73555 LET P1 = P1 + 1
73560 RETURN
73565 LET S1$ = W$(N(T1 - 100, 1) + Q0 - 1)
73570 LET P1 = P1 + 1
73575 RETURN
73580 REM pos F:L:C and site F:L (F*1E9+L, 0: absent)
73585 LET W6 = Q0
73590 LET W7 = Q1
73595 LET P1 = P1 + 2
73600 LET S1$ = ""
73605 GOTO 73635
73610 LET W6 = I(N9, 4)
73615 LET W7 = 0
73620 LET S1$ = "-"
73625 IF W6 = 0 THEN 73545
73630 LET S1$ = ""
73635 LET W8 = INT(W6 / 1E9)
73640 LET S1$ = STR$(W8) & ":" & STR$(W6 - W8 * 1E9)
73645 IF W7 = 0 THEN 73545
73650 LET S1$ = S1$ & ":" & STR$(W7)
73655 RETURN
73660 REM f: always # and 16 hex digits of the limbs
73665 LET W6 = Q0
73670 LET P1 = P1 + 1
73675 FOR W8 = 1 TO 4
73680 LET L(W8) = C(W6, W8)
73685 NEXT W8
73690 CALL "io_hex": L(), S1$
73695 RETURN
73700 REM i: decimal if |v| <= 999999999, else the hex form of the limbs (3.1)
73702 IF F$(W2) = "off" THEN 73850
73705 LET W6 = Q0
73710 LET P1 = P1 + 1
73715 FOR W8 = 1 TO 4
73720 LET L(W8) = C(W6, W8)
73725 NEXT W8
73730 LET W7 = L(3) * 65536 + L(4)
73735 IF L(1) = 0 THEN 73770
73740 IF L(1) <> 65535 THEN 73790
73745 IF L(2) <> 65535 THEN 73790
73750 LET W7 = 65536 * 65536 - W7
73755 IF W7 > 999999999 THEN 73790
73760 LET S1$ = "-" & STR$(W7)
73765 RETURN
73770 IF L(2) <> 0 THEN 73790
73775 IF W7 > 999999999 THEN 73790
73780 LET S1$ = STR$(W7)
73785 RETURN
73790 CALL "io_hex": L(), S1$
73795 RETURN
73800 REM a field type that LIR records do not have
73805 LET M$ = "passes.txt gives record " & Q$(W0) & " a field type " & P$ & " does not know"
73810 GOTO 72205
73812 REM ---- 3815: Q0 Q1 = the operand value at P1 and the next one (record N9; row 0, the func record, is in M) ----
73815 IF N9 = 0 THEN 73835
73820 LET Q0 = O(P1)
73825 LET Q1 = 0
73830 RETURN
73835 LET Q0 = M(P1)
73840 LET Q1 = M(P1 + 1)
73845 RETURN
73848 REM ---- 3850: an off field (row Q0 of G): its limbs, then written as an i field (3730) ----
73850 LET W6 = Q0
73852 LET P1 = P1 + 1
73854 FOR W8 = 1 TO 4
73856 LET L(W8) = G(W6, W8 - 1)
73858 NEXT W8
73860 GOTO 73730
73897 REM ---- 3900: the checks of one validated field beyond its type (DESIGN 3.6.5), called after 2350 ----
73900 IF A9 = 1 THEN 73995
73905 IF Y0 <> 37 THEN 73940
73910 IF F$(B0) <> "par" THEN 73925
73915 LET M$ = B$ & " is parameter " & STR$(X1) & ", so it must be register " & STR$(X1)
73918 IF V <> X1 THEN 72180
73919 IF X2 > 3 THEN 75260
73920 LET Y2$ = Y2$ & SEG$("ifp", X2, X2)
73922 GOTO 73995
73925 IF F$(B0) <> "cls" THEN 73995
73930 LET Y1$ = Y1$ & Z$
73935 GOTO 73995
73940 IF Y0 <> 33 THEN 73965
73945 IF F$(B0) <> "conv" THEN 73950
73947 LET G1$ = Z$
73950 IF F$(B0) <> "cls" THEN 73995
73952 LET M$ = "fconv " & G1$ & " with class " & Z$ & " (class p exactly for conversion s)"
73954 IF G1$ = "s" THEN 73960
73956 IF Z$ = "p" THEN 72180
73958 GOTO 73995
73960 IF Z$ <> "p" THEN 72180
73962 GOTO 73995
73965 IF T1 <> 1 THEN 73975
73967 IF F$(B0) = "incl" THEN 73971
73968 IF F$(B0) <> "dim" THEN 73995
73971 LET M$ = B$ & " must be 0 or 1"
73972 IF V > 1 THEN 72180
73973 GOTO 73995
73975 IF T1 < 16 THEN 73995
73977 IF T1 > 22 THEN 73995
73979 IF F$(B0) = "d" THEN 73985
73981 IF F$(B0) = "e" THEN 73985
73983 IF F$(B0) <> "ind" THEN 73995
73985 LET M$ = B$ & " is written inside a loop whose induction register it is"
73987 FOR Q1 = 1 TO B1
73989 IF K(T(Q1), 1) <> 1 THEN 73993
73991 IF O(I(K(T(Q1), 2), 2) + 1) = V THEN 72180
73993 NEXT Q1
73995 RETURN
74395 REM ---- 4400: func: .main, a unique name, the signature its calls must match (DESIGN 3.6.5) ----
74400 LET I(0, 3) = A5
74405 LET Q2 = M(1)
74410 LET M$ = "func " & S$(Q2) & ": kind main exactly for the name .main, which has no results"
74415 IF M(2) = 1 THEN 74440
74420 IF LEN(S$(Q2)) <> 5 THEN 74455
74425 IF S$(Q2) = ".main" THEN 72180
74430 GOTO 74455
74440 IF LEN(S$(Q2)) <> 5 THEN 72180
74442 IF S$(Q2) <> ".main" THEN 72180
74444 IF LEN(Y1$) > 0 THEN 72180
74446 LET M6 = M6 + 1
74448 LET M$ = "a second func of kind main"
74450 IF M6 > 1 THEN 72180
74455 LET M$ = "func " & S$(Q2) & " is defined twice"
74460 IF H(Q2) <> 0 THEN 72180
74465 LET F6 = F6 + 1
74470 LET M$ = "more than 49999 functions"
74475 IF F6 > 49999 THEN 72180
74480 LET H(Q2) = F6
74485 LET V$(F6) = Y1$ & "/" & Y2$
74490 GOTO 72060
74495 REM ---- 4500: chk: n = the argument slots of its error (C3, from 4700) ----
74500 LET M$ = "chk names an error whose arguments take " & STR$(C3) & " slots, but n = " & STR$(U(4))
74505 IF U(4) <> C3 THEN 72180
74506 FOR Q3 = 1 TO U(4)
74507 IF R(O(I(A0, 2) + 2 + Q3), 1) > 3 THEN 75270
74508 NEXT Q3
74510 GOTO 72060
74515 REM ---- 4520: ret: the results of the func, in number and class ----
74520 LET P1 = I(A0, 2)
74525 LET M$ = "ret does not return the results of its func (" & Y1$ & ")"
74530 IF O(P1) <> LEN(Y1$) THEN 72180
74535 FOR Q3 = 1 TO O(P1)
74540 IF R(O(P1 + Q3), 1) <> POS("ifp", SEG$(Y1$, Q3, Q3)) THEN 72180
74545 NEXT Q3
74550 GOTO 72060
74555 REM ---- 4560: call: its signature R2$ = result classes "/" argument classes, against the func (4800) or deferred ----
74560 LET P1 = I(A0, 2)
74565 LET Q2 = O(P1)
74570 LET R2$ = ""
74575 LET P2 = P1 + 1
74580 FOR Q3 = 1 TO O(P2)
74584 IF R(O(P2 + Q3), 1) > 3 THEN 75265
74585 LET R2$ = R2$ & SEG$("ifp", R(O(P2 + Q3), 1), R(O(P2 + Q3), 1))
74590 NEXT Q3
74595 LET R2$ = R2$ & "/"
74600 LET P2 = P2 + O(P2) + 1
74605 FOR Q3 = 1 TO O(P2)
74609 IF R(O(P2 + Q3), 1) > 3 THEN 75265
74610 LET R2$ = R2$ & SEG$("ifp", R(O(P2 + Q3), 1), R(O(P2 + Q3), 1))
74615 NEXT Q3
74620 IF H(Q2) = 0 THEN 74640
74625 GOSUB 74800
74630 LET M$ = "call " & S$(Q2) & " (" & R2$ & ") does not match its func (" & V$(H(Q2)) & ")"
74632 IF Q5 = 0 THEN 72180
74635 GOTO 72060
74640 LET Z$ = STR$(Q2) & ":" & R2$
74642 GOSUB 74930
74645 GOTO 72060
74695 REM ---- 4700: C3 = the argument slots of error row W1: one per args letter, two for h (DESIGN 2.6.2) ----
74700 LET C3 = 0
74705 LET R2$ = E$(W1, 4)
74710 IF R2$ = "-" THEN 74740
74715 FOR Q3 = 1 TO LEN(R2$)
74720 LET C3 = C3 + 1
74725 IF SEG$(R2$, Q3, Q3) <> "h" THEN 74735
74730 LET C3 = C3 + 1
74735 NEXT Q3
74740 RETURN
74795 REM ---- 4800: Q5 = 1 if the call signature R2$ matches func H(Q2): all its results, or none ----
74800 LET Q5 = 0
74805 LET R3$ = V$(H(Q2))
74810 IF LEN(R2$) <> LEN(R3$) THEN 74825
74815 IF R2$ = R3$ THEN 74840
74825 LET R3$ = SEG$(R3$, POS(R3$, "/"), LEN(R3$))
74830 IF LEN(R2$) <> LEN(R3$) THEN 74845
74835 IF R2$ <> R3$ THEN 74845
74840 LET Q5 = 1
74845 RETURN
74895 REM ---- 4900: H1 = a hash of Z$ modulo H2 ----
74900 LET H1 = 0
74905 FOR Q4 = 1 TO LEN(Z$)
74910 LET H1 = H1 * 31 + ASC(SEG$(Z$, Q4, Q4))
74915 LET H1 = H1 - INT(H1 / H2) * H2
74920 NEXT Q4
74925 RETURN
74928 REM ---- 4930: Z$ joins the set U$ of forward calls ----
74930 LET H2 = 131071
74932 GOSUB 74900
74934 IF LEN(U$(H1)) = 0 THEN 74950
74936 IF LEN(U$(H1)) <> LEN(Z$) THEN 74940
74938 IF U$(H1) = Z$ THEN 74960
74940 LET H1 = H1 + 1
74942 IF H1 < 131071 THEN 74934
74944 LET H1 = 0
74946 GOTO 74934
74950 LET Q6 = Q6 + 1
74952 LET M$ = "more distinct forward calls than " & P$ & " holds"
74954 IF Q6 > 131000 THEN 72180
74956 LET U$(H1) = Z$
74960 RETURN
74965 REM ---- 4970: at #end every forward call names a func of the file and matches it (4800) ----
74970 FOR Q3 = 0 TO 131070
74972 IF LEN(U$(Q3)) = 0 THEN 74990
74974 LET Q4 = POS(U$(Q3), ":")
74976 LET Q2 = VAL(SEG$(U$(Q3), 1, Q4 - 1))
74978 LET R2$ = SEG$(U$(Q3), Q4 + 1, LEN(U$(Q3)))
74980 LET M$ = "call of " & S$(Q2) & ", which no func defines"
74982 IF H(Q2) = 0 THEN 72180
74984 GOSUB 74800
74986 LET M$ = "call " & S$(Q2) & " does not match its func"
74988 IF Q5 = 0 THEN 72180
74990 NEXT Q3
74992 RETURN
74995 REM ---- 5000: Q2 = the row of S$ that holds Z$ (interned, DESIGN 2.7; a new row if absent) ----
75000 LET H2 = 262139
75005 GOSUB 74900
75010 IF P(H1) = 0 THEN 75040
75015 LET Q2 = P(H1)
75020 IF LEN(S$(Q2)) <> LEN(Z$) THEN 75030
75025 IF S$(Q2) = Z$ THEN 75060
75030 LET H1 = H1 + 1
75032 IF H1 < 262139 THEN 75010
75034 LET H1 = 0
75036 GOTO 75010
75040 LET A3 = A3 + 1
75045 LET M$ = "more than 199999 distinct strings"
75050 IF A3 > 199999 THEN 72180
75052 LET S$(A3) = Z$
75054 LET P(H1) = A3
75056 LET Q2 = A3
75060 RETURN
75095 REM ---- 5100: an off field (io_i left its limbs in L): a new row of G, any i64 (DESIGN 3.6.4) ----
75100 LET A6 = A6 + 1
75105 LET M$ = "more off fields in a function than instructions"
75110 IF A6 > 199999 THEN 72180
75115 FOR Q3 = 1 TO 4
75120 LET G(A6, Q3 - 1) = L(Q3)
75125 NEXT Q3
75130 LET V1 = A6
75160 RETURN
75195 REM ---- 5200: soff inside a slay group: a multiple of 8, above the previous one, at most size - 8 ----
75200 LET M$ = "a record other than soff inside a slay group"
75202 IF Y0 <> 21 THEN 72180
75204 LET V = U(1)
75206 LET M$ = "soff " & STR$(V) & " is not a multiple of 8, not above the previous soff, or above the slay size - 8"
75208 IF V <> 8 * INT(V / 8) THEN 72180
75210 IF V <= Z7 THEN 72180
75212 IF V > Z6 - 8 THEN 72180
75214 LET Z7 = V
75216 GOTO 71925
75217 REM ---- 5220: slay lab size n: n soff records follow ----
75220 LET X9 = U(3)
75222 LET Z8 = 3
75224 LET Z6 = U(2)
75226 LET Z7 = -1
75228 GOTO 72060
75235 REM ---- 5240: V8 = 3 (sea.lir): the opcode among the rows of set LF (2.12.6, Decision 113) ----
75240 FOR I1 = 1 TO Z(7)
75242 IF Q(I1, 1) <> 6 THEN 75248
75244 IF Q$(I1) <> G$(1) THEN 75248
75246 LET I0 = I1
75247 GOTO 70825
75248 NEXT I1
75250 GOTO 72180
75255 REM ---- 5260: Sea functions pass and return the classes i f p only (3.6.3), so no vector or mask ----
75257 REM register is a parameter (3919), a call's argument or result (4584, 4609) or a chk argument (4507)
75260 LET M$ = B$ & " is a parameter of a vector or mask class (Sea functions take i f p, 3.6.3)"
75262 GOTO 72180
75265 LET M$ = "call of " & S$(Q2) & " with a vector or mask register (Sea functions take i f p, 3.6.3)"
75267 GOTO 72180
75270 LET M$ = "chk with a vector or mask argument"
75272 GOTO 72180
75280 REM ---- 5285: mov of masks (V8 = 3): the destination takes the lane count of the source (3.6.1) ----
75285 LET W2 = O(P1 + 1)
75287 LET W1 = R(W2, 2)
75289 IF W1 = 0 THEN 75362
75291 LET W2 = O(P1)
75293 GOSUB 75380
75295 GOTO 72060
75298 REM ---- 5300: an LF instruction (V8 = 3): vfeat on x86_64-linux only (3.6.4); a mask has the lane count of
75299 REM the instruction that writes it and is read only with that lane count (3.6.1) ----
75300 LET X3 = Q(I0, 6)
75302 LET M$ = "vfeat on target " & T$ & " (x86_64-linux only, 3.6.4)"
75304 IF X3 <> 119 THEN 75312
75306 IF T$ <> "x86_64-linux" THEN 72180
75308 GOTO 72060
75310 REM W1 the lane count: 2 for ldm2 stm2 xcmp xsel, 4 for ldm4 stm4 ycmp ysel, operand a's for mand mor mnot
75312 LET W1 = 2
75314 IF X3 = 76 THEN 75338
75316 IF X3 = 80 THEN 75338
75318 IF X3 = 95 THEN 75338
75320 IF X3 = 96 THEN 75338
75322 LET W1 = 4
75324 IF X3 = 77 THEN 75338
75326 IF X3 = 81 THEN 75338
75328 IF X3 = 112 THEN 75338
75330 IF X3 = 113 THEN 75338
75332 IF X3 < 116 THEN 72060
75334 LET W2 = O(I(A0, 2) + 1)
75335 LET W1 = R(W2, 2)
75336 IF W1 = 0 THEN 75362
75337 REM each m operand in field order: a read one must have W1 lanes, a written one gets W1 (5380)
75338 LET P1 = I(A0, 2)
75340 FOR J2 = 1 TO Q(I0, 4)
75342 LET B4 = Q(I0, 3) + J2 - 1
75344 IF F(B4, 1) <> 22 THEN 75358
75346 LET W2 = O(P1 + J2 - 1)
75348 IF F(B4, 0) = 2 THEN 75356
75350 LET M$ = "mask m" & STR$(W2) & " is read with " & STR$(W1) & " lanes but has " & STR$(R(W2, 2)) & " (3.6.1)"
75352 IF R(W2, 2) <> W1 THEN 72180
75354 GOTO 75358
75356 GOSUB 75380
75358 NEXT J2
75360 GOTO 72060
75362 LET M$ = "mask m" & STR$(W2) & " is read before an instruction gives it a lane count (3.6.1)"
75364 GOTO 72180
75375 REM ---- 5380: mask W2 written with W1 lanes: its first write fixes its lane count, a later one keeps it ----
75380 LET M$ = "mask m" & STR$(W2) & " is written with " & STR$(W1) & " lanes after " & STR$(R(W2, 2)) & " (3.6.1)"
75382 IF R(W2, 2) = 0 THEN 75388
75384 IF R(W2, 2) <> W1 THEN 72180
75386 RETURN
75388 LET R(W2, 2) = W1
75390 RETURN
75395 REM ---- 5400: once, from 6165, for a row of set LF: its internal code (73-119, the table K1$ of 6136), its
75397 REM category and memory kind (ldx ldy stx sty f64, ldm2 ldm4 stm2 stm4 byte; the rest pure) and roles (6930) ----
75400 LET C5$ = "|" & Q$(I2) & "="
75402 LET P3 = POS(K1$, C5$)
75404 LET M$ = "passes.txt has the set-LF record " & Q$(I2) & ", which " & P$ & " does not know"
75406 IF P3 = 0 THEN 72205
75408 LET X3 = 72 + VAL(SEG$(K1$, P3 + LEN(C5$), P3 + LEN(C5$) + 1))
75410 LET Q(I2, 6) = X3
75412 LET Q(I2, 7) = 1
75414 IF X3 < 74 THEN 75428
75416 IF X3 > 81 THEN 75428
75418 LET Q(I2, 7) = 3
75420 IF X3 < 78 THEN 75424
75422 LET Q(I2, 7) = 4
75424 LET Q(I2, 8) = 3
75425 IF X3 - 74 - 4 * INT((X3 - 74) / 4) < 2 THEN 75428
75426 LET Q(I2, 8) = 2
75428 GOSUB 76930
75430 GOTO 76205
76105 REM ---- once: internal codes of the opcodes (Q(row,6)), categories (Q(row,7): 1 pure, 2 iaddc
76110 REM isubc imulc inegc, 3 load, 4 store), memory kinds (Q(row,8)), field roles (F(row,0)) ----------
76115 LET C1$ = "|li=01|lf=02|la=03|sa=04|mov=05|iadd=06|isub=07|imul=08|iaddc=09|isubc=10|imulc=11|ineg=12|inegc=13|idivf=14|imodf=15|imulh=16|iand=17|ior=18|"
76120 LET C2$ = "|ixor=19|ishl=20|ishr=21|isar=22|bnot=23|icmp=24|isel=25|fsel=26|psel=27|rcount=28|fadd=29|fsub=30|fmul=31|fdiv=32|fneg=33|fabs=34|fsqrt=35|"
76125 LET C3$ = "|fmin=36|fmax=37|ffloor=38|fceil=39|ftrunc=40|fround=41|fcmp=42|fnan=43|itof=44|ftoi=45|padd=46|ldi=47|ldb=48|ldf=49|ldp=50|sti=51|stb=52|"
76130 LET C4$ = "|stf=53|stp=54|mcopy=55|loop=56|endloop=57|do=58|enddo=59|if=60|ifz=61|else=62|endif=63|exit=64|next=65|ret=66|call=67|rcall=68|chkb=69|"
76135 LET C0$ = C1$ & C2$ & C3$ & C4$ & "|chk=70|retain=71|release=72|"
76136 LET K1$ = "|pdiff=01|ldx=02|ldy=03|ldm2=04|ldm4=05|stx=06|sty=07|stm2=08|stm4=09|xadd=10|xsub=11|xmul=12|xdiv=13|xmin=14|xmax=15|xneg=16|xabs=17|xsqrt=18|"
76137 LET K2$ = "|xfloor=19|xceil=20|xtrunc=21|xround=22|xcmp=23|xsel=24|xsplat=25|xlane=26|yadd=27|ysub=28|ymul=29|ydiv=30|ymin=31|ymax=32|yneg=33|yabs=34|"
76138 LET K3$ = "|ysqrt=35|yfloor=36|yceil=37|ytrunc=38|yround=39|ycmp=40|ysel=41|ysplat=42|ylane=43|mand=44|mor=45|mnot=46|vfeat=47|"
76139 LET K1$ = K1$ & K2$ & K3$
76140 FOR I2 = 0 TO Z(7)
76145 LET Q(I2, 6) = 0
76150 LET Q(I2, 7) = 0
76155 LET Q(I2, 8) = 0
76160 IF I2 = 0 THEN 76205
76165 IF Q(I2, 1) = 6 THEN 75400
76167 IF Q(I2, 1) <> 5 THEN 76205
76170 LET C5$ = "|" & Q$(I2) & "="
76175 LET P3 = POS(C0$, C5$)
76180 IF P3 = 0 THEN 76205
76185 LET X3 = VAL(SEG$(C0$, P3 + LEN(C5$), P3 + LEN(C5$) + 1))
76190 LET Q(I2, 6) = X3
76195 GOSUB 76805
76200 GOSUB 76930
76205 NEXT I2
76210 REM the rows of the instructions T2 and T4 write, T3's mov, and the conditions of icmp
76215 LET E2 = 0
76220 LET E3 = 0
76225 LET E4 = 0
76230 LET E5 = 0
76235 LET E6 = 0
76240 LET E7 = 0
76245 LET E8 = 0
76250 LET E9 = 0
76255 LET G2 = 0
76260 LET G3 = 0
76265 LET G4 = 0
76270 LET G5 = 0
76275 LET G6 = 0
76280 LET G7 = 0
76285 LET G8 = 0
76290 GOSUB 76625
76295 LET M$ = "an opcode that " & P$ & " writes is missing from passes.txt"
76300 IF E2 * E3 * E4 * E5 * E6 * E7 * E8 * E9 = 0 THEN 72205
76305 IF G2 * G3 * G4 * G5 * G6 * G7 * G8 = 0 THEN 72205
76310 CALL "tb_enum": N$(), Z(5), "cc", X3
76315 LET M$ = "enumeration cc is missing from passes.txt"
76320 IF X3 = 0 THEN 72205
76325 CALL "tb_word": N(), W$(), X3, "eq", C4
76330 CALL "tb_word": N(), W$(), X3, "ne", C5
76335 CALL "tb_word": N(), W$(), X3, "lt", C6
76340 CALL "tb_word": N(), W$(), X3, "le", C7
76345 CALL "tb_word": N(), W$(), X3, "gt", C8
76350 CALL "tb_word": N(), W$(), X3, "ge", C9
76355 IF C4 * C5 * C6 * C7 * C8 * C9 = 0 THEN 72205
76360 REM the header offsets and the extent limit (rt.inc, limits.inc)
76365 LET Z$ = "ARR_ROWS"
76370 GOSUB 72310
76375 LET K6 = V
76380 LET Z$ = "ARR_COLS"
76385 GOSUB 72310
76390 LET K7 = V
76395 LET Z$ = "ARR_DATA"
76400 GOSUB 72310
76405 LET K8 = V
76410 LET Z$ = "ARR_RC"
76415 GOSUB 72310
76420 LET K9 = V
76425 LET Z$ = "LIM_EXTENT"
76430 GOSUB 72310
76435 LET K0 = V
76440 REM the entries that make array registers, named through the entries table (DESIGN 5.8 Terms)
76445 LET C5$ = "ARR_NEW"
76450 GOSUB 76580
76455 LET Y3 = Q2
76460 LET C5$ = "ARR_NEW_U"
76465 GOSUB 76580
76470 LET Y4 = Q2
76475 LET C5$ = "ARR_NEW_S"
76480 GOSUB 76580
76485 LET Y5 = Q2
76490 LET C5$ = "SORT"
76495 GOSUB 76580
76500 LET Y6 = Q2
76505 LET C5$ = "ARGSORT"
76510 GOSUB 76580
76515 LET Y7 = Q2
76520 LET C5$ = "ARGS"
76525 GOSUB 76580
76530 LET Y8 = Q2
76535 LET C5$ = "ARR_UNIQUE"
76540 GOSUB 76580
76545 LET Y9 = Q2
76550 REM N8 marks an unknown L or U; U9 = 2^52 bounds every constant of a fact; Y2 counts functions
76555 LET N8 = 1E30
76560 LET U9 = 2 ^ 52
76565 LET Y2 = 0
76570 RETURN
76575 REM ---- SU_ENT: Q2 = the row of S$ holding the name of the entry whose id is C5$ ----------------
76580 FOR I3 = 1 TO N7
76585 IF Y$(I3, 1) <> C5$ THEN 76605
76590 LET Z$ = Y$(I3, 2)
76595 GOSUB 75000
76600 RETURN
76605 NEXT I3
76610 LET M$ = "entry " & C5$ & " is not in the entries table"
76615 GOTO 72205
76620 REM ---- SU_ROWS: the rows of the opcodes the LIR passes write ----------------------------------------
76625 FOR I2 = 1 TO A8
76630 LET I3 = A(I2)
76635 LET X3 = Q(I3, 6)
76640 IF X3 <> 1 THEN 76650
76645 LET E2 = I3
76650 IF X3 <> 2 THEN 76660
76655 LET E3 = I3
76660 IF X3 <> 5 THEN 76670
76665 LET E4 = I3
76670 IF X3 <> 6 THEN 76680
76675 LET E5 = I3
76680 IF X3 <> 7 THEN 76690
76685 LET E6 = I3
76690 IF X3 <> 8 THEN 76700
76695 LET E7 = I3
76700 IF X3 <> 12 THEN 76710
76705 LET E8 = I3
76710 IF X3 <> 17 THEN 76720
76715 LET E9 = I3
76720 IF X3 <> 22 THEN 76730
76725 LET G2 = I3
76730 IF X3 <> 16 THEN 76740
76735 LET G3 = I3
76740 IF X3 <> 24 THEN 76750
76745 LET G4 = I3
76750 IF X3 <> 25 THEN 76760
76755 LET G5 = I3
76760 IF X3 <> 26 THEN 76770
76765 LET G6 = I3
76770 IF X3 <> 27 THEN 76780
76775 LET G7 = I3
76780 IF X3 <> 31 THEN 76790
76785 LET G8 = I3
76790 NEXT I2
76795 RETURN
76800 REM ---- SU_CAT: category and memory kind of row I2 (internal code X3) -------------------------
76805 IF X3 < 47 THEN 76855
76810 IF X3 > 54 THEN 77080
76815 LET Q(I2, 7) = 3
76820 IF X3 > 50 THEN 76835
76825 LET Q(I2, 8) = X3 - 46
76830 GOTO 76845
76835 LET Q(I2, 7) = 4
76840 LET Q(I2, 8) = X3 - 50
76845 REM kinds: 1 i64 (ldi sti), 2 byte (ldb stb), 3 f64 (ldf stf), 4 address (ldp stp)
76850 RETURN
76855 IF X3 = 9 THEN 76905
76860 IF X3 = 10 THEN 76905
76865 IF X3 = 11 THEN 76905
76870 IF X3 = 13 THEN 76905
76875 IF X3 = 14 THEN 77080
76880 IF X3 = 15 THEN 77080
76885 IF X3 = 28 THEN 77080
76890 IF X3 = 45 THEN 77080
76895 LET Q(I2, 7) = 1
76900 RETURN
76905 LET Q(I2, 7) = 2
76910 RETURN
76915 REM ---- SU_ROLE: F(field,0) of every field of row I2: 0 site (no operand), 1 register read,
76920 REM 2 register written, 3 an i or f immediate (a row of C), 4 an off field (a row of G), 5 a u
76925 REM field (a count), 6 any other one-operand field, 7 a pos (two operands) ----------------------
76930 FOR J2 = 1 TO Q(I2, 4)
76935 LET B4 = Q(I2, 3) + J2 - 1
76940 LET T2 = F(B4, 1)
76945 LET F(B4, 0) = 6
76950 IF T2 = 6 THEN 77020
76955 IF T2 = 5 THEN 77030
76960 IF T2 = 1 THEN 77040
76965 IF T2 = 2 THEN 77050
76970 IF T2 = 3 THEN 77065
76975 IF T2 < 16 THEN 77070
76980 IF T2 > 22 THEN 77070
76985 LET F(B4, 0) = 1
76990 IF X3 = 55 THEN 77070
76995 IF F$(B4) = "d" THEN 77010
77000 IF F$(B4) = "e" THEN 77010
77005 IF F$(B4) <> "ind" THEN 77070
77010 LET F(B4, 0) = 2
77015 GOTO 77070
77020 LET F(B4, 0) = 0
77025 GOTO 77070
77030 LET F(B4, 0) = 7
77035 GOTO 77070
77040 LET F(B4, 0) = 5
77045 GOTO 77070
77050 IF F$(B4) <> "off" THEN 77065
77055 LET F(B4, 0) = 4
77060 GOTO 77070
77065 LET F(B4, 0) = 3
77070 NEXT J2
77075 RETURN
77080 RETURN
77160 REM ---- VIS: lirrw's own operand visitor (modes 9-12 only; the pass keeps its own, DESIGN 2.6.3): visit
77165 REM the register operands of instruction N0 in field order; for each, O(P0) is the register and R0 its role
77170 REM (1 read, 2 written). Locals P0 W9 J9 B3 J0 J8 R0 and U(field) (the u fields, for the repeat counts).
77175 LET P0 = I(N0, 2)
77180 LET W9 = I(N0, 1)
77185 IF W9 = 0 THEN 77080
77190 FOR J9 = 1 TO Q(W9, 4)
77195 LET B3 = Q(W9, 3) + J9 - 1
77200 LET R0 = F(B3, 0)
77205 IF R0 = 0 THEN 77275
77210 LET J0 = 1
77215 IF F(B3, 3) = 0 THEN 77225
77220 LET J0 = U(F(B3, 3))
77225 FOR J8 = 1 TO J0
77230 IF R0 > 2 THEN 77245
77235 IF O(P0) = 0 THEN 77245
77240 GOSUB 77290
77245 IF R0 <> 5 THEN 77255
77250 LET U(J9) = O(P0)
77255 LET P0 = P0 + 1
77260 IF R0 <> 7 THEN 77270
77265 LET P0 = P0 + 1
77270 NEXT J8
77275 NEXT J9
77280 RETURN
77285 REM CBD: the callback of mode V0 (9 count a read, 10 uncount it, 11 renumber, 12 self reads), back to VIS
77290 ON V0 - 8 GOTO 77680, 77700, 77720, 77755
77675 REM CB9 (T10): count a read
77680 IF R0 <> 1 THEN 77080
77685 LET R(O(P0), 2) = R(O(P0), 2) + 1
77690 RETURN
77695 REM CB10 (T10): uncount a read of a deleted instruction
77700 IF R0 <> 1 THEN 77080
77705 LET R(O(P0), 2) = R(O(P0), 2) - 1
77710 RETURN
77715 REM CB11 (renumbering): number registers by first appearance (W(old,0) new, W(new,1) class)
77720 LET X6 = O(P0)
77725 IF W(X6, 0) > 0 THEN 77745
77730 LET H8 = H8 + 1
77735 LET W(X6, 0) = H8
77740 LET W(H8, 1) = R(X6, 1)
77745 LET O(P0) = W(X6, 0)
77750 RETURN
77752 REM CB12 (T10, L-bn): X6 counts the reads of register X3
77755 IF R0 <> 1 THEN 77080
77757 IF O(P0) <> X3 THEN 77080
77758 LET X6 = X6 + 1
77759 RETURN
77840 REM ---- COMPACT: drop the deleted instructions, operands kept in record order; then BLOCKS ------
77845 LET N2 = 0
77850 LET P3 = 0
77855 FOR N3 = 1 TO A0
77860 IF I(N3, 1) = 0 THEN 77925
77865 LET N2 = N2 + 1
77870 LET P4 = I(N3, 2)
77875 LET X3 = I(N3, 3)
77880 LET I(N2, 0) = I(N3, 0)
77885 LET I(N2, 1) = I(N3, 1)
77890 LET I(N2, 3) = X3
77895 LET I(N2, 4) = I(N3, 4)
77900 LET I(N2, 2) = P3 + 1
77905 FOR X4 = 0 TO X3 - 1
77910 LET O(P3 + 1 + X4) = O(P4 + X4)
77915 NEXT X4
77920 LET P3 = P3 + X3
77925 NEXT N3
77930 LET A0 = N2
77935 LET A1 = P3
77940 REM ---- BLOCKS: K(b,1..4) of every block from the records (kind, opening, else, closing) -------
77945 FOR N3 = 1 TO A0
77950 LET X3 = Q(I(N3, 1), 6)
77955 IF X3 < 56 THEN 78040
77960 IF X3 > 63 THEN 78040
77965 LET B4 = O(I(N3, 2))
77970 IF X3 = 57 THEN 78035
77975 IF X3 = 59 THEN 78035
77980 IF X3 = 63 THEN 78035
77985 IF X3 = 62 THEN 78025
77990 LET K(B4, 1) = 4
77995 IF X3 = 61 THEN 78005
78000 LET K(B4, 1) = (X3 - 54) / 2
78005 LET K(B4, 2) = N3
78010 LET K(B4, 3) = 0
78015 LET K(B4, 4) = 0
78020 GOTO 78040
78025 LET K(B4, 3) = N3
78030 GOTO 78040
78035 LET K(B4, 4) = N3
78040 NEXT N3
78045 RETURN
78675 REM ---- RENREG: registers renumbered by first appearance (parameters first, DESIGN 3.6.1) -----
78680 FOR X4 = 1 TO M7
78685 LET W(X4, 0) = 0
78690 NEXT X4
78695 FOR X4 = 1 TO M(5)
78700 LET W(X4, 0) = X4
78705 LET W(X4, 1) = R(X4, 1)
78710 NEXT X4
78715 LET H8 = M(5)
78720 LET V0 = 11
78725 FOR N0 = 1 TO A0
78730 GOSUB 77175
78735 NEXT N0
78740 FOR X4 = 1 TO H8
78745 LET R(X4, 1) = W(X4, 1)
78750 NEXT X4
78755 LET M7 = H8
78760 RETURN
78765 REM ---- RENBLK: blocks renumbered in order of their opening records -------------------------
78770 LET H8 = 0
78775 FOR N3 = 1 TO A0
78780 LET X3 = Q(I(N3, 1), 6)
78785 IF X3 < 56 THEN 78845
78790 IF X3 > 65 THEN 78845
78795 LET P4 = I(N3, 2)
78800 IF X3 = 56 THEN 78830
78805 IF X3 = 58 THEN 78830
78810 IF X3 = 60 THEN 78830
78815 IF X3 = 61 THEN 78830
78820 LET O(P4) = W(O(P4), 2)
78825 GOTO 78845
78830 LET H8 = H8 + 1
78835 LET W(O(P4), 2) = H8
78840 LET O(P4) = H8
78845 NEXT N3
78850 LET B2 = H8
78855 GOSUB 77945
78860 RETURN
78950 REM ====================================================================================
78955 REM T10: clean-up until nothing changes (DESIGN 5.8 T10, L-bn); the entry 69440 then renumbers
78960 REM ====================================================================================
78965 GOSUB 79510
78967 LET H9 = 0
78970 FOR R2 = 1 TO M7
78975 LET R(R2, 2) = 0
78980 NEXT R2
78985 LET V0 = 9
78990 FOR N0 = 1 TO A0
78995 GOSUB 77175
79000 NEXT N0
79005 FOR N2 = A0 TO 1 STEP -1
79010 LET B7 = I(N2, 1)
79012 IF I(N2, 0) < 0 THEN 79100
79015 LET P4 = I(N2, 2)
79020 LET X4 = Q(B7, 7)
79025 IF Q(B7, 6) <> 5 THEN 79035
79030 IF O(P4) = O(P4 + 1) THEN 79075
79035 IF X4 = 3 THEN 79070
79040 IF X4 <> 1 THEN 79100
79042 REM a pure instruction or load is dead when its destination has no read but its own (L-bn: an
79043 REM isel R c S R that nothing else reads goes)
79045 FOR J2 = 1 TO Q(B7, 4)
79050 IF F(Q(B7, 3) + J2 - 1, 0) <> 2 THEN 79060
79055 LET X3 = O(P4 + J2 - 1)
79056 GOSUB 79255
79057 IF R(X3, 2) = X6 THEN 79075
79060 NEXT J2
79065 GOTO 79100
79070 LET X3 = O(P4)
79071 GOSUB 79255
79072 IF R(X3, 2) > X6 THEN 79100
79075 LET N0 = N2
79080 LET V0 = 10
79085 GOSUB 77175
79090 LET I(N2, 1) = 0
79095 LET H9 = 1
79100 NEXT N2
79105 GOSUB 77845
79110 REM empty if / ifz (with its else), retain R followed at once by release R
79115 FOR N2 = 1 TO A0 - 1
79120 IF I(N2, 1) = 0 THEN 79230
79122 IF I(N2, 0) < 0 THEN 79230
79125 LET X3 = Q(I(N2, 1), 6)
79130 LET X4 = Q(I(N2 + 1, 1), 6)
79135 IF X3 = 71 THEN 79205
79140 IF X3 < 60 THEN 79230
79145 IF X3 > 61 THEN 79230
79150 LET B5 = O(I(N2, 2))
79155 IF O(I(N2 + 1, 2)) <> B5 THEN 79230
79160 IF X4 = 63 THEN 79185
79165 IF X4 <> 62 THEN 79230
79170 IF N2 + 2 > A0 THEN 79230
79175 IF Q(I(N2 + 2, 1), 6) <> 63 THEN 79230
79180 LET I(N2 + 2, 1) = 0
79185 LET I(N2, 1) = 0
79190 LET I(N2 + 1, 1) = 0
79195 LET H9 = 1
79200 GOTO 79230
79205 IF X4 <> 72 THEN 79230
79210 IF O(I(N2, 2)) <> O(I(N2 + 1, 2)) THEN 79230
79215 LET I(N2, 1) = 0
79220 LET I(N2 + 1, 1) = 0
79225 LET H9 = 1
79230 NEXT N2
79235 GOSUB 77845
79240 IF H9 = 1 THEN 78965
79245 RETURN
79250 REM SELF (L-bn): X6 = the reads of register X3 by instruction N2 itself, which do not count
79255 LET X6 = 0
79260 LET N0 = N2
79265 LET V0 = 12
79270 GOSUB 77175
79275 RETURN
79505 REM ---- DEAD (DESIGN 5.8, L-bb reading 3): I(n,0) = -1 for every record after an exit, next
79507 REM or ret up to the end of its part, which T2, T3, T4 and T10 never change; else 0. X6 = 1
79508 REM inside such a range, X4 the blocks opened in it. Locals N3 X3 X4 X6.
79510 LET X6 = 0
79515 LET X4 = 0
79520 FOR N3 = 1 TO A0
79525 LET I(N3, 0) = 0
79530 LET X3 = Q(I(N3, 1), 6)
79535 IF X6 = 1 THEN 79560
79540 IF X3 < 64 THEN 79640
79545 IF X3 > 66 THEN 79640
79550 LET X6 = 1
79555 GOTO 79640
79560 REM a block opened in the range (loop do if ifz) is dead with all of it
79565 IF X3 = 56 THEN 79595
79570 IF X3 = 58 THEN 79595
79575 IF X3 = 60 THEN 79595
79580 IF X3 = 61 THEN 79595
79585 IF X3 = 62 THEN 79605
79590 GOTO 79610
79595 LET X4 = X4 + 1
79600 GOTO 79635
79605 IF X4 = 0 THEN 79630
79610 IF X3 = 57 THEN 79625
79615 IF X3 = 59 THEN 79625
79620 IF X3 <> 63 THEN 79635
79625 REM a closing record (endloop enddo endif) of the part itself, or its else, is live
79627 IF X4 = 0 THEN 79630
79628 LET X4 = X4 - 1
79629 GOTO 79635
79630 LET X6 = 0
79632 GOTO 79640
79635 LET I(N3, 0) = -1
79640 NEXT N3
79645 RETURN
