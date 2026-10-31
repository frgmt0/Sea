55000 REM ====================================================================================
55002 REM seafuse part 7 (lines 55000-59999): F3, the fused reductions (DESIGN 2.12.4 F3, L-et,
55004 REM the lead's reading D2). Analysis (55010, from fu4fan, before the mask selections outside
55006 REM F3 become plain leaves): a lib sum mean variance std max min argmax argmin nnz any all of
55008 REM one argument that is the root of an element-wise vector tree is fused standalone (role 7,
55009 REM Y(lib,5) the root; the root and its nodes not written); when every array leaf of the tree
55010 REM is a mask selection X[m] of a vector by the same mask local, it is masked (Y(root,3) = 1
55011 REM until the slots are cleared, Y(lib,6) = 1). Generation (55100): xblk P T n { the leaf and
55012 REM check phase (F1 (1)); a masked one's count q by IX 3; L13's statements for the function
55013 REM (3.5.9) with X(K) the element expression F (fu5f1 40800), the data loads where L13 loads
55014 REM V's; masked: the loop runs over the base under if of the mask element and a counter J of
55015 REM the selected elements (D = ci 1) replaces K where L13 uses the position (L-et) }. sum8's
55016 REM home has the type F8 (%1, R14; appended to the type table when sea.hir has none, D2).
55018 FOR X3 = 1 TO H0
55020 IF H(X3, 1) <> 12 THEN 55060
55021 LET R2 = H(X3, 6)
55022 LET Z$ = D$(R2)
55023 LET F9 = 4
55024 GOSUB 8440
55025 IF POS("|sum|mean|variance|std|max|min|argmax|argmin|nnz|any|all|", "|" & F9$ & "|") = 0 THEN 55060
55026 LET X6 = H(X3, 3)
55027 IF X6 = 0 THEN 55060
55028 IF H(X6, 4) <> 0 THEN 55060
55029 IF Y(X6, 0) = 0 THEN 56100
55030 IF Y(X6, 2) <> X6 THEN 55060
55032 IF Y(X6, 1) > 0 THEN 55060
55034 IF H(X6, 2) <= 9 THEN 55060
55036 IF T(H(X6, 2), 1) <> 1 THEN 55060
55037 LET I5 = X6
55038 GOSUB 57250
55039 IF I6 = 1 THEN 55060
55042 LET I5 = X3
55043 GOSUB 30900
55044 IF I6 = 1 THEN 55060
55045 LET I5 = X6
55046 GOSUB 30866
55047 IF I3 > 1180 THEN 55060
55048 LET Y(X3, 1) = 7
55050 LET Y(X3, 5) = X6
55051 LET X6 = H(X3, 3)
55052 GOSUB 55070
55054 LET X3 = Y(X3, 5)
55055 LET X6 = X3
55056 GOSUB 30600
55057 LET Y(X3, 1) = 1
55058 LET X3 = W(X3)
55060 NEXT X3
55062 GOTO 56300
55064 REM ---- 55070: masked when every array leaf of tree X6 (of lib X3) is a mask selection of a
55066 REM vector by an lv of one mask lid (Y(X6,3) = 1, Y(X3,6) = 1; the idx nodes not written)
55070 LET C7 = 0
55071 LET X9 = X6
55072 GOSUB 30660
55073 FOR X8 = X7 TO X9
55074 IF Y(X8, 7) <> X9 THEN 55087
55075 IF Y(X8, 4) < 2 THEN 55087
55076 IF Y(X8, 4) = 7 THEN 55087
55077 IF Y(X8, 4) <> 6 THEN 55099
55078 IF H(H(H(X8, 3), 4), 4) <> 0 THEN 55099
55079 LET C8 = X8
55080 LET X8 = H(H(X8, 3), 4)
55081 IF ABS(H(X8, 1) - 5) + ABS(T(H(X8, 2), 1) - T(H(H(C8, 3), 2), 1)) > 0 THEN 55099
55082 GOSUB 50750
55083 LET X8 = C8
55084 IF C7 = 0 THEN 55086
55085 IF C7 <> C5 THEN 55099
55086 LET C7 = C5
55087 NEXT X8
55088 IF C7 = 0 THEN 55099
55089 LET Y(X9, 3) = 1
55090 LET Y(X3, 6) = 1
55091 FOR X8 = X7 TO X9
55092 IF Y(X8, 7) * 10 + Y(X8, 4) <> X9 * 10 + 6 THEN 55094
55093 LET Y(X8, 1) = 1
55094 NEXT X8
55099 RETURN
55100 REM ---- 55100: the reduction X (role 7): xblk P T n in its place (P the position of its
55101 REM statement; the EMPTY_REDUCE chk at the lib's, Q9$); B1$ its name, C2 the element type of the
55102 REM tree R8, M9 the slot of a masked one's first selection (its mask tmp M, data w, count q);
55103 REM the script G9$ (55900) with the names of slot 0 and the globals; N the count
55104 LET R8 = Y(X, 5)
55105 LET I9 = X
55106 LET X8 = X
55108 GOSUB 40925
55110 LET R2 = C6
55112 GOSUB 8400
55114 LET U$ = P9$
55116 LET R9 = C6
55118 LET R7 = C6
55120 LET S0 = 199
55122 LET Z7 = 0
55124 LET Z8 = 0
55126 GOSUB 41260
55128 GOSUB 9115
55130 GOSUB 40100
55131 GOSUB 56200
55132 LET R2 = H(X, 6)
55134 GOSUB 8400
55136 LET Q9$ = P9$
55138 LET P9$ = U$
55140 GOSUB 40990
55142 LET V(53) = H(X, 2)
55144 LET Z$ = D$(R2)
55146 LET F9 = 4
55148 GOSUB 8440
55150 LET B1$ = F9$
55152 LET Y7 = H(R8, 2)
55154 GOSUB 8700
55156 LET C2 = E5
55158 LET Q9 = 1
55160 LET M9 = 0
55162 LET V(118) = V(7)
55163 GOSUB 56180
55164 IF Y(X, 6) = 0 THEN 55200
55166 REM masked: the count q of the first selection's mask (IX 3), N its alias, i the base's count
55168 LET X6 = R8
55170 GOSUB 30660
55172 FOR X9 = X7 TO R8
55174 IF Y(X9, 7) * 10 + Y(X9, 4) <> R8 * 10 + 6 THEN 55178
55176 IF M9 > 0 THEN 55178
55177 LET M9 = Y(X9, 3)
55178 NEXT X9
55180 LET K8 = M9
55181 IF Y(R8, 0) <> 0 THEN 55186
55182 LET S$ = "C 0,B q,D M,= w,( n K,L q,L q,L w,L K,eld P 2 %2 0,wbin P 3 add,asg P set,)"
55184 GOSUB 9000
55186 LET V(118) = V(100 + 25 * M9 + 9)
55188 LET V(35) = V(100 + 25 * M9 + 8)
55200 LET K8 = 0
55202 GOSUB 55600
55204 LET G9$ = ""
55206 LET B1 = (POS("|sum     |mean    |variance|std     |max     |min     |argmax  |argmin  |nnz     |any     |all     ", "|" & B1$) - 1) / 9 + 1
55208 ON B1 GOTO 55220, 55240, 55260, 55290, 55300, 55300, 55300, 55300, 55340, 55340, 55340
55219 REM sum: f64 sum8, i64 the running sum R
55220 IF C2 = 3 THEN 55226
55222 GOSUB 55500
55224 GOTO 55400
55226 GOSUB 55560
55228 LET G9$ = G9$ & ",L R"
55230 GOTO 55400
55239 REM mean: the sum into S, then S / f64(N)
55240 GOSUB 55580
55242 LET G9$ = G9$ & ",L N,cvt P 4,= F,L S,L F,bin P 4 div"
55244 GOTO 55400
55259 REM variance: NaN for N = 0, 0 for N = 1, else the mean m, sum8 of (y - m)^2 over N - 1
55260 GOSUB 55270
55262 GOTO 55400
55270 LET G9$ = G9$ & "C 0,= z,L N,L z,bin P 2 eq,cf P 4 #7FF8000000000000,{,C 1,= o,L N,L o,bin P 2 eq"
55272 LET G9$ = G9$ & ",cf P 4 #0000000000000000,{,"
55274 GOSUB 55580
55276 LET G9$ = G9$ & ",L N,cvt P 4,= F,L S,L F,bin P 4 div,= m,"
55278 LET E1$ = "~y"
55279 IF C2 = 4 THEN 55281
55280 LET E1$ = "~v,L v,cvt P 4,= y"
55281 LET E1$ = E1$ & ",L y,L m,bin P 4 sub,= d,L d,L d,bin P 4 mul,= Y"
55282 GOSUB 55510
55284 LET G9$ = G9$ & ",= U,L N,L o,wbin P 3 sub,= f,L f,cvt P 4,= g,L U,L g,bin P 4 div,],ifx P 4,],ifx P 4"
55286 RETURN
55289 REM std: the sqrt of variance's xblk
55290 LET G9$ = G9$ & "{,"
55292 GOSUB 55270
55294 LET G9$ = G9$ & ",],= p,L p,lib P 4 sqrt 1"
55296 GOTO 55400
55299 REM max min argmax argmin: EMPTY_REDUCE, then R H X over the elements (B5$ the comparison)
55300 LET B5$ = SEG$("gtltgtlt", 2 * B1 - 9, 2 * B1 - 8)
55302 LET B9$ = STR$(C2)
55304 LET G9$ = G9$ & "C 0,= Z,L N,L Z,bin P 2 eq,= E,cs P 5 " & B1$ & ",= S,L E,L S,chk Q EMPTY_REDUCE 1,"
55306 IF C2 = 3 THEN 55310
55308 LET G9$ = G9$ & "cf P 4 #7FF8000000000000"
55309 GOTO 55312
55310 LET G9$ = G9$ & "C 0"
55312 LET G9$ = G9$ & ",B R,cb P 2 0,B H,C 0,B X,~D," & L1$ & ",~Y,"
55314 IF C2 = 3 THEN 55320
55316 LET G9$ = G9$ & "L Y,lib P 2 isnan 1,= U,L U,un P 2 not,= k,L Y,L R,bin P 2 " & B5$ & ",= V,L H,un P 2 not,= p"
55318 LET G9$ = G9$ & ",L p,L V,bin P 2 bor,= T,L k,L T,bin P 2 band,= C"
55319 GOTO 55322
55320 LET G9$ = G9$ & "L Y,L R,bin P 2 " & B5$ & ",= V,L H,un P 2 not,= p,L p,L V,bin P 2 bor,= C"
55322 LET G9$ = G9$ & ",L R,L C,L Y,L R,lib P " & B9$ & " where 3,asg P set,L X,L C,L " & X1$ & ",L X,lib P 3 where 3,asg P set"
55324 LET G9$ = G9$ & ",L H,L H,L C,bin P 2 bor,asg P set," & L2$ & ",L " & SEG$("RRXX", B1 - 4, B1 - 4)
55326 GOTO 55400
55339 REM nnz any all: R, then R op= the element
55340 LET B5$ = "C 0"
55342 IF B1 = 9 THEN 55346
55344 LET B5$ = "cb P 2 " & STR$(B1 - 10)
55346 LET G9$ = G9$ & B5$ & ",B R,~D," & L1$ & ",~B,L R,L R,L B,"
55348 LET B5$ = "wbin P 3 add"
55350 IF B1 = 9 THEN 55354
55352 LET B5$ = "bin P 2 " & SEG$("borband", 3 * B1 - 29, 4 * B1 - 37)
55354 LET G9$ = G9$ & B5$ & ",asg P set," & L2$ & ",L R"
55399 REM the xblk closed; the lib is not written
55400 LET G9$ = G9$ & ",]"
55402 GOSUB 55900
55404 LET N7 = N7 - 1
55406 GOTO 5190
55495 REM ---- 55500: G9$ = G9$ & sum8 (3.5.9) of the element E1$ (55510; 55500: X(K) itself): tmp Z,
55496 REM ifx (N > Z) (xblk { home H (F8), its address A, the eight -0 stores, the data, Q 7, O 1, L,
55497 REM hloop K { (masked: if the mask element) lane W of the position, bind V, Y, V += Y, store
55498 REM (masked: J += D) }, a0 ... a7, the add tree }) (+0)
55500 LET E1$ = "~Y"
55510 LET G9$ = G9$ & "C 0,= Z,L N,L Z,bin P 2 gt,{,anew P %1 0 0,= H,D H,= A,cf P 4 #8000000000000000,= M"
55512 FOR B4 = 0 TO 7
55514 LET G9$ = G9$ & ",L M,L A,C " & STR$(B4) & ",est P %4 0"
55516 NEXT B4
55517 GOSUB 55540
55518 LET G9$ = G9$ & ",~D," & P1$ & "C 7,= Q," & B7$ & M1$
55520 LET G9$ = G9$ & "L " & X1$ & ",L Q,wbin P 3 and,= W,L A,L W,eld P 4 %4 0,B V," & E1$
55521 LET G9$ = G9$ & ",L V,L V,L Y,bin P 4 add,asg P set,L V,L A,L W,est P %4 0," & M2$ & B6$
55522 FOR B4 = 0 TO 7
55524 LET G9$ = G9$ & ",L A,C " & STR$(B4) & ",eld P 4 %4 0,= " & SEG$("abcejlnq", B4 + 1, B4 + 1)
55526 NEXT B4
55528 LET G9$ = G9$ & ",L a,L b,bin P 4 add,= r,L c,L e,bin P 4 add,= s,L r,L s,bin P 4 add,= t,L j,L l,bin P 4 add,= u"
55530 LET G9$ = G9$ & ",L n,L q,bin P 4 add,= w,L u,L w,bin P 4 add,= x,L t,L x,bin P 4 add,],cf P 4 #0000000000000000,ifx P 4"
55532 RETURN
55539 REM ---- 55540: sum8's nest: hloop K over Z ... L (B7$, closed by >); masked: loop(X; K) with its guard (R-l, D-2)
55540 LET B7$ = "C 1,= O,L " & B2$ & ",L O,wbin P 3 sub,= L,L Z,L L,L O,K K,"
55542 LET B6$ = ">"
55544 IF M9 = 0 THEN 55550
55546 LET B7$ = "( i K,"
55548 LET B6$ = ")"
55550 RETURN
55555 REM ---- 55560: G9$ = G9$ & the i64 running sum: bind R = 0, the data, loop { R = R + X(K) }
55560 LET G9$ = G9$ & "C 0,B R,~D," & L1$ & ",~Y,L R,L R,L Y,bin P 3 add,asg P set," & L2$
55562 RETURN
55575 REM ---- 55580: G9$ = G9$ & the sum into S (f64: sum8; i64: the running sum, S = f64(R))
55580 IF C2 = 3 THEN 55586
55582 GOSUB 55500
55584 LET G9$ = G9$ & ",= S"
55585 RETURN
55586 GOSUB 55560
55588 LET G9$ = G9$ & ",L R,cvt P 4,= S"
55590 RETURN
55595 REM ---- 55600: the loop's form (L1$ L2$; sum8's B2$ P1$ M1$ M2$; X1$ the position K or J) and
55596 REM the type F8 (%1) of an f64 sum8 (sum mean variance std of f64; variance std of i64, whose deviations are f64): sea.hir's tfvec f64 8, else appended (G5 = 1, D2, D-1: the
55597 REM row 20008, past every real id, a pseudo element whose tptr fu2out numbers at its first
55598 REM reference with the tptrs, %1 written ^20008, 9234)
55600 LET L1$ = "( N K"
55602 LET L2$ = ")"
55604 LET X1$ = "K"
55606 LET P1$ = ""
55608 LET M1$ = ""
55610 LET M2$ = ""
55612 LET B2$ = "N"
55614 IF M9 = 0 THEN 55632
55616 LET L1$ = "C 0,B J,C 1,= D,( i K,~M"
55618 LET L2$ = "~E,)"
55620 LET X1$ = "J"
55622 LET P1$ = "C 0,B J,C 1,= D,"
55624 LET M1$ = "~M,"
55626 LET M2$ = "~E,"
55628 LET B2$ = "i"
55632 IF C2 = 4 THEN 55634
55633 IF POS("|variance|std|", "|" & B1$ & "|") = 0 THEN 55672
55634 IF POS("|sum|mean|variance|std|", "|" & B1$ & "|") = 0 THEN 55672
55636 IF G6 > 0 THEN 55670
55638 FOR B4 = 10 TO Y9
55639 IF T(B4, 0) <> 8 THEN 55644
55640 IF T(B4, 1) <> 1 THEN 55644
55641 IF T(B4, 2) <> 4 THEN 55644
55642 IF T(B4, 3) <> 1 THEN 55644
55643 LET G6 = B4
55644 NEXT B4
55646 IF G6 > 0 THEN 55670
55648 LET T7 = T7 + 1
55650 LET Q2$ = "types"
55652 IF T7 <= T9 - 9 THEN 55656
55653 GOSUB 8088
55656 LET G6 = 20008
55658 LET G5 = 1
55660 LET T(G6, 0) = 8
55662 LET T(G6, 1) = 1
55664 LET T(G6, 2) = 4
55666 LET T(G6, 3) = 1
55668 LET C(G6, 6) = 1
55670 LET V(54) = G6 * (1 - 2 * G5)
55672 RETURN
55895 REM ---- 55900: the script G9$ run in parts: each ~c a step (D the data loads, a masked one's
55896 REM mask data again with its first selection, 41350; M if (the mask element); E J += D and the if closed; else F into tmp c)
55900 LET T2 = POS(G9$, "~")
55902 IF T2 = 0 THEN 55930
55904 LET S$ = SEG$(G9$, 1, T2 - 1)
55906 LET T1$ = SEG$(G9$, T2 + 1, T2 + 1)
55908 LET G9$ = SEG$(G9$, T2 + 3, LEN(G9$))
55910 IF LEN(S$) < 2 THEN 55914
55911 IF SEG$(S$, LEN(S$), LEN(S$)) <> "," THEN 55913
55912 LET S$ = SEG$(S$, 1, LEN(S$) - 1)
55913 GOSUB 9000
55914 LET K8 = 0
55915 GOSUB 55940
55916 LET K8 = 0
55917 GOTO 55900
55930 LET S$ = G9$
55932 GOTO 9000
55940 IF T1$ = "D" THEN 55956
55941 IF T1$ = "M" THEN 55964
55942 IF T1$ = "E" THEN 55970
55944 GOSUB 40800
55946 LET L8 = C2
55948 LET K8 = 0
55950 LET S$ = "= " & T1$
55952 GOTO 9000
55956 GOTO 40640
55964 LET K8 = M9
55966 LET S$ = "L w,L K,eld P 2 %2 0,?"
55968 GOTO 9000
55970 LET K8 = 0
55972 LET S$ = "L J,L J,L D,wbin P 3 add,asg P set,)"
55974 GOTO 9000
55976 RETURN
55995 REM ---- 56000: the leaf phase of a mask selection X[m] (fu5f1 40200, slot K8): tmp a = X, tmp
55996 REM M = m after their subtrees, at the idx's position IX 1's shape check of m against X
56000 LET X4 = H(D1, 3)
56002 LET S$ = "= a"
56004 GOSUB 8900
56005 LET B6$ = "X a 0,= n,"
56006 LET X4 = H(H(D1, 3), 4)
56008 LET S$ = "= M"
56010 GOSUB 8900
56012 LET R2 = H(D1, 6)
56014 GOSUB 8400
56016 LET Q9$ = P9$
56018 LET P9$ = U$
56019 IF T(H(H(D1, 3), 2), 1) = 2 THEN 56036
56020 LET S$ = B6$ & "X M 0,= N,L n,L N,bin P 2 ne,= S,"
56022 IF Z8 = 1 THEN 56026
56024 LET S$ = S$ & "ci P 3 %6,= Z,"
56026 LET S$ = S$ & "L S,L n,L Z,L N,L Z,chk Q SHAPE_MISMATCH 4"
56028 LET Z8 = 1
56030 GOSUB 9000
56032 GOTO 40296
56034 REM a whole-matrix mask (MM): IX 2 of 3.5.9, X0 X1 (r c), RM CM (I W), S0 S1, S, mchk, NN (n)
56036 IF B6$ = "" THEN 56040
56038 LET B6$ = "X a 0,= r,X a 1,= c,"
56040 LET S$ = B6$ & "X M 0,= I,X M 1,= W,L r,L I,bin P 2 ne,= s,L c,L W,bin P 2 ne,= t,L s,L t,bin P 2 bor,= S,L S,L r,L c,L I,L W,chk Q SHAPE_MISMATCH 4,L r,L c,wbin P 3 mul,= n"
56042 GOTO 56030
56048 REM ---- 56050: a kind-8 leaf (a mask selection of a group statement's local, F2 (3)): no base tmp, its extents
56049 REM those of the statement's root (as a kind-5 leaf, 40214), the mask and its checks as 56000
56050 LET C5 = 100 + 25 * V(3000 + 20 * Y(D1, 5) + 11)
56052 LET V(Q0 + 8) = V(C5 + 8)
56054 LET V(Q0 + 10) = V(C5 + 10)
56056 LET V(Q0 + 3) = V(C5 + 3)
56058 LET B6$ = ""
56060 GOTO 56006
56065 REM ---- 56070: (40380) a mask selection's kept extent where its node loads its operands' extents
56066 REM (IX 3, R-c): its count q over the base positions n; 56080: the first operand's shape G (a
56067 REM mask selection's q); 56084: N1$ the name of an operand's extent in a node's check (n, or q)
56070 LET S$ = "C 0,B q,D M,= w,( n K,L q,L q,L w,L K,eld P 2 %2 0,wbin P 3 add,asg P set,)"
56072 GOTO 9000
56080 LET V(7) = V(Q0 + 8)
56081 IF ABS(Y(X8, 4) - 7) <> 1 THEN 56083
56082 LET V(7) = V(Q0 + 9)
56083 RETURN
56084 LET N1$ = "n"
56085 IF ABS(Y(X8, 4) - 7) <> 1 THEN 56087
56086 LET N1$ = "q"
56087 RETURN
56095 REM ---- 56100: a lib of a mask selection X[m] (a vector X, an lv of a bool vector m): the
56096 REM selection is the tree, its own only leaf (kind 6, F4)
56100 IF H(X6, 1) <> 39 THEN 56140
56102 IF Y(X6, 1) > 0 THEN 55060
56104 LET X8 = H(X6, 3)
56106 IF H(X8, 2) <= 9 THEN 55060
56108 IF T(H(X8, 2), 1) = 0 THEN 55060
56110 LET X9 = H(X8, 4)
56112 IF X9 = 0 THEN 55060
56114 IF H(X9, 4) <> 0 THEN 55060
56116 IF H(X9, 1) <> 5 THEN 55060
56118 IF H(X9, 2) <= 9 THEN 55060
56120 IF T(H(X9, 2), 1) * 10 + T(H(X9, 2), 2) <> T(H(X8, 2), 1) * 10 + 2 THEN 55060
56122 LET Y(X6, 4) = 6
56124 LET Y(X6, 7) = X6
56126 GOTO 57170
56139 REM ---- 56140: a lib of a .flat of a matrix tree (R-k) with one array leaf, a whole one, read at the linear
56140 IF H(X6, 1) <> 45 THEN 55060
56141 REM position K: role 7, the view not written (implementer reading: two array leaves, which may broadcast, are left to sealoop)
56142 LET R2 = H(X6, 6)
56143 LET F9 = 4
56144 GOSUB 8440
56145 IF F9$ <> "flat" THEN 55060
56146 LET X9 = H(X6, 3)
56147 IF Y(X9, 0) = 0 THEN 55060
56148 IF Y(X9, 2) <> X9 THEN 55060
56149 IF Y(X9, 1) > 0 THEN 55060
56150 IF T(H(X9, 2), 1) <> 2 THEN 55060
56151 LET C7 = 0
56152 LET X6 = X9
56153 GOSUB 30660
56154 FOR X8 = X7 TO X9
56155 IF Y(X8, 7) <> X9 THEN 56162
56156 IF ABS(Y(X8, 4) - 4) = 3 THEN 56162
56157 IF Y(X8, 4) = 2 THEN 56160
56158 LET C7 = 99
56159 GOTO 56162
56160 LET C7 = C7 + 1
56162 NEXT X8
56164 IF C7 = 1 THEN 57160
56165 GOTO 55060
56166 LET Y(X3, 1) = 7
56168 LET Y(X3, 5) = X9
56170 LET Y(H(X3, 3), 1) = 1
56172 LET C8 = X3
56173 LET X3 = X9
56174 GOSUB 30600
56176 LET Y(X9, 1) = 1
56177 LET X3 = C8
56178 GOTO 55060
56179 REM ---- 56180: (55163) the count N of a .flat F3 over a matrix tree: R * C after the leaf and check phase (R-k)
56180 IF R4 <> 2 THEN 56188
56182 LET K8 = 0
56184 LET S$ = "L R,L C,wbin P 3 mul,= N"
56186 GOSUB 9000
56188 RETURN
56195 REM ---- 56200: a fixed root's extents (fu6grp 51800; H8 = 0: no unit statement, never a selection store's R-n)
56200 LET K8 = Y(R8, 3)
56201 LET H8 = 0
56202 GOSUB 51800
56204 LET K8 = 0
56206 RETURN
56295 REM ---- 56300: F4's concatenation parts (L-eu): a vector arr (bool i64 f64) of one row with a part: a
56296 REM range selection of a vector (idx, one rng) is rewritten as L9 (c) (role 8), each such part
56297 REM read from its base by its index map (a folded leaf, kind 4: its idx, rng and dols not written)
56300 FOR X3 = 1 TO H0
56302 IF H(X3, 1) <> 47 THEN 56340
56304 IF H(X3, 2) <= 9 THEN 56340
56306 IF T(H(X3, 2), 1) <> 1 THEN 57004
56307 IF ABS(T(H(X3, 2), 2) - 3) > 1 THEN 56340
56308 LET X5 = H(X3, 3)
56310 IF H(X5, 1) <> 48 THEN 56340
56312 IF H(X5, 4) <> 0 THEN 56340
56313 GOSUB 57140
56314 IF C3 = 1 THEN 56340
56316 LET X8 = H(X5, 3)
56318 IF X8 = 0 THEN 56332
56320 GOSUB 57030
56322 IF C4 = 0 THEN 56330
56324 GOSUB 57060
56330 LET X8 = H(X8, 4)
56331 GOTO 56318
56332 IF C7 = 0 THEN 56340
56334 LET Y(X3, 1) = 8
56336 GOSUB 57065
56340 NEXT X3
56342 RETURN
56395 REM ---- 56400: the concatenation X (role 8), L9 (c) at its position (U$; its record the locals'
56396 REM loc pos): each part's tmp a (a folded one: its base B, IX 1, IX 2), their lengths n (IX 3,
56397 REM 1, ext) summed into A, U = anew, D its data, J the offset; each part stored at D[J ...]
56400 LET R2 = H(X, 6)
56401 LET I9 = X
56402 GOSUB 8400
56404 LET U$ = P9$
56406 LET R9 = R2
56408 LET R7 = R2
56409 LET G3 = 1
56410 LET S0 = 199
56412 LET Z7 = 0
56414 LET Z8 = 0
56416 LET Q9 = 1
56418 LET Y7 = H(X, 2)
56420 GOSUB 8700
56422 GOSUB 8730
56424 LET V(58) = V5
56426 LET V(53) = H(X, 2)
56428 GOSUB 9115
56430 LET X5 = H(X, 3)
56432 LET D1 = H(X5, 3)
56434 IF D1 = 0 THEN 57054
56436 IF Y(D1, 1) = 1 THEN 56445
56438 LET D3 = D1
56440 GOSUB 40900
56441 LET X4 = D1
56442 LET S$ = "= a"
56443 GOSUB 8900
56444 GOTO 56446
56445 GOSUB 40200
56446 LET D1 = H(D1, 4)
56447 GOTO 56434
56448 IF T(H(X, 2), 1) = 2 THEN 57070
56449 REM the lengths, summed into A (the first one's alias)
56450 LET D1 = H(X5, 3)
56452 LET D9 = 0
56454 IF D1 = 0 THEN 56476
56456 LET K8 = Y(D1, 3)
56458 LET Q0 = 100 + 25 * K8
56460 IF Y(D1, 1) <> 1 THEN 56463
56461 GOSUB 40380
56462 GOTO 56468
56463 LET S$ = "C 1,= n"
56464 IF H(D1, 2) <= 9 THEN 56466
56465 LET S$ = "X a 0,= n"
56466 GOSUB 9000
56468 IF D9 > 0 THEN 56471
56469 LET V(1) = V(100 + 25 * Y(D1, 3) + 8)
56470 GOTO 56474
56471 LET K8 = Y(D1, 3)
56472 LET S$ = "L A,L n,wbin P 3 add,= A"
56473 GOSUB 9000
56474 LET D9 = D9 + 1
56475 LET D1 = H(D1, 4)
56476 IF D1 > 0 THEN 56456
56477 REM the result U, its data D, the offset J; each part's copy (J += the previous length K)
56478 LET K8 = 0
56480 LET S$ = "L A,anew P %0 0 1,= U,D U,= D,C 0,= J"
56482 IF T(H(X, 2), 3) = 0 THEN 56486
56484 LET S$ = "anew P %0 0 0,= U,D U,= D,C 0,= J"
56486 GOSUB 9000
56488 LET D1 = H(X5, 3)
56490 LET D6 = 0
56492 IF D1 = 0 THEN 56530
56494 IF D6 = 0 THEN 56500
56496 LET S$ = "L J,L K,wbin P 3 add,= J"
56498 GOSUB 9000
56500 LET K8 = Y(D1, 3)
56502 LET Q0 = 100 + 25 * K8
56504 IF H(D1, 2) <= 9 THEN 56522
56506 IF Y(D1, 1) = 1 THEN 56514
56508 LET S$ = "D a,= x,( n K,L x,L K,eld P %e %u 0,L D,L J,L K,wbin P 3 add,est P %5 0,)"
56510 GOSUB 9000
56512 GOTO 56524
56514 LET S$ = "D a,= x,( n K"
56515 GOSUB 9000
56516 LET D2 = D1
56517 GOSUB 40820
56518 LET K8 = 0
56519 LET S$ = "L D,L J,L K,wbin P 3 add,est P %5 0,)"
56520 GOSUB 9000
56521 GOTO 56524
56522 LET S$ = "L a,L D,L J,est P %5 0"
56523 GOSUB 9000
56524 LET V(11) = V(100 + 25 * Y(D1, 3) + 8)
56526 LET D6 = 1
56527 LET D1 = H(D1, 4)
56528 GOTO 56492
56530 LET K8 = 0
56532 LET S$ = "L U,]"
56534 GOSUB 9000
56535 LET G3 = 0
56536 LET N7 = N7 - 1
56538 GOTO 5190
56595 REM ---- 56600: F3 in an F2 group (the lead's reading D1): the reduction statement H8 (kind 2)
56596 REM after its leaf and check phase: a masked one's count q (IX 3, its first selection's slot M9,
56597 REM whose extents and mask extent the space test compares, 52460; counted at its node when the
56598 REM root is a node, 56070), N the count, the EMPTY_REDUCE check of max min argmax argmin at the
56599 REM lib's position; its globals kept (56780)
56600 IF V(3000 + 20 * H8 + 2) <> 2 THEN 56638
56602 LET B3 = H8
56603 GOSUB 56640
56604 LET V(118) = V(100 + 25 * Y(R8, 3) + 8)
56605 LET P9$ = U$
56606 IF M9 = 0 THEN 56616
56608 LET V(3000 + 20 * H8 + 11) = M9
56610 LET K8 = M9
56611 IF Y(R8, 0) <> 0 THEN 56614
56612 LET S$ = "C 0,B q,D M,= w,( n K,L q,L q,L w,L K,eld P 2 %2 0,wbin P 3 add,asg P set,)"
56613 GOSUB 9000
56614 LET V(118) = V(100 + 25 * M9 + 9)
56616 LET K8 = 0
56618 IF ABS(B1 - 6.5) > 1.5 THEN 56634
56620 LET R2 = H(V(3000 + 20 * H8 + 13), 6)
56622 GOSUB 8400
56624 LET Q9$ = P9$
56626 LET P9$ = U$
56628 LET S$ = "C 0,= z,L N,L z,bin P 2 eq,= E,cs P 5 " & B1$ & ",= S,L E,L S,chk Q EMPTY_REDUCE 1"
56630 GOSUB 9000
56634 GOSUB 56780
56636 LET K8 = V(3000 + 20 * H8 + 11)
56638 RETURN
56639 REM ---- 56640: of the reduction statement B3: R8 its tree's root, B1$ B1 the function, C2 the element type, M9 a masked one's slot, F8's type (55600)
56640 LET R8 = V(3000 + 20 * B3 + 3)
56642 LET R2 = H(V(3000 + 20 * B3 + 13), 6)
56644 LET F9 = 4
56646 GOSUB 8440
56648 LET B1$ = F9$
56650 LET B1 = (POS("|sum     |mean    |variance|std     |max     |min     |argmax  |argmin  |nnz     |any     |all     ", "|" & B1$) - 1) / 9 + 1
56652 LET C2 = T(H(R8, 2), 2)
56654 LET M9 = 0
56656 IF V(3000 + 20 * B3 + 15) = 0 THEN 56660
56658 LET M9 = Y(V(3000 + 20 * B3 + 15), 3)
56660 GOTO 55600
56661 REM ---- 56662: before the group's block, each reduction's accumulators (F3: bound before the nest; masked: the counter J and D = 1)
56662 FOR B3 = 1 TO H9
56663 IF V(3000 + 20 * B3 + 2) <> 2 THEN 56699
56664 GOSUB 56640
56665 GOSUB 56790
56666 LET P9$ = U$
56667 LET K8 = 0
56668 LET S$ = ""
56669 LET B7$ = SEG$(",C 0,B J,C 1,= D", 1, 16 * SGN(M9))
56671 ON B1 GOTO 56672, 56672, 56699, 56699, 56680, 56680, 56680, 56680, 56686, 56690, 56690
56672 IF C2 = 3 THEN 56686
56674 LET S$ = S$ & "anew P %1 0 0,= H,D H,= A,cf P 4 #8000000000000000,= M"
56675 FOR B4 = 0 TO 7
56676 LET S$ = S$ & ",L M,L A,C " & STR$(B4) & ",est P %4 0"
56677 NEXT B4
56678 LET S$ = S$ & B7$ & ",C 7,= Q"
56679 GOTO 56696
56680 IF C2 = 3 THEN 56684
56681 LET S$ = S$ & "cf P 4 #7FF8000000000000,B R,cb P 2 0,B H,C 0,B X"
56682 GOTO 56694
56684 LET S$ = S$ & "C 0,B R,cb P 2 0,B H,C 0,B X"
56685 GOTO 56694
56686 LET S$ = S$ & "C 0,B R"
56688 GOTO 56694
56690 LET S$ = S$ & "cb P 2 " & STR$(B1 - 10) & ",B R"
56694 LET S$ = S$ & B7$
56696 GOSUB 9000
56698 GOSUB 56780
56699 NEXT B3
56700 RETURN
56719 REM ---- 56720: (the tail of 41200) each reduction's step in the copy's body, after the stores: the
56720 REM space's globals C G K L R kept; the fused copy reads a kind-5 or kind-8 leaf as the bound Ei
56721 REM (41240); masked: if (the mask element at the position) { the step at J, J += D }, else
56722 REM Y = F and the step at K (the fused copy's Y the bound element b, 41212); L13's step with its accumulators (56790)
56723 FOR B3 = E8 TO E9
56724 IF V(3000 + 20 * B3 + 2) <> 2 THEN 56760
56725 GOSUB 56640
56726 FOR B4 = 0 TO 4
56727 LET V(4290 + B4) = V(VAL(SEG$("003007011012018", 3 * B4 + 1, 3 * B4 + 3)))
56728 NEXT B4
56736 LET X1$ = "K"
56737 LET P9$ = U$
56738 IF M9 = 0 THEN 56745
56739 LET X1$ = "J"
56740 LET K8 = M9
56741 LET S$ = "L w,L K,eld P 2 %2 0,?"
56742 IF Q9 < 3 THEN 56744
56743 LET S$ = "L w,L K,L L,L R,wbin P 3 mul,wbin P 3 add,eld P 2 %2 0,?"
56744 GOSUB 9000
56745 LET K8 = 0
56746 LET V(121) = V(100 + 25 * Y(R8, 3) + 2)
56747 IF Q8 = 1 THEN 56750
56748 IF (B1 * 10 + C2 - 14) * (B1 * 10 + C2 - 24) = 0 THEN 56750
56749 GOSUB 56764
56750 GOSUB 56790
56751 GOSUB 56800
56752 GOSUB 9000
56753 LET S$ = "L J,L J,L D,wbin P 3 add,asg P set,)"
56754 IF M9 > 0 THEN 56756
56755 GOTO 56757
56756 GOSUB 9000
56757 FOR B4 = 0 TO 4
56758 LET V(VAL(SEG$("003007011012018", 3 * B4 + 1, 3 * B4 + 3))) = V(4290 + B4)
56759 NEXT B4
56760 NEXT B3
56761 LET K8 = 0
56762 RETURN
56763 REM ---- 56764: the split copy computes the element Y = F at L13's place (sum8: after its lane load)
56764 GOSUB 40800
56765 LET L8 = C2
56766 LET K8 = 0
56767 LET S$ = "= Y"
56768 GOTO 9000
56779 REM ---- 56780: the globals of the reduction statement B3 kept (A D H J Q R, slot 0's N X); 56790: put back
56780 FOR B4 = 0 TO 7
56782 LET V(4300 + 12 * B3 + B4) = V(VAL(SEG$("001004008010017018118120", 3 * B4 + 1, 3 * B4 + 3)))
56784 NEXT B4
56786 RETURN
56790 FOR B4 = 0 TO 7
56792 LET V(VAL(SEG$("001004008010017018118120", 3 * B4 + 1, 3 * B4 + 3))) = V(4300 + 12 * B3 + B4)
56794 NEXT B4
56796 RETURN
56799 REM ---- 56800: S$ = the step of reduction B1 (L13 3.5.9) for the element Y at the position X1$
56800 ON B1 GOTO 56802, 56802, 56838, 56838, 56810, 56810, 56810, 56810, 56830, 56832, 56834
56802 LET S$ = "L R,L R,L Y,bin P 3 add,asg P set"
56804 IF C2 = 3 THEN 56838
56806 GOTO 56880
56810 LET B5$ = SEG$("gtltgtlt", 2 * B1 - 9, 2 * B1 - 8)
56812 LET S$ = "L Y,L R,bin P 2 " & B5$ & ",= V,L H,un P 2 not,= p,L p,L V,bin P 2 bor,= C"
56814 IF C2 = 3 THEN 56818
56816 LET S$ = "L Y,lib P 2 isnan 1,= U,L U,un P 2 not,= k,L Y,L R,bin P 2 " & B5$ & ",= V,L H,un P 2 not,= p,L p,L V,bin P 2 bor,= T,L k,L T,bin P 2 band,= C"
56818 LET S$ = S$ & ",L R,L C,L Y,L R,lib P " & STR$(C2) & " where 3,asg P set,L X,L C,L " & X1$ & ",L X,lib P 3 where 3,asg P set"
56820 LET S$ = S$ & ",L H,L H,L C,bin P 2 bor,asg P set"
56822 RETURN
56830 LET S$ = "L R,L R,L Y,wbin P 3 add,asg P set"
56831 RETURN
56832 LET S$ = "L R,L R,L Y,bin P 2 bor,asg P set"
56833 RETURN
56834 LET S$ = "L R,L R,L Y,bin P 2 band,asg P set"
56838 RETURN
56839 REM ---- 56840: after the group's block, each reduction's final value bound to its local at its statement's position (F2 (d), D1)
56840 FOR B3 = 1 TO H9
56841 IF V(3000 + 20 * B3 + 2) <> 2 THEN 56869
56842 GOSUB 56640
56843 GOSUB 56790
56844 LET P9$ = U$
56845 LET K8 = 0
56846 LET S$ = "L R"
56847 ON B1 GOTO 56850, 56850, 56869, 56869, 56864, 56864, 56863, 56863, 56864, 56864, 56864
56850 IF C2 = 3 THEN 56858
56851 LET S$ = "C 0,= z,L N,L z,bin P 2 gt,{"
56852 FOR B4 = 0 TO 7
56853 LET S$ = S$ & ",L A,C " & STR$(B4) & ",eld P 4 %4 0,= " & SEG$("abcejlnq", B4 + 1, B4 + 1)
56854 NEXT B4
56855 LET S$ = S$ & ",L a,L b,bin P 4 add,= r,L c,L e,bin P 4 add,= s,L r,L s,bin P 4 add,= t,L j,L l,bin P 4 add,= u"
56856 LET S$ = S$ & ",L n,L q,bin P 4 add,= w,L u,L w,bin P 4 add,= x,L t,L x,bin P 4 add,],cf P 4 #0000000000000000,ifx P 4"
56857 GOTO 56860
56858 IF B1 = 1 THEN 56864
56859 LET S$ = "L R,cvt P 4"
56860 IF B1 = 1 THEN 56864
56861 LET S$ = S$ & ",= S,L N,cvt P 4,= F,L S,L F,bin P 4 div"
56862 GOTO 56864
56863 LET S$ = "L X"
56864 GOSUB 9000
56865 LET R2 = V(3000 + 20 * B3 + 6)
56866 GOSUB 8400
56867 LET Z$ = "bind " & P9$ & " " & STR$(V(3000 + 20 * B3 + 5))
56868 GOSUB 8050
56869 NEXT B3
56870 RETURN
56879 REM ---- 56880: sum8's step: lane W of the position, V = its home lane, V += Y, the store (the split copy computes Y after V, 56764)
56880 LET S$ = "L " & X1$ & ",L Q,wbin P 3 and,= W,L A,L W,eld P 4 %4 0,B V"
56881 LET B6$ = "L V,L V,L Y,bin P 4 add,asg P set,L V,L A,L W,est P %4 0"
56882 IF Q8 = 1 THEN 56888
56883 GOSUB 9000
56884 GOSUB 56764
56885 LET S$ = B6$
56886 RETURN
56888 LET S$ = S$ & "," & B6$
56889 RETURN
57000 REM ---- 57004: (56306) F4's concatenation parts of a matrix arr (bool i64 f64) of one or more rows,
57001 REM each a row of matrices and scalars or of scalars and vectors (L-eu): one folded part (57030: a view
57002 REM .T .flat of a matrix, .col .row of a vector; a selection of an array by rng and all indices) makes
57003 REM it L9 (c) (role 8, every row not written), each read from its base by its map (kind 3 or 4, 30640)
57004 IF T(H(X3, 2), 1) <> 2 THEN 56340
57005 IF ABS(T(H(X3, 2), 2) - 3) > 1 THEN 56340
57006 LET X5 = H(X3, 3)
57007 IF H(X5, 1) <> 48 THEN 56340
57008 GOSUB 57140
57009 IF C3 = 1 THEN 56340
57010 IF X8 = 0 THEN 57016
57011 GOSUB 57030
57012 IF C4 = 0 THEN 57014
57013 GOSUB 57060
57014 LET X8 = H(X8, 4)
57015 GOTO 57010
57016 LET X5 = H(X5, 4)
57017 IF X5 = 0 THEN 57021
57018 IF H(X5, 1) <> 48 THEN 57021
57019 LET X8 = H(X5, 3)
57020 GOTO 57010
57021 LET X5 = H(X3, 3)
57022 GOTO 56332
57028 LET C4 = 4
57029 RETURN
57030 REM ---- 57031: C4 = the folded kind of the part X8: 3 a view (C6 its code) of no view (.T .flat of a matrix, .col .row of a vector), 4 an idx of an array (no view) by rng and all only, else 0
57031 LET C4 = 0
57032 LET C6 = 0
57033 LET X9 = H(X8, 3)
57034 IF H(X8, 1) = 45 THEN 57043
57035 IF H(X8, 1) <> 39 THEN 57042
57036 IF H(X9, 1) = 45 THEN 57042
57037 IF H(X9, 2) <= 9 THEN 57042
57038 IF T(H(X9, 2), 1) = 0 THEN 57042
57039 LET X9 = H(X9, 4)
57040 IF X9 = 0 THEN 57028
57041 IF ABS(H(X9, 1) - 31) = 15 THEN 57039
57042 RETURN
57043 IF H(X9, 1) = 45 THEN 57042
57044 IF H(X9, 2) <= 9 THEN 57042
57045 LET R2 = H(X8, 6)
57046 LET F9 = 4
57047 GOSUB 8440
57048 LET C6 = (POS("|T   |flat|col |row ", "|" & F9$) - 1) / 5 + 1
57049 IF T(H(X9, 2), 1) <> 2 - INT(C6 / 3) THEN 57042
57050 LET C4 = 3
57051 RETURN
57052 REM ---- 57053: (56434) the leaf phase goes on with the parts of the next row of the concatenation X;
57053 REM after the last one X5 = its first row
57054 LET X5 = H(X5, 4)
57055 IF X5 = 0 THEN 57058
57056 LET D1 = H(X5, 3)
57057 GOTO 56434
57058 LET X5 = H(X, 3)
57059 GOTO 56448
57060 REM ---- 57060: (56327, 57013) the part X8 folded, of kind C4 (C6 a view's code; 30640); 57065: (56336) every row from X5 not written
57061 LET Y(X8, 4) = C4
57062 LET Y(X8, 5) = C6
57063 LET C7 = 1
57064 GOTO 30640
57065 LET Y(X5, 1) = 1
57066 LET X5 = H(X5, 4)
57067 IF X5 > 0 THEN 57065
57068 LET X5 = H(X3, 3)
57069 RETURN
57070 REM ---- 57070: (56448) a matrix concatenation (L9 (c), L-eu): each row's join (R, C) (57190), the first
57071 REM row's the stack's (G, H), each later one's columns checked against H (chk at P, none for a
57072 REM fixed-size result) and its rows summed into G; Y(row,5) its R; U = anew (G H), D its data, the
57073 REM offsets o (rows) and J (columns, per row); each part copied at (o, J) (57117); o += the previous
57074 REM row's R, J += the previous part's c (n in a row of scalars and vectors)
57076 LET Q9$ = U$
57077 LET X5 = H(X, 3)
57078 LET D8 = 0
57079 GOSUB 57190
57080 LET Y(X5, 5) = V(18)
57081 IF D8 > 0 THEN 57085
57082 LET V(7) = V(18)
57083 LET V(8) = V(3)
57084 GOTO 57090
57085 LET S$ = "L H,L C,bin P 2 ne,= S,L S,L G,L H,L R,L C,chk Q SHAPE_MISMATCH 4,"
57086 IF T(H(X, 2), 3) = 0 THEN 57088
57087 LET S$ = ""
57088 LET S$ = S$ & "L G,L R,wbin P 3 add,= G"
57089 GOSUB 9000
57090 LET D8 = D8 + 1
57091 LET X5 = H(X5, 4)
57092 IF X5 > 0 THEN 57079
57093 LET K8 = 0
57094 LET S$ = "L G,L H,anew P %0 0 2,= U,D U,= D,C 0,= o"
57095 IF T(H(X, 2), 3) = 0 THEN 57097
57096 LET S$ = "anew P %0 0 0,= U,D U,= D,C 0,= o"
57097 GOSUB 9000
57098 LET X5 = H(X, 3)
57099 LET D8 = 0
57100 IF D8 = 0 THEN 57103
57101 LET S$ = "L o,L K,wbin P 3 add,= o"
57102 GOSUB 9000
57103 LET D1 = H(X5, 3)
57104 LET D6 = 0
57105 LET S$ = "C 0,= J"
57106 GOSUB 9000
57107 GOSUB 57117
57108 LET D6 = 1
57109 LET D1 = H(D1, 4)
57110 IF D1 > 0 THEN 57107
57111 LET V(11) = Y(X5, 5)
57112 LET D8 = 1
57113 LET X5 = H(X5, 4)
57114 IF X5 > 0 THEN 57100
57115 GOTO 56530
57116 REM ---- 57117: the part D1 of row X5 copied at (o, J), after J += the previous part's c or n (K)
57117 IF D6 = 0 THEN 57120
57118 LET S$ = "L J,L K,wbin P 3 add,= J"
57119 GOSUB 9000
57120 LET K8 = Y(D1, 3)
57121 LET D2 = D1
57122 IF H(D1, 2) > 9 THEN 57126
57123 LET S$ = "L a,L D,L o,L J,L G,wbin P 3 mul,wbin P 3 add,est P %5 0"
57124 GOSUB 9000
57125 GOTO 57135
57126 IF T(H(D1, 2), 1) = 2 THEN 57130
57127 LET Q9 = 1
57128 LET S$ = "D a,= x,( n K"
57129 GOTO 57132
57130 LET Q9 = 3
57131 LET S$ = "D a,= x,( c L,( r K"
57132 GOSUB 9000
57133 GOSUB 57177
57134 GOSUB 9000
57135 LET V(11) = V(100 + 25 * Y(D1, 3) + 8 - 5 * Y(X5, 6))
57136 RETURN
57139 REM ---- 57140: C7 = 0; C3 = 1 when the concatenation X3 is denied (30900) or the parts of its rows from X5 take more slots than a unit has (3 each at most, 30870); X8 the first part of row X5
57140 LET C7 = 0
57141 LET C3 = 0
57142 LET I3 = 0
57143 LET I4 = X5
57144 LET X8 = H(I4, 3)
57145 IF X8 = 0 THEN 57149
57146 LET I3 = I3 + 3
57147 LET X8 = H(X8, 4)
57148 GOTO 57145
57149 LET I4 = H(I4, 4)
57150 IF I4 > 0 THEN 57144
57151 LET I5 = X3
57152 GOSUB 30900
57153 IF I6 = 1 THEN 57155
57154 IF I3 <= 1180 THEN 57156
57155 LET C3 = 1
57156 LET X8 = H(X5, 3)
57157 RETURN
57159 REM ---- 57160: (56164) a .flat reduction X3's tree X9 fused standalone when its slots fit (30860) and X3 is not denied (30900)
57160 GOSUB 30860
57161 IF I3 > 1180 THEN 55060
57162 LET I5 = X3
57163 GOSUB 30900
57164 IF I6 = 1 THEN 55060
57165 GOTO 57242
57169 REM ---- 57170: (56126) a reduction X3 of a mask selection X6 fused standalone unless denied (30900; its leaf marks undone)
57170 LET I5 = X3
57171 GOSUB 30900
57172 IF I6 = 0 THEN 55048
57173 LET Y(X6, 4) = 0
57174 LET Y(X6, 7) = 0
57175 GOTO 55060
57176 REM ---- 57177: (57133) the element of part D1 at K (a vector part, Q9 = 1) or (K, L) (a matrix part, Q9 = 3): a folded one's by its map (40820), else from its data; S$ = its store into D at o + (J + K) G or lin(o + K, J + L, G)
57177 IF Y(D1, 1) <> 1 THEN 57180
57178 GOSUB 40820
57179 GOTO 57184
57180 LET S$ = "L x,L K,L L,L r,wbin P 3 mul,wbin P 3 add,eld P %e %u 0"
57181 IF Q9 = 3 THEN 57183
57182 LET S$ = "L x,L K,eld P %e %u 0"
57183 GOSUB 9000
57184 LET K8 = Y(D1, 3)
57185 LET S$ = "L D,L o,L K,wbin P 3 add,L J,L L,wbin P 3 add,L G,wbin P 3 mul,wbin P 3 add,est P %5 0,),)"
57186 IF Q9 = 3 THEN 57188
57187 LET S$ = "L D,L o,L J,L K,wbin P 3 add,L G,wbin P 3 mul,wbin P 3 add,est P %5 0,)"
57188 RETURN
57189 REM ---- 57190: (57079) the join (R, C) of row X5 (L9 (c)): Y(X5,6) 1 matrices and scalars (r c each, a scalar 1 1; rows checked against R, no chk if fixed; C += c), 0 scalars and vectors (n each, a scalar 1; C += n; R = 1)
57190 LET Y(X5, 6) = 0
57191 LET D1 = H(X5, 3)
57192 IF H(D1, 2) <= 9 THEN 57195
57193 IF T(H(D1, 2), 1) <> 2 THEN 57195
57194 LET Y(X5, 6) = 1
57195 LET D1 = H(D1, 4)
57196 IF D1 > 0 THEN 57192
57197 LET D1 = H(X5, 3)
57198 LET D9 = 0
57199 LET K8 = Y(D1, 3)
57200 LET S$ = "C 1,= n"
57201 IF Y(X5, 6) = 0 THEN 57203
57202 LET S$ = "C 1,= r,C 1,= c"
57203 IF H(D1, 2) <= 9 THEN 57210
57204 IF Y(D1, 1) <> 1 THEN 57207
57205 GOSUB 40380
57206 GOTO 57211
57207 LET S$ = "X a 0,= n"
57208 IF Y(X5, 6) = 0 THEN 57210
57209 LET S$ = "X a 0,= r,X a 1,= c"
57210 GOSUB 9000
57211 LET Q0 = 100 + 25 * Y(D1, 3)
57212 IF D9 > 0 THEN 57218
57213 LET V(3) = V(Q0 + 8)
57214 IF Y(X5, 6) = 0 THEN 57225
57215 LET V(18) = V(Q0 + 10)
57216 LET V(3) = V(Q0 + 3)
57217 GOTO 57225
57218 LET K8 = Y(D1, 3)
57219 LET S$ = "L C,L n,wbin P 3 add,= C"
57220 IF Y(X5, 6) = 0 THEN 57224
57221 LET S$ = "L R,L r,bin P 2 ne,= S,L S,L R,L C,L r,L c,chk Q SHAPE_MISMATCH 4,L C,L c,wbin P 3 add,= C"
57222 IF T(H(X, 2), 3) = 0 THEN 57224
57223 LET S$ = "L C,L c,wbin P 3 add,= C"
57224 GOSUB 9000
57225 LET D9 = D9 + 1
57226 LET D1 = H(D1, 4)
57227 IF D1 > 0 THEN 57199
57228 IF Y(X5, 6) = 1 THEN 57231
57229 LET S$ = "C 1,= R"
57230 GOTO 9000
57231 RETURN
57241 REM ---- 57242: (57165) a .flat reduction's failing tree root X9 under variance or std (57250) is not fused with it
57242 LET I5 = X9
57243 GOSUB 57250
57244 IF I6 = 0 THEN 56166
57245 GOTO 55060
57248 REM ---- 57250: I6 = 1 when the reduction X3 is variance or std and its tree's root I5 can fail: F3 fuses their tree only when it is
57249 REM quiet (2.12.4 F3; L13's N = 1 arm reads no element, so a failing root is left to F1 and L13, which evaluate every element first)
57250 LET I6 = 0
57251 IF Y(I5, 0) <> 2 THEN 57257
57252 LET R2 = H(X3, 6)
57253 LET F9 = 4
57254 GOSUB 8440
57255 IF POS("|variance|std|", "|" & F9$ & "|") = 0 THEN 57257
57256 LET I6 = 1
57257 RETURN
