10 REM ====================================================================================
12 REM seagen_a64 -- Sea pass 4 for arm64-macos: sea.lir -> sea.s (DESIGN 2.1, 3.6, 4.6, 4.8,
14 REM 4.9, 4.9.2). Built as DESIGN 2.6.3: this file and a64data.bas (lines 1-59999), the modules
16 REM io diag tables ralloc, the DATA blocks errors exits consts entries records, 99999 END.
18 REM Reads sea.lir twice: pass A collects every function's parameter and result classes (a
20 REM call needs its callee's, even when it discards the results), pass B writes sea.s. Each
21 REM function is buffered, analysed (validation, the definitions and reads of its registers;
22 REM sweep 2: immediates, fused comparisons, one-branch ifs; sweep 3: the allocator's reference
23 REM walk and the allocation, passes/lib/ralloc.bas) and swept three times: mode 0 counts the
24 REM lines it will need (more than 240000 instructions do not fit the +-1 MiB conditional
25 REM branches: the far form, b.<inverse> 9f / b <label> / 9:), mode 1 writes the code, mode 2
26 REM the cold blocks (_sea_err calls) and the f64 constants (.quad 0x...). Data records are
28 REM copied as read.
30 REM Phase-5 allocator (DESIGN 4.9.2): the linear scan of ralloc over machine registers
32 REM numbered P = n + 1 for xn and n + 33 for dn (25 general, 29 FP allocatable); scratch x15
34 REM x16 x17 and d29 d30 d31 (a spilled operand in position n in scratch n, a spilled
35 REM destination in scratch 1; staged templates on them; x17 / d31 break move cycles).
36 REM Frame, from sp up: [0,A1) outgoing stack arguments and the _sea_err argument slots;
38 REM [A1,A1+A2) the results area of calls; the LIR slots; the spill slots from A3 (slot s at
40 REM A3 + 8(s-1)); the saved callee-saved registers from A4 (table order x19-x28, d8-d15); F9
42 REM the saved address of this function's own results area; A6 bytes in all; the frame record
43 REM above. A7 = the frame (16 + A6, + realignment); A9 = 1: the prologue stack check (DESIGN 4.6).
46 REM Arrays: E E$ errors; X X$ exits; C C$ consts; Y Y$ entries; N N$ W$ R R$ F F$ Z
48 REM passes.txt; K K$ the needed constants (a64data.bas order: K(1) SLOT_SIZE, K(2)
50 REM STACK_LEAF_MAX, K(3) RC_STATIC, K(4) TAG_STR, K(5-8) STR_RC TAG LEN BYTES, K(9-11)
52 REM FMT_NPIECE NCONV PIECES, K(12-20) FP_KIND CONV FLAGS CLS WIDTH PREC TEXT TLEN SIZE,
54 REM K(21-22) FPK_TEXT CONV, K(23-27) FF_LEFT PLUS SPACE ZERO ALT, K(28-30) CLS_I F P,
56 REM K(31-33) SITE_FILE LINE SIZE, K(34) DATA_ALIGN, K(35-37) ESIZE_I64 F64 BOOL, K(38-45)
58 REM LIM_LIR_INSTRS OPERANDS REGS BLOCKS SLOTS IMMS LABELS SITES, K(46) FILE_VERSION, K(47-49)
59 REM SL_SIZE NREF REFS);
60 REM A(row,1) special code, A(row,2) template of each LIR record row; P$ M Q$ T$ templates
62 REM (M: first line, code lines, cold lines, error rows of $C $D, argument slots); V$ cc
64 REM map; U$ inversions; B$ the function's records, O their rows, G their callee, entry or
66 REM error row (other records: 1 = a fused comparison, a one-branch if and its exit/next and
67 REM endif); G$ fields; U u values; L limbs; Q P the source registers and classes, J$ operand
68 REM names (and move sources 3000+j); D the allocator's table (ralloc: D(r,0) the class 1 i,
69 REM 2 f, 3 p, D(r,8) the location); T(r) the record of r's only definition (-1: several); W(r)
70 REM its reads that need a register; J slots (size, align, offset); B blocks (kind 1 loop 2 do
71 REM 3 if, else seen, step register, ind); I open blocks; S sites (file, line), H their hash;
72 REM S$ signatures (name, parameter classes, result classes); H$ #file paths; V helper limbs;
74 REM W also the byte codes of CHANGE outside a function; A$ message argument.
76 REM Scalars: W0 mode (0 count, 1 code, 2 cold, 3 analysis), W1 far, W2 lines counted; F0
78 REM function number; F1 F2 F3 its pos; F4 kind; F5$ name; F6$ F7$ classes; F8 own extra
80 REM results; N0 records; M0 registers; S0 slots; A0 largest alignment; B7 blocks; K7 open
82 REM blocks; L1 leaf; X8 definition site; X9 sites; D9 data section; D8 last label; M9 mains;
83 REM Y3 the entries row of FREE (release calls it); S8 spill slots; C4 C5 a fused comparison
84 REM (1 flags, condition C7$; 2 a test of register C6 against 0), M7 = 1 in a ret's move.
85 REM ====================================================================================
200 DIM E(299), E$(299,5), X(19), X$(19), C(299,4), C$(299), Y(29), Y$(29,5)
205 DIM N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), Z(8)
210 DIM K(60), K$(60), A(399,2), P$(199), M(199,6), Q$(1999), T$(199,2), V$(10,3), U$(30,2)
215 DIM B$(219999), O(219999), G(219999), G$(300), U(40), L(4), Q(200), P(200), J$(320), V(4)
220 DIM D(111110,8), T(99999), J(9999,3), B(9999,4), I(10000), S(49999,2), H(131071), S$(19999,3)
225 DIM H$(100), W(99999), A$(4)
230 FILES "sea.lir"; "sea.s"
235 LET P$ = "seagen_a64"
240 REM ---- own DATA (a64data.bas), read before the generated blocks ------------------------
245 LET K0 = 0
250 READ Z$
255 IF Z$ = "-" THEN 280
260 LET K0 = K0 + 1
265 IF K0 > 60 THEN 9970
270 LET K$(K0) = Z$
275 GOTO 250
280 LET S9$ = "|"
285 READ Z$
290 IF Z$ = "-" THEN 310
295 READ V0
300 LET S9$ = S9$ & Z$ & "=" & STR$(V0) & "|"
305 GOTO 285
310 LET V8 = 0
315 READ Z$
320 IF Z$ = "-" THEN 350
325 LET V8 = V8 + 1
330 IF V8 > 10 THEN 9970
335 LET V$(V8,1) = Z$
340 READ V$(V8,2), V$(V8,3)
345 GOTO 315
350 LET U8 = 0
355 READ Z$
360 IF Z$ = "-" THEN 390
365 LET U8 = U8 + 1
370 IF U8 > 30 THEN 9970
375 LET U$(U8,1) = Z$
380 READ U$(U8,2)
385 GOTO 355
390 LET T7 = 0
395 LET Q8 = 0
400 READ Z$
405 IF Z$ = "-" THEN 495
410 LET T7 = T7 + 1
415 IF T7 > 199 THEN 9970
420 LET P$(T7) = Z$
425 READ T$(T7,1), T$(T7,2)
430 READ V0, V1
435 IF Q8 + V0 + V1 > 1999 THEN 9970
440 LET M(T7,1) = Q8 + 1
445 LET M(T7,2) = V0
450 LET M(T7,3) = V1
455 LET M(T7,6) = 0
460 FOR I5 = 1 TO V0 + V1
465 LET Q8 = Q8 + 1
470 READ Q$(Q8)
475 IF I5 <= V0 THEN 490
477 REM a cold line's $k: argument slot k is used
478 FOR I6 = 0 TO 9
480 IF POS(Q$(Q8), "$" & STR$(I6)) = 0 THEN 486
482 IF I6 + 1 <= M(T7,6) THEN 486
484 LET M(T7,6) = I6 + 1
486 NEXT I6
490 NEXT I5
492 GOTO 400
495 REM ---- the generated blocks (DESIGN 2.6.3), in their canonical order ---------------------
500 CALL "tb_errors": P$, E(), E$(), 299, E0
505 CALL "tb_exits": P$, E(), E$(), E0, X(), X$(), 19, N7
510 CALL "tb_consts": P$, E(), E$(), E0, C(), C$(), 299, C9
515 CALL "tb_entries": P$, E(), E$(), E0, Y(), Y$(), 29, Y9
520 LET Z(1) = 39
525 LET Z(2) = 299
530 LET Z(3) = 399
535 LET Z(4) = 1499
540 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), R(), R$(), F(), F$(), Z()
545 REM the constants this pass needs, as numbers
550 FOR I5 = 1 TO K0
555 CALL "tb_cval": C(), C$(), C9, K$(I5), V0, T
560 IF T = 0 THEN 575
565 LET M$ = "constant " & K$(I5) & " is not in the consts table"
570 GOTO 9975
575 LET K(I5) = V0
580 NEXT I5
585 LET M$ = "a LIR limit is larger than the arrays of seagen_a64"
590 IF K(38) + K(42) + 2 > 219999 THEN 9975
595 IF K(40) > 99999 THEN 9975
600 IF K(41) > 9999 THEN 9975
605 IF K(42) > 9999 THEN 9975
610 IF K(45) > 49999 THEN 9975
612 GOSUB 1400
615 REM the error rows of the templates' cold blocks and of the stack check
620 FOR I5 = 1 TO T7
625 FOR I6 = 1 TO 2
630 LET M(I5, 3 + I6) = 0
635 IF T$(I5,I6) = "-" THEN 660
640 CALL "dg_find": T$(I5,I6), E$(), E0, V0
645 LET M$ = "template error " & T$(I5,I6) & " is not in the error table"
650 IF V0 = 0 THEN 9975
655 LET M(I5, 3 + I6) = V0
660 NEXT I6
665 NEXT I5
670 CALL "dg_find": "STACK_OVERFLOW", E$(), E0, E9
675 LET M$ = "STACK_OVERFLOW is not in the error table"
680 IF E9 = 0 THEN 9975
685 REM every LIR record row: special code, template; O$ = |name=row|... for the lookup
690 LET O$ = "|"
695 FOR I5 = 1 TO Z(7)
700 LET A(I5,1) = 0
705 LET A(I5,2) = 0
710 IF R(I5,1) < 5 THEN 770
712 IF R(I5,1) > 6 THEN 770
715 LET O$ = O$ & R$(I5) & "=" & STR$(I5) & "|"
720 LET V0 = POS(S9$, "|" & R$(I5) & "=")
725 IF V0 = 0 THEN 740
730 LET V1 = POS(S9$, "|", V0 + 1)
735 LET A(I5,1) = VAL(SEG$(S9$, V0 + LEN(R$(I5)) + 2, V1 - 1))
740 LET Z$ = R$(I5)
745 IF Z$ <> "rcount" THEN 755
750 LET Z$ = "rcount0"
755 FOR I6 = 1 TO T7
760 IF P$(I6) <> Z$ THEN 768
765 LET A(I5,2) = I6
768 NEXT I6
770 NEXT I5
775 LET T9 = 0
780 FOR I6 = 1 TO T7
785 IF P$(I6) <> "rcount1" THEN 795
790 LET T9 = I6
795 NEXT I6
800 LET M$ = "template rcount1 missing"
805 IF T9 = 0 THEN 9975
810 REM the phase-4 records retain release mcopy (codes 22-24) are emitted from their templates
815 FOR I5 = 1 TO Z(7)
820 IF A(I5,1) < 22 THEN 840
825 IF A(I5,1) > 24 THEN 840
830 LET M$ = "template " & R$(I5) & " missing"
835 IF A(I5,2) = 0 THEN 9975
840 NEXT I5
845 REM Y3 = the row of the entry FREE, which release calls (DESIGN 4.8, 4.9); 0: checked at a
850 REM release
855 LET Y3 = 0
860 FOR I5 = 1 TO Y9
865 IF Y$(I5,1) <> "FREE" THEN 875
870 LET Y3 = I5
875 NEXT I5
1000 REM ---- pass A: the signature of every function ---------------------------------------
1005 CALL "io_hdr": 1, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), K(46), T$, H$(), 100, N1, L$
1010 IF T$ <> "arm64-macos" THEN 9980
1015 LET L0 = N1 + 3
1020 LET G0 = 0
1025 IF L$ = "#end" THEN 1120
1030 CALL "io_split": L$, G$(), 300, C0
1035 IF C0 < 1 THEN 9990
1040 IF G$(1) <> "func" THEN 1110
1045 IF C0 < 6 THEN 9990
1050 LET G0 = G0 + 1
1052 LET M$ = "more functions than the signature table holds"
1055 IF G0 > 19999 THEN 9975
1060 LET S$(G0,1) = G$(2)
1061 GOSUB 1130
1065 CALL "io_u": G$(5), V0, T
1070 IF T <> 0 THEN 9990
1075 IF 6 + V0 > C0 THEN 9990
1080 LET Z$ = ""
1085 FOR I8 = 1 TO V0
1090 LET Z$ = Z$ & SEG$(G$(5 + I8), 1, 1)
1095 NEXT I8
1097 LET S$(G0,2) = Z$
1099 CALL "io_u": G$(6 + V0), V1, T
1101 IF T <> 0 THEN 9990
1103 IF 6 + V0 + V1 <> C0 THEN 9990
1104 LET Z$ = ""
1105 FOR I8 = 1 TO V1
1106 LET Z$ = Z$ & G$(6 + V0 + I8)
1107 NEXT I8
1108 LET S$(G0,3) = Z$
1110 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
1115 GOTO 1025
1120 RESTORE #1
1122 FOR I8 = 0 TO 131071
1124 LET H(I8) = 0
1126 NEXT I8
1128 GOTO 1200
1130 REM ---- pass A: no two func records share a name (DESIGN 3.6.5); a hash set of them in H,
1131 REM cleared before pass B uses H for the sites
1132 CHANGE G$(2) TO W
1133 LET S5 = 0
1134 FOR I8 = 1 TO W(0)
1135 LET S5 = S5 * 31 + W(I8)
1136 LET S5 = S5 - INT(S5 / 131071) * 131071
1137 NEXT I8
1138 IF H(S5) = 0 THEN 1145
1139 IF S$(H(S5),1) = G$(2) THEN 9990
1140 LET S5 = S5 + 1
1141 IF S5 < 131071 THEN 1138
1142 LET S5 = 0
1143 GOTO 1138
1145 LET H(S5) = G0
1146 RETURN
1200 REM ---- pass B: the code ----------------------------------------------------------------
1205 CALL "io_hdr": 1, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), K(46), T$, H$(), 100, N1, L$
1210 LET L0 = N1 + 3
1215 SCRATCH #2
1220 LET W0 = 1
1225 LET X$ = "// sea.s -- written by seagen_a64 from sea.lir (Sea DESIGN.md 4.8, 4.9)"
1230 GOSUB 9000
1235 LET X$ = ".section __TEXT,__text,regular,pure_instructions"
1240 GOSUB 9010
1245 REM one top-level record per round: a function (buffered to endfunc) or a data record
1250 IF L$ = "#end" THEN 8000
1255 CALL "io_split": L$, G$(), 300, C0
1260 IF C0 < 1 THEN 9990
1265 LET Z$ = G$(1)
1270 GOSUB 9350
1275 IF I0 = 0 THEN 9990
1280 IF Y0 = 1 THEN 1300
1285 IF Y0 = 30 THEN 7000
1290 IF Y0 = 31 THEN 7100
1292 IF Y0 = 34 THEN 7300
1293 IF Y0 = 37 THEN 7455
1295 GOTO 9990
1300 IF D9 <> 0 THEN 9990
1305 GOSUB 3700
1310 LET B$(1) = L$
1315 LET N0 = 1
1320 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
1325 LET N0 = N0 + 1
1330 IF N0 <= 219999 THEN 1345
1335 LET A$(1) = "instructions"
1340 GOTO 9960
1345 LET B$(N0) = L$
1350 IF L$ = "#end" THEN 9990
1355 IF L$ <> "endfunc" THEN 1320
1360 GOSUB 3000
1365 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
1370 GOTO 1250
1400 REM ---- the allocator (passes/lib/ralloc.bas, DESIGN 4.9.2, Decision 60): its table D and the
1401 REM register tables; machine register P = n + 1 for xn, n + 33 for dn
1402 CALL "ra_init": D(), K(40), K(41), 111110, T
1403 LET M$ = "the register table D is smaller than the allocator needs"
1404 IF T <> 0 THEN 9975
1405 REM x9-x14 x8 x0-x7 x19-x28 crossing no call, x19-x28 x9-x14 x8 x0-x7 crossing one
1406 FOR I5 = 0 TO 28
1407 IF I5 = 8 THEN 1416
1408 IF I5 < 8 THEN 1418
1409 IF I5 < 15 THEN 1420
1410 IF I5 < 19 THEN 1424
1411 CALL "ra_tab": D(), I5 + 1, 1, I5 - 3, I5 - 18, 1
1412 GOTO 1424
1416 CALL "ra_tab": D(), 9, 1, 7, 17, 0
1417 GOTO 1424
1418 CALL "ra_tab": D(), I5 + 1, 1, I5 + 8, I5 + 18, 0
1419 GOTO 1424
1420 CALL "ra_tab": D(), I5 + 1, 1, I5 - 8, I5 + 2, 0
1424 NEXT I5
1426 REM d16-d28 d0-d7 d8-d15 crossing no call, d8-d15 (callee-saved) d16-d28 d0-d7 crossing one
1428 FOR I5 = 0 TO 28
1430 IF I5 > 15 THEN 1440
1432 IF I5 > 7 THEN 1436
1433 CALL "ra_tab": D(), I5 + 33, 2, I5 + 14, I5 + 22, 0
1434 GOTO 1442
1436 CALL "ra_tab": D(), I5 + 33, 2, I5 + 14, I5 - 7, 1
1438 GOTO 1442
1440 CALL "ra_tab": D(), I5 + 33, 2, I5 - 15, I5 - 7, 0
1442 NEXT I5
1443 REM the staged templates (DESIGN 4.9.2 "Templates")
1444 LET S7$ = "|idivf|imodf|rcount|ftoi|fmin|fmax|ffloor|fceil|ftrunc|fround|mcopy|"
1446 RETURN
1450 REM ---- FNN$(P) = the name of machine register P (x0-x30, d0-d31) ---------------------------
1452 DEF FNN$(P9)
1454 LET P9$ = "x" & STR$(P9 - 1)
1456 IF P9 < 33 THEN 1460
1458 LET P9$ = "d" & STR$(P9 - 33)
1460 LET FNN$ = P9$
1462 FNEND
1464 REM ---- FNI(R) = 1 if register R's only definition is an li (an immediate candidate) --------
1466 DEF FNI(R6)
1468 LET R7 = 0
1470 IF T(R6) <= 0 THEN 1476
1472 IF A(O(T(R6)),1) <> 4 THEN 1476
1474 LET R7 = 1
1476 LET FNI = R7
1478 FNEND
2000 REM ---- analysis: the definitions (T) and reads (W) of the record's registers (DESIGN 4.9.2
2001 REM "Immediates", fusion): T(r) the record of r's only definition, -1 for several (or a
2002 REM parameter); W(r) its reads
2003 IF J = 1 THEN 2049
2004 IF Y0 = 2 THEN 2049
2005 FOR K2 = 1 TO P0
2006 IF K2 > 1 THEN 2008
2007 IF Y0 = 8 THEN 2009
2008 LET W(Q(K2)) = W(Q(K2)) + 1
2009 NEXT K2
2010 IF D1 = 0 THEN 2018
2011 IF Y0 = 19 THEN 2018
2012 IF Y0 = 20 THEN 2018
2013 IF Y0 = 24 THEN 2017
2014 LET R2 = D1
2015 GOSUB 2040
2016 GOTO 2018
2017 LET W(D1) = W(D1) + 1
2018 IF E1 = 0 THEN 2022
2019 LET R2 = E1
2020 GOSUB 2040
2022 IF Y0 <> 8 THEN 2026
2023 LET R2 = Q(1)
2024 GOSUB 2040
2026 IF Y0 < 19 THEN 2049
2027 IF Y0 > 20 THEN 2049
2028 LET Y4 = Y0 - 15
2029 FOR K2 = 1 TO VAL(G$(Y4 - 1))
2030 LET Z$ = G$(Y4 + K2 - 1)
2031 LET R2 = VAL(SEG$(Z$, 2, LEN(Z$)))
2032 GOSUB 2040
2033 NEXT K2
2034 RETURN
2040 IF T(R2) = 0 THEN 2044
2041 LET T(R2) = -1
2042 RETURN
2044 LET T(R2) = J
2049 RETURN
2100 REM ---- sweep 2: the immediates (W keeps only the reads that need a register), the fused
2101 REM comparisons and the one-branch ifs (G = 1; DESIGN 4.9.2 "Compare and branch fusion")
2102 FOR J = 2 TO N0 - 1
2103 GOSUB 2300
2104 IF Y0 = 2 THEN 2140
2105 IF Q0 = 0 THEN 2108
2106 LET W(Q(Q0)) = W(Q(Q0)) - 1
2108 FOR K2 = 1 TO P0
2109 GOSUB 2650
2110 IF V9 = 0 THEN 2112
2111 LET W(Q(K2)) = W(Q(K2)) - 1
2112 NEXT K2
2113 IF Y0 = 12 THEN 2150
2114 IF Y0 = 13 THEN 2150
2115 IF Y0 <> 0 THEN 2140
2116 REM a comparison read only by the next if/ifz or the condition of the next selection
2117 IF POS("|icmp|fcmp|bnot|", "|" & R$(I0) & "|") = 0 THEN 2140
2118 IF T(D1) <> J THEN 2140
2119 IF W(D1) <> 1 THEN 2140
2120 CALL "io_split": B$(J + 1), J$(), 300, C1
2122 IF C1 < 3 THEN 2140
2124 IF J$(3) <> "i" & STR$(D1) THEN 2140
2126 IF POS("|if|ifz|isel|psel|fsel|", "|" & J$(1) & "|") = 0 THEN 2140
2128 LET G(J) = 1
2140 NEXT J
2142 RETURN
2150 REM an if/ifz without else whose first part is one exit or next: one conditional branch (G
2151 REM = 1 on it and on the exit/next and the endif, which emit nothing)
2152 CALL "io_split": B$(J + 1), J$(), 300, C1
2154 IF C1 <> 2 THEN 2140
2156 IF J$(1) = "exit" THEN 2160
2158 IF J$(1) <> "next" THEN 2140
2160 IF B$(J + 2) <> "endif " & G$(2) THEN 2140
2162 LET G(J) = 1
2164 LET G(J + 1) = 1
2166 LET G(J + 2) = 1
2168 GOTO 2140
2200 REM ---- sweep 3: the allocator's reference walk (passes/lib/API.md, ralloc), then the
2201 REM allocation. Reported: every reference that exists in the code (not an immediate, not an
2202 REM li that is not emitted, not the register of a fused comparison)
2203 FOR I5 = 1 TO LEN(F6$)
2204 CALL "ra_par": D(), I5
2205 NEXT I5
2206 LET C5 = 0
2207 FOR J = 2 TO N0 - 1
2208 GOSUB 2300
2209 LET C4 = C5
2210 LET C5 = 0
2211 IF Y0 = 2 THEN 2290
2212 IF Y0 <> 4 THEN 2214
2213 IF W(D1) = 0 THEN 2290
2214 FOR K2 = 1 TO P0
2215 IF K2 = Q0 THEN 2222
2216 GOSUB 2650
2217 IF V9 = 1 THEN 2222
2218 IF K2 > 1 THEN 2221
2219 IF Y0 = 8 THEN 2222
2220 IF C4 > 0 THEN 2222
2221 CALL "ra_ref": D(), J, Q(K2), 0
2222 NEXT K2
2223 IF C4 <> 2 THEN 2225
2224 CALL "ra_ref": D(), J, C6, 0
2225 IF Y0 <> 24 THEN 2227
2226 CALL "ra_ref": D(), J, D1, 0
2227 IF Y0 = 19 THEN 2232
2228 IF Y0 = 20 THEN 2232
2229 IF Y0 <> 23 THEN 2234
2232 CALL "ra_call": D(), J
2234 IF Y0 <> 0 THEN 2240
2235 IF G(J) = 0 THEN 2240
2236 GOSUB 2700
2237 GOTO 2290
2240 IF D1 = 0 THEN 2246
2241 IF Y0 = 24 THEN 2246
2242 IF Y0 = 19 THEN 2250
2243 IF Y0 = 20 THEN 2250
2244 CALL "ra_ref": D(), J, D1, 1
2246 IF E1 = 0 THEN 2248
2247 CALL "ra_ref": D(), J, E1, 1
2248 IF Y0 <> 8 THEN 2250
2249 CALL "ra_ref": D(), J, Q(1), 1
2250 IF Y0 < 19 THEN 2257
2251 IF Y0 > 20 THEN 2257
2252 LET Y4 = Y0 - 15
2253 FOR K3 = 1 TO VAL(G$(Y4 - 1))
2254 LET Z$ = G$(Y4 + K3 - 1)
2255 CALL "ra_ref": D(), J, VAL(SEG$(Z$, 2, LEN(Z$))), 1
2256 NEXT K3
2257 IF Y0 <> 0 THEN 2260
2258 IF R$(I0) <> "mov" THEN 2290
2259 CALL "ra_hint": D(), J, D1, Q(1), 0
2260 IF Y0 < 8 THEN 2290
2261 IF Y0 > 15 THEN 2290
2262 LET Y7 = VAL(G$(2))
2263 ON Y0 - 7 GOTO 2264,2268,2270,2268,2272,2272,2290,2268
2264 LET K2 = 4
2265 GOSUB 2650
2266 CALL "ra_open": D(), J, Y7, 1, Q(1), Q(4) * (1 - V9)
2267 GOTO 2290
2268 CALL "ra_close": D(), J, Y7
2269 GOTO 2290
2270 CALL "ra_open": D(), J, Y7, 2, 0, 0
2271 GOTO 2290
2272 CALL "ra_open": D(), J, Y7, 3, 0, 0
2290 NEXT J
2292 CALL "ra_end": D(), M0, S8, T
2294 LET M$ = "a block still open after the allocation"
2296 IF T <> 0 THEN 9975
2298 RETURN
2300 REM ---- decode record J: row I0, code Y0, fields (9400), immediates (2400), move kind (2620)
2302 LET I0 = O(J)
2304 LET Y0 = A(I0,1)
2306 CALL "io_split": B$(J), G$(), 300, C0
2308 GOSUB 9400
2310 GOSUB 2400
2312 GOSUB 2620
2314 RETURN
2400 REM ---- the immediate operand of a direct instruction (DESIGN 4.9.2 "Immediates"): Q0 its
2401 REM position (0: none), Q0$ its text, N8 = 1 when the mnemonic takes the opposite sign (add /
2402 REM sub, adds / subs, cmp / cmn). An immediate first operand of a commuting add, a logical
2403 REM operation or a compare moves to the second place (icmp: the condition mirrored)
2404 LET Q0 = 0
2405 LET N8 = 0
2406 IF Y0 <> 0 THEN 2449
2407 LET Z$ = "|" & R$(I0) & "|"
2408 LET Q7 = 1
2409 IF POS("|iadd|isub|padd|iaddc|isubc|icmp|", Z$) > 0 THEN 2416
2410 LET Q7 = 2
2411 IF POS("|iand|ior|ixor|", Z$) > 0 THEN 2416
2412 LET Q7 = 3
2413 IF POS("|ishl|ishr|isar|", Z$) > 0 THEN 2416
2414 IF Z$ <> "|chkb|" THEN 2449
2415 LET Q7 = 4
2416 LET Q6 = 2
2417 IF Q7 < 4 THEN 2419
2418 LET Q6 = 1
2419 GOSUB 2460
2420 IF Q9 = 1 THEN 2440
2421 IF POS("|iadd|iaddc|icmp|iand|ior|ixor|", Z$) = 0 THEN 2449
2422 LET Q6 = 1
2423 GOSUB 2460
2424 IF Q9 = 0 THEN 2449
2425 LET Q6 = Q(1)
2426 LET Q(1) = Q(2)
2427 LET Q(2) = Q6
2428 LET Q6 = 2
2429 LET Y5 = POS("|lt=gt|le=ge|gt=lt|ge=le|", "|" & K1$ & "=")
2430 IF Y5 = 0 THEN 2440
2431 LET K1$ = SEG$("|lt=gt|le=ge|gt=lt|ge=le|", Y5 + 4, Y5 + 5)
2440 LET Q0 = Q6
2441 LET Q0$ = Q9$
2449 RETURN
2460 REM operand Q6 as an immediate of kind Q7 (1 add / sub / cmp, 2 logical, 3 shift, 4 chkb):
2461 REM Q9 = 1 and its text Q9$ when it is one
2462 LET Q9 = 0
2463 IF FNI(Q(Q6)) = 0 THEN 2479
2464 LET R4 = Q(Q6)
2465 GOSUB 2500
2466 ON Q7 GOTO 2468,2470,2472,2475
2468 GOSUB 2520
2469 RETURN
2470 GOSUB 2540
2471 RETURN
2472 IF K9 <> 0 THEN 2479
2473 IF V0 > 63 THEN 2479
2474 GOTO 2476
2475 IF K9 <> 0 THEN 2479
2476 IF V0 < 0 THEN 2479
2477 IF V0 > 4095 THEN 2479
2478 LET Q9 = 1
2479 LET Q9$ = "#" & STR$(V0)
2480 RETURN
2500 REM ---- the value of li register R4 (FNI(R4) = 1): its field H2$; V0 and K9 (0: decimal V0,
2501 REM 1: |v| >= 1E9) and the limbs V() as io_i gives them
2502 LET Z$ = B$(T(R4))
2504 LET H2$ = SEG$(Z$, POS(Z$, " ", 4) + 1, LEN(Z$))
2506 CALL "io_i": H2$, V0, K9, V(), T
2508 RETURN
2520 REM ---- V0 (K9) as the 12-bit immediate of add / sub / cmp, optionally shifted by 12: Q9 = 1,
2521 REM Q9$ "#v" or "#v, lsl #12" of |V0|, N8 = 1 for a negative V0 (the opposite instruction)
2522 LET Q9 = 0
2523 IF K9 <> 0 THEN 2532
2524 LET V1 = ABS(V0)
2525 LET Q9$ = "#" & STR$(V1)
2526 IF V1 <= 4095 THEN 2530
2527 IF V1 <> INT(V1 / 4096) * 4096 THEN 2532
2528 IF V1 > 4095 * 4096 THEN 2532
2529 LET Q9$ = "#" & STR$(V1 / 4096) & ", lsl #12"
2530 LET Q9 = 1
2531 LET N8 = 0
2532 IF Q9 = 0 THEN 2535
2533 IF V0 >= 0 THEN 2535
2534 LET N8 = 1
2535 RETURN
2540 REM ---- the limbs V() as a logical immediate (a 2-64-bit element, repeated, that is a
2541 REM rotated run of ones): Q9 = 1, Q9$ = "#0x" and 16 hex digits. H3$: the bits, lowest first
2542 LET Q9 = 0
2543 LET V1 = V(1) + V(2) + V(3) + V(4)
2544 IF V1 = 0 THEN 2569
2545 IF V1 = 4 * 65535 THEN 2569
2546 LET H3$ = ""
2547 FOR E4 = 4 TO 1 STEP -1
2548 LET E5 = V(E4)
2549 FOR E6 = 1 TO 16
2550 LET H3$ = H3$ & STR$(E5 - 2 * INT(E5 / 2))
2551 LET E5 = INT(E5 / 2)
2552 NEXT E6
2553 NEXT E4
2554 REM E2 = the smallest element size: the bits repeat with period E2 / 2 while it halves
2555 LET E2 = 64
2556 IF SEG$(H3$, 1, 64 - E2 / 2) <> SEG$(H3$, E2 / 2 + 1, 64) THEN 2560
2557 LET E2 = E2 / 2
2558 IF E2 > 2 THEN 2556
2560 LET H4$ = SEG$(H3$, 1, E2) & SEG$(H3$, 1, 1)
2561 LET E5 = 0
2562 LET E6 = POS(H4$, "10")
2563 IF E6 = 0 THEN 2567
2564 LET E5 = E5 + 1
2565 LET E6 = POS(H4$, "10", E6 + 1)
2566 GOTO 2563
2567 IF E5 <> 1 THEN 2569
2568 GOSUB 2575
2569 RETURN
2575 CALL "io_hex": V(), H2$
2576 LET Q9$ = "#0x" & SEG$(H2$, 2, 17)
2577 LET Q9 = 1
2578 RETURN
2620 REM ---- N2 = 1 if the record's operands are read by a parallel move (ret, call, rcall, loop,
2621 REM the staged templates), which takes any li value as an immediate source (DESIGN 4.9.2)
2622 LET N2 = 1
2623 IF Y0 = 8 THEN 2632
2624 IF Y0 = 24 THEN 2632
2625 IF Y0 = 0 THEN 2630
2626 IF Y0 < 18 THEN 2628
2627 IF Y0 <= 20 THEN 2632
2628 LET N2 = 0
2629 RETURN
2630 IF POS(S7$, "|" & R$(I0) & "|") = 0 THEN 2628
2632 RETURN
2650 REM ---- V9 = 1 if operand K2 of a move record (N2 = 1) is an immediate source: its only
2651 REM definition is an li; never a loop's ind, its step only when the closing add encodes it
2652 LET V9 = 0
2653 IF N2 = 0 THEN 2665
2654 IF FNI(Q(K2)) = 0 THEN 2665
2655 IF Y0 <> 8 THEN 2664
2656 IF K2 = 1 THEN 2665
2657 IF K2 < 4 THEN 2664
2658 LET R4 = Q(4)
2659 GOSUB 2500
2660 GOSUB 2520
2661 IF Q9 = 0 THEN 2665
2664 LET V9 = 1
2665 RETURN
2700 REM ---- a fused comparison (G(J) = 1): C5 = 2 when the next record is an if/ifz and the
2701 REM comparison tests against 0 (bnot, icmp eq / ne with the immediate 0): cbz / cbnz on
2702 REM register C6, C7$ = eq (true when it is 0) or ne; otherwise C5 = 1, C7$ the condition
2703 REM after the compare (L-as)
2704 LET C5 = 1
2705 LET C6 = Q(1)
2706 LET C7$ = "eq"
2707 IF R$(I0) = "bnot" THEN 2718
2708 FOR I2 = 1 TO V8
2709 IF V$(I2,1) = K1$ THEN 2712
2710 NEXT I2
2711 GOTO 9990
2712 LET C7$ = V$(I2,2)
2713 IF R$(I0) <> "fcmp" THEN 2715
2714 LET C7$ = V$(I2,3)
2715 IF Q0 <> 2 THEN 2721
2716 IF Q0$ <> "#0" THEN 2721
2717 IF POS("|eq|ne|", "|" & K1$ & "|") = 0 THEN 2721
2718 IF SEG$(B$(J + 1), 1, 3) = "if " THEN 2720
2719 IF SEG$(B$(J + 1), 1, 4) <> "ifz " THEN 2721
2720 LET C5 = 2
2721 RETURN
3000 REM ---- one function: analysis (W0 = 3), layout, sweeps ---------------------------------
3005 LET F0 = F0 + 1
3010 CALL "ra_fn": D()
3025 LET M0 = 0
3030 LET S0 = 0
3035 LET S9 = 0
3040 LET A0 = 16
3045 LET B7 = 0
3050 LET K7 = 0
3055 LET O0 = 0
3060 LET I9 = 0
3065 LET N9 = 0
3070 LET L1 = 1
3075 LET A1 = 0
3080 LET A2 = 0
3085 LET W0 = 3
3090 FOR J = 1 TO N0 - 1
3095 CALL "io_split": B$(J), G$(), 300, C0
3100 IF C0 < 1 THEN 9990
3105 LET Z$ = G$(1)
3110 GOSUB 9350
3115 IF I0 = 0 THEN 9990
3120 LET O(J) = I0
3125 LET G(J) = 0
3130 IF J > 1 THEN 3145
3135 IF Y0 <> 1 THEN 9990
3140 GOTO 3155
3145 IF Y0 = 1 THEN 9990
3150 IF Y0 >= 30 THEN 9990
3155 GOSUB 9400
3160 IF J > 1 THEN 3200
3165 REM the func record: parameter registers and classes, result classes
3170 LET F6$ = ""
3175 FOR I5 = 1 TO P0
3180 LET T(I5) = -1
3182 IF Q(I5) <> I5 THEN 9990
3185 LET F6$ = F6$ & SEG$("ifp", P(I5), P(I5))
3190 NEXT I5
3191 LET F7$ = ""
3192 FOR I5 = 1 TO U(6)
3193 LET F7$ = F7$ & G$(6 + U(4) + I5)
3194 NEXT I5
3195 LET Z6$ = F7$
3196 GOSUB 9630
3197 LET F8 = Z8
3198 IF F4 = 2 THEN 3480
3199 IF P0 + U(6) = 0 THEN 3480
3200 IF Y0 <> 2 THEN 3260
3205 REM a slot: right after func, numbered s1, s2, ...; the alignment a power of two
3210 IF S9 = 1 THEN 9990
3215 IF H1 <> S0 + 1 THEN 9990
3220 LET S0 = H1
3225 IF S0 <= K(42) THEN 3240
3230 LET A$(1) = "slots"
3235 GOTO 9960
3240 LET J(S0,1) = U(2)
3242 LET J(S0,2) = U(3)
3244 LET Y1 = 1
3246 IF Y1 = U(3) THEN 3254
3248 IF Y1 > U(3) THEN 9990
3250 LET Y1 = Y1 * 2
3252 GOTO 3246
3254 IF U(3) <= A0 THEN 3480
3256 LET A0 = U(3)
3258 GOTO 3480
3260 LET S9 = 1
3262 LET N9 = N9 + 1
3264 LET O0 = O0 + C0 - 1 - X5
3266 IF Y0 = 0 THEN 3300
3268 ON Y0 GOTO 9990,9990,9990,3290,3290,9990,3295,3320,3360,3320,3360,3320,3320,3380,3360,3400,3400,3410,3420,3442,3460,3480,3496,3480
3290 LET I9 = I9 + 1
3292 GOTO 3480
3295 IF H1 < 1 THEN 9990
3296 IF H1 > S0 THEN 9990
3297 GOTO 3480
3300 REM an instruction made from a template (rcount: by its incl)
3302 LET T5 = A(I0,2)
3303 IF T5 = 0 THEN 9990
3304 IF R$(I0) <> "rcount" THEN 3309
3305 IF U0 > 1 THEN 9990
3306 IF U0 = 0 THEN 3309
3307 LET T5 = T9
3309 IF R$(I0) <> "mov" THEN 3312
3311 IF D2 <> P(1) THEN 9990
3312 IF R$(I0) <> "chkb" THEN 3314
3313 IF U0 > 1 THEN 9990
3314 IF M(T5,6) * K(1) <= A1 THEN 3316
3315 LET A1 = M(T5,6) * K(1)
3316 LET A$(1) = "labels"
3318 IF H0 > K(44) THEN 9960
3319 GOTO 3620
3320 REM opening a block: numbered in order, pushed
3322 LET Y1 = VAL(G$(2))
3324 IF Y1 <> B7 + 1 THEN 9990
3326 LET B7 = Y1
3328 IF B7 <= K(41) THEN 3334
3330 LET A$(1) = "blocks"
3332 GOTO 9960
3334 LET K7 = K7 + 1
3336 LET I(K7) = B7
3338 LET B(B7,2) = 0
3340 LET B(B7,4) = 0
3342 LET B(B7,1) = 3
3344 IF Y0 <> 10 THEN 3347
3346 LET B(B7,1) = 2
3347 IF Y0 <> 8 THEN 3480
3348 GOSUB 3630
3349 LET B(B7,4) = Q(1)
3350 LET B(B7,3) = Q(4)
3351 GOTO 3480
3360 REM closing: the innermost open block, of the matching kind
3362 LET Y1 = VAL(G$(2))
3364 IF K7 = 0 THEN 9990
3366 IF I(K7) <> Y1 THEN 9990
3368 LET Y2 = 3
3370 IF Y0 <> 9 THEN 3372
3371 LET Y2 = 1
3372 IF Y0 <> 11 THEN 3374
3373 LET Y2 = 2
3374 IF B(Y1,1) <> Y2 THEN 9990
3376 LET K7 = K7 - 1
3378 GOTO 3480
3380 REM else: of the innermost open if or ifz, once
3382 LET Y1 = VAL(G$(2))
3384 IF K7 = 0 THEN 9990
3386 IF I(K7) <> Y1 THEN 9990
3388 IF B(Y1,1) <> 3 THEN 9990
3390 IF B(Y1,2) <> 0 THEN 9990
3392 LET B(Y1,2) = 1
3394 GOTO 3480
3400 REM exit / next: an enclosing loop or do
3401 LET Y1 = VAL(G$(2))
3402 FOR I5 = 1 TO K7
3403 IF I(I5) = Y1 THEN 3406
3404 NEXT I5
3405 GOTO 9990
3406 IF B(Y1,1) = 3 THEN 9990
3407 GOTO 3480
3410 REM ret: the function's result count and classes
3411 IF P0 <> LEN(F7$) THEN 9990
3412 FOR I5 = 1 TO P0
3413 IF SEG$("ifp", P(I5), P(I5)) <> SEG$(F7$, I5, I5) THEN 9990
3414 NEXT I5
3415 GOTO 3480
3420 REM call: the callee's signature (pass A); its extra results need the results area
3421 LET L1 = 0
3422 IF G$(2) = ".main" THEN 9990
3423 FOR I5 = 1 TO G0
3424 IF S$(I5,1) = G$(2) THEN 3427
3425 NEXT I5
3426 GOTO 9990
3427 LET G(J) = I5
3428 LET Z6$ = S$(I5,3)
3429 GOSUB 9630
3430 LET Y6 = 0
3431 IF Z8 = 0 THEN 3435
3432 LET Y6 = 1
3433 IF 8 * Z8 <= A2 THEN 3435
3434 LET A2 = 8 * Z8
3435 LET Z7$ = S$(G(J),2)
3436 LET Y7 = U(2)
3437 LET Y4 = 4
3438 LET Y8 = 0
3439 GOSUB 3550
3440 GOTO 3480
3441 REM rcall: the entry of rt.inc; site S: the site index is one more integer argument
3442 LET L1 = 0
3443 FOR I5 = 1 TO Y9
3444 IF Y$(I5,2) = G$(2) THEN 3447
3445 NEXT I5
3446 GOTO 9990
3447 LET G(J) = I5
3448 LET Y8 = 0
3449 IF Y$(I5,3) <> "S" THEN 3451
3450 LET Y8 = 1
3451 IF Y8 <> X3 THEN 9990
3452 LET Z7$ = Y$(I5,4)
3453 IF Z7$ <> "-" THEN 3455
3454 LET Z7$ = ""
3455 LET Z6$ = Y$(I5,5)
3456 IF Z6$ <> "-" THEN 3458
3457 LET Z6$ = ""
3458 LET M$ = "a runtime entry with results beyond the registers"
3459 GOTO 3462
3460 REM chk: an error of phase R
3461 GOTO 3470
3462 GOSUB 9630
3463 IF Z8 > 0 THEN 9975
3464 LET Y6 = 0
3465 LET Y7 = U(3)
3466 LET Y4 = 5
3467 GOSUB 3550
3468 GOTO 3480
3470 CALL "dg_find": G$(3), E$(), E0, Y1
3471 IF Y1 = 0 THEN 9990
3472 IF E$(Y1,2) <> "R" THEN 9990
3473 LET G(J) = Y1
3474 GOSUB 3600
3475 IF Y2 <> U(4) THEN 9990
3476 IF (P0 - 1) * K(1) <= A1 THEN 3480
3478 LET A1 = (P0 - 1) * K(1)
3480 GOSUB 2000
3481 NEXT J
3482 IF K7 <> 0 THEN 9990
3484 LET A$(1) = "instructions"
3485 IF N9 > K(38) THEN 9960
3486 LET A$(1) = "operands"
3487 IF O0 > K(39) THEN 9960
3488 LET A$(1) = "immediates"
3489 IF I9 > K(43) THEN 9960
3490 GOSUB 2100
3491 GOSUB 2200
3492 GOSUB 3800
3493 GOSUB 3900
3494 RETURN
3496 REM release: its sequence calls the FREE entry, so the function is not a leaf (DESIGN 4.9)
3497 LET L1 = 0
3498 LET M$ = "entry FREE is not in the entries table"
3499 IF Y3 = 0 THEN 9975
3500 GOTO 3480
3550 REM ---- arguments P() against classes Z7$, result registers G$(Y4..) against Z6$ (Y7 of
3551 REM them, or 0); the stack bytes of the arguments (Y6 = 1: x0 holds the results area;
3552 REM Y8 = 1: the site index is one more integer argument) into A1
3553 IF P0 <> LEN(Z7$) THEN 9990
3554 FOR I5 = 1 TO P0
3555 IF SEG$("ifp", P(I5), P(I5)) <> SEG$(Z7$, I5, I5) THEN 9990
3556 NEXT I5
3557 IF Y7 = 0 THEN 3565
3558 IF Y7 <> LEN(Z6$) THEN 9990
3559 FOR I5 = 1 TO Y7
3560 IF SEG$(G$(Y4 + I5 - 1), 1, 1) <> SEG$(Z6$, I5, I5) THEN 9990
3561 NEXT I5
3565 LET G1 = Y6
3566 LET G2 = 0
3567 LET G3 = 0
3568 FOR I5 = 1 TO P0 + Y8
3569 IF I5 > P0 THEN 3575
3570 IF P(I5) <> 2 THEN 3575
3571 LET G2 = G2 + 1
3572 IF G2 <= 8 THEN 3580
3573 LET G3 = G3 + 1
3574 GOTO 3580
3575 LET G1 = G1 + 1
3576 IF G1 <= 8 THEN 3580
3577 LET G3 = G3 + 1
3580 NEXT I5
3582 IF 8 * G3 <= A1 THEN 3586
3584 LET A1 = 8 * G3
3586 RETURN
3600 REM ---- Y2 = the argument slots the args letters of error Y1 need: h two, the others one
3601 REM (DESIGN 2.6.2); a chk names exactly that many (DESIGN 3.6.5, 4.9)
3602 LET Y2 = 0
3604 LET Z$ = E$(Y1,4)
3606 IF Z$ = "-" THEN 3618
3608 FOR I5 = 1 TO LEN(Z$)
3610 LET Y2 = Y2 + 1
3612 IF SEG$(Z$, I5, I5) <> "h" THEN 3616
3614 LET Y2 = Y2 + 1
3616 NEXT I5
3618 RETURN
3620 REM la: the highest data label referenced, L8; the file must define it (checked at #end)
3622 IF R$(I0) <> "la" THEN 3480
3624 IF H0 <= L8 THEN 3480
3626 LET L8 = H0
3628 GOTO 3480
3630 REM a loop: its ind is not the ind of an enclosing loop (the loop writes it at each step)
3632 LET R0 = Q(1)
3634 GOSUB 9660
3636 LET B(B7,1) = 1
3638 RETURN
3700 REM ---- the func record (in G$): name, kind, position --------------------------------
3705 IF C0 < 6 THEN 9990
3710 LET F5$ = G$(2)
3715 CALL "io_pos": G$(4), F1, F2, F3, T
3720 IF T <> 0 THEN 9990
3725 IF F1 >= N1 THEN 9990
3730 LET F4 = 2
3735 IF G$(3) = "fn" THEN 3750
3740 IF G$(3) <> "main" THEN 9990
3745 LET F4 = 1
3750 IF F5$ = ".main" THEN 3790
3755 IF F4 = 1 THEN 9990
3760 REM a fn's name becomes the label Lfn_<name>: letters, digits, _ (LANGUAGE 3.3)
3765 CHANGE F5$ TO W
3770 FOR I5 = 1 TO W(0)
3772 LET Y1 = W(I5)
3774 IF Y1 = 95 THEN 3786
3776 IF Y1 < 48 THEN 9990
3778 IF Y1 <= 57 THEN 3786
3780 IF Y1 < 65 THEN 9990
3782 IF Y1 <= 90 THEN 3786
3783 IF Y1 < 97 THEN 9990
3784 IF Y1 > 122 THEN 9990
3786 NEXT I5
3788 RETURN
3790 IF F4 <> 1 THEN 9990
3792 LET M9 = M9 + 1
3794 IF M9 > 1 THEN 9990
3796 RETURN
3800 REM ---- frame layout (see the header) ---------------------------------------------------
3805 LET Y7 = A1 + A2
3810 FOR I5 = 1 TO S0
3815 LET Y1 = J(I5,2)
3820 LET Y7 = INT((Y7 + Y1 - 1) / Y1) * Y1
3825 LET J(I5,3) = Y7
3830 LET Y7 = Y7 + J(I5,1)
3835 NEXT I5
3840 LET Y7 = INT((Y7 + 7) / 8) * 8
3845 LET A3 = Y7
3850 LET Y7 = Y7 + 8 * S8
3855 LET A4 = Y7
3856 LET Z1$ = ""
3857 GOSUB 4500
3858 LET Y7 = Y7 + 8 * Y1
3862 LET F9 = 0
3864 IF F8 = 0 THEN 3874
3866 LET F9 = Y7
3868 LET Y7 = Y7 + 8
3874 LET A6 = INT((Y7 + 15) / 16) * 16
3876 LET A8 = 0
3878 IF A0 <= 16 THEN 3882
3880 LET A8 = 1
3882 LET A7 = 16 + A6
3884 IF A8 = 0 THEN 3888
3886 LET A7 = A7 + A0 - 16
3888 LET A9 = 0
3890 IF L1 = 0 THEN 3894
3892 IF A7 <= K(2) THEN 3896
3894 LET A9 = 1
3896 RETURN
3900 REM ---- the definition site (DESIGN 4.6, 4.9), then the three sweeps ---------------------
3910 LET X1 = F1
3915 LET X2 = F2
3920 LET W0 = 1
3925 GOSUB 9300
3928 LET X8 = X0
3930 LET W0 = 0
3935 LET W2 = 0
3940 LET W1 = 0
3945 GOSUB 4000
3950 GOSUB 4300
3955 GOSUB 4400
3960 GOSUB 4450
3965 IF W2 <= 250000 THEN 3975
3970 LET W1 = 1
3975 LET W0 = 1
3980 GOSUB 4000
3982 GOSUB 4300
3984 GOSUB 4400
3986 LET W0 = 2
3988 GOSUB 4450
3990 GOSUB 4300
3995 RETURN
4000 REM ---- label, stack check, frame, parameters ---------------------------------------------
4005 LET X$ = "// " & F5$ & " at " & STR$(F1) & ":" & STR$(F2) & ":" & STR$(F3)
4010 GOSUB 9000
4015 LET X$ = ".p2align 2"
4020 GOSUB 9010
4025 IF F4 <> 1 THEN 4050
4030 LET X$ = ".globl _sea_main"
4035 GOSUB 9010
4040 LET X$ = "_sea_main:"
4045 GOTO 4055
4050 LET X$ = "Lfn_" & F5$ & ":"
4055 GOSUB 9000
4060 IF A9 = 0 THEN 4100
4062 REM r = sp - _sea_stack_limit; a borrow (sp below the limit) or r < the frame size, unsigned,
4063 REM is a stack overflow at the definition line; nothing wraps for any frame size (DESIGN 4.6)
4064 LET X$ = "adrp x17, _sea_stack_limit@PAGE"
4066 GOSUB 9010
4068 LET X$ = "ldr x17, [x17, _sea_stack_limit@PAGEOFF]"
4070 GOSUB 9010
4072 LET X$ = "subs x16, sp, x17"
4074 GOSUB 9010
4076 LET Z1$ = "b.lo"
4078 LET Z2$ = ""
4080 LET Z3$ = "L" & STR$(F0) & "_so"
4082 GOSUB 9100
4084 LET Z5 = A7
4086 LET Z5$ = "x17"
4088 GOSUB 9050
4090 LET X$ = "cmp x16, x17"
4092 GOSUB 9010
4094 LET Z1$ = "b.lo"
4095 LET Z2$ = ""
4096 LET Z3$ = "L" & STR$(F0) & "_so"
4097 GOSUB 9100
4100 LET X$ = "stp x29, x30, [sp, #-16]!"
4105 GOSUB 9010
4110 LET X$ = "mov x29, sp"
4115 GOSUB 9010
4120 IF A6 = 0 THEN 4160
4125 IF A6 > 4095 THEN 4140
4130 LET X$ = "sub sp, sp, #" & STR$(A6)
4135 GOTO 4155
4140 LET Z5 = A6
4145 LET Z5$ = "x16"
4150 GOSUB 9050
4152 LET X$ = "sub sp, sp, x16"
4155 GOSUB 9010
4160 IF A8 = 0 THEN 4180
4165 LET X$ = "mov x16, sp"
4170 GOSUB 9010
4175 LET X$ = "and sp, x16, #-" & STR$(A0)
4178 GOSUB 9010
4180 REM the callee-saved registers the function uses (DESIGN 4.9.2 "Calls"), then the parameters
4181 REM from x0-x7 (after the results area), d0-d7 and the stack into their locations: one
4182 REM parallel move (DESIGN 4.9.2 "Moves")
4183 LET Z1$ = "str"
4184 GOSUB 4500
4185 LET G1 = 0
4186 IF F8 = 0 THEN 4192
4187 LET Z1$ = "str"
4188 LET Z2$ = "x0"
4189 LET Z3 = F9
4190 LET Z4$ = "sp"
4191 LET Z0$ = "x16"
4192 IF F8 = 0 THEN 4196
4193 GOSUB 9020
4194 LET G1 = 1
4196 LET G2 = 0
4197 LET G3 = 0
4198 LET M8 = 0
4199 LET M7 = 0
4200 FOR K2 = 1 TO LEN(F6$)
4202 LET M4 = 1
4204 IF SEG$(F6$, K2, K2) = "f" THEN 4212
4206 IF G1 >= 8 THEN 4218
4208 LET M2 = 1 + G1
4209 LET G1 = G1 + 1
4210 GOTO 4224
4212 LET M4 = 2
4213 IF G2 >= 8 THEN 4218
4214 LET M2 = 33 + G2
4215 LET G2 = G2 + 1
4216 GOTO 4224
4218 LET M8 = M8 + 1
4219 LET J$(M8) = "x" & STR$(16 + 8 * G3)
4220 LET G3 = G3 + 1
4222 LET M2 = 3000 + M8
4224 LET M3 = D(K2,8)
4226 IF M3 = 0 THEN 4232
4228 CALL "ra_mv": D(), M2, M3, M4, T
4230 IF T <> 0 THEN 6790
4232 NEXT K2
4234 GOSUB 6700
4295 RETURN
4300 REM ---- the records of the function (slots have no code); modes 0 and 1 replay the saves ----
4302 LET C5 = 0
4303 IF W0 = 2 THEN 4305
4304 CALL "ra_rew": D()
4305 FOR J = 2 TO N0 - 1
4310 IF A(O(J),1) = 2 THEN 4320
4315 GOSUB 5000
4320 NEXT J
4325 RETURN
4400 REM ---- epilogue: every ret branches here ---------------------------------------------------
4405 LET X$ = "L" & STR$(F0) & "_ret:"
4410 GOSUB 9000
4412 LET Z1$ = "ldr"
4414 GOSUB 4500
4415 LET X$ = "mov sp, x29"
4420 GOSUB 9010
4425 LET X$ = "ldp x29, x30, [sp], #16"
4430 GOSUB 9010
4435 LET X$ = "ret"
4440 GOSUB 9010
4445 RETURN
4450 REM ---- the stack check's cold block: _sea_err(STACK_OVERFLOW, definition site) -------------
4455 IF A9 = 0 THEN 4490
4460 LET X$ = "L" & STR$(F0) & "_so:"
4465 GOSUB 9000
4470 LET Z8 = E(E9)
4475 LET X0 = X8
4480 GOSUB 9375
4490 RETURN
4500 REM ---- Z1$ (str, ldr; "" only counts) the callee-saved registers this function uses, 8
4501 REM bytes each from A4 in table order x19-x28, d8-d15 (DESIGN 4.9.2 "Frame"): Y1 of them
4502 LET Y1 = 0
4504 FOR K3 = 1 TO 18
4506 LET P1 = K3 + 19
4508 IF K3 <= 10 THEN 4512
4510 LET P1 = K3 + 30
4512 CALL "ra_used": D(), P1, U1
4514 IF U1 = 0 THEN 4530
4516 IF Z1$ = "" THEN 4528
4518 LET Z2$ = FNN$(P1)
4520 LET Z3 = A4 + 8 * Y1
4521 LET Z4$ = "sp"
4522 LET Z0$ = "x16"
4524 IF Z1$ = "str" THEN 4527
4525 IF P1 > 32 THEN 4527
4526 LET Z0$ = Z2$
4527 GOSUB 9020
4528 LET Y1 = Y1 + 1
4530 NEXT K3
4532 RETURN
5000 REM ---- one record: code (modes 0, 1) and cold part (modes 0, 2) ----------------------------
5005 GOSUB 2300
5010 LET C4 = C5
5015 LET C5 = 0
5020 LET L9$ = "L" & STR$(F0) & "_"
5025 LET M7 = 0
5030 IF Y0 = 0 THEN 5100
5035 ON Y0 GOTO 9990,9990,9990,5300,5350,9990,5400,5450,5500,5550,5600,5650,5650,5700,5750,5800,5850,5900,6000,6200,6400,5100,6500,5100
5100 REM ---- an instruction from its template: staged, special or direct (DESIGN 4.9.2) ---------
5102 LET T5 = A(I0,2)
5104 IF R$(I0) <> "rcount" THEN 5108
5106 IF U0 <> 1 THEN 5108
5107 LET T5 = T9
5108 IF POS(S7$, "|" & R$(I0) & "|") > 0 THEN 6100
5110 IF R$(I0) = "mov" THEN 5250
5112 IF R$(I0) = "chkb" THEN 6300
5114 IF POS("|isel|psel|fsel|", "|" & R$(I0) & "|") > 0 THEN 6350
5116 IF G(J) = 1 THEN 6460
5118 IF W0 = 2 THEN 5200
5120 GOSUB 5150
5122 FOR I6 = M(T5,1) TO M(T5,1) + M(T5,2) - 1
5124 LET Z$ = Q$(I6)
5126 GOSUB 9150
5128 NEXT I6
5130 GOSUB 5185
5132 IF W0 = 1 THEN 5290
5134 GOTO 5200
5150 REM ---- the operand names J$(1..P0) (the immediate, the register, or the scratch register of
5151 REM the position loaded from the spill slot; a load or store: 9800) and the destination's J0$
5152 REM (D7 = its spill slot, 0 if in a register; 5185 stores it)
5153 IF B1 > 0 THEN 5165
5154 FOR K2 = 1 TO P0
5155 LET Z2$ = Q0$
5156 IF K2 = Q0 THEN 5163
5157 LET Z2$ = ""
5158 IF K2 > 1 THEN 5160
5159 IF C4 > 0 THEN 5163
5160 LET R3 = Q(K2)
5161 LET K4 = K2
5162 GOSUB 9720
5163 LET J$(K2) = Z2$
5164 NEXT K2
5165 GOSUB 5170
5166 IF B1 = 0 THEN 5169
5167 GOSUB 9800
5169 RETURN
5170 LET D7 = 0
5171 LET J0$ = ""
5172 IF D1 = 0 THEN 5184
5173 IF G(J) = 1 THEN 5184
5174 LET D6 = D(D1,8)
5175 IF D6 <> 0 THEN 5177
5176 GOTO 5193
5177 IF D6 < 0 THEN 5180
5178 LET J0$ = FNN$(D6)
5179 RETURN
5180 LET D7 = -D6
5181 LET J0$ = "x15"
5182 IF D2 <> 2 THEN 5184
5183 LET J0$ = "d29"
5184 RETURN
5185 IF D7 = 0 THEN 5184
5186 LET Z1$ = "str"
5187 LET Z2$ = J0$
5188 LET Z3 = A3 + 8 * (D7 - 1)
5189 LET Z4$ = "sp"
5190 LET Z0$ = "x16"
5191 GOSUB 9020
5192 RETURN
5193 LET M$ = "a destination without a location"
5194 GOTO 9975
5200 REM ---- the cold part of a template: its cold lines and _sea_err ----------------------------
5205 IF M(T5,4) = 0 THEN 5240
5210 LET X$ = L9$ & "e" & STR$(J) & ":"
5215 GOSUB 9000
5220 FOR I6 = M(T5,1) + M(T5,2) TO M(T5,1) + M(T5,2) + M(T5,3) - 1
5225 LET Z$ = Q$(I6)
5228 GOSUB 9150
5230 NEXT I6
5232 LET Z8 = E(M(T5,4))
5235 GOSUB 9375
5240 IF M(T5,5) = 0 THEN 5290
5242 LET X$ = L9$ & "f" & STR$(J) & ":"
5244 GOSUB 9000
5246 LET Z8 = E(M(T5,5))
5248 GOSUB 9375
5249 GOTO 5290
5250 REM ---- mov: one move step between the two locations (nothing between equal ones) --------
5252 IF W0 = 2 THEN 5290
5254 LET M2 = D(Q(1),8)
5256 LET M3 = D(D1,8)
5258 LET M4 = 1
5260 IF D2 <> 2 THEN 5264
5262 LET M4 = 2
5264 LET M$ = "a mov operand without a location"
5266 IF M2 = 0 THEN 9975
5268 IF M3 = 0 THEN 9975
5270 IF M2 = M3 THEN 5290
5272 GOSUB 6800
5290 RETURN
5300 REM ---- li: the constant into the destination, unless every read takes it as an immediate --
5305 IF W0 = 2 THEN 5290
5310 IF W(D1) = 0 THEN 5290
5315 GOSUB 5170
5320 FOR I1 = 1 TO 4
5325 LET V(I1) = L(I1)
5330 NEXT I1
5335 LET Z5$ = J0$
5340 GOSUB 9060
5345 GOSUB 5185
5348 GOTO 5290
5350 REM ---- lf: the constant is a .quad in the cold part, loaded pc-relative ------------------
5355 LET Y6$ = L9$ & "c" & STR$(J)
5360 IF W0 = 2 THEN 5385
5362 GOSUB 5170
5365 LET X$ = "adrp x16, " & Y6$ & "@PAGE"
5370 GOSUB 9010
5375 LET X$ = "ldr " & J0$ & ", [x16, " & Y6$ & "@PAGEOFF]"
5378 GOSUB 9010
5380 GOSUB 5185
5383 IF W0 = 1 THEN 5290
5385 LET X$ = ".p2align 3"
5388 GOSUB 9010
5390 LET X$ = Y6$ & ":"
5392 GOSUB 9000
5394 LET X$ = ".quad 0x" & SEG$(G$(3), 2, 17)
5396 GOSUB 9010
5398 GOTO 5290
5400 REM ---- sa: the address of a LIR slot --------------------------------------------------------
5405 IF W0 = 2 THEN 5290
5408 GOSUB 5170
5410 LET Y7 = J(H1,3)
5415 IF Y7 > 4095 THEN 5430
5420 LET X$ = "add " & J0$ & ", sp, #" & STR$(Y7)
5425 GOTO 5440
5430 LET Z5 = Y7
5432 LET Z5$ = J0$
5434 GOSUB 9050
5436 LET X$ = "add " & J0$ & ", sp, " & J0$
5440 GOSUB 9010
5445 GOSUB 5185
5449 GOTO 5290
5450 REM ---- loop b ind start last step: one parallel move ind <- start, the hidden count <- last
5451 REM (and the hidden step <- step), then the top (DESIGN 4.9.2 "Moves", "Loop closing")
5452 IF W0 = 2 THEN 5290
5453 LET Y7 = VAL(G$(2))
5454 LET Y6$ = L9$ & STR$(Y7) & "_"
5455 CALL "ra_blk": D(), Y7, C3, S3, B5
5456 LET M8 = 0
5457 LET K2 = 2
5458 LET M3 = D(Q(1),8)
5459 GOSUB 5480
5460 LET K2 = 3
5461 LET M3 = C3
5462 GOSUB 5480
5463 IF S3 = 0 THEN 5467
5464 LET K2 = 4
5465 LET M3 = S3
5466 GOSUB 5480
5467 GOSUB 6700
5468 LET X$ = Y6$ & "top:"
5469 GOSUB 9000
5470 GOTO 5290
5480 REM ---- appends the move of operand K2 (an immediate source J$(tag) or its location) to M3
5481 GOSUB 2650
5482 LET M2 = D(Q(K2),8)
5483 LET M4 = 1
5484 IF D(Q(K2),0) <> 2 THEN 5486
5485 LET M4 = 2
5486 IF V9 = 0 THEN 5492
5487 LET R4 = Q(K2)
5488 GOSUB 2500
5489 LET M8 = M8 + 1
5490 LET J$(M8) = "v" & H2$
5491 LET M2 = 3000 + M8
5492 LET M$ = "a move source without a location"
5493 IF M2 = 0 THEN 9975
5494 CALL "ra_mv": D(), M2, M3, M4, T
5495 IF T <> 0 THEN 6790
5496 RETURN
5500 REM ---- endloop b: ind + step, the count down, the branch to the top (DESIGN 4.9.2, L-ai) ----
5501 IF W0 = 2 THEN 5290
5502 LET Y7 = VAL(G$(2))
5503 LET Y6$ = L9$ & STR$(Y7) & "_"
5504 LET X$ = Y6$ & "next:"
5505 GOSUB 9000
5506 CALL "ra_blk": D(), Y7, C3, S3, B5
5507 LET M$ = "a loop without a count location"
5508 IF C3 = 0 THEN 9975
5509 LET G6$ = "x17"
5510 IF C3 < 0 THEN 5513
5511 LET G6$ = FNN$(C3)
5512 GOTO 5519
5513 LET Z1$ = "ldr"
5514 LET Z2$ = "x17"
5515 LET Z3 = A3 + 8 * (-C3 - 1)
5516 LET Z4$ = "sp"
5517 LET Z0$ = "x17"
5518 GOSUB 9020
5519 IF B5 = 1 THEN 5530
5520 REM ind not read after the loop: add, subs, b.hs (last + 1 runs for every last)
5521 GOSUB 5560
5522 LET X$ = "subs " & G6$ & ", " & G6$ & ", #1"
5523 GOSUB 9010
5524 GOSUB 5620
5525 LET Z1$ = "b.hs"
5526 LET Z2$ = ""
5527 LET Z3$ = Y6$ & "top"
5528 GOSUB 9100
5529 GOTO 5545
5530 REM ind read after the loop: cbz to the exit, sub, add, b
5531 LET Z1$ = "cbz"
5532 LET Z2$ = G6$ & ", "
5533 LET Z3$ = Y6$ & "exit"
5534 GOSUB 9100
5535 LET X$ = "sub " & G6$ & ", " & G6$ & ", #1"
5536 GOSUB 9010
5537 GOSUB 5620
5538 GOSUB 5560
5540 LET X$ = "b " & Y6$ & "top"
5542 GOSUB 9010
5545 LET X$ = Y6$ & "exit:"
5546 GOSUB 9000
5548 GOTO 5290
5550 REM ---- do b: the top label -----------------------------------------------------------------
5552 IF W0 = 2 THEN 5290
5554 LET Y6$ = L9$ & G$(2) & "_"
5556 LET X$ = Y6$ & "top:"
5558 GOSUB 9000
5559 GOTO 5290
5560 REM ---- ind + step of loop Y7 (ind in x15 when spilled, stored back): the step's hidden
5561 REM register S3 (x16 when spilled), the immediate, or the step register (x16 when spilled)
5562 LET R3 = B(Y7,4)
5563 LET K4 = 1
5564 GOSUB 9720
5565 LET G7$ = Z2$
5566 LET G9$ = "add"
5567 IF S3 <> 0 THEN 5582
5568 LET R4 = B(Y7,3)
5569 LET Q9 = 0
5570 IF FNI(R4) = 0 THEN 5573
5571 GOSUB 2500
5572 GOSUB 2520
5573 IF Q9 = 0 THEN 5578
5574 LET G8$ = Q9$
5575 IF N8 = 0 THEN 5590
5576 LET G9$ = "sub"
5577 GOTO 5590
5578 LET R3 = R4
5579 LET K4 = 2
5580 GOSUB 9720
5581 GOTO 5589
5582 LET Z2$ = FNN$(ABS(S3))
5583 IF S3 > 0 THEN 5589
5584 LET Z2$ = "x16"
5585 LET S1 = -S3
5586 GOSUB 9750
5589 LET G8$ = Z2$
5590 LET X$ = G9$ & " " & G7$ & ", " & G7$ & ", " & G8$
5591 GOSUB 9010
5592 IF D(B(Y7,4),8) > 0 THEN 5599
5593 LET Z1$ = "str"
5594 LET Z2$ = "x15"
5595 LET Z3 = A3 + 8 * (-D(B(Y7,4),8) - 1)
5596 LET Z4$ = "sp"
5597 LET Z0$ = "x16"
5598 GOSUB 9020
5599 RETURN
5600 REM ---- enddo b -------------------------------------------------------------------------------
5602 IF W0 = 2 THEN 5290
5604 LET Y6$ = L9$ & G$(2) & "_"
5606 LET X$ = "b " & Y6$ & "top"
5608 GOSUB 9010
5610 LET X$ = Y6$ & "exit:"
5612 GOSUB 9000
5614 GOTO 5290
5620 REM ---- the spilled count back from x17 (str leaves the flags alone) --------------------------
5621 IF C3 > 0 THEN 5629
5622 LET Z1$ = "str"
5623 LET Z2$ = "x17"
5624 LET Z3 = A3 + 8 * (-C3 - 1)
5625 LET Z4$ = "sp"
5626 LET Z0$ = "x16"
5627 GOSUB 9020
5629 RETURN
5650 REM ---- if b c / ifz b c: to the else label when the first part does not run; a one-branch
5651 REM if (G = 1) to its exit / next label when it does (DESIGN 4.9.2 "Compare and branch fusion")
5652 IF W0 = 2 THEN 5290
5653 LET Z3$ = L9$ & G$(2) & "_else"
5654 LET B6 = 1
5655 IF Y0 = 13 THEN 5657
5656 LET B6 = 0
5657 IF G(J) = 0 THEN 5666
5658 CALL "io_split": B$(J + 1), J$(), 300, C1
5659 LET Z3$ = L9$ & J$(2) & "_exit"
5660 IF J$(1) = "exit" THEN 5665
5661 LET Z3$ = L9$ & J$(2) & "_top"
5662 IF B(VAL(J$(2)),1) <> 1 THEN 5665
5663 LET Z3$ = L9$ & J$(2) & "_next"
5665 LET B6 = 1 - B6
5666 REM B6 = 1: branch when the condition holds, 0: when it does not
5667 IF C4 <> 1 THEN 5674
5668 LET Z1$ = "b." & C7$
5669 IF B6 = 1 THEN 5671
5670 GOSUB 9140
5671 LET Z2$ = ""
5672 GOSUB 9100
5673 GOTO 5290
5674 LET R3 = Q(1)
5675 LET G9$ = "ne"
5676 IF C4 <> 2 THEN 5679
5677 LET R3 = C6
5678 LET G9$ = C7$
5679 LET K4 = 1
5680 GOSUB 9720
5681 LET Z2$ = Z2$ & ", "
5682 LET Z1$ = "cbz"
5683 IF G9$ = "eq" THEN 5685
5684 LET B6 = 1 - B6
5685 IF B6 = 1 THEN 5672
5686 LET Z1$ = "cbnz"
5687 GOTO 5672
5700 REM ---- else b -------------------------------------------------------------------------------
5702 IF W0 = 2 THEN 5290
5704 LET Y6$ = L9$ & G$(2) & "_"
5706 LET X$ = "b " & Y6$ & "end"
5708 GOSUB 9010
5710 LET X$ = Y6$ & "else:"
5712 GOSUB 9000
5714 GOTO 5290
5750 REM ---- endif b (the else label too when there was no else; nothing after a one-branch if) --
5752 IF W0 = 2 THEN 5290
5753 IF G(J) = 1 THEN 5290
5754 LET Y7 = VAL(G$(2))
5756 LET Y6$ = L9$ & G$(2) & "_"
5758 IF B(Y7,2) = 1 THEN 5766
5760 LET X$ = Y6$ & "else:"
5762 GOSUB 9000
5766 LET X$ = Y6$ & "end:"
5768 GOSUB 9000
5770 GOTO 5290
5800 REM ---- exit b (nothing in a one-branch if) ------------------------------------------------
5802 IF W0 = 2 THEN 5290
5803 IF G(J) = 1 THEN 5290
5804 LET X$ = "b " & L9$ & G$(2) & "_exit"
5806 GOSUB 9010
5808 GOTO 5290
5850 REM ---- next b: a loop's closing sequence, a do's top (nothing in a one-branch if) -----------
5852 IF W0 = 2 THEN 5290
5853 IF G(J) = 1 THEN 5290
5854 LET Y7 = VAL(G$(2))
5856 LET X$ = "b " & L9$ & G$(2) & "_top"
5858 IF B(Y7,1) <> 1 THEN 5862
5860 LET X$ = "b " & L9$ & G$(2) & "_next"
5862 GOSUB 9010
5864 GOTO 5290
5900 REM ---- ret: one parallel move of the results into x0-x7, d0-d7 and the caller's results
5901 REM area (its address from F9 in x16), then to the epilogue
5902 IF W0 = 2 THEN 5290
5904 IF F8 = 0 THEN 5910
5906 LET Z2$ = "x16"
5907 LET Z3 = F9
5908 LET Z4$ = "sp"
5909 GOSUB 9752
5910 LET M7 = 1
5911 LET M8 = 0
5912 LET G1 = 0
5913 LET G2 = 0
5914 LET G4 = 0
5915 FOR K2 = 1 TO P0
5916 IF P(K2) = 2 THEN 5922
5917 LET M3 = 1 + G1
5918 LET G1 = G1 + 1
5919 IF G1 <= 8 THEN 5928
5920 GOTO 5925
5922 LET M3 = 33 + G2
5923 LET G2 = G2 + 1
5924 IF G2 <= 8 THEN 5928
5925 LET M3 = 2000 + G4
5926 LET G4 = G4 + 1
5928 GOSUB 5480
5930 NEXT K2
5932 GOSUB 6700
5934 LET X$ = "b " & L9$ & "ret"
5936 GOSUB 9010
5938 GOTO 5290
6000 REM ---- call: saves, the argument move, bl, the result move, the loads (DESIGN 4.8, 4.9.2) --
6002 IF W0 = 2 THEN 5290
6004 LET Y7 = G(J)
6006 LET Z6$ = S$(Y7,3)
6008 GOSUB 9630
6010 LET Y4 = 4
6012 LET N5 = VAL(G$(3))
6014 GOSUB 6600
6016 LET M8 = 0
6018 LET G1 = 0
6020 LET G2 = 0
6022 LET G3 = 0
6024 IF Z8 = 0 THEN 6032
6026 LET M8 = 1
6027 LET J$(1) = "a"
6028 CALL "ra_mv": D(), 3001, 1, 1, T
6030 LET G1 = 1
6032 GOSUB 6050
6034 GOSUB 6700
6036 LET X$ = "bl Lfn_" & S$(Y7,1)
6038 GOSUB 9010
6040 GOSUB 6070
6042 GOSUB 6650
6044 GOTO 5290
6050 REM ---- the arguments Q() P() to x<G1>.. d<G2>.. and the stack slots 1000+G3 ..: appended ----
6051 FOR K2 = 1 TO P0
6052 IF P(K2) = 2 THEN 6058
6053 LET M3 = 1 + G1
6054 LET G1 = G1 + 1
6055 IF G1 <= 8 THEN 6064
6056 GOTO 6061
6058 LET M3 = 33 + G2
6059 LET G2 = G2 + 1
6060 IF G2 <= 8 THEN 6064
6061 LET M3 = 1000 + G3
6062 LET G3 = G3 + 1
6064 GOSUB 5480
6066 NEXT K2
6068 RETURN
6070 REM ---- the N5 results G$(Y4 ...) from x0-x7, d0-d7, the results area (2000+j): one move ----
6071 LET G1 = 0
6072 LET G2 = 0
6073 LET G4 = 0
6074 FOR K3 = 1 TO N5
6075 LET Z$ = G$(Y4 + K3 - 1)
6076 LET R3 = VAL(SEG$(Z$, 2, LEN(Z$)))
6077 LET M4 = 1
6078 IF SEG$(Z$, 1, 1) = "f" THEN 6084
6079 LET M2 = 1 + G1
6080 LET G1 = G1 + 1
6081 IF G1 <= 8 THEN 6090
6082 GOTO 6088
6084 LET M4 = 2
6085 LET M2 = 33 + G2
6086 LET G2 = G2 + 1
6087 IF G2 <= 8 THEN 6090
6088 LET M2 = 2000 + G4
6089 LET G4 = G4 + 1
6090 LET M3 = D(R3,8)
6091 LET M$ = "a call result without a location"
6092 IF M3 = 0 THEN 9975
6093 CALL "ra_mv": D(), M2, M3, M4, T
6094 IF T <> 0 THEN 6790
6095 NEXT K3
6096 GOSUB 6700
6098 RETURN
6100 REM ---- a staged template (DESIGN 4.9.2, L-an): the operands into x15 x16 x17 / d29 d30 d31
6101 REM in operand order by class (one parallel move; mcopy's d first), the sequence, the results
6102 REM from x15 (x16) / d29 into their locations (one parallel move)
6103 IF W0 = 2 THEN 5200
6104 LET M8 = 0
6105 LET G1 = 0
6106 LET G2 = 0
6107 IF Y0 <> 24 THEN 6112
6108 LET G1 = 1
6109 CALL "ra_mv": D(), D(D1,8), 16, 1, T
6112 FOR K2 = 1 TO P0
6113 IF P(K2) = 2 THEN 6117
6114 LET G1 = G1 + 1
6115 LET M3 = 15 + G1
6116 GOTO 6119
6117 LET G2 = G2 + 1
6118 LET M3 = 61 + G2
6119 GOSUB 5480
6120 NEXT K2
6122 GOSUB 6700
6124 FOR I6 = M(T5,1) TO M(T5,1) + M(T5,2) - 1
6126 LET Z$ = Q$(I6)
6128 GOSUB 9150
6130 NEXT I6
6132 IF Y0 = 24 THEN 6146
6134 LET M4 = 1
6135 LET M2 = 16
6136 IF D2 <> 2 THEN 6139
6137 LET M4 = 2
6138 LET M2 = 62
6139 CALL "ra_mv": D(), M2, D(D1,8), M4, T
6140 IF E1 = 0 THEN 6144
6142 CALL "ra_mv": D(), 17, D(E1,8), 1, T
6144 GOSUB 6700
6146 IF W0 = 1 THEN 5290
6148 GOTO 5200
6200 REM ---- rcall: saves, the argument move (the site index last for an entry with site S), bl
6201 REM _<symbol>, the result move, the loads
6202 IF W0 = 2 THEN 5290
6204 LET Y7 = G(J)
6206 LET Y4 = 5
6208 LET N5 = VAL(G$(4))
6210 GOSUB 6600
6212 LET M8 = 0
6214 LET G1 = 0
6216 LET G2 = 0
6218 LET G3 = 0
6220 GOSUB 6050
6222 IF X3 = 0 THEN 6236
6224 LET M8 = M8 + 1
6226 LET J$(M8) = "v" & STR$(X0)
6228 LET M3 = 1 + G1
6230 IF G1 < 8 THEN 6234
6232 LET M3 = 1000 + G3
6234 CALL "ra_mv": D(), 3000 + M8, M3, 1, T
6236 GOSUB 6700
6238 LET X$ = "bl _" & Y$(Y7,2)
6240 GOSUB 9010
6242 GOSUB 6070
6244 GOSUB 6650
6246 GOTO 5290
6300 REM ---- chkb idx ext dim: unsigned idx >= ext fails (idx < 0 too); an immediate index 0-4095:
6301 REM cmp ext, #idx / b.ls (DESIGN 4.9.2); the cold block stores idx, dim, ext
6302 IF W0 = 2 THEN 6330
6304 LET R3 = Q(2)
6305 LET K4 = 2
6306 GOSUB 9720
6307 LET G6$ = Z2$
6308 IF Q0 = 1 THEN 6316
6309 LET R3 = Q(1)
6310 LET K4 = 1
6311 GOSUB 9720
6312 LET X$ = "cmp " & Z2$ & ", " & G6$
6313 LET Z1$ = "b.hs"
6314 GOTO 6320
6316 LET X$ = "cmp " & G6$ & ", " & Q0$
6318 LET Z1$ = "b.ls"
6320 GOSUB 9010
6321 LET Z2$ = ""
6322 LET Z3$ = L9$ & "e" & STR$(J)
6323 GOSUB 9100
6324 IF W0 = 1 THEN 5290
6330 LET X$ = L9$ & "e" & STR$(J) & ":"
6331 GOSUB 9000
6332 LET R3 = Q(2)
6333 LET K4 = 2
6334 GOSUB 9720
6335 LET J$(2) = Z2$
6336 IF Q0 = 1 THEN 6341
6337 LET R3 = Q(1)
6338 LET K4 = 1
6339 GOSUB 9720
6340 GOTO 6344
6341 LET X$ = "mov x15, " & Q0$
6342 GOSUB 9010
6343 LET Z2$ = "x15"
6344 LET J$(1) = Z2$
6345 GOTO 5220
6350 REM ---- isel / psel / fsel d c a b: csel / fcsel on the flags of a fused comparison, else of
6351 REM cmp c, #0 (condition ne)
6352 IF W0 = 2 THEN 5290
6354 GOSUB 5150
6356 LET G9$ = C7$
6358 IF C4 = 1 THEN 6364
6360 LET G9$ = "ne"
6361 LET X$ = "cmp " & J$(1) & ", #0"
6362 GOSUB 9010
6364 LET Z1$ = "csel"
6365 IF R$(I0) <> "fsel" THEN 6367
6366 LET Z1$ = "fcsel"
6367 LET X$ = Z1$ & " " & J0$ & ", " & J$(2) & ", " & J$(3) & ", " & G9$
6368 GOSUB 9010
6370 GOSUB 5185
6372 GOTO 5290
6400 REM ---- chk c err site n a...: to the cold block when c <> 0 ---------------------------------
6402 LET Y6$ = L9$ & "e" & STR$(J)
6404 IF W0 = 2 THEN 6430
6406 LET R3 = Q(1)
6408 LET K4 = 1
6410 GOSUB 9720
6416 LET Z1$ = "cbnz"
6418 LET Z2$ = Z2$ & ", "
6420 LET Z3$ = Y6$
6422 GOSUB 9100
6424 IF W0 = 1 THEN 5290
6430 LET X$ = Y6$ & ":"
6432 GOSUB 9000
6434 FOR K2 = 2 TO P0
6436 LET R3 = Q(K2)
6438 LET K4 = 1
6440 GOSUB 9720
6442 LET Z1$ = "str"
6444 LET Z3 = (K2 - 2) * K(1)
6446 LET Z4$ = "sp"
6448 LET Z0$ = "x16"
6450 GOSUB 9020
6452 NEXT K2
6454 LET Z8 = E(G(J))
6456 GOSUB 9375
6458 GOTO 5290
6460 REM ---- a fused icmp / fcmp / bnot: its template's first line sets the flags (C5 = 1), or
6461 REM nothing for a test against 0 read by cbz / cbnz (C5 = 2); 2700
6462 IF W0 = 2 THEN 5290
6464 GOSUB 2700
6466 IF C5 = 2 THEN 5290
6468 GOSUB 5150
6470 LET Z$ = Q$(M(T5,1))
6472 GOSUB 9150
6474 GOTO 5290
6500 REM ---- release a: the count down; at 0 the free path saves, calls FREE with a in x0 and
6501 REM loads (DESIGN 4.9, 4.9.2); a in x15 when spilled, the count in x16
6502 IF W0 = 2 THEN 5290
6504 LET R3 = Q(1)
6506 LET K4 = 1
6508 GOSUB 9720
6510 LET G6$ = Z2$
6512 LET X$ = "ldr x16, [" & G6$ & "]"
6514 GOSUB 9010
6516 LET X$ = "cbz x16, 1f"
6518 GOSUB 9010
6520 LET X$ = "subs x16, x16, #1"
6522 GOSUB 9010
6524 LET X$ = "str x16, [" & G6$ & "]"
6526 GOSUB 9010
6528 LET X$ = "b.ne 1f"
6530 GOSUB 9010
6532 LET N5 = 0
6534 GOSUB 6600
6536 IF G6$ = "x0" THEN 6542
6538 LET X$ = "mov x0, " & G6$
6540 GOSUB 9010
6542 LET X$ = "bl _" & Y$(Y3,2)
6544 GOSUB 9010
6546 GOSUB 6650
6548 LET X$ = "1:"
6550 GOSUB 9000
6552 GOTO 5290
6600 REM ---- the saves of record J (ra_sv): every interval in a caller-saved register crossing it,
6601 REM except the N5 results G$(Y4 ...) (whose save slot, if any, is unused), stored to its
6602 REM save slot; 6650 loads them back
6603 CALL "ra_sv": D(), J, N4, T
6604 LET Z1$ = "str"
6610 FOR I4 = 1 TO N4
6612 CALL "ra_svi": D(), I4, P1, S1, R5
6614 FOR K3 = 1 TO N5
6616 LET Z$ = G$(Y4 + K3 - 1)
6618 IF VAL(SEG$(Z$, 2, LEN(Z$))) = R5 THEN 6630
6620 NEXT K3
6621 IF S1 = 0 THEN 6634
6622 LET Z2$ = FNN$(P1)
6624 IF Z1$ = "ldr" THEN 6628
6626 GOSUB 9760
6627 GOTO 6630
6628 GOSUB 9750
6630 NEXT I4
6632 RETURN
6634 LET M$ = "a call crossed by an interval without a save slot"
6636 GOTO 9975
6650 LET Z1$ = "ldr"
6652 GOTO 6610
6700 REM ---- the listed moves as one parallel move (ra_pm): its steps emitted in order ------------
6702 CALL "ra_pm": D(), M6
6704 FOR M1 = 1 TO M6
6706 CALL "ra_st": D(), M1, M2, M3, M4, M5
6708 GOSUB 6800
6710 NEXT M1
6712 RETURN
6790 LET M$ = "more than 320 moves in one parallel move"
6792 GOTO 9975
6800 REM ---- one move step: source M2, destination M3, class M4 (codes of passes/lib/API.md: 1-64
6801 REM a register, 0 the cycle scratch x17 / d31, -s a spill slot, 1000+j an outgoing stack slot,
6802 REM 2000+j a results-area slot, at x16 in a ret (M7 = 1), 3000+j the source J$(j)): a memory
6803 REM destination from a register directly, from memory or an immediate through x17
6804 IF M3 < 0 THEN 6820
6806 IF M3 >= 1000 THEN 6820
6808 LET N6 = M3
6810 GOSUB 6890
6812 LET Z2$ = N6$
6814 GOTO 6850
6820 LET Z4$ = "sp"
6821 IF M3 >= 0 THEN 6824
6822 LET Z3 = A3 + 8 * (-M3 - 1)
6823 GOTO 6832
6824 LET Z3 = 8 * (M3 - 1000)
6825 IF M3 < 2000 THEN 6832
6826 LET Z3 = A1 + 8 * (M3 - 2000)
6827 IF M7 = 0 THEN 6832
6828 LET Z3 = 8 * (M3 - 2000)
6829 LET Z4$ = "x16"
6830 LET M$ = "a ret with more than 4095 results in the results area"
6831 IF Z3 > 32760 THEN 9975
6832 IF M2 < 0 THEN 6840
6833 IF M2 > 64 THEN 6840
6834 LET N6 = M2
6835 GOSUB 6890
6836 LET Z2$ = N6$
6837 LET Z1$ = "str"
6838 LET Z0$ = "x17"
6839 GOTO 9020
6840 LET G5 = Z3
6841 LET G5$ = Z4$
6842 LET Z2$ = "x17"
6843 GOSUB 6850
6844 LET Z3 = G5
6845 LET Z4$ = G5$
6846 LET Z1$ = "str"
6847 LET Z2$ = "x17"
6848 LET Z0$ = "x16"
6849 GOTO 9020
6850 REM ---- the source M2 into the register Z2$: a register move, a spill or results-area load,
6851 REM an immediate, the results-area address (a), an incoming stack parameter (x<offset>)
6852 IF M2 < 0 THEN 6860
6853 IF M2 >= 2000 THEN 6863
6854 LET N6 = M2
6855 GOSUB 6890
6856 IF N6$ = Z2$ THEN 6899
6857 LET X$ = "mov " & Z2$ & ", " & N6$
6858 IF SEG$(Z2$, 1, 1) <> "d" THEN 9010
6859 LET X$ = "f" & X$
6860 IF M2 >= 0 THEN 9010
6861 LET S1 = -M2
6862 GOTO 9750
6863 IF M2 >= 3000 THEN 6868
6864 LET Z3 = A1 + 8 * (M2 - 2000)
6865 LET Z4$ = "sp"
6866 GOTO 9752
6868 LET Z$ = J$(M2 - 3000)
6869 IF SEG$(Z$, 1, 1) <> "v" THEN 6874
6870 CALL "io_i": SEG$(Z$, 2, LEN(Z$)), V0, K9, V(), T
6871 LET Z5$ = Z2$
6872 GOTO 9060
6874 IF Z$ <> "a" THEN 6884
6875 LET X$ = "add " & Z2$ & ", sp, #" & STR$(A1)
6876 IF A1 <= 4095 THEN 9010
6877 LET Z5 = A1
6878 LET Z5$ = Z2$
6879 GOSUB 9050
6880 LET X$ = "add " & Z2$ & ", sp, " & Z2$
6881 GOTO 9010
6884 LET Z3 = VAL(SEG$(Z$, 2, LEN(Z$)))
6885 LET Z4$ = "x29"
6886 GOTO 9752
6890 REM ---- N6$ = the name of register code N6 of class M4 (0: the cycle scratch x17 / d31) ----
6891 LET N6$ = "x17"
6892 IF M4 <> 2 THEN 6894
6893 LET N6$ = "d31"
6894 IF N6 = 0 THEN 6899
6895 LET N6$ = FNN$(N6)
6899 RETURN
7000 REM ---- data: str lab v -- a static string object (rt.inc SEA_STR_*) ---------------------
7005 GOSUB 7900
7010 GOSUB 9400
7015 IF H0 <> D8 + 1 THEN 9990
7020 LET D8 = H0
7025 CALL "io_unesc": G$(3), 0, R9$, T
7030 IF T <> 0 THEN 9990
7035 LET Z9$ = "Ld" & STR$(H0)
7040 GOSUB 7500
7045 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7050 GOTO 1250
7100 REM ---- data: fmt lab k, then k ftext / fconv -- a pre-parsed format (SEA_FMT_*, SEA_FP_*) -
7105 GOSUB 7900
7110 GOSUB 9400
7115 IF H0 <> D8 + 1 THEN 9990
7120 LET D8 = H0
7125 LET V4 = H0
7130 LET Y7 = U(2)
7135 IF Y7 > 219999 THEN 9990
7140 LET Y8 = 0
7145 FOR I3 = 1 TO Y7
7150 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7155 LET B$(I3) = L$
7160 IF SEG$(L$, 1, 6) <> "fconv " THEN 7170
7165 LET Y8 = Y8 + 1
7170 NEXT I3
7175 LET X$ = ".p2align 3"
7180 GOSUB 9010
7185 LET X$ = "Ld" & STR$(V4) & ":"
7190 GOSUB 9000
7195 LET Z7 = 0
7200 LET Z6 = K(9)
7202 GOSUB 7600
7204 LET X$ = ".quad " & STR$(Y7)
7206 GOSUB 9010
7208 LET Z7 = Z7 + 8
7210 LET Z6 = K(10)
7212 GOSUB 7600
7214 LET X$ = ".quad " & STR$(Y8)
7216 GOSUB 9010
7218 LET Z7 = Z7 + 8
7220 LET Z6 = K(11)
7222 GOSUB 7600
7224 FOR I3 = 1 TO Y7
7226 GOSUB 7700
7228 NEXT I3
7230 REM the bytes of the text pieces
7232 FOR I3 = 1 TO Y7
7234 CALL "io_split": B$(I3), G$(), 300, C0
7236 IF G$(1) <> "ftext" THEN 7250
7238 CALL "io_unesc": G$(2), 0, R9$, T
7240 LET X$ = "Ld" & STR$(V4) & "_t" & STR$(I3) & ":"
7242 GOSUB 9000
7244 GOSUB 7650
7250 NEXT I3
7255 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7260 GOTO 1250
7300 REM ---- data: dat lab elt n, then n dvi / dvf -- a constant buffer, SEA_DATA_ALIGN ---------
7305 GOSUB 7900
7310 GOSUB 9400
7315 IF H0 <> D8 + 1 THEN 9990
7320 LET D8 = H0
7325 LET Y7 = U(3)
7330 LET Y5$ = G$(3)
7335 LET Y6$ = "dvi"
7340 LET Y8 = K(35)
7345 IF Y5$ <> "f64" THEN 7360
7350 LET Y6$ = "dvf"
7355 LET Y8 = K(36)
7360 IF Y5$ <> "bool" THEN 7370
7365 LET Y8 = K(37)
7370 LET M$ = "an element size other than 1 or 8 bytes"
7372 IF Y8 = 1 THEN 7378
7374 IF Y8 <> 8 THEN 9975
7376 IF Y5$ = "bool" THEN 9975
7378 IF Y5$ <> "bool" THEN 7382
7380 IF Y8 <> 1 THEN 9975
7382 LET M$ = "SEA_DATA_ALIGN is not a power of two"
7384 LET Y1 = 0
7386 LET Y2 = 1
7388 IF Y2 >= K(34) THEN 7396
7390 LET Y2 = Y2 * 2
7392 LET Y1 = Y1 + 1
7394 GOTO 7388
7396 IF Y2 <> K(34) THEN 9975
7398 LET X$ = ".p2align " & STR$(Y1)
7400 GOSUB 9010
7402 LET X$ = "Ld" & STR$(H0) & ":"
7404 GOSUB 9000
7406 FOR I3 = 1 TO Y7
7408 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7410 CALL "io_split": L$, G$(), 300, C0
7412 IF C0 < 1 THEN 9990
7414 IF G$(1) <> Y6$ THEN 9990
7416 LET Z$ = G$(1)
7418 GOSUB 9350
7420 GOSUB 9400
7422 IF Y8 = 8 THEN 7434
7424 IF L(1) + L(2) + L(3) <> 0 THEN 9990
7426 IF L(4) > 1 THEN 9990
7428 LET X$ = ".byte " & STR$(L(4))
7430 GOSUB 9010
7432 GOTO 7440
7434 CALL "io_hex": L(), R$
7436 LET X$ = ".quad 0x" & SEG$(R$, 2, 17)
7438 GOSUB 9010
7440 NEXT I3
7445 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7450 GOTO 1250
7455 REM ---- data: slay lab size n, then n soff -- a struct layout descriptor (SEA_SL_*, DESIGN
7456 REM 4.9); the offsets strictly ascending multiples of 8, each at most size - 8 (DESIGN 3.6.5)
7457 GOSUB 7900
7458 GOSUB 9400
7459 IF H0 <> D8 + 1 THEN 9990
7460 LET D8 = H0
7461 LET Y8 = U(2)
7462 LET Y7 = U(3)
7463 LET X$ = ".p2align 3"
7464 GOSUB 9010
7465 LET X$ = "Ld" & STR$(H0) & ":"
7466 GOSUB 9000
7467 LET Z7 = 0
7468 LET Z6 = K(47)
7469 GOSUB 7600
7470 LET X$ = ".quad " & STR$(Y8)
7471 GOSUB 9010
7472 LET Z7 = Z7 + 8
7473 LET Z6 = K(48)
7474 GOSUB 7600
7475 LET X$ = ".quad " & STR$(Y7)
7476 GOSUB 9010
7477 LET Z7 = Z7 + 8
7478 LET Z6 = K(49)
7479 GOSUB 7600
7480 LET V4 = -8
7481 FOR I3 = 1 TO Y7
7482 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7483 CALL "io_split": L$, G$(), 300, C0
7484 IF C0 < 1 THEN 9990
7485 LET Z$ = G$(1)
7486 GOSUB 9350
7487 IF Y0 <> 38 THEN 9990
7488 GOSUB 9400
7489 IF U(1) <= V4 THEN 9990
7490 IF U(1) <> INT(U(1) / 8) * 8 THEN 9990
7491 IF U(1) > Y8 - 8 THEN 9990
7492 LET V4 = U(1)
7493 LET X$ = ".quad " & STR$(V4)
7494 GOSUB 9010
7495 NEXT I3
7496 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7497 GOTO 1250
7500 REM ---- a static string object Z9$ with the bytes R9$ (rt.inc SEA_STR_*, 8-byte aligned) ---
7505 LET X$ = ".p2align 3"
7510 GOSUB 9010
7515 LET X$ = Z9$ & ":"
7520 GOSUB 9000
7525 LET Z7 = 0
7530 LET Z6 = K(5)
7532 GOSUB 7600
7534 LET X$ = ".quad " & STR$(K(3))
7536 GOSUB 9010
7538 LET Z7 = Z7 + 8
7540 LET Z6 = K(6)
7542 GOSUB 7600
7544 LET X$ = ".byte " & STR$(K(4))
7546 GOSUB 9010
7548 LET Z7 = Z7 + 1
7550 LET Z6 = K(7)
7552 GOSUB 7600
7554 LET X$ = ".quad " & STR$(LEN(R9$))
7556 GOSUB 9010
7558 LET Z7 = Z7 + 8
7560 LET Z6 = K(8)
7562 GOSUB 7600
7564 GOSUB 7650
7566 RETURN
7600 REM ---- a field at offset Z6 of a record whose next free byte is Z7: .space the gap ------
7602 LET M$ = "a rt.inc layout whose fields are not in ascending order"
7604 IF Z6 < Z7 THEN 9975
7606 IF Z6 = Z7 THEN 7614
7608 LET X$ = ".space " & STR$(Z6 - Z7)
7610 GOSUB 9010
7612 LET Z7 = Z6
7614 RETURN
7650 REM ---- the bytes of R9$ as .byte lines of 16 ---------------------------------------------
7652 IF LEN(R9$) = 0 THEN 7690
7654 CHANGE R9$ TO W
7656 LET X$ = ""
7658 FOR I2 = 1 TO W(0)
7660 IF LEN(X$) > 0 THEN 7666
7662 LET X$ = ".byte " & STR$(W(I2))
7664 GOTO 7668
7666 LET X$ = X$ & ", " & STR$(W(I2))
7668 IF I2 - INT(I2 / 16) * 16 <> 0 THEN 7676
7670 GOSUB 9010
7672 LET X$ = ""
7676 NEXT I2
7678 IF LEN(X$) = 0 THEN 7690
7680 GOSUB 9010
7690 RETURN
7700 REM ---- piece I3 of the format: B$(I3) is its ftext or fconv record ------------------------
7702 CALL "io_split": B$(I3), G$(), 300, C0
7704 IF C0 < 1 THEN 9990
7706 LET Z$ = G$(1)
7708 GOSUB 9350
7710 IF Y0 = 32 THEN 7716
7712 IF Y0 <> 33 THEN 9990
7716 GOSUB 9400
7718 LET Z7 = 0
7720 IF Y0 = 33 THEN 7800
7722 CALL "io_unesc": G$(2), 0, R9$, T
7724 IF T <> 0 THEN 9990
7726 LET Z6 = K(12)
7728 GOSUB 7600
7730 LET X$ = ".byte " & STR$(K(21))
7732 GOSUB 9010
7734 LET Z7 = Z7 + 1
7736 LET Z6 = K(13)
7738 GOSUB 7600
7740 LET X$ = ".byte 0"
7742 GOSUB 9010
7744 LET Z7 = Z7 + 1
7746 LET Z6 = K(14)
7748 GOSUB 7600
7749 LET X$ = ".byte 0"
7750 GOSUB 9010
7752 LET Z7 = Z7 + 1
7754 LET Z6 = K(15)
7756 GOSUB 7600
7757 LET X$ = ".byte 0"
7758 GOSUB 9010
7760 LET Z7 = Z7 + 1
7762 LET V5 = -1
7764 LET V6 = -1
7766 GOSUB 7860
7768 LET Z6 = K(18)
7770 GOSUB 7600
7772 LET X$ = ".quad Ld" & STR$(V4) & "_t" & STR$(I3)
7774 GOSUB 9010
7776 LET Z7 = Z7 + 8
7778 LET Z6 = K(19)
7780 GOSUB 7600
7782 LET X$ = ".quad " & STR$(LEN(R9$))
7784 GOSUB 9010
7786 LET Z7 = Z7 + 8
7788 LET Z6 = K(20)
7790 GOSUB 7600
7792 RETURN
7800 REM a conversion: letter, flags (fl letters l p s z a -> SEA_FF_*), class, width, precision
7801 GOSUB 7960
7802 LET Y1 = 0
7804 IF G$(2) = "-" THEN 7816
7806 FOR I2 = 1 TO LEN(G$(2))
7808 LET Y1 = Y1 + K(22 + POS("lpsza", SEG$(G$(2), I2, I2)))
7810 NEXT I2
7816 LET Y2 = K(28)
7818 IF G$(6) <> "f" THEN 7822
7820 LET Y2 = K(29)
7822 IF G$(6) <> "p" THEN 7826
7824 LET Y2 = K(30)
7826 LET V5 = -1
7828 IF G$(3) = "-" THEN 7832
7830 LET V5 = VAL(G$(3))
7832 LET V6 = -1
7834 IF G$(4) = "-" THEN 7838
7836 LET V6 = VAL(G$(4))
7838 LET Z6 = K(12)
7840 GOSUB 7600
7842 LET X$ = ".byte " & STR$(K(22))
7844 GOSUB 9010
7846 LET Z7 = Z7 + 1
7848 LET Z6 = K(13)
7850 GOSUB 7600
7852 LET X$ = ".byte " & STR$(ASC(G$(5)))
7854 GOSUB 9010
7856 LET Z7 = Z7 + 1
7857 GOTO 7880
7860 REM width V5 and precision V6 (i32 each)
7862 LET Z6 = K(16)
7864 GOSUB 7600
7866 LET X$ = ".long " & STR$(V5)
7868 GOSUB 9010
7870 LET Z7 = Z7 + 4
7872 LET Z6 = K(17)
7874 GOSUB 7600
7875 LET X$ = ".long " & STR$(V6)
7876 GOSUB 9010
7877 LET Z7 = Z7 + 4
7878 RETURN
7880 LET Z6 = K(14)
7881 GOSUB 7600
7882 LET X$ = ".byte " & STR$(Y1)
7883 GOSUB 9010
7884 LET Z7 = Z7 + 1
7885 LET Z6 = K(15)
7886 GOSUB 7600
7887 LET X$ = ".byte " & STR$(Y2)
7888 GOSUB 9010
7889 LET Z7 = Z7 + 1
7890 GOSUB 7860
7891 LET Z6 = K(18)
7892 GOSUB 7600
7893 LET X$ = ".quad 0"
7894 GOSUB 9010
7895 LET Z7 = Z7 + 8
7896 LET Z6 = K(19)
7897 GOSUB 7600
7898 LET X$ = ".quad 0"
7899 GOTO 7784
7900 REM ---- the data section starts at the first data record --------------------------------
7902 LET W0 = 1
7904 IF D9 = 1 THEN 7914
7906 LET D9 = 1
7908 LET X$ = ".section __DATA,__const"
7910 GOSUB 9010
7914 RETURN
7960 REM ---- fconv: class p exactly for %s, i or f for the numeric conversions (DESIGN 3.6.5) --
7962 IF G$(5) <> "s" THEN 7968
7964 IF G$(6) <> "p" THEN 9990
7966 RETURN
7968 IF G$(6) = "p" THEN 9990
7970 RETURN
8000 REM ---- #end: the #file strings and _sea_sites (rt.inc SEA_SITE_*) ------------------------
8005 CALL "io_end": 1, P$, E(), E$(), E0
8010 IF M9 <> 1 THEN 9990
8012 IF L8 > D8 THEN 9990
8015 GOSUB 7900
8020 FOR I4 = 1 TO N1
8025 LET Z9$ = "Lsf" & STR$(I4 - 1)
8030 LET R9$ = H$(I4)
8035 GOSUB 7500
8040 NEXT I4
8045 LET X$ = ".globl _sea_sites"
8050 GOSUB 9010
8055 LET X$ = ".p2align 3"
8060 GOSUB 9010
8065 LET X$ = "_sea_sites:"
8070 GOSUB 9000
8075 FOR I4 = 1 TO X9
8080 LET Z7 = 0
8085 LET Z6 = K(31)
8090 GOSUB 7600
8095 LET X$ = ".quad Lsf" & STR$(S(I4,1))
8100 GOSUB 9010
8105 LET Z7 = Z7 + 8
8110 LET Z6 = K(32)
8115 GOSUB 7600
8120 LET X$ = ".quad " & STR$(S(I4,2))
8125 GOSUB 9010
8130 LET Z7 = Z7 + 8
8135 LET Z6 = K(33)
8140 GOSUB 7600
8145 NEXT I4
8150 GOTO 99999
9000 REM ---- emit X$ (mode 0: count it); 9010: indented ---------------------------------------
9002 IF W0 = 0 THEN 9006
9004 PRINT #2, X$
9005 RETURN
9006 LET W2 = W2 + 1
9007 IF POS(X$, ".quad") = 0 THEN 9009
9008 LET W2 = W2 + 1
9009 RETURN
9010 LET X$ = "    " & X$
9012 GOTO 9002
9020 REM ---- Z1$ Z2$, [Z4$, #Z3]: a load or store of 8 bytes at Z4$ + Z3 (Z3 >= 0); an offset
9021 REM beyond the scaled form goes through the general register Z0$: [Z4$, Z0$]
9022 IF Z3 > 32760 THEN 9036
9024 IF Z3 <> INT(Z3 / 8) * 8 THEN 9036
9026 IF Z3 = 0 THEN 9032
9028 LET X$ = Z1$ & " " & Z2$ & ", [" & Z4$ & ", #" & STR$(Z3) & "]"
9030 GOTO 9010
9032 LET X$ = Z1$ & " " & Z2$ & ", [" & Z4$ & "]"
9034 GOTO 9010
9036 LET Z5 = Z3
9038 LET Z5$ = Z0$
9040 GOSUB 9050
9042 LET X$ = Z1$ & " " & Z2$ & ", [" & Z4$ & ", " & Z0$ & "]"
9044 GOTO 9010
9050 REM ---- Z5$ = Z5 (an integer 0 <= Z5 < 2^53); 9060: Z5$ = the limbs V(1..4) ---------------
9052 LET V5 = Z5
9053 FOR I1 = 4 TO 1 STEP -1
9054 LET V(I1) = V5 - INT(V5 / 65536) * 65536
9055 LET V5 = INT(V5 / 65536)
9056 NEXT I1
9060 LET V6 = 0
9061 LET V7 = 0
9062 FOR I1 = 1 TO 4
9063 IF V(I1) <> 0 THEN 9065
9064 LET V6 = V6 + 1
9065 IF V(I1) <> 65535 THEN 9067
9066 LET V7 = V7 + 1
9067 NEXT I1
9068 IF V7 > V6 THEN 9084
9070 LET X$ = "movz " & Z5$ & ", #" & STR$(V(4))
9071 GOSUB 9010
9072 FOR I1 = 3 TO 1 STEP -1
9073 IF V(I1) = 0 THEN 9076
9074 LET X$ = "movk " & Z5$ & ", #" & STR$(V(I1)) & ", lsl #" & STR$(16 * (4 - I1))
9075 GOSUB 9010
9076 NEXT I1
9077 RETURN
9084 LET X$ = "movn " & Z5$ & ", #" & STR$(65535 - V(4))
9085 GOSUB 9010
9086 FOR I1 = 3 TO 1 STEP -1
9087 IF V(I1) = 65535 THEN 9090
9088 LET X$ = "movk " & Z5$ & ", #" & STR$(V(I1)) & ", lsl #" & STR$(16 * (4 - I1))
9089 GOSUB 9010
9090 NEXT I1
9091 RETURN
9100 REM ---- conditional branch Z1$ Z2$Z3$ (Z2$ = "x9, " for cbz / cbnz); far: inverted over b --
9102 IF W1 = 1 THEN 9110
9104 LET X$ = Z1$ & " " & Z2$ & Z3$
9106 GOTO 9010
9110 FOR I1 = 1 TO U8
9112 IF U$(I1,1) = Z1$ THEN 9120
9114 NEXT I1
9116 LET M$ = "no inversion for the branch " & Z1$
9118 GOTO 9975
9120 LET X$ = U$(I1,2) & " " & Z2$ & "9f"
9122 GOSUB 9010
9124 LET X$ = "b " & Z3$
9126 GOSUB 9010
9128 LET X$ = "9:"
9130 GOTO 9000
9140 REM ---- Z1$ = the inverse of the conditional branch Z1$ (U$; L-as: it holds when unordered) --
9141 FOR I1 = 1 TO U8
9142 IF U$(I1,1) = Z1$ THEN 9146
9143 NEXT I1
9144 LET M$ = "no inversion for the branch " & Z1$
9145 GOTO 9975
9146 LET Z1$ = U$(I1,2)
9147 RETURN
9150 REM ---- one template line Z$: placeholders replaced; a branch to $C / $D through 9100 -------
9152 LET R$ = ""
9153 LET N3 = 0
9154 LET Y1 = 1
9156 LET Y2 = POS(Z$, "$", Y1)
9158 IF Y2 = 0 THEN 9170
9160 LET R$ = R$ & SEG$(Z$, Y1, Y2 - 1)
9162 LET Y3$ = SEG$(Z$, Y2 + 1, Y2 + 1)
9164 LET Y1 = Y2 + 2
9166 GOSUB 9200
9168 GOTO 9156
9170 LET R$ = R$ & SEG$(Z$, Y1, LEN(Z$))
9171 IF N3 = 0 THEN 9173
9172 GOSUB 9280
9173 LET Y3$ = SEG$(Z$, LEN(Z$) - 1, LEN(Z$))
9174 IF Y3$ = "$C" THEN 9184
9176 IF Y3$ = "$D" THEN 9184
9178 LET X$ = R$
9180 IF SEG$(R$, LEN(R$), LEN(R$)) = ":" THEN 9000
9182 GOTO 9010
9184 LET Y2 = POS(R$, " ")
9186 LET Z1$ = SEG$(R$, 1, Y2 - 1)
9188 LET Z3$ = L9$ & "e" & STR$(J)
9190 IF Y3$ = "$C" THEN 9194
9192 LET Z3$ = L9$ & "f" & STR$(J)
9194 LET Z2$ = SEG$(R$, Y2 + 1, LEN(R$) - LEN(Z3$))
9196 GOTO 9100
9200 REM ---- the value of placeholder Y3$, appended to R$ ------------------------------------
9201 IF POS("dabcwx", Y3$) > 0 THEN 9253
9202 IF Y3$ <> "C" THEN 9206
9204 LET R$ = R$ & L9$ & "e" & STR$(J)
9205 RETURN
9206 IF Y3$ <> "D" THEN 9210
9208 LET R$ = R$ & L9$ & "f" & STR$(J)
9209 RETURN
9210 IF Y3$ <> "M" THEN 9214
9212 LET R$ = R$ & M$
9213 RETURN
9214 IF Y3$ <> "L" THEN 9218
9216 LET R$ = R$ & "Ld" & STR$(H0)
9217 RETURN
9218 IF Y3$ <> "U" THEN 9222
9220 LET R$ = R$ & STR$(U0)
9221 RETURN
9222 IF Y3$ <> "S" THEN 9226
9224 LET R$ = R$ & STR$(X0)
9225 RETURN
9226 LET Y5 = 2
9228 IF Y3$ = "K" THEN 9236
9230 LET Y5 = 3
9232 IF Y3$ = "F" THEN 9236
9234 GOTO 9244
9236 FOR I2 = 1 TO V8
9238 IF V$(I2,1) = K1$ THEN 9242
9240 NEXT I2
9241 GOTO 9990
9242 LET R$ = R$ & V$(I2,Y5)
9243 RETURN
9244 LET Y5 = POS("0123456789", Y3$)
9245 LET M$ = "unknown template placeholder $" & Y3$
9246 IF Y5 = 0 THEN 9975
9247 LET R$ = R$ & STR$((Y5 - 1) * K(1))
9248 RETURN
9250 REM ---- the operand placeholders: $d the destination J0$, $a $b $c the operands J$(1..3), $w
9251 REM $x the 32-bit names of the destination and of the first operand; an immediate $b of the
9252 REM opposite sign (N8) turns the mnemonic (N3, 9280)
9253 LET Y5 = POS("dabcwx", Y3$)
9254 IF Y5 > 1 THEN 9257
9255 LET R$ = R$ & J0$
9256 RETURN
9257 IF Y5 > 4 THEN 9264
9258 LET R$ = R$ & J$(Y5 - 1)
9259 IF Y5 <> 3 THEN 9256
9260 IF Q0 <> 2 THEN 9256
9261 IF N8 = 0 THEN 9256
9262 LET N3 = 1
9263 RETURN
9264 LET Y6 = Y5 - 5
9265 LET Z9$ = J0$
9266 IF Y6 = 0 THEN 9268
9267 LET Z9$ = J$(1)
9268 LET R$ = R$ & "w" & SEG$(Z9$, 2, LEN(Z9$))
9269 RETURN
9280 REM the opposite instruction of an add / sub / cmp with a negative immediate
9281 LET Y2 = POS(R$, " ")
9282 LET Z1$ = SEG$(R$, 1, Y2 - 1)
9283 LET Y5 = POS("|add=sub|sub=add|adds=subs|subs=adds|cmp=cmn|", "|" & Z1$ & "=")
9284 LET M$ = "no opposite instruction for " & Z1$
9285 IF Y5 = 0 THEN 9975
9286 LET Y6 = POS("|add=sub|sub=add|adds=subs|subs=adds|cmp=cmn|", "|", Y5 + 1)
9287 LET R$ = SEG$("|add=sub|sub=add|adds=subs|subs=adds|cmp=cmn|", Y5 + LEN(Z1$) + 2, Y6 - 1) & SEG$(R$, Y2, LEN(R$))
9288 RETURN
9300 REM ---- X0 = the index of site X1:X2 in _sea_sites; added in mode 1 (first occurrence) ----
9302 LET S5 = X1 * 1E9 + X2
9304 LET S6 = S5 - INT(S5 / 131071) * 131071
9306 IF H(S6) = 0 THEN 9324
9308 LET S7 = H(S6)
9310 IF S(S7,1) <> X1 THEN 9318
9312 IF S(S7,2) <> X2 THEN 9318
9314 LET X0 = S7 - 1
9316 RETURN
9318 LET S6 = S6 + 1
9320 IF S6 < 131071 THEN 9306
9322 LET S6 = 0
9323 GOTO 9306
9324 IF W0 = 1 THEN 9334
9326 LET M$ = "a site missing from the site table"
9328 IF W0 = 2 THEN 9975
9330 LET X0 = 0
9332 RETURN
9334 LET X9 = X9 + 1
9336 IF X9 <= K(45) THEN 9342
9338 LET A$(1) = "sites"
9340 GOTO 9960
9342 LET S(X9,1) = X1
9344 LET S(X9,2) = X2
9346 LET H(S6) = X9
9348 LET X0 = X9 - 1
9349 RETURN
9350 REM ---- I0 = the LIR record row of opcode Z$ (0: none), Y0 its special code ----------------
9352 LET I0 = 0
9354 LET Y0 = 0
9356 IF POS(Z$, "|") > 0 THEN 9370
9358 IF POS(Z$, "=") > 0 THEN 9370
9360 LET Y1 = POS(O$, "|" & Z$ & "=")
9362 IF Y1 = 0 THEN 9370
9364 LET Y2 = POS(O$, "|", Y1 + 1)
9366 LET I0 = VAL(SEG$(O$, Y1 + LEN(Z$) + 2, Y2 - 1))
9368 LET Y0 = A(I0,1)
9370 RETURN
9375 REM ---- cold tail: _sea_err(Z8, site X0, slots at sp) ------------------------------------
9377 LET Z5 = Z8
9379 LET Z5$ = "x0"
9381 GOSUB 9050
9383 LET Z5 = X0
9385 LET Z5$ = "x1"
9387 GOSUB 9050
9389 LET X$ = "mov x2, sp"
9391 GOSUB 9010
9393 LET X$ = "bl _sea_err"
9395 GOTO 9010
9400 REM ---- the fields of G$(1..C0) against record row I0 (DESIGN 3.1, passes.txt): checks, ----
9401 REM registers (D1 D2 the destination d, E1 a second destination e, Q P J$ the sources, B1 B2
9402 REM base / idx), site X0, cc K1$, first u U0, scale U2, off limbs L() (O1 = 1 if not 0),
9403 REM label H0, slot H1, site fields X5
9404 LET T0 = 1
9406 LET P0 = 0
9408 LET D1 = 0
9409 LET E1 = 0
9410 LET D2 = 0
9412 LET B1 = 0
9414 LET B2 = 0
9416 LET X3 = 0
9418 LET X0 = 0
9419 LET X5 = 0
9420 LET U0 = -1
9422 LET U2 = 0
9424 LET O1 = 0
9426 LET H0 = 0
9428 LET H1 = 0
9430 LET K1$ = ""
9432 FOR J1 = 1 TO R(I0,4)
9434 LET J2 = R(I0,3) + J1 - 1
9436 LET U(J1) = 0
9438 LET X4 = 1
9440 IF F(J2,3) = 0 THEN 9444
9442 LET X4 = U(F(J2,3))
9444 FOR J3 = 1 TO X4
9446 LET T0 = T0 + 1
9448 IF T0 > C0 THEN 9990
9450 LET Z$ = G$(T0)
9452 LET T1 = F(J2,1)
9453 GOSUB 9680
9454 IF Z$ <> "-" THEN 9458
9456 IF F(J2,2) = 1 THEN 9540
9458 IF T1 >= 100 THEN 9524
9460 ON T1 GOTO 9462,9474,9484,9540,9488,9494,9504,9990,9990,9990,9990,9990,9508,9512,9518,9530,9530,9530,9530,9990,9990,9990
9462 CALL "io_u": Z$, V0, T
9464 IF T <> 0 THEN 9990
9466 LET U(J1) = V0
9468 IF F$(J2) <> "scale" THEN 9471
9470 LET U2 = V0
9471 IF U0 >= 0 THEN 9540
9472 LET U0 = V0
9473 GOTO 9540
9474 CALL "io_i": Z$, V0, K9, L(), T
9476 IF T <> 0 THEN 9990
9478 IF F$(J2) <> "off" THEN 9540
9480 IF L(1) + L(2) + L(3) + L(4) = 0 THEN 9540
9482 LET O1 = 1
9483 GOTO 9540
9484 CALL "io_f": Z$, L(), T
9486 IF T <> 0 THEN 9990
9487 GOTO 9540
9488 CALL "io_pos": Z$, V0, V1, V2, T
9490 IF T <> 0 THEN 9990
9492 IF V0 >= N1 THEN 9990
9493 GOTO 9540
9494 CALL "io_site": Z$, X1, X2, T
9496 IF T <> 0 THEN 9990
9498 IF X1 >= N1 THEN 9990
9500 LET X3 = 1
9502 GOSUB 9300
9503 GOTO 9540
9504 GOSUB 9600
9506 GOTO 9540
9508 CALL "io_u": Z$, V0, T
9509 IF T <> 0 THEN 9990
9510 IF V0 < 1 THEN 9990
9511 GOTO 9540
9512 IF SEG$(Z$, 1, 1) <> "d" THEN 9990
9514 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), H0, T
9515 IF T <> 0 THEN 9990
9516 IF H0 < 1 THEN 9990
9517 GOTO 9540
9518 IF SEG$(Z$, 1, 1) <> "s" THEN 9990
9520 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), H1, T
9522 IF T <> 0 THEN 9990
9523 GOTO 9540
9524 CALL "tb_word": N(), W$(), T1 - 100, Z$, V0
9526 IF V0 = 0 THEN 9990
9527 IF F$(J2) <> "cc" THEN 9540
9528 LET K1$ = Z$
9529 GOTO 9540
9530 GOSUB 9550
9531 IF F$(J2) = "e" THEN 9546
9532 IF F$(J2) <> "d" THEN 9536
9533 LET D1 = R0
9534 LET D2 = R1
9535 GOTO 9547
9536 LET P0 = P0 + 1
9537 LET Q(P0) = R0
9538 LET P(P0) = R1
9539 GOSUB 9590
9540 NEXT J3
9542 NEXT J1
9544 IF T0 = C0 THEN 9549
9545 GOTO 9990
9546 LET E1 = R0
9547 GOSUB 9660
9548 GOTO 9540
9549 RETURN
9550 REM ---- the register Z$ of field type T1 (16 reg, 17 ri, 18 rf, 19 rp): R0 number, R1 class
9551 REM (1 i, 2 f, 3 p); one class per register (D(r,0)); a new one is M0 + 1, the highest (DESIGN 3.6.1)
9552 LET R1 = POS("ifp", SEG$(Z$, 1, 1))
9554 IF R1 = 0 THEN 9990
9556 IF T1 = 16 THEN 9560
9558 IF R1 <> T1 - 16 THEN 9990
9560 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), R0, T
9562 IF T <> 0 THEN 9990
9564 IF R0 < 1 THEN 9990
9566 IF R0 <= K(40) THEN 9572
9568 LET A$(1) = "registers"
9570 GOTO 9960
9572 IF D(R0,0) = 0 THEN 9577
9574 IF D(R0,0) <> R1 THEN 9990
9576 RETURN
9577 IF R0 <> M0 + 1 THEN 9990
9578 LET D(R0,0) = R1
9579 LET T(R0) = 0
9580 LET W(R0) = 0
9582 LET M0 = R0
9584 RETURN
9590 REM the base and index fields of loads and stores
9592 IF F$(J2) <> "base" THEN 9595
9594 LET B1 = P0
9595 IF F$(J2) <> "idx" THEN 9599
9597 LET B2 = P0
9599 RETURN
9600 REM ---- a fl field: "-" or letters of l p s z a, each once, in this order (DESIGN 3.1) ----
9602 IF Z$ = "-" THEN 9618
9604 LET Y1 = 0
9606 FOR I2 = 1 TO LEN(Z$)
9608 LET Y2 = POS("lpsza", SEG$(Z$, I2, I2))
9610 IF Y2 <= Y1 THEN 9990
9612 LET Y1 = Y2
9614 NEXT I2
9618 RETURN
9630 REM ---- Z8 = the results of classes Z6$ beyond x0-x7 and d0-d7 (the results area) --------
9632 LET Z8 = 0
9634 LET Y1 = 0
9636 LET Y2 = 0
9638 FOR I1 = 1 TO LEN(Z6$)
9640 IF SEG$(Z6$, I1, I1) = "f" THEN 9648
9642 LET Y1 = Y1 + 1
9644 IF Y1 <= 8 THEN 9654
9646 GOTO 9652
9648 LET Y2 = Y2 + 1
9650 IF Y2 <= 8 THEN 9654
9652 LET Z8 = Z8 + 1
9654 NEXT I1
9656 RETURN
9660 REM ---- analysis (W0 = 3): register R0 is written; it is not the ind of an open loop ------
9661 REM (DESIGN 3.6.5: the body never writes ind)
9662 IF W0 <> 3 THEN 9672
9664 FOR I7 = 1 TO K7
9666 IF B(I(I7),1) <> 1 THEN 9670
9668 IF B(I(I7),4) = R0 THEN 9990
9670 NEXT I7
9672 RETURN
9680 REM ---- X5 counts the site fields of the record, present or -: they are no operands (DESIGN 2.7)
9682 IF T1 <> 6 THEN 9686
9684 LET X5 = X5 + 1
9686 RETURN
9720 REM ---- Z2$ = the name of register R3 as the operand in position K4: its machine register,
9721 REM or scratch register K4 of its class (x15 x16 x17, d29 d30 d31) loaded from its spill
9722 REM slot (an f load's offset beyond the scaled form through x<14+K4>, which its position
9723 REM leaves free); DESIGN 4.9.2 "Operands"
9724 LET L2 = D(R3,8)
9725 IF L2 <> 0 THEN 9727
9726 GOTO 9738
9727 IF L2 < 0 THEN 9730
9728 LET Z2$ = FNN$(L2)
9729 RETURN
9730 LET Z2$ = "x" & STR$(14 + K4)
9731 LET Z0$ = Z2$
9732 IF D(R3,0) <> 2 THEN 9734
9733 LET Z2$ = "d" & STR$(28 + K4)
9734 LET Z1$ = "ldr"
9735 LET Z3 = A3 + 8 * (-L2 - 1)
9736 LET Z4$ = "sp"
9737 GOTO 9020
9738 LET M$ = "a register without a location"
9739 GOTO 9975
9745 REM ---- 9750: spill slot S1 into the register Z2$; 9752: [Z4$ + Z3] into Z2$ (an offset
9746 REM beyond the scaled form through Z2$ itself, through x17 for a d register)
9750 LET Z3 = A3 + 8 * (S1 - 1)
9751 LET Z4$ = "sp"
9752 LET Z1$ = "ldr"
9753 LET Z0$ = Z2$
9754 IF SEG$(Z2$, 1, 1) <> "d" THEN 9020
9755 LET Z0$ = "x17"
9756 GOTO 9020
9760 REM ---- the register Z2$ into spill slot S1 (an offset beyond the scaled form through x16) ---
9761 LET Z3 = A3 + 8 * (S1 - 1)
9762 LET Z4$ = "sp"
9763 LET Z1$ = "str"
9764 LET Z0$ = "x16"
9765 GOTO 9020
9800 REM ---- the memory operand M$ of a load or store (DESIGN 4.9.2 "Loads and stores"): base
9801 REM Q(B1) (x16 when spilled), idx Q(B2) (x17 when spilled) times scale U2, off L() (O1 = 1
9802 REM if not 0; G8 its value when 0 <= off < 65536, else -1): [base], [base, #off] with an
9803 REM encodable offset, [base, idx] or [base, idx, lsl #3] (scale 1 or the access size, off 0),
9804 REM else the address formed in x16; a store's spilled value loaded afterwards into x15 / d29
9805 LET Z9 = 8
9806 IF POS("|ldb|stb|", "|" & R$(I0) & "|") = 0 THEN 9808
9807 LET Z9 = 1
9808 LET R3 = Q(B1)
9809 LET K4 = 2
9810 GOSUB 9720
9811 LET G6$ = Z2$
9812 LET G7$ = ""
9813 IF B2 = 0 THEN 9818
9814 LET R3 = Q(B2)
9815 LET K4 = 3
9816 GOSUB 9720
9817 LET G7$ = Z2$
9818 LET G8 = -1
9819 IF L(1) + L(2) + L(3) <> 0 THEN 9821
9820 LET G8 = L(4)
9821 IF B2 > 0 THEN 9834
9822 LET M$ = "[" & G6$ & "]"
9823 IF O1 = 0 THEN 9880
9824 LET M$ = "[" & G6$ & ", #" & STR$(G8) & "]"
9825 IF G8 < 0 THEN 9828
9826 IF G8 <> INT(G8 / Z9) * Z9 THEN 9828
9827 IF G8 <= 4095 * Z9 THEN 9880
9828 LET G9$ = G6$
9829 GOTO 9862
9834 LET M$ = "[" & G6$ & ", " & G7$ & "]"
9835 IF O1 = 1 THEN 9840
9836 IF U2 = 1 THEN 9880
9837 LET M$ = "[" & G6$ & ", " & G7$ & ", lsl #3]"
9838 IF U2 = Z9 THEN 9880
9840 LET Y1 = 1
9841 LET Y2 = 0
9842 IF Y1 >= U2 THEN 9846
9843 LET Y1 = Y1 * 2
9844 LET Y2 = Y2 + 1
9845 GOTO 9842
9846 LET X$ = "add x16, " & G6$ & ", " & G7$ & ", lsl #" & STR$(Y2)
9847 IF Y1 = U2 THEN 9853
9848 LET Z5 = U2
9849 LET Z5$ = "x15"
9850 GOSUB 9050
9851 LET X$ = "madd x16, " & G7$ & ", x15, " & G6$
9853 GOSUB 9010
9854 LET M$ = "[x16]"
9855 IF O1 = 0 THEN 9880
9856 LET G9$ = "x16"
9862 REM the offset added to x16 or to the base: an immediate 0-4095, else through x17
9863 LET X$ = "add x16, " & G9$ & ", #" & STR$(G8)
9864 IF G8 < 0 THEN 9867
9865 IF G8 > 4095 THEN 9867
9866 GOTO 9874
9867 FOR I1 = 1 TO 4
9868 LET V(I1) = L(I1)
9869 NEXT I1
9870 LET Z5$ = "x17"
9871 GOSUB 9060
9872 LET X$ = "add x16, " & G9$ & ", x17"
9874 GOSUB 9010
9876 LET M$ = "[x16]"
9880 IF SEG$(R$(I0), 1, 1) <> "s" THEN 9890
9882 LET R3 = Q(1)
9884 LET K4 = 1
9886 GOSUB 9720
9888 LET J$(1) = Z2$
9890 RETURN
9960 CALL "dg_compile": P$, H$(), N1, F1, F2, F3, "TOO_LARGE", A$(), 1, E(), E$(), E0
9970 CALL "dg_boot": P$
9975 CALL "dg_bug": P$, M$
9980 CALL "dg_internal": P$, "BAD_HEADER", E(), E$(), E0
9990 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
