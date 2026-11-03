55000 REM ====================================================================================
55002 REM sealoop part b (lines 55000-59999): the matrix product bin matmul (DESIGN 2.13.4; 55400 R35 of the 8c libs; 55500 R36 of 9b;
55004 REM Decisions 124, 125). Entered from 5546 for every bin X of an array type (any other goes to
55006 REM L7's test at 5551): L7 never takes @. R35: a product of two dynamic f64 operands (pass 2a
55008 REM wrote a dyn where one was fixed-size) is validated and copied, sealower lowering it by
55010 REM rule 39 (MATMUL GEMV VECMAT). L21: a product of two fixed-size f64 operands is an xblk at
55012 REM P of the result type T (fixed-size when it has at most LIM_FIXED_ELEMS elements, else the
55014 REM dynamic array; a vector only when k = 0) written by the script interpreter (lp1walk 9000) in the pinned order of
55016 REM DESIGN 2.13.2 (L-iw): tmp I = a, tmp J = b (the homes, left to right), the result R (anew
55018 REM P T 0 0, or an n or r x c anew with constant extents), the data D E F of R I J, then by shape
55020 REM matrix @ vector, vector @ matrix (L13's sum8 per column, 35600) or matrix @ matrix; every
55022 REM loop is an rloop over constant bounds, an empty one (r, c = 0) not written, k = 0 storing
55024 REM cf +0. Variables: B1 B2 the operands' ranks, B3 the result's, C2 C3 C5 the extents r k c,
55026 REM C6 the fixed-size operands, B9 the result's elements. Script names (slot 0): B the true,
55028 REM C the 0, K the 1, T r - 1, V c - 1, X k - 2 (an rloop's last is its count - 1), i the
55030 REM row, v the column, z the chain index, S the running sum (the chain's first term is the
55032 REM product itself), g h the extents of a dynamic result; N the k of sum8 (its own names Z N
55033 REM H A M Q O L k W G Y a ... x are not used here); column-major: a[i,z] at i + z * r
55034 REM ====================================================================================
55040 LET R2 = H(X, 6)
55042 LET F9 = 4
55044 GOSUB 8440
55046 IF F9$ <> "matmul" THEN 5551
55048 REM ---- validation (2.13.4: R35 and L21; every other shape is a bad record)
55050 LET X2 = H(X1, 4)
55052 IF X2 = 0 THEN 2900
55054 IF H(X2, 4) <> 0 THEN 2900
55056 LET Y7 = H(X1, 2)
55058 GOSUB 8700
55060 IF R5 = 0 THEN 2900
55062 IF E5 <> 4 THEN 2900
55064 LET B1 = R5
55066 LET C6 = F5
55068 LET C2 = T(Y7, 0)
55070 LET C3 = T(Y7, 4 - 4 * (2 - R5))
55072 LET Y7 = H(X2, 2)
55074 GOSUB 8700
55076 IF R5 = 0 THEN 2900
55078 IF E5 <> 4 THEN 2900
55080 LET B2 = R5
55082 LET C6 = C6 + F5
55084 IF B1 + B2 < 3 THEN 2900
55086 LET B3 = B1 + B2 - 2
55088 LET Y7 = H(X, 2)
55090 GOSUB 8700
55092 IF R5 <> B3 THEN 2900
55094 IF E5 <> 4 THEN 2900
55096 IF C6 = 1 THEN 2900
55098 IF C6 = 2 THEN 55110
55100 REM R35: both operands and the result dynamic; copied after the children
55102 IF F5 <> 0 THEN 2900
55104 GOTO 5160
55110 REM L21: the extents r (rows of a matrix a), k (inner), c (columns of a matrix b)
55112 IF T(H(X2, 2), 0) <> C3 THEN 2900
55114 IF B1 = 2 THEN 55118
55116 LET C2 = 1
55118 LET C5 = T(H(X2, 2), 4)
55120 IF B2 = 2 THEN 55124
55122 LET C5 = 1
55124 LET B9 = C2 * C5
55126 LET Q1$ = "LIM_FIXED_ELEMS"
55128 GOSUB 1850
55130 IF B9 > Q1 THEN 55140
55132 IF F5 <> 1 THEN 2900
55134 IF T(Y7, 0) <> C2 * (B1 - 1) + C5 * (2 - B1) THEN 2900
55136 IF B3 = 1 THEN 55150
55138 IF T(Y7, 4) = C5 THEN 55150
55139 GOTO 2900
55140 REM a dynamic result: a matrix, or a vector when k = 0 (an operand has at most LIM_FIXED_ELEMS
55141 REM elements, so a vector result over that many has k = 0)
55142 IF F5 <> 0 THEN 2900
55143 IF B3 = 2 THEN 55150
55144 IF C3 <> 0 THEN 2900
55150 REM ---- the rewrite: the xblk's block, tmp I = a, tmp J = b
55152 GOSUB 8400
55154 LET V(53) = H(X, 2)
55156 GOSUB 9115
55158 LET K8 = 0
55160 LET X4 = X1
55162 LET S$ = "= I"
55164 GOSUB 8900
55166 LET X4 = X2
55168 LET S$ = "= J"
55170 GOSUB 8900
55172 LET C9 = O9
55174 REM the result R, the data D E F, the constants B C K and the last indices T V X
55176 LET S$ = "anew P %0 0 0,= R"
55177 IF F5 = 1 THEN 55182
55178 IF B3 = 2 THEN 55181
55179 LET S$ = "C " & STR$(B9) & ",= g,L g,anew P %0 0 1,= R"
55180 GOTO 55182
55181 LET S$ = "C " & STR$(C2) & ",= g,C " & STR$(C5) & ",= h,L g,L h,anew P %0 0 2,= R"
55182 IF B9 = 0 THEN 55230
55184 LET S$ = S$ & ",D R,= D,D I,= E,D J,= F,cb P 2 1,= B,C 0,= C,C 1,= K"
55186 IF B1 = 1 THEN 55190
55188 LET S$ = S$ & ",C " & STR$(C2 - 1) & ",= T"
55190 IF B2 = 1 THEN 55194
55192 LET S$ = S$ & ",C " & STR$(C5 - 1) & ",= V"
55194 IF C3 < 2 THEN 55198
55196 LET S$ = S$ & ",C " & STR$(C3 - 2) & ",= X"
55198 IF B1 = 1 THEN 55260
55200 REM matrix @ vector: R[i] = the chain of row i; matrix @ matrix: v outer, i inner, R[i,v]
55201 REM (column-major: a[i,z] at i + z * r, b[z,v] at z + v * k, R[i,v] at i + v * r)
55202 IF B2 = 2 THEN 55212
55204 LET B4$ = "C 0"
55206 LET B5$ = "L z"
55208 LET B6$ = "L i"
55210 GOTO 55220
55212 LET S$ = S$ & ",[ B C V K v"
55214 LET B4$ = "L v,C " & STR$(C3) & ",wbin P 3 mul"
55216 LET B5$ = "L z,L v,C " & STR$(C3) & ",wbin P 3 mul,wbin P 3 add"
55218 LET B6$ = "L i,L v,C " & STR$(C2) & ",wbin P 3 mul,wbin P 3 add"
55220 LET S$ = S$ & ",[ B C T K i,"
55222 GOSUB 55300
55224 LET S$ = S$ & ",L D," & B6$ & ",est P %4 0,)"
55226 IF B2 = 1 THEN 55230
55228 LET S$ = S$ & ",)"
55230 LET S$ = S$ & ",L R,]"
55232 GOSUB 9000
55234 LET N7 = N7 - 1
55236 GOTO 5180
55258 REM vector @ matrix: R[v] = sum8 over k of x[k] * A[k,v] (35600, N = k), cf +0 for k = 0
55260 LET S$ = S$ & ",[ B C V K v,"
55262 IF C3 > 0 THEN 55268
55264 LET S$ = S$ & "cf P 4 #0000000000000000"
55266 GOTO 55290
55268 LET B8$ = "^1"
55270 FOR B4 = 10 TO Y9
55272 IF T(B4, 1) <> 1 THEN 55282
55274 IF T(B4, 3) <> 1 THEN 55282
55276 IF T(B4, 2) <> 4 THEN 55282
55278 IF T(B4, 0) <> 8 THEN 55282
55280 LET B8$ = STR$(B4)
55282 NEXT B4
55284 LET B3$ = ""
55286 LET B9$ = "L E,L k,eld P 4 %4 0,L F,L k,L v,C " & STR$(C3) & ",wbin P 3 mul,wbin P 3 add,eld P 4 %4 0,bin P 4 mul,= Y"
55287 LET S$ = S$ & "C " & STR$(C3) & ",= N,"
55288 GOSUB 35600
55290 LET S$ = S$ & ",L D,L v,est P %4 0,)"
55292 GOTO 55230
55295 REM ---- 55300: S$ = S$ & the chain of row i (and column v): its value, cf +0 for k = 0 (B4$ the
55296 REM index of b's first element, B5$ that of b's element z; a's element z is i + z * r)
55300 IF C3 > 0 THEN 55306
55302 LET S$ = S$ & "cf P 4 #0000000000000000"
55304 RETURN
55306 LET S$ = S$ & "L E,L i,eld P 4 %4 0,L F," & B4$ & ",eld P 4 %4 0,bin P 4 mul,B S"
55308 IF C3 = 1 THEN 55314
55310 LET S$ = S$ & ",[ B K X K z,L S,L S,L E,L i,L z,C " & STR$(C2) & ",wbin P 3 mul,wbin P 3 add,eld P 4 %4 0,L F,"
55312 LET S$ = S$ & B5$ & ",eld P 4 %4 0,bin P 4 mul,bin P 4 add,asg P set,)"
55314 LET S$ = S$ & ",L S"
55316 RETURN
55400 REM ---- R35 for the library calls of DESIGN 2.13.4 (8c; from 5314: every lib but ind2sub and those
55401 REM of K3$ and K5$): lib lu, chol (one dynamic f64 matrix; the type 8, 9), solve (an Lu, a Chol or a
55402 REM dynamic f64 matrix, then a dynamic f64 vector or matrix; the dynamic f64 array of its rank), rcond
55403 REM (an Lu; f64), eig_sym (one or two dynamic f64 matrices; f64[]): validated and copied after its
55404 REM children (sealower's rule 39 lowers them); any other lib goes on at R36 (55500). B1 the function, C2
55405 REM the arity, B2 the child C3, B3 its kind (1 a vector, 2 a matrix, 8 9 a handle, 0 any other),
55406 REM B4 the row of the kinds child C3 of B1 may have
55410 LET B1 = POS("|lu     |chol   |solve  |rcond  |eig_sym|", "|" & SEG$(F9$ & "       ", 1, 7) & "|")
55412 IF B1 = 0 THEN 55500
55414 LET B1 = (B1 - 1) / 8 + 1
55416 LET C2 = H(X, 5)
55418 IF C2 < 1 THEN 2900
55420 IF C2 > 2 THEN 2900
55422 IF C2 = 2 THEN 55428
55424 IF B1 = 3 THEN 2900
55426 GOTO 55430
55428 IF ABS(B1 - 4) <> 1 THEN 2900
55430 LET B2 = X1
55432 LET C3 = 0
55434 LET C3 = C3 + 1
55436 LET Y7 = H(B2, 2)
55438 GOSUB 8700
55440 LET B3 = Y7
55442 IF ABS(Y7 - 8.5) < 1 THEN 55454
55444 LET B3 = 0
55446 IF E5 <> 4 THEN 55454
55448 IF F5 <> 0 THEN 55454
55450 LET B3 = R5
55454 LET B4 = B1 + 3 * (C3 - 1) * (1 - SGN(ABS(B1 - 3)))
55456 IF POS(SEG$("2  2  2898  2  12 ", 3 * B4 - 2, 3 * B4), STR$(B3)) = 0 THEN 2900
55458 LET B2 = H(B2, 4)
55460 IF C3 < C2 THEN 55434
55462 REM the type: Lu, Chol, the dynamic f64 array of B's rank, f64, the dynamic f64 vector
55464 LET Y7 = H(X, 2)
55466 GOSUB 8700
55468 ON B1 GOTO 55470, 55470, 55474, 55478, 55480
55470 IF Y7 <> B1 + 7 THEN 2900
55472 GOTO 5160
55474 IF R5 <> B3 THEN 2900
55476 GOTO 55482
55478 IF Y7 <> 4 THEN 2900
55479 GOTO 5160
55480 IF R5 <> 1 THEN 2900
55482 IF E5 <> 4 THEN 2900
55484 IF F5 <> 0 THEN 2900
55486 GOTO 5160
55500 REM ---- R36 (9b, DESIGN 2.14.4): a lib of the 21 plotting calls stays in sea.hirl with its children
55501 REM rewritten: a child of an array type must be a dynamic f64 vector or matrix or a dynamic str
55502 REM vector (R10 materialized it: no unrewritten array expression, the check R35 makes); scalar and
55503 REM handle children are any expression, their classes sealower's (L-jj); copied after its children.
55504 REM Any other lib goes on at 5324. B2 the child
55506 IF POS("|figure|panel|twin_y|save_svg|plot|xline|bar|barh|contour|image|xlabel|ylabel|title|legend|grid|xlim|ylim|x_ticks|y_ticks|y_reverse|axis_equal|", "|" & F9$ & "|") = 0 THEN 5324
55508 LET B2 = X1
55510 IF B2 = 0 THEN 5160
55512 LET Y7 = H(B2, 2)
55514 GOSUB 8700
55516 IF R5 = 0 THEN 55524
55518 IF F5 <> 0 THEN 2900
55520 IF E5 = 4 THEN 55524
55522 IF E5 * 10 + R5 <> 51 THEN 2900
55524 LET B2 = H(B2, 4)
55526 GOTO 55510
