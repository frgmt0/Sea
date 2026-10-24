50000 REM sealower part 5 (lines 50000-59999): sub-phase 4g-2, structs, records, fields (DESIGN 3.5.9 R18-R24; 3.6.6 rules 15 (g), 16, 18, 27, 31, 38). Layouts from layout.bas in O() (L-k; O(t,6) a slay label). A home or aggregate address register
50001 REM has V(.,0) = 1, V(.,3) its type. Fields: fld H5 i. ---- 50003: I2 = the base of the fld chain from node I2, I3 = the sum of its field offsets --
50003 LET I3 = 0
50004 IF H(I2, 1) <> 60 THEN 50010
50005 CALL "ly_fld": O(), H(H(I2, 7), 4), H(I2, 5), I4, I5
50006 LET I3 = I3 + I5
50008 LET I2 = H(I2, 7)
50009 GOTO 50004
50010 RETURN
50098 REM ---- 50100 (10145): L2$ (release or retain) of each reference value of the home V1, ascending, O$ kept (rules 15 (g), 16, 27 (c), (d))
50100 LET I6 = V1
50101 LET O9$ = O$
50102 LET I7 = V(V1, 3)
50104 FOR I8 = 1 TO O(I7, 3)
50106 CALL "ly_ref": O(), I7, I8, Z3
50108 GOSUB 7418
50112 LET V2 = N2
50114 LET V3 = I6
50116 GOSUB 7640
50118 LET V1 = N2
50120 GOSUB 10150
50122 NEXT I8
50123 LET O$ = O9$
50124 RETURN
50198 REM ---- fld: a chain over an idx folds into its load (rule 18); else its base, then 50300 at the summed offset; of a temporary base: 15 (f)
50200 LET I2 = X
50202 GOSUB 50003
50204 LET X1 = I2
50206 LET D1 = D
50208 LET S = 22
50210 IF H(I2, 1) = 39 THEN 7380
50212 LET S = 68
50214 GOTO 7375
50220 LET Q0 = R9
50222 LET I2 = X
50224 GOSUB 50003
50226 LET M2 = 0
50228 LET M4 = I3
50230 LET M8 = H(X, 4)
50232 GOSUB 50300
50234 LET X0 = X
50236 GOSUB 42668
50238 LET X0 = I2
50240 LET R0 = Q0
50242 GOSUB 10080
50244 GOTO 3088
50298 REM ---- 50300: the load ld? D2 Q0 M2 M3 M4 (M2 = 0: Q0 - 0 M4) of type M8; an aggregate M8 (50330): its address li S M3, imul, padd (li O M4, padd), a new home D2
50300 LET T5 = M8
50302 GOSUB 40600
50304 IF F5 = 1 THEN 50330
50306 LET T1 = M8
50308 GOSUB 7395
50310 GOSUB 7470
50312 LET O$ = "ldp"
50314 IF M8 > 4 THEN 50318
50316 LET O$ = SEG$("ldbldildf", 3 * M8 - 5, 3 * M8 - 3)
50318 LET V2 = D2
50320 LET V3 = Q0
50322 LET Z3 = M4
50324 IF M2 = 0 THEN 7655
50326 LET V4 = M2
50328 LET Z3 = M3
50329 GOTO 11410
50330 GOSUB 7418
50334 LET D2 = N2
50336 LET V(D2, 0) = 1
50338 LET V(D2, 3) = M8
50340 LET V3 = Q0
50342 IF M2 = 0 THEN 50366
50344 LET Z3 = M3
50346 GOSUB 10590
50348 LET V4 = N2
50350 LET V3 = M2
50352 LET O$ = "imul"
50354 GOSUB 42795
50356 LET V4 = V2
50358 LET V3 = Q0
50360 GOSUB 50370
50362 IF M4 = 0 THEN 50376
50364 LET V3 = D2
50366 LET Z3 = M4
50367 GOSUB 10590
50368 LET V4 = N2
50370 LET V2 = D2
50372 LET O$ = "padd"
50374 GOTO 7575
50376 RETURN
50398 REM ---- 50400: D2 = a new home holding a copy of the aggregate D2, its references retained (rules 12 (c), 15 (f), 27 (c)); falls into 50600
50400 LET V3 = D2
50402 LET T5 = V(D2, 3)
50404 GOSUB 40622
50408 LET V2 = D2
50410 LET Z0 = 0
50498 REM ---- 50600: copy (rule 27 (c)) of type T5 from V3 into the home V2; retains on V2 unless Z0 = 1 (an owned source, moved)
50600 GOSUB 40670
50602 IF Z0 = 1 THEN 50608
50604 LET V1 = V2
50606 GOTO 10180
50608 RETURN
50698 REM ---- slit (rule 27 (g)): its home (the destination home, else a new slot), each value stored at its field right after it (resume 69)
50700 LET D2 = D
50702 IF D < 1 THEN 50706
50704 IF V(D, 0) = 1 THEN 50710
50706 LET T5 = H(X, 4)
50707 GOSUB 40622
50710 LET W(W0 + 3) = D2
50712 LET W(W0 + 4) = H(X, 7)
50716 IF W(W0 + 4) = 0 THEN 50760
50718 LET S = 69
50720 GOTO 7366
50730 CALL "ly_fld": O(), H(X, 4), W(W0 + 5), M8, M4
50732 LET Q0 = W(W0 + 3)
50734 LET X0 = W(W0 + 4)
50736 LET T5 = M8
50738 GOSUB 40600
50740 IF F5 = 1 THEN 50751
50741 GOSUB 10230
50742 LET O$ = "stp"
50743 IF M8 > 4 THEN 50746
50744 LET O$ = SEG$("stbstistf", 3 * M8 - 5, 3 * M8 - 3)
50746 LET V2 = R9
50747 LET V3 = Q0
50748 LET Z3 = M4
50749 GOSUB 7655
50750 GOTO 50757
50751 LET M2 = 0
50752 GOSUB 50330
50753 GOSUB 9890
50754 LET V2 = D2
50755 LET V3 = R9
50756 GOSUB 50600
50757 LET W(W0 + 4) = H(W(W0 + 4), 8)
50758 LET W(W0 + 5) = W(W0 + 5) + 1
50759 GOTO 50716
50760 LET R9 = W(W0 + 3)
50762 GOTO 3090
51098 REM ---- 51100: M4 = the off of the eld or est X, plus k*sc when its index (last child) is a ci k (R3); 51099: with M3 = H(X, 5)
51099 LET M3 = H(X, 5)
51100 CALL "io_i": S$(H(X, 0)), M4, K9, L(), T
51102 LET O4 = H(X, 7)
51104 IF H(O4, 8) = 0 THEN 51110
51106 LET O4 = H(O4, 8)
51108 GOTO 51104
51110 IF H(O4, 1) <> 1 THEN 51120
51112 CALL "io_i": S$(H(O4, 0)), O8, K9, L(), T
51114 LET M4 = M4 + O8 * H(X, 5)
51120 RETURN
51198 REM ---- 51200: W4 = 1 if the address of the est X is fresh: lv D of tmp D = adat (lv A), tmp A = anew before it in its xblk or block
51200 LET W4 = 0
51202 LET D5 = H(H(X, 7), 8)
51204 IF H(D5, 1) <> 5 THEN 51220
51206 LET D5 = A(G(F0, 0) + H(D5, 5), 0)
51208 LET D6 = H(D5, 7)
51210 IF 100 * H(D6, 1) + H(H(D6, 7), 1) <> 4705 THEN 51220
51212 LET D6 = A(G(F0, 0) + H(H(D6, 7), 5), 0)
51214 IF H(H(D6, 7), 1) <> 50 THEN 51220
51216 LET D6 = H(D6, 8)
51217 IF D6 = 0 THEN 51220
51218 IF D6 <> D5 THEN 51216
51219 LET W4 = 1
51220 RETURN
51298 REM ---- 51300 (reading eld, est): address type E3, value type E6, sc W7, off W8: the tptr of E6 (an aggregate whole only at off 0, R18, R19), or of a struct or record S with sc its size and a field of type E6 at off (R24, ly_at)
51300 GOSUB 30920
51302 LET T5 = E6
51304 GOSUB 40600
51306 IF E5 = 0 THEN 51312
51308 IF F5 * W8 <> 0 THEN 2360
51310 RETURN
51312 IF E3 <= 9 THEN 2360
51314 IF T(E3, 1) <> 4 THEN 2360
51316 LET W9 = T(E3, 2)
51318 IF T(W9, 1) <> 7 THEN 2360
51320 IF W7 <> O(W9, 1) THEN 2360
51322 CALL "ly_at": O(), W9, W8, E6, S2
51324 IF S2 = 0 THEN 2360
51326 RETURN
51398 REM ---- 51400: I2 = the value of node I2 through seqs (rule 5) -------------------------------
51400 IF H(I2, 1) <> 19 THEN 51410
51402 LET I2 = H(I2, 7)
51404 IF H(I2, 8) = 0 THEN 51400
51406 LET I2 = H(I2, 8)
51408 GOTO 51404
51410 RETURN
51498 REM ---- est whose value is a slit (R19, rule 26 (b)): its address and index first (32403), then E, then the slit written in place at E (resume 70); only fresh
51500 LET I2 = H(X, 7)
51502 GOSUB 51400
51504 IF H(I2, 1) <> 61 THEN 32404
51506 LET W(W0 + 5) = 1
51508 LET W(W0 + 4) = H(H(X, 7), 8)
51510 GOTO 32404
51550 IF W(W0 + 5) = 0 THEN 32900
51552 LET U0 = E1
51554 GOSUB 51200
51556 IF W4 = 0 THEN 2360
51558 LET Q0 = U(E1 + 1, 1)
51560 LET M2 = U(E1 + 2, 1)
51562 GOSUB 51099
51566 LET M8 = H(H(X, 7), 4)
51568 GOSUB 50330
51570 LET S = 70
51572 LET X1 = H(X, 7)
51574 LET D1 = D2
51576 GOTO 7380
51580 GOTO 3081
51998 REM ---- est of an aggregate value E2 (R19, from 32911): E, then fresh copy(E <- V) with retains of a borrowed V, else V's retains, E's old references released, mcopy
52000 LET T5 = H(X0, 4)
52002 GOSUB 40600
52004 IF F5 = 0 THEN 32912
52006 GOSUB 51200
52008 LET Q0 = E3
52010 LET M2 = E4
52012 GOSUB 51099
52016 LET M8 = H(X0, 4)
52018 GOSUB 50330
52020 LET W7 = D2
52022 IF W4 = 1 THEN 52032
52023 LET R9 = E2
52024 GOSUB 42000
52026 LET V1 = W7
52028 GOSUB 10140
52030 LET Z0 = 1
52031 GOTO 52034
52032 GOSUB 9890
52034 LET V2 = W7
52036 LET V3 = E2
52038 LET T5 = M8
52040 GOSUB 50600
52042 GOTO 3081
52098 REM ---- eld of an aggregate type (R18, from 32805): its address, borrowed (15 (f) of a temporary: 42666)
52100 GOSUB 40592
52104 IF F5 = 0 THEN 32806
52106 LET Q0 = E2
52108 LET M2 = E3
52110 GOSUB 51099
52114 LET M8 = T5
52116 GOSUB 50330
52118 GOTO 32825
52198 REM ---- an idx folded by its parent fld chain (13180): the outermost fld's type and the summed offset, into its destination (40740 cleared the idx's)
52200 LET X0 = W(W0 - 6)
52201 LET D = W(W0 - 5)
52202 LET M8 = H(X0, 4)
52204 LET I2 = X0
52206 GOSUB 50003
52208 LET M4 = I3
52210 GOTO 13190
52298 REM ---- adat right after a cow of the same lv or fld chain (R23): the cow's A, no load of the chain; of a ref parameter's lv (L-n) only as an est's address or L17's D'
52300 IF H(W5, 8) = 0 THEN 32400
52302 FOR I5 = W0 TO 12 STEP -6
52304 IF H(W(I5 - 6), 1) = 32 THEN 52308
52306 NEXT I5
52307 GOTO 32400
52308 IF H(W5, 8) <> W(I5) THEN 32400
52310 LET I2 = H(X, 7)
52312 LET I4 = H(W5, 7)
52314 IF H(I2, 1) <> H(I4, 1) THEN 32400
52316 IF H(I2, 5) <> H(I4, 5) THEN 32400
52318 IF H(I2, 1) = 60 THEN 52336
52320 IF H(I2, 1) <> 5 THEN 32400
52322 IF I2 <> H(X, 7) THEN 52340
52324 IF A(G(F0, 0) + H(I2, 5), 2) = 0 THEN 52340
52326 IF H(W(I5), 1) = 49 THEN 52340
52328 LET I4 = H(H(W(I5), 8), 7)
52330 IF H(I4, 1) <> 48 THEN 32400
52332 IF H(W(I5), 1) + H(H(W(I5), 8), 1) + 4 * T(H(I4, 4), 1) <> 116 THEN 32400
52334 GOTO 52340
52336 LET I2 = H(I2, 7)
52338 LET I4 = H(I4, 7)
52339 GOTO 52314
52340 LET E1 = U0
52342 LET W(W0 + 3) = U0
52344 LET E2 = W6
52346 GOTO 32701
52398 REM ---- cow of a fld chain (R23): the memory form of rule 19 at the field (base the chain's lv: a struct local, ref parameter or element address)
52400 LET I2 = H(X, 7)
52402 GOSUB 50003
52404 LET C7 = A(G(F0, 0) + H(I2, 5), 3)
52406 IF C7 > 0 THEN 52410
52408 LET C7 = H(I2, 5)
52410 LET S1 = I3
52412 LET F6 = 0
52414 GOSUB 11690
52416 LET S1 = 0
52418 GOTO 41519
52420 LET W5 = X
52422 LET W6 = C8
52424 RETURN
52498 REM ---- (reading a cow, 40287) a fld chain over the lv of a struct or record, naming an array field
52500 LET I2 = E2
52502 GOSUB 50003
52504 IF H(I2, 1) <> 5 THEN 2360
52506 IF T(H(I2, 4), 1) <> 7 THEN 2360
52508 GOTO 40290
52644 REM ---- 52646: R9 = the address Q0 + I3 (li O I3, padd A Q0 O; marked as a home of type M8, 50330)
52646 LET M2 = 0
52648 LET M4 = I3
52650 GOSUB 50330
52652 LET R9 = D2
52654 RETURN
52698 REM ---- arrnew of struct or record elements (rule 17, 38): la of the type's slay label, given at its first la; sea_arr_new_s
52700 IF O(T2, 6) > 0 THEN 52710
52702 LET Q3 = 6
52704 LET Q4 = T2
52706 GOSUB 7935
52708 LET O(T2, 6) = D0
52710 GOSUB 7418
52714 LET L1$ = "la" & FNR$(N2) & " d" & STR$(O(T2, 6))
52720 GOSUB 7695
52722 GOTO 33018
52730 LET Q9 = U1
52732 GOTO 33046
52740 LET C3 = 5
52742 LET Z3 = O(T2, 1)
52744 RETURN
52748 REM ---- writing a slay record (label I of the type X) and its soff records (3.6.2, rule 38)
52750 CALL "io_put": 2, "slay d" & STR$(I) & " " & STR$(O(X, 1)) & " " & STR$(O(X, 3))
52752 FOR I8 = 1 TO O(X, 3)
52754 CALL "ly_ref": O(), X, I8, Z3
52756 CALL "io_put": 2, "soff " & STR$(Z3)
52758 NEXT I8
52760 GOTO 1825
52798 REM ---- reading fld (child a struct or record, i a field of it, ty its type) and slit (n the fields, the children their types)
52800 LET H(H1, 4) = I(2)
52802 LET H(H1, 5) = I(3)
52804 LET E3 = H(H(H1, 7), 4)
52806 IF T(E3, 1) <> 7 THEN 2360
52808 IF I(3) >= T(E3, 2) THEN 2360
52810 CALL "ly_fld": O(), E3, I(3), E4, E5
52812 IF E4 <> I(2) THEN 2360
52814 GOTO 1285
52820 LET H(H1, 4) = I(2)
52822 IF T(I(2), 1) <> 7 THEN 2360
52824 IF I(3) <> T(I(2), 2) THEN 2360
52826 LET E2 = H(H1, 7)
52828 FOR E6 = 0 TO I(3) - 1
52830 CALL "ly_fld": O(), I(2), E6, E4, E5
52832 IF H(E2, 4) <> E4 THEN 2360
52834 LET E2 = H(E2, 8)
52836 NEXT E6
52838 GOTO 1285
52848 REM ---- reading tstruct, trec (after sea.hir's tvec ... types, before any tptr) and their fd records into the layout (ly_st, ly_fd)
52850 IF K = 64 THEN 52880
52852 GOSUB 1301
52860 IF Y9 > T9 THEN 52876
52862 LET T(Y9, 1) = 7
52864 LET T(Y9, 2) = I(3 - INT(K / 63))
52866 CALL "ly_st": O(), Y9, T(Y9, 2), T
52868 IF T = 0 THEN 1285
52870 IF O(0, 4) <> 0 THEN 2360
52876 GOTO 1282
52880 IF P8$ <> "" THEN 1285
52882 CALL "ly_fd": O(), I(2), T
52884 IF T <> 0 THEN 2360
52886 GOTO 1285
52890 CALL "ly_fix": O(), Y9, I(2), I(3) * T(Y9, 0), T
52892 IF T <> 0 THEN 2360
52894 RETURN
52898 REM ---- the bind of an aggregate local (41038): bound (rule 16, the .t locals of a seq it binds moved to the block: 33236), unless a seq's .t local (16 (e)); 52950: an ifx arm copied, moved when owned (27 (k))
52900 IF H(W(W0 - 6), 1) = 19 THEN 3090
52902 GOTO 33236
52950 GOSUB 9890
52952 GOTO 50600
52998 REM ---- mcpy into counted elements (R20, 42700): 53000 the retains at D4 for each reference offset of the element I7 at M2 (index) M3 J3, ascending
53000 FOR I8 = 1 TO O(I7, 3)
53002 CALL "ly_ref": O(), I7, I8, M4
53004 LET M4 = M4 + J3
53006 LET Q0 = D4
53008 LET M8 = 5
53010 GOSUB 50300
53012 LET V1 = D2
53014 GOSUB 10180
53016 NEXT I8
53018 RETURN
53098 REM ---- 53100: Z0 = 1 if the source is an owned aggregate home named by a tmp (adat of its lv): moved, and that tmp is marked H(.,6) = 1 (T2 skips it)
53100 LET Z0 = 0
53102 LET I2 = H(H(X, 7), 8)
53104 IF H(I2, 1) <> 5 THEN 53110
53106 LET I2 = H(A(G(F0, 0) + H(I2, 5), 0), 7)
53110 IF H(I2, 1) <> 47 THEN 53130
53112 LET I2 = H(I2, 7)
53114 IF H(I2, 1) <> 5 THEN 53130
53116 LET I4 = A(G(F0, 0) + H(I2, 5), 0)
53118 LET X0 = H(I4, 7)
53120 LET T5 = H(X0, 4)
53122 GOSUB 40600
53124 IF F5 * I4 = 0 THEN 53130
53126 GOSUB 9890
53128 LET H(I4, 6) = Z0
53130 RETURN
53198 REM ---- asg set to an aggregate local or ref parameter (rule 27 (d), from 41056): V's retains when borrowed, H's old references released, mcopy H V
53200 LET X0 = H(H(X, 7), 8)
53202 GOSUB 10230
53204 LET V1 = H(H(X, 7), 5)
53206 GOSUB 10140
53208 LET V2 = H(H(X, 7), 5)
53210 LET V3 = R9
53212 LET T5 = A(G(F0, 0) + V2, 1)
53214 GOSUB 40670
53216 GOTO 3090
53290 LET P5 = P4
53292 LET P4 = Y8
53294 GOTO 23692
53298 REM ---- 53300 (23646, 23660; rule 12 (b), (c)): the root read J5 as the base of a path (flds, idx bases): its outermost node Y8 owned when it holds counts and its consumer comes after the rarg (idx H5, fld H6 = 1; 53334); else 53290
53300 LET P6 = J5
53302 IF H(P4, 1) = 60 THEN 53308
53304 IF H(P4, 1) <> 39 THEN 53315
53306 IF H(P4, 7) <> P6 THEN 53315
53308 LET P6 = P4
53310 GOSUB 23780
53312 LET P4 = P5
53314 GOTO 53302
53315 IF H(P4, 1) = 11 THEN 2710
53316 LET Y8 = P6
53318 LET T3 = H(Y8, 4)
53320 GOSUB 9802
53322 IF U3 = 0 THEN 53290
53324 LET P5 = Y8
53326 GOSUB 42960
53328 IF U6 <= K4 THEN 2710
53330 LET H(Y8, 5 + INT(H(Y8, 1) / 60)) = 1
53332 GOTO 2710
53334 IF H(P5, 6) = 1 THEN 10050
53336 GOTO 10010
53338 REM ---- 53340 (ret, before each value X1): D1 = the next fixed result's hidden address N2 when the value is a slit (through seqs), written there directly (rule 27 (h)), else 0
53340 LET D1 = 0
53342 GOSUB 41120
53344 IF F5 = 0 THEN 53354
53346 LET I2 = X1
53348 GOSUB 51400
53350 IF H(I2, 1) <> 61 THEN 53354
53352 LET D1 = N2
53354 RETURN
53498 REM ---- rarg of an element or field path (rule 31, from 4518): the root lv, then each index in path order (x3 the node, its register kept in its H0: 53520), then 53540
53500 GOSUB 53600
53502 LET P6 = H8
53510 LET W(W0 + 5) = P6
53512 LET S = 45
53514 LET X1 = P6
53516 GOTO 7375
53520 LET P6 = W(W0 + 5)
53522 LET H(P6, 0) = R9
53524 IF H(P6, 8) > 0 THEN 53534
53526 IF P6 = H(W(W0 + 4), 7) THEN 53540
53528 LET P6 = P6 + 1
53530 GOTO 53524
53534 LET P6 = H(P6, 8)
53536 GOTO 53510
53538 REM at its place: deferred (rule 31, 16780) only its checks (H(X2,0) = 1, the argument 0 for now), else checks, cows and the address
53540 LET X2 = W(W0 + 4)
53542 GOSUB 53600
53544 GOSUB 16780
53546 LET H(X2, 0) = Z0
53548 LET J7 = 1 - Z0
53550 LET J8 = 1
53552 GOSUB 53620
53554 LET R9 = R9 * J7
53556 LET X = W(W0)
53558 LET Q5 = 0
53560 GOTO 4630
53598 REM ---- 53600: H8 = the root lv of the path of the rarg X2 (through idx bases and flds), A1 its local
53600 LET H8 = H(X2, 7)
53602 IF H(H8, 1) = 5 THEN 53608
53603 IF ABS(H(H8, 1) - 49.5) <> 10.5 THEN 2360
53604 LET H8 = H(H8, 7)
53606 GOTO 53602
53608 LET A1 = H(H8, 5)
53610 RETURN
53618 REM ---- 53620: R9 = the address of the path of X2 from its root H8 (rule 31): J7 = 1 with the cows, J8 = 1 at its place (the root as loaded there, the idx sites) A8 + T7 (T7 < 0: none) is the address of the node H8 (T8 1), the place of its
53619 REM array (T8 2), or T8 3 a local array in A8; X3 its parent
53620 LET A8 = A(G(F0, 0) + A1, 3)
53622 IF A8 > 0 THEN 53626
53624 LET A8 = A1
53626 LET T7 = -1
53630 LET T5 = H(H8, 4)
53632 GOSUB 40600
53634 LET T8 = 3 - A(G(F0, 0) + A1, 2) - F5 * (2 - A(G(F0, 0) + A1, 2))
53640 LET A9 = H8
53642 IF H(A9, 8) = 0 THEN 53648
53644 LET A9 = H(A9, 8)
53646 GOTO 53642
53648 LET X3 = A9 + 1
53650 IF X3 = X2 THEN 53720
53652 IF H(X3, 1) = 39 THEN 53660
53654 CALL "ly_fld": O(), H(H8, 4), H(X3, 5), T5, I5
53655 LET T7 = (T7 + ABS(T7)) / 2 + I5
53656 LET T8 = 2 - SGN(ABS(ABS(T(T5, 1) - 2) - 1))
53658 LET H8 = X3
53659 GOTO 53640
53660 LET A9 = H(H(X3, 7), 8)
53662 LET R1 = H(A9, 0)
53664 LET R2 = H(H(A9, 8), 0)
53666 LET X = X3 * J8 + X * (1 - J8)
53670 LET F6 = INT(1 / T8)
53672 LET T6 = H(H8, 4)
53674 IF F6 = 0 THEN 53680
53676 GOSUB 53720
53678 LET R6 = R9
53679 GOTO 53689
53680 LET R6 = A8
53682 IF T8 = 3 THEN 53689
53684 IF J8 - SGN(ABS(H(H8, 1) - 5)) <> 1 THEN 53688
53686 LET R6 = H(H8, 0)
53687 GOTO 53689
53688 GOSUB 53730
53689 IF X3 = U9 THEN 53729
53690 GOSUB 10920
53691 IF J7 + SGN(ABS(X3 - H(X2, 7))) = 0 THEN 53729
53692 LET C8 = R6 + (A8 - R6) * INT(T8 / 3)
53694 IF F6 + 1 - J7 > 0 THEN 53704
53696 LET C7 = A8 * (3 - T8)
53698 LET S1 = (T7 + ABS(T7)) / 2
53700 GOSUB 11690
53702 LET S1 = 0
53704 GOSUB 17680
53706 LET A8 = R9
53708 LET T7 = -1
53709 LET T8 = 1
53710 LET H8 = X3
53712 GOTO 53640
53718 REM ---- 53720: R9 = the address A8 + T7 of the node H8 (li O T7, padd: 52646); 53730: R6 = ldp A8 - 0 T7, the array at that place
53720 LET R9 = A8
53722 IF T7 < 0 THEN 53729
53724 LET Q0 = A8
53725 LET M8 = H(H8, 4)
53726 LET I3 = T7
53727 GOTO 52646
53729 RETURN
53730 GOSUB 7418
53734 LET Z3 = (T7 + ABS(T7)) / 2
53735 LET L1$ = SEG$("ldildfldp", 3 * V(N2, 1) - 2, 3 * V(N2, 1)) & FNR$(N2) & FNR$(A8) & " - 0 " & STR$(Z3)
53736 GOSUB 7695
53738 LET R6 = N2
53739 RETURN
53758 REM ---- 53760 ($ in an index of the idx P3 of a rarg path whose base is no root, 13370): the base's array R6 by 53620 up to P3 (checks, no cows), kept in H(P3,0)
53760 FOR A9 = W0 TO 6 STEP -6
53762 IF W(A9 + 2) = 45 THEN 53766
53764 NEXT A9
53765 GOTO 2365
53766 LET B8 = X
53767 LET X9 = X2
53768 LET U9 = P3
53769 LET X2 = W(A9 + 4)
53770 GOSUB 53600
53771 LET J7 = 0
53772 LET J8 = 1
53773 GOSUB 53620
53774 LET P3 = U9
53775 LET H(P3, 0) = R6
53776 LET U9 = 0
53777 LET X = B8
53778 LET X2 = X9
53779 GOTO 13380
