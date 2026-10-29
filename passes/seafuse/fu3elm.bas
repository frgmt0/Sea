20000 REM ====================================================================================
20001 REM seafuse part 3 (lines 20000-29999): L19, the elemental application (DESIGN 2.11.4, 2.12.3
20002 REM "L19 in seafuse"; Decision 84, L-ck, L-do), and ind2sub with an array r (L-cl, L-dp). The
20003 REM rewritten node I8 (an emap P T iid n, or the lib ind2sub of a holder, A7 = 1) with the
20004 REM arguments a1 ... an: (1) tmp P Ai = ai after each argument's subtree; (2) rule 22's
20005 REM broadcast extents and shape checks of the arguments of elemental parameters whose type is
20006 REM an array (21000, the same records and order as sealoop's L7); (3) a home Rj = anew for
20007 REM each kept result (fixed size: then its extents); the data of the homes, then of the array
20008 REM arguments; (4) the nest, whose body is the call P ty1 fid n of the elemental function F
20009 REM (sealoop's L20 inlines it) with each array argument's element (eld) and lv Ai for the
20010 REM others, stored by est (k = 1), bound by a tbind of new .l locals Ej whose kept ones are
20011 REM stored (k >= 2), or a statement eval (nothing kept); for L-cl the block of rule 36's
20012 REM sequence; (5) the value lv R1 (k = 1, an xblk), or in place of the holder L11's statement
20013 REM forms: a tbind's locals bound from the Rj, a tasg's targets stored by asg P set (22000:
20014 REM a cv converted as rule 15 (j) says), ret P k for a tret, nothing for an eval. Slots
20015 REM (fu1walk 9000): one per argument, a its tmp, e u its element type and size, k its rank (0
20016 REM for an argument of a uniform or scalar parameter, V(Q0+22) = 1), n or r c its extents, s j
20017 REM its strides, x its data. X the node rewritten (the emap, or its holder statement), I7 the
20018 REM holder's seq or 0, L6 the holder's kind (0 none), L5 k, U3 the kept results, J0 n, Y1 F,
20019 REM F4 R4 the broadcast's fixed and rank, G4 L0 its static extents. Script names: U a home,
20020 REM V its data (V(1700 + j) and V(1800 + j) per result j), f an element result.
20021 REM ---- P, n, k (Y6 the node's type) and the kept results ------------------------------------
20022 LET R2 = H(I8, 6)
20024 GOSUB 8400
20026 LET R7 = R2
20028 LET Y6 = H(I8, 2)
20030 LET J0 = 0
20032 LET X4 = H(I8, 3)
20034 IF X4 = 0 THEN 20040
20036 LET J0 = J0 + 1
20038 LET X4 = H(X4, 4)
20039 GOTO 20034
20040 LET L5 = 0
20042 IF A7 = 0 THEN 20052
20044 LET L5 = 2
20046 IF Y6 <= 9 THEN 2900
20048 IF T(Y6, 1) + T(Y6, 2) > 0 THEN 2900
20050 GOTO 20066
20052 LET Y1 = H(I8, 5)
20054 IF Y6 = 1 THEN 20070
20056 LET L5 = 1
20058 IF Y6 <= 9 THEN 2900
20060 IF T(Y6, 1) > 0 THEN 20070
20062 IF T(Y6, 2) > 0 THEN 2900
20066 GOSUB 20955
20068 LET L5 = VAL(F9$)
20069 IF A7 * (L5 - 2) <> 0 THEN 2900
20070 IF L5 > 64 THEN 2900
20072 IF L6 > 0 THEN 20076
20074 IF L5 <> 1 THEN 2900
20076 IF L6 <> 21 THEN 20084
20078 LET R2 = H(X, 6)
20080 LET F9 = 3
20081 GOSUB 8440
20082 IF VAL(F9$) <> L5 THEN 2900
20084 IF L6 <> 24 THEN 20090
20086 GOSUB 20930
20087 IF J9 <> L5 THEN 2900
20088 REM the kept results: none under an eval, not a - of a tbind nor a skip of a tasg
20090 LET U3 = 0
20092 LET X3 = H(X, 3)
20094 FOR W4 = 1 TO L5
20096 LET V(1800 + W4) = 0
20098 IF L6 = 22 THEN 20120
20100 IF L6 <> 24 THEN 20106
20102 IF H(X3, 1) = 18 THEN 20118
20104 GOTO 20114
20106 IF L6 <> 21 THEN 20114
20108 LET R2 = H(X, 6)
20110 LET F9 = 3 + W4
20111 GOSUB 8440
20112 IF F9$ = "-" THEN 20120
20114 LET V(1800 + W4) = 1
20116 LET U3 = U3 + 1
20118 LET X3 = H(X3, 4)
20120 NEXT W4
20121 REM ---- the slots: every argument; the rank, fixedness and static extents of the broadcast
20122 LET N4 = J0
20124 LET N0 = 0
20126 LET F4 = 1
20128 LET G4 = 1
20130 LET L0 = 1
20132 LET X4 = H(I8, 3)
20134 FOR K8 = 1 TO N4
20136 LET Q0 = 100 + 25 * K8
20138 LET V(Q0 + 22) = 0
20140 LET Y7 = H(X4, 2)
20142 IF A7 = 1 THEN 20148
20144 IF Y7 <> A(G(Y1, 1) + K8) THEN 20148
20146 LET V(Q0 + 22) = 1
20147 GOTO 20162
20148 GOSUB 8700
20150 IF R5 = 0 THEN 20162
20152 LET N0 = N0 + 1
20154 LET R4 = R5
20156 LET F4 = F4 * F5
20158 IF T(Y7, 0) < 2 THEN 20162
20160 LET G4 = T(Y7, 0)
20162 IF R5 = 0 THEN 20166
20163 IF T(Y7, 4) < 2 THEN 20166
20164 LET L0 = T(Y7, 4)
20166 LET X4 = H(X4, 4)
20168 NEXT K8
20170 IF N0 = 0 THEN 2900
20171 REM ---- the block of the rewrite (an xblk, a block, or the statements in place of a tbind)
20172 GOSUB 9115
20174 IF I7 = 0 THEN 20190
20175 REM a seq's binds become statements: its record row is dropped
20176 LET X5 = H(I7, 8)
20178 LET O(H(I8, 8), 0) = O(X5, 0)
20180 IF O9 <> X5 THEN 20184
20182 LET O9 = H(I8, 8)
20184 LET N7 = N7 - 1
20186 LET R2 = H(I7, 6)
20187 LET F9 = 4
20188 GOSUB 8440
20189 LET M(Z0, 1) = M(Z0, 1) + VAL(F9$)
20190 IF L6 <> 24 THEN 20210
20191 REM a tasg: its targets' rows are cut off, put back for the stores (G7 the first)
20192 LET X5 = I8
20194 IF I7 = 0 THEN 20198
20196 LET X5 = I7
20198 LET G7 = O(H(X, 0), 0)
20200 LET G8 = H(X5, 0)
20202 LET O(H(X, 0), 0) = O(G8, 0)
20204 LET O(G8, 0) = 0
20209 REM ---- step (1): tmp P Ai after each argument's subtree, of the argument's type
20210 LET X4 = H(I8, 3)
20212 FOR K8 = 1 TO N4
20214 LET S$ = "= a"
20216 GOSUB 8900
20218 LET X4 = H(X4, 4)
20220 NEXT K8
20222 REM ---- steps (2)-(4): rule 22's extents, checks, homes, data and nest (21000)
20224 LET C9 = O9
20226 LET A3 = 1
20228 GOSUB 21000
20230 LET A3 = 0
20232 IF A7 = 1 THEN 20400
20234 REM the element call: each argument's element or lv Ai, call P ty1 fid n (ty1 F's result type)
20236 FOR K8 = 1 TO N4
20238 LET Q0 = 100 + 25 * K8
20240 LET S$ = "L a"
20242 IF V(Q0 + 6) = 0 THEN 20248
20244 LET S$ = "L x,L K,eld P %e %u 0"
20246 IF R4 = 2 THEN 20250
20248 GOTO 20252
20250 LET S$ = "L x,L K,L s,wbin P 3 mul,L L,L j,wbin P 3 mul,wbin P 3 add,eld P %e %u 0"
20252 GOSUB 9000
20254 NEXT K8
20256 LET R2 = G(Y1, 6)
20258 LET F9 = 5
20260 GOSUB 8440
20262 LET Z$ = "call " & P9$ & " " & F9$ & " " & STR$(Y1) & " " & STR$(J0)
20264 GOSUB 8050
20265 REM after the element value: eval (nothing kept), est (k = 1) or a tbind and the ests
20266 LET K8 = 0
20268 LET S$ = "eval P"
20270 IF U3 = 0 THEN 20346
20272 IF L5 > 1 THEN 20284
20274 LET V(22) = V(1701)
20276 LET S$ = ""
20278 LET U1 = Y6
20280 GOSUB 20980
20282 GOTO 20346
20283 REM k >= 2: block { tbind P k of new .l locals Ej (- discarded), the est of each kept Ej }
20284 GOSUB 9115
20286 LET Y9$ = "tbind " & P9$ & " " & STR$(L5)
20288 LET U7 = U0 + 1
20290 FOR W4 = 1 TO L5
20292 IF V(1800 + W4) > 0 THEN 20298
20294 LET Y9$ = Y9$ & " -"
20296 GOTO 20306
20298 GOSUB 20966
20300 LET U1 = T(U1, 2)
20302 LET U2 = 0
20303 GOSUB 8100
20304 LET Y9$ = Y9$ & " @" & STR$(U0)
20306 NEXT W4
20308 LET Z$ = Y9$
20310 GOSUB 8050
20312 LET M(Z0, 1) = M(Z0, 1) + 1
20314 FOR W4 = 1 TO L5
20316 IF V(1800 + W4) = 0 THEN 20329
20318 LET V(32) = U7
20320 LET U7 = U7 + 1
20322 LET V(22) = V(1700 + W4)
20323 GOSUB 20966
20324 LET S$ = "L f,"
20325 GOSUB 20980
20326 GOSUB 9000
20329 NEXT W4
20344 LET S$ = "}"
20346 GOSUB 9000
20349 REM ---- the nest closed
20350 LET S$ = ")"
20352 IF R4 = 1 THEN 20356
20354 LET S$ = "),)"
20356 GOSUB 9000
20358 GOTO 20500
20395 REM ---- L-cl's element body: block { tmp d = r's element, tmp g = k's, tmp f = bin mod g d,
20396 REM tmp h = lib idiv g d (rule 36's imodf, idivf, both always computed), the est of f and
20397 REM of h when kept }, every node at the lib's position P
20400 GOSUB 9115
20402 FOR K8 = 1 TO 2
20404 LET Q0 = 100 + 25 * K8
20406 LET S$ = "L a,= q"
20408 IF V(Q0 + 6) = 0 THEN 20416
20410 LET S$ = "L x,L K,eld P %e %u 0,= q"
20412 IF R4 = 1 THEN 20416
20414 LET S$ = "L x,L K,L s,wbin P 3 mul,L L,L j,wbin P 3 mul,wbin P 3 add,eld P %e %u 0,= q"
20416 GOSUB 9000
20418 NEXT K8
20420 LET V(30) = V(134)
20422 LET V(33) = V(159)
20424 LET K8 = 0
20426 LET S$ = "L g,L d,bin P 3 mod,= f,L g,L d,lib P 3 idiv 2,= h"
20428 GOSUB 9000
20430 FOR W4 = 1 TO 2
20432 IF V(1800 + W4) = 0 THEN 20442
20434 LET V(22) = V(1700 + W4)
20436 LET S$ = SEG$("L f,L h,", 4 * W4 - 3, 4 * W4)
20438 GOSUB 20966
20440 GOSUB 20980
20441 GOSUB 9000
20442 NEXT W4
20444 LET S$ = "}"
20446 GOTO 20346
20495 REM ---- step (5): the value (k = 1: lv R1, the xblk closed) or the holder's statement forms
20500 IF L6 > 0 THEN 20510
20502 LET V(21) = V(1801)
20504 LET S$ = "L U,]"
20506 GOSUB 9000
20508 GOTO 20590
20509 REM a tbind: its kept locals bound from the Rj, in place (the block's n grows)
20510 IF L6 <> 21 THEN 20540
20512 FOR W4 = 1 TO L5
20514 IF V(1800 + W4) = 0 THEN 20530
20516 LET V(21) = V(1800 + W4)
20518 LET S$ = "L U"
20520 GOSUB 9000
20522 LET R2 = H(X, 6)
20524 LET F9 = 3 + W4
20526 GOSUB 8440
20527 LET Z$ = "bind " & P9$ & " " & F9$
20528 GOSUB 8050
20530 NEXT W4
20532 LET H(W(X), 5) = H(W(X), 5) + M(Z0, 1) - 1
20534 LET Z0 = Z0 - 1
20536 GOTO 20590
20539 REM a tret: ret P k of the Rj, then the block closed
20540 IF L6 <> 31 THEN 20554
20542 FOR W4 = 1 TO L5
20544 LET V(21) = V(1800 + W4)
20546 LET S$ = "L U"
20548 GOSUB 9000
20550 NEXT W4
20551 LET Z$ = "ret " & P9$ & " " & STR$(L5)
20552 GOSUB 8050
20554 IF L6 <> 24 THEN 20584
20555 REM a tasg: each target's rows back at the tail, then its store of Rj by its cv (22000)
20556 LET X3 = H(X, 3)
20558 LET W4 = 1
20560 LET P4 = O(H(X3, 8), 0)
20562 IF H(X3, 1) <> 18 THEN 20568
20564 LET N7 = N7 - 1
20566 GOTO 20578
20568 LET O(O9, 0) = G7
20570 LET O9 = H(X3, 8)
20572 LET O(O9, 0) = 0
20574 LET W3 = V(1800 + W4)
20576 GOSUB 22000
20578 LET G7 = P4
20580 LET X3 = H(X3, 4)
20581 LET W4 = W4 + 1
20582 IF H(X3, 4) > 0 THEN 20560
20584 LET K8 = 0
20586 LET S$ = "}"
20588 GOSUB 9000
20590 LET N7 = N7 - 1
20592 GOTO 5190
20895 REM ---- 20900: the emap X validated (DESIGN 2.11.4): its instance (the same ty and n, n = np
20896 REM of F, F of kind elem); each argument of the instance's type, of an elemental parameter
20897 REM (bool, i64, f64) that type or an array of it, of a uniform one exactly its type; at least
20898 REM one argument of an elemental parameter is an array. H(X,5) = F
20900 LET R2 = H(X, 6)
20901 LET F9 = 4
20902 GOSUB 8440
20903 LET Z1$ = "inst " & F9$ & " "
20904 LET R2 = 0
20905 LET R2 = R2 + 1
20906 IF R2 > D0 THEN 2900
20907 IF SEG$(D$(R2), 1, LEN(Z1$)) <> Z1$ THEN 20905
20908 LET R3 = R2
20909 LET F9 = 3
20910 GOSUB 8440
20911 LET Y1 = VAL(F9$)
20912 IF Y1 > G0 THEN 2900
20913 LET F9 = 4
20914 GOSUB 8440
20915 LET Z1$ = F9$
20916 LET F9 = 5
20917 GOSUB 8440
20918 LET Z2$ = F9$
20919 LET R2 = H(X, 6)
20920 LET F9 = 3
20921 GOSUB 8440
20922 IF F9$ <> Z1$ THEN 2900
20923 LET F9 = 5
20924 GOSUB 8440
20925 IF F9$ <> Z2$ THEN 2900
20926 IF VAL(F9$) <> G(Y1, 2) THEN 2900
20927 LET R2 = G(Y1, 6)
20928 LET F9 = 4
20929 GOTO 21800
20930 REM ---- 20930: J9 = the number of targets of the tasg X (its children but the last)
20931 LET J9 = 0
20932 LET X3 = H(X, 3)
20933 IF H(X3, 4) = 0 THEN 20937
20934 LET J9 = J9 + 1
20935 LET X3 = H(X3, 4)
20936 GOTO 20933
20937 RETURN
20954 REM ---- 20955: F9$ = the n of the ttuple record of type Y6 (R2 its row)
20955 LET R2 = 0
20956 LET R2 = R2 + 1
20957 IF R2 > D0 THEN 2900
20958 IF SEG$(D$(R2), 1, 8 + LEN(STR$(Y6))) <> "ttuple " & STR$(Y6) & " " THEN 20956
20959 LET F9 = 3
20960 GOTO 8440
20964 REM ---- 20966: U1 = the type of result W4 of the node's type Y6 (k = 1: Y6 itself; else the
20965 REM component W4 of the ttuple Y6, its record's field 3 + W4)
20966 LET U1 = Y6
20967 IF L5 = 1 THEN 20975
20968 IF W4 > 2 THEN 20970
20969 LET U1 = T(Y6, 2 + W4)
20970 IF W4 <= 2 THEN 20975
20971 GOSUB 20955
20972 LET F9 = 3 + W4
20973 GOSUB 8440
20974 LET U1 = VAL(F9$)
20975 RETURN
20978 REM ---- 20980: S$ & the store est P size 0 of the element value into V at the position (U1
20979 REM the result's array type)
20980 LET Z1$ = "L V,L K,"
20982 IF R4 = 1 THEN 20985
20984 LET Z1$ = "L V,L K,L L,L R,wbin P 3 mul,wbin P 3 add,"
20985 LET E5 = T(U1, 2)
20986 GOSUB 8730
20987 LET S$ = S$ & Z1$ & "est P " & STR$(V5) & " 0"
20988 RETURN
20998 REM ==== 21000: rule 22 (2)-(6) (DESIGN 3.5.9 L7) over the slots 1 ... N4: under L19 (A3 = 1)
20999 REM the homes and data of the kept results and the nest opened; else (A3 = 0) L7 of the
21000 REM scalar operation Z6$ into the result type T6, the result Q; then K8 = 0
21002 IF A3 = 1 THEN 21014
21004 LET Y7 = T6
21006 GOSUB 8700
21008 LET R4 = R5
21010 LET F4 = F5
21011 GOSUB 8730
21012 LET V(58) = V5
21013 LET V(53) = T6
21014 LET K9 = 0
21016 LET Z8 = 0
21018 LET Z7 = 0
21020 REM (2) the extents of the array operands (of a fixed-size result only the matrices')
21022 FOR K8 = 1 TO N4
21024 LET Q0 = 100 + 25 * K8
21026 LET Y7 = U(V(Q0 + 1), 1)
21028 GOSUB 8700
21030 IF V(Q0 + 22) = 0 THEN 21034
21032 LET R5 = 0
21034 LET V(Q0 + 6) = R5
21036 IF R5 = 0 THEN 21058
21038 LET V(Q0 + 4) = E5
21040 GOSUB 8730
21042 LET V(Q0 + 13) = V5
21044 IF K9 > 0 THEN 21048
21046 LET K9 = K8
21048 LET S$ = "X a 0,= n"
21050 IF R5 = 1 THEN 21054
21052 LET S$ = "X a 0,= r,X a 1,= c"
21054 IF F4 = 0 THEN 21057
21056 IF R5 = 1 THEN 21058
21057 GOSUB 9000
21058 NEXT K8
21060 IF K9 = 0 THEN 2900
21062 REM the checks of a dynamic result, folded left to right (G, or R and C, the shape so far)
21064 IF F4 = 1 THEN 21110
21066 LET Q0 = 100 + 25 * K9
21068 LET V(7) = V(Q0 + 8)
21070 LET V(18) = V(Q0 + 10)
21072 LET V(3) = V(Q0 + 3)
21074 FOR K8 = K9 + 1 TO N4
21076 IF V(100 + 25 * K8 + 6) = 0 THEN 21100
21078 IF R4 = 2 THEN 21090
21080 LET S$ = "L G,L n,bin P 2 ne,= S,"
21082 IF Z8 = 1 THEN 21086
21084 LET S$ = S$ & "ci P 3 %6,= Z,"
21086 LET S$ = S$ & "L S,L G,L Z,L n,L Z,chk P SHAPE_MISMATCH 4"
21088 LET Z8 = 1
21089 GOTO 21098
21090 GOSUB 21290
21092 LET S$ = S$ & "L R,L r,bin P 2 eq,B A,L R,L O,bin P 2 eq,= B,L r,L O,bin P 2 eq,= E,L A,L A,L B,bin P 2 bor"
21094 LET S$ = S$ & ",asg P set,L A,L A,L E,bin P 2 bor,asg P set,L C,L c,bin P 2 eq,B F,L C,L O,bin P 2 eq,= H"
21095 LET S$ = S$ & ",L c,L O,bin P 2 eq,= J,L F,L F,L H,bin P 2 bor,asg P set,L F,L F,L J,bin P 2 bor,asg P set"
21096 LET S$ = S$ & ",L A,L A,L F,bin P 2 band,asg P set,L A,un P 2 not,= S,L S,L R,L C,L r,L c,chk P SHAPE_MISMATCH 4"
21098 GOSUB 21280
21100 NEXT K8
21102 GOTO 21120
21105 REM (3) a fixed-size result: its home, then its extents
21110 LET S$ = "anew P %0 0 0,= Q,X Q 0,= G"
21112 IF R4 = 1 THEN 21130
21114 LET S$ = "anew P %0 0 0,= Q,X Q 0,= R,X Q 1,= C"
21116 GOTO 21130
21120 LET S$ = "L G,anew P %0 0 1,= Q"
21122 IF R4 = 1 THEN 21130
21124 LET S$ = "L R,L C,anew P %0 0 2,= Q"
21130 LET K8 = 0
21132 IF A3 = 0 THEN 21136
21134 GOSUB 21400
21135 GOTO 21138
21136 GOSUB 9000
21138 IF R4 = 1 THEN 21152
21139 REM (4) the strides of the matrix operands
21140 FOR K8 = 1 TO N4
21142 IF V(100 + 25 * K8 + 6) = 0 THEN 21148
21144 GOSUB 21290
21145 LET S$ = S$ & "L r,L O,bin P 2 ne,= s,L c,L O,bin P 2 ne,= t,L t,L r,wbin P 3 mul,= j"
21146 GOSUB 9000
21148 NEXT K8
21151 REM (5) the data of the result (under L19 of the kept homes) and of the array operands
21152 LET K8 = 0
21154 IF A3 = 0 THEN 21158
21156 GOSUB 21450
21157 GOTO 21160
21158 LET S$ = "D Q,= D"
21159 GOSUB 9000
21160 FOR K8 = 1 TO N4
21162 IF V(100 + 25 * K8 + 6) = 0 THEN 21166
21164 LET S$ = "D a,= x"
21165 GOSUB 9000
21166 NEXT K8
21167 REM (6) the loop nest (under L19 its body is the caller's) and its body
21168 LET K8 = 0
21170 LET S$ = "( G K"
21172 IF R4 = 1 THEN 21176
21174 LET S$ = "( C L,( R K"
21176 GOSUB 9000
21178 IF A3 = 1 THEN 21220
21180 FOR K8 = 1 TO N4
21182 LET Q0 = 100 + 25 * K8
21184 LET S$ = "L a"
21186 IF V(Q0 + 6) = 0 THEN 21192
21188 LET S$ = "L x,L K,eld P %e %u 0"
21190 IF R4 = 1 THEN 21192
21191 LET S$ = "L x,L K,L s,wbin P 3 mul,L L,L j,wbin P 3 mul,wbin P 3 add,eld P %e %u 0"
21192 GOSUB 9000
21194 NEXT K8
21196 LET Z$ = Z6$
21198 GOSUB 8050
21200 LET K8 = 0
21202 LET S$ = "L D,L K,est P %5 0,)"
21204 IF R4 = 1 THEN 21208
21206 LET S$ = "L D,L K,L L,L R,wbin P 3 mul,wbin P 3 add,est P %5 0,),)"
21208 GOSUB 9000
21220 RETURN
21278 REM ---- 21280: S$ run, then the combined shape (R, C) := (where(R = 1, r, R), where(C = 1, c, C))
21280 GOSUB 9000
21281 IF R4 = 1 THEN 21284
21282 LET S$ = "L R,L O,bin P 2 eq,L r,L R,lib P 3 where 3,= R,L C,L O,bin P 2 eq,L c,L C,lib P 3 where 3,= C"
21283 GOSUB 9000
21284 RETURN
21288 REM ---- 21290: S$ = "tmp O = ci 1," at its first use, else empty
21290 LET S$ = ""
21291 IF Z7 = 1 THEN 21294
21292 LET S$ = "C 1,= O,"
21293 LET Z7 = 1
21294 RETURN
21395 REM ---- 21400 (3) under L19: the home of each kept result (its type in %0), then of a fixed-size
21396 REM broadcast its extents: the first kept home's, or with none the static ones (L-do)
21400 LET U9 = 0
21402 FOR W4 = 1 TO L5
21404 IF V(1800 + W4) = 0 THEN 21424
21406 GOSUB 20966
21408 LET V(53) = U1
21410 LET S$ = "anew P %0 0 0,= U"
21412 IF F4 = 1 THEN 21418
21414 LET S$ = "L G,anew P %0 0 1,= U"
21416 IF R4 = 1 THEN 21418
21417 LET S$ = "L R,L C,anew P %0 0 2,= U"
21418 GOSUB 9000
21420 LET V(1800 + W4) = V(21)
21422 IF U9 > 0 THEN 21424
21423 LET U9 = W4
21424 NEXT W4
21426 IF F4 = 0 THEN 21446
21428 IF U9 = 0 THEN 21440
21430 LET V(21) = V(1800 + U9)
21432 LET S$ = "X U 0,= G"
21434 IF R4 = 1 THEN 9000
21436 LET S$ = "X U 0,= R,X U 1,= C"
21438 GOTO 9000
21440 LET S$ = "C " & STR$(G4) & ",= G"
21442 IF R4 = 1 THEN 9000
21444 LET S$ = "C " & STR$(G4) & ",= R,C " & STR$(L0) & ",= C"
21445 GOTO 9000
21446 RETURN
21448 REM ---- 21450 (5) under L19: the data of each kept result (V(1700 + j))
21450 FOR W4 = 1 TO L5
21452 IF V(1800 + W4) = 0 THEN 21458
21454 LET V(21) = V(1800 + W4)
21455 LET S$ = "D U,= V"
21456 GOSUB 9000
21457 LET V(1700 + W4) = V(22)
21458 NEXT W4
21460 RETURN
21795 REM ---- 21800: 20900's checks of F's kind and of each argument X1 against its parameter
21800 GOSUB 8440
21801 IF F9$ <> "elem" THEN 2900
21802 LET J9 = 0
21803 LET X1 = H(X, 3)
21804 FOR Y4 = 1 TO G(Y1, 2)
21805 LET R2 = R3
21806 LET F9 = 5 + Y4
21807 GOSUB 8440
21808 LET Y7 = H(X1, 2)
21809 IF VAL(F9$) <> Y7 THEN 2900
21810 LET N5 = A(G(Y1, 1) + Y4)
21811 IF Y7 = N5 THEN 21820
21812 IF N5 < 2 THEN 2900
21813 IF N5 > 4 THEN 2900
21814 IF Y7 <= 9 THEN 2900
21815 IF T(Y7, 1) = 0 THEN 2900
21816 IF T(Y7, 2) <> N5 THEN 2900
21818 LET J9 = 1
21820 LET X1 = H(X1, 4)
21822 NEXT Y4
21824 IF J9 = 0 THEN 2900
21826 LET H(X, 5) = Y1
21828 RETURN
21995 REM ==== 22000: the store of result W4 (the home W3, script name T) into the target X3 (its
21996 REM rows at the tail) by its cv W6 (rule 15 (j), as sealoop's L12 converts it), written at P9$
21997 REM as asg P set: 0 none; 1 cvt f64 (L7 of the array into the target's type T8, with 4 the
21998 REM fix's shape check first: tmp A); 2 dyn (L10: the fixed home copied into a new array); 4 fix
21999 REM (L10: the shape checked, the array copied into a new home)
22000 LET R2 = H(X, 6)
22002 LET F9 = 3 + W4
22004 GOSUB 8440
22006 LET W6 = VAL(F9$)
22008 LET C9 = O9
22010 LET T8 = H(X3, 2)
22012 LET V(20) = W3
22014 LET K8 = 0
22016 LET S$ = "L T,asg P set"
22018 IF W6 = 0 THEN 9000
22020 LET S$ = "L T,cvt P 4,asg P set"
22022 IF U(W3, 1) <= 9 THEN 9000
22024 IF W6 - 2 * INT(W6 / 2) = 1 THEN 22040
22026 IF W6 = 2 THEN 22080
22028 IF W6 = 4 THEN 22100
22030 GOTO 2900
22039 REM the cvt of an array: L7 into the target's type (with a fix: tmp A, its shape check first)
22040 GOSUB 9115
22042 LET T6 = T8
22044 IF W6 < 4 THEN 22056
22046 LET Y7 = T8
22048 GOSUB 8700
22050 GOSUB 22200
22052 LET S$ = "L T,= A," & S$
22054 GOSUB 9000
22055 LET V(20) = V(1)
22056 LET K8 = 1
22058 LET V(147) = 0
22060 LET S$ = "L T,= a"
22062 GOSUB 9000
22064 LET N4 = 1
22066 LET T6 = T8
22068 LET Z6$ = "cvt " & P9$ & " 4"
22070 GOSUB 21000
22072 LET S$ = "L Q,],asg P set"
22074 GOTO 9000
22079 REM dyn (L10) of the fixed-size home (tmp S) into the dynamic target type
22080 GOSUB 9115
22082 LET Y7 = U(W3, 1)
22084 GOSUB 8700
22086 LET V(53) = T8
22088 LET S$ = "L T,= S,X S 0,= R,L R,anew P %0 0 1,= A"
22090 IF R5 = 1 THEN 22094
22092 LET S$ = "L T,= S,X S 0,= R,X S 1,= C,L R,L C,anew P %0 0 2,= A"
22094 GOSUB 8730
22095 LET S$ = S$ & ",D A,= D,C " & STR$(B5) & ",= K,L D,D S,L K,mcpy P,L A,],asg P set"
22096 GOTO 9000
22099 REM fix (L10) of the dynamic home (tmp A) into the fixed-size target type, its shape checked
22100 GOSUB 9115
22102 LET T6 = T8
22104 LET Y7 = T8
22106 GOSUB 8700
22108 LET V(53) = T8
22110 GOSUB 22200
22112 LET S$ = "L T,= A," & S$
22114 GOSUB 8730
22116 LET S$ = S$ & ",anew P %0 0 0,= V,D A,= D,C " & STR$(B5) & ",= K,D V,L D,L K,mcpy P,L V,],asg P set"
22118 GOTO 9000
22195 REM ---- 22200: S$ = the shape check of fix: the extents of A (rank R5) against those of T6
22200 LET S$ = "X A 0,= R,C " & STR$(T(T6, 0)) & ",= E,L R,L E,bin P 2 ne,= S,ci P 3 %6,= Z,L S,L E,L Z,L R,L Z"
22202 IF R5 = 1 THEN 22208
22204 LET S$ = "X A 0,= R,X A 1,= C,C " & STR$(T(T6, 0)) & ",= E,C " & STR$(T(T6, 4)) & ",= F,L R,L E,bin P 2 ne,= G"
22206 LET S$ = S$ & ",L C,L F,bin P 2 ne,= H,L G,L H,bin P 2 bor,= S,L S,L E,L F,L R,L C"
22208 LET S$ = S$ & ",chk P SHAPE_EXPECTED 4"
22210 RETURN
