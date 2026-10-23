35000 REM ====================================================================================
35002 REM sealoop part 7 (lines 35000-39999): reductions, sorting and searching (DESIGN 3.5.9,
35004 REM "What sealoop rewrites in 4f": L13, L14, R12-R16). The lib X (name F9$, first child X1)
35006 REM is validated; sort and argsort are copied (R16); every other one becomes an xblk at P
35008 REM written by the script interpreter (lp1walk 9000). Variables: B1 the code (the order of
35010 REM K5$), B2 1 for a name.dim form, B3 its d, B8 the result's element type, C2 and C6 the
35012 REM operand's element type and fixedness, C3 the second child; B1$ the name, B2$ the element
35014 REM index script, B3$ the data load of V (none in a dim: form), B4$ the extent load N, B5$
35016 REM that of isum, B8$ the type F8 (R14: ^1 appended, or the id of sea.hir's f64[8]), B9$
35018 REM the element script of sum8 (its value tmp Y). Script names: V the operand, N its length
35020 REM (a dim: form: an alias of Rr p or Cc J), D its data, k the inner induction, i the outer.
35022 REM ====================================================================================
35030 LET B1$ = F9$
35032 LET B2 = 0
35034 IF LEN(B1$) < 5 THEN 35042
35036 IF SEG$(B1$, LEN(B1$) - 3, LEN(B1$)) <> ".dim" THEN 35042
35038 LET B1$ = SEG$(B1$, 1, LEN(B1$) - 4)
35040 LET B2 = 1
35042 LET B1 = POS(K5$, "|" & B1$ & " ")
35044 IF B1 > 0 THEN 35050
35046 IF B2 = 1 THEN 2900
35048 GOTO 5314
35050 LET B1 = (B1 - 1) / 12 + 1
35052 REM name.dim only of the nine reductions; max and min of two arguments are elemental (L7)
35054 IF B2 = 0 THEN 35062
35056 IF B1 > 11 THEN 2900
35058 IF B1 = 7 THEN 2900
35060 IF B1 = 8 THEN 2900
35062 IF B1 < 5 THEN 35070
35064 IF B1 > 6 THEN 35070
35066 IF B2 = 1 THEN 35070
35068 IF H(X, 5) <> 1 THEN 5314
35070 REM ---- validation (3.5.9 "What the passes validate"; 2.6.2 "Readings fixed by 4f")
35072 LET C5 = 1 + B2
35074 IF B1 < 15 THEN 35078
35076 LET C5 = 2
35078 IF H(X, 5) <> C5 THEN 2900
35080 LET Y7 = H(X1, 2)
35082 GOSUB 8700
35084 LET C2 = E5
35086 LET C6 = F5
35088 IF R5 <> 1 + B2 THEN 2900
35090 IF B1 > 8 THEN 35098
35092 IF E5 < 3 THEN 2900
35094 IF E5 > 4 THEN 2900
35096 GOTO 35110
35098 IF B1 > 14 THEN 35104
35100 IF E5 <> 2 THEN 2900
35102 GOTO 35110
35104 IF E5 < 3 THEN 2900
35106 IF E5 > 5 THEN 2900
35108 IF F5 <> 0 THEN 2900
35110 REM the result's element type: 0 the operand's
35112 LET B8 = VAL(SEG$("0444003332233303", B1, B1))
35114 IF B8 > 0 THEN 35118
35116 LET B8 = C2
35118 LET Y7 = H(X, 2)
35120 GOSUB 8700
35122 IF E5 <> B8 THEN 2900
35124 IF B2 = 1 THEN 35140
35126 IF B1 = 12 THEN 35132
35128 IF B1 > 14 THEN 35132
35130 IF R5 = 0 THEN 35200
35131 GOTO 2900
35132 IF R5 <> 1 THEN 2900
35134 IF B1 = 15 THEN 35180
35136 IF F5 <> 0 THEN 2900
35138 IF B1 = 12 THEN 35200
35139 GOTO 35184
35140 REM a dim: form: a vector of the operand's fixedness; its second child the ci 0 or 1
35142 IF R5 <> 1 THEN 2900
35144 IF F5 <> C6 THEN 2900
35146 LET C3 = H(X1, 4)
35148 IF H(C3, 1) <> 1 THEN 2900
35150 IF H(C3, 2) <> 3 THEN 2900
35152 LET R2 = H(C3, 6)
35154 LET F9 = 4
35156 GOSUB 8440
35158 IF F9$ = "0" THEN 35164
35160 IF F9$ <> "1" THEN 2900
35162 REM d = 0: c elements (the cols, T(.,4)); d = 1: r (the rows, T(.,0))
35164 LET B3 = VAL(F9$)
35166 IF F5 = 0 THEN 35200
35168 IF T(H(X, 2), 0) <> T(H(X1, 2), 4 - 4 * B3) THEN 2900
35170 GOTO 35200
35178 REM sort: the operand's type; sort and argsort: a bool desc (R16); copied
35180 IF H(X, 2) <> H(X1, 2) THEN 2900
35184 IF H(H(X1, 4), 2) <> 2 THEN 2900
35186 GOTO 5160
35195 REM ---- the rewrite: tmp V = v (P the lib's position), then the rule's script ------------
35200 LET R2 = H(X, 6)
35202 GOSUB 8400
35204 LET V(53) = H(X, 2)
35206 LET B8$ = "^1"
35208 FOR B4 = 10 TO Y9
35210 IF T(B4, 1) <> 1 THEN 35220
35212 IF T(B4, 3) <> 1 THEN 35220
35214 IF T(B4, 2) <> 4 THEN 35220
35216 IF T(B4, 0) <> 8 THEN 35220
35218 LET B8$ = STR$(B4)
35220 NEXT B4
35222 GOSUB 9115
35224 LET K8 = 0
35226 IF B2 = 0 THEN 35236
35228 REM a dim: form: the ci d is not written
35230 LET O(H(C3, 0), 0) = O(H(C3, 8), 0)
35232 IF O9 <> H(C3, 8) THEN 35235
35233 LET O9 = H(C3, 0)
35235 LET N7 = N7 - 1
35236 LET X4 = X1
35238 LET S$ = "= V"
35240 GOSUB 8900
35242 IF B2 = 1 THEN 35260
35244 LET B2$ = "L k"
35246 LET B3$ = "D V,= D,"
35248 LET B4$ = "X V 0,= N,"
35249 LET S$ = ""
35250 GOSUB 35400
35252 LET S$ = S$ & ",]"
35254 GOSUB 9000
35256 GOTO 35300
35258 REM ---- the dim: forms: Rr p, Cc J, RES a, DR b (slot 1), D, loop(Cc; i) or loop(Rr; i)
35260 LET B3$ = ""
35262 LET B4$ = ""
35264 LET B2$ = "L k,L i,L p,wbin P 3 mul,wbin P 3 add"
35266 IF B3 = 0 THEN 35270
35268 LET B2$ = "L i,L k,L p,wbin P 3 mul,wbin P 3 add"
35270 LET K8 = 1
35272 LET S$ = "X V 0,= p,X V 1,= J," & SEG$("L J,L p,", 4 * B3 + 1, 4 * B3 + 4) & "anew P %0 0 1"
35274 IF C6 = 0 THEN 35278
35276 LET S$ = "X V 0,= p,X V 1,= J,anew P %0 0 0"
35278 LET S$ = S$ & ",= a,D a,= b,D V,= D,( " & SEG$("Jp", B3 + 1, B3 + 1) & " i"
35280 GOSUB 9000
35282 LET K8 = 0
35284 LET S5$ = SEG$("Jp", 2 - B3, 2 - B3)
35286 GOSUB 9300
35288 LET C5 = V(S5)
35290 LET S5$ = "N"
35292 GOSUB 9300
35294 LET V(S5) = C5
35296 LET S$ = "{,"
35297 GOSUB 35400
35298 LET S$ = S$ & ",]"
35299 GOSUB 9000
35300 IF B2 = 0 THEN 35310
35302 LET K8 = 1
35304 LET S$ = "= c,L c,L b,L i,est P %" & STR$(B8) & " 0,),L a,]"
35306 GOSUB 9000
35308 LET K8 = 0
35310 LET N7 = N7 - 1
35312 GOTO 5180
35395 REM ==== 35400: S$ = S$ & the rule of code B1 (the statements after tmp V, then the value) ====
35400 ON B1 GOTO 35410, 35430, 35450, 35460, 35470, 35470, 35470, 35470, 35530, 35530, 35530, 35550, 35560, 35570
35405 REM sum: f64 sum8 into the value; i64 isum, value lv R (R12 (b))
35410 IF C2 = 3 THEN 35420
35412 LET S$ = S$ & B4$
35414 GOSUB 35590
35416 GOTO 35600
35420 LET B5$ = B4$
35422 GOSUB 35650
35424 LET S$ = S$ & ",L R"
35426 RETURN
35428 REM mean: the sum into S, then S / f64(N) (an i64 sum converted first)
35430 GOSUB 35680
35432 LET S$ = S$ & ",L N,cvt P 4,= F,L S,L F,bin P 4 div"
35434 RETURN
35445 REM variance (3.5.9 L13): its tmp N, Z0 z, O1 o, MEAN into m, DEV into U, N1 f, F1 g
35450 LET S$ = S$ & B4$ & "C 0,= z,L N,L z,bin P 2 eq,cf P 4 #7FF8000000000000,{,C 1,= o,L N,L o,bin P 2 eq"
35452 LET S$ = S$ & ",cf P 4 #0000000000000000,{,"
35453 LET B4$ = ""
35454 GOSUB 35430
35455 LET S$ = S$ & ",= m,"
35456 LET B9$ = "L D," & B2$ & ",eld P 3 %3 0,= v,L v,cvt P 4,= y"
35457 IF C2 = 3 THEN 35459
35458 LET B9$ = "L D," & B2$ & ",eld P 4 %4 0,= y"
35459 GOTO 35700
35460 REM std: tmp Vr h = the xblk of variance, value lib sqrt
35462 LET S$ = S$ & "{,"
35464 GOSUB 35450
35466 LET S$ = S$ & ",],= h,L h,lib P 4 sqrt 1"
35468 RETURN
35469 REM max min argmax argmin: B5$ the comparison, B9$ the element type as a field
35470 LET B5$ = SEG$("gtltgtlt", 2 * B1 - 9, 2 * B1 - 8)
35472 LET B9$ = STR$(C2)
35474 LET S$ = S$ & B4$ & "C 0,= Z,L N,L Z,bin P 2 eq,= E,cs P 5 " & B1$ & ",= S,L E,L S,chk P EMPTY_REDUCE 1,"
35476 IF C2 = 3 THEN 35482
35478 LET S$ = S$ & "cf P 4 #7FF8000000000000"
35480 GOTO 35484
35482 LET S$ = S$ & "C 0"
35484 LET S$ = S$ & ",B R,cb P 2 0,B H,C 0,B X," & B3$ & "( N k,L D," & B2$ & ",eld P " & B9$ & " %" & B9$ & " 0,= Y,"
35486 IF C2 = 3 THEN 35492
35488 LET S$ = S$ & "L Y,lib P 2 isnan 1,= U,L U,un P 2 not,= K,L Y,L R,bin P 2 " & B5$ & ",= G,L H,un P 2 not,= h"
35490 LET S$ = S$ & ",L h,L G,bin P 2 bor,= T,L K,L T,bin P 2 band,= C"
35491 GOTO 35494
35492 LET S$ = S$ & "L Y,L R,bin P 2 " & B5$ & ",= G,L H,un P 2 not,= h,L h,L G,bin P 2 bor,= C"
35494 LET S$ = S$ & ",L R,L C,L Y,L R,lib P " & B9$ & " where 3,asg P set,L X,L C,L k,L X,lib P 3 where 3,asg P set"
35496 LET S$ = S$ & ",L H,L H,L C,bin P 2 bor,asg P set,),L " & SEG$("RRXX", B1 - 4, B1 - 4)
35498 RETURN
35525 REM nnz any all: bind R, data, N, loop { R op= the element }
35530 LET B5$ = "C 0"
35531 IF B1 = 9 THEN 35533
35532 LET B5$ = "cb P 2 " & STR$(B1 - 10)
35533 LET S$ = S$ & B5$ & ",B R," & B3$ & B4$ & "( N k,L D," & B2$ & ",eld P 2 %2 0,= B,L R,L R,L B,"
35534 LET B5$ = "wbin P 3 add"
35535 IF B1 = 9 THEN 35537
35536 LET B5$ = "bin P 2 " & SEG$("borband", 3 * B1 - 29, 4 * B1 - 37)
35537 LET S$ = S$ & B5$ & ",asg P set,),L R"
35538 RETURN
35545 REM find (L14): the count C, the result R, its data g, data(m) again h, the counter O, One o
35550 LET S$ = S$ & "X V 0,= X,C 0,B C,D V,= d,( X k,L C,L C,L d,L k,eld P 2 %2 0,wbin P 3 add,asg P set,),L C"
35552 LET S$ = S$ & ",anew P %0 0 1,= R,D R,= g,D V,= h,C 0,B O,C 1,= o,( X K,L h,L K,eld P 2 %2 0,= B,L B,?"
35554 LET S$ = S$ & ",L K,L g,L O,est P %3 0,L O,L O,L o,wbin P 3 add,asg P set,),),L R"
35556 RETURN
35558 REM find_first: R = where(B and R = -1, K, R); find_last: R = where(B, K, R)
35560 LET S$ = S$ & "X V 0,= X,C -1,B R,C -1,= U,D V,= D,( X k,L D,L k,eld P 2 %2 0,= B,L R,L U,bin P 2 eq,= u"
35562 LET S$ = S$ & ",L B,L u,bin P 2 band,= c,L R,L c,L k,L R,lib P 3 where 3,asg P set,),L R"
35564 RETURN
35570 LET S$ = S$ & "X V 0,= X,C -1,B R,D V,= D,( X k,L D,L k,eld P 2 %2 0,= B,L R,L B,L k,L R,lib P 3 where 3"
35572 LET S$ = S$ & ",asg P set,),L R"
35574 RETURN
35585 REM ---- 35590: B9$ = the element of sum (X(K) of 3.5.9: tmp Y = eld f64 D index)
35590 LET B9$ = "L D," & B2$ & ",eld P 4 %4 0,= Y"
35592 RETURN
35595 REM ---- 35600: S$ = S$ & sum8(X) (3.5.9), X(K) the script B9$ ending in its value tmp Y:
35596 REM tmp Z, then ifx (N > Z) (xblk { home H, its address A, the eight -0 stores, data, Q 7,
35597 REM O 1, L, hloop k { lane W, bind G, X, G += Y, store }, a0..a7, the add tree }) (+0)
35600 LET S$ = S$ & "C 0,= Z,L N,L Z,bin P 2 gt,{,anew P " & B8$ & " 0 0,= H,D H,= A,cf P 4 #8000000000000000,= M"
35602 FOR B4 = 0 TO 7
35604 LET S$ = S$ & ",L M,L A,C " & STR$(B4) & ",est P %4 0"
35606 NEXT B4
35608 LET S$ = S$ & "," & B3$ & "C 7,= Q,C 1,= O,L N,L O,wbin P 3 sub,= L,L Z,L L,L O,K k,L k,L Q,wbin P 3 and,= W"
35610 LET S$ = S$ & ",L A,L W,eld P 4 %4 0,B G," & B9$ & ",L G,L G,L Y,bin P 4 add,asg P set,L G,L A,L W,est P %4 0,>"
35612 FOR B4 = 0 TO 7
35614 LET S$ = S$ & ",L A,C " & STR$(B4) & ",eld P 4 %4 0,= " & SEG$("abcejlnq", B4 + 1, B4 + 1)
35616 NEXT B4
35618 LET S$ = S$ & ",L a,L b,bin P 4 add,= r,L c,L e,bin P 4 add,= s,L r,L s,bin P 4 add,= t,L j,L l,bin P 4 add,= u"
35620 LET S$ = S$ & ",L n,L q,bin P 4 add,= w,L u,L w,bin P 4 add,= x,L t,L x,bin P 4 add,],cf P 4 #0000000000000000,ifx P 4"
35622 RETURN
35645 REM ---- 35650: S$ = S$ & isum: bind R = 0, data, the extent B5$ (if not yet loaded), loop {
35646 REM R = R + the element (iaddc, the call's line) }
35650 LET S$ = S$ & "C 0,B R," & B3$ & B5$ & "( N k,L D," & B2$ & ",eld P 3 %3 0,= Y,L R,L R,L Y,bin P 3 add,asg P set,)"
35652 RETURN
35675 REM ---- 35680: S$ = S$ & the sum of mean into S (f64: tmp N, sum8; i64: isum, tmp S = f64(R))
35680 IF C2 = 3 THEN 35690
35682 LET S$ = S$ & B4$
35684 GOSUB 35590
35686 GOSUB 35600
35688 LET S$ = S$ & ",= S"
35689 RETURN
35690 LET B5$ = B4$
35692 GOSUB 35650
35694 LET S$ = S$ & ",L R,cvt P 4,= S"
35696 RETURN
35698 REM ---- 35700: variance's DEV (sum8 of (y - m)^2 into U), N1, F1, its value, the two ifx
35700 LET B9$ = B9$ & ",L y,L m,bin P 4 sub,= d,L d,L d,bin P 4 mul,= Y"
35702 GOSUB 35600
35704 LET S$ = S$ & ",= U,L N,L o,wbin P 3 sub,= f,L f,cvt P 4,= g,L U,L g,bin P 4 div,],ifx P 4,],ifx P 4"
35706 RETURN
