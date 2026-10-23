100 REM ====================================================================================
105 REM sealoop -- pass 3a, first program: sea.hir -> sea.hirl (docs/DESIGN.md 2.1, 2.7, 3.5.9)
110 REM Rewrites the array constructs into explicit scalar HIR: 4e-0's L1-L4 (zeros ones filled
115 REM len rows cols numel, fore) and 4e's L5-L11 (selection reads and folded views, selection
120 REM stores and compound stores, element-wise operations, range values, numeric literals and
125 REM concatenation, materialized views, dyn, fix, ind2sub with an array k), 4f's L13-L14. Others
130 REM are copied unchanged, so a file without those constructs is sea.hir byte for byte. Built
135 REM as DESIGN 2.6.3 says: the files lp0main lp1walk lp2out lp3sel lp4ew lp5lit lp6tup lp7red,
140 REM the modules io diag tables, the DATA blocks errors exits consts records, 99999 END. Exit:
145 REM 0; 10 program too large (nodes, symbols, types of sea.hirl as a whole, 3.5.9); 11
150 REM internal error (truncated input, bad header, bad record, bad tree; DESIGN 2.2). Steps:
155 REM (A) lp0main reads and validates all of sea.hir; (B) lp1walk visits the records in file
160 REM order and builds the output as a linked list, the rewrites (lp1walk, lp3sel, lp4ew,
165 REM lp5lit) inserting their records; (C) lp2out numbers the new locals and tptr types, writes.
170 REM Tables: D$ the body records as read (r = 1..D0); P(r,0) its records row, P(r,1) its node
175 REM   (for fn its function); H nodes (0 the output row before its subtree, 1 kind, 2 ty or 0,
180 REM   3 first child, 4 next sibling, 5 fore lid, lib n, dol: link of the unclaimed dols then
185 REM   its idx, idx: the local of its base, block: statements added, 6 its record row, 7 and 8
190 REM   the first and last output row of its subtree); W the tree stack, after (A) the parents;
195 REM   G functions (1 locals base in A, 2 np, 3 nl, 4 new locals, 5 their first entry in
200 REM   U(.,5), 6 fn record r); A local types; T types (0 n or rows of a fixed type, 1 rank 1 2,
205 REM   0 a ttuple, 2 element, 3 fixed 1 (ttuple: its first component), 4 cols (ttuple: the
210 REM   second)); O output rows (0 the next row, row 0 the head; 1 the record r copied, or 0:
215 REM   generated, text in O$); U new locals (1 type, -e the tptr of e, 2 mut 0 let 1 for, 3 the
220 REM   record whose pos is its loc pos, 4 lid, 5 the locals in declaring order); Y(e) the tptr
222 REM   of element type e (2 bool 3 i64 4 f64): 0 none, 1 used, else its id; S(e) the element
224 REM   size; V the script variables (lp1walk 9000), M the open blocks of a script (1 count, 2
226 REM   the loop local or 0). Kinds (R(i,0) per records row): 1 ci 2 cf 3 cb 4 cs 5 lv 6 cvt 7
228 REM   un 8 bin 9 powk 10 call 11 rarg 12 lib 13 fmt 14 ftext 15 fconv 16 rng 17 ifx 18 skip
230 REM   19 seq 20 bind 21 tbind 22 eval 23 asg 24 tasg 25 if 26 while 27 forr 28 break 29 cont
232 REM   30 ret 31 tret 32 block 39 idx 40 dol 41 fore 43 dyn 44 fix 45 view 46 all 47 arr 48
234 REM   row (nodes); 33 fn 34 par 35 loc 36 end 37 tvec 38 ttuple 42 tmat 49 tfvec 50 tfmat.
240 REM ====================================================================================
245 FILES "sea.hir"; "sea.hirl"
250 DIM E(299), E$(299,5), Q(20), Q$(20), K(299,4), K$(299), Z(8), I(40), L(4), A$(2), Y(4), S(4)
255 DIM N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), G$(300), H$(100)
260 DIM H(99999,8), G(49999,6), A(99999), T(20008,4), W(99999), P(349999,1), D$(349999)
265 DIM O(449999,1), O$(449999), U(49999,5), V(499), M(99,2), D(64,1)
270 LET P$ = "sealoop"
275 REM ---- the tables (canonical order: errors exits consts records) --------------------------
280 CALL "tb_errors": P$, E(), E$(), 299, E0
285 CALL "tb_exits": P$, E(), E$(), E0, Q(), Q$(), 20, N9
290 CALL "tb_consts": P$, E(), E$(), E0, K(), K$(), 299, K0
295 LET Z(1) = 39
300 LET Z(2) = 299
305 LET Z(3) = 399
310 LET Z(4) = 1499
315 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), R(), R$(), F(), F$(), Z()
320 LET Q1$ = "FILE_VERSION"
325 GOSUB 1850
330 LET V8 = Q1
335 LET Q1$ = "LIM_NODES"
340 GOSUB 1850
345 LET N8 = Q1
350 LET Q1$ = "LIM_SYMBOLS"
355 GOSUB 1850
360 LET S8 = Q1
365 LET Q1$ = "LIM_TYPES"
370 GOSUB 1850
375 LET T9 = Q1 + 9
380 LET Q1$ = "ESIZE_BOOL"
385 GOSUB 1850
390 LET S(2) = Q1
395 LET Q1$ = "ESIZE_I64"
400 GOSUB 1850
405 LET S(3) = Q1
410 LET Q1$ = "ESIZE_F64"
415 GOSUB 1850
420 LET S(4) = Q1
421 LET Q1$ = "SHAPE_VEC"
422 GOSUB 1850
423 LET V(59) = Q1
424 LET Q1$ = "LIM_EXTENT"
425 GOSUB 1850
426 LET X9 = Q1 - 1
427 GOSUB 2800
428 LET Z4$ = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
429 LET Z5$ = "abcejklnqrstuwxIMNWXY"
430 IF N8 > 99999 THEN 445
435 IF S8 > 49999 THEN 445
440 IF T9 <= 20008 THEN 455
445 CALL "dg_bug": P$, "a capacity limit is larger than the pass's tables"
450 REM ---- R(i,0) = the kind of every record row of sea.hir that 4d implements, else 0 ---------
455 LET K1$ = "|ci=01|cf=02|cb=03|cs=04|lv=05|cvt=06|un=07|bin=08|powk=09|call=10|rarg=11|lib=12|fmt=13|ftext=14|fconv=15|rng=16|ifx=17|skip=18|seq=19|bind=20|"
460 LET K2$ = "|tbind=21|eval=22|asg=23|tasg=24|if=25|while=26|forr=27|break=28|cont=29|ret=30|tret=31|block=32|fn=33|par=34|loc=35|end=36|tvec=37|ttuple=38|"
465 LET K1$ = K1$ & K2$ & "|idx=39|dol=40|fore=41|tmat=42|"
467 LET K1$ = K1$ & "|dyn=43|fix=44|view=45|all=46|arr=47|row=48|tfvec=49|tfmat=50|"
470 FOR I = 1 TO Z(7)
475 LET R(I, 0) = 0
480 IF R(I, 1) = 2 THEN 490
485 IF R(I, 1) <> 4 THEN 505
490 LET P1 = POS(K1$, "|" & R$(I) & "=")
495 IF P1 = 0 THEN 505
500 LET R(I, 0) = VAL(SEG$(K1$, P1 + LEN(R$(I)) + 2, P1 + LEN(R$(I)) + 3))
505 NEXT I
510 REM the library functions of L1-L3 in the order of their codes (lp1walk), the elemental ones, L13-L14 (lp7red)
515 LET K3$ = "|zeros  |ones   |filled |len    |rows   |cols   |numel  "
517 LET K4$ = "|f64|i64|isnan|abs|sign|sqrt|floor|ceil|trunc|round|min|max|log|exp|sin|cos|pow|hypot|"
518 LET K4$ = K4$ & "idiv|where|sub2ind|"
519 LET K5$ = "|sum        |mean       |variance   |std        |max        |min        |argmax     |argmin     |nnz        |any        |all        |find       |find_first |find_last  |sort       |argsort    "
520 REM ==== (A) reading sea.hir =================================================================
525 CALL "io_hdr": 1, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), V8, T$, H$(), 100, N1, L$
530 LET L9 = N1 + 3
535 LET Y9 = 9
540 LET P8$ = ""
545 REM one record per round: L$ (a byte outside 0x20-0x7E, a bad split or opcode: bad record)
550 CALL "io_plain": L$, J1
555 IF J1 = 0 THEN 2900
560 CALL "io_split": L$, G$(), 300, C0
565 IF C0 < 1 THEN 2900
570 IF G$(1) = "#end" THEN 1700
575 LET I0 = 0
580 FOR I = 1 TO Z(7)
585 IF R(I, 0) = 0 THEN 600
590 IF R$(I) <> G$(1) THEN 600
595 LET I0 = I
597 GOTO 610
600 NEXT I
605 IF I0 = 0 THEN 2900
610 LET K = R(I0, 0)
615 GOSUB 2000
620 REM a capacity overflow met at a record without a position is reported at the next one with one
625 IF Q8 = 0 THEN 645
630 IF P8$ = "" THEN 645
635 LET Q2$ = P8$
640 GOTO 2920
645 IF D0 < 349999 THEN 665
650 IF Q8 = 1 THEN 655
652 LET P8$ = "nodes"
653 GOTO 1290
655 LET Q2$ = "nodes"
660 GOTO 2920
665 LET D0 = D0 + 1
670 LET D$(D0) = L$
675 LET P(D0, 0) = I0
680 LET P(D0, 1) = 0
685 IF K < 33 THEN 700
690 IF K = 42 THEN 1310
692 IF K > 48 THEN 1310
695 IF K < 39 THEN 1300
700 REM ---- a node: inside a function whose par and loc records are complete ------------------
705 IF F7 = 0 THEN 2905
710 IF P7 + L7 > 0 THEN 2905
715 GOSUB 1900
720 IF W1 < P1 THEN 2905
725 LET Q2$ = "nodes"
730 IF H0 >= N8 THEN 2920
735 LET H0 = H0 + 1
740 LET P(D0, 1) = H0
745 LET H(H0, 1) = K
750 LET H(H0, 2) = 0
755 IF K < 20 THEN 770
760 IF K < 39 THEN 775
765 IF K = 41 THEN 775
770 LET H(H0, 2) = I(2)
775 FOR I = 3 TO 8
780 LET H(H0, I) = 0
785 NEXT I
787 LET H(H0, 6) = D0
790 REM the children: the P1 topmost stack entries, the earliest first
795 IF P1 = 0 THEN 820
800 LET H(H0, 3) = W(W1 - P1 + 1)
805 FOR I = W1 - P1 + 1 TO W1 - 1
810 LET H(W(I), 4) = W(I + 1)
815 NEXT I
820 LET W1 = W1 - P1 + 1
825 LET W(W1) = H0
830 REM fore: its loop variable; lib: its n; dol: pushed on the unclaimed dols; idx: claims the
832 REM unclaimed dols of its indices (those after its base's root: post-order, 3.3)
835 IF K <> 41 THEN 850
840 LET H(H0, 5) = I(2)
845 GOTO 1290
850 IF K <> 12 THEN 860
855 LET H(H0, 5) = I(4)
857 GOTO 1290
860 IF K <> 40 THEN 870
862 LET H(H0, 5) = D9
864 LET D9 = H0
866 GOTO 1290
870 IF K <> 39 THEN 1290
872 IF D9 <= H(H0, 3) THEN 1290
874 LET Q5 = H(D9, 5)
876 LET H(D9, 5) = H0
878 LET D9 = Q5
880 GOTO 872
1285 REM ---- the next record ------------------------------------------------------------------------
1290 CALL "io_read": 1, L$, L9, P$, E(), E$(), E0
1295 GOTO 550
1300 REM ---- declarations: fn par loc end tvec ttuple (tmat tfvec tfmat: 1310) -----------------------
1305 ON K - 32 GOTO 1430, 1550, 1585, 1650, 1310, 1360
1310 REM types come first, ids from 10 in order (3.5.1): rank, element, fixed, n or rows, cols
1315 IF G0 > 0 THEN 2900
1320 IF I(1) <> Y9 + 1 THEN 2900
1325 LET Y9 = I(1)
1330 IF Y9 <= T9 THEN 1340
1335 LET P8$ = "types"
1337 GOTO 1290
1340 LET T(Y9, 1) = 1
1341 IF K = 42 THEN 1343
1342 IF K <> 50 THEN 1344
1343 LET T(Y9, 1) = 2
1344 LET T(Y9, 2) = I(2)
1345 LET T(Y9, 3) = 0
1346 LET T(Y9, 0) = 0
1347 LET T(Y9, 4) = 1
1348 IF K < 49 THEN 1290
1349 LET T(Y9, 3) = 1
1350 LET T(Y9, 0) = I(3)
1351 IF K = 49 THEN 1290
1352 LET T(Y9, 4) = I(4)
1353 GOTO 1290
1355 REM ttuple: rank 0; its first two components (n >= 2) in 3 and 4
1360 IF G0 > 0 THEN 2900
1362 IF I(1) <> Y9 + 1 THEN 2900
1364 LET Y9 = I(1)
1366 IF Y9 <= T9 THEN 1372
1368 LET P8$ = "types"
1370 GOTO 1290
1372 LET T(Y9, 1) = 0
1374 LET T(Y9, 2) = 0
1376 LET T(Y9, 3) = VAL(G$(4))
1378 LET T(Y9, 4) = VAL(G$(5))
1380 GOTO 1290
1425 REM fn: functions numbered from 1, kind main or fn; the par and loc records follow (3.5.4)
1430 IF F7 = 1 THEN 2905
1435 IF I(1) <> G0 + 1 THEN 2900
1440 LET Q2$ = "symbols"
1445 IF G0 >= 49999 THEN 2920
1450 IF G$(4) = "elem" THEN 2900
1455 LET G0 = G0 + 1
1460 LET P(D0, 1) = G0
1465 LET G(G0, 1) = A0
1470 LET G(G0, 2) = I(5)
1475 LET G(G0, 3) = I(6)
1480 LET G(G0, 4) = 0
1485 LET G(G0, 5) = 0
1490 LET G(G0, 6) = D0
1495 LET F7 = 1
1500 LET P7 = I(5)
1505 LET L7 = I(6)
1510 GOTO 1290
1550 IF F7 = 0 THEN 2905
1555 IF P7 = 0 THEN 2905
1560 LET P7 = P7 - 1
1565 GOTO 1610
1585 IF F7 = 0 THEN 2905
1590 IF P7 > 0 THEN 2905
1595 IF L7 = 0 THEN 2905
1600 LET L7 = L7 - 1
1605 REM a par or loc: its type in A (the locals of every function, in order)
1610 IF A0 < 99999 THEN 1625
1615 LET P8$ = "symbols"
1620 GOTO 1290
1625 LET A0 = A0 + 1
1630 LET A(A0) = I(2)
1640 GOTO 1290
1645 REM end pops the body block; the stack is then empty (3.3)
1650 IF F7 = 0 THEN 2905
1655 IF P7 + L7 > 0 THEN 2905
1660 IF W1 <> 1 THEN 2905
1665 IF H(W(1), 1) <> 32 THEN 2905
1670 LET W1 = 0
1672 LET D9 = 0
1675 LET F7 = 0
1680 GOTO 1290
1695 REM #end: nothing may follow; no function may be open; a pending capacity error at 1:1
1700 IF C0 <> 1 THEN 2900
1705 IF F7 = 1 THEN 2905
1710 IF P8$ = "" THEN 1735
1715 LET Q2$ = P8$
1720 LET F1 = N1 - 1
1725 LET L1 = 1
1730 LET C1 = 1
1732 GOTO 2920
1735 CALL "io_end": 1, P$, E(), E$(), E0
1740 GOTO 5000
1840 REM ==== subroutines of the reader ===========================================================
1845 REM ---- 1850: Q1 = the constant Q1$ of the consts table ------------------------------------
1850 CALL "tb_cval": K(), K$(), K0, Q1$, Q1, W7
1855 IF W7 = 0 THEN 1865
1860 CALL "dg_bug": P$, "constant " & Q1$ & " is not in the consts table"
1865 RETURN
1895 REM ---- 1900: P1 = the number of nodes the record pops (passes.txt pops column) ----------
1900 LET P1 = 0
1905 FOR J = 1 TO R(I0, 5)
1910 LET P2 = R(I0, 5 + J)
1915 IF P2 < 0 THEN 1930
1920 LET P1 = P1 + P2
1925 GOTO 1935
1930 LET P1 = P1 + I(-P2)
1935 NEXT J
1940 RETURN
1990 REM ---- 2000: the fields of the record against passes.txt; I(j) = value of a u-like field j;
1995 REM a pos field sets F1 L1 C1 and Q8 = 1; a bad field is the internal error bad record
2000 LET Q8 = 0
2005 LET T0 = 1
2010 LET N6 = 0
2015 IF F7 = 0 THEN 2025
2020 LET N6 = G(G0, 2) + G(G0, 3)
2025 FOR J = 1 TO R(I0, 4)
2030 LET B0 = R(I0, 3) + J - 1
2035 LET I(J) = 0
2040 LET X0 = 1
2045 IF F(B0, 3) = 0 THEN 2055
2050 LET X0 = I(F(B0, 3))
2055 FOR X5 = 1 TO X0
2060 LET T0 = T0 + 1
2065 IF T0 > C0 THEN 2900
2070 LET Z$ = G$(T0)
2075 LET T1 = F(B0, 1)
2080 IF F(B0, 2) = 0 THEN 2090
2085 IF Z$ = "-" THEN 2095
2090 GOSUB 2120
2095 NEXT X5
2100 NEXT J
2105 IF T0 < C0 THEN 2900
2110 RETURN
2115 REM 2120: the token Z$ of type T1 (u i f s pos site fl ty lid fid cid iid; 100+ enum)
2120 IF T1 >= 100 THEN 2290
2125 IF T1 > 12 THEN 2900
2130 ON T1 GOTO 2135, 2150, 2160, 2170, 2180, 2200, 2215, 2240, 2260, 2280, 2280, 2280
2135 CALL "io_u": Z$, V1, W7
2140 IF W7 <> 0 THEN 2900
2145 LET I(J) = V1
2147 RETURN
2150 CALL "io_i": Z$, V1, K9, L(), W7
2152 IF W7 <> 0 THEN 2900
2154 RETURN
2160 CALL "io_f": Z$, L(), W7
2162 IF W7 <> 0 THEN 2900
2164 RETURN
2170 CALL "io_unesc": Z$, 0, Q1$, W7
2172 IF W7 <> 0 THEN 2900
2174 RETURN
2180 CALL "io_pos": Z$, F1, L1, C1, W7
2182 IF W7 <> 0 THEN 2900
2184 IF F1 >= N1 THEN 2900
2186 LET Q8 = 1
2188 RETURN
2200 CALL "io_site": Z$, F2, L2, W7
2202 IF W7 <> 0 THEN 2900
2204 IF F2 >= N1 THEN 2900
2206 RETURN
2210 REM fl: '-' or the letters l p s z a, each at most once, in this order
2215 IF Z$ = "-" THEN 2235
2220 LET P2 = 0
2222 FOR X6 = 1 TO LEN(Z$)
2224 LET X7 = POS("lpsza", SEG$(Z$, X6, X6))
2226 IF X7 <= P2 THEN 2900
2228 LET P2 = X7
2230 NEXT X6
2235 RETURN
2240 CALL "io_u": Z$, V1, W7
2242 IF W7 <> 0 THEN 2900
2244 IF V1 < 1 THEN 2900
2246 IF V1 > Y9 THEN 2900
2248 LET I(J) = V1
2250 RETURN
2260 CALL "io_u": Z$, V1, W7
2262 IF W7 <> 0 THEN 2900
2264 IF V1 < 1 THEN 2900
2266 IF V1 > N6 THEN 2900
2268 LET I(J) = V1
2270 RETURN
2280 CALL "io_u": Z$, V1, W7
2282 IF W7 <> 0 THEN 2900
2284 IF V1 < 1 THEN 2900
2286 LET I(J) = V1
2288 RETURN
2290 CALL "tb_word": N(), W$(), T1 - 100, Z$, X7
2292 IF X7 = 0 THEN 2900
2294 RETURN
2795 REM ---- 2800: X9$ = the i field of the value X9 (0 <= X9 < 2^53): decimal below 10^9, else hex
2800 LET X9$ = STR$(X9)
2802 IF X9 < 1E9 THEN 2814
2804 FOR J = 4 TO 1 STEP -1
2806 LET L(J) = X9 - 65536 * INT(X9 / 65536)
2808 LET X9 = INT(X9 / 65536)
2810 NEXT J
2812 CALL "io_hex": L(), X9$
2814 RETURN
2895 REM ---- failures ---------------------------------------------------------------------------
2900 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
2905 CALL "dg_internal": P$, "BAD_TREE", E(), E$(), E0
2915 REM program too large: Q2$, at F1 L1 C1 (the record being read)
2920 LET A$(1) = Q2$
2925 CALL "dg_compile": P$, H$(), N1, F1, L1, C1, "TOO_LARGE", A$(), 1, E(), E$(), E0
2928 REM program too large: Q2$, at P9$ (the position of the node a rewrite implements, 3.5.9)
2930 CALL "io_pos": P9$, F1, L1, C1, W7
2935 GOTO 2920
