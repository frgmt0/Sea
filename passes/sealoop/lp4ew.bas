19900 REM ====================================================================================
19902 REM sealoop part 4 (lines 19900-24999): element-wise operations and the other value
19904 REM rewrites of DESIGN 3.5.9: L8 range values, L7 (an operation's operands in the slots 1
19906 REM ... N4: a its tmp, e u its element type and size, k its rank, n or r c its extents, s j
19908 REM its strides, x its data), L6's compound store of a whole array, L10 dyn, fix and
19910 REM materialized views, L11 ind2sub with an array k. %0 is the result's type, %1 its element
19912 REM type, %5 that element's size; %2 %3 %4 the sizes of bool, i64, f64, %6 SEA_SHAPE_VEC.
19914 REM ====================================================================================
19995 REM ==== L8 (rule 25): the range value X (also a fore's vector) =================================
20000 LET R2 = H(X, 6)
20002 GOSUB 8400
20004 LET V(53) = H(X, 2)
20006 GOSUB 9115
20008 LET K8 = 0
20010 LET X5 = X
20012 GOSUB 15530
20014 LET C9 = O9
20016 LET S$ = "C 1,= r,L l,L r,wbin P 3 add,= t,C 0,= s,L e,L t,L s,lib P 3 where 3,= n,ci P 3 " & X9$
20018 LET S$ = S$ & ",= x,L l,L x,bin P 2 gt,= G,L l,L s,bin P 2 lt,= U,L G,L U,bin P 2 bor,B B,L B,L B,L e"
20020 LET S$ = S$ & ",bin P 2 band,asg P set,ci P 3 #7FFFFFFFFFFFFFFF,= m,L l,L m,bin P 2 eq,B h,L h,L h,L U"
20022 LET S$ = S$ & ",bin P 2 bor,asg P set,L h,L m,L t,lib P 3 where 3,= V,L B,L V,chk P ARRAY_SIZE 1,L n"
20024 LET S$ = S$ & ",anew P %0 0 1,= A,D A,= D,C 0,B Q,C 1,= O,[ e a l c k,L k,L D,L Q,est P %3 0,L Q,L Q"
20026 LET S$ = S$ & ",L O,wbin P 3 add,asg P set,),L A,]"
20028 GOSUB 9000
20030 LET N7 = N7 - 1
20032 GOTO 5180
20095 REM ==== L7 (rule 22): the node X with an array operand =========================================
20100 LET R2 = H(X, 6)
20102 GOSUB 8400
20104 LET T6 = H(X, 2)
20106 LET Y7 = T6
20108 GOSUB 8700
20110 IF R5 = 0 THEN 2900
20112 LET Z$ = D$(R2)
20114 LET F9 = 3
20116 GOSUB 8440
20118 LET F9$ = STR$(E5)
20120 GOSUB 8470
20122 LET Z6$ = Z$
20124 GOSUB 9115
20126 LET N4 = 0
20128 LET X4 = X1
20130 IF X4 = 0 THEN 20140
20132 LET N4 = N4 + 1
20134 LET K8 = N4
20136 LET S$ = "= a"
20137 GOSUB 8900
20138 LET X4 = H(X4, 4)
20139 GOTO 20130
20140 LET C9 = O9
20142 GOSUB 20150
20144 LET S$ = "L Q,]"
20146 GOSUB 9000
20147 LET N7 = N7 - 1
20148 GOTO 5180
20149 REM ---- 20150: L7 (2)-(6) of the operands a of slots 1 ... N4, the result type T6, Z6$ the
20150 REM scalar operation's record (its type the element's); the result is Q, then K8 = 0
20151 LET Y7 = T6
20152 GOSUB 8700
20153 LET R4 = R5
20154 LET F4 = F5
20155 LET V(53) = T6
20156 LET V(58) = S(E5)
20157 LET K9 = 0
20158 LET Z8 = 0
20159 LET Z7 = 0
20160 REM (2) the extents of the array operands (of a fixed-size result only the matrices')
20161 FOR K8 = 1 TO N4
20162 LET Q0 = 100 + 25 * K8
20163 LET Y7 = U(V(Q0 + 1), 1)
20164 GOSUB 8700
20165 LET V(Q0 + 4) = E5
20166 LET V(Q0 + 13) = S(E5)
20167 LET V(Q0 + 6) = R5
20168 IF R5 = 0 THEN 20178
20169 IF K9 > 0 THEN 20171
20170 LET K9 = K8
20171 LET S$ = "X a 0,= n"
20172 IF R5 = 1 THEN 20174
20173 LET S$ = "X a 0,= r,X a 1,= c"
20174 IF F4 = 0 THEN 20177
20175 IF R5 = 1 THEN 20178
20177 GOSUB 9000
20178 NEXT K8
20179 IF K9 = 0 THEN 2900
20180 REM the checks of a dynamic result, folded left to right (G, or R and C, the shape so far)
20181 IF F4 = 1 THEN 20210
20182 LET Q0 = 100 + 25 * K9
20183 LET V(7) = V(Q0 + 8)
20184 LET V(18) = V(Q0 + 10)
20185 LET V(3) = V(Q0 + 3)
20186 FOR K8 = K9 + 1 TO N4
20187 IF V(100 + 25 * K8 + 6) = 0 THEN 20202
20188 IF R4 = 2 THEN 20196
20189 LET S$ = "L G,L n,bin P 2 ne,= S,"
20190 IF Z8 = 1 THEN 20192
20191 LET S$ = S$ & "ci P 3 %6,= Z,"
20192 LET S$ = S$ & "L S,L G,L Z,L n,L Z,chk P SHAPE_MISMATCH 4"
20193 LET Z8 = 1
20194 GOTO 20201
20196 GOSUB 20290
20197 LET S$ = S$ & "L R,L r,bin P 2 eq,B A,L R,L O,bin P 2 eq,= B,L r,L O,bin P 2 eq,= E,L A,L A,L B,bin P 2 bor"
20198 LET S$ = S$ & ",asg P set,L A,L A,L E,bin P 2 bor,asg P set,L C,L c,bin P 2 eq,B F,L C,L O,bin P 2 eq,= H"
20199 LET S$ = S$ & ",L c,L O,bin P 2 eq,= J,L F,L F,L H,bin P 2 bor,asg P set,L F,L F,L J,bin P 2 bor,asg P set"
20200 LET S$ = S$ & ",L A,L A,L F,bin P 2 band,asg P set,L A,un P 2 not,= S,L S,L R,L C,L r,L c,chk P SHAPE_MISMATCH 4"
20201 GOSUB 20280
20202 NEXT K8
20203 GOTO 20220
20205 REM (3) a fixed-size result: its home, then its extents
20210 LET S$ = "anew P %0 0 0,= Q,X Q 0,= G"
20212 IF R4 = 1 THEN 20230
20214 LET S$ = "anew P %0 0 0,= Q,X Q 0,= R,X Q 1,= C"
20216 GOTO 20230
20220 LET S$ = "L G,anew P %0 0 1,= Q"
20222 IF R4 = 1 THEN 20230
20224 LET S$ = "L R,L C,anew P %0 0 2,= Q"
20230 LET K8 = 0
20232 GOSUB 9000
20234 IF R4 = 1 THEN 20244
20235 REM (4) the strides of the matrix operands
20236 FOR K8 = 1 TO N4
20237 IF V(100 + 25 * K8 + 6) = 0 THEN 20241
20238 GOSUB 20290
20239 LET S$ = S$ & "L r,L O,bin P 2 ne,= s,L c,L O,bin P 2 ne,= t,L t,L r,wbin P 3 mul,= j"
20240 GOSUB 9000
20241 NEXT K8
20243 REM (5) the data of the result and of the array operands, (6) the loop nest and its body
20244 LET K8 = 0
20245 LET S$ = "D Q,= D"
20246 GOSUB 9000
20247 FOR K8 = 1 TO N4
20248 IF V(100 + 25 * K8 + 6) = 0 THEN 20251
20249 LET S$ = "D a,= x"
20250 GOSUB 9000
20251 NEXT K8
20252 LET K8 = 0
20253 LET S$ = "( G K"
20254 IF R4 = 1 THEN 20256
20255 LET S$ = "( C L,( R K"
20256 GOSUB 9000
20257 FOR K8 = 1 TO N4
20258 LET Q0 = 100 + 25 * K8
20259 LET S$ = "L a"
20260 IF V(Q0 + 6) = 0 THEN 20264
20261 LET S$ = "L x,L K,eld P %e %u 0"
20262 IF R4 = 1 THEN 20264
20263 LET S$ = "L x,L K,L s,wbin P 3 mul,L L,L j,wbin P 3 mul,wbin P 3 add,eld P %e %u 0"
20264 GOSUB 9000
20265 NEXT K8
20266 LET Z$ = Z6$
20267 GOSUB 8050
20268 LET K8 = 0
20269 LET S$ = "L D,L K,est P %5 0,)"
20270 IF R4 = 1 THEN 20272
20271 LET S$ = "L D,L K,L L,L R,wbin P 3 mul,wbin P 3 add,est P %5 0,),)"
20272 GOTO 9000
20278 REM ---- 20280: S$ run, then the combined shape (R, C) := (where(R = 1, r, R), where(C = 1, c, C))
20280 GOSUB 9000
20281 IF R4 = 1 THEN 20284
20282 LET S$ = "L R,L O,bin P 2 eq,L r,L R,lib P 3 where 3,= R,L C,L O,bin P 2 eq,L c,L C,lib P 3 where 3,= C"
20283 GOSUB 9000
20284 RETURN
20288 REM ---- 20290: S$ = "tmp O = ci 1," at its first use, else empty
20290 LET S$ = ""
20291 IF Z7 = 1 THEN 20294
20292 LET S$ = "C 1,= O,"
20293 LET Z7 = 1
20294 RETURN
20295 REM ==== L6 for whole arrays: asg op (lv a) e = asg set (lv a) (the L7 xblk of bin op (lv a) e) ===
20300 LET R2 = H(X, 6)
20302 GOSUB 8400
20304 LET F9 = 3
20306 GOSUB 8440
20308 LET X4 = X1
20310 LET T6 = H(X4, 2)
20312 LET Y7 = T6
20314 GOSUB 8700
20316 LET Z6$ = "bin " & P9$ & " " & STR$(E5) & " " & F9$
20318 LET R2 = H(X4, 6)
20320 LET F9 = 4
20322 GOSUB 8440
20324 LET C9 = H(X4, 8)
20326 GOSUB 9115
20328 LET Z$ = "lv " & P9$ & " " & STR$(T6) & " " & F9$
20330 GOSUB 8050
20332 LET K8 = 1
20334 LET L8 = T6
20336 LET S$ = "= a"
20338 GOSUB 9000
20340 LET K8 = 2
20342 LET X4 = H(X4, 4)
20344 GOSUB 8900
20346 LET C9 = O9
20348 LET N4 = 2
20350 GOSUB 20150
20352 LET S$ = "L Q,],asg P set"
20354 GOSUB 9000
20356 LET N7 = N7 - 1
20358 GOTO 5180
20495 REM ==== L10 (rule 27 (i), (j)): dyn and fix of the operand X1 ===================================
20500 LET R2 = H(X, 6)
20502 GOSUB 8400
20504 LET T6 = H(X, 2)
20506 LET V(53) = T6
20508 LET Y7 = H(X1, 2)
20510 GOSUB 8700
20512 LET R4 = R5
20514 LET F4 = F5
20516 LET Y7 = T6
20518 GOSUB 8700
20520 IF R4 <> R5 THEN 2900
20522 IF R4 = 0 THEN 2900
20524 IF F4 + F5 <> 1 THEN 2900
20526 GOSUB 9115
20528 LET K8 = 0
20530 LET X4 = X1
20532 IF K = 44 THEN 20550
20534 IF F4 = 0 THEN 2900
20536 LET S$ = "= S"
20538 GOSUB 8900
20540 LET Y7 = H(X1, 2)
20541 GOSUB 8700
20542 LET S$ = "X S 0,= R,L R,anew P %0 0 1,= A"
20543 IF R5 = 1 THEN 20545
20544 LET S$ = "X S 0,= R,X S 1,= C,L R,L C,anew P %0 0 2,= A"
20545 LET S$ = S$ & ",D A,= D,C " & STR$(B5) & ",= K,L D,D S,L K,mcpy P,L A,]"
20546 GOTO 20570
20550 LET S$ = "= A"
20552 GOSUB 8900
20554 GOSUB 20580
20562 LET S$ = S$ & ",anew P %0 0 0,= V,D A,= D,C " & STR$(B5) & ",= K,D V,L D,L K,mcpy P,L V,]"
20570 GOSUB 9000
20572 LET N7 = N7 - 1
20574 GOTO 5180
20578 REM ---- 20580: S$ = the shape check of fix: the extents of A (rank R5) against those of T6
20580 LET S$ = "X A 0,= R,C " & STR$(T(T6, 0)) & ",= E,L R,L E,bin P 2 ne,= S,ci P 3 %6,= Z,L S,L E,L Z,L R,L Z"
20582 IF R5 = 1 THEN 20588
20584 LET S$ = "X A 0,= R,X A 1,= C,C " & STR$(T(T6, 0)) & ",= E,C " & STR$(T(T6, 4)) & ",= F,L R,L E,bin P 2 ne,= G"
20586 LET S$ = S$ & ",L C,L F,bin P 2 ne,= H,L G,L H,bin P 2 bor,= S,L S,L E,L F,L R,L C"
20588 LET S$ = S$ & ",chk P SHAPE_EXPECTED 4"
20590 RETURN
20595 REM ==== L10 (rule 28): the view X materialized (not an idx base, or a .T masked whole) ===========
20600 LET R2 = H(X, 6)
20602 GOSUB 8400
20604 LET F9 = 4
20606 GOSUB 8440
20608 LET V0 = (POS("|T   |flat|col |row ", "|" & F9$) - 1) / 5 + 1
20610 LET T6 = H(X, 2)
20612 LET V(53) = T6
20614 LET Y7 = T6
20616 GOSUB 8700
20618 LET F4 = F5
20620 LET V(54) = E5
20622 LET V(58) = S(E5)
20624 GOSUB 9115
20626 LET K8 = 0
20628 LET X4 = X1
20630 LET S$ = "= A"
20632 GOSUB 8900
20634 LET Y7 = H(X1, 2)
20636 GOSUB 8700
20638 IF R5 = 0 THEN 2900
20640 IF F5 <> F4 THEN 2900
20642 IF V0 = 1 THEN 20670
20644 IF F5 = 1 THEN 20664
20646 LET C8$ = "R"
20648 LET S$ = "X A 0,= R,L R,C 1,anew P %0 0 2"
20650 IF V0 = 3 THEN 20660
20652 LET S$ = "X A 0,= R,C 1,L R,anew P %0 0 2"
20654 IF V0 = 4 THEN 20660
20656 LET C8$ = "K"
20658 LET S$ = "X A 0,= R,X A 1,= C,L R,L C,wbin P 3 mul,= K,L K,anew P %0 0 1"
20660 LET S$ = S$ & ",= V,D V,= D,D A,= S,L " & C8$ & ",ci P 3 %5,wbin P 3 mul,= B,L D,L S,L B,mcpy P,L V,]"
20662 GOTO 20690
20664 LET S$ = "anew P %0 0 0,= V,D V,= D,D A,= S,C " & STR$(B5) & ",= B,L D,L S,L B,mcpy P,L V,]"
20666 GOTO 20690
20670 IF R5 <> 2 THEN 2900
20672 LET S$ = "X A 1,= R,X A 0,= C,L R,L C,anew P %0 0 2"
20674 IF F4 = 0 THEN 20678
20676 LET S$ = "X A 1,= R,X A 0,= C,anew P %0 0 0"
20678 LET S$ = S$ & ",= V,D V,= F,D A,= G,( C h,( R z,L G,L h,L z,L C,wbin P 3 mul,wbin P 3 add,eld P %1 %5 0"
20680 LET S$ = S$ & ",L F,L z,L h,L R,wbin P 3 mul,wbin P 3 add,est P %5 0,),),L V,]"
20690 GOSUB 9000
20692 LET N7 = N7 - 1
20694 GOTO 5180
20795 REM ==== L11 (Decision 33): tbind, tasg or tret X of ind2sub(r, k), r a scalar, k an array ========
20800 LET X5 = X1
20802 IF H(X5, 4) = 0 THEN 20806
20804 LET X5 = H(X5, 4)
20805 GOTO 20802
20806 LET R2 = H(X5, 6)
20808 GOSUB 8400
20810 LET R7 = R2
20812 LET Y6 = H(X5, 2)
20814 IF T(Y6, 1) <> 0 THEN 2900
20816 GOSUB 9115
20818 LET K8 = 0
20820 IF K <> 24 THEN 20834
20822 REM a tasg: its targets' rows are cut off, put back for the stores (G7 the first)
20824 LET G7 = O(H(X, 0), 0)
20826 LET G8 = H(H(X5, 3), 0)
20828 LET O(H(X, 0), 0) = O(G8, 0)
20830 LET O(G8, 0) = 0
20834 LET X4 = H(X5, 3)
20836 LET S$ = "B p"
20838 GOSUB 8900
20840 LET X4 = H(X4, 4)
20842 LET Y7 = H(X4, 2)
20844 GOSUB 8700
20846 LET S$ = "B o"
20848 IF F5 = 0 THEN 20852
20850 LET S$ = "= o"
20852 GOSUB 8900
20854 LET C9 = O9
20856 FOR I6 = 1 TO 2
20858 GOSUB 9115
20860 LET K8 = 1
20862 LET S$ = "L o,= a"
20864 GOSUB 9000
20866 LET K8 = 2
20868 LET S$ = "L p,= a"
20870 GOSUB 9000
20872 LET N4 = 2
20874 LET T6 = T(Y6, 2 + I6)
20876 LET Z6$ = "bin " & P9$ & " 3 mod"
20878 IF I6 = 1 THEN 20882
20880 LET Z6$ = "lib " & P9$ & " 3 idiv 2"
20882 GOSUB 20150
20884 LET S$ = "L Q,]"
20886 GOSUB 9000
20888 IF K <> 21 THEN 20904
20890 LET R2 = H(X, 6)
20892 LET F9 = 3 + I6
20894 GOSUB 8440
20896 LET Z$ = "eval " & P9$
20898 IF F9$ = "-" THEN 20902
20900 LET Z$ = "bind " & P9$ & " " & F9$
20902 GOSUB 8050
20903 GOTO 20912
20904 LET Y7 = T6
20906 GOSUB 8700
20908 LET S$ = SEG$("B E,B F,= E,= F", 4 * I6 + 8 * F5 - 3, 4 * I6 + 8 * F5 - 1)
20910 GOSUB 9000
20911 LET V(470 + I6) = V(4 + I6)
20912 NEXT I6
20914 IF K <> 21 THEN 20924
20916 LET H(W(X), 5) = H(W(X), 5) + M(Z0, 1) - 1
20918 LET Z0 = Z0 - 1
20920 GOTO 20961
20924 IF K <> 31 THEN 20930
20925 LET V(5) = V(471)
20926 LET V(6) = V(472)
20927 LET S$ = "L E,L F,ret P 2,}"
20928 GOTO 20959
20930 REM a tasg: each target's rows back at the tail, then its store of E or F (a selection's: L6)
20932 LET G5 = V(471)
20933 LET G6 = V(472)
20934 LET X3 = X1
20935 LET I6 = 1
20936 LET G9 = O(H(X3, 8), 0)
20937 LET V(474) = G9
20938 IF H(X3, 1) = 18 THEN 20963
20940 LET P6 = O9
20941 LET O(O9, 0) = G7
20942 LET O9 = H(X3, 8)
20943 LET O(O9, 0) = 0
20944 LET V(5) = G5
20945 LET V(6) = G6
20946 REM the store of lv E (or F), converted by its cv (L12's, lp6tup; it may use G7 ... G9)
20947 LET W3 = V(4 + I6)
20948 LET R2 = H(X, 6)
20949 LET F9 = 3 + I6
20950 GOSUB 8440
20951 LET W6 = VAL(F9$)
20952 GOSUB 30300
20954 LET G7 = V(474)
20955 LET X3 = H(X3, 4)
20956 LET I6 = I6 + 1
20957 IF H(X3, 4) > 0 THEN 20936
20958 LET S$ = "}"
20959 LET K8 = 0
20960 GOSUB 9000
20961 LET N7 = N7 - 1
20962 GOTO 5180
20963 LET N7 = N7 - 1
20964 GOTO 20954
