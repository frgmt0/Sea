30000 REM ====================================================================================
30002 REM sealower part 3 (lines 30000-39999): sea.hirl, sub-phase 4e-0 (DESIGN 3.5.9; 3.6.6 "Two
30004 REM programs", "Lowering of the sea.hirl records", rules T1-T3, 15 (k), 16 (e), 30 (1)).
30006 REM Node kinds: 43 xblk 44 tmp 45 hloop 46 ext 47 adat 48 eld 49 est 50 anew 51 wbin; 52 tptr
30008 REM is a type (T kind 4, T(.,2) its elt). Records 82-87 are not in the kind map: BAD_RECORD.
30010 REM Locals: A(.,0) the tmp node that binds it, A(.,3) the register it names when that is not
30012 REM its own (T1 another name, T3 the xblk's destination, rule 30 (1) the vector the loop
30014 REM holds), A(.,4) 1 a .l local + 2 mut for. H(bind,6) = 1: the bind of an L4 block. Fields:
30016 REM xblk H6 n; tmp, hloop H5 lid; ext H5 dim; eld, est H5 sc, H0 off (text); anew H5 z, H6 r;
30018 REM wbin H5 op (1 add 2 sub 3 mul). Resume codes 60-65 (32010).
30020 REM ====================================================================================
30040 REM ---- reading: the lib calls sealoop rewrites never reach sea.hirl (3.5.9) --------------
30050 LET K3$ = "|zeros  |ones   |filled |len    |rows   |cols   |numel  "
30052 LET W2$ = G$(4)
30054 GOSUB 1875
30056 IF W2 > 0 THEN 2360
30058 GOTO 1285
30059 REM ---- 30060: H3 = the flags of a loc record: 1 a .l local (3.5.9), + 2 mut for ---------
30060 LET H3 = 0
30062 IF LEN(G$(2)) < 3 THEN 30068
30064 IF SEG$(G$(2), 1, 2) <> ".l" THEN 30068
30066 LET H3 = 1
30068 IF G$(4) <> "for" THEN 30072
30070 LET H3 = H3 + 2
30072 RETURN
30074 REM ---- the columns 0, 3, 4 of the local just stored (par: H3 = 0), then the next record --
30075 LET A(A0, 0) = 0
30077 LET A(A0, 3) = 0
30079 LET A(A0, 4) = H3
30081 GOTO 1285
30098 REM ---- tptr id elt: after sea.hir's table (Y7 = 1 from here), ids on from its last; elt a
30099 REM scalar or str (the elements of 4d and 4g); T kind 4 -----------------------------------
30100 IF G0 > 0 THEN 2360
30102 IF I(1) <> Y9 + 1 THEN 2360
30104 LET Y9 = I(1)
30106 LET Y7 = 1
30108 IF Y9 <= T9 THEN 30114
30110 LET P8$ = "types"
30112 GOTO 1285
30114 IF I(2) < 2 THEN 2360
30116 IF I(2) > 5 THEN 2360
30118 LET T(Y9, 1) = 4
30120 LET T(Y9, 2) = I(2)
30122 GOTO 1285
30198 REM ==== reading the node records of set HL (node H1, kind K, fields I() and G$()): their
30199 REM fields, and the checks of 3.5.9 that one record allows; E1 = the function's locals base
30200 LET E1 = G(G0, 0)
30202 ON K - 42 GOTO 30210, 30240, 30290, 30330, 30370, 30400, 30440, 30480, 30530
30204 REM ---- xblk ty n: ty is its last child's type ------------------------------------------
30210 LET H(H1, 4) = I(2)
30212 LET H(H1, 6) = I(3)
30214 LET E2 = H(H1, 7)
30216 IF H(E2, 8) = 0 THEN 30222
30218 LET E2 = H(E2, 8)
30220 GOTO 30216
30222 IF H(E2, 4) <> I(2) THEN 2360
30224 GOTO 1285
30230 REM ---- tmp lid: its local bound once, of the child's type; a tptr local only of an adat --
30240 LET H(H1, 5) = I(2)
30242 LET E2 = H(H1, 7)
30244 LET E3 = H(E2, 4)
30246 IF E3 = 0 THEN 2360
30248 IF E3 <> A(E1 + I(2), 1) THEN 2360
30250 IF A(E1 + I(2), 0) <> 0 THEN 2360
30252 LET A(E1 + I(2), 0) = H1
30254 IF E3 <= 9 THEN 1285
30256 IF T(E3, 1) <> 4 THEN 1285
30258 IF H(E2, 1) <> 47 THEN 2360
30260 GOTO 1285
30280 REM ---- hloop lid: a local of type 3 and mut for; start, last, step of type 3; a block ------
30290 LET H(H1, 5) = I(2)
30292 IF A(E1 + I(2), 1) <> 3 THEN 2360
30294 IF A(E1 + I(2), 4) < 2 THEN 2360
30296 LET E2 = H(H1, 7)
30298 FOR E3 = 1 TO 3
30300 IF H(E2, 4) <> 3 THEN 2360
30302 LET E2 = H(E2, 8)
30304 NEXT E3
30306 IF H(E2, 1) <> 32 THEN 2360
30308 GOTO 1285
30320 REM ---- ext ty dim: ty 3; of an array, dim below its rank, or of a str, dim 0 ------------
30330 LET H(H1, 4) = I(2)
30332 LET H(H1, 5) = I(3)
30334 IF I(2) <> 3 THEN 2360
30336 LET E3 = H(H(H1, 7), 4)
30338 IF E3 <> 5 THEN 30344
30340 IF I(3) = 0 THEN 1285
30342 GOTO 2360
30344 GOSUB 30900
30346 IF I(3) >= E4 THEN 2360
30348 GOTO 1285
30360 REM ---- adat ty: of an array; ty the tptr of its element type -----------------------------
30370 LET H(H1, 4) = I(2)
30372 LET E3 = H(H(H1, 7), 4)
30374 GOSUB 30900
30376 IF E4 = 0 THEN 2360
30378 LET E6 = T(E3, 2)
30380 LET E3 = I(2)
30382 GOSUB 30920
30384 IF E5 = 0 THEN 2360
30386 GOTO 1285
30390 REM ---- eld ty sc off: an address of the tptr of ty, an index of type 3 ---------------------
30400 LET H(H1, 4) = I(2)
30402 LET H(H1, 5) = I(3)
30404 GOSUB 1900
30406 LET S$(S0) = G$(5)
30408 LET H(H1, 0) = S0
30410 LET E2 = H(H1, 7)
30412 LET E3 = H(E2, 4)
30414 LET E6 = I(2)
30416 GOSUB 30920
30418 IF E5 = 0 THEN 2360
30420 IF H(H(E2, 8), 4) <> 3 THEN 2360
30422 GOTO 1285
30430 REM ---- est sc off: a value, an address of the tptr of the value's type, an index of type 3 -
30440 LET H(H1, 5) = I(2)
30442 GOSUB 1900
30444 LET S$(S0) = G$(4)
30446 LET H(H1, 0) = S0
30448 LET E2 = H(H1, 7)
30450 LET E6 = H(E2, 4)
30452 LET E2 = H(E2, 8)
30454 LET E3 = H(E2, 4)
30456 GOSUB 30920
30458 IF E5 = 0 THEN 2360
30460 IF H(H(E2, 8), 4) <> 3 THEN 2360
30462 GOTO 1285
30470 REM ---- anew ty z r: z 0 or 1; ty an array type of rank r; r extents of type 3 ------------
30480 LET H(H1, 4) = I(2)
30482 LET H(H1, 5) = I(3)
30484 LET H(H1, 6) = I(4)
30486 IF I(3) > 1 THEN 2360
30488 LET E3 = I(2)
30490 GOSUB 30900
30492 IF E4 = 0 THEN 2360
30494 IF E4 <> I(4) THEN 2360
30496 LET E2 = H(H1, 7)
30498 IF E2 = 0 THEN 1285
30500 IF H(E2, 4) <> 3 THEN 2360
30502 LET E2 = H(E2, 8)
30504 GOTO 30498
30520 REM ---- wbin ty op: ty 3, two operands of type 3; op 1 add 2 sub 3 mul ---------------------
30530 LET H(H1, 4) = I(2)
30532 IF I(2) <> 3 THEN 2360
30534 LET K3$ = "|add    |sub    |mul    "
30536 LET W2$ = G$(4)
30538 GOSUB 1875
30540 IF W2 = 0 THEN 2360
30542 LET H(H1, 5) = W2
30544 LET E2 = H(H1, 7)
30546 IF H(E2, 4) <> 3 THEN 2360
30548 IF H(H(E2, 8), 4) <> 3 THEN 2360
30550 GOTO 1285
30890 REM ---- 30900: E4 = the rank of the type E3 when it is an array (tvec 1, tmat 2), else 0 ----
30900 LET E4 = 0
30902 IF E3 <= 9 THEN 30910
30904 IF T(E3, 1) = 1 THEN 30908
30905 IF T(E3, 1) <> 3 THEN 30910
30906 LET E4 = 1
30908 LET E4 = E4 + 1
30910 RETURN
30915 REM ---- 30920: E5 = 1 if the type E3 is the tptr of the element type E6, else 0 ---------------
30920 LET E5 = 0
30922 IF E3 <= 9 THEN 30930
30924 IF T(E3, 1) <> 4 THEN 30930
30926 IF T(E3, 2) <> E6 THEN 30930
30928 LET E5 = 1
30930 RETURN
30990 REM ==== 31000: the checks of 3.5.9 on the function just read (its nodes H2 .. H0): a tmp
30991 REM local read only after its tmp and never written (bind, tbind, asg, tasg, rarg; nor the
30992 REM local of an hloop or forr); a tptr local only a tmp's; the bind of a .l local only the
30993 REM first statement of an L4 block (a block of 4), which is marked H(bind,6) = 1
31000 LET E1 = G(G0, 0)
31002 FOR E2 = H2 TO H0
31004 IF H(E2, 1) <> 32 THEN 31016
31006 IF H(E2, 6) <> 4 THEN 31016
31008 LET E3 = H(E2, 7)
31010 IF H(E3, 1) <> 20 THEN 31016
31012 IF A(E1 + H(E3, 5), 4) - 2 * INT(A(E1 + H(E3, 5), 4) / 2) = 0 THEN 31016
31014 LET H(E3, 6) = 1
31016 NEXT E2
31020 FOR E2 = H2 TO H0
31022 LET E3 = H(E2, 1)
31024 IF E3 = 5 THEN 31060
31026 IF E3 = 20 THEN 31080
31028 IF E3 = 21 THEN 31100
31030 IF E3 = 23 THEN 31120
31032 IF E3 = 24 THEN 31130
31034 IF E3 = 11 THEN 31120
31036 IF E3 = 45 THEN 31090
31038 IF E3 = 27 THEN 31090
31040 NEXT E2
31042 RETURN
31050 REM an lv: after the tmp of its local; a tptr local is always a tmp's
31060 LET E4 = H(E2, 5)
31062 LET E5 = A(E1 + E4, 0)
31064 IF E5 = 0 THEN 31070
31066 IF E2 < E5 THEN 2360
31068 GOTO 31040
31070 LET E3 = A(E1 + E4, 1)
31072 IF E3 <= 9 THEN 31040
31074 IF T(E3, 1) = 4 THEN 2360
31076 GOTO 31040
31078 REM a bind: not of a tmp local; of a .l local only when marked
31080 LET E4 = H(E2, 5)
31082 IF A(E1 + E4, 0) <> 0 THEN 2360
31084 IF A(E1 + E4, 4) - 2 * INT(A(E1 + E4, 4) / 2) = 0 THEN 31040
31086 IF H(E2, 6) <> 1 THEN 2360
31088 GOTO 31040
31089 REM the local of an hloop or forr is not a tmp local
31090 IF A(E1 + H(E2, 5), 0) <> 0 THEN 2360
31092 GOTO 31040
31098 REM a tbind: none of its locals a tmp local
31100 FOR E4 = 1 TO H(E2, 6)
31102 LET E5 = M(H(E2, 0) + E4 - 1)
31104 IF E5 = 0 THEN 31108
31106 IF A(E1 + E5, 0) <> 0 THEN 2360
31108 NEXT E4
31110 GOTO 31040
31118 REM an asg or a rarg: the root local of its target (first child)
31120 LET E4 = H(E2, 7)
31122 GOSUB 31150
31124 GOTO 31040
31128 REM a tasg: the root local of each of its n targets
31130 LET E4 = H(E2, 7)
31132 FOR E6 = 1 TO H(E2, 6)
31134 GOSUB 31150
31136 LET E4 = H(E4, 8)
31138 NEXT E6
31140 GOTO 31040
31145 REM ---- 31150: the root local of the target E4 (its lv, or the base lv of an idx; a skip has
31146 REM none) is not a tmp local
31150 LET O1 = E4
31152 IF H(O1, 1) = 18 THEN 31162
31154 IF H(O1, 1) = 5 THEN 31160
31156 LET O1 = H(O1, 7)
31157 IF O1 = 0 THEN 2365
31158 GOTO 31152
31160 IF A(E1 + H(O1, 5), 0) <> 0 THEN 2360
31162 RETURN
31990 REM ==== lowering: the node kinds 43-51 (from 9705) and the resume codes 60-65 (from 9715) ===
32000 ON H(X, 1) - 42 GOTO 32200, 32100, 32400, 32400, 32400, 32400, 32400, 32400, 32400
32010 ON S - 59 GOTO 32240, 32250, 32130, 32420, 32560, 33210
32090 REM ---- tmp L (T1, T3): no instruction of its own. The child with L's register as its
32091 REM destination (A(.,3), set by T3, else L's own), except: an lv M (not a ref parameter, not a
32092 REM rule-12 copy), an ifx, && or || is lowered with no destination and L names its register
32100 LET E1 = G(F0, 0) + H(X, 5)
32102 LET E2 = H(X, 7)
32104 LET W(W0 + 3) = 0
32106 LET D1 = A(E1, 3)
32108 IF D1 > 0 THEN 32124
32110 LET D1 = 0
32112 LET W(W0 + 3) = 1
32114 IF H(E2, 1) = 17 THEN 32124
32116 IF H(E2, 1) <> 8 THEN 32119
32117 IF H(E2, 5) = 16 THEN 32124
32118 IF H(E2, 5) = 17 THEN 32124
32119 IF H(E2, 1) <> 5 THEN 32122
32120 IF A(G(F0, 0) + H(E2, 5), 2) = 1 THEN 32122
32121 IF H(E2, 6) = 0 THEN 32124
32122 LET D1 = H(X, 5)
32123 LET W(W0 + 3) = 0
32124 LET S = 62
32126 LET X1 = E2
32128 GOTO 7380
32130 IF W(W0 + 3) = 0 THEN 32134
32132 LET A(G(F0, 0) + H(X, 5), 3) = R9
32134 LET R9 = 0
32136 GOTO 3090
32190 REM ---- xblk: with a destination D and the value lv L of one of its own tmps, L's register is
32191 REM D (T3); its statements in order, then its value with the destination D; then the
32192 REM releases of its owned temporaries (T2); x1 = the value's register, x2 = the next child
32200 LET W(W0 + 4) = H(X, 7)
32202 IF D < 1 THEN 32214
32204 GOSUB 33500
32206 IF H(E2, 1) <> 5 THEN 32214
32208 LET E4 = A(G(F0, 0) + H(E2, 5), 0)
32209 IF E4 < E3 THEN 32214
32210 IF E4 >= X THEN 32214
32212 LET A(G(F0, 0) + H(E2, 5), 3) = D
32214 LET E2 = W(W0 + 4)
32216 LET X1 = E2
32217 LET D1 = 0
32218 LET S = 60
32219 IF H(E2, 8) <> 0 THEN 7380
32221 LET S = 61
32222 LET D1 = D
32223 GOTO 7380
32240 LET W(W0 + 4) = H(W(W0 + 4), 8)
32242 GOTO 32214
32250 LET W(W0 + 3) = R9
32252 GOSUB 32300
32254 LET R9 = W(W0 + 3)
32256 GOTO 3090
32290 REM ---- 32300: release the owned temporaries of the xblk X -- the tmps whose innermost xblk it
32291 REM is and whose child 9890 calls owned -- in the order of their tmp records, except the one
32292 REM its value names (moved out, T2); collected on U from the last tmp back
32300 GOSUB 33500
32302 LET E5 = 0
32304 IF H(E2, 1) <> 5 THEN 32308
32306 LET E5 = H(E2, 5)
32308 LET E6 = U0
32310 LET E4 = X - 1
32312 IF E4 < E3 THEN 32340
32314 IF H(E4, 1) <> 43 THEN 32320
32315 REM a nested xblk has its own temporaries: skip its subtree
32316 LET P4 = E4
32317 GOSUB 13480
32318 LET E4 = P4 - 1
32319 GOTO 32312
32320 IF H(E4, 1) <> 44 THEN 32336
32322 IF H(E4, 5) = E5 THEN 32336
32324 LET X0 = H(E4, 7)
32326 GOSUB 9890
32328 IF Z0 = 0 THEN 32336
32330 GOSUB 7970
32332 LET U(U0, 1) = A(G(F0, 0) + H(E4, 5), 3)
32333 IF U(U0, 1) > 0 THEN 32336
32334 LET U(U0, 1) = H(E4, 5)
32336 LET E4 = E4 - 1
32338 GOTO 32312
32340 IF U0 = E6 THEN 32350
32342 LET V1 = U(U0, 1)
32344 GOSUB 10140
32346 LET U0 = U0 - 1
32348 GOTO 32340
32350 RETURN
32390 REM ---- the children of hloop ext adat eld est anew wbin, left to right (rule 1; an lv emits
32391 REM nothing), onto U above x1 = U0; x2 = the next child; an hloop stops before its block
32400 LET W(W0 + 3) = U0
32402 LET W(W0 + 4) = H(X, 7)
32404 IF W(W0 + 4) = 0 THEN 32430
32406 IF H(X, 1) <> 45 THEN 32410
32408 IF H(W(W0 + 4), 8) = 0 THEN 32430
32410 LET S = 63
32412 LET X1 = W(W0 + 4)
32414 LET D1 = 0
32416 GOTO 7380
32420 GOSUB 7970
32422 LET U(U0, 1) = R9
32424 LET U(U0, 2) = 0
32426 LET W(W0 + 4) = H(W(W0 + 4), 8)
32428 GOTO 32404
32430 LET E1 = W(W0 + 3)
32432 ON H(X, 1) - 44 GOTO 32500, 32600, 32700, 32800, 32900, 33000, 33100
32490 REM ---- hloop K: loop B K start last step (B the next block, 3.6.4), its block, endloop B; a
32491 REM loop for break, cont and rule 16 (b) (J: 7985 with x1 = B)
32500 LET E2 = U(E1 + 1, 1)
32502 LET E3 = U(E1 + 2, 1)
32504 LET E4 = U(E1 + 3, 1)
32506 LET U0 = E1
32508 GOSUB 7885
32510 LET W(W0 + 3) = B7
32512 LET L1$ = "loop " & STR$(B7)
32514 LET V1 = H(X, 5)
32516 GOSUB 7500
32518 LET L1$ = L1$ & " " & Z$
32520 LET V1 = E2
32522 GOSUB 7500
32524 LET L1$ = L1$ & " " & Z$
32526 LET V1 = E3
32528 GOSUB 7500
32530 LET L1$ = L1$ & " " & Z$
32532 LET V1 = E4
32534 GOSUB 7500
32536 LET L1$ = L1$ & " " & Z$
32538 GOSUB 7695
32540 GOSUB 7985
32542 LET S = 64
32544 LET X1 = W(W0 + 4)
32546 LET D1 = 0
32548 GOTO 7380
32560 LET J0 = J0 - 1
32562 LET L1$ = "endloop " & STR$(W(W0 + 3))
32564 GOSUB 7695
32566 LET R9 = 0
32568 GOTO 3090
32590 REM ---- ext dim: ext(A, dim) of rule 17 (ldi E A - 0 16 or 24), of a str ldi E S - 0 16
32591 REM (SEA_STR_LEN), into the destination; an owned operand released after it (rule 15 (k))
32600 LET E2 = U(E1 + 1, 1)
32602 LET U0 = E1
32604 LET C1 = 1
32606 GOSUB 7470
32608 LET Z3 = H9
32610 IF H(H(X, 7), 4) = 5 THEN 32614
32612 LET Z3 = G2 + H(X, 5) * (G3 - G2)
32614 LET V2 = D2
32616 LET V3 = E2
32618 GOSUB 7640
32620 LET X0 = H(X, 7)
32622 LET R0 = E2
32624 GOSUB 10080
32626 LET R9 = D2
32628 GOTO 3090
32690 REM ---- adat: data(A) of rule 17 (ldp D A - 0 40) into the destination -------------------
32700 LET E2 = U(E1 + 1, 1)
32702 LET U0 = E1
32704 LET C1 = 3
32706 GOSUB 7470
32708 LET V2 = D2
32710 LET V3 = E2
32712 LET Z3 = G4
32714 GOSUB 7640
32716 LET X0 = H(X, 7)
32718 LET R0 = E2
32720 GOSUB 10080
32722 LET R9 = D2
32724 GOTO 3090
32790 REM ---- eld sc off: ldb (bool), ldi (i64), ldf (f64) or ldp (a reference, borrowed) R D X sc
32791 REM off into the destination
32800 LET E2 = U(E1 + 1, 1)
32802 LET E3 = U(E1 + 2, 1)
32804 LET U0 = E1
32806 LET T1 = H(X, 4)
32808 GOSUB 7395
32810 GOSUB 7470
32812 LET O$ = "ldp"
32814 IF H(X, 4) > 4 THEN 32818
32816 LET O$ = SEG$("ldbldildf", 3 * H(X, 4) - 5, 3 * H(X, 4) - 3)
32818 LET V2 = D2
32820 LET V3 = E2
32822 LET V4 = E3
32824 GOSUB 32950
32826 LET R9 = D2
32828 GOTO 3090
32890 REM ---- est sc off: stb, sti, stf or stp (a reference: retained first when borrowed, rule 15
32891 REM (a)) V D X sc off
32900 LET E2 = U(E1 + 1, 1)
32902 LET E3 = U(E1 + 2, 1)
32904 LET E4 = U(E1 + 3, 1)
32906 LET U0 = E1
32908 LET X0 = H(X, 7)
32910 LET R9 = E2
32912 GOSUB 10230
32914 LET E5 = H(H(X, 7), 4)
32916 LET O$ = "stp"
32918 IF E5 > 4 THEN 32922
32920 LET O$ = SEG$("stbstistf", 3 * E5 - 5, 3 * E5 - 3)
32922 LET V2 = E2
32924 LET V3 = E3
32926 LET V4 = E4
32928 GOSUB 32950
32930 LET R9 = 0
32932 GOTO 3090
32945 REM ---- 32950: L1$ = O$ V2 V3 V4, then the sc and off of node X; emitted ------------------
32950 LET V1 = V2
32952 GOSUB 7500
32954 LET L1$ = O$ & " " & Z$
32956 LET V1 = V3
32958 GOSUB 7500
32960 LET L1$ = L1$ & " " & Z$
32962 LET V1 = V4
32964 GOSUB 7500
32966 LET L1$ = L1$ & " " & Z$ & " " & STR$(H(X, 5)) & " " & S$(H(X, 0))
32968 GOSUB 7695
32970 RETURN
32990 REM ---- anew z r: arrnew (z 0, sea_arr_new_u) or arrnewz (z 1, sea_arr_new) of rule 17 with
32991 REM the element kind and rank of its type: li K ek, li N rank, for a vector li C 1, then the
32992 REM rcall into the destination (owned)
33000 LET T3 = H(X, 4)
33002 LET T2 = T(T3, 2)
33004 GOSUB 11300
33006 LET Z3 = G6
33008 IF C3 = 1 THEN 33016
33010 LET Z3 = G5
33012 IF C3 = 2 THEN 33016
33014 LET Z3 = G7
33016 GOSUB 10590
33018 LET R1 = N2
33020 LET Z3 = H(X, 6)
33022 GOSUB 10590
33024 LET R2 = N2
33026 LET R3 = U(E1 + 1, 1)
33028 IF H(X, 6) = 2 THEN 33036
33030 LET Z3 = 1
33032 GOSUB 10590
33034 LET R4 = N2
33035 GOTO 33038
33036 LET R4 = U(E1 + 2, 1)
33038 LET U0 = E1
33040 LET Q9 = Y4
33042 IF H(X, 5) = 0 THEN 33046
33044 LET Q9 = Y3
33046 LET C1 = 3
33048 GOSUB 7470
33050 GOSUB 5590
33052 LET V1 = D2
33054 GOSUB 7500
33056 LET L1$ = L1$ & " " & Z$ & " 4"
33058 LET V1 = R1
33060 GOSUB 7500
33062 LET L1$ = L1$ & " " & Z$
33064 LET V1 = R2
33066 GOSUB 7500
33068 LET L1$ = L1$ & " " & Z$
33070 LET V1 = R3
33072 GOSUB 7500
33074 LET L1$ = L1$ & " " & Z$
33076 LET V1 = R4
33078 GOSUB 7500
33080 LET L1$ = L1$ & " " & Z$
33082 GOSUB 7695
33084 LET R9 = D2
33086 GOTO 3090
33090 REM ---- wbin op: iadd, isub or imul d a b into the destination (wrapping) -----------------
33100 LET E2 = U(E1 + 1, 1)
33102 LET E3 = U(E1 + 2, 1)
33104 LET U0 = E1
33106 LET C1 = 1
33108 GOSUB 7470
33110 LET O$ = SEG$("iaddisubimul", 4 * H(X, 5) - 3, 4 * H(X, 5))
33112 LET V2 = D2
33114 LET V3 = E2
33116 LET V4 = E3
33118 GOSUB 7575
33120 LET R9 = D2
33122 GOTO 3090
33190 REM ---- the bind of an L4 block (rule 30 (1), not rule 2): the vector with no destination; an
33191 REM owned value's register is the hidden local H's (A(.,3)), a borrowed X gets mov H X, retain
33192 REM H; the .t locals of a seq vector wait for the end of the block, right after H (16 (e))
33200 LET S = 65
33202 LET X1 = H(X, 7)
33204 LET D1 = 0
33206 GOTO 7380
33210 LET E1 = G(F0, 0) + H(X, 5)
33212 LET X0 = H(X, 7)
33214 GOSUB 9890
33216 IF Z0 = 0 THEN 33224
33218 LET A(E1, 3) = R9
33220 LET V1 = R9
33222 GOTO 33240
33224 LET O$ = "mov"
33226 LET V2 = H(X, 5)
33228 LET V3 = R9
33230 GOSUB 7540
33232 LET V1 = H(X, 5)
33234 GOSUB 10180
33236 LET V1 = H(X, 5)
33238 REM the seq's .t locals pending on this bind (frame W0) move to the block (frame W0 - 6)
33240 LET E2 = J9
33242 IF E2 = 0 THEN 33252
33244 IF J(E2, 4) <> W0 THEN 33252
33246 LET J(E2, 4) = W0 - 6
33248 LET E2 = E2 - 1
33250 GOTO 33242
33252 GOSUB 10320
33254 GOTO 3090
33290 REM ---- 33300 (of 9890): an xblk P5 is owned exactly when its value is (rule 15 (k), T2): an
33291 REM owned node, or lv L of a tmp of it whose child is owned
33300 LET O1 = H(P5, 7)
33302 IF H(O1, 8) = 0 THEN 33308
33304 LET O1 = H(O1, 8)
33306 GOTO 33302
33308 IF H(O1, 1) <> 5 THEN 33330
33310 LET O2 = A(G(F0, 0) + H(O1, 5), 0)
33312 IF O2 = 0 THEN 33330
33313 IF O2 >= P5 THEN 33330
33314 LET O3 = P5
33316 IF H(O3, 7) = 0 THEN 33322
33318 LET O3 = H(O3, 7)
33320 GOTO 33316
33322 IF O2 < O3 THEN 33330
33324 LET P5 = H(O2, 7)
33326 GOTO 9910
33330 LET P5 = O1
33332 GOTO 9910
33390 REM ---- 33400 (of the seq, 15360): J(J9,4) = the frame that consumes the seq of frame W0: its
33391 REM parent, or for a tmp the innermost xblk holding it (T2), else that tmp
33400 LET E2 = W0 - 6
33402 LET J(J9, 4) = E2
33404 IF H(W(E2), 1) <> 44 THEN 33416
33406 LET E2 = E2 - 6
33408 IF E2 < 6 THEN 33416
33410 IF H(W(E2), 1) <> 43 THEN 33406
33412 LET J(J9, 4) = E2
33416 RETURN
33490 REM ---- 33500: E2 = the last child of node X, E3 = the first node of its subtree ----------
33500 LET E2 = H(X, 7)
33502 IF H(E2, 8) = 0 THEN 33508
33504 LET E2 = H(E2, 8)
33506 GOTO 33502
33508 LET E3 = X
33510 IF H(E3, 7) = 0 THEN 33516
33512 LET E3 = H(E3, 7)
33514 GOTO 33510
33516 RETURN
