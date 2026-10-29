30000 REM ====================================================================================
30002 REM sealower part 3 (lines 30000-39999): sea.hirl, sub-phase 4e-0 (DESIGN 3.5.9; 3.6.6 "Two programs", "Lowering of the sea.hirl records", rules T1-T3, 15 (k), 16 (e), 30 (1)). Node kinds: 43 xblk 44 tmp 45 hloop 46 ext 47 adat 48 eld 49 est 50
30004 REM anew 51 wbin; 52 tptr is a type (T kind 4, T(.,2) its elt). Records 82-87 are not in the kind map: BAD_RECORD. Locals: A(.,0) the tmp node that binds it, A(.,3) the register it names when that is not its own (T1 another name, T3 the xblk's
30006 REM destination, rule 30 (1) the vector the loop holds), A(.,4) 1 a .l local + 2 mut for. H(bind,6) = 1: the bind of an L4 block. Fields: xblk H6 n; tmp, hloop H5 lid; ext H5 dim; eld, est H5 sc, H0 off (text); anew H5 z, H6 r; wbin H5 op (1
30008 REM add 2 sub 3 mul). Resume codes 60-65 (32010). Sub-phase 4h: kinds 65 iblk, 66 iret, resume codes 71, 72 (33690).
30020 REM ====================================================================================
30040 REM ---- reading: the lib calls sealoop rewrites never reach sea.hirl (3.5.9; those of L13, L14 take an array operand: R10, 40116); sort and argsort do (R16) ---------------------------
30050 LET K3$ = "|zeros  |ones   |filled |len    |rows   |cols   |numel  "
30052 GOSUB 1872
30056 IF W2 > 0 THEN 2360
30057 IF POS("|sort|argsort|", "|" & W2$ & "|") > 0 THEN 30130
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
30098 REM ---- tptr id elt: after sea.hir's table (Y7 = 1 from here), ids on from its last; elt a scalar or str (the elements of 4d and 4g); T kind 4 -----------------------------------
30100 GOSUB 1302
30106 LET Y7 = 1
30108 IF Y9 > T9 THEN 1282
30114 IF I(2) < 2 THEN 2360
30115 IF T(I(2), 1) = 7 THEN 30118
30116 IF I(2) > 5 THEN 2360
30118 LET T(Y9, 1) = 4
30120 LET T(Y9, 2) = I(2)
30122 GOTO 1285
30126 REM ---- lib sort / argsort (R16): two children, a dynamic vector of f64, i64 or str elements and a bool desc; the result that vector's type (sort) or an i64 vector (argsort)
30130 IF H(H1, 6) <> 2 THEN 2360
30132 LET E2 = H(H1, 7)
30134 LET E3 = H(E2, 4)
30136 IF E3 <= 9 THEN 2360
30138 IF T(E3, 1) <> 1 THEN 2360
30140 IF T(E3, 2) < 3 THEN 2360
30142 IF T(E3, 2) > 5 THEN 2360
30144 IF H(H(E2, 8), 4) <> 2 THEN 2360
30146 LET E4 = H(H1, 4)
30148 IF W2$ = "sort" THEN 30158
30150 IF E4 <= 9 THEN 2360
30152 IF T(E4, 1) <> 1 THEN 2360
30154 IF T(E4, 2) = 3 THEN 1285
30156 GOTO 2360
30158 IF E4 <> E3 THEN 2360
30160 GOTO 1285
30198 REM ==== reading the node records of set HL (node H1, kind K, fields I() and G$()): their fields, and the checks of 3.5.9 that one record allows; E1 = the function's locals base
30200 LET E1 = G(G0, 0)
30202 ON K - 42 GOTO 30210, 30240, 30290, 30330, 30370, 30400, 30440, 30480, 30530, 2360, 40200, 40210, 40242, 40286, 40302, 40320, 2360, 52800, 52820, 2360, 2360, 2360, 33900, 33978
30204 REM ---- xblk ty n: ty is its last child's type; an iblk value makes it inline (33980)
30210 LET H(H1, 4) = I(2)
30212 LET H(H1, 6) = I(3)
30214 LET E2 = H(H1, 7)
30215 LET E5 = 0
30216 IF H(E2, 8) = 0 THEN 30222
30217 LET E5 = E5 + SGN(ABS(H(E2, 1) - 44))
30218 LET E2 = H(E2, 8)
30220 GOTO 30216
30222 IF H(E2, 4) <> I(2) THEN 2360
30223 IF H(E2, 1) = 65 THEN 33982
30224 GOTO 33990
30230 REM ---- tmp lid: its local bound once, of the child's type; a tptr local only of an adat --
30240 LET H(H1, 5) = I(2)
30242 LET E2 = H(H1, 7)
30244 LET E3 = H(E2, 4)
30246 IF E3 = 0 THEN 2360
30248 IF E3 <> A(E1 + I(2), 1) THEN 2360
30250 IF A(E1 + I(2), 0) <> 0 THEN 2360
30252 LET A(E1 + I(2), 0) = H1
30253 LET A(E1 + I(2), 2) = 1 - SGN(ABS(H(E2, 1) - 11))
30254 IF E3 <= 9 THEN 1285
30256 IF T(E3, 1) <> 4 THEN 1285
30257 IF H(E2, 1) = 58 THEN 1285
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
30373 LET E6 = E3
30374 IF T(E3, 1) = 7 THEN 30380
30375 GOSUB 30900
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
30415 LET W7 = I(3)
30416 CALL "io_i": G$(5), W8, K9, L(), T
30418 GOSUB 51300
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
30455 LET W7 = I(2)
30456 CALL "io_i": G$(4), W8, K9, L(), T
30458 GOSUB 51300
30460 IF H(H(E2, 8), 4) <> 3 THEN 2360
30462 GOTO 1285
30470 REM ---- anew ty z r: z 0 or 1; ty an array type of rank r; r extents of type 3 ------------
30480 LET H(H1, 4) = I(2)
30482 LET H(H1, 5) = I(3)
30484 LET H(H1, 6) = I(4)
30486 IF I(3) > 1 THEN 2360
30488 LET E3 = I(2)
30489 IF T(E3, 1) = 7 THEN 40344
30490 GOSUB 30900
30492 IF E4 = 0 THEN 2360
30493 IF T(E3, 1) > 4 THEN 40344
30494 IF E4 <> I(4) THEN 2360
30496 LET E2 = H(H1, 7)
30498 IF E2 = 0 THEN 1285
30500 IF H(E2, 4) <> 3 THEN 2360
30502 LET E2 = H(E2, 8)
30504 GOTO 30498
30520 REM ---- wbin ty op: ty 3, operands of type 2 or 3 (R7); op 1 add 2 sub 3 mul, 4 and (R13: both 3)
30530 LET H(H1, 4) = I(2)
30532 IF I(2) <> 3 THEN 2360
30534 LET K3$ = "|add    |sub    |mul    |and    "
30536 GOSUB 1872
30540 IF W2 = 0 THEN 2360
30542 LET H(H1, 5) = W2
30544 LET E2 = H(H1, 7)
30546 IF ABS(H(E2, 4) - 2.5) <> .5 THEN 2360
30548 IF ABS(H(H(E2, 8), 4) - 2.5) <> .5 THEN 2360
30549 IF W2 < 4 THEN 1285
30550 IF H(E2, 4) + H(H(E2, 8), 4) <> 6 THEN 2360
30552 GOTO 1285
30890 REM ---- 30900: E4 = the rank of the type E3 when it is an array (tvec tfvec 1, tmat tfmat 2), else 0
30900 LET E4 = 0
30902 IF E3 <= 9 THEN 30910
30904 LET E4 = VAL(SEG$("1020120", T(E3, 1), T(E3, 1)))
30910 RETURN
30915 REM ---- 30920: E5 = 1 if the type E3 is the tptr of the element type E6, else 0 ---------------
30920 LET E5 = 0
30922 IF E3 <= 9 THEN 30930
30924 IF T(E3, 1) <> 4 THEN 30930
30926 IF T(E3, 2) <> E6 THEN 30930
30928 LET E5 = 1
30930 RETURN
30990 REM ==== 31000: the checks of 3.5.9 on the function just read (its nodes H2 .. H0): a tmp local read only after its tmp and never written (bind, tbind, asg, tasg, rarg; nor the local of an hloop or forr); a tptr local only a tmp's; the bind of
30991 REM a .l local only the first statement of an L4 block (a block of 4), which is marked H(bind,6) = 1; an iblk claimed by its inline xblk, an iret by its iblk (H5, 4h)
31000 LET E1 = G(G0, 0)
31002 GOSUB 40400
31020 FOR E2 = H2 TO H0
31022 LET E3 = H(E2, 1)
31024 IF E3 = 5 THEN 31060
31026 IF E3 = 20 THEN 31080
31028 IF E3 = 21 THEN 31100
31030 IF E3 = 23 THEN 31120
31032 IF E3 = 24 THEN 31130
31034 IF E3 = 11 THEN 34100
31036 IF E3 = 45 THEN 31090
31038 IF E3 = 27 THEN 31090
31039 IF ABS(E3 - 65.5) = .5 THEN 31044
31040 NEXT E2
31042 RETURN
31044 IF H(E2, 5) = 0 THEN 2360
31046 GOTO 31040
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
31086 GOSUB 40490
31088 GOTO 31040
31089 REM the local of an hloop or forr is not a tmp local
31090 IF A(E1 + H(E2, 5), 0) <> 0 THEN 2360
31092 GOTO 31040
31098 REM a tbind: none of its locals a tmp local; one of .l locals only first in a block (41791)
31100 FOR E4 = 1 TO H(E2, 6)
31102 LET E5 = M(H(E2, 0) + E4 - 1)
31104 IF E5 = 0 THEN 31108
31106 IF A(E1 + E5, 0) <> 0 THEN 2360
31108 NEXT E4
31109 GOSUB 41791
31110 GOTO 31040
31118 REM an asg or a rarg: the root local of its target (first child)
31120 LET E4 = H(E2, 7)
31122 GOSUB 31150
31123 IF E3 = 23 THEN 40550
31124 GOTO 31040
31128 REM a tasg: the root local of each of its n targets
31130 LET E4 = H(E2, 7)
31132 FOR E6 = 1 TO H(E2, 6)
31134 GOSUB 31150
31136 LET E4 = H(E4, 8)
31138 NEXT E6
31140 GOTO 31040
31145 REM ---- 31150: the root local of the target E4 (its lv, or the base lv of an idx; a skip has none) is not a tmp local
31150 LET O1 = E4
31152 IF H(O1, 1) = 18 THEN 31162
31154 IF H(O1, 1) = 5 THEN 31160
31156 LET O1 = H(O1, 7)
31157 IF O1 = 0 THEN 2365
31158 GOTO 31152
31160 IF A(E1 + H(O1, 5), 0) * (1 - A(E1 + H(O1, 5), 2)) <> 0 THEN 2360
31162 RETURN
31990 REM ==== lowering: the node kinds 43-51 (from 9705) and the resume codes 60-65 (from 9715) ===
32000 ON H(X, 1) - 42 GOTO 32200, 32100, 32400, 32400, 52300, 32400, 32400, 32400, 32400, 2365, 32400, 32400, 32400, 41502, 32400, 41532, 2365, 50200, 50700, 2365, 2365, 2365, 33700, 33800
32010 ON S - 59 GOTO 32240, 32250, 32130, 32420, 32560, 33210, 41028, 41056, 50220, 50730, 51580, 33750, 33812
32090 REM ---- tmp L (T1, T3): no instruction of its own. The child with L's register as its destination (A(.,3), set by T3, else L's own), except: an lv M (not a ref parameter, not a rule-12 copy), an ifx, && or || is lowered with no destination and
32091 REM L names its register
32100 LET E1 = G(F0, 0) + H(X, 5)
32102 LET E2 = H(X, 7)
32103 IF H(E2, 1) = 11 THEN 34200
32104 LET W(W0 + 3) = 0
32106 LET D1 = A(E1, 3)
32108 IF D1 > 0 THEN 32124
32110 LET D1 = 0
32111 GOSUB 41330
32112 LET W(W0 + 3) = 1
32113 IF F5 = 1 THEN 32124
32114 IF H(E2, 1) = 17 THEN 32124
32115 IF H(E2, 1) + SGN(H(E2, 5)) = 44 THEN 32124
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
32134 GOSUB 41640
32135 GOTO 3081
32190 REM ---- xblk: with a destination D and the value lv L of one of its own tmps (T3) or of a scalar .l accumulator bound by a bind inside it (R12 (b), 33520), L's register is D; its statements in order, then its value with the destination D; then
32191 REM the releases of its owned temporaries (T2); x1 = the value's register, x2 = the next child
32200 LET W(W0 + 4) = H(X, 7)
32202 IF D < 1 THEN 32214
32204 GOSUB 33500
32206 IF H(E2, 1) <> 5 THEN 32214
32207 LET E4 = A(G(F0, 0) + H(E2, 5), 0)
32208 IF E4 = 0 THEN 33520
32209 IF E4 < E3 THEN 32214
32210 IF E4 >= X THEN 32214
32211 IF H(E4, 1) * SGN(ABS(H(H(E4, 7), 1) + SGN(H(H(E4, 7), 5)) - 44)) <> 44 THEN 32214
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
32290 REM ---- 32300: release the owned temporaries of the xblk X -- the tmps whose innermost xblk it is and whose child 9890 calls owned -- in the order of their tmp records, except the one its value names (moved out, T2); collected on U from the
32291 REM last tmp back
32300 GOSUB 33500
32302 LET E5 = 0
32304 IF H(E2, 1) <> 5 THEN 32308
32306 LET E5 = H(E2, 5)
32308 LET E6 = U0
32310 LET E4 = X - 1
32312 IF E4 < E3 THEN 32340
32314 IF ABS(H(E4, 1) - 54) <> 11 THEN 32320
32315 REM a nested xblk has its own temporaries: skip its subtree
32316 LET P4 = E4
32317 GOSUB 13480
32318 LET E4 = P4 - 1
32319 GOTO 32312
32320 IF H(E4, 1) <> 44 THEN 32336
32321 IF H(E4, 6) = 1 THEN 32336
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
32390 REM ---- the children of hloop ext adat eld est anew wbin, left to right (rule 1; an lv emits nothing), onto U above x1 = U0; x2 = the next child; an hloop stops before its block
32400 LET W(W0 + 3) = U0
32402 LET W(W0 + 4) = H(X, 7)
32403 IF H(X, 1) = 49 THEN 51500
32404 IF W(W0 + 4) = 0 THEN 32430
32406 IF H(X, 1) <> 45 THEN 32409
32408 IF H(W(W0 + 4), 8) = 0 THEN 32430
32409 IF H(W(W0 + 4), 8) = 0 THEN 41592
32410 LET S = 63
32412 GOTO 7366
32420 GOSUB 7966
32426 LET W(W0 + 4) = H(W(W0 + 4), 8)
32428 GOTO 32404
32430 LET E1 = W(W0 + 3)
32432 ON H(X, 1) - 44 GOTO 32500, 32600, 32700, 32800, 51550, 41302, 33100, 2365, 41400, 41412, 41452, 2365, 41437
32490 REM ---- hloop K: loop B K start last step (B the next block, 3.6.4), its block, endloop B; a loop for break, cont and rule 16 (b) (J: 7985 with x1 = B)
32500 LET E2 = U(E1 + 1, 1)
32502 LET E3 = U(E1 + 2, 1)
32504 LET E4 = U(E1 + 3, 1)
32506 LET U0 = E1
32508 GOSUB 7885
32510 LET W(W0 + 3) = B7
32512 LET L1$ = "loop " & STR$(B7) & FNR$(H(X, 5)) & FNR$(E2) & FNR$(E3) & FNR$(E4)
32538 GOSUB 7695
32540 GOSUB 7985
32542 LET S = 64
32544 GOTO 7366
32560 LET J0 = J0 - 1
32562 LET L1$ = "endloop " & STR$(W(W0 + 3))
32564 GOSUB 7695
32566 GOTO 3081
32590 REM ---- ext dim: ext(A, dim) of rule 17 (ldi E A - 0 16 or 24), of a str ldi E S - 0 16 (SEA_STR_LEN), into the destination; an owned operand released after it (rule 15 (k))
32600 LET E2 = U(E1 + 1, 1)
32602 LET U0 = E1
32604 GOSUB 7468
32607 GOSUB 41270
32608 LET Z3 = H9
32609 IF F5 = 1 THEN 41280
32610 IF H(H(X, 7), 4) = 5 THEN 32614
32612 LET Z3 = G2 + H(X, 5) * (G3 - G2)
32614 LET L1$ = SEG$("ldildfldp", 3 * V(D2, 1) - 2, 3 * V(D2, 1)) & FNR$(D2) & FNR$(E2) & " - 0 " & STR$(Z3)
32616 GOSUB 7695
32620 LET X0 = H(X, 7)
32622 LET R0 = E2
32624 GOSUB 10080
32626 GOTO 3088
32690 REM ---- adat: data(A) of rule 17 (ldp D A - 0 40) into the destination -------------------
32700 LET E2 = U(E1 + 1, 1)
32701 GOSUB 41270
32702 LET U0 = E1
32703 IF F5 = 1 THEN 41296
32704 GOSUB 7466
32708 LET Z3 = G4
32710 LET L1$ = SEG$("ldildfldp", 3 * V(D2, 1) - 2, 3 * V(D2, 1)) & FNR$(D2) & FNR$(E2) & " - 0 " & STR$(Z3)
32712 GOSUB 7695
32716 LET X0 = H(X, 7)
32718 LET R0 = E2
32720 GOSUB 10080
32722 GOTO 3088
32790 REM ---- eld sc off: ldb (bool), ldi (i64), ldf (f64) or ldp (a reference, borrowed) R D X sc off into the destination
32800 LET E2 = U(E1 + 1, 1)
32802 LET E3 = U(E1 + 2, 1)
32804 LET U0 = E1
32805 IF H(X, 4) > 9 THEN 52100
32806 GOSUB 7391
32810 GOSUB 7470
32812 LET O$ = "ldp"
32814 IF H(X, 4) > 4 THEN 32818
32816 LET O$ = SEG$("ldbldildf", 3 * H(X, 4) - 5, 3 * H(X, 4) - 3)
32818 LET V2 = D2
32820 LET V3 = E2
32822 LET V4 = E3
32824 GOSUB 32950
32825 GOSUB 42666
32826 GOTO 3088
32890 REM ---- est sc off: stb, sti, stf or stp (a reference: retained first when borrowed, rule 15 (a)) V D X sc off
32900 LET E2 = U(E1 + 1, 1)
32902 LET E3 = U(E1 + 2, 1)
32904 LET E4 = U(E1 + 3, 1)
32906 LET U0 = E1
32908 LET X0 = H(X, 7)
32910 LET R9 = E2
32911 IF H(X0, 4) > 9 THEN 52000
32912 GOSUB 42000
32914 LET E5 = H(H(X, 7), 4)
32915 LET D4 = 0
32916 LET O$ = "stp"
32918 IF E5 > 4 THEN 42800
32920 LET O$ = SEG$("stbstistf", 3 * E5 - 5, 3 * E5 - 3)
32922 LET V2 = E2
32924 LET V3 = E3
32926 LET V4 = E4
32928 GOSUB 32950
32929 IF D4 > 0 THEN 42850
32930 GOTO 3081
32945 REM ---- 32950: L1$ = O$ V2 V3 V4, then the sc and off of node X; emitted ------------------
32950 LET L1$ = O$ & FNR$(V2) & FNR$(V3)
32952 IF V4 = 0 THEN 41600
32954 LET L1$ = L1$ & FNR$(V4) & " " & STR$(H(X, 5)) & " " & S$(H(X, 0))
32956 GOTO 7695
32990 REM ---- anew z r: arrnew (z 0, sea_arr_new_u) or arrnewz (z 1, sea_arr_new) of rule 17 with the element kind and rank of its type: li K ek, li N rank, for a vector li C 1, then the rcall into the destination (owned)
33000 LET T3 = H(X, 4)
33002 LET T2 = T(T3, 2)
33004 GOSUB 11300
33006 LET Z3 = G6
33008 IF C3 = 1 THEN 33016
33010 LET Z3 = G5
33012 IF C3 = 2 THEN 33016
33014 LET Z3 = G7 + (I1 - G7) * INT(C3 / 4)
33015 IF C3 = 5 THEN 52700
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
33042 IF H(X, 5) + INT(C3 / 4) = 0 THEN 33046
33044 LET Q9 = Y3
33045 IF C3 = 5 THEN 52730
33046 GOSUB 7466
33050 GOSUB 5590
33052 LET L1$ = L1$ & FNR$(D2) & " 4" & FNR$(R1) & FNR$(R2) & FNR$(R3) & FNR$(R4)
33082 GOTO 7662
33090 REM ---- wbin op: iadd, isub, imul (wrapping) or iand (R13) d a b into the destination ----------
33100 LET E2 = U(E1 + 1, 1)
33102 LET E3 = U(E1 + 2, 1)
33104 LET U0 = E1
33106 GOSUB 7468
33110 LET V4 = E3
33112 LET L1$ = SEG$("iaddisubimuliand", 4 * H(X, 5) - 3, 4 * H(X, 5)) & FNR$(D2) & FNR$(E2) & FNR$(V4)
33114 GOSUB 7620
33120 GOTO 3088
33190 REM ---- the bind of an L4 block (rule 30 (1), not rule 2): the vector with no destination; an owned value's register is the hidden local H's (A(.,3)), a borrowed X gets mov H X, retain H; the .t locals of a seq vector wait for the end of the
33191 REM block, right after H (16 (e))
33200 LET S = 65
33202 LET X1 = H(X, 7)
33204 GOTO 7375
33210 LET E1 = G(F0, 0) + H(X, 5)
33212 LET X0 = H(X, 7)
33214 GOSUB 9890
33216 IF Z0 = 0 THEN 33224
33218 LET A(E1, 3) = R9
33220 LET V1 = R9
33222 GOTO 33240
33224 LET L1$ = "mov" & FNR$(H(X, 5)) & FNR$(R9)
33226 GOSUB 7620
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
33290 REM ---- 33300 (of 9890): an xblk P5 is owned exactly when its value is (rule 15 (k), T2): an owned node, or lv L of a tmp of it whose child is owned
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
33390 REM ---- 33400 (of the seq, 15360): J(J9,4) = the frame that consumes the seq of frame W0: its parent, or for a tmp the innermost xblk holding it (T2), else that tmp
33400 LET E2 = W0 - 6
33402 LET J(J9, 4) = E2
33404 IF H(W(E2), 1) <> 44 THEN 33416
33406 LET E2 = E2 - 6
33408 IF E2 < 6 THEN 33416
33409 IF H(W(E2), 1) = 65 THEN 33416
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
33518 REM ---- (from 32208) R12 (b): the value lv L of a scalar .l local that a bind in the subtree of the xblk X (E3 .. X - 1) declares, an accumulator: L's register is the destination D
33520 LET E5 = H(E2, 5)
33522 IF A(G(F0, 0) + E5, 4) - 2 * INT(A(G(F0, 0) + E5, 4) / 2) = 0 THEN 32214
33524 IF A(G(F0, 0) + E5, 1) > 4 THEN 32214
33526 FOR E4 = E3 TO X - 1
33528 IF H(E4, 1) <> 20 THEN 33534
33530 IF H(E4, 5) <> E5 THEN 33534
33532 LET A(G(F0, 0) + E5, 3) = D
33534 NEXT E4
33536 GOTO 32214
33548 REM ---- 33550 (rule 3 for the node X): F3 = 1 if X is an ifx with a destination D that is the value of an xblk (R12 (a)): D is its R even when it is a local's register, with no mov
33550 LET F3 = 0
33552 IF D < 1 THEN 33560
33554 IF H(X, 1) <> 17 THEN 33560
33556 IF H(W(W0 - 6), 1) <> 43 THEN 33560
33558 LET F3 = 1
33560 RETURN
33590 REM ---- lib sort / argsort (R16, rule 24; from 19570, W2 21 or 22, its arguments U(Z6+1 ..)): rcall sea_sort or sea_argsort site 1 R 2 V Dsc into the destination (owned), then the release of an owned vector right after it (rule 15 (b))
33600 LET Q1$ = "SORT"
33602 IF W2 = 21 THEN 33606
33604 LET Q1$ = "ARGSORT"
33606 LET Q9 = FNE(Q1$, " (pi, p)")
33618 IF Y$(Q9, 4) <> "pi" THEN 33622
33620 IF Y$(Q9, 5) = "p" THEN 33626
33622 CALL "dg_bug": P$, "entry " & Q1$ & " (pi, p) is not in the entries table"
33626 GOSUB 7466
33630 GOSUB 5590
33632 LET L1$ = L1$ & FNR$(D2) & " 2"
33638 FOR I = Z6 + 1 TO Z6 + 2
33640 LET L1$ = L1$ & FNR$(U(I, 1))
33646 NEXT I
33648 GOSUB 7695
33650 LET X0 = H(X, 7)
33652 LET R0 = U(Z6 + 1, 1)
33654 GOSUB 10080
33656 GOTO 19575
33690 REM ==== sub-phase 4h (DESIGN 3.5.9 L18, R26-R30 and their validation; 3.6.6 rule 37 and its iblk/iret bullet): kinds 65 iblk (H4 ty, H6 k, H5 its inline xblk) and 66 iret (H6 k, H5 its iblk); an inline xblk has H5 = its iblk. Resume codes 71, 72
33700 REM ---- iblk k (R27): R1 .. Rk on U above x1 (D = -2: a component's own new register is its Ri; R32: an aggregate component a new home), do B (x2 = B), its block above the scope height x3 (resume 71); with a destination (D >= 0) k = 1
33702 IF D < 0 THEN 33706
33704 IF H(X, 6) <> 1 THEN 2360
33706 LET W(W0 + 3) = U0
33708 FOR O6 = 1 TO H(X, 6)
33710 LET T1 = H(X, 4)
33711 IF T1 <= 9 THEN 33714
33712 IF T(T1, 1) <> 2 THEN 33714
33713 LET T1 = M(T(T1, 3) + O6 - 1)
33714 GOSUB 40595
33715 IF F5 = 0 THEN 33719
33716 GOSUB 40622
33717 LET N2 = D2
33718 GOTO 33726
33719 IF D <> -2 THEN 33724
33720 LET N2 = U(W(W0 + 3) - H(X, 6) + O6, 1)
33722 IF N2 > N7 THEN 33726
33724 GOSUB 7395
33725 GOSUB 7420
33726 GOSUB 7970
33728 LET U(U0, 1) = N2
33730 NEXT O6
33731 GOSUB 34300
33732 GOSUB 7885
33734 LET W(W0 + 4) = B7
33736 LET W(W0 + 5) = J9
33738 LET L1$ = "do " & STR$(B7)
33740 GOSUB 7695
33742 LET S = 71
33744 GOTO 7370
33746 REM the block done (for k = 0 with its releases): exit B unless k > 0 or its last statement is an iret (R29), enddo B
33750 IF H(X, 6) > 0 THEN 33764
33751 LET P3 = H(H(X, 7), 7)
33752 IF H(P3, 8) = 0 THEN 33758
33754 LET P3 = H(P3, 8)
33756 GOTO 33752
33758 IF H(P3, 1) = 66 THEN 33764
33760 LET L1$ = "exit " & STR$(W(W0 + 4))
33762 GOSUB 7695
33764 LET L1$ = "enddo " & STR$(W(W0 + 4))
33766 GOSUB 34400
33767 REM R27, the value R1 .. Rk: P3 = the statement's frame (below the inline xblk, past seqs and xblks); a destination D gets mov D R1, except the new register V of rule 15 (d) or of a scalar ref parameter's asg set (W(P3 + 3) = D): V is R1
33768 LET E1 = W(W0 + 3)
33769 LET R9 = U(E1 + 1, 1) * SGN(H(X, 6))
33770 LET P3 = W0 - 6
33771 LET P3 = P3 - 6
33772 IF ABS(H(W(P3), 1) - 31) = 12 THEN 33771
33773 IF D = -2 THEN 33786
33774 IF D < 1 THEN 33797
33775 IF H(W(P3), 1) <> 23 THEN 33779
33776 IF W(P3 + 3) <> D THEN 33779
33777 LET W(P3 + 3) = R9
33778 GOTO 33797
33779 LET L1$ = "mov" & FNR$(D) & FNR$(R9)
33780 GOSUB 7620
33781 LET R9 = D
33782 GOTO 33797
33785 REM D = -2: a component in a local's register (a tbind's local, a tasg's scalar local) gets mov L Ri here under a tbind, from step (d) of rule 2 under a tasg (U(.,2) = -L)
33786 FOR O6 = 1 TO H(X, 6)
33787 LET E2 = E1 - H(X, 6) + O6
33788 IF U(E2, 1) + N7 * V(U(E1 + O6, 1), 0) > N7 THEN 33795
33789 IF H(W(P3), 1) = 24 THEN 33793
33790 LET L1$ = "mov" & FNR$(U(E2, 1)) & FNR$(U(E1 + O6, 1))
33791 GOSUB 7620
33792 GOTO 33796
33793 LET U(E2, 2) = -U(E2, 1)
33794 LET U(E2, 1) = U(E1 + O6, 1)
33795 IF V(U(E1 + O6, 1), 0) = 1 THEN 34600
33796 NEXT O6
33797 LET U0 = E1
33798 GOTO 3090
33800 REM ---- iret k (R29): its values on U above x1, owned (rule 15 (a); resume 72); the releases down to its iblk's scope height (rule 16 (c) inside it, R22); mov Ri Vi; exit B
33802 LET W(W0 + 3) = U0
33804 LET W(W0 + 4) = H(X, 7)
33806 IF W(W0 + 4) = 0 THEN 33820
33808 LET S = 72
33810 GOTO 7366
33812 GOSUB 7966
33814 LET X0 = W(W0 + 4)
33816 GOSUB 10230
33818 LET W(W0 + 4) = H(W(W0 + 4), 8)
33819 GOTO 33806
33820 FOR O6 = W0 - 6 TO 6 STEP -6
33822 IF H(W(O6), 1) = 65 THEN 33826
33824 NEXT O6
33825 GOTO 2365
33826 GOSUB 10450
33828 LET U4 = W(O6 + 5)
33830 GOSUB 10390
33832 FOR E5 = 1 TO H(X, 6)
33833 IF V(U(W(O6 + 3) + E5, 1), 0) = 1 THEN 34500
33834 LET L1$ = "mov" & FNR$(U(W(O6 + 3) + E5, 1)) & FNR$(U(W(W0 + 3) + E5, 1))
33836 GOSUB 7620
33838 NEXT E5
33840 LET L1$ = "exit " & STR$(W(O6 + 4))
33842 LET U0 = W(W0 + 3)
33844 GOTO 7664
33900 REM ---- reading iblk ty k (R26, validation of 4h): a block child; k 0 for ty 1, m for a ttuple of m, else 1; inside no ret or tret, a break or cont only in a loop inside it; each iret no inner iblk claimed claimed (H5), k values of the result types
33902 LET H(H1, 4) = I(2)
33904 LET H(H1, 6) = I(3)
33906 IF H(H(H1, 7), 1) <> 32 THEN 2360
33908 LET E4 = 1
33910 IF I(2) > 1 THEN 33914
33912 LET E4 = 0
33914 IF I(2) <= 9 THEN 33920
33916 IF T(I(2), 1) <> 2 THEN 33920
33918 LET E4 = T(I(2), 2)
33920 IF E4 <> I(3) THEN 2360
33922 LET P4 = H1
33924 GOSUB 13480
33926 LET E2 = P4 - 1
33928 LET E2 = E2 + 1
33930 IF E2 >= H1 THEN 1285
33932 LET E3 = H(E2, 1)
33934 IF ABS(E3 - 30.5) = .5 THEN 2360
33936 IF ABS(E3 - 28.5) = .5 THEN 33962
33938 IF E3 <> 66 THEN 33928
33940 IF H(E2, 5) > 0 THEN 33928
33942 LET H(E2, 5) = H1
33944 IF H(E2, 6) <> I(3) THEN 2360
33946 LET E5 = H(E2, 7)
33948 LET E4 = 0
33950 IF E5 = 0 THEN 33928
33952 LET E4 = E4 + 1
33954 LET E6 = I(2)
33955 IF E6 <= 9 THEN 33958
33956 IF T(E6, 1) <> 2 THEN 33958
33957 LET E6 = M(T(E6, 3) + E4 - 1)
33958 IF H(E5, 4) <> E6 THEN 2360
33959 LET E5 = H(E5, 8)
33960 GOTO 33950
33961 REM a break or cont E2: some hloop, while or forr E6 of the iblk's subtree holds it
33962 LET E6 = E2
33964 LET E6 = E6 + 1
33966 IF E6 >= H1 THEN 2360
33968 IF H(E6, 1) = 45 THEN 33972
33970 IF ABS(H(E6, 1) - 26.5) <> .5 THEN 33964
33972 LET P4 = E6
33973 GOSUB 13480
33974 IF P4 > E2 THEN 33964
33976 GOTO 33928
33977 REM ---- reading iret k (claimed by its innermost iblk, 33942; checked at the function's end, 31044)
33978 LET H(H1, 6) = I(2)
33979 GOTO 1285
33980 REM ---- (30223) an inline xblk H1, its value E2 an iblk: every statement a tmp (E5 counts the others, R26); H5 links the two. Any other xblk of type 1 or of a ttuple is not allowed (30224)
33982 IF E5 > 0 THEN 2360
33984 LET H(H1, 5) = E2
33986 LET H(E2, 5) = H1
33988 GOTO 1285
33990 IF I(2) = 1 THEN 2360
33992 IF I(2) <= 9 THEN 1285
33994 IF T(I(2), 1) = 2 THEN 2360
33996 GOTO 1285
33998 REM ==== sub-phase 6b (DESIGN 2.11.5): rule 39 (print, make_dir here; format at 5274, FMOD at 8502), R31 (ref arguments of an inline call: ref locals, A(.,2) = 1), R32 (aggregate results of an inline call: a new home, V(.,0) = 1)
34000 REM ---- rule 39 (from 19570: W2 26 print, 27 make_dir; operands U(Z6+1 .. U0)), from the entry's record: operands of its Args classes, rcall with the site (S) or -, each result a new register (the last the destination), owned operands released
34001 LET Q1$ = "MAKE_DIR"
34002 IF W2 = 27 THEN 34006
34004 LET Q1$ = "PRINT"
34006 LET Q9 = FNE(Q1$, "")
34008 IF LEN(Y$(Q9, 4)) <> U0 - Z6 THEN 2360
34010 GOSUB 5590
34012 LET D2 = 0
34014 FOR K7 = 1 TO Z4
34016 LET C1 = POS("ifp", SEG$(Y$(Q9, 5), K7, K7))
34018 LET D = D * INT(K7 / Z4)
34020 GOSUB 7470
34022 LET L1$ = L1$ & FNR$(D2)
34024 NEXT K7
34026 LET L1$ = L1$ & " " & STR$(U0 - Z6)
34028 FOR K7 = Z6 + 1 TO U0
34030 IF SEG$("ifp", V(U(K7, 1), 1), V(U(K7, 1), 1)) <> SEG$(Y$(Q9, 4), K7 - Z6, K7 - Z6) THEN 2360
34032 LET L1$ = L1$ & FNR$(U(K7, 1))
34034 NEXT K7
34036 GOSUB 7695
34038 LET X0 = H(X, 7)
34040 FOR K7 = Z6 + 1 TO U0
34042 LET R0 = U(K7, 1)
34044 GOSUB 10080
34046 LET X0 = H(X0, 8)
34048 NEXT K7
34050 GOTO 19575
34098 REM ---- (31034) a rarg E2 whose parent is a tmp (E2 + 1): that tmp's parent (its last sibling + 1) is an inline xblk (H5 its iblk), so a ref local stands only there (2.11.5 validation)
34100 IF H(E2 + 1, 1) <> 44 THEN 31120
34102 LET O1 = E2 + 1
34104 IF H(O1, 8) = 0 THEN 34110
34106 LET O1 = H(O1, 8)
34108 GOTO 34104
34110 IF H(O1 + 1, 1) <> 43 THEN 2360
34112 IF H(O1 + 1, 5) = 0 THEN 2360
34114 GOTO 31120
34198 REM ---- R31 (from 32103): tmp Ai = rarg lowered at its place as a call's argument (4515: a scalar local's slot sa A and store, a reference local's stp, a struct or fixed local's home, a ref parameter's p, a path; deferred: rule 31)
34200 LET W(W0 + 4) = E2
34202 LET X2 = E2
34204 GOTO 4515
34208 REM (4630) the ref local Ai is then the p register R9 holding the address: written as R9 (its output number shared, 3.6.1); a deferred path has none yet (34300)
34210 IF R9 = 0 THEN 32134
34212 LET V(H(X, 5), 2) = V(R9, 2)
34214 GOTO 32134
34298 REM ---- 34300 (iblk X, before do B): the rest of each deferred ref argument of its inline xblk in argument order (rule 31): a local's store into its slot Ai; a path again (loads, checks at the call's line, cows), Ai then its address
34300 LET K7 = H(H(X, 5), 7)
34302 IF H(K7, 1) <> 44 THEN 34330
34304 LET X2 = H(K7, 7)
34306 IF H(X2, 1) <> 11 THEN 34326
34308 IF H(X2, 0) <> 1 THEN 34326
34310 IF H(H(X2, 7), 1) <> 5 THEN 34318
34312 LET V2 = H(H(X2, 7), 5)
34314 LET V3 = H(K7, 5)
34315 LET Z3 = 0
34316 GOSUB 7650
34317 GOTO 34326
34318 GOSUB 53600
34320 LET J7 = 1
34322 LET J8 = 0
34324 GOSUB 53620
34325 LET V(H(K7, 5), 2) = V(R9, 2)
34326 LET K7 = H(K7, 8)
34328 GOTO 34302
34330 RETURN
34398 REM ---- 34400 (iblk X): enddo B (L1$), then the reloads of rule 12 (R31): each slot argument's local (a scalar or reference local, not a ref parameter or ref local, not a home) loaded from its Ai, in argument order; then R27
34400 GOSUB 7695
34402 LET K7 = H(H(X, 5), 7)
34404 IF H(K7, 1) <> 44 THEN 34420
34406 LET X3 = H(K7, 7)
34408 IF H(X3, 1) <> 11 THEN 34418
34410 IF H(H(X3, 7), 1) <> 5 THEN 34418
34412 LET V2 = H(H(X3, 7), 5)
34414 IF A(G(F0, 0) + V2, 2) + V(V2, 0) > 0 THEN 34418
34415 LET V3 = H(K7, 5)
34416 LET Z3 = 0
34417 GOSUB 7640
34418 LET K7 = H(K7, 8)
34419 GOTO 34404
34420 RETURN
34498 REM ---- R32 (from 33833, iret): the owned aggregate value E5 stored into its home Ri (the iblk W(O6)'s component type): li N size, mcopy H V N (moved: owned, rule 15 (a) above)
34500 LET T5 = H(W(O6), 4)
34502 IF T(T5, 1) <> 2 THEN 34506
34504 LET T5 = M(T(T5, 3) + E5 - 1)
34506 LET V2 = U(W(O6 + 3) + E5, 1)
34508 LET V3 = U(W(W0 + 3) + E5, 1)
34510 GOSUB 40670
34512 GOTO 33838
34598 REM ---- R32 (from 33795, D = -2): an aggregate component's home Ri copied (moved) into the home its tbind, tasg, tret or eval provides, in R27's place of the mov
34600 LET T5 = M(T(H(X, 4), 3) + O6 - 1)
34602 LET V2 = U(E2, 1)
34604 LET V3 = U(E1 + O6, 1)
34606 GOSUB 40670
34608 GOTO 33796
34698 REM ---- the rule-12 pre-pass (2586, 2588) and an iblk (6b, R31; L-w): an inlined body's statements are statements of their own, as in the callee. At an iblk N4 met while skipping, its body is visited (E6 = N4), the old E6 and iblk B3 kept in its H0
34699 REM (unused by the iblk); below its body start B4 they come back (34720). 34740: Z0 = 1 if the rarg K5 lies in the body of an iblk inside the statement (its own statement's, not this one's)
34700 IF H(N4, 1) <> 65 THEN 2720
34702 LET H(N4, 0) = E6 + 1E6 * B3
34704 LET B3 = N4
34706 LET E6 = N4
34708 LET P4 = N4
34710 GOSUB 13480
34712 LET B4 = P4
34714 GOTO 2720
34720 LET E6 = H(B3, 0) - 1E6 * INT(H(B3, 0) / 1E6)
34722 LET B3 = INT(H(B3, 0) / 1E6)
34724 LET B4 = 0
34726 IF B3 = 0 THEN 2586
34728 LET P4 = B3
34730 GOSUB 13480
34732 LET B4 = P4
34734 GOTO 2586
34740 LET Z0 = 0
34742 FOR A6 = K5 + 1 TO B5
34744 IF H(A6, 1) <> 65 THEN 34752
34746 LET P4 = A6
34748 GOSUB 13480
34750 IF P4 > K5 THEN 34752
34751 LET Z0 = 1
34752 NEXT A6
34754 RETURN
