10 REM ====================================================================================
20 REM seaval -- validator of Sea's intermediate files against include/passes.txt
30 REM (docs/DESIGN.md 2.10, 3, 3.9). A Baysick program built like a pass (DESIGN 2.6.3):
40 REM this file (lines 1-59999), the modules io diag tables, the generated DATA blocks errors
50 REM consts records, and the line 99999 END.
60 REM
70 REM USAGE   the file to check is read on standard input. Its FIRST line (not part of the file)
80 REM         names the format: ast, res, hir1, hir, lir1 or lir. The rest is the file, verbatim.
90 REM         (Baysick has no command-line arguments: the options travel on standard input,
100 REM         DESIGN 2.2 step 4.) Example: ( echo hir1; cat sea.hir1 ) | seaval
110 REM EXIT    0 the file is valid (nothing is printed); 11 it is not (DESIGN 2.2: an internal
120 REM         consistency check failed: a file that fails here is a pass bug, so status 10, a
130 REM         Sea compile error, is never used). Messages on standard error, two lines:
140 REM            seaval: line <n>: <what is wrong>
150 REM            seaval: record: <the record, cut at 100 bytes>
160 REM            seaval: internal error: <bad record | bad tree | bad header | truncated input>
170 REM         (the last line is the text of errors.inc; a header error names the header line, a
180 REM         file that ends early the last line read). A line beyond Baysick's 65 536-byte
190 REM         limit, or a wrong format name, is also reported with status 11.
200 REM CHECKED header records (order, version = SEA_FILE_VERSION, target in enum target, #file
210 REM         paths); every body byte in 0x20-0x7E; every record: opcode of the file's sets (ast:
220 REM         A with codes 1-49; res: A, the codes 50-63 as well; hir1: H H1; hir: H HF; lir1: L; lir: L LF), field count including the repeated
230 REM         fields, each field's type (u i f s pos site fl, enumerations, references, registers
240 REM         with their class); the tree stack of DESIGN 3.3 (pops from the pops column; a
250 REM         section end - prog, cn, end - leaves the stack empty; end pops a block); in the
260 REM         HIR files: section order (types, then constants / instances, then functions),
270 REM         type ids 10, 11, ... in order and ty references to defined ids, fd records after
280 REM         tstruct / trec, cn / inst / fn numbering from 1, np par and nl loc records before
290 REM         the body, lid within the function's locals; in the LIR files: functions then data
300 REM         records, slots right after func and numbered from 1, blocks numbered from 1 in
310 REM         opening order and properly nested (exit / next name an open loop or do), register
320 REM         numbers 1, 2, ... in order of first appearance with one class each (DESIGN 3.6.1)
330 REM         and no x y m class in lir1, data labels d1, d2, ... in order (in lir1 also in the
340 REM         order of first reference), fmt / dat sub-records, chk names an error of errors.inc
350 REM         (phase R); and #end as the last record, with nothing after it.
360 REM NOT CHECKED  anything that needs the meaning of the program (types of operands, the
370 REM         position of a node in its source, names of rt.inc entries).
380 REM
390 REM Variables  (scalars: a letter and at most one digit; arrays: one letter)
400 REM   arrays   E E$ error table; N N$ W$ enums; R R$ records; F F$ fields; Z counts and
410 REM            capacities; C C$ constants; Y special code per record row; G$ fields of the
420 REM            current line; U values of the u-like fields of the record; L limb scratch;
430 REM            S tree stack (record rows); Q register class by number; K block stack
440 REM            (number, kind); H$ #file paths; A allowed record sets of this format
450 REM   P$ pass name  K$ format name  K0 format 1 ast 2 hir1 3 hir 4 lir1 5 lir
460 REM   L$ current line  L0 its number  C0 its field count  I0 its record row  Y0 its special code
470 REM   M$ what is wrong  D$ error name for the final message
480 REM   S0 tree stack depth  H8 HIR section (1 types, 2 constants / instances, 3 functions)
490 REM   F7 inside a function  P7 par left  L7 loc left  F8 locals of the function  Y9 last type id
500 REM   X8 fd records owed  C7 cn count  I7 inst count  F6 fn count  D9 prog seen
510 REM   M8 LIR (0 outside, 1 after func, 2 in code, 3 data)  M7 last register  S6 slots  B1 block
520 REM   depth  B2 last block number  D8 data labels defined  R8 highest label used  X9 sub-records
530 REM   owed  Z9 kind owed (0 ftext / fconv, 1 dvi, 2 dvf, 3 soff; Z6 slay size, Z7 last soff)  V9 file version  R9 B9 S9 limits
540 REM Special codes Y(i): 1 prog; 10 type definition  11 fd  12 cn  13 inst  14 fn  15 par  16 loc
550 REM   17 end; 30 str  31 fmt  32 ftext  33 fconv  34 dat  35 dvi  36 dvf  37 func  38 slot
560 REM   39 endfunc  40 loop  41 endloop  42 do  43 enddo  44 if / ifz  45 else  46 endif  47 exit
570 REM   48 next  50 chk  25 slay  26 soff (phase 4: retain release mcopy are plain records); 0 every other record.
580 REM ====================================================================================
590 DIM E(299), E$(299,5), N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), Z(8)
600 DIM C(299,4), C$(299), Y(399), G$(300), U(40), L(4), S(100000), Q(100000), K(10000,2), H$(100), A(6)
610 LET P$ = "seaval"
620 REM ---- the tables ---------------------------------------------------------------------
630 CALL "tb_errors": P$, E(), E$(), 299, E0
640 CALL "tb_consts": P$, E(), E$(), E0, C(), C$(), 299, N5
650 LET Z(1) = 39
660 LET Z(2) = 299
670 LET Z(3) = 399
680 LET Z(4) = 1499
690 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), R(), R$(), F(), F$(), Z()
700 CALL "tb_cval": C(), C$(), N5, "FILE_VERSION", V9, T
710 IF T = 0 THEN 730
720 CALL "dg_bug": P$, "constant FILE_VERSION is not in the consts table"
730 CALL "tb_cval": C(), C$(), N5, "LIM_LIR_REGS", R9, T
740 IF T = 0 THEN 760
750 CALL "dg_bug": P$, "constant LIM_LIR_REGS is not in the consts table"
760 CALL "tb_cval": C(), C$(), N5, "LIM_LIR_BLOCKS", B9, T
770 IF T = 0 THEN 790
780 CALL "dg_bug": P$, "constant LIM_LIR_BLOCKS is not in the consts table"
790 CALL "tb_cval": C(), C$(), N5, "LIM_LIR_SLOTS", S9, T
800 IF T = 0 THEN 830
810 CALL "dg_bug": P$, "constant LIM_LIR_SLOTS is not in the consts table"
820 REM the stacks below are sized for the limits
830 IF R9 > 100000 THEN 860
840 IF B9 > 10000 THEN 860
850 GOTO 880
860 CALL "dg_bug": P$, "register or block limit larger than the validator's arrays"
870 REM ---- special code of every record row (see the legend) ------------------------------
880 LET K1$ = "|tvec=10|tmat=10|tfvec=10|tfmat=10|tstruct=10|trec=10|ttuple=10|fd=11|cn=12|inst=13|fn=14|par=15|loc=16|end=17|"
890 LET K2$ = "|str=30|fmt=31|ftext=32|fconv=33|dat=34|dvi=35|dvf=36|func=37|slot=38|endfunc=39|loop=40|endloop=41|do=42|enddo=43|if=44|ifz=44|else=45|endif=46|exit=47|next=48|chk=50|slay=25|soff=26|"
900 FOR I = 1 TO Z(7)
910 LET Y(I) = 0
920 LET S1 = R(I, 1)
930 IF S1 = 1 THEN 1010
940 IF S1 = 0 THEN 1070
950 IF S1 = 6 THEN 1070
960 IF S1 = 5 THEN 1040
970 LET P1 = POS(K1$, "|" & R$(I) & "=")
980 IF P1 = 0 THEN 1070
990 LET Y(I) = VAL(SEG$(K1$, P1 + LEN(R$(I)) + 2, P1 + LEN(R$(I)) + 3))
1000 GOTO 1070
1010 IF R$(I) = "prog" THEN 1020
1012 IF R$(I) = "rerr" THEN 1016
1014 IF R$(I) = "rtup" THEN 1018
1015 GOTO 1070
1016 LET Y(I) = 20
1017 GOTO 1070
1018 LET Y(I) = 21
1019 GOTO 1070
1020 LET Y(I) = 1
1030 GOTO 1070
1040 LET P1 = POS(K2$, "|" & R$(I) & "=")
1050 IF P1 = 0 THEN 1070
1060 LET Y(I) = VAL(SEG$(K2$, P1 + LEN(R$(I)) + 2, P1 + LEN(R$(I)) + 3))
1070 NEXT I
1080 REM ---- the format line, then the header --------------------------------------------------
1090 IF END #0 THEN 1210
1100 LINPUT #0, K$
1110 REM Baysick compares strings without trailing blanks: "lir1 " = "lir1", so check the last byte too (DESIGN 2.7)
1120 IF LEN(K$) = 0 THEN 1210
1130 IF SEG$(K$, LEN(K$), LEN(K$)) = " " THEN 1210
1140 REM the allowed record sets A(s) of each format; sets 1 A, 2 H, 3 H1, 4 HF, 5 L, 6 LF
1150 LET K0 = 0
1160 IF K$ = "ast" THEN 1220
1165 IF K$ = "res" THEN 1226
1170 IF K$ = "hir1" THEN 1250
1180 IF K$ = "hir" THEN 1290
1190 IF K$ = "lir1" THEN 1330
1200 IF K$ = "lir" THEN 1360
1210 CALL "dg_bug": P$, "the first input line must name the format: ast, res, hir1, hir, lir1 or lir"
1220 LET K0 = 1
1221 LET R6 = 0
1222 GOTO 1230
1226 LET K0 = 1
1227 LET R6 = 1
1230 LET A(1) = 1
1240 GOTO 1390
1250 LET K0 = 2
1260 LET A(2) = 1
1270 LET A(3) = 1
1280 GOTO 1390
1290 LET K0 = 3
1300 LET A(2) = 1
1310 LET A(4) = 1
1320 GOTO 1390
1330 LET K0 = 4
1340 LET A(5) = 1
1350 GOTO 1390
1360 LET K0 = 5
1370 LET A(5) = 1
1380 LET A(6) = 1
1390 CALL "io_hdr": 0, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), V9, T$, H$(), 100, N1, L$
1400 LET L0 = N1 + 3
1410 LET Y9 = 9
1420 REM ---- one record per round: L$ is line L0 ---------------------------------------------------
1430 LET D$ = "BAD_RECORD"
1440 CALL "io_plain": L$, O
1450 LET M$ = "a byte outside 0x20-0x7E"
1460 IF O = 0 THEN 4910
1470 CALL "io_split": L$, G$(), 300, C0
1480 LET M$ = "empty record, a blank at its start or end, two blanks in a row, or more than 300 fields"
1490 IF C0 < 1 THEN 4910
1500 IF G$(1) = "#end" THEN 4560
1510 LET M$ = "a record after prog"
1520 IF D9 = 1 THEN 4910
1530 REM the record row: the opcode among the sets of this format
1540 LET I0 = 0
1550 FOR I = 1 TO Z(7)
1560 IF A(R(I, 1)) = 0 THEN 1600
1562 IF R6 = 1 THEN 1570
1564 IF R(I, 1) <> 1 THEN 1570
1566 IF R(I, 2) >= 50 THEN 1600
1570 IF R$(I) <> G$(1) THEN 1600
1580 LET I0 = I
1590 GOTO 1630
1600 NEXT I
1610 LET M$ = "unknown opcode '" & G$(1) & "' for format " & K$
1620 GOTO 4910
1630 LET Y0 = Y(I0)
1640 REM a new LIR function numbers its registers, slots and blocks from 1 (before its fields)
1650 IF Y0 <> 37 THEN 1710
1660 LET M7 = 0
1670 LET S6 = 0
1680 LET B1 = 0
1690 LET B2 = 0
1700 REM ---- the fields: types, counts and the repeated fields ---------------------------------------
1710 LET T0 = 1
1720 FOR J = 1 TO R(I0, 4)
1730 LET B0 = R(I0, 3) + J - 1
1740 LET U(J) = 0
1750 LET X0 = 1
1760 IF F(B0, 3) = 0 THEN 1780
1770 LET X0 = U(F(B0, 3))
1780 FOR X = 1 TO X0
1790 LET T0 = T0 + 1
1800 LET M$ = "too few fields: " & F$(B0) & " is missing"
1810 IF T0 > C0 THEN 4910
1820 LET Z$ = G$(T0)
1830 LET T1 = F(B0, 1)
1840 LET O1 = F(B0, 2)
1850 GOSUB 5170
1860 NEXT X
1870 NEXT J
1880 LET M$ = "too many fields"
1890 IF T0 < C0 THEN 4910
1900 REM ---- what the record means: the tree files, or the LIR files --------------------------------
1910 IF K0 > 3 THEN 3160
1920 LET D$ = "BAD_TREE"
1930 LET M$ = "fd record expected after tstruct / trec"
1940 IF X8 = 0 THEN 1960
1950 IF Y0 <> 11 THEN 4910
1960 IF Y0 = 0 THEN 2085
1970 IF Y0 = 1 THEN 2260
1980 IF Y0 = 10 THEN 2320
1990 IF Y0 = 11 THEN 2490
1992 IF Y0 = 20 THEN 6600
1994 IF Y0 = 21 THEN 6800
2000 IF Y0 = 12 THEN 2540
2010 IF Y0 = 13 THEN 2660
2020 IF Y0 = 14 THEN 2760
2030 IF Y0 = 15 THEN 2950
2040 IF Y0 = 16 THEN 3000
2050 IF Y0 = 17 THEN 3060
2060 LET M$ = "record kind not handled"
2070 GOTO 4910
2080 REM ---- a node: pops its children, pushes itself ----------------------------------------------
2085 LET T9 = 2
2090 IF K0 = 1 THEN 2190
2100 LET M$ = "node outside a function"
2110 IF F7 = 1 THEN 2160
2120 IF K0 = 3 THEN 4910
2130 IF H8 = 3 THEN 4910
2140 LET H8 = 2
2150 GOTO 2190
2160 LET M$ = "node before the par / loc records of the function are complete"
2170 IF P7 > 0 THEN 4910
2180 IF L7 > 0 THEN 4910
2190 GOSUB 4950
2200 LET S0 = S0 + 1
2210 LET M$ = "tree deeper than the validator's stack"
2220 IF S0 > 100000 THEN 4910
2230 LET S(S0) = I0
2240 GOTO 4520
2250 REM ---- prog: pops everything, the stack must be empty ----------------------------------------
2260 GOSUB 4950
2270 LET M$ = "prog leaves nodes on the stack"
2280 IF S0 > 0 THEN 4910
2290 LET D9 = 1
2300 GOTO 4520
2310 REM ---- a type record: id is the next id, 10 first; tstruct / trec owe n fd records -------------
2320 LET M$ = "type record after the constants, instances or functions"
2330 IF H8 > 1 THEN 4910
2340 LET Z$ = "id"
2350 GOSUB 5090
2360 LET M$ = "type id " & STR$(V) & " where " & STR$(Y9 + 1) & " was expected (ids count from 10, in order)"
2370 IF V <> Y9 + 1 THEN 4910
2380 LET Y9 = V
2390 LET X8 = 0
2400 IF R$(I0) <> "tstruct" THEN 2440
2410 LET Z$ = "n"
2420 GOSUB 5090
2430 LET X8 = V
2440 IF R$(I0) <> "trec" THEN 4520
2450 LET Z$ = "n"
2460 GOSUB 5090
2470 LET X8 = V
2480 GOTO 4520
2490 LET M$ = "fd record outside tstruct / trec"
2500 IF X8 = 0 THEN 4910
2510 LET X8 = X8 - 1
2520 GOTO 4520
2530 REM ---- cn (hir1) and inst (hir): numbered from 1 ---------------------------------------------
2540 LET M$ = "constant after the functions"
2550 IF H8 = 3 THEN 4910
2560 LET H8 = 2
2570 LET Z$ = "cid"
2580 GOSUB 5090
2590 LET M$ = "cn numbered " & STR$(V) & " where " & STR$(C7 + 1) & " was expected"
2600 IF V <> C7 + 1 THEN 4910
2610 LET C7 = V
2620 GOSUB 4950
2630 LET M$ = "nodes left on the stack after cn"
2640 IF S0 > 0 THEN 4910
2650 GOTO 4520
2660 LET M$ = "instance after the functions"
2670 IF H8 = 3 THEN 4910
2680 LET H8 = 2
2690 LET Z$ = "iid"
2700 GOSUB 5090
2710 LET M$ = "inst numbered " & STR$(V) & " where " & STR$(I7 + 1) & " was expected"
2720 IF V <> I7 + 1 THEN 4910
2730 LET I7 = V
2740 GOTO 4520
2750 REM ---- fn / par / loc / end --------------------------------------------------------------------
2760 LET M$ = "fn inside a function"
2770 IF F7 = 1 THEN 4910
2780 LET M$ = "nodes left on the stack before fn"
2790 IF S0 > 0 THEN 4910
2800 LET Z$ = "fid"
2810 GOSUB 5090
2820 LET M$ = "fn numbered " & STR$(V) & " where " & STR$(F6 + 1) & " was expected"
2830 IF V <> F6 + 1 THEN 4910
2840 LET F6 = V
2850 LET Z$ = "np"
2860 GOSUB 5090
2870 LET P7 = V
2880 LET Z$ = "nl"
2890 GOSUB 5090
2900 LET L7 = V
2910 LET F8 = P7 + L7
2920 LET F7 = 1
2930 LET H8 = 3
2940 GOTO 4520
2950 LET M$ = "par outside a function, or more par records than np"
2960 IF F7 = 0 THEN 4910
2970 IF P7 = 0 THEN 4910
2980 LET P7 = P7 - 1
2990 GOTO 4520
3000 LET M$ = "loc outside a function, before its par records, or more loc records than nl"
3010 IF F7 = 0 THEN 4910
3020 IF P7 > 0 THEN 4910
3030 IF L7 = 0 THEN 4910
3040 LET L7 = L7 - 1
3050 GOTO 4520
3060 LET M$ = "end outside a function"
3070 IF F7 = 0 THEN 4910
3080 GOSUB 4950
3090 LET M$ = "end must pop the function body, a block"
3100 IF R$(S(S0 + 1)) <> "block" THEN 4910
3110 LET M$ = "nodes left on the stack after end"
3120 IF S0 > 0 THEN 4910
3130 LET F7 = 0
3140 GOTO 4520
3150 REM ---- LIR records ---------------------------------------------------------------------------------
3160 IF X9 = 0 THEN 3310
3162 IF Z9 <> 3 THEN 3170
3164 GOTO 7000
3170 LET M$ = "ftext / fconv records expected after fmt"
3180 IF Z9 > 0 THEN 3220
3190 IF Y0 = 32 THEN 3290
3200 IF Y0 = 33 THEN 3290
3210 GOTO 4910
3220 LET M$ = "dvi records expected after dat of i64 or bool"
3230 IF Z9 > 1 THEN 3260
3240 IF Y0 = 35 THEN 3290
3250 GOTO 4910
3260 LET M$ = "dvf records expected after dat of f64"
3270 IF Y0 = 36 THEN 3290
3280 GOTO 4910
3290 LET X9 = X9 - 1
3300 GOTO 4520
3310 LET M$ = "ftext, fconv, dvi, dvf or soff record outside its fmt, dat or slay"
3312 IF Y0 = 26 THEN 4910
3320 IF Y0 < 32 THEN 3360
3330 IF Y0 > 36 THEN 3360
3340 IF Y0 = 34 THEN 3360
3350 GOTO 4910
3360 IF Y0 = 30 THEN 4050
3370 IF Y0 = 31 THEN 4050
3380 IF Y0 = 34 THEN 4050
3385 IF Y0 = 25 THEN 4050
3390 IF Y0 = 37 THEN 4270
3400 IF Y0 = 38 THEN 4310
3410 IF Y0 = 39 THEN 4450
3420 REM an instruction (including the block records): only inside a function
3430 LET M$ = "instruction outside a function"
3440 IF M8 = 0 THEN 4910
3450 LET M$ = "instruction after the data records"
3460 IF M8 = 3 THEN 4910
3470 LET M8 = 2
3480 IF Y0 < 40 THEN 4520
3490 IF Y0 > 48 THEN 4520
3500 LET Z$ = "b"
3510 GOSUB 5090
3520 IF Y0 = 40 THEN 3610
3530 IF Y0 = 42 THEN 3610
3540 IF Y0 = 44 THEN 3610
3550 IF Y0 = 45 THEN 3760
3560 IF Y0 = 46 THEN 3830
3570 IF Y0 = 41 THEN 3830
3580 IF Y0 = 43 THEN 3830
3590 GOTO 3970
3600 REM ---- loop, do, if, ifz open block V: numbers count from 1 in order of opening ---------------
3610 LET M$ = "block " & STR$(V) & " opened where " & STR$(B2 + 1) & " was expected (blocks count from 1)"
3620 IF V <> B2 + 1 THEN 4910
3630 LET B2 = V
3640 LET B1 = B1 + 1
3650 LET M$ = "more blocks than SEA_LIM_LIR_BLOCKS"
3660 IF B1 > B9 THEN 4910
3670 LET K(B1, 1) = V
3680 LET W1 = 1
3690 IF Y0 = 40 THEN 3730
3700 LET W1 = 2
3710 IF Y0 = 42 THEN 3730
3720 LET W1 = 3
3730 LET K(B1, 2) = W1
3740 GOTO 4520
3750 REM ---- else: the innermost open block is an if without else -------------------------------------
3760 LET M$ = "else without an open if of the same number"
3770 IF B1 = 0 THEN 4910
3780 IF K(B1, 1) <> V THEN 4910
3790 IF K(B1, 2) <> 3 THEN 4910
3800 LET K(B1, 2) = 4
3810 GOTO 4520
3820 REM ---- endloop, enddo, endif: close the innermost block, which must be of that kind and number ---
3830 LET M$ = "end of block " & STR$(V) & " does not match the innermost open block"
3840 IF B1 = 0 THEN 4910
3850 IF K(B1, 1) <> V THEN 4910
3860 LET W1 = K(B1, 2)
3870 IF Y0 = 41 THEN 3910
3880 IF Y0 = 43 THEN 3930
3890 IF W1 < 3 THEN 4910
3900 GOTO 3940
3910 IF W1 <> 1 THEN 4910
3920 GOTO 3940
3930 IF W1 <> 2 THEN 4910
3940 LET B1 = B1 - 1
3950 GOTO 4520
3960 REM ---- exit, next: an enclosing loop or do ---------------------------------------------------------
3970 LET M$ = "exit / next names block " & STR$(V) & ", which is not an open loop or do"
3980 FOR W1 = B1 TO 1 STEP -1
3990 IF K(W1, 1) <> V THEN 4020
4000 IF K(W1, 2) > 2 THEN 4910
4010 GOTO 4520
4020 NEXT W1
4030 GOTO 4910
4040 REM ---- data records str, fmt, dat: after the last function, labels d1, d2, ... in order ----------
4050 LET M$ = "data record inside a function"
4060 IF M8 = 1 THEN 4910
4070 IF M8 = 2 THEN 4910
4080 LET M8 = 3
4090 LET Z$ = "lab"
4100 GOSUB 5090
4110 LET M$ = "data label d" & STR$(V) & " where d" & STR$(D8 + 1) & " was expected"
4120 IF V <> D8 + 1 THEN 4910
4130 LET D8 = V
4140 IF Y0 = 30 THEN 4520
4142 IF Y0 = 25 THEN 7020
4150 LET Z$ = "n"
4160 IF Y0 = 34 THEN 4180
4170 LET Z$ = "k"
4180 GOSUB 5090
4190 LET X9 = V
4200 LET Z9 = 0
4210 IF Y0 = 31 THEN 4520
4220 LET Z9 = 2
4230 IF E1$ = "f64" THEN 4520
4240 LET Z9 = 1
4250 GOTO 4520
4260 REM ---- func: the registers of the parameters were checked as fields ----------------------------------
4270 LET M$ = "func inside a function, or after the data records"
4280 IF M8 <> 0 THEN 4910
4290 LET M8 = 1
4300 GOTO 4520
4310 LET M$ = "slot record not directly after func"
4320 IF M8 <> 1 THEN 4910
4330 LET S6 = S6 + 1
4340 LET M$ = "more slots than SEA_LIM_LIR_SLOTS"
4350 IF S6 > S9 THEN 4910
4360 LET Z$ = "align"
4370 GOSUB 5090
4380 LET A1 = 1
4390 IF A1 >= V THEN 4420
4400 LET A1 = A1 * 2
4410 GOTO 4390
4420 LET M$ = "slot alignment " & STR$(V) & " is not a power of two"
4430 IF A1 <> V THEN 4910
4440 GOTO 4520
4450 LET M$ = "endfunc outside a function"
4460 IF M8 = 0 THEN 4910
4470 IF M8 = 3 THEN 4910
4480 LET M$ = "endfunc with open blocks"
4490 IF B1 > 0 THEN 4910
4500 LET M8 = 0
4510 REM ---- next record -------------------------------------------------------------------------------------
4520 IF END #0 THEN 4880
4530 CALL "io_read": 0, L$, L0, P$, E(), E$(), E0
4540 GOTO 1430
4550 REM ---- #end: nothing may be open, nothing may follow ---------------------------------------------------
4560 LET M$ = "#end carries fields"
4570 IF C0 <> 1 THEN 4910
4580 LET D$ = "BAD_TREE"
4590 IF K0 > 3 THEN 4720
4600 LET M$ = "nodes left on the stack at #end"
4610 IF S0 > 0 THEN 4910
4620 LET D$ = "BAD_RECORD"
4630 LET M$ = "no prog record"
4640 IF K0 = 1 THEN 4700
4650 LET M$ = "a function is not closed by end"
4660 IF F7 = 1 THEN 4910
4670 LET M$ = "fd records missing after the last tstruct / trec"
4680 IF X8 > 0 THEN 4910
4690 GOTO 4840
4700 IF D9 = 0 THEN 4910
4710 GOTO 4840
4720 LET D$ = "BAD_RECORD"
4730 LET M$ = "a function is not closed by endfunc"
4740 IF M8 = 1 THEN 4910
4750 IF M8 = 2 THEN 4910
4760 LET M$ = "sub-records of the last fmt or dat are missing"
4770 IF X9 > 0 THEN 4910
4780 LET M$ = "data label d" & STR$(R8) & " is used but only " & STR$(D8) & " are defined"
4790 IF R8 > D8 THEN 4910
4800 REM lir1 numbers data labels by first reference: a label that no instruction uses cannot occur (DESIGN 3.6.2)
4810 LET M$ = "data label d" & STR$(D8) & " is defined but no instruction uses it (lir1 numbers labels by first use; " & STR$(R8) & " are used)"
4820 IF K0 <> 4 THEN 4840
4830 IF R8 < D8 THEN 4910
4840 IF END #0 THEN 4860
4850 CALL "dg_note": P$, "records follow #end"
4860 CALL "io_end": 0, P$, E(), E$(), E0
4870 STOP
4880 CALL "dg_note": P$, "input ends after line " & STR$(L0)
4890 CALL "dg_internal": P$, "TRUNCATED", E(), E$(), E0
4900 REM ---- failure: say where, then the internal error of errors.inc (status 11) ----------------------------
4910 CALL "dg_note": P$, "line " & STR$(L0) & ": " & M$
4920 CALL "dg_note": P$, "record: " & SEG$(L$, 1, 100)
4930 CALL "dg_internal": P$, D$, E(), E$(), E0
4940 REM ---- subroutine: pop the children of the record (pops column); S0 is the stack depth ---------------
4950 LET P1 = 0
4960 FOR W1 = 1 TO R(I0, 5)
4970 LET V = R(I0, 5 + W1)
4980 IF V < 0 THEN 5010
4990 LET P1 = P1 + V
5000 GOTO 5020
5010 LET P1 = P1 + U(-V)
5020 NEXT W1
5030 LET D$ = "BAD_TREE"
5040 LET M$ = "the record pops " & STR$(P1) & " nodes but the stack holds " & STR$(S0)
5050 IF S0 < P1 THEN 4910
5060 LET S0 = S0 - P1
5070 RETURN
5080 REM ---- subroutine: V = the value of the u field named Z$ of the current record ---------------------------
5090 FOR W1 = 1 TO R(I0, 4)
5100 IF F$(R(I0, 3) + W1 - 1) = Z$ THEN 5140
5110 NEXT W1
5120 LET M$ = "validator: record " & R$(I0) & " has no field " & Z$
5130 GOTO 4910
5140 LET V = U(W1)
5150 RETURN
5160 REM ---- subroutine: check the token Z$ of type T1 (optional if O1 = 1) as field J ---------------------------
5170 LET B$ = "field " & F$(B0) & " ('" & Z$ & "')"
5180 LET M$ = B$
5190 IF O1 = 0 THEN 5220
5200 IF Z$ <> "-" THEN 5220
5210 RETURN
5220 IF T1 >= 100 THEN 6460
5230 ON T1 GOTO 5250, 5300, 5340, 5380, 5490, 5510, 5570, 5670, 5750, 5830, 5830, 5830, 5890, 5910, 6070, 6210, 6210, 6210, 6210, 6210, 6210, 6210
5240 REM u: unsigned decimal
5250 CALL "io_u": Z$, V, T
5260 IF T <> 0 THEN 6530
5270 LET U(J) = V
5280 RETURN
5290 REM i: decimal, or hex for |v| >= 1E9
5300 CALL "io_i": Z$, V, K1, L(), T
5310 IF T <> 0 THEN 6530
5320 RETURN
5330 REM f: # and 16 hex digits
5340 CALL "io_f": Z$, L(), T
5350 IF T <> 0 THEN 6530
5360 RETURN
5370 REM s: escaped string; a chk record names an error of errors.inc with phase R
5380 CALL "io_unesc": Z$, 0, R1$, T
5390 IF T <> 0 THEN 6530
5400 IF Y0 <> 50 THEN 5470
5410 IF F$(B0) <> "err" THEN 5470
5420 CALL "dg_find": R1$, E$(), E0, W1
5430 LET M$ = B$ & " is not a name of the error table"
5440 IF W1 = 0 THEN 4910
5450 LET M$ = B$ & " (a chk names a run-time error)"
5460 IF E$(W1, 2) <> "R" THEN 4910
5470 RETURN
5480 REM pos F:L:C and site F:L: the file index must name a #file record
5490 CALL "io_pos": Z$, F1, L1, C1, T
5500 GOTO 5520
5510 CALL "io_site": Z$, F1, L1, T
5520 IF T <> 0 THEN 6530
5530 LET M$ = B$ & " names file " & STR$(F1) & " but the header has " & STR$(N1) & " #file records"
5540 IF F1 >= N1 THEN 4910
5550 RETURN
5560 REM fl: - or the letters l p s z a, each at most once, in this order
5570 IF Z$ = "-" THEN 5650
5580 LET P1 = 0
5590 FOR W1 = 1 TO LEN(Z$)
5600 LET X1 = POS("lpsza", SEG$(Z$, W1, W1))
5610 IF X1 = 0 THEN 6530
5620 IF X1 <= P1 THEN 6530
5630 LET P1 = X1
5640 NEXT W1
5650 RETURN
5660 REM ty: a type id already defined
5670 CALL "io_u": Z$, V, T
5680 IF T <> 0 THEN 6530
5690 LET U(J) = V
5700 LET M$ = B$ & " is not a defined type id (the last is " & STR$(Y9) & ")"
5710 IF V >= 1 THEN 5720
5712 IF R6 = 1 THEN 5730
5714 GOTO 4910
5720 IF V > Y9 THEN 4910
5730 RETURN
5740 REM lid: a local of the current function
5750 CALL "io_u": Z$, V, T
5760 IF T <> 0 THEN 6530
5770 LET U(J) = V
5780 LET M$ = B$ & " is not a local of the function (it has " & STR$(F8) & ")"
5790 IF V < 1 THEN 4910
5795 IF R6 = 1 THEN 5810
5800 IF V > F8 THEN 4910
5810 RETURN
5820 REM fid, cid, iid: numbers from 1 (the tables they name are checked by the passes)
5830 CALL "io_u": Z$, V, T
5840 IF T <> 0 THEN 6530
5850 LET U(J) = V
5860 IF V < 1 THEN 6530
5870 RETURN
5880 REM blk: a block number from 1 (nesting is checked per record)
5890 GOTO 5830
5900 REM lab: d and a number; instructions use labels in order of first reference (lir1)
5910 IF LEN(Z$) < 2 THEN 6530
5920 IF SEG$(Z$, 1, 1) <> "d" THEN 6530
5930 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), V, T
5940 IF T <> 0 THEN 6530
5950 IF V < 1 THEN 6530
5960 LET U(J) = V
5970 IF Y0 = 30 THEN 6050
5980 IF Y0 = 31 THEN 6050
5990 IF Y0 = 34 THEN 6050
5995 IF Y0 = 25 THEN 6050
6000 IF K0 <> 4 THEN 6030
6010 LET M$ = B$ & " is used before d" & STR$(R8 + 1) & " (lir1 numbers labels by first use)"
6020 IF V > R8 + 1 THEN 4910
6030 IF V <= R8 THEN 6050
6040 LET R8 = V
6050 RETURN
6060 REM slot: s and a number; defined in order by slot records, used by instructions
6070 IF LEN(Z$) < 2 THEN 6530
6080 IF SEG$(Z$, 1, 1) <> "s" THEN 6530
6090 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), V, T
6100 IF T <> 0 THEN 6530
6110 IF V < 1 THEN 6530
6120 LET U(J) = V
6130 IF Y0 = 38 THEN 6170
6140 LET M$ = B$ & " names a slot that func has not declared (" & STR$(S6) & " so far)"
6150 IF V > S6 THEN 4910
6160 RETURN
6170 LET M$ = B$ & " where s" & STR$(S6 + 1) & " was expected (slots count from 1)"
6180 IF V <> S6 + 1 THEN 4910
6190 RETURN
6200 REM reg, ri rf rp rx ry rm: a class letter and a number; numbers in order of first appearance
6210 IF LEN(Z$) < 2 THEN 6530
6220 LET X1 = POS("ifpxym", SEG$(Z$, 1, 1))
6230 IF X1 = 0 THEN 6530
6240 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), V, T
6250 IF T <> 0 THEN 6530
6260 IF V < 1 THEN 6530
6270 IF T1 = 16 THEN 6310
6280 IF X1 = T1 - 16 THEN 6310
6290 LET M$ = B$ & " has the wrong register class here"
6300 GOTO 4910
6310 LET M$ = B$ & " has a vector or mask class, which sea.lir1 does not use"
6320 IF K0 <> 4 THEN 6340
6330 IF X1 > 3 THEN 4910
6340 LET M$ = B$ & " is beyond SEA_LIM_LIR_REGS"
6350 IF V > R9 THEN 4910
6360 IF V <= M7 THEN 6420
6370 LET M$ = B$ & " is not the next register (" & STR$(M7 + 1) & " is: numbers follow first appearance)"
6380 IF V <> M7 + 1 THEN 4910
6390 LET M7 = V
6400 LET Q(V) = X1
6410 RETURN
6420 LET M$ = B$ & " was used before with another class"
6430 IF Q(V) <> X1 THEN 4910
6440 RETURN
6450 REM enumeration: a word listed in passes.txt (an elt field is remembered for dat)
6460 LET X1 = T1 - 100
6470 CALL "tb_word": N(), W$(), X1, Z$, W1
6480 IF W1 = 0 THEN 6530
6490 IF F$(B0) <> "elt" THEN 6510
6500 LET E1$ = Z$
6510 RETURN
6520 REM the field is not valid for its type
6530 IF T1 >= 100 THEN 6560
6540 LET M$ = B$ & " is not a valid " & SEG$("u    i    f    s    pos  site fl   ty   lid  fid  cid  iid  blk  lab  slot reg  ri   rf   rp   rx   ry   rm   ", 5 * T1 - 4, 5 * T1)
6550 GOTO 4910
6560 LET M$ = B$ & " is not a word of enumeration " & N$(T1 - 100)
6570 GOTO 4910
6580 REM ---- sea.res: rerr and rtup (DESIGN 3.4.1): declarations, not nodes, never on the tree stack --------
6590 REM T9 body state: 0 nothing yet, 1 rerr / rtup seen, 2 the tree has begun
6600 LET M$ = "rerr is not the first record of the body"
6610 IF T9 <> 0 THEN 4910
6620 LET T9 = 1
6630 LET Z$ = "code"
6640 GOSUB 5090
6650 LET Q1 = V
6660 LET Z$ = "k"
6670 GOSUB 5090
6680 LET Q2 = V
6690 LET M$ = "rerr code " & STR$(Q1) & " is not a code of phase C2 with " & STR$(Q2) & " arguments"
6700 FOR W2 = 1 TO E0
6710 IF E(W2) <> Q1 THEN 6780
6720 IF E$(W2, 2) <> "C2" THEN 4910
6730 LET Q3 = LEN(E$(W2, 4))
6740 IF E$(W2, 4) <> "-" THEN 6760
6750 LET Q3 = 0
6760 IF Q3 <> Q2 THEN 4910
6770 GOTO 4520
6780 NEXT W2
6790 GOTO 4910
6800 LET M$ = "rtup after the tree began"
6810 IF T9 = 2 THEN 4910
6820 LET T9 = 1
6830 LET Z$ = "id"
6840 GOSUB 5090
6850 LET M$ = "rtup id " & STR$(V) & " where " & STR$(Y9 + 1) & " was expected (ids count from 10, in order)"
6860 IF V <> Y9 + 1 THEN 4910
6870 LET Y9 = V
6880 LET Z$ = "n"
6890 GOSUB 5090
6900 LET M$ = "rtup with fewer than 2 components"
6910 IF V < 2 THEN 4910
6920 GOTO 4520
6990 REM ---- soff inside a slay group: a multiple of 8, above the previous one, at most size - 8 ----
7000 LET M$ = "a record other than soff inside a slay group"
7002 IF Y0 <> 26 THEN 4910
7004 LET Z$ = "v"
7006 GOSUB 5090
7008 LET M$ = "soff " & STR$(V) & " is not a multiple of 8, not above the previous soff, or above the slay size - 8"
7010 IF V <> 8 * INT(V / 8) THEN 4910
7012 IF V <= Z7 THEN 4910
7014 IF V > Z6 - 8 THEN 4910
7016 LET Z7 = V
7018 GOTO 3290
7019 REM ---- slay lab size n: n soff records follow ----
7020 LET Z$ = "n"
7022 GOSUB 5090
7024 LET X9 = V
7026 LET Z9 = 3
7028 LET Z$ = "size"
7030 GOSUB 5090
7032 LET Z6 = V
7034 LET Z7 = -1
7036 GOTO 4520
