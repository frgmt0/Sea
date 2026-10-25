87000 REM ralloc.bas: the linear-scan register allocator of DESIGN 4.9.2 (Decisions 59, 60; L-ac L-an
87003 REM L-aq); lines 87000-88999. API: API.md. Needs no module. All state lives in the caller's
87006 REM D(Z9,8): rows 1..R9 registers (col 0 the caller's class, col 8 the location), R9+b block b,
87009 REM X+1.. (X = R9+B9) scalars, 64 machine-register rows, moves. Row 0: R9 B9 Z9, highest row
87012 REM used, blocks, -, open block, loop depth. Row X+1: last call, W list, M, slots, start chain,
87015 REM save cursor, moves, steps. Register walk columns: 1 first+1, 2 last, 3 block at last,
87018 REM 4 pend*(B9+1)+depth, 5 hint A*(R9+1)+B, 6 W link / next call, 7 first call crossed (or, with
87021 REM none, -(3K+n): a result of call K, n results counted up to 2), 8 start;
87024 REM after ra_end: 1 first, 2 end, 3 start, 4 depth, 5 hint, 6 start chain, 7 save slot, 8 loc.
87027 REM Block row: 0 kind (1 loop 2 do 3 if), 1 parent, 2 open, 3 close, 4 first call, 5 ind (then
87030 REM ind referenced after), 6 step, 7 depth (then count location), 8 hidden step (then location).
87033 SUB "ra_init": D(), R9, B9, Z9, T ' records the limits; T = 1 if D(Z9,8) is too small
87036 LET T = 1
87039 IF R9 + B9 + 546 > Z9 THEN 87057
87042 LET D(0, 1) = R9
87045 LET D(0, 2) = B9
87048 LET D(0, 3) = Z9
87051 LET D(R9 + B9 + 1, 1) = -1
87054 LET T = 0
87057 SUBEND
87060 SUB "ra_tab": D(), P, C, N, K, S ' machine register P allocatable: class C, ranks N K, callee-saved S
87063 LET X = D(0, 1) + D(0, 2) + 2 + P
87066 LET D(X, 0) = C
87069 LET D(X, 1) = N
87072 LET D(X, 2) = K
87075 LET D(X, 3) = S
87078 SUBEND
87081 SUB "ra_fn": D() ' starts a function: clears the rows of the previous one (column 0 too)
87084 LET X = D(0, 1) + D(0, 2)
87087 FOR I = 1 TO D(0, 4)
87090 FOR J = 0 TO 8
87093 LET D(I, J) = 0
87096 NEXT J
87099 NEXT I
87102 LET D(0, 4) = 0
87105 LET D(0, 5) = 0
87108 LET D(0, 7) = 0
87111 LET D(0, 8) = 0
87114 FOR J = 2 TO 8
87117 LET D(X + 1, J) = 0
87120 NEXT J
87123 REM no call yet: last call -1, so every register referenced so far is in the W list
87126 LET D(X + 1, 1) = -1
87129 FOR I = 1 TO 64
87132 LET D(X + 2 + I, 4) = 0
87135 LET D(X + 2 + I, 5) = 0
87138 NEXT I
87141 SUBEND
87144 SUB "ra_par": D(), R ' parameter R, written at position 0
87147 CALL "ra_ref": D(), 0, R, 0
87150 SUBEND
87153 SUB "ra_ref": D(), K, R, W ' register R read (W = 0, position 2K) or written (W = 1, 2K+1) by record K
87156 LET R9 = D(0, 1)
87159 LET G1 = D(0, 2) + 1
87162 LET X = R9 + G1 - 1
87165 LET P = 2 * K + W
87168 LET B = D(0, 7)
87171 IF D(R, 1) <> 0 THEN 87267
87174 REM the first reference: first = last = start = P
87177 LET D(R, 1) = P + 1
87180 LET D(R, 2) = P
87183 LET D(R, 3) = B
87186 LET D(R, 4) = D(0, 8)
87189 LET D(R, 5) = 0
87192 LET D(R, 7) = 0
87195 LET D(R, 8) = P
87198 IF R <= D(0, 4) THEN 87207
87201 LET D(0, 4) = R
87204 REM Z = the outermost open loop: the interval covers it unless P is a write at its body level
87207 LET Z = 0
87210 LET Y = B
87213 IF Y = 0 THEN 87228
87216 IF D(R9 + Y, 0) = 3 THEN 87222
87219 LET Z = Y
87222 LET Y = D(R9 + Y, 1)
87225 GOTO 87213
87228 IF Z = 0 THEN 87255
87231 IF W = 0 THEN 87237
87234 IF Z = B THEN 87255
87237 LET D(R, 8) = 2 * D(R9 + Z, 2) + 1
87240 LET D(R, 4) = Z * G1 + D(0, 8)
87243 REM a call already seen in Z lies between the extended start and P: crossed
87246 IF D(R9 + Z, 4) = 0 THEN 87255
87249 LET D(R, 7) = D(R9 + Z, 4)
87252 REM into the W list (registers referenced since the last call)
87255 LET D(R, 6) = D(X + 1, 2)
87258 LET D(X + 1, 2) = R
87261 GOTO 87420
87264 REM a later reference; Q the previous one. Not in W: a call came after Q (the first is D(R,6))
87267 LET Q = D(R, 2)
87270 IF Q > 2 * D(X + 1, 1) THEN 87294
87273 LET N = D(R, 6)
87276 IF 2 * N + 1 >= P THEN 87285
87279 IF D(R, 7) > 0 THEN 87285
87282 LET D(R, 7) = N
87285 LET D(R, 6) = D(X + 1, 2)
87288 LET D(X + 1, 2) = R
87291 REM loops that closed since Q and contain Q: the outermost one Z is covered from its start
87294 LET Z = 0
87297 LET Y = D(R, 3)
87300 IF Y = 0 THEN 87318
87303 IF D(R9 + Y, 3) = 0 THEN 87318
87306 IF D(R9 + Y, 0) = 3 THEN 87312
87309 LET Z = Y
87312 LET Y = D(R9 + Y, 1)
87315 GOTO 87300
87318 IF Z = 0 THEN 87354
87321 LET O = 2 * D(R9 + Z, 2) + 1
87324 IF D(R, 8) <= O THEN 87333
87327 LET D(R, 8) = O
87330 REM every call in Z lies inside the interval: the first one is a candidate first crossing
87333 LET F = D(R9 + Z, 4)
87336 IF F = 0 THEN 87354
87339 IF D(R, 7) <= 0 THEN 87345
87342 IF F >= D(R, 7) THEN 87354
87345 LET D(R, 7) = F
87348 REM open loops opened after Q: the outermost one Z is covered to its end (pend), unless an
87351 REM open pend encloses it already
87354 LET Z = 0
87357 LET Y = B
87360 IF Y = 0 THEN 87378
87363 IF 2 * D(R9 + Y, 2) + 1 < Q THEN 87378
87366 IF D(R9 + Y, 0) = 3 THEN 87372
87369 LET Z = Y
87372 LET Y = D(R9 + Y, 1)
87375 GOTO 87360
87378 LET E = INT(D(R, 4) / G1)
87381 LET G = D(R, 4) - E * G1
87384 IF Z = 0 THEN 87399
87387 IF E = 0 THEN 87393
87390 IF D(R9 + E, 3) = 0 THEN 87399
87393 LET E = Z
87396 REM last reference, its block, the deepest loop depth
87399 LET D(R, 2) = P
87402 LET D(R, 3) = B
87405 IF D(0, 8) <= G THEN 87411
87408 LET G = D(0, 8)
87411 LET D(R, 4) = E * G1 + G
87414 REM a result of the call K while nothing is crossed: column 7 = -(3 * K + n), n the results counted
87417 REM up to 2 (ra_sv accepts a listed interval with no save slot when it is a result of its record)
87420 IF W = 0 THEN 87474
87423 IF K <> D(X + 1, 1) THEN 87453
87426 IF D(R, 7) > 0 THEN 87453
87429 LET N = -D(R, 7)
87432 LET E = INT(N / 3)
87435 IF E = K THEN 87453
87438 LET N = N - 3 * E + 1
87441 IF N <= 2 THEN 87447
87444 LET N = 2
87447 LET D(R, 7) = -(3 * K + N)
87450 REM a write of an open loop's step register: that loop gets a hidden step register
87453 LET Y = B
87456 IF Y = 0 THEN 87474
87459 IF D(R9 + Y, 0) <> 1 THEN 87468
87462 IF D(R9 + Y, 6) <> R THEN 87468
87465 LET D(R9 + Y, 8) = 1
87468 LET Y = D(R9 + Y, 1)
87471 GOTO 87456
87474 SUBEND
87477 SUB "ra_call": D(), K ' record K is a call, rcall or release (after its reads, before its writes)
87480 LET R9 = D(0, 1)
87483 LET X = R9 + D(0, 2)
87486 LET D(X + 1, 1) = K
87489 REM the first call after the last reference of every register in W is K
87492 LET R = D(X + 1, 2)
87495 IF R = 0 THEN 87510
87498 LET N = D(R, 6)
87501 LET D(R, 6) = K
87504 LET R = N
87507 GOTO 87495
87510 LET D(X + 1, 2) = 0
87513 REM the first call inside each open block (an outer block with one has all of them)
87516 LET Y = D(0, 7)
87519 IF Y = 0 THEN 87534
87522 IF D(R9 + Y, 4) <> 0 THEN 87534
87525 LET D(R9 + Y, 4) = K
87528 LET Y = D(R9 + Y, 1)
87531 GOTO 87519
87534 SUBEND
87537 SUB "ra_hint": D(), K, R, A, B ' R written by record K prefers A's register, then B's
87540 IF D(R, 1) <> 2 * K + 2 THEN 87546
87543 LET D(R, 5) = A * (D(0, 1) + 1) + B
87546 SUBEND
87549 SUB "ra_open": D(), K, B, Y, I, S ' record K opens block B of kind Y; a loop's ind I and step S
87552 LET Z = D(0, 1) + B
87555 LET D(Z, 0) = Y
87558 LET D(Z, 1) = D(0, 7)
87561 LET D(Z, 2) = K
87564 LET D(Z, 3) = 0
87567 LET D(Z, 4) = 0
87570 LET D(Z, 5) = I
87573 LET D(Z, 6) = S
87576 LET D(Z, 7) = 0
87579 LET D(Z, 8) = 0
87582 LET D(0, 5) = B
87585 LET D(0, 7) = B
87588 IF Y = 3 THEN 87597
87591 LET D(0, 8) = D(0, 8) + 1
87594 LET D(Z, 7) = D(0, 8)
87597 SUBEND
87600 SUB "ra_close": D(), K, B ' record K closes block B; a loop's closing sequence references
87603 LET Z = D(0, 1) + B
87606 IF D(Z, 0) <> 1 THEN 87624
87609 CALL "ra_ref": D(), K, D(Z, 5), 0
87612 IF D(Z, 6) = 0 THEN 87621
87615 IF D(Z, 8) <> 0 THEN 87621
87618 CALL "ra_ref": D(), K, D(Z, 6), 0
87621 CALL "ra_ref": D(), K, D(Z, 5), 1
87624 LET D(Z, 3) = K
87627 LET D(0, 7) = D(Z, 1)
87630 IF D(Z, 0) = 3 THEN 87636
87633 LET D(0, 8) = D(0, 8) - 1
87636 SUBEND
87639 SUB "ra_end": D(), M, S8, T ' M LIR registers: hidden registers, intervals, scan, slots
87642 LET T = 1
87645 LET S8 = 0
87648 IF D(0, 7) <> 0 THEN 87876
87651 LET T = 0
87654 LET R9 = D(0, 1)
87657 LET G1 = D(0, 2) + 1
87660 LET X = R9 + G1 - 1
87663 LET L = D(X + 1, 1)
87666 LET D(X + 1, 3) = M
87669 REM per loop: ind referenced after its endloop (from the last reference, before extension)
87672 FOR B = 1 TO D(0, 5)
87675 IF D(R9 + B, 0) <> 1 THEN 87690
87678 LET F = 0
87681 IF D(D(R9 + B, 5), 2) <= 2 * D(R9 + B, 3) + 1 THEN 87687
87684 LET F = 1
87687 LET D(R9 + B, 5) = F
87690 NEXT B
87693 REM the LIR registers: end = last, or the pend loop's end; a call between last and it is crossed
87696 FOR R = 1 TO M
87699 IF D(R, 1) <> 0 THEN 87708
87702 LET D(R, 3) = -1
87705 GOTO 87756
87708 LET E = INT(D(R, 4) / G1)
87711 LET U = D(R, 2)
87714 LET C = D(R, 7)
87717 IF E = 0 THEN 87738
87720 IF 2 * D(R9 + E, 3) + 1 <= U THEN 87726
87723 LET U = 2 * D(R9 + E, 3) + 1
87726 IF C > 0 THEN 87738
87729 IF D(R, 2) > 2 * L THEN 87738
87732 IF D(R, 6) >= D(R9 + E, 3) THEN 87738
87735 LET C = D(R, 6)
87738 LET D(R, 1) = D(R, 1) - 1
87741 LET D(R, 3) = D(R, 8)
87744 LET D(R, 4) = D(R, 4) - E * G1
87747 LET D(R, 2) = U
87750 LET D(R, 7) = C
87753 LET D(R, 8) = 0
87756 NEXT R
87759 REM hidden registers M+1, ... by loop: the count, then the step; above R9: a slot of its own
87762 LET H = M
87765 FOR B = 1 TO D(0, 5)
87768 LET Z = R9 + B
87771 IF D(Z, 0) <> 1 THEN 87810
87774 LET V = D(Z, 7)
87777 LET D(Z, 7) = -1
87780 LET H = H + 1
87783 IF H > R9 THEN 87792
87786 LET D(Z, 7) = H
87789 CALL "ra_hid": D(), H, Z, V
87792 IF D(Z, 8) = 0 THEN 87810
87795 LET D(Z, 8) = -1
87798 LET H = H + 1
87801 IF H > R9 THEN 87810
87804 LET D(Z, 8) = H
87807 CALL "ra_hid": D(), H, Z, V
87810 NEXT B
87813 IF H <= R9 THEN 87819
87816 LET H = R9
87819 IF H <= D(0, 4) THEN 87828
87822 LET D(0, 4) = H
87825 REM the intervals in register order, sorted by start (stable: ties by register number)
87828 LET Q = 0
87831 LET Z = 0
87834 FOR R = 1 TO H
87837 IF D(R, 3) < 0 THEN 87858
87840 LET D(R, 6) = 0
87843 IF Z = 0 THEN 87852
87846 LET D(Z, 6) = R
87849 GOTO 87855
87852 LET Q = R
87855 LET Z = R
87858 NEXT R
87861 CALL "ra_srt": D(), Q, 3, 6, Z
87864 LET D(X + 1, 5) = Z
87867 CALL "ra_scn": D()
87870 CALL "ra_slt": D(), S8
87873 CALL "ra_rew": D()
87876 SUBEND
87879 SUB "ra_hid": D(), H, Z, V ' hidden register H of the loop at block row Z, of loop depth V
87882 LET D(H, 0) = 1
87885 LET D(H, 1) = 2 * D(Z, 2) + 1
87888 LET D(H, 2) = 2 * D(Z, 3) + 1
87891 LET D(H, 3) = D(H, 1)
87894 LET D(H, 4) = V
87897 LET D(H, 5) = 0
87900 LET D(H, 7) = D(Z, 4)
87903 LET D(H, 8) = 0
87906 SUBEND
87909 SUB "ra_srt": D(), H, C, L, N ' N = the chain from H linked by column L, sorted by column C (stable)
87912 LET N = 0
87915 IF H = 0 THEN 88041
87918 LET K = 1
87921 REM bottom-up merge of runs of K elements (S. Tatham's list merge sort)
87924 LET P = H
87927 LET H = 0
87930 LET T = 0
87933 LET M = 0
87936 IF P = 0 THEN 88029
87939 LET M = M + 1
87942 LET Q = P
87945 LET P1 = 0
87948 LET P1 = P1 + 1
87951 LET Q = D(Q, L)
87954 IF Q = 0 THEN 87960
87957 IF P1 < K THEN 87948
87960 LET Q1 = K
87963 IF P1 > 0 THEN 87975
87966 IF Q1 = 0 THEN 88023
87969 IF Q = 0 THEN 88023
87972 GOTO 87996
87975 IF Q1 = 0 THEN 87984
87978 IF Q = 0 THEN 87984
87981 IF D(P, C) > D(Q, C) THEN 87996
87984 LET E = P
87987 LET P = D(P, L)
87990 LET P1 = P1 - 1
87993 GOTO 88005
87996 LET E = Q
87999 LET Q = D(Q, L)
88002 LET Q1 = Q1 - 1
88005 IF T = 0 THEN 88014
88008 LET D(T, L) = E
88011 GOTO 88017
88014 LET H = E
88017 LET T = E
88020 GOTO 87963
88023 LET P = Q
88026 GOTO 87936
88029 LET D(T, L) = 0
88032 LET K = 2 * K
88035 IF M > 1 THEN 87924
88038 LET N = H
88041 SUBEND
88044 SUB "ra_scn": D() ' the scan of DESIGN 4.9.2 over the start chain: locations in column 8
88047 LET R9 = D(0, 1)
88050 LET X = R9 + D(0, 2) + 2
88053 LET R = D(X - 1, 5)
88056 IF R = 0 THEN 88233
88059 LET S = D(R, 3)
88062 LET C = 1
88065 IF D(R, 0) <> 2 THEN 88074
88068 LET C = 2
88071 REM expire the active intervals of the class that end below S
88074 FOR P = 1 TO 64
88077 IF D(X + P, 0) <> C THEN 88089
88080 IF D(X + P, 5) = 0 THEN 88089
88083 IF D(D(X + P, 5), 2) >= S THEN 88089
88086 LET D(X + P, 5) = 0
88089 NEXT P
88092 REM the hint: A's register, then B's, if free
88095 LET A = INT(D(R, 5) / (R9 + 1))
88098 LET B = D(R, 5) - A * (R9 + 1)
88101 FOR I = 1 TO 2
88104 IF A = 0 THEN 88119
88107 LET P = D(A, 8)
88110 IF P < 1 THEN 88119
88113 IF D(X + P, 0) <> C THEN 88119
88116 IF D(X + P, 5) = 0 THEN 88218
88119 LET A = B
88122 NEXT I
88125 REM the first free register of the row (column 1 crossing no call, 2 crossing one)
88128 LET K = 1
88131 IF D(R, 7) <= 0 THEN 88137
88134 LET K = 2
88137 LET Q = 0
88140 FOR P = 1 TO 64
88143 IF D(X + P, 0) <> C THEN 88158
88146 IF D(X + P, 5) <> 0 THEN 88158
88149 IF Q = 0 THEN 88155
88152 IF D(X + P, K) >= D(X + Q, K) THEN 88158
88155 LET Q = P
88158 NEXT P
88161 LET P = Q
88164 IF P <> 0 THEN 88218
88167 REM none free: the victim has the smallest depth, then the last end, then the highest number
88170 LET V = R
88173 FOR P = 1 TO 64
88176 IF D(X + P, 0) <> C THEN 88200
88179 LET O = D(X + P, 5)
88182 IF D(O, 4) > D(V, 4) THEN 88200
88185 IF D(O, 4) < D(V, 4) THEN 88197
88188 IF D(O, 2) < D(V, 2) THEN 88200
88191 IF D(O, 2) > D(V, 2) THEN 88197
88194 IF O < V THEN 88200
88197 LET V = O
88200 NEXT P
88203 IF V <> R THEN 88212
88206 LET D(R, 8) = -1
88209 GOTO 88227
88212 LET P = D(V, 8)
88215 LET D(V, 8) = -1
88218 LET D(R, 8) = P
88221 LET D(X + P, 5) = R
88224 LET D(X + P, 4) = 1
88227 LET R = D(R, 6)
88230 GOTO 88056
88233 SUBEND
88236 SUB "ra_slt": D(), S8 ' the spill and save slots in order of first use; the loops' locations
88239 LET R9 = D(0, 1)
88242 LET X = R9 + D(0, 2) + 2
88245 REM users: spilled (first use = first reference), caller-saved and crossing (its first call)
88248 LET Q = 0
88251 LET Z = 0
88254 FOR R = 1 TO D(0, 4)
88257 IF D(R, 3) < 0 THEN 88305
88260 LET P = D(R, 8)
88263 IF P <> -1 THEN 88272
88266 LET D(R, 4) = D(R, 1)
88269 GOTO 88287
88272 IF D(R, 7) <= 0 THEN 88305
88275 IF D(X + P, 3) = 0 THEN 88284
88278 LET D(R, 7) = 0
88281 GOTO 88305
88284 LET D(R, 4) = 2 * D(R, 7)
88287 LET D(R, 5) = 0
88290 IF Z = 0 THEN 88299
88293 LET D(Z, 5) = R
88296 GOTO 88302
88299 LET Q = R
88302 LET Z = R
88305 NEXT R
88308 CALL "ra_srt": D(), Q, 4, 5, Z
88311 LET S8 = 0
88314 IF Z = 0 THEN 88344
88317 LET S8 = S8 + 1
88320 IF D(Z, 8) <> -1 THEN 88332
88323 LET D(Z, 8) = -S8
88326 LET D(Z, 7) = 0
88329 GOTO 88335
88332 LET D(Z, 7) = S8
88335 LET Z = D(Z, 5)
88338 GOTO 88314
88341 REM per loop: the count and step locations; L-aq ones (-1) get slots of their own, by block
88344 FOR B = 1 TO D(0, 5)
88347 LET Z = R9 + B
88350 IF D(Z, 0) <> 1 THEN 88380
88353 FOR J = 7 TO 8
88356 LET H = D(Z, J)
88359 IF H = 0 THEN 88377
88362 IF H > 0 THEN 88374
88365 LET S8 = S8 + 1
88368 LET D(Z, J) = -S8
88371 GOTO 88377
88374 LET D(Z, J) = D(H, 8)
88377 NEXT J
88380 NEXT B
88383 SUBEND
88386 SUB "ra_blk": D(), B, C, S, F ' loop B: count location C, hidden step location S (0 none), F
88389 LET Z = D(0, 1) + B
88392 LET C = D(Z, 7)
88395 LET S = D(Z, 8)
88398 LET F = D(Z, 5)
88401 SUBEND
88404 SUB "ra_used": D(), P, U ' U = 1 if machine register P was given to an interval
88407 LET U = D(D(0, 1) + D(0, 2) + 2 + P, 4)
88410 SUBEND
88413 SUB "ra_rew": D() ' starts a sweep: the save cursor at the head of the start chain
88416 LET X = D(0, 1) + D(0, 2) + 1
88419 LET D(X, 6) = D(X, 5)
88422 FOR P = 1 TO 64
88425 LET D(X + 1 + P, 5) = 0
88428 NEXT P
88431 SUBEND
88434 SUB "ra_sv": D(), K, N, T ' N intervals in caller-saved registers crossing record K
88437 LET X = D(0, 1) + D(0, 2) + 2
88440 LET C = D(X - 1, 6)
88443 REM the occupant of each register: the last interval on it starting at or before 2K
88446 IF C = 0 THEN 88464
88449 IF D(C, 3) > 2 * K THEN 88464
88452 IF D(C, 8) < 1 THEN 88458
88455 LET D(X + D(C, 8), 5) = C
88458 LET C = D(C, 6)
88461 GOTO 88446
88464 LET D(X - 1, 6) = C
88467 LET N = 0
88470 LET T = 0
88473 FOR P = 1 TO 64
88476 LET O = D(X + P, 5)
88479 IF O = 0 THEN 88524
88482 IF D(X + P, 3) <> 0 THEN 88524
88485 IF D(O, 2) <= 2 * K + 1 THEN 88524
88488 LET N = N + 1
88491 LET D(X + N, 6) = P
88494 LET D(X + N, 7) = D(O, 7)
88497 LET D(X + N, 8) = O
88500 IF D(O, 7) > 0 THEN 88524
88503 REM no save slot: a result of record K (or of two or more calls, not tracked further), else misuse
88506 LET D(X + N, 7) = 0
88509 LET V = -D(O, 7)
88512 LET E = INT(V / 3)
88515 IF E = K THEN 88524
88518 IF V - 3 * E >= 2 THEN 88524
88521 LET T = 1
88524 NEXT P
88527 SUBEND
88530 SUB "ra_svi": D(), I, P, S, R ' entry I of the last ra_sv list: register P, save slot S, register R
88533 LET X = D(0, 1) + D(0, 2) + 2 + I
88536 LET P = D(X, 6)
88539 LET S = D(X, 7)
88542 LET R = D(X, 8)
88545 SUBEND
88548 SUB "ra_mv": D(), S, E, C, T ' appends the move S -> E of class C; T = 1 if 320 are listed
88551 LET X = D(0, 1) + D(0, 2) + 1
88554 LET T = 1
88557 LET N = D(X, 7)
88560 IF N >= 320 THEN 88581
88563 LET N = N + 1
88566 LET D(X + 65 + N, 0) = S
88569 LET D(X + 65 + N, 1) = E
88572 LET D(X + 65 + N, 2) = C
88575 LET D(X, 7) = N
88578 LET T = 0
88581 SUBEND
88584 SUB "ra_pm": D(), N ' sequences the listed moves into N steps (three steps of DESIGN 4.9.2)
88587 LET X = D(0, 1) + D(0, 2) + 1
88590 LET Z = X + 65
88593 LET M = D(X, 7)
88596 LET D(X, 7) = 0
88599 LET N = 0
88602 REM column 7: 0 done, 1 memory destination, 2 register to register, 3 into a register from memory
88605 REM or an immediate; column 8: the current source
88608 FOR I = 1 TO M
88611 LET S = D(Z + I, 0)
88614 LET E = D(Z + I, 1)
88617 LET D(Z + I, 8) = S
88620 LET D(Z + I, 7) = 0
88623 IF S = E THEN 88647
88626 LET D(Z + I, 7) = 1
88629 IF E < 1 THEN 88647
88632 IF E > 64 THEN 88647
88635 LET D(Z + I, 7) = 3
88638 IF S < 1 THEN 88647
88641 IF S > 64 THEN 88647
88644 LET D(Z + I, 7) = 2
88647 NEXT I
88650 REM step 1: memory destinations by key: spill slot s, then 1000+j and 2000+j upwards
88653 LET B = 0
88656 FOR I = 1 TO M
88659 IF D(Z + I, 7) <> 1 THEN 88686
88662 LET E = D(Z + I, 1)
88665 LET V = 1000000 + E
88668 IF E > 0 THEN 88674
88671 LET V = -E
88674 IF B = 0 THEN 88680
88677 IF V >= W THEN 88686
88680 LET B = I
88683 LET W = V
88686 NEXT I
88689 IF B = 0 THEN 88704
88692 LET S = D(Z + B, 8)
88695 GOSUB 88815
88698 GOTO 88653
88701 REM step 2: the first register move whose destination is no remaining source; else a cycle
88704 LET A = 0
88707 FOR I = 1 TO M
88710 IF D(Z + I, 7) <> 2 THEN 88743
88713 IF A <> 0 THEN 88719
88716 LET A = I
88719 FOR J = 1 TO M
88722 IF D(Z + J, 7) <> 2 THEN 88728
88725 IF D(Z + J, 8) = D(Z + I, 1) THEN 88743
88728 NEXT J
88731 LET B = I
88734 LET S = D(Z + B, 8)
88737 GOSUB 88815
88740 GOTO 88704
88743 NEXT I
88746 IF A = 0 THEN 88791
88749 REM every remaining move is in a cycle: the first one's source into the cycle scratch (0)
88752 LET S = D(Z + A, 8)
88755 LET N = N + 1
88758 LET D(Z + N, 3) = S
88761 LET D(Z + N, 4) = 0
88764 LET D(Z + N, 5) = D(Z + A, 2)
88767 LET D(Z + N, 6) = A
88770 FOR J = 1 TO M
88773 IF D(Z + J, 7) <> 2 THEN 88782
88776 IF D(Z + J, 8) <> S THEN 88782
88779 LET D(Z + J, 8) = 0
88782 NEXT J
88785 GOTO 88704
88788 REM step 3: memory and immediate sources into registers, in destination order
88791 FOR B = 1 TO M
88794 IF D(Z + B, 7) <> 3 THEN 88803
88797 LET S = D(Z + B, 8)
88800 GOSUB 88815
88803 NEXT B
88806 LET D(X, 8) = N
88809 GOTO 88836
88812 REM emit move B from source S as the next step
88815 LET N = N + 1
88818 LET D(Z + N, 3) = S
88821 LET D(Z + N, 4) = D(Z + B, 1)
88824 LET D(Z + N, 5) = D(Z + B, 2)
88827 LET D(Z + N, 6) = B
88830 LET D(Z + B, 7) = 0
88833 RETURN
88836 SUBEND
88839 SUB "ra_st": D(), I, S, E, C, J ' step I of the last ra_pm: source S, destination E, class C, move J
88842 LET X = D(0, 1) + D(0, 2) + 66 + I
88845 LET S = D(X, 3)
88848 LET E = D(X, 4)
88851 LET C = D(X, 5)
88854 LET J = D(X, 6)
88857 SUBEND
