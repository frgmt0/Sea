100 REM ====================================================================================
105 REM seafuse -- pass 3a, first program: sea.hir -> sea.hirf (docs/DESIGN.md 2.1, 2.12.3, 3.5.9)
110 REM 7b: L19, the elemental application, and ind2sub with an array r (L-cl), written here as
115 REM DESIGN 2.11.4 specifies them, except that each per-element application is the call record
120 REM of the elemental function (sealoop's L20 inlines it later); the fusion rewrites F1-F5 are
125 REM 7c's. Every other record is copied unchanged, so a file without an emap and without an
130 REM ind2sub of an array r is sea.hir byte for byte (L-ek); the inst records are dropped (rule
135 REM (1) of 2.12.3). Built as DESIGN 2.6.3 says: the files fu0main ... (in name order), the
140 REM modules io diag tables layout, the DATA blocks errors exits consts records, 99999 END.
145 REM Exit: 0; 10 program too large (nodes, symbols, types of sea.hirf as a whole, at the
150 REM position of the emap or lib being rewritten, 3.5.9 "Capacity", L-el); 11 internal error
155 REM (truncated input, bad header, bad record, bad tree; DESIGN 2.2). Steps: (A) fu0main reads
160 REM and validates all of sea.hir; (B) fu1walk visits the records in file order and builds the
165 REM output as a linked list, L19 (fu3elm) inserting its records; (C) fu2out numbers the new
170 REM .l locals and the tptr types in file order and writes sea.hirf.
175 REM Tables: D$ the records as read (r = 1..D0); P(r,0) its records row, P(r,1) its node (for fn
180 REM   its function); H nodes (0 the output row before its subtree, 1 kind, 2 ty or 0, 3 first
185 REM   child, 4 next sibling, 5 block: statements added, 6 its record row, 7 and 8 the first
190 REM   and last output row of its subtree); W the tree stack, after (A) the parents; G
200 REM   functions (1 locals base, 2 np, 3 nl, 4 new locals, 5 their first entry in U(.,5), 6 fn
205 REM   record r); A local types; T types (0 n or rows of a fixed type, 1 rank 1 2, 0 a ttuple or
210 REM   struct, 2 element (a struct itself), 3 fixed 1 (ttuple: its first component), 4 cols
215 REM   (ttuple: the second)); O output rows (0 the next row, row 0 the head; 1 the record r
220 REM   copied, or 0: generated, text in O$); U new locals (1 type, -e the tptr of e, 2 mut 0 let
225 REM   1 for, 3 the record whose pos is its loc pos, 4 lid, 5 the locals in declaring order); V
230 REM   the script variables (fu1walk 9000), V(55..57) the sizes of bool i64 f64, V(1700 + j) and
235 REM   V(1800 + j) the data and home of result j of L19; M the open blocks of a script (1
240 REM   count, 2 the loop local or 0); C the layout table of the module layout (C(e,6): the
245 REM   tptr of element type e: 0 none, 1 used, else its id; of a tptr id: its element); Y the
250 REM   tables of F1-F5 (7c, Decision 112 (1); unused in 7b), one table per column: 1 and 2
252 REM   per node its class and its iteration space, 3 the statements of a fused group, 4 its
255 REM   locals, 5 the leaf list, 6 and 7 the leaf index maps.
260 REM Kinds (R(i,0) per records row): 1 ci 2 cf 3 cb 4 cs 5 lv 6 cvt 7 un 8 bin 9 powk 10 call
265 REM   11 rarg 12 lib 13 fmt 14 ftext 15 fconv 16 rng 17 ifx 18 skip 19 seq 20 bind 21 tbind
270 REM   22 eval 23 asg 24 tasg 25 if 26 while 27 forr 28 break 29 cont 30 ret 31 tret 32 block
275 REM   39 idx 40 dol 41 fore 43 dyn 44 fix 45 view 46 all 47 arr 48 row 51 match 52 arm 56 fld
280 REM   57 proj 58 slit 64 emap 65-73 jopen jclose jobj jarr jend jkey jval jvec jmat (nodes);
285 REM   33 fn 34 par 35 loc 36 end 37 tvec 38 ttuple 42 tmat 49 tfvec 50 tfmat 53 tstruct 54
290 REM   trec 55 fd 63 inst (declarations).
295 REM ====================================================================================
300 FILES "sea.hir"; "sea.hirf"
305 DIM E(299), E$(299,5), Q(20), Q$(20), K(299,4), K$(299), Z(8), I(40), L(4), A$(2)
310 DIM N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), G$(300), H$(100)
315 DIM H(99999,8), G(49999,6), A(99999), T(20008,4), W(99999), P(349999,1), D$(349999)
320 DIM O(449999,1), O$(449999), U(49999,5), V(37000), M(99,2), C(120008,6), Y(99999,7)
325 LET P$ = "seafuse"
330 REM ---- the tables (canonical order: errors exits consts records) --------------------------
335 CALL "tb_errors": P$, E(), E$(), 299, E0
340 CALL "tb_exits": P$, E(), E$(), E0, Q(), Q$(), 20, N9
345 CALL "tb_consts": P$, E(), E$(), E0, K(), K$(), 299, K0
350 LET Z(1) = 39
355 LET Z(2) = 299
360 LET Z(3) = 399
365 LET Z(4) = 1499
370 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), R(), R$(), F(), F$(), Z()
375 LET Q1$ = "FILE_VERSION"
380 GOSUB 1850
385 LET V8 = Q1
390 LET Q1$ = "LIM_NODES"
395 GOSUB 1850
400 LET N8 = Q1
405 LET Q1$ = "LIM_SYMBOLS"
410 GOSUB 1850
415 LET S8 = Q1
420 LET Q1$ = "LIM_TYPES"
425 GOSUB 1850
430 LET T9 = Q1 + 9
435 LET Q1$ = "ESIZE_BOOL"
440 GOSUB 1850
445 LET V(55) = Q1
450 LET Q1$ = "ESIZE_I64"
455 GOSUB 1850
460 LET V(56) = Q1
465 LET Q1$ = "ESIZE_F64"
470 GOSUB 1850
475 LET V(57) = Q1
480 LET Q1$ = "SHAPE_VEC"
485 GOSUB 1850
490 LET V(59) = Q1
495 LET Z4$ = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
500 LET Z5$ = "abcejklnqrstuwxIMNWXY"
505 IF N8 > 99999 THEN 520
510 IF S8 > 49999 THEN 520
515 IF T9 <= 20008 THEN 530
520 CALL "dg_bug": P$, "a capacity limit is larger than the pass's tables"
525 REM ---- R(i,0) = the kind of every record row of the sets H and HF, else 0 (H1, HL: bad) -----
530 LET K1$ = "|ci=01|cf=02|cb=03|cs=04|lv=05|cvt=06|un=07|bin=08|powk=09|call=10|rarg=11|lib=12|fmt=13|ftext=14|fconv=15|rng=16|ifx=17|skip=18|seq=19|bind=20|"
535 LET K2$ = "|tbind=21|eval=22|asg=23|tasg=24|if=25|while=26|forr=27|break=28|cont=29|ret=30|tret=31|block=32|fn=33|par=34|loc=35|end=36|tvec=37|ttuple=38|"
540 LET K1$ = K1$ & K2$ & "|jopen=65|jclose=66|jobj=67|jarr=68|jend=69|jkey=70|jval=71|jvec=72|jmat=73|"
545 LET K1$ = K1$ & "|idx=39|dol=40|fore=41|tmat=42|dyn=43|fix=44|view=45|all=46|arr=47|row=48|tfvec=49|tfmat=50|"
550 LET K1$ = K1$ & "|match=51|arm=52|tstruct=53|trec=54|fd=55|fld=56|proj=57|slit=58|inst=63|emap=64|"
555 CALL "ly_init": C(), K(), K$(), K0, T9, 120008, P$
560 FOR I = 1 TO Z(7)
565 LET R(I, 0) = 0
570 IF R(I, 1) = 2 THEN 580
575 IF R(I, 1) <> 4 THEN 595
580 LET P1 = POS(K1$, "|" & R$(I) & "=")
585 IF P1 = 0 THEN 595
590 LET R(I, 0) = VAL(SEG$(K1$, P1 + LEN(R$(I)) + 2, P1 + LEN(R$(I)) + 3))
595 NEXT I
600 REM ==== (A) reading sea.hir =================================================================
605 CALL "io_hdr": 1, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), V8, T$, H$(), 100, N1, L$
610 LET L9 = N1 + 3
615 LET Y9 = 9
620 LET P8$ = ""
625 REM one record per round: L$ (a byte outside 0x20-0x7E, a bad split or opcode: bad record)
630 CALL "io_plain": L$, J1
635 IF J1 = 0 THEN 2900
640 CALL "io_split": L$, G$(), 300, C0
645 IF C0 < 1 THEN 2900
650 IF G$(1) = "#end" THEN 1700
655 LET I0 = 0
660 FOR I = 1 TO Z(7)
665 IF R(I, 0) = 0 THEN 680
670 IF R$(I) <> G$(1) THEN 680
675 LET I0 = I
677 GOTO 690
680 NEXT I
685 IF I0 = 0 THEN 2900
690 LET K = R(I0, 0)
695 IF C(0, 4) = 0 THEN 705
700 IF K <> 55 THEN 2900
705 GOSUB 2000
710 REM a capacity overflow met at a record without a position is reported at the next one with one
715 IF Q8 = 0 THEN 735
720 IF P8$ = "" THEN 735
725 LET Q2$ = P8$
730 GOTO 2920
735 IF D0 < 349999 THEN 760
740 IF Q8 = 1 THEN 750
745 LET P8$ = "nodes"
747 GOTO 1290
750 LET Q2$ = "nodes"
755 GOTO 2920
760 LET D0 = D0 + 1
765 LET D$(D0) = L$
770 LET P(D0, 0) = I0
775 LET P(D0, 1) = 0
780 IF K < 33 THEN 800
785 IF K = 63 THEN 1600
787 IF K = 42 THEN 1310
789 IF K > 55 THEN 800
791 IF K > 52 THEN 1400
793 IF K > 50 THEN 800
795 IF K > 48 THEN 1310
797 IF K < 39 THEN 1300
800 REM ---- a node: inside a function whose par and loc records are complete ------------------
805 IF F7 = 0 THEN 2905
810 IF P7 + L7 > 0 THEN 2905
815 GOSUB 1900
820 IF W1 < P1 THEN 2905
825 LET Q2$ = "nodes"
830 IF H0 >= N8 THEN 2920
835 LET H0 = H0 + 1
840 LET P(D0, 1) = H0
845 LET H(H0, 1) = K
850 LET H(H0, 2) = 0
855 REM the ty field: of ci ... seq, idx dol, dyn ... row, fld proj slit, emap (2.6: passes.txt)
860 IF K < 20 THEN 885
865 IF K < 39 THEN 890
870 IF K = 41 THEN 890
875 IF K > 64 THEN 890
880 IF ABS(K - 52) < 2 THEN 890
885 LET H(H0, 2) = I(2)
890 FOR I = 3 TO 8
895 LET H(H0, I) = 0
900 NEXT I
905 LET H(H0, 6) = D0
910 REM the children: the P1 topmost stack entries, the earliest first
915 IF P1 = 0 THEN 940
920 LET H(H0, 3) = W(W1 - P1 + 1)
925 FOR I = W1 - P1 + 1 TO W1 - 1
930 LET H(W(I), 4) = W(I + 1)
935 NEXT I
940 LET W1 = W1 - P1 + 1
945 LET W(W1) = H0
950 IF K = 64 THEN 1640
1285 REM ---- the next record ------------------------------------------------------------------------
1290 CALL "io_read": 1, L$, L9, P$, E(), E$(), E0
1295 GOTO 630
1300 REM ---- declarations: fn par loc end tvec ttuple (tmat tfvec tfmat: 1310) -----------------------
1305 ON K - 32 GOTO 1430, 1550, 1585, 1650, 1310, 1360
1310 REM types come first, ids from 10 in order (3.5.1): rank, element, fixed, n or rows, cols
1315 IF G0 + A5 > 0 THEN 2900
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
1348 GOTO 1381
1355 REM ttuple: rank 0; its first two components (n >= 2) in 3 and 4
1360 IF G0 + A5 > 0 THEN 2900
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
1381 REM an array type registered with the module layout: its element str, bool, i64, f64 or a
1382 REM struct or record (3.5.7); of a fixed-size one n or rows, cols
1383 LET N5 = I(2)
1384 IF N5 = 5 THEN 1387
1385 IF C(N5, 0) = 1 THEN 1387
1386 IF C(N5, 0) <> 4 THEN 2900
1387 IF K > 48 THEN 1390
1388 CALL "ly_dyn": C(), Y9
1389 GOTO 1290
1390 LET T(Y9, 3) = 1
1391 LET T(Y9, 0) = I(3)
1392 LET N0 = I(3)
1393 IF K = 49 THEN 1396
1394 LET T(Y9, 4) = I(4)
1395 LET N0 = I(3) * I(4)
1396 CALL "ly_fix": C(), Y9, N5, N0, W0
1397 IF W0 <> 0 THEN 2900
1398 GOTO 1290
1399 REM tstruct and trec: a type (rank 0, its element itself) opened for its n fd records (layout)
1400 IF G0 + A5 > 0 THEN 2900
1401 IF K = 55 THEN 1416
1402 IF I(1) <> Y9 + 1 THEN 2900
1403 LET Y9 = I(1)
1404 IF Y9 <= T9 THEN 1407
1405 LET P8$ = "types"
1406 GOTO 1290
1407 LET T(Y9, 0) = 0
1408 LET T(Y9, 1) = 0
1409 LET T(Y9, 2) = Y9
1410 LET T(Y9, 3) = 0
1411 LET T(Y9, 4) = 0
1412 LET N0 = I(3)
1413 IF K = 53 THEN 1420
1414 LET N0 = I(2)
1415 GOTO 1420
1416 REM fd: the next field of the open struct (none open: bad record; after a capacity error none)
1417 IF P8$ <> "" THEN 1290
1418 IF C(0, 4) = 0 THEN 2900
1419 GOTO 1424
1420 CALL "ly_st": C(), Y9, N0, W0
1421 IF W0 = 0 THEN 1290
1422 LET P8$ = "types"
1423 GOTO 1290
1424 LET N5 = I(2)
1425 CALL "ly_fd": C(), N5, W0
1426 IF W0 <> 0 THEN 2900
1427 GOTO 1290
1428 REM fn: functions numbered from 1 (any kind: main fn inl elem); the par and loc records follow
1430 IF F7 = 1 THEN 2905
1435 IF I(1) <> G0 + 1 THEN 2900
1440 LET Q2$ = "symbols"
1445 IF G0 >= 49999 THEN 2920
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
1600 IF K = 63 THEN 1680
1602 LET L7 = L7 - 1
1605 REM a par or loc: its type in A (the locals of every function, in order)
1610 IF A0 < 99999 THEN 1625
1615 LET P8$ = "symbols"
1620 GOTO 1290
1625 LET A0 = A0 + 1
1630 LET A(A0) = I(2)
1635 GOTO 1290
1637 REM an emap: its children (n of them) are its arguments; its iid an instance read before
1640 IF I(3) > A5 THEN 2900
1642 IF I(4) < 1 THEN 2900
1644 GOTO 1290
1645 REM end pops the body block; the stack is then empty (3.3)
1650 IF F7 = 0 THEN 2905
1655 IF P7 + L7 > 0 THEN 2905
1660 IF W1 <> 1 THEN 2905
1665 IF H(W(1), 1) <> 32 THEN 2905
1670 LET W1 = 0
1675 LET F7 = 0
1677 GOTO 1290
1678 REM inst: after the types, before the functions, iids from 1 in order (A5 the last)
1680 IF G0 > 0 THEN 2900
1682 IF I(1) <> A5 + 1 THEN 2900
1684 LET A5 = I(1)
1686 GOTO 1290
1695 REM #end: nothing may follow; no function may be open; a pending capacity error at 1:1
1700 IF C0 <> 1 THEN 2900
1702 IF C(0, 4) <> 0 THEN 2900
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
2895 REM ---- failures ---------------------------------------------------------------------------
2900 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
2905 CALL "dg_internal": P$, "BAD_TREE", E(), E$(), E0
2915 REM program too large: Q2$, at F1 L1 C1 (the record being read)
2920 LET A$(1) = Q2$
2925 CALL "dg_compile": P$, H$(), N1, F1, L1, C1, "TOO_LARGE", A$(), 1, E(), E$(), E0
2928 REM program too large: Q2$, at P9$ (the position of the node a rewrite implements, 3.5.9)
2930 CALL "io_pos": P9$, F1, L1, C1, W7
2935 GOTO 2920
2937 REM ---- 2940: (fu1walk 5190, at the end of a node, no GOSUB pending) a limit passed inside the fusion I9 (fu1walk 8088): that fusion
2938 REM and every later one in walk order are not applied (L-el, 2.12.3): O2 = the first node of I9's subtree, fu4fan 30900 denies
2939 REM every unit whose node is O2 or later; the walk's changes are restored and it runs once more (5045); a second time: reported (2990)
2940 IF O2 > 0 THEN 2990
2941 LET I4 = I9
2942 IF H(I4, 3) = 0 THEN 2945
2943 LET I4 = H(I4, 3)
2944 GOTO 2942
2945 LET O2 = I4
2946 LET O1 = 0
2947 LET I9 = 0
2948 FOR X = 1 TO H0
2949 IF H(X, 1) <> 32 THEN 2951
2950 LET H(X, 5) = 0
2951 NEXT X
2952 FOR X = 1 TO G0
2953 LET G(X, 4) = 0
2954 LET G(X, 5) = 0
2955 NEXT X
2956 IF LEN(I7$) = 0 THEN 2964
2957 GOTO 2977
2964 LET I7$ = ""
2965 LET C(20008, 6) = 0
2966 LET G6 = 0
2967 LET G5 = 0
2968 REM the modes a unit sets and clears (52026 H4, 56409 G3, 51004 H7, 51044 H6) and the script's state, cleared
2969 LET H4 = 0
2970 LET G3 = 0
2971 LET H6 = 0
2972 LET H7 = 0
2973 LET Z7 = 0
2974 LET Z8 = 0
2975 LET K8 = 0
2976 GOTO 5045
2977 LET O5$ = SEG$(I7$, 2, LEN(I7$))
2978 LET J = POS(O5$, "|")
2979 IF J > 0 THEN 2982
2980 LET C(VAL(O5$), 6) = 0
2981 GOTO 2964
2982 LET C(VAL(SEG$(O5$, 1, J - 1)), 6) = 0
2983 LET I7$ = SEG$(O5$, J, LEN(O5$))
2984 GOTO 2956
2988 REM ---- 2990: a limit passed again inside a fusion after the run again (not expected: every later fusion is denied): reported where it was first met
2990 LET P9$ = O3$
2991 LET Q2$ = O4$
2992 GOTO 2930
