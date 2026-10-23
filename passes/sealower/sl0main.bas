100 REM ====================================================================================
105 REM sealower -- pass 3a: sea.hirl -> sea.lir1 (docs/DESIGN.md 2.1, 3.5.9, 3.6). Phase 1: the
110 REM canonical lowering of scalar code (DESIGN 3.6.6 rules 1-12); no call is inlined (3.6.6).
115 REM Built as DESIGN 2.6.3 says: this file, the modules io diag tables, the DATA blocks errors
120 REM exits consts entries records, and 99999 END. Exit status: 0, 10 (program too large, 2.7),
125 REM 11 (internal error: truncated input, bad header, bad record, bad tree; DESIGN 2.2).
130 REM Reads all of sea.hirl into tables; lowers each function in file order into L$ (its slot
135 REM records come first, 3.6.3) and writes it; then the data records in label order (3.6.2).
140 REM A record outside the phase-1 subset of 3.6.6 (arrays, structs, strings beyond printf %s,
145 REM f64 %, pow, other library functions, elemental code) is rejected by pass 2a, so meeting
150 REM one here is the internal error bad record.
155 REM Tables: H nodes (1 kind, 2 F*1E9+L, 3 column, 4 ty, 5 a, 6 b, 7 first child, 8 next
160 REM   sibling, 0 string); G functions (0 locals base in A, 1 name, 2 kind 1 main 2 fn, 3 rty,
165 REM   4 np, 5 nl, 6 F*1E9+L, 7 column, 8 body); A locals (1 ty, 2 ref); T types (1 kind 1 tvec
170 REM   2 ttuple, 2 n, 3 first component in M); M lists (tuple components, tbind lids, 0 for -);
175 REM   S$ field texts; V registers (1 class 1 i 2 f 3 p, 2 output number); W frames (6 words:
180 REM   node, dest, resume, x1, x2, x3), the tree stack while reading; U value stack (1 register,
185 REM   2 reload local, store target or class); D data items (1 kind 1 str 2 fmt, 2 node);
190 REM   B slots (1 size, 2 align); J open loops; P site hash; L$ the function's records.
195 REM Node kinds (column 1 of H, R(i,0) per record row): 1 ci 2 cf 3 cb 4 cs 5 lv 6 cvt 7 un
200 REM   8 bin 9 powk 10 call 11 rarg 12 lib 13 fmt 14 ftext 15 fconv 16 rng 17 ifx 18 skip
205 REM   19 seq 20 bind 21 tbind 22 eval 23 asg 24 tasg 25 if 26 while 27 forr 28 break 29 cont
210 REM   30 ret 31 tret 32 block; records 33 fn 34 par 35 loc 36 end 37 tvec 38 ttuple; 39 idx
211 REM   40 dol 42 tmat; sea.hirl (sl3hirl): 43 xblk 44 tmp 45 hloop 46 ext 47 adat 48 eld 49 est
212 REM   50 anew 51 wbin 52 tptr. Locals A: 0 the tmp binding it, 3 its register if not its own, 4 flags.
215 REM Dest D of a node (rules 2, 3): 0 a new register; 1..N7 the register of a local; above N7
220 REM   a given new register R; -1 a call whose results are discarded (nr 0); -2 a call whose
225 REM   result registers are the top of U (tbind, tasg, tret). Registers are virtual numbers
230 REM   (locals 1..N7 = their lid) numbered for output on first appearance (3.6.1).
235 REM ====================================================================================
240 FILES "sea.hirl"; "sea.lir1"
245 DIM E(299), E$(299,5), Q(20), Q$(20), K(299,4), K$(299), Y(22), Y$(22,5), Z(8), I(40), L(4)
250 DIM N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), G$(300), H$(100)
255 DIM H(99999,8), G(49999,8), A(99999,4), T(20008,3), M(199999), S$(199999), A$(2)
260 DIM V(199999,3), W(599999), U(199999,2), D(49999,2), B(9999,2), J(59999,4), P(131071), O(99999,6)
265 DIM L$(199999)
270 LET P$ = "sealower"
275 REM ---- the tables (canonical order: errors exits consts entries records) ----------------
280 CALL "tb_errors": P$, E(), E$(), 299, E0
285 CALL "tb_exits": P$, E(), E$(), E0, Q(), Q$(), 20, N9
290 CALL "tb_consts": P$, E(), E$(), E0, K(), K$(), 299, K0
295 CALL "tb_entries": P$, E(), E$(), E0, Y(), Y$(), 22, Y0
300 LET Z(1) = 39
305 LET Z(2) = 299
310 LET Z(3) = 399
315 LET Z(4) = 1499
320 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), R(), R$(), F(), F$(), Z()
325 LET Q1$ = "FILE_VERSION"
330 GOSUB 1850
335 LET V8 = Q1
340 LET Q1$ = "LIM_NODES"
345 GOSUB 1850
350 LET N8 = Q1
355 LET Q1$ = "LIM_LIR_INSTRS"
360 GOSUB 1850
365 LET I9 = Q1
370 LET Q1$ = "LIM_LIR_OPERANDS"
375 GOSUB 1850
380 LET O9 = Q1
385 LET Q1$ = "LIM_LIR_REGS"
390 GOSUB 1850
395 LET R8 = Q1
400 LET Q1$ = "LIM_LIR_BLOCKS"
405 GOSUB 1850
410 LET B9 = Q1
415 LET Q1$ = "LIM_LIR_SLOTS"
420 GOSUB 1850
425 LET S9 = Q1
430 LET Q1$ = "LIM_LIR_IMMS"
435 GOSUB 1850
440 LET M9 = Q1
445 LET Q1$ = "LIM_LIR_LABELS"
450 GOSUB 1850
455 LET D9 = Q1
460 LET Q1$ = "LIM_LIR_SITES"
465 GOSUB 1850
470 LET Z8 = Q1
475 LET Q1$ = "SLOT_SIZE"
480 GOSUB 1850
485 LET Z7 = Q1
490 LET Q1$ = "ESIZE_I64"
495 GOSUB 1850
500 LET E7 = Q1
505 LET Q1$ = "ESIZE_F64"
510 GOSUB 1850
515 LET E8 = Q1
516 LET Q1$ = "LIM_TYPES"
517 GOSUB 1850
518 LET T9 = Q1 + 9
519 CALL "ly_init": O(), K(), K$(), K0, T9, 99999, P$
520 REM the tables above are DIMmed for these limits
521 REM type ids run to 9 + SEA_LIM_TYPES (the predefined 1-9, then the program's)
522 IF T9 > 20008 THEN 565
525 IF N8 > 99999 THEN 565
530 IF I9 > 199999 THEN 565
535 IF R8 > 199999 THEN 565
540 IF B9 > 9999 THEN 565
545 IF S9 > 9999 THEN 565
550 IF D9 > 49999 THEN 565
555 IF Z8 > 65535 THEN 565
560 GOTO 575
565 CALL "dg_bug": P$, "a capacity limit is larger than the pass's tables"
570 REM the runtime entries of rules 8 and 9 (rt.inc SEA_ENTRY_LIST)
575 LET Y1 = 0
580 LET Y2 = 0
585 FOR I = 1 TO Y0
590 IF Y$(I, 1) <> "PRINTF" THEN 600
595 LET Y1 = I
600 IF Y$(I, 1) <> "NOW" THEN 610
605 LET Y2 = I
610 NEXT I
615 IF Y1 = 0 THEN 645
620 IF Y2 = 0 THEN 645
625 IF Y$(Y1, 4) <> "pp" THEN 645
630 IF Y$(Y1, 5) <> "-" THEN 645
635 IF Y$(Y2, 4) <> "-" THEN 645
640 IF Y$(Y2, 5) = "f" THEN 655
645 CALL "dg_bug": P$, "entry PRINTF (pp, -) or NOW (-, f) is not in the entries table"
650 REM ---- R(i,0) = the node kind of every HIR record row of the phase-1 subset, else 0 -----
655 LET K1$ = "|ci=01|cf=02|cb=03|cs=04|lv=05|cvt=06|un=07|bin=08|powk=09|call=10|rarg=11|lib=12|fmt=13|ftext=14|fconv=15|rng=16|ifx=17|skip=18|seq=19|bind=20|"
656 GOSUB 9130
660 LET K2$ = "|tbind=21|eval=22|asg=23|tasg=24|if=25|while=26|forr=27|break=28|cont=29|ret=30|tret=31|block=32|fn=33|par=34|loc=35|end=36|tvec=37|ttuple=38|"
662 LET K2$ = K2$ & "|idx=39|dol=40|tmat=42|"
663 LET K2$ = K2$ & "|xblk=43|tmp=44|hloop=45|ext=46|adat=47|eld=48|est=49|anew=50|wbin=51|tptr=52|"
664 LET K2$ = K2$ & "|chkb=53|chk=54|rcnt=55|cow=56|mcpy=57|cdat=58|tfvec=41|tfmat=59|fld=60|slit=61|tstruct=62|trec=63|fd=64|"
665 LET K1$ = K1$ & K2$
670 FOR I = 1 TO Z(7)
675 LET R(I, 0) = 0
680 IF R(I, 1) = 2 THEN 690
682 IF R(I, 1) = 7 THEN 690
685 IF R(I, 1) <> 4 THEN 705
690 LET P1 = POS(K1$, "|" & R$(I) & "=")
695 IF P1 = 0 THEN 705
700 LET R(I, 0) = VAL(SEG$(K1$, P1 + LEN(R$(I)) + 2, P1 + LEN(R$(I)) + 3))
705 NEXT I
710 REM ==== reading sea.hirl ==================================================================
715 CALL "io_hdr": 1, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), V8, T$, H$(), 100, N1, L$
720 LET L9 = N1 + 3
725 LET Y9 = 9
730 LET P8$ = ""
735 REM one record per round: L$
740 CALL "io_plain": L$, O
745 IF O = 0 THEN 2360
750 CALL "io_split": L$, G$(), 300, C0
755 IF C0 < 1 THEN 2360
760 IF G$(1) = "#end" THEN 1695
765 LET I0 = 0
770 FOR I = 1 TO Z(7)
775 IF R(I, 0) = 0 THEN 795
780 IF R$(I) <> G$(1) THEN 795
785 LET I0 = I
790 GOTO 805
795 NEXT I
800 GOTO 2360
805 LET K = R(I0, 0)
810 GOSUB 1970
811 IF O(0, 4) * (K - 64) <> 0 THEN 2360
815 REM a capacity overflow met at a record without a position is reported at the next one with one
820 IF Q8 = 0 THEN 840
825 IF P8$ = "" THEN 840
830 LET Q2$ = P8$
835 GOTO 2375
840 IF K > 32 THEN 9670
845 REM ---- a node: inside a function whose par and loc records are complete -----------------
850 IF F7 = 0 THEN 2365
855 IF P7 + L7 > 0 THEN 2365
860 GOSUB 1915
865 IF W1 < P1 THEN 2365
870 LET Q2$ = "nodes"
875 IF H0 >= N8 THEN 2375
880 LET H0 = H0 + 1
885 LET H1 = H0
890 LET H(H1, 1) = K
895 LET H(H1, 2) = F1 * 1E9 + L1
900 LET H(H1, 3) = C1
905 LET H(H1, 4) = 0
910 IF K > 19 THEN 916
915 LET H(H1, 4) = I(2)
916 IF K < 39 THEN 920
917 IF K > 40 THEN 920
918 LET H(H1, 4) = I(2)
920 LET H(H1, 5) = 0
925 LET H(H1, 6) = 0
930 LET H(H1, 7) = 0
935 LET H(H1, 8) = 0
940 LET H(H1, 0) = 0
945 REM the children: the P1 topmost stack entries, the earliest first
950 IF P1 = 0 THEN 975
955 LET H(H1, 7) = W(W1 - P1 + 1)
960 FOR I = W1 - P1 + 1 TO W1 - 1
965 LET H(W(I), 8) = W(I + 1)
970 NEXT I
975 LET W1 = W1 - P1 + 1
980 LET W(W1) = H1
981 GOSUB 40100
982 IF K > 42 THEN 30200
983 IF K < 33 THEN 985
984 ON K - 38 GOTO 1040, 1015, 1050
985 ON K GOTO 995, 995, 1015, 995, 1015, 1285, 1070, 1095, 1135, 1025, 1285, 1155, 1040, 995, 1180, 1025, 1285, 1285, 1040, 1050, 1200, 1285, 1255, 8105, 1050, 1285, 1050, 1285, 1285, 1060, 1285, 1060
990 REM the value of field 3 (ci cf cs ftext) as a string
995 GOSUB 1900
1000 LET S$(S0) = G$(4)
1005 LET H(H1, 0) = S0
1010 GOTO 1285
1015 LET H(H1, 5) = I(3)
1020 GOTO 1285
1025 LET H(H1, 5) = I(3)
1030 LET H(H1, 6) = I(4)
1035 GOTO 1285
1040 LET H(H1, 6) = I(3)
1045 GOTO 1285
1050 LET H(H1, 5) = I(2)
1055 GOTO 1285
1060 LET H(H1, 6) = I(2)
1065 GOTO 1285
1070 LET K3$ = "|neg    |not    "
1075 LET W2$ = G$(4)
1080 GOSUB 1875
1085 LET H(H1, 5) = W2
1090 GOTO 1285
1095 LET K3$ = "|add    |sub    |mul    |div    |mod    |pow    |matmul |eq     |ne     |lt     |le     |gt     |ge     |band   |bor    |and    |or     |cat    "
1100 LET W2$ = G$(4)
1105 GOSUB 1875
1110 LET H(H1, 5) = W2
1115 GOSUB 1900
1120 LET S$(S0) = G$(4)
1125 LET H(H1, 0) = S0
1130 GOTO 1285
1135 CALL "io_i": G$(4), V, K9, L(), T
1140 IF K9 <> 0 THEN 2360
1145 LET H(H1, 5) = V
1150 GOTO 1285
1155 GOSUB 1900
1160 LET S$(S0) = G$(4)
1165 LET H(H1, 0) = S0
1170 LET H(H1, 6) = I(4)
1175 GOTO 30050
1180 GOSUB 1900
1185 LET S$(S0) = G$(4) & " " & G$(5) & " " & G$(6) & " " & G$(7)
1190 LET H(H1, 0) = S0
1195 GOTO 1285
1200 LET H(H1, 6) = I(2)
1205 LET H(H1, 0) = M1 + 1
1210 LET Q2$ = "nodes"
1215 IF M1 + I(2) > 199999 THEN 2375
1220 FOR I = 1 TO I(2)
1225 LET M1 = M1 + 1
1230 LET M(M1) = 0
1235 IF G$(3 + I) = "-" THEN 1245
1240 LET M(M1) = VAL(G$(3 + I))
1245 NEXT I
1250 GOTO 1285
1255 LET K3$ = "|set    |add    |sub    |mul    |div    "
1260 LET W2$ = G$(3)
1265 GOSUB 1875
1270 LET H(H1, 5) = W2
1275 GOTO 1285
1280 REM ---- the next record --------------------------------------------------------------------
1285 CALL "io_read": 1, L$, L9, P$, E(), E$(), E0
1290 GOTO 740
1295 REM ---- declarations: fn par loc end tvec ttuple --------------------------------------------
1300 ON K - 32 GOTO 1430, 1550, 1585, 1650, 1310, 1350
1305 REM types come first, ids from 10 in order (3.5.1)
1310 IF G0 > 0 THEN 2360
1312 IF Y7 = 1 THEN 2360
1315 IF I(1) <> Y9 + 1 THEN 2360
1320 LET Y9 = I(1)
1325 IF Y9 <= T9 THEN 1340
1330 LET P8$ = "types"
1335 GOTO 1285
1340 LET T(Y9, 1) = 1 + 2 * INT(K / 42)
1342 LET T(Y9, 2) = I(2)
1343 CALL "ly_dyn": O(), Y9
1345 GOTO 1285
1350 IF G0 > 0 THEN 2360
1352 IF Y7 = 1 THEN 2360
1355 IF I(1) <> Y9 + 1 THEN 2360
1360 LET Y9 = I(1)
1365 IF Y9 > T9 THEN 1415
1370 IF M1 + I(2) > 199999 THEN 1415
1375 LET T(Y9, 1) = 2
1380 LET T(Y9, 2) = I(2)
1385 LET T(Y9, 3) = M1 + 1
1390 FOR I = 1 TO I(2)
1395 LET M1 = M1 + 1
1400 LET M(M1) = VAL(G$(3 + I))
1405 NEXT I
1410 GOTO 1285
1415 LET P8$ = "types"
1420 GOTO 1285
1425 REM fn: functions numbered from 1; the par and loc records follow (3.5.4)
1430 IF F7 = 1 THEN 2365
1435 IF I(1) <> G0 + 1 THEN 2360
1440 LET Q2$ = "symbols"
1445 IF G0 >= 49999 THEN 2375
1450 LET G0 = G0 + 1
1455 LET K3$ = "|main   |fn     "
1460 LET W2$ = G$(4)
1465 GOSUB 1875
1470 IF W2 = 0 THEN 2360
1475 GOSUB 1900
1480 LET S$(S0) = G$(3)
1485 LET G(G0, 0) = A0
1490 LET G(G0, 1) = S0
1495 LET G(G0, 2) = W2
1500 LET G(G0, 3) = I(4)
1505 LET G(G0, 4) = I(5)
1510 LET G(G0, 5) = I(6)
1515 LET G(G0, 6) = F1 * 1E9 + L1
1520 LET G(G0, 7) = C1
1525 LET G(G0, 8) = 0
1530 LET F7 = 1
1532 LET H2 = H0 + 1
1535 LET P7 = I(5)
1540 LET L7 = I(6)
1545 GOTO 1285
1550 IF F7 = 0 THEN 2365
1555 IF P7 = 0 THEN 2365
1560 LET P7 = P7 - 1
1562 LET H3 = 0
1565 LET Q2 = 0
1570 IF G$(4) = "val" THEN 1610
1575 LET Q2 = 1
1580 GOTO 1610
1585 IF F7 = 0 THEN 2365
1590 IF P7 > 0 THEN 2365
1595 IF L7 = 0 THEN 2365
1600 LET L7 = L7 - 1
1605 LET Q2 = 0
1606 GOSUB 30060
1610 IF A0 < 99999 THEN 1625
1615 LET P8$ = "symbols"
1620 GOTO 1285
1625 LET A0 = A0 + 1
1630 LET A(A0, 1) = I(2)
1635 LET A(A0, 2) = Q2
1640 GOTO 30075
1645 REM end pops the body block; the stack is then empty (3.3)
1650 IF F7 = 0 THEN 2365
1655 IF P7 + L7 > 0 THEN 2365
1660 IF W1 <> 1 THEN 2365
1665 IF H(W(1), 1) <> 32 THEN 2365
1670 LET G(G0, 8) = W(1)
1672 GOSUB 31000
1675 LET W1 = 0
1680 LET F7 = 0
1685 GOTO 1285
1690 REM #end: nothing may follow; no function may be open
1695 IF F7 = 1 THEN 2365
1700 IF P8$ <> "" THEN 2360
1705 CALL "io_end": 1, P$, E(), E$(), E0
1710 REM ==== writing sea.lir1 ===================================================================
1715 SCRATCH #2
1720 CALL "io_hdr_put": 2, V8, T$, H$(), N1
1725 FOR F0 = 1 TO G0
1730 GOSUB 2415
1735 NEXT F0
1740 REM the data records, in label order (3.6.2)
1745 FOR I = 1 TO D0
1750 LET X = D(I, 2)
1752 IF D(I, 1) = 3 THEN 41562
1753 IF D(I, 1) > 3 THEN 42479
1755 IF D(I, 1) = 2 THEN 1770
1760 CALL "io_put": 2, "str d" & STR$(I) & " " & S$(H(X, 0))
1765 GOTO 1825
1770 CALL "io_put": 2, "fmt d" & STR$(I) & " " & STR$(H(X, 6))
1775 LET X2 = H(X, 7)
1780 IF X2 = 0 THEN 1825
1785 IF H(X2, 1) = 15 THEN 1800
1790 CALL "io_put": 2, "ftext " & S$(H(X2, 0))
1795 GOTO 1815
1800 LET T1 = H(H(X2, 7), 4)
1805 GOSUB 7395
1810 CALL "io_put": 2, "fconv " & S$(H(X2, 0)) & " " & SEG$("ifp", C1, C1)
1815 LET X2 = H(X2, 8)
1820 GOTO 1780
1825 NEXT I
1830 CALL "io_fin": 2
1835 STOP
1840 REM ==== subroutines of the reader ===========================================================
1845 REM ---- 1850: Q1 = the constant Q1$ of the consts table ------------------------------------
1850 CALL "tb_cval": K(), K$(), K0, Q1$, Q1, T
1855 IF T = 0 THEN 1865
1860 CALL "dg_bug": P$, "constant " & Q1$ & " is not in the consts table"
1865 RETURN
1870 REM ---- 1875: W2 = the position (1..) of the word W2$ in the list K3$ ("|" + 7 bytes), or 0 -
1875 LET W2 = POS(K3$, "|" & W2$ & " ")
1880 IF W2 = 0 THEN 1890
1885 LET W2 = (W2 - 1) / 8 + 1
1890 RETURN
1895 REM ---- 1900: S0 = a new row of S$ (its capacity exceeds the records that use it) --------
1900 LET S0 = S0 + 1
1905 RETURN
1910 REM ---- 1915: P1 = the number of nodes the record pops (passes.txt pops column) ----------
1915 LET P1 = 0
1920 FOR J = 1 TO R(I0, 5)
1925 LET P2 = R(I0, 5 + J)
1930 IF P2 < 0 THEN 1945
1935 LET P1 = P1 + P2
1940 GOTO 1950
1945 LET P1 = P1 + I(-P2)
1950 NEXT J
1955 RETURN
1960 REM ---- 1970: the fields of the record against passes.txt; I(j) = value of a u-like field j;
1965 REM a pos field sets F1 L1 C1 and Q8 = 1; a bad field is the internal error bad record
1970 LET Q8 = 0
1975 LET T0 = 1
1980 LET N6 = 0
1985 IF F7 = 0 THEN 1995
1990 LET N6 = G(G0, 4) + G(G0, 5)
1995 FOR J = 1 TO R(I0, 4)
2000 LET B0 = R(I0, 3) + J - 1
2005 LET I(J) = 0
2010 LET X0 = 1
2015 IF F(B0, 3) = 0 THEN 2025
2020 LET X0 = I(F(B0, 3))
2025 FOR X5 = 1 TO X0
2030 LET T0 = T0 + 1
2035 IF T0 > C0 THEN 2360
2040 LET Z$ = G$(T0)
2045 LET T1 = F(B0, 1)
2050 IF F(B0, 2) = 0 THEN 2060
2055 IF Z$ = "-" THEN 2065
2060 GOSUB 2090
2065 NEXT X5
2070 NEXT J
2075 IF T0 < C0 THEN 2360
2080 RETURN
2085 REM 2090: the token Z$ of type T1 (u i f s pos site fl ty lid fid cid iid; 100+ enum)
2090 IF T1 >= 100 THEN 2340
2095 IF T1 > 12 THEN 2360
2100 ON T1 GOTO 2105, 2125, 2140, 2155, 2170, 2195, 2215, 2255, 2285, 2315, 2315, 2315
2105 CALL "io_u": Z$, V, T
2110 IF T <> 0 THEN 2360
2115 LET I(J) = V
2120 RETURN
2125 CALL "io_i": Z$, V, K9, L(), T
2130 IF T <> 0 THEN 2360
2135 RETURN
2140 CALL "io_f": Z$, L(), T
2145 IF T <> 0 THEN 2360
2150 RETURN
2155 CALL "io_unesc": Z$, 0, Q1$, T
2160 IF T <> 0 THEN 2360
2165 RETURN
2170 CALL "io_pos": Z$, F1, L1, C1, T
2175 IF T <> 0 THEN 2360
2180 IF F1 >= N1 THEN 2360
2185 LET Q8 = 1
2190 RETURN
2195 CALL "io_site": Z$, F2, L2, T
2200 IF T <> 0 THEN 2360
2205 IF F2 >= N1 THEN 2360
2210 RETURN
2215 IF Z$ = "-" THEN 2250
2220 LET P2 = 0
2225 FOR X6 = 1 TO LEN(Z$)
2230 LET X7 = POS("lpsza", SEG$(Z$, X6, X6))
2235 IF X7 <= P2 THEN 2360
2240 LET P2 = X7
2245 NEXT X6
2250 RETURN
2255 CALL "io_u": Z$, V, T
2260 IF T <> 0 THEN 2360
2265 IF V < 1 THEN 2360
2270 IF V > Y9 THEN 2360
2275 LET I(J) = V
2280 RETURN
2285 CALL "io_u": Z$, V, T
2290 IF T <> 0 THEN 2360
2295 IF V < 1 THEN 2360
2300 IF V > N6 THEN 2360
2305 LET I(J) = V
2310 RETURN
2315 CALL "io_u": Z$, V, T
2320 IF T <> 0 THEN 2360
2325 IF V < 1 THEN 2360
2330 LET I(J) = V
2335 RETURN
2340 CALL "tb_word": N(), W$(), T1 - 100, Z$, X7
2345 IF X7 = 0 THEN 2360
2350 RETURN
2355 REM ---- failures ---------------------------------------------------------------------------
2360 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
2365 CALL "dg_internal": P$, "BAD_TREE", E(), E$(), E0
2370 REM program too large: Q2$, at the record being read (F1 L1 C1)
2375 LET A$(1) = Q2$
2380 CALL "dg_compile": P$, H$(), N1, F1, L1, C1, "TOO_LARGE", A$(), 1, E(), E$(), E0
2385 REM program too large: Q2$, at the node X being lowered
2390 LET A$(1) = Q2$
2395 LET F1 = INT(H(X, 2) / 1E9)
2400 LET L1 = H(X, 2) - F1 * 1E9
2405 CALL "dg_compile": P$, H$(), N1, F1, L1, H(X, 3), "TOO_LARGE", A$(), 1, E(), E$(), E0
2410 REM ==== lowering one function F0 (DESIGN 3.6.3, 3.6.6) =======================================
2415 LET N6 = G(F0, 4)
2420 LET N7 = N6 + G(F0, 5)
2425 REM forget the output numbers of the previous function's registers
2430 FOR I = 1 TO V9
2435 LET V(I, 2) = 0
2440 NEXT I
2445 REM each local and parameter has one register of its class (rule 1); a ref parameter is a p
2450 FOR I = 1 TO N7
2455 LET T1 = A(G(F0, 0) + I, 1)
2460 GOSUB 7395
2465 LET V(I, 1) = C1
2470 IF A(G(F0, 0) + I, 2) = 0 THEN 2480
2475 LET V(I, 1) = 3
2480 LET V(I, 2) = 0
2481 LET T5 = T1
2482 GOSUB 40600
2483 LET V(I, 0) = F5
2484 LET V(I, 3) = T5
2485 NEXT I
2490 LET V0 = N7
2495 LET V9 = N7
2497 GOSUB 41170
2500 LET M7 = 0
2505 LET L0 = 0
2510 LET O7 = 0
2515 LET Q7 = 0
2520 LET B7 = 0
2525 LET S5 = 0
2530 LET J0 = 0
2532 LET J9 = 0
2535 LET U0 = 0
2540 LET S7 = 0
2541 REM the func record's pos is a site too (2.7, 4.9); a capacity error here is reported at
2542 REM that pos, held in the unused node row 0
2543 LET H(0, 2) = G(F0, 6)
2544 LET H(0, 3) = G(F0, 7)
2545 LET X = 0
2546 LET K8 = G(F0, 6)
2547 GOSUB 7795
2548 LET X = G(F0, 8)
2550 REM rule 12 snapshots: in one statement (its expressions; an if, while, forr or hloop only its
2555 REM condition or range), a read of a local L before a ref argument of L is flagged H(.,6) = 1
2560 REM (an lv's own column 6 is free); the read then copies L into a new register. The nodes are
2561 REM visited last first, so an xblk is met before its subtree [E6, xblk]: the statements inside
2562 REM an xblk belong to the statement that holds it (3.6.6 rule 12, sea.hirl)
2565 LET N3 = G(F0, 8)
2570 IF H(N3, 7) = 0 THEN 2582
2575 LET N3 = H(N3, 7)
2580 GOTO 2570
2582 LET E6 = G(F0, 8) + 1
2585 FOR N4 = G(F0, 8) TO N3 STEP -1
2588 IF N4 >= E6 THEN 2720
2590 IF H(N4, 1) < 20 THEN 2720
2591 GOSUB 41750
2592 IF A5 > 0 THEN 2642
2595 IF H(N4, 1) > 31 THEN 23230
2600 IF H(N4, 7) = 0 THEN 2720
2605 LET B5 = N4 - 1
2610 IF H(N4, 1) < 25 THEN 2625
2615 IF H(N4, 1) > 27 THEN 23250
2620 LET B5 = H(N4, 7)
2625 LET A5 = N4
2630 IF H(A5, 7) = 0 THEN 2642
2635 LET A5 = H(A5, 7)
2640 GOTO 2630
2642 REM U7, U8: the statement's evaluation order (an asg set to an idx, a tasg; 3.5.5 G1)
2643 GOSUB 23280
2645 FOR K5 = A5 TO B5
2650 IF H(K5, 1) <> 11 THEN 2715
2655 LET C5 = H(K5, 7)
2660 IF ABS(H(C5, 1) - 49.5) = 10.5 THEN 23450
2662 IF H(C5, 1) <> 5 THEN 2715
2665 LET L5 = H(C5, 5)
2670 IF A(G(F0, 0) + L5, 2) = 1 THEN 23490
2675 FOR J5 = A5 TO B5
2680 IF H(J5, 1) <> 5 THEN 2710
2685 IF H(J5, 5) <> L5 THEN 2710
2690 REM the evaluation order, the targets of ref arguments and the consumers of reference values
2695 GOTO 23550
2705 LET H(J5, 6) = 1
2710 NEXT J5
2715 NEXT K5
2720 NEXT N4
2725 REM the func record: the parameters are numbered first (3.6.1)
2730 LET F1 = INT(G(F0, 6) / 1E9)
2735 LET L1 = G(F0, 6) - F1 * 1E9
2740 LET F9$ = "func " & S$(G(F0, 1)) & " main"
2745 IF G(F0, 2) = 1 THEN 2755
2750 LET F9$ = "func " & S$(G(F0, 1)) & " fn"
2755 LET F9$ = F9$ & " " & STR$(F1) & ":" & STR$(L1) & ":" & STR$(G(F0, 7)) & " " & STR$(N6 + H7)
2757 GOSUB 41200
2760 FOR I = 1 TO N6
2765 LET V1 = I
2770 GOSUB 7500
2775 LET F9$ = F9$ & " " & Z$
2780 NEXT I
2785 LET T1 = G(F0, 3)
2790 GOSUB 2935
2795 LET F9$ = F9$ & " " & STR$(Z5) & Z5$
2800 REM the body: the frame machine runs until the body block returns
2805 LET X1 = G(F0, 8)
2810 LET D1 = 0
2815 GOTO 3030
2820 REM rule 6: .main always ends with ret 0, a function without results unless it ends with ret
2825 IF G(F0, 2) = 1 THEN 2875
2830 IF G(F0, 3) <> 1 THEN 2885
2835 LET X2 = H(G(F0, 8), 7)
2840 LET X3 = 0
2845 IF X2 = 0 THEN 2865
2850 LET X3 = X2
2855 LET X2 = H(X2, 8)
2860 GOTO 2845
2865 IF X3 = 0 THEN 2875
2870 IF H(X3, 1) = 30 THEN 2885
2875 LET L1$ = "ret 0"
2880 GOSUB 7695
2885 CALL "io_put": 2, F9$
2890 FOR I = 1 TO S5
2895 CALL "io_put": 2, "slot s" & STR$(I) & " " & STR$(B(I, 1)) & " " & STR$(B(I, 2))
2900 NEXT I
2905 FOR I = 1 TO L0
2910 CALL "io_put": 2, L$(I)
2915 NEXT I
2920 CALL "io_put": 2, "endfunc"
2925 RETURN
2930 REM ---- 2935: Z5 = the number of results of type T1 and Z5$ = " c1 c2 ..." their classes --
2935 LET Z5 = 0
2940 LET Z5$ = ""
2945 IF T1 = 1 THEN 3015
2950 IF T1 > 9 THEN 2975
2955 GOSUB 7395
2960 LET Z5 = 1
2965 LET Z5$ = " " & SEG$("ifp", C1, C1)
2970 GOTO 3015
2975 IF T(T1, 1) >= 5 THEN 3015
2977 IF T(T1, 1) <> 2 THEN 2955
2980 LET Z6 = T1
2985 FOR X6 = 1 TO T(Z6, 2)
2990 LET T1 = M(T(Z6, 3) + X6 - 1)
2992 IF T1 <= 9 THEN 2995
2993 IF T(T1, 1) >= 5 THEN 3005
2995 GOSUB 7395
3000 LET Z5$ = Z5$ & " " & SEG$("ifp", C1, C1)
3002 LET Z5 = Z5 + 1
3005 NEXT X6
3015 RETURN
3020 REM ==== the frame machine ======================================================================
3025 REM 3030: lower node X1 with dest D1 (the caller has stored its resume code in its frame)
3030 LET W0 = W0 + 6
3035 LET W(W0) = X1
3040 LET W(W0 + 1) = D1
3045 LET W(W0 + 2) = 0
3050 LET W(W0 + 3) = 0
3055 LET W(W0 + 4) = 0
3060 LET W(W0 + 5) = 0
3065 LET X = X1
3070 LET D = D1
3071 GOSUB 40740
3072 IF H(X, 1) > 32 THEN 9705
3075 ON H(X, 1) GOTO 3140, 3210, 3175, 3250, 3310, 3435, 3490, 3575, 4150, 4450, 3080, 4985, 3080, 3080, 3080, 3080, 4025, 3080, 5645, 5710, 5735, 6045, 6070, 5850, 6395, 6515, 6650, 7060, 7070, 7100, 7220, 7320
3080 GOTO 2365
3085 REM 3090: the node of the top frame is done, its value in R9; resume the frame below it
3090 GOSUB 10450
3091 LET W0 = W0 - 6
3095 IF W0 = 0 THEN 2820
3100 LET X = W(W0)
3105 LET D = W(W0 + 1)
3110 LET S = W(W0 + 2)
3112 IF S > 38 THEN 9715
3115 IF S > 20 THEN 3125
3120 ON S GOTO 3445, 3500, 3595, 3620, 3850, 3915, 4035, 16360, 16400, 4160, 4500, 5080, 5400, 5510, 5535, 5695, 15360, 15230, 5835, 5995
3125 ON S - 20 GOTO 16210, 3090, 6180, 15010, 6285, 6405, 6460, 6495, 6545, 6620, 6680, 6705, 6775, 7025, 7135, 7305, 7350, 8620
