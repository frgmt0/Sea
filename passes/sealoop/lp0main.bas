100 REM ====================================================================================
105 REM sealoop -- pass 3a, second program: sea.hirf -> sea.hirl (DESIGN.md 2.1, 2.7, 2.12.3, 3.5.9)
110 REM Rewrites the array constructs into explicit scalar HIR: 4e-0's L1-L4 (zeros ones filled
115 REM len rows cols numel, fore) and 4e's L5-L11 (selection reads and folded views, selection
120 REM stores and compound stores, element-wise operations, range values, numeric literals and
125 REM concatenation, materialized views, dyn, fix, ind2sub with an array k), 4f's L13-L14, 4g-1's
127 REM L16 match and the str cases of L2-L14 (lp8str), 4g-2's L15 projection, L17 (field paths,
128 REM reference and aggregate elements) and the struct cases (lp9agg). Others
130 REM are copied unchanged, so a file without those constructs is sea.hir byte for byte. Built
135 REM as DESIGN 2.6.3 says: the files lp0main ... lpainl (in name order), the modules io diag
140 REM tables layout, the DATA blocks errors exits consts records, 99999 END. Exit:
145 REM 0; 10 program too large (nodes, symbols, types of sea.hirl as a whole, 3.5.9); 11
150 REM internal error (truncated input, bad header, bad record, bad tree; DESIGN 2.2). Steps:
152 REM 7b (DESIGN 2.12.3): the input is seafuse's sea.hirf: no inst or emap (L19 is seafuse's), the HL
153 REM records tptr xblk tmp hloop ext adat eld est anew wbin chkb chk rcnt cow mcpy validated
154 REM (3000-3490) and kept; their .l locals and tptr types renumbered with sealoop's (lp2out).
155 REM (A) lp0main reads and validates all of sea.hirf; (B) lp1walk visits the records in file
160 REM order and builds the output as a linked list, the rewrites (lp1walk, lp3sel, lp4ew,
165 REM lp5lit) inserting their records; (C) lp2out numbers the new locals and tptr types, writes.
170 REM Tables: D$ the body records as read (r = 1..D0); P(r,0) its records row, P(r,1) its node
175 REM   (for fn its function); H nodes (0 the output row before its subtree, 1 kind, 2 ty or 0,
180 REM   3 first child, 4 next sibling, 5 fore lid, lib n, dol: link of the unclaimed dols then
185 REM   its idx, idx: the local of its base, block: statements added, jobj jarr: the open one
186 REM   it is in (A, 6d), 6 its record row, 7 and 8
190 REM   the first and last output row of its subtree); W the tree stack, after (A) the parents;
195 REM   G functions (1 locals base in A, 2 np, 3 nl, 4 new locals, 5 their first entry in
200 REM   U(.,5), 6 fn record r); A local types; T types (0 n or rows of a fixed type, 1 rank 1 2,
205 REM   0 a ttuple or struct, 2 element (a struct itself), 3 fixed 1 (ttuple: its first component), 4 cols (ttuple: the
210 REM   second)); O output rows (0 the next row, row 0 the head; 1 the record r copied, or 0:
215 REM   generated, text in O$); U new locals (1 type, -e the tptr of e, 2 mut 0 let 1 for, 3 the
220 REM   record whose pos is its loc pos, 4 lid, 5 the locals in declaring order); the tptr
222 REM   of element type e in C(e,6) below; S(e) the element size (of a struct its layout size);
224 REM   V the script variables (lp1walk 9000), M the open blocks of a script (1 count, 2
225 REM   the loop local or 0); C the layout table of the module layout (C(t,6): the tptr of
226 REM   element type t: 0 none, 1 used, else its id; of a tptr id: its element); J per node the
227 REM   path data of L17 (lp9agg). Kinds (R(i,0) per records row): 1 ci 2 cf 3 cb 4 cs 5 lv 6 cvt 7
228 REM   un 8 bin 9 powk 10 call 11 rarg 12 lib 13 fmt 14 ftext 15 fconv 16 rng 17 ifx 18 skip
230 REM   19 seq 20 bind 21 tbind 22 eval 23 asg 24 tasg 25 if 26 while 27 forr 28 break 29 cont
232 REM   30 ret 31 tret 32 block 39 idx 40 dol 41 fore 43 dyn 44 fix 45 view 46 all 47 arr 48
234 REM   row 51 match 52 arm 56 fld 57 proj 58 slit (nodes); 33 fn 34 par 35 loc 36 end 37 tvec 38
236 REM   ttuple 42 tmat 49 tfvec 50 tfmat 53 tstruct 54 trec 55 fd; 59 tmp 60 xblk 61 iblk 62 iret
237 REM   (the stream of L18 only). 4h: L18 (lpainl) inlines the prelude calls between (A) and (B);
238 REM   6b: L20 (lpainl) the calls of fn kind inl as well (M then also its inline levels).
239 REM   6c: the calls of kind elem by L20. 7b: 63 tptr (a type) and, after the j* records, the HL
240 REM   6d: 65-73 jopen jclose jobj jarr jend jkey jval jvec jmat: kept statements (copied
241 REM   after their children), validated in (A) (900-987; DESIGN 2.11.4).
242 REM   nodes 74 ext 75 adat 76 eld 77 anew 78 wbin 79 hloop 80 est 81 chkb 82 chk 83 rcnt 84 cow 85 mcpy (DESIGN 2.12.3).
243 REM ====================================================================================
245 FILES "sea.hirf"; "sea.hirl"
250 DIM E(299), E$(299,5), Q(20), Q$(20), K(299,4), K$(299), Z(8), I(40), L(4), A$(2), S(20008)
255 DIM N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), G$(300), H$(100)
260 DIM H(99999,8), G(49999,6), A(99999), T(20008,4), W(99999), P(349999,1), D$(349999)
265 DIM O(449999,1), O$(449999), U(49999,5), V(1699), M(49999,3), D(64,1)
266 DIM C(120008,6), J(99999,5)
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
406 LET Q1$ = "ESIZE_PTR"
407 GOSUB 1850
408 LET S(5) = Q1
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
462 LET K1$ = K1$ & "|jopen=65|jclose=66|jobj=67|jarr=68|jend=69|jkey=70|jval=71|jvec=72|jmat=73|"
465 LET K1$ = K1$ & K2$ & "|idx=39|dol=40|fore=41|tmat=42|"
466 LET A9 = 120008
467 LET K1$ = K1$ & "|dyn=43|fix=44|view=45|all=46|arr=47|row=48|tfvec=49|tfmat=50|"
468 LET K1$ = K1$ & "|match=51|arm=52|tstruct=53|trec=54|fd=55|fld=56|proj=57|slit=58|tmp=59|xblk=60|tptr=63|ext=74|adat=75|eld=76|anew=77|wbin=78|hloop=79|est=80|chkb=81|chk=82|rcnt=83|cow=84|mcpy=85|"
469 CALL "ly_init": C(), K(), K$(), K0, T9, A9, P$
470 FOR I = 1 TO Z(7)
475 LET R(I, 0) = 0
480 IF R(I, 1) = 2 THEN 490
485 IF ABS(R(I, 1) - 5.5) <> 1.5 THEN 505
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
611 IF C(0, 4) = 0 THEN 615
612 IF K <> 55 THEN 2900
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
686 IF K = 63 THEN 3002
690 IF K = 42 THEN 1310
691 IF K > 55 THEN 700
692 IF K > 52 THEN 1400
693 IF K > 50 THEN 700
694 IF K > 48 THEN 1310
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
762 IF ABS(K - 60.5) = 1.5 THEN 775
763 IF K > 78 THEN 775
764 IF ABS(K - 69) < 5 THEN 775
765 IF K = 41 THEN 775
766 IF K > 55 THEN 770
767 IF K > 50 THEN 775
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
826 IF K = 32 THEN 960
827 IF ABS(K - 69) < 5 THEN 900
828 IF E1 > 0 THEN 930
829 IF D2 = 1 THEN 940
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
870 IF K <> 39 THEN 3052
872 IF D9 <= H(H0, 3) THEN 1290
874 LET Q5 = H(D9, 5)
876 LET H(D9, 5) = H0
878 LET D9 = Q5
880 GOTO 872
881 REM ---- 6d: a j* record (DESIGN 2.11.4 "write_json"): only between a jopen and its jclose in
882 REM file order (D2 = 1 there: the block of 3.5.7 step 4), a statement of a block (E1 counts
883 REM the j* nodes no block has claimed yet); the child of a jval a JSON scalar (bool i64 f64
884 REM str), of a jvec / jmat a dynamic vector / matrix of JSON scalars, of a jopen a str; else bad
900 LET E1 = E1 + 1
901 IF K <> 65 THEN 906
902 IF D2 = 1 THEN 2900
903 IF H(H(H0, 3), 2) <> 5 THEN 2900
904 LET D2 = 1
905 GOTO 1290
906 IF D2 = 0 THEN 2900
907 IF K <> 66 THEN 910
908 LET D2 = 0
909 GOTO 1290
910 IF K < 71 THEN 1290
911 LET D5 = H(H(H0, 3), 2)
912 IF K > 71 THEN 916
913 IF D5 < 2 THEN 2900
914 IF D5 > 5 THEN 2900
915 GOTO 1290
916 IF T(D5, 1) <> K - 71 THEN 2900
917 IF T(D5, 3) <> 0 THEN 2900
918 IF T(D5, 2) < 2 THEN 2900
919 IF T(D5, 2) > 5 THEN 2900
920 GOTO 1290
925 REM a node other than a block whose children hold a j* record: bad record
930 LET D5 = H(H0, 3)
931 IF D5 = 0 THEN 936
932 IF ABS(H(D5, 1) - 69) < 5 THEN 2900
933 LET D5 = H(D5, 4)
934 GOTO 931
936 IF D2 = 0 THEN 835
937 REM between a jopen and its jclose only what pass 2b's emit writes: no other statement
940 IF POS("|20|21|22|23|24|26|28|29|30|31|51|52|", "|" & STR$(K) & "|") > 0 THEN 2900
942 GOTO 835
950 REM a block: its j* statements in order; a jclose the last statement, after the block's jopen
952 REM (D4 1 after it, 2 after the jclose); jobj and jarr closed by a jend of the same block (D3
954 REM the innermost open one, each linked to the one it is inside by H(.,5)); a jkey in a jobj
960 LET D3 = 0
961 LET D4 = 0
962 LET D5 = H(H0, 3)
963 IF D5 = 0 THEN 985
964 IF ABS(H(D5, 1) - 69) > 4 THEN 983
965 LET E1 = E1 - 1
966 ON H(D5, 1) - 64 GOTO 968, 970, 975, 975, 978, 981, 983, 983, 983
968 LET D4 = 1
969 GOTO 983
970 IF D4 <> 1 THEN 2900
971 IF H(D5, 4) > 0 THEN 2900
972 IF D3 > 0 THEN 2900
973 LET D4 = 2
974 GOTO 983
975 LET H(D5, 5) = D3
976 LET D3 = D5
977 GOTO 983
978 IF D3 = 0 THEN 2900
979 LET D3 = H(D3, 5)
980 GOTO 983
981 IF D3 = 0 THEN 2900
982 IF H(D3, 1) <> 67 THEN 2900
983 LET D5 = H(D5, 4)
984 GOTO 963
985 IF D3 > 0 THEN 2900
986 IF D4 = 1 THEN 2900
987 GOTO 1290
1285 REM ---- the next record ------------------------------------------------------------------------
1290 IF A2 = 1 THEN 50740
1292 CALL "io_read": 1, L$, L9, P$, E(), E$(), E0
1295 GOTO 550
1300 REM ---- declarations: fn par loc end tvec ttuple (tmat tfvec tfmat: 1310) -----------------------
1305 ON K - 32 GOTO 1430, 1550, 1585, 1650, 1310, 1360
1310 REM types come first, ids from 10 in order (3.5.1): rank, element, fixed, n or rows, cols; among
1311 REM sea.hirf's tptrs only seafuse's appended F8, a tfvec (3.5.9 "Types", 2.12.3 (3), D-1)
1315 IF G0 > 0 THEN 2900
1316 IF A6 = 0 THEN 1320
1317 IF K <> 49 THEN 2900
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
1360 IF G0 + A6 > 0 THEN 2900
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
1400 IF G0 + A6 > 0 THEN 2900
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
1413 IF K = 53 THEN 1415
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
1428 REM fn: functions numbered from 1, kind main or fn; the par and loc records follow (3.5.4)
1430 IF F7 = 1 THEN 2905
1435 IF I(1) <> G0 + 1 THEN 2900
1440 LET Q2$ = "symbols"
1445 IF G0 >= 49999 THEN 2920
1450 REM 6c: kind elem accepted (an elemental function, inlined by L20)
1455 LET G0 = G0 + 1
1460 LET P(D0, 1) = G0
1465 LET G(G0, 1) = A0
1470 LET G(G0, 2) = I(5)
1475 LET G(G0, 3) = I(6)
1480 LET G(G0, 4) = 0
1485 LET G(G0, 5) = 0
1487 LET G(G0, 0) = 0
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
1632 IF POS("|.p |.q |.i |", "|" & G$(2) & " |") = 0 THEN 1640
1634 LET G(G0, 0) = G(G0, 0) + 1
1636 IF SEG$(G$(2), 1, 2) <> ".l" THEN 1290
1638 REM 7b: a .l local of sea.hirf (renumbered on output, lp2out)
1640 LET A3 = 1
1642 GOTO 1290
1645 REM end pops the body block; the stack is then empty (3.3)
1650 IF F7 = 0 THEN 2905
1655 IF P7 + L7 > 0 THEN 2905
1660 IF W1 <> 1 THEN 2905
1665 IF H(W(1), 1) <> 32 THEN 2905
1667 GOSUB 3414
1670 LET W1 = 0
1672 LET D9 = 0
1675 LET F7 = 0
1680 GOTO 1290
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
1735 IF A2 = 1 THEN 5000
1737 CALL "io_end": 1, P$, E(), E$(), E0
1740 GOTO 50040
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
2996 REM ==== 7b: the records of sea.hirf beyond sea.hir (DESIGN 2.12.3, 3.5.9 "What the passes validate")
2998 REM ---- 3002: tptr id elt (rule (3)): after sea.hir's types (A6 their last id), before the
3000 REM functions; elt str, a scalar, a struct or record, no two of one elt; T(id,2) its elt (A3 = 1)
3002 IF G0 > 0 THEN 2900
3004 IF I(1) <> Y9 + 1 THEN 2900
3006 IF A6 > 0 THEN 3010
3008 LET A6 = Y9
3010 LET N5 = I(2)
3012 IF N5 > A6 THEN 2900
3014 IF N5 = 5 THEN 3020
3016 IF C(N5, 0) = 1 THEN 3020
3018 IF C(N5, 0) <> 4 THEN 2900
3020 FOR J = A6 + 1 TO Y9
3021 IF T(J, 3) = 1 THEN 3024
3022 IF T(J, 2) = N5 THEN 2900
3024 NEXT J
3026 LET Y9 = I(1)
3028 IF Y9 <= T9 THEN 3034
3030 LET P8$ = "types"
3032 GOTO 1290
3034 FOR J = 0 TO 4
3036 LET T(Y9, J) = 0
3038 NEXT J
3040 LET T(Y9, 2) = N5
3042 LET A3 = 1
3044 GOTO 1290
3046 REM ---- the node H0 of kind K (rules (1)-(5), T1): the HL nodes, and the .l locals: A(e) +
3048 REM 400000 m, m 1 declared by a tmp, hloop or rcnt, 2 by a bind or tbind, 3 read before its
3050 REM declaration (only an hloop's local may be: its block precedes it); L5 the first child
3052 LET L5 = H(H0, 3)
3054 IF K = 5 THEN 3076
3056 IF K = 11 THEN 3092
3058 IF K = 20 THEN 3116
3060 IF K = 21 THEN 3126
3062 IF K = 23 THEN 3096
3064 IF K = 24 THEN 3106
3066 IF K = 59 THEN 3152
3068 IF K = 60 THEN 3178
3070 IF K < 74 THEN 1290
3072 ON K - 73 GOTO 3190, 3208, 3232, 3258, 3278, 3296, 3236, 3324, 3330, 3354, 3384, 3398
3074 REM lv of a .l local: its type; read before any declaration: mark 3
3076 LET V1 = I(3)
3078 GOSUB 3458
3080 IF L0 = 0 THEN 1290
3082 IF I(2) <> A7 THEN 2900
3084 IF A8 > 0 THEN 1290
3086 LET A(L6) = A(L6) + 1200000
3088 GOTO 1290
3090 REM rarg, asg (set, of a scalar), a tasg's targets: a .l local only one a bind or tbind declared
3092 GOSUB 3428
3094 GOTO 1290
3096 GOSUB 3428
3098 IF L0 = 0 THEN 1290
3100 IF G$(3) <> "set" THEN 2900
3102 IF A7 > 5 THEN 2900
3104 GOTO 1290
3106 IF H(L5, 4) = 0 THEN 1290
3108 GOSUB 3428
3110 LET L5 = H(L5, 4)
3112 GOTO 3106
3114 REM bind, tbind of .l locals: each declared here once (mark 2), a bind's of its child's type
3116 LET V1 = I(2)
3118 GOSUB 3458
3120 IF L0 = 0 THEN 1290
3122 IF H(L5, 2) <> A7 THEN 2900
3124 GOTO 3140
3126 FOR J = 4 TO C0
3128 IF G$(J) = "-" THEN 3136
3130 LET V1 = VAL(G$(J))
3132 GOSUB 3458
3134 IF L0 = 1 THEN 3140
3136 NEXT J
3138 GOTO 1290
3140 IF A8 > 0 THEN 2900
3142 LET A(L6) = A(L6) + 800000
3144 IF K = 21 THEN 3136
3146 GOTO 1290
3148 REM tmp: of a .l local (in L18's stream also of a .p or .q), declared once, of its child's type;
3150 REM of a tptr type only of an adat
3152 LET V1 = I(2)
3154 GOSUB 3458
3156 IF L0 = 1 THEN 3162
3158 IF A2 = 1 THEN 1290
3160 GOTO 2900
3162 IF A8 > 0 THEN 2900
3164 IF H(L5, 2) <> A7 THEN 2900
3166 LET A(L6) = A(L6) + 400000
3168 GOSUB 3474
3170 IF A8 = 0 THEN 1290
3172 IF H(L5, 1) = 75 THEN 1290
3174 GOTO 2900
3176 REM xblk: ty its last child's
3178 IF H(L5, 4) = 0 THEN 3184
3180 LET L5 = H(L5, 4)
3182 GOTO 3178
3184 IF H(L5, 2) = I(2) THEN 1290
3186 GOTO 2900
3188 REM ext: ty 3, of a str (dim 0) or of an array (dim < its rank)
3190 IF I(2) <> 3 THEN 2900
3192 LET A7 = H(L5, 2)
3194 IF A7 <> 5 THEN 3200
3196 IF I(3) = 0 THEN 1290
3198 GOTO 2900
3200 IF A7 <= 9 THEN 2900
3202 IF I(3) < T(A7, 1) THEN 1290
3204 GOTO 2900
3206 REM adat: ty a tptr whose elt is the array's element type (of a struct or record home: that type)
3208 IF A6 = 0 THEN 2900
3210 IF I(2) <= A6 THEN 2900
3212 LET A7 = H(L5, 2)
3214 IF A7 <= 9 THEN 2900
3216 IF T(A7, 1) = 0 THEN 3222
3218 IF T(I(2), 2) = T(A7, 2) THEN 1290
3220 GOTO 2900
3222 IF C(A7, 0) <> 4 THEN 2900
3224 IF T(I(2), 2) = A7 THEN 1290
3226 GOTO 2900
3228 REM eld, est: an address of a tptr type whose elt is ty (eld) or the value's type (est), or a struct
3230 REM or record (R24's fields; their offsets are seaval's to check), then an index of type 3
3232 LET L6 = I(2)
3234 GOTO 3240
3236 LET L6 = H(L5, 2)
3238 LET L5 = H(L5, 4)
3240 GOSUB 3474
3242 IF A8 = 0 THEN 2900
3244 LET A7 = T(H(L5, 2), 2)
3246 IF A7 = L6 THEN 3250
3248 IF C(A7, 0) <> 4 THEN 2900
3250 IF H(H(L5, 4), 2) = 3 THEN 1290
3252 GOTO 2900
3254 REM anew: a dynamic array type of rank r, z 0 or 1, r children of type 3; or a fixed-size, struct
3256 REM or record type with r = 0 and z = 0
3258 IF I(2) <= 9 THEN 2900
3260 IF I(3) > 1 THEN 2900
3262 IF T(I(2), 1) = 0 THEN 3270
3264 IF T(I(2), 3) > 0 THEN 3272
3266 IF I(4) <> T(I(2), 1) THEN 2900
3268 GOTO 3374
3270 IF C(I(2), 0) <> 4 THEN 2900
3272 IF I(3) + I(4) = 0 THEN 1290
3274 GOTO 2900
3276 REM wbin: ty 3; add, sub, mul of two operands of type 2 or 3, and of two of type 3
3278 IF I(2) <> 3 THEN 2900
3280 LET A8 = 2
3282 IF G$(4) <> "and" THEN 3286
3284 LET A8 = 3
3286 GOSUB 3450
3288 LET L5 = H(L5, 4)
3290 GOSUB 3450
3292 GOTO 1290
3294 REM hloop: its local a .l local of type 3 and mut for; three children of type 3, then a block
3296 LET V1 = I(2)
3298 GOSUB 3458
3300 IF L0 = 0 THEN 2900
3302 IF A7 <> 3 THEN 2900
3304 IF ABS(A8 - 1.5) = .5 THEN 2900
3306 IF POS(D$(G(G0, 6) + V1), " for ") = 0 THEN 2900
3308 LET A(L6) = A7 + 400000
3310 FOR J = 1 TO 3
3312 IF H(L5, 2) <> 3 THEN 2900
3314 LET L5 = H(L5, 4)
3316 NEXT J
3318 IF H(L5, 1) = 32 THEN 1290
3320 GOTO 2900
3322 REM chkb: dim 0 or 1, two children of type 3
3324 IF I(2) > 1 THEN 2900
3326 GOTO 3374
3328 REM chk: a type-2 condition; err a run-time error whose arguments take n slots
3330 IF H(L5, 2) <> 2 THEN 2900
3332 CALL "dg_find": G$(3), E$(), E0, A8
3334 IF A8 = 0 THEN 2900
3336 IF E$(A8, 2) <> "R" THEN 2900
3338 LET A7 = 0
3340 IF E$(A8, 4) = "-" THEN 3348
3342 FOR J = 1 TO LEN(E$(A8, 4))
3344 LET A7 = A7 + 1 + POS("h", SEG$(E$(A8, 4), J, J))
3346 NEXT J
3348 IF A7 = I(3) THEN 1290
3350 GOTO 2900
3352 REM rcnt incl l e: l and e distinct .l locals of types 3 and 2, declared by it; three of type 3
3354 IF I(2) > 1 THEN 2900
3356 IF I(3) = I(4) THEN 2900
3358 FOR J = 3 TO 4
3360 LET V1 = I(J)
3362 GOSUB 3458
3364 IF L0 = 0 THEN 2900
3366 IF A8 > 0 THEN 2900
3368 IF A7 <> 6 - J THEN 2900
3370 LET A(L6) = A7 + 400000
3372 NEXT J
3374 IF L5 = 0 THEN 1290
3376 IF H(L5, 2) <> 3 THEN 2900
3378 LET L5 = H(L5, 4)
3380 GOTO 3374
3382 REM cow: an lv or a fld chain of a dynamic array type
3384 IF ABS(H(L5, 1) - 30.5) <> 25.5 THEN 2900
3386 LET A7 = H(L5, 2)
3388 IF A7 <= 9 THEN 2900
3390 IF T(A7, 1) = 0 THEN 2900
3392 IF T(A7, 3) = 0 THEN 1290
3394 GOTO 2900
3396 REM mcpy: two addresses of a tptr type, a count of type 3
3398 GOSUB 3474
3400 IF A8 = 0 THEN 2900
3402 LET L5 = H(L5, 4)
3404 GOSUB 3474
3406 IF A8 = 0 THEN 2900
3408 IF H(H(L5, 4), 2) = 3 THEN 1290
3410 GOTO 2900
3412 REM ---- (end, 1667): every .l local of the function G0 declared
3414 FOR V1 = G(G0, 2) + 1 TO G(G0, 2) + G(G0, 3)
3416 GOSUB 3458
3418 IF L0 = 0 THEN 3422
3420 IF ABS(A8 - 1.5) <> .5 THEN 2900
3422 NEXT V1
3424 RETURN
3426 REM ---- the target L5 of a rarg, asg or tasg: an lv of a .l local only of one a bind declared
3428 LET L0 = 0
3430 IF H(L5, 1) <> 5 THEN 3446
3432 LET R2 = H(L5, 6)
3434 LET F9 = 4
3436 GOSUB 8440
3438 LET V1 = VAL(F9$)
3440 GOSUB 3458
3442 IF L0 = 0 THEN 3446
3444 IF A8 <> 2 THEN 2900
3446 RETURN
3448 REM ---- the type of node L5 from A8 (2 or 3) to 3
3450 IF H(L5, 2) < A8 THEN 2900
3452 IF H(L5, 2) > 3 THEN 2900
3454 RETURN
3456 REM ---- local V1 of function G0: L6 its entry of A, A7 its type, A8 its mark, L0 1 if a .l local
3458 LET L6 = G(G0, 1) + V1
3460 LET A8 = INT(A(L6) / 400000)
3462 LET A7 = A(L6) - 400000 * A8
3464 LET L0 = 0
3466 IF SEG$(D$(G(G0, 6) + V1), 1, 6) <> "loc .l" THEN 3470
3468 LET L0 = 1
3470 RETURN
3472 REM ---- A8 = 1 if node L5 is of a tptr type (the types after A6, F8 excepted), else 0
3474 LET A8 = 0
3476 IF A6 = 0 THEN 3482
3478 IF H(L5, 2) <= A6 THEN 3482
3479 IF T(H(L5, 2), 3) = 1 THEN 3482
3480 LET A8 = 1
3482 RETURN
