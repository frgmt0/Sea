100 REM ====================================================================================
105 REM sealower -- pass 3a: sea.hir -> sea.lir1 (docs/DESIGN.md 2.1, 3.5, 3.6). Phase 1: the
110 REM canonical lowering of scalar code (DESIGN 3.6.6 rules 1-12); no call is inlined (3.6.6).
115 REM Built as DESIGN 2.6.3 says: this file, the modules io diag tables, the DATA blocks errors
120 REM exits consts entries records, and 99999 END. Exit status: 0, 10 (program too large, 2.7),
125 REM 11 (internal error: truncated input, bad header, bad record, bad tree; DESIGN 2.2).
130 REM Reads all of sea.hir into tables; lowers each function in file order into L$ (its slot
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
210 REM   30 ret 31 tret 32 block; records 33 fn 34 par 35 loc 36 end 37 tvec 38 ttuple.
215 REM Dest D of a node (rules 2, 3): 0 a new register; 1..N7 the register of a local; above N7
220 REM   a given new register R; -1 a call whose results are discarded (nr 0); -2 a call whose
225 REM   result registers are the top of U (tbind, tasg, tret). Registers are virtual numbers
230 REM   (locals 1..N7 = their lid) numbered for output on first appearance (3.6.1).
235 REM ====================================================================================
240 FILES "sea.hir"; "sea.lir1"
245 DIM E(299), E$(299,5), Q(20), Q$(20), K(299,4), K$(299), Y(9), Y$(9,5), Z(8), I(40), L(4)
250 DIM N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), G$(300), H$(100)
255 DIM H(99999,8), G(49999,8), A(99999,2), T(19999,3), M(199999), S$(199999), A$(2)
260 DIM V(199999,2), W(599999), U(199999,2), D(49999,2), B(9999,2), J(9999), P(131071)
265 DIM L$(199999)
270 LET P$ = "sealower"
275 REM ---- the tables (canonical order: errors exits consts entries records) ----------------
280 CALL "tb_errors": P$, E(), E$(), 299, E0
285 CALL "tb_exits": P$, E(), E$(), E0, Q(), Q$(), 20, N9
290 CALL "tb_consts": P$, E(), E$(), E0, K(), K$(), 299, K0
295 CALL "tb_entries": P$, E(), E$(), E0, Y(), Y$(), 9, Y0
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
520 REM the tables above are DIMmed for these limits
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
660 LET K2$ = "|tbind=21|eval=22|asg=23|tasg=24|if=25|while=26|forr=27|break=28|cont=29|ret=30|tret=31|block=32|fn=33|par=34|loc=35|end=36|tvec=37|ttuple=38|"
665 LET K1$ = K1$ & K2$
670 FOR I = 1 TO Z(7)
675 LET R(I, 0) = 0
680 IF R(I, 1) = 2 THEN 690
685 IF R(I, 1) <> 4 THEN 705
690 LET P1 = POS(K1$, "|" & R$(I) & "=")
695 IF P1 = 0 THEN 705
700 LET R(I, 0) = VAL(SEG$(K1$, P1 + LEN(R$(I)) + 2, P1 + LEN(R$(I)) + 3))
705 NEXT I
710 REM ==== reading sea.hir ===================================================================
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
815 REM a capacity overflow met at a record without a position is reported at the next one with one
820 IF Q8 = 0 THEN 840
825 IF P8$ = "" THEN 840
830 LET Q2$ = P8$
835 GOTO 2375
840 IF K > 32 THEN 1300
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
910 IF K > 19 THEN 920
915 LET H(H1, 4) = I(2)
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
985 ON K GOTO 995, 995, 1015, 995, 1015, 1285, 1070, 1095, 1135, 1025, 1285, 1155, 1040, 995, 1180, 1025, 1285, 1285, 1040, 1050, 1200, 1285, 1255, 1060, 1050, 1285, 1050, 1285, 1285, 1060, 1285, 1060
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
1175 GOTO 1285
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
1315 IF I(1) <> Y9 + 1 THEN 2360
1320 LET Y9 = I(1)
1325 IF Y9 <= 19999 THEN 1340
1330 LET P8$ = "types"
1335 GOTO 1285
1340 LET T(Y9, 1) = 1
1345 GOTO 1285
1350 IF G0 > 0 THEN 2360
1355 IF I(1) <> Y9 + 1 THEN 2360
1360 LET Y9 = I(1)
1365 IF Y9 > 19999 THEN 1415
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
1535 LET P7 = I(5)
1540 LET L7 = I(6)
1545 GOTO 1285
1550 IF F7 = 0 THEN 2365
1555 IF P7 = 0 THEN 2365
1560 LET P7 = P7 - 1
1565 LET Q2 = 0
1570 IF G$(4) = "val" THEN 1610
1575 LET Q2 = 1
1580 GOTO 1610
1585 IF F7 = 0 THEN 2365
1590 IF P7 > 0 THEN 2365
1595 IF L7 = 0 THEN 2365
1600 LET L7 = L7 - 1
1605 LET Q2 = 0
1610 IF A0 < 99999 THEN 1625
1615 LET P8$ = "symbols"
1620 GOTO 1285
1625 LET A0 = A0 + 1
1630 LET A(A0, 1) = I(2)
1635 LET A(A0, 2) = Q2
1640 GOTO 1285
1645 REM end pops the body block; the stack is then empty (3.3)
1650 IF F7 = 0 THEN 2365
1655 IF P7 + L7 > 0 THEN 2365
1660 IF W1 <> 1 THEN 2365
1665 IF H(W(1), 1) <> 32 THEN 2365
1670 LET G(G0, 8) = W(1)
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
1805 GOSUB 7320
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
2460 GOSUB 7320
2465 LET V(I, 1) = C1
2470 IF A(G(F0, 0) + I, 2) = 0 THEN 2480
2475 LET V(I, 1) = 3
2480 LET V(I, 2) = 0
2485 NEXT I
2490 LET V0 = N7
2495 LET V9 = N7
2500 LET M7 = 0
2505 LET L0 = 0
2510 LET O7 = 0
2515 LET Q7 = 0
2520 LET B7 = 0
2525 LET S5 = 0
2530 LET J0 = 0
2535 LET U0 = 0
2540 LET S7 = 0
2545 LET X = G(F0, 8)
2550 REM rule 12 snapshots: in one statement (its expressions; an if, while or forr only its
2555 REM condition or range), a read of a local L before a ref argument of L is flagged H(.,6) = 1
2560 REM (an lv's own column 6 is free); the read then copies L into a new register
2565 LET N3 = G(F0, 8)
2570 IF H(N3, 7) = 0 THEN 2585
2575 LET N3 = H(N3, 7)
2580 GOTO 2570
2585 FOR N4 = N3 TO G(F0, 8)
2590 IF H(N4, 1) < 20 THEN 2720
2595 IF H(N4, 1) > 31 THEN 2720
2600 IF H(N4, 7) = 0 THEN 2720
2605 LET B5 = N4 - 1
2610 IF H(N4, 1) < 25 THEN 2625
2615 IF H(N4, 1) > 27 THEN 2625
2620 LET B5 = H(N4, 7)
2625 LET A5 = N4
2630 IF H(A5, 7) = 0 THEN 2645
2635 LET A5 = H(A5, 7)
2640 GOTO 2630
2645 FOR K5 = A5 TO B5
2650 IF H(K5, 1) <> 11 THEN 2715
2655 LET C5 = H(K5, 7)
2660 IF H(C5, 1) <> 5 THEN 2715
2665 LET L5 = H(C5, 5)
2670 IF V(L5, 1) = 3 THEN 2715
2675 FOR J5 = A5 TO K5 - 1
2680 IF H(J5, 1) <> 5 THEN 2710
2685 IF H(J5, 5) <> L5 THEN 2710
2690 REM the lv of another rarg is not a read
2695 IF H(J5 + 1, 1) <> 11 THEN 2705
2700 IF H(J5 + 1, 7) = J5 THEN 2710
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
2755 LET F9$ = F9$ & " " & STR$(F1) & ":" & STR$(L1) & ":" & STR$(G(F0, 7)) & " " & STR$(N6)
2760 FOR I = 1 TO N6
2765 LET V1 = I
2770 GOSUB 7425
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
2880 GOSUB 7620
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
2955 GOSUB 7320
2960 LET Z5 = 1
2965 LET Z5$ = " " & SEG$("ifp", C1, C1)
2970 GOTO 3015
2975 IF T(T1, 1) <> 2 THEN 2360
2980 LET Z6 = T1
2985 FOR X6 = 1 TO T(Z6, 2)
2990 LET T1 = M(T(Z6, 3) + X6 - 1)
2995 GOSUB 7320
3000 LET Z5$ = Z5$ & " " & SEG$("ifp", C1, C1)
3005 NEXT X6
3010 LET Z5 = T(Z6, 2)
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
3075 ON H(X, 1) GOTO 3140, 3210, 3175, 3250, 3310, 3435, 3490, 3575, 4150, 4450, 3080, 4985, 3080, 3080, 3080, 3080, 4025, 3080, 5645, 5710, 5735, 6045, 6070, 5850, 6395, 6515, 6645, 6985, 6995, 7025, 7145, 7245
3080 GOTO 2365
3085 REM 3090: the node of the top frame is done, its value in R9; resume the frame below it
3090 LET W0 = W0 - 6
3095 IF W0 = 0 THEN 2820
3100 LET X = W(W0)
3105 LET D = W(W0 + 1)
3110 LET S = W(W0 + 2)
3115 IF S > 20 THEN 3125
3120 ON S GOTO 3445, 3500, 3595, 3620, 3850, 3915, 4035, 4100, 4130, 4160, 4500, 5080, 5400, 5510, 5535, 5695, 3090, 3090, 5835, 5995
3125 ON S - 20 GOTO 3090, 3090, 6180, 6275, 6285, 6405, 6460, 6495, 6545, 6620, 6675, 6700, 6770, 6960, 7060, 7230, 7275
3130 REM ==== the nodes (state 0) and their resume points ============================================
3135 REM ---- constants: li / lf into the dest or a new register (rules 1, 3) ----------------------
3140 LET C1 = 1
3145 GOSUB 7395
3150 GOSUB 7790
3155 LET V1 = D2
3160 GOSUB 7425
3165 LET L1$ = "li " & Z$ & " " & S$(H(X, 0))
3170 GOTO 3290
3175 LET C1 = 1
3180 GOSUB 7395
3185 GOSUB 7790
3190 LET V1 = D2
3195 GOSUB 7425
3200 LET L1$ = "li " & Z$ & " " & STR$(H(X, 5))
3205 GOTO 3290
3210 LET C1 = 2
3215 GOSUB 7395
3220 GOSUB 7790
3225 LET V1 = D2
3230 GOSUB 7425
3235 LET L1$ = "lf " & Z$ & " " & S$(H(X, 0))
3240 GOTO 3290
3245 REM a string constant: a str data record and la (rule 7)
3250 LET C1 = 3
3255 GOSUB 7395
3260 LET Q3 = 1
3265 LET Q4 = X
3270 GOSUB 7860
3275 LET V1 = D2
3280 GOSUB 7425
3285 LET L1$ = "la " & Z$ & " d" & STR$(D0)
3290 GOSUB 7620
3295 LET R9 = D2
3300 GOTO 3090
3305 REM ---- lv: no instruction (rule 1), mov into a dest (rule 2), a load for a ref parameter -----
3310 LET A1 = H(X, 5)
3315 IF V(A1, 1) = 3 THEN 3385
3320 LET R9 = A1
3325 IF D > 0 THEN 3355
3330 IF H(X, 6) = 0 THEN 3090
3335 REM a snapshot (rule 12): mov T L into a new register
3340 LET C1 = V(A1, 1)
3345 GOSUB 7345
3350 LET D = N2
3355 LET O$ = "mov"
3360 LET V2 = D
3365 LET V3 = A1
3370 GOSUB 7465
3375 LET R9 = D
3380 GOTO 3090
3385 LET T1 = A(G(F0, 0) + A1, 1)
3390 GOSUB 7320
3395 GOSUB 7395
3400 LET V2 = D2
3405 LET V3 = A1
3410 LET Z3 = 0
3415 GOSUB 7565
3420 LET R9 = D2
3425 GOTO 3090
3430 REM ---- cvt: itof (rule 1) --------------------------------------------------------------------
3435 LET S = 1
3440 GOTO 7295
3445 LET C1 = 2
3450 GOSUB 7395
3455 LET O$ = "itof"
3460 LET V2 = D2
3465 LET V3 = R9
3470 GOSUB 7465
3475 LET R9 = D2
3480 GOTO 3090
3485 REM ---- un: inegc (i64, checked), fneg, bnot (rule 1) -----------------------------------------
3490 LET S = 2
3495 GOTO 7295
3500 LET T1 = H(X, 4)
3505 GOSUB 7320
3510 GOSUB 7395
3515 LET V2 = D2
3520 LET V3 = R9
3525 LET O$ = "bnot"
3530 IF H(X, 5) = 2 THEN 3555
3535 LET O$ = "fneg"
3540 IF C1 = 2 THEN 3555
3545 LET O$ = "inegc"
3550 GOSUB 7700
3555 GOSUB 7465
3560 LET R9 = D2
3565 GOTO 3090
3570 REM ---- bin: left, right, one instruction (rules 1, 11); && and || by rule 3 -------------------
3575 IF H(X, 5) = 16 THEN 3820
3580 IF H(X, 5) = 17 THEN 3820
3585 LET S = 3
3590 GOTO 7295
3595 LET W(W0 + 3) = R9
3600 LET S = 4
3605 LET X1 = H(H(X, 7), 8)
3610 LET D1 = 0
3615 GOTO 7305
3620 LET A1 = W(W0 + 3)
3625 LET A2 = R9
3630 LET A3 = H(X, 5)
3635 LET T1 = H(H(X, 7), 4)
3640 GOSUB 7320
3645 LET C2 = C1
3650 LET T1 = H(X, 4)
3655 GOSUB 7320
3660 GOSUB 7395
3665 LET V2 = D2
3670 LET V3 = A1
3675 LET V4 = A2
3680 IF A3 > 18 THEN 2360
3685 ON A3 GOTO 3690, 3690, 3690, 3720, 3735, 2360, 2360, 3760, 3760, 3760, 3760, 3760, 3760, 3785, 3795, 2360, 2360, 2360
3690 LET O$ = SEG$("faddfsubfmul", 4 * A3 - 3, 4 * A3)
3695 IF C2 = 2 THEN 3800
3700 IF C2 <> 1 THEN 2360
3705 LET O$ = SEG$("iaddcisubcimulc", 5 * A3 - 4, 5 * A3)
3710 GOSUB 7700
3715 GOTO 3800
3720 IF C2 <> 2 THEN 2360
3725 LET O$ = "fdiv"
3730 GOTO 3800
3735 IF C2 <> 1 THEN 2360
3740 IF H(H(X, 7), 4) <> 3 THEN 2360
3745 LET O$ = "imodf"
3750 GOSUB 7700
3755 GOTO 3800
3760 LET O$ = "icmp " & S$(H(X, 0))
3765 IF C2 = 1 THEN 3800
3770 IF C2 <> 2 THEN 2360
3775 LET O$ = "fcmp " & S$(H(X, 0))
3780 GOTO 3800
3785 LET O$ = "iand"
3790 GOTO 3800
3795 LET O$ = "ior"
3800 GOSUB 7500
3805 LET R9 = D2
3810 GOTO 3090
3815 REM && / ||: R = a; if (&&) or ifz (||) B R; R = b; endif B; a local dest then gets mov L R
3820 GOSUB 3985
3825 LET W(W0 + 3) = D2
3830 LET S = 5
3835 LET X1 = H(X, 7)
3840 LET D1 = D2
3845 GOTO 7305
3850 GOSUB 7810
3855 LET W(W0 + 4) = B7
3860 LET L1$ = "ifz " & STR$(B7) & " "
3865 IF H(X, 5) = 17 THEN 3875
3870 LET L1$ = "if " & STR$(B7) & " "
3875 LET V1 = W(W0 + 3)
3880 GOSUB 7425
3885 LET L1$ = L1$ & Z$
3890 GOSUB 7620
3895 LET S = 6
3900 LET X1 = H(H(X, 7), 8)
3905 LET D1 = W(W0 + 3)
3910 GOTO 7305
3915 LET L1$ = "endif " & STR$(W(W0 + 4))
3920 GOSUB 7620
3925 GOTO 3935
3930 REM the value R of an ifx / && / ||: a new register, or the given one; a local gets mov L R
3935 LET R9 = W(W0 + 3)
3940 IF D < 1 THEN 3090
3945 IF D > N7 THEN 3090
3950 LET O$ = "mov"
3955 LET V2 = D
3960 LET V3 = R9
3965 GOSUB 7465
3970 LET R9 = D
3975 GOTO 3090
3980 REM 3985: D2 = R, a new register of the node's class unless D is a given new register
3985 LET D2 = D
3990 IF D > N7 THEN 4015
3995 LET T1 = H(X, 4)
4000 GOSUB 7320
4005 GOSUB 7345
4010 LET D2 = N2
4015 RETURN
4020 REM ---- ifx: c; if B c; R = then; else B; R = else; endif B (rule 3) ---------------------------
4025 LET S = 7
4030 GOTO 7295
4035 GOSUB 7810
4040 LET W(W0 + 4) = B7
4045 LET L1$ = "if " & STR$(B7) & " "
4050 LET V1 = R9
4055 GOSUB 7425
4060 LET L1$ = L1$ & Z$
4065 GOSUB 7620
4070 GOSUB 3985
4075 LET W(W0 + 3) = D2
4080 LET S = 8
4085 LET X1 = H(H(X, 7), 8)
4090 LET D1 = D2
4095 GOTO 7305
4100 LET L1$ = "else " & STR$(W(W0 + 4))
4105 GOSUB 7620
4110 LET S = 9
4115 LET X1 = H(H(H(X, 7), 8), 8)
4120 LET D1 = W(W0 + 3)
4125 GOTO 7305
4130 LET L1$ = "endif " & STR$(W(W0 + 4))
4135 GOSUB 7620
4140 GOTO 3935
4145 REM ---- powk: x^0 = 1, x^1 = x, x^2 = x*x, x^3 = (x*x)*x, x^4 = (x*x)*(x*x), x^-k = 1/x^k --
4150 LET S = 10
4155 GOTO 7295
4160 LET A1 = R9
4165 LET A3 = H(X, 5)
4170 LET A2 = ABS(A3)
4175 IF A2 > 4 THEN 2360
4180 LET C1 = 2
4185 GOSUB 7395
4190 IF A3 <> 0 THEN 4230
4195 LET V1 = D2
4200 GOSUB 7425
4205 GOSUB 7790
4210 LET L1$ = "lf " & Z$ & " #3FF0000000000000"
4215 GOSUB 7620
4220 GOTO 4430
4225 REM A4 = the register of x^|k|: D2 itself for k > 0
4230 LET A4 = D2
4235 IF A3 > 0 THEN 4260
4240 LET A4 = A1
4245 IF A2 = 1 THEN 4370
4250 GOSUB 7345
4255 LET A4 = N2
4260 IF A2 > 1 THEN 4290
4265 LET O$ = "mov"
4270 LET V2 = A4
4275 LET V3 = A1
4280 GOSUB 7465
4285 GOTO 4370
4290 LET O$ = "fmul"
4295 LET V2 = A4
4300 IF A2 = 2 THEN 4315
4305 GOSUB 7345
4310 LET V2 = N2
4315 LET V3 = A1
4320 LET V4 = A1
4325 GOSUB 7500
4330 IF A2 = 2 THEN 4370
4335 LET V3 = V2
4340 LET V4 = A1
4345 IF A2 = 3 THEN 4355
4350 LET V4 = V2
4355 LET V2 = A4
4360 GOSUB 7500
4365 REM a negative k: 1 / x^|k|
4370 IF A3 > 0 THEN 4430
4375 GOSUB 7345
4380 LET V1 = N2
4385 GOSUB 7425
4390 GOSUB 7790
4395 LET L1$ = "lf " & Z$ & " #3FF0000000000000"
4400 GOSUB 7620
4405 LET O$ = "fdiv"
4410 LET V2 = D2
4415 LET V3 = N2
4420 LET V4 = A4
4425 GOSUB 7500
4430 LET R9 = D2
4435 GOTO 3090
4440 REM ---- call: the arguments left to right (rarg by rule 12), call, the reloads (rules 2, 5) ---
4445 REM frame: x1 = U0 at entry (the arguments are U(x1+1 ..)), x2 = the next argument
4450 IF H(X, 5) > G0 THEN 2360
4455 LET W(W0 + 3) = U0
4460 LET W(W0 + 4) = H(X, 7)
4465 LET X2 = W(W0 + 4)
4470 IF X2 = 0 THEN 4660
4475 IF H(X2, 1) = 11 THEN 4515
4480 LET S = 11
4485 LET X1 = X2
4490 LET D1 = 0
4495 GOTO 7305
4500 LET Q5 = 0
4505 GOTO 4630
4510 REM a rarg of a local L: its ref parameter register, or a slot holding L, reloaded later
4515 LET X3 = H(X2, 7)
4520 IF H(X3, 1) <> 5 THEN 2360
4525 LET A1 = H(X3, 5)
4530 LET R9 = A1
4535 LET Q5 = 0
4540 IF V(A1, 1) = 3 THEN 4630
4545 LET Z1 = E7
4550 IF V(A1, 1) = 1 THEN 4560
4555 LET Z1 = E8
4560 LET Z2 = Z1
4565 GOSUB 7830
4570 LET C1 = 3
4575 GOSUB 7345
4580 LET V1 = N2
4585 GOSUB 7425
4590 LET L1$ = "sa " & Z$ & " s" & STR$(S5)
4595 GOSUB 7620
4600 LET V2 = A1
4605 LET V3 = N2
4610 LET Z3 = 0
4615 GOSUB 7575
4620 LET R9 = N2
4625 LET Q5 = A1
4630 GOSUB 7895
4635 LET U(U0, 1) = R9
4640 LET U(U0, 2) = Q5
4645 LET W(W0 + 4) = H(W(W0 + 4), 8)
4650 GOTO 4465
4655 REM the call record; a result register that is also reloaded gets a new register, moved after
4660 LET A1 = W(W0 + 3)
4665 LET T1 = G(H(X, 5), 3)
4670 GOSUB 2935
4675 LET Q6 = Z5
4680 LET R9 = 0
4685 IF D = -1 THEN 4745
4690 IF D = -2 THEN 4750
4695 IF Q6 = 0 THEN 4745
4700 IF Q6 <> 1 THEN 2360
4705 LET C1 = POS("ifp", SEG$(Z5$, 2, 2))
4710 GOSUB 7395
4715 GOSUB 7895
4720 LET U(U0, 1) = D2
4725 LET U(U0, 2) = 0
4730 LET R9 = D2
4735 LET A2 = U0
4740 GOTO 4760
4745 LET Q6 = 0
4750 LET A2 = A1
4755 REM the results are U(A2-Q6+1 .. A2), the arguments U(W(W0+3)+1 .. W(W0+3)+n)
4760 FOR I = A2 - Q6 + 1 TO A2
4765 LET A3 = U(I, 1)
4770 IF A3 > N7 THEN 4810
4775 FOR X6 = W(W0 + 3) + 1 TO W(W0 + 3) + H(X, 6)
4780 IF U(X6, 2) <> A3 THEN 4805
4785 LET C1 = V(A3, 1)
4790 GOSUB 7345
4795 LET U(I, 1) = N2
4800 LET U(I, 2) = A3
4805 NEXT X6
4810 NEXT I
4815 LET L1$ = "call " & S$(G(H(X, 5), 1)) & " " & STR$(Q6)
4820 FOR I = A2 - Q6 + 1 TO A2
4825 LET V1 = U(I, 1)
4830 GOSUB 7425
4835 LET L1$ = L1$ & " " & Z$
4840 NEXT I
4845 LET L1$ = L1$ & " " & STR$(H(X, 6))
4850 FOR I = W(W0 + 3) + 1 TO W(W0 + 3) + H(X, 6)
4855 LET V1 = U(I, 1)
4860 GOSUB 7425
4865 LET L1$ = L1$ & " " & Z$
4870 NEXT I
4875 GOSUB 7620
4880 REM rule 12: reload each slot argument's local, in argument order
4885 FOR I = W(W0 + 3) + 1 TO W(W0 + 3) + H(X, 6)
4890 IF U(I, 2) = 0 THEN 4915
4895 LET V2 = U(I, 2)
4900 LET V3 = U(I, 1)
4905 LET Z3 = 0
4910 GOSUB 7565
4915 NEXT I
4920 REM then the results that had to wait for the reloads
4925 FOR I = A2 - Q6 + 1 TO A2
4930 IF U(I, 2) <= 0 THEN 4965
4935 LET O$ = "mov"
4940 LET V2 = U(I, 2)
4945 LET V3 = U(I, 1)
4950 GOSUB 7465
4955 LET U(I, 1) = V2
4960 LET U(I, 2) = 0
4965 NEXT I
4970 LET U0 = W(W0 + 3)
4975 GOTO 3090
4980 REM ---- lib: printf (rule 8), now (9), f64 and i64 (10), idiv (11) ---------------------------
4985 LET K3$ = "|printf |now    |f64    |i64    |idiv   "
4990 LET W2$ = S$(H(X, 0))
4995 GOSUB 1875
5000 IF W2 = 0 THEN 2360
5005 IF H(X, 6) <> VAL(SEG$("10112", W2, W2)) THEN 2360
5010 ON W2 GOTO 5020, 5335, 5390, 5390, 5500
5015 REM printf: frame x1 = U0 at entry, x2 = the next piece of the fmt
5020 LET X2 = H(X, 7)
5025 IF H(X2, 1) <> 13 THEN 2365
5030 LET W(W0 + 3) = U0
5035 LET W(W0 + 4) = H(X2, 7)
5040 LET X2 = W(W0 + 4)
5045 IF X2 = 0 THEN 5120
5050 IF H(X2, 1) = 14 THEN 5105
5055 IF H(X2, 1) <> 15 THEN 2365
5060 LET S = 12
5065 LET X1 = H(X2, 7)
5070 LET D1 = 0
5075 GOTO 7305
5080 GOSUB 7895
5085 LET U(U0, 1) = R9
5090 LET T1 = H(H(W(W0 + 4), 7), 4)
5095 GOSUB 7320
5100 LET U(U0, 2) = C1
5105 LET W(W0 + 4) = H(W(W0 + 4), 8)
5110 GOTO 5040
5115 REM the slot of SLOT_SIZE * max(n, 1) bytes, one store per argument, la of the fmt, rcall
5120 LET A1 = U0 - W(W0 + 3)
5125 LET Z1 = Z7 * A1
5130 IF A1 > 0 THEN 5140
5135 LET Z1 = Z7
5140 LET Z2 = Z7
5145 GOSUB 7830
5150 LET C1 = 3
5155 GOSUB 7345
5160 LET A2 = N2
5165 LET V1 = A2
5170 GOSUB 7425
5175 LET L1$ = "sa " & Z$ & " s" & STR$(S5)
5180 GOSUB 7620
5185 FOR I = 1 TO A1
5190 LET V2 = U(W(W0 + 3) + I, 1)
5195 LET V3 = A2
5200 LET Z3 = Z7 * (I - 1)
5205 LET O$ = SEG$("stistfstp", 3 * U(W(W0 + 3) + I, 2) - 2, 3 * U(W(W0 + 3) + I, 2))
5210 GOSUB 7580
5215 NEXT I
5220 LET Q3 = 2
5225 LET Q4 = H(X, 7)
5230 GOSUB 7860
5235 LET C1 = 3
5240 GOSUB 7345
5245 LET A3 = N2
5250 LET V1 = A3
5255 GOSUB 7425
5260 LET L1$ = "la " & Z$ & " d" & STR$(D0)
5265 GOSUB 7620
5270 LET Q9 = Y1
5275 GOSUB 5590
5280 LET V1 = A3
5285 GOSUB 7425
5290 LET L1$ = L1$ & " " & STR$(LEN(Y$(Y1, 4))) & " " & Z$
5295 LET V1 = A2
5300 GOSUB 7425
5305 LET L1$ = L1$ & " " & Z$
5310 GOSUB 7620
5315 LET U0 = W(W0 + 3)
5320 LET R9 = 0
5325 GOTO 3090
5330 REM now: rcall of the entry NOW into the dest or a new f register
5335 LET C1 = 2
5340 GOSUB 7395
5345 LET Q9 = Y2
5350 GOSUB 5590
5355 LET V1 = D2
5360 GOSUB 7425
5365 LET L1$ = L1$ & " " & Z$ & " 0"
5370 GOSUB 7620
5375 LET R9 = D2
5380 GOTO 3090
5385 REM f64(x): itof, or mov for an f64; i64(x): ftoi for an f64, else mov
5390 LET S = 13
5395 GOTO 7295
5400 LET T1 = H(H(X, 7), 4)
5405 GOSUB 7320
5410 LET C2 = C1
5415 LET C1 = 1
5420 IF S$(H(X, 0)) = "i64" THEN 5430
5425 LET C1 = 2
5430 GOSUB 7395
5435 LET V2 = D2
5440 LET V3 = R9
5445 LET O$ = "mov"
5450 IF C1 = C2 THEN 5480
5455 IF C2 = 3 THEN 2360
5460 LET O$ = "itof"
5465 IF C1 = 2 THEN 5480
5470 LET O$ = "ftoi"
5475 GOSUB 7700
5480 GOSUB 7465
5485 LET R9 = D2
5490 GOTO 3090
5495 REM idiv(a, b): idivf with the node's line as site
5500 LET S = 14
5505 GOTO 7295
5510 LET W(W0 + 3) = R9
5515 LET S = 15
5520 LET X1 = H(H(X, 7), 8)
5525 LET D1 = 0
5530 GOTO 7305
5535 LET C1 = 1
5540 GOSUB 7395
5545 LET O$ = "idivf"
5550 LET V2 = D2
5555 LET V3 = W(W0 + 3)
5560 LET V4 = R9
5565 GOSUB 7700
5570 GOSUB 7500
5575 LET R9 = D2
5580 GOTO 3090
5585 REM 5590: L1$ = "rcall <symbol> <site or -> <nr>" of entry row Q9; its results go after it
5590 LET L1$ = "rcall " & Y$(Q9, 2) & " -"
5595 IF Y$(Q9, 3) <> "S" THEN 5615
5600 GOSUB 7700
5605 LET L1$ = "rcall " & Y$(Q9, 2) & " " & Z9$
5610 LET S7 = 1
5615 LET Z4 = LEN(Y$(Q9, 5))
5620 IF Y$(Q9, 5) <> "-" THEN 5630
5625 LET Z4 = 0
5630 LET L1$ = L1$ & " " & STR$(Z4)
5635 RETURN
5640 REM ---- seq: the bind nodes in order, then the value in the seq's place (rule 5) -------------
5645 LET W(W0 + 4) = H(X, 7)
5650 LET X2 = W(W0 + 4)
5655 LET X1 = X2
5660 LET D1 = D
5665 IF H(X2, 8) = 0 THEN 5685
5670 LET S = 16
5675 LET D1 = 0
5680 GOTO 7305
5685 LET S = 17
5690 GOTO 7305
5695 LET W(W0 + 4) = H(W(W0 + 4), 8)
5700 GOTO 5650
5705 REM ---- bind: the value with the local as dest (rule 2) ---------------------------------------
5710 LET S = 18
5715 LET X1 = H(X, 7)
5720 LET D1 = H(X, 5)
5725 GOTO 7305
5730 REM ---- tbind: the result registers on U (locals, or new for -), then the call (rule 2) -------
5735 LET X2 = H(X, 7)
5740 LET W(W0 + 3) = U0
5745 LET Z6 = H(X2, 4)
5750 IF Z6 <= 9 THEN 2360
5755 IF T(Z6, 1) <> 2 THEN 2360
5760 IF T(Z6, 2) <> H(X, 6) THEN 2360
5765 FOR I = 1 TO H(X, 6)
5770 GOSUB 7895
5775 LET U(U0, 2) = 0
5780 LET U(U0, 1) = M(H(X, 0) + I - 1)
5785 IF U(U0, 1) > 0 THEN 5810
5790 LET T1 = M(T(Z6, 3) + I - 1)
5795 GOSUB 7320
5800 GOSUB 7345
5805 LET U(U0, 1) = N2
5810 NEXT I
5815 LET S = 19
5820 LET X1 = X2
5825 LET D1 = -2
5830 GOTO 7305
5835 LET U0 = W(W0 + 3)
5840 GOTO 3090
5845 REM ---- tasg: targets lv (a ref parameter: a new register, stored after) or skip (new) ------
5850 LET W(W0 + 3) = U0
5855 LET X2 = H(X, 7)
5860 LET X3 = X2
5865 FOR I = 1 TO H(X, 6)
5870 LET X3 = H(X3, 8)
5875 NEXT I
5880 LET Z6 = H(X3, 4)
5885 IF Z6 <= 9 THEN 2360
5890 IF T(Z6, 1) <> 2 THEN 2360
5895 IF T(Z6, 2) <> H(X, 6) THEN 2360
5900 FOR I = 1 TO H(X, 6)
5905 GOSUB 7895
5910 LET U(U0, 2) = 0
5915 IF H(X2, 1) = 18 THEN 5945
5920 IF H(X2, 1) <> 5 THEN 2360
5925 LET A1 = H(X2, 5)
5930 LET U(U0, 1) = A1
5935 IF V(A1, 1) <> 3 THEN 5965
5940 LET U(U0, 2) = -A1
5945 LET T1 = M(T(Z6, 3) + I - 1)
5950 GOSUB 7320
5955 GOSUB 7345
5960 LET U(U0, 1) = N2
5965 LET X2 = H(X2, 8)
5970 NEXT I
5975 LET S = 20
5980 LET X1 = X3
5985 LET D1 = -2
5990 GOTO 7305
5995 FOR I = W(W0 + 3) + 1 TO U0
6000 IF U(I, 2) >= 0 THEN 6025
6005 LET V2 = U(I, 1)
6010 LET V3 = -U(I, 2)
6015 LET Z3 = 0
6020 GOSUB 7575
6025 NEXT I
6030 LET U0 = W(W0 + 3)
6035 GOTO 3090
6040 REM ---- eval: the expression, a call discarding its results (rule 5) --------------------------
6045 LET S = 21
6050 LET X1 = H(X, 7)
6055 LET D1 = -1
6060 GOTO 7305
6065 REM ---- asg to lv L (rules 2, 12) ------------------------------------------------------------
6070 LET X2 = H(X, 7)
6075 IF H(X2, 1) <> 5 THEN 2360
6080 LET A1 = H(X2, 5)
6085 LET X1 = H(X2, 8)
6090 LET D1 = 0
6095 IF V(A1, 1) = 3 THEN 6205
6100 IF H(X, 5) > 1 THEN 6120
6105 LET S = 22
6110 LET D1 = A1
6115 GOTO 7305
6120 LET W(W0 + 3) = A1
6125 IF H(X2, 6) = 0 THEN 6170
6130 REM a snapshot of the left operand L (rule 12): mov T L before the value
6135 LET C1 = V(A1, 1)
6140 GOSUB 7345
6145 LET O$ = "mov"
6150 LET V2 = N2
6155 LET V3 = A1
6160 GOSUB 7465
6165 LET W(W0 + 3) = N2
6170 LET S = 23
6175 GOTO 7305
6180 LET A1 = H(H(X, 7), 5)
6185 LET A2 = W(W0 + 3)
6190 LET C1 = V(A1, 1)
6195 GOTO 6305
6200 REM a ref parameter: set: the value into a new register, stored; op: load, value, op, store
6205 LET T1 = A(G(F0, 0) + A1, 1)
6210 GOSUB 7320
6215 GOSUB 7345
6220 LET W(W0 + 3) = N2
6225 IF H(X, 5) > 1 THEN 6245
6230 LET S = 24
6235 LET D1 = N2
6240 GOTO 7305
6245 LET V2 = N2
6250 LET V3 = A1
6255 LET Z3 = 0
6260 GOSUB 7565
6265 LET S = 25
6270 GOTO 7305
6275 LET V2 = W(W0 + 3)
6280 GOTO 6370
6285 LET A2 = W(W0 + 3)
6290 LET C1 = V(A2, 1)
6295 GOSUB 7345
6300 LET A1 = N2
6305 LET A3 = H(X, 5) - 1
6310 LET O$ = SEG$("faddfsubfmulfdiv", 4 * A3 - 3, 4 * A3)
6315 IF C1 = 2 THEN 6340
6320 IF C1 <> 1 THEN 2360
6325 IF A3 = 4 THEN 2360
6330 LET O$ = SEG$("iaddcisubcimulc", 5 * A3 - 4, 5 * A3)
6335 GOSUB 7700
6340 LET V2 = A1
6345 LET V3 = A2
6350 LET V4 = R9
6355 GOSUB 7500
6360 IF V(H(H(X, 7), 5), 1) <> 3 THEN 3090
6365 LET V2 = A1
6370 LET V3 = H(H(X, 7), 5)
6375 LET Z3 = 0
6380 GOSUB 7575
6385 GOTO 3090
6390 REM ---- if: c; if B c; then; [else B; else]; endif B (rule 4) --------------------------------
6395 LET S = 26
6400 GOTO 7295
6405 GOSUB 7810
6410 LET W(W0 + 3) = B7
6415 LET L1$ = "if " & STR$(B7) & " "
6420 LET V1 = R9
6425 GOSUB 7425
6430 LET L1$ = L1$ & Z$
6435 GOSUB 7620
6440 LET S = 27
6445 LET X1 = H(H(X, 7), 8)
6450 LET D1 = 0
6455 GOTO 7305
6460 IF H(X, 5) = 0 THEN 6495
6465 LET L1$ = "else " & STR$(W(W0 + 3))
6470 GOSUB 7620
6475 LET S = 28
6480 LET X1 = H(H(H(X, 7), 8), 8)
6485 LET D1 = 0
6490 GOTO 7305
6495 LET L1$ = "endif " & STR$(W(W0 + 3))
6500 GOSUB 7620
6505 GOTO 3090
6510 REM ---- while: do B; c; ifz B2 c; exit B; endif B2; body; enddo B (rule 4) -------------------
6515 GOSUB 7810
6520 LET W(W0 + 3) = B7
6525 LET L1$ = "do " & STR$(B7)
6530 GOSUB 7620
6535 LET S = 29
6540 GOTO 7295
6545 GOSUB 7810
6550 LET L1$ = "ifz " & STR$(B7) & " "
6555 LET V1 = R9
6560 GOSUB 7425
6565 LET L1$ = L1$ & Z$
6570 GOSUB 7620
6575 LET L1$ = "exit " & STR$(W(W0 + 3))
6580 GOSUB 7620
6585 LET L1$ = "endif " & STR$(B7)
6590 GOSUB 7620
6595 GOSUB 7910
6600 LET S = 30
6605 LET X1 = H(H(X, 7), 8)
6610 LET D1 = 0
6615 GOTO 7305
6620 LET J0 = J0 - 1
6625 LET L1$ = "enddo " & STR$(W(W0 + 3))
6630 GOSUB 7620
6635 GOTO 3090
6640 REM ---- forr: lo, hi, st (or li 1); rcount; loop B L lo C st; body; endloop B (rule 4) -------
6645 LET X2 = H(X, 7)
6650 IF H(X2, 1) <> 16 THEN 2365
6655 LET S = 31
6660 LET X1 = H(X2, 7)
6665 LET D1 = 0
6670 GOTO 7305
6675 LET W(W0 + 3) = R9
6680 LET S = 32
6685 LET X1 = H(H(H(X, 7), 7), 8)
6690 LET D1 = 0
6695 GOTO 7305
6700 LET W(W0 + 4) = R9
6705 IF H(H(X, 7), 6) = 0 THEN 6730
6710 LET S = 33
6715 LET X1 = H(H(H(H(X, 7), 7), 8), 8)
6720 LET D1 = 0
6725 GOTO 7305
6730 LET C1 = 1
6735 GOSUB 7345
6740 LET V1 = N2
6745 GOSUB 7425
6750 GOSUB 7790
6755 LET L1$ = "li " & Z$ & " 1"
6760 GOSUB 7620
6765 LET R9 = N2
6770 LET W(W0 + 5) = R9
6775 LET C1 = 1
6780 GOSUB 7345
6785 LET A1 = N2
6790 LET L1$ = "rcount"
6795 LET V1 = A1
6800 GOSUB 7425
6805 LET L1$ = L1$ & " " & Z$
6810 FOR I = 3 TO 5
6815 LET V1 = W(W0 + I)
6820 GOSUB 7425
6825 LET L1$ = L1$ & " " & Z$
6830 NEXT I
6835 GOSUB 7700
6840 LET L1$ = L1$ & " " & STR$(H(H(X, 7), 5)) & " " & Z9$
6845 LET S7 = 1
6850 GOSUB 7620
6855 GOSUB 7810
6860 LET L1$ = "loop " & STR$(B7)
6865 LET V1 = H(X, 5)
6870 GOSUB 7425
6875 LET L1$ = L1$ & " " & Z$
6880 LET V1 = W(W0 + 3)
6885 GOSUB 7425
6890 LET L1$ = L1$ & " " & Z$
6895 LET V1 = A1
6900 GOSUB 7425
6905 LET L1$ = L1$ & " " & Z$
6910 LET V1 = W(W0 + 5)
6915 GOSUB 7425
6920 LET L1$ = L1$ & " " & Z$
6925 GOSUB 7620
6930 LET W(W0 + 3) = B7
6935 GOSUB 7910
6940 LET S = 34
6945 LET X1 = H(H(X, 7), 8)
6950 LET D1 = 0
6955 GOTO 7305
6960 LET J0 = J0 - 1
6965 LET L1$ = "endloop " & STR$(W(W0 + 3))
6970 GOSUB 7620
6975 GOTO 3090
6980 REM ---- break / cont: exit / next of the innermost loop (rule 4) ------------------------------
6985 LET L1$ = "exit "
6990 GOTO 7000
6995 LET L1$ = "next "
7000 IF J0 = 0 THEN 2365
7005 LET L1$ = L1$ & STR$(J(J0))
7010 GOSUB 7620
7015 GOTO 3090
7020 REM ---- ret k: the values, ret k regs (rule 5) ------------------------------------------------
7025 LET W(W0 + 3) = U0
7030 LET W(W0 + 4) = H(X, 7)
7035 IF W(W0 + 4) = 0 THEN 7080
7040 LET S = 35
7045 LET X1 = W(W0 + 4)
7050 LET D1 = 0
7055 GOTO 7305
7060 GOSUB 7895
7065 LET U(U0, 1) = R9
7070 LET W(W0 + 4) = H(W(W0 + 4), 8)
7075 GOTO 7035
7080 GOSUB 7095
7085 GOTO 3090
7090 REM 7095: ret of the registers U(W(W0+3)+1 .. U0); U0 back to W(W0+3)
7095 LET L1$ = "ret " & STR$(U0 - W(W0 + 3))
7100 FOR I = W(W0 + 3) + 1 TO U0
7105 LET V1 = U(I, 1)
7110 GOSUB 7425
7115 LET L1$ = L1$ & " " & Z$
7120 NEXT I
7125 GOSUB 7620
7130 LET U0 = W(W0 + 3)
7135 RETURN
7140 REM ---- tret: the call with a new register per result, ret of them (rule 5) ----------------
7145 LET X2 = H(X, 7)
7150 LET W(W0 + 3) = U0
7155 LET Z6 = H(X2, 4)
7160 IF Z6 <= 9 THEN 2360
7165 IF T(Z6, 1) <> 2 THEN 2360
7170 FOR I = 1 TO T(Z6, 2)
7175 LET T1 = M(T(Z6, 3) + I - 1)
7180 GOSUB 7320
7185 GOSUB 7345
7190 GOSUB 7895
7195 LET U(U0, 1) = N2
7200 LET U(U0, 2) = 0
7205 NEXT I
7210 LET S = 36
7215 LET X1 = X2
7220 LET D1 = -2
7225 GOTO 7305
7230 GOSUB 7095
7235 GOTO 3090
7240 REM ---- block: the statements in order (rule 6: no instruction of its own) -------------------
7245 LET W(W0 + 4) = H(X, 7)
7250 IF W(W0 + 4) = 0 THEN 3090
7255 LET S = 37
7260 LET X1 = W(W0 + 4)
7265 LET D1 = 0
7270 GOTO 7305
7275 LET W(W0 + 4) = H(W(W0 + 4), 8)
7280 GOTO 7250
7285 REM ==== helpers of the frame machine ===========================================================
7290 REM 7295: lower the first child with dest 0 and resume code S; 7305: X1 with dest D1
7295 LET X1 = H(X, 7)
7300 LET D1 = 0
7305 LET W(W0 + 2) = S
7310 GOTO 3030
7315 REM ---- 7320: C1 = the register class of the scalar type T1 (1 i: bool, i64; 2 f; 3 p: str) ---
7320 IF T1 < 2 THEN 2360
7325 IF T1 > 5 THEN 2360
7330 LET C1 = VAL(SEG$("1123", T1 - 1, T1 - 1))
7335 RETURN
7340 REM ---- 7345: N2 = a new register of class C1 -------------------------------------------------
7345 LET Q2$ = "registers"
7350 IF V0 >= 199999 THEN 2390
7355 LET V0 = V0 + 1
7360 LET N2 = V0
7365 LET V(N2, 1) = C1
7370 LET V(N2, 2) = 0
7375 IF V0 <= V9 THEN 7385
7380 LET V9 = V0
7385 RETURN
7390 REM ---- 7395: D2 = the dest D if it is a register, else a new register of class C1 ------------
7395 LET D2 = D
7400 IF D > 0 THEN 7415
7405 GOSUB 7345
7410 LET D2 = N2
7415 RETURN
7420 REM ---- 7425: Z$ = the register V1 as written: its output number is given on first use (3.6.1)
7425 IF V(V1, 2) > 0 THEN 7450
7430 LET Q2$ = "registers"
7435 IF M7 >= R8 THEN 2390
7440 LET M7 = M7 + 1
7445 LET V(V1, 2) = M7
7450 LET Z$ = SEG$("ifp", V(V1, 1), V(V1, 1)) & STR$(V(V1, 2))
7455 RETURN
7460 REM ---- 7465 / 7500: L1$ = O$ and the registers V2 V3 (V4), then the site if S7 = 1; emitted ----
7465 LET V1 = V2
7470 GOSUB 7425
7475 LET L1$ = O$ & " " & Z$
7480 LET V1 = V3
7485 GOSUB 7425
7490 LET L1$ = L1$ & " " & Z$
7495 GOTO 7545
7500 LET V1 = V2
7505 GOSUB 7425
7510 LET L1$ = O$ & " " & Z$
7515 LET V1 = V3
7520 GOSUB 7425
7525 LET L1$ = L1$ & " " & Z$
7530 LET V1 = V4
7535 GOSUB 7425
7540 LET L1$ = L1$ & " " & Z$
7545 IF S7 = 0 THEN 7620
7550 LET L1$ = L1$ & " " & Z9$
7555 GOTO 7620
7560 REM ---- 7565 / 7575: load into V2 / store V2 through the p register V3 + Z3, by V2's class ----
7565 LET O$ = SEG$("ldildfldp", 3 * V(V2, 1) - 2, 3 * V(V2, 1))
7570 GOTO 7580
7575 LET O$ = SEG$("stistfstp", 3 * V(V2, 1) - 2, 3 * V(V2, 1))
7580 LET V1 = V2
7585 GOSUB 7425
7590 LET L1$ = O$ & " " & Z$
7595 LET V1 = V3
7600 GOSUB 7425
7605 LET L1$ = L1$ & " " & Z$ & " - 0 " & STR$(Z3)
7610 GOTO 7620
7615 REM ---- 7620: append L1$ to the function's records; S7 = 1 if it ends with a site ----------
7620 LET Q2$ = "instructions"
7625 IF L0 >= I9 THEN 2390
7630 LET L0 = L0 + 1
7635 LET L$(L0) = L1$
7640 LET P2 = 0
7645 LET Z4 = 0
7650 LET P2 = POS(L1$, " ", P2 + 1)
7655 IF P2 = 0 THEN 7670
7660 LET Z4 = Z4 + 1
7665 GOTO 7650
7670 LET O7 = O7 + Z4 - S7
7675 LET S7 = 0
7680 LET Q2$ = "operands"
7685 IF O7 > O9 THEN 2390
7690 RETURN
7695 REM ---- 7700: Z9$ = the site F:L of node X, S7 = 1; counts the distinct sites (2.7) ---------
7700 LET F1 = INT(H(X, 2) / 1E9)
7705 LET L1 = H(X, 2) - F1 * 1E9
7710 LET Z9$ = STR$(F1) & ":" & STR$(L1)
7715 LET S7 = 1
7720 LET Z4 = H(X, 2) - INT(H(X, 2) / 131071) * 131071
7725 IF P(Z4) = 0 THEN 7755
7730 IF P(Z4) = H(X, 2) + 1 THEN 7775
7735 LET Z4 = Z4 + 1
7740 IF Z4 < 131071 THEN 7725
7745 LET Z4 = 0
7750 GOTO 7725
7755 LET Q2$ = "sites"
7760 IF S8 >= Z8 THEN 2390
7765 LET S8 = S8 + 1
7770 LET P(Z4) = H(X, 2) + 1
7775 RETURN
7780 REM ---- 7790 / 7810 / 7830 / 7860: count an li / lf; a new block B7; a new slot S5 of Z1
7785 REM bytes, alignment Z2; a new data label D0 of kind Q3 for node Q4 -----------------------
7790 LET Q2$ = "immediates"
7795 IF Q7 >= M9 THEN 2390
7800 LET Q7 = Q7 + 1
7805 RETURN
7810 LET Q2$ = "blocks"
7815 IF B7 >= B9 THEN 2390
7820 LET B7 = B7 + 1
7825 RETURN
7830 LET Q2$ = "slots"
7835 IF S5 >= S9 THEN 2390
7840 LET S5 = S5 + 1
7845 LET B(S5, 1) = Z1
7850 LET B(S5, 2) = Z2
7855 RETURN
7860 LET Q2$ = "labels"
7865 IF D0 >= D9 THEN 2390
7870 LET D0 = D0 + 1
7875 LET D(D0, 1) = Q3
7880 LET D(D0, 2) = Q4
7885 RETURN
7890 REM ---- 7895 / 7910: one more entry on U (registers) / J (open loops, block B7) ---------
7895 IF U0 >= 199999 THEN 2365
7900 LET U0 = U0 + 1
7905 RETURN
7910 LET J0 = J0 + 1
7915 LET J(J0) = W(W0 + 3)
7920 RETURN
