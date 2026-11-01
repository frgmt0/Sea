10000 REM ====================================================================================
10005 REM seafuse part 2 (lines 10000-14999): (C) numbering and writing sea.hirf (DESIGN 2.12.3
10010 REM rules (3), (4); 3.5.9 "Types", "Locals"). The new locals of a function F get the lids
10015 REM after its np + nl in the order of their declaring records (tmp, bind, tbind, hloop) in
10020 REM the output, named .l1 .l2 ...; U(.,5) lists them in that order, G(F,5) its first entry.
10025 REM The tptr types get the ids after the last of sea.hir's table in order of first reference
10030 REM in the file: a function's new locals (their loc records follow its own), then the ^e
10035 REM fields of its records. Then the header, the records in list order (the tptr records
10040 REM before the first fn; a fn record with nl + its new locals, their loc records after its
10045 REM own; no inst record), and #end.
10050 LET U5 = 0
10052 GOSUB 11005
10055 LET F0 = 0
10060 LET J = O(0, 0)
10065 IF J = 0 THEN 10165
10070 IF O(J, 1) = 0 THEN 10095
10075 IF R(P(O(J, 1), 0), 0) <> 33 THEN 10155
10080 LET F0 = P(O(J, 1), 1)
10085 LET G(F0, 5) = U5 + 1
10090 GOTO 10155
10095 REM a generated record: tmp, bind, tbind or hloop declares each new local @u it names
10100 LET Z1$ = O$(J)
10105 LET J3 = POS(Z1$, " ")
10110 IF POS("|tmp|bind|tbind|hloop|rcnt|", "|" & SEG$(Z1$, 1, J3 - 1) & "|") = 0 THEN 10155
10115 LET J3 = POS(Z1$, "@")
10120 IF J3 = 0 THEN 10155
10125 LET J4 = POS(Z1$, " ", J3)
10130 IF J4 > 0 THEN 10140
10135 LET J4 = LEN(Z1$) + 1
10140 LET V1 = VAL(SEG$(Z1$, J3 + 1, J4 - 1))
10145 LET U5 = U5 + 1
10147 LET U(U5, 5) = V1
10150 LET U(V1, 4) = G(F0, 2) + G(F0, 3) + U5 - G(F0, 5) + 1
10152 LET J3 = POS(Z1$, "@", J4)
10153 GOTO 10120
10155 LET J = O(J, 0)
10160 GOTO 10065
10165 IF U5 = U0 THEN 10175
10170 CALL "dg_bug": P$, "a new local has no declaring record"
10175 REM the tptr ids in order of first reference
10180 LET Y8 = Y9
10182 LET J = O(0, 0)
10184 IF J = 0 THEN 10220
10186 IF O(J, 1) = 0 THEN 10204
10188 IF R(P(O(J, 1), 0), 0) <> 33 THEN 10216
10190 LET F0 = P(O(J, 1), 1)
10192 FOR K5 = G(F0, 5) TO G(F0, 5) + G(F0, 4) - 1
10194 LET E3 = -U(U(K5, 5), 1)
10196 GOSUB 10234
10198 NEXT K5
10200 GOTO 10216
10204 LET Z1$ = O$(J)
10206 GOSUB 11070
10216 LET J = O(J, 0)
10218 GOTO 10184
10220 FOR E3 = 1 TO Y8
10225 IF C(E3, 6) <> 1 THEN 10231
10230 CALL "dg_bug": P$, "a tptr type is referred to by no record"
10231 NEXT E3
10232 GOTO 10245
10233 REM ---- 10234: the tptr of element type E3 (< 1 nothing) is numbered at its first reference;
10234 REM C(id,6) of the new id names E3 (10600)
10235 IF E3 < 1 THEN 10240
10236 IF C(E3, 6) <> 1 THEN 10240
10237 LET Y9 = Y9 + 1
10238 LET C(E3, 6) = Y9
10239 LET C(Y9, 6) = E3
10240 RETURN
10241 REM ---- writing --------------------------------------------------------------------------------
10245 SCRATCH #2
10250 CALL "io_hdr_put": 2, V8, T$, H$(), N1
10255 LET W5 = 0
10260 LET M5 = -1
10265 LET J = O(0, 0)
10270 IF J = 0 THEN 10380
10275 IF O(J, 1) = 0 THEN 10365
10280 LET R1 = O(J, 1)
10285 LET K = R(P(R1, 0), 0)
10290 IF K = 33 THEN 10320
10295 CALL "io_put": 2, D$(R1)
10300 IF K < 34 THEN 10370
10305 IF K > 35 THEN 10370
10310 REM the last par or loc record of the function: its new locals follow
10312 LET M5 = M5 - 1
10314 IF M5 <> 0 THEN 10370
10316 GOSUB 10500
10318 GOTO 10370
10320 REM fn: the tptr records first (once, after sea.hir's type table); nl counts the new locals
10325 IF W5 = 1 THEN 10340
10330 GOSUB 10600
10335 LET W5 = 1
10340 LET F0 = P(R1, 1)
10345 LET Z$ = D$(R1)
10350 IF G(F0, 4) > 0 THEN 10700
10352 CALL "io_put": 2, Z$
10354 LET M5 = G(F0, 2) + G(F0, 3)
10356 IF M5 <> 0 THEN 10370
10358 GOSUB 10500
10360 GOTO 10370
10365 GOSUB 10800
10367 CALL "io_put": 2, Z$
10370 LET J = O(J, 0)
10375 GOTO 10270
10380 IF W5 = 1 THEN 10390
10385 GOSUB 10600
10390 CALL "io_fin": 2
10395 STOP
10495 REM ---- 10500: the loc records of the new locals of function F0, in lid order --------------------
10500 IF G(F0, 4) = 0 THEN 10560
10505 FOR K5 = 1 TO G(F0, 4)
10510 LET V1 = U(G(F0, 5) + K5 - 1, 5)
10515 LET Z$ = STR$(U(V1, 1))
10520 IF U(V1, 1) > 0 THEN 10530
10525 LET Z$ = STR$(C(-U(V1, 1), 6))
10530 LET Z1$ = "let"
10535 IF U(V1, 2) = 0 THEN 10545
10540 LET Z1$ = "for"
10545 LET R2 = U(V1, 3)
10550 GOSUB 8400
10555 CALL "io_put": 2, "loc .l" & STR$(K5) & " " & Z$ & " " & Z1$ & " " & P9$
10558 NEXT K5
10560 RETURN
10595 REM ---- 10600: the tptr records, in id order (an appended F8, the pseudo element 20008, as its tfvec: D-1)
10600 FOR K5 = Y8 + 1 TO Y9
10605 IF C(K5, 6) <> 20008 THEN 10615
10610 CALL "io_put": 2, "tfvec " & STR$(K5) & " 4 8"
10612 GOTO 10625
10615 CALL "io_put": 2, "tptr " & STR$(K5) & " " & STR$(C(K5, 6))
10625 NEXT K5
10630 RETURN
10695 REM ---- 10700: the fn record Z$ with its nl field (field 7) increased by the new locals -----------
10700 LET J3 = 1
10705 FOR K5 = 2 TO 7
10710 LET J3 = POS(Z$, " ", J3) + 1
10715 NEXT K5
10720 LET J4 = POS(Z$, " ", J3)
10725 LET Z$ = SEG$(Z$, 1, J3 - 1) & STR$(G(F0, 3) + G(F0, 4)) & SEG$(Z$, J4, LEN(Z$))
10730 GOTO 10352
10795 REM ---- 10800: Z$ = the generated record of row J, @u and ^e replaced by the lid and the tptr id --
10800 LET Z1$ = O$(J)
10805 LET Z$ = ""
10807 GOSUB 11040
10810 LET J3 = 1
10812 LET P3 = 1
10815 LET J4 = POS(Z1$, " ", J3)
10820 IF J4 > 0 THEN 10830
10825 LET J4 = LEN(Z1$) + 1
10830 LET Z2$ = SEG$(Z1$, J3, J4 - 1)
10832 GOSUB 11055
10835 IF W8$ & SEG$(Z2$, 1, 1) <> "l@" THEN 10845
10840 LET Z2$ = STR$(U(VAL(SEG$(Z2$, 2, LEN(Z2$))), 4))
10845 IF W8$ & SEG$(Z2$, 1, 1) <> "t^" THEN 10855
10850 LET Z2$ = STR$(C(VAL(SEG$(Z2$, 2, LEN(Z2$))), 6))
10855 IF J3 = 1 THEN 10870
10860 LET Z$ = Z$ & " " & Z2$
10865 GOTO 10875
10870 LET Z$ = Z2$
10875 LET J3 = J4 + 1
10877 LET P3 = P3 + 1
10880 IF J4 <= LEN(Z1$) THEN 10815
10885 RETURN
11001 REM ---- 11005: W7$ = |op=c...| for each record of the sets H HF HL (passes.txt), c the code of
11002 REM each field after the opcode in order: t a ty, l a lid, . any other. A ^e (tptr) or @p (new
11003 REM local) marker is read only in a t or an l field, never inside an escaped s payload (ftext,
11004 REM cs, jkey ... may hold any ^ or @ byte, DESIGN 3.1)
11005 LET W7$ = "|"
11010 FOR I = 1 TO Z(7)
11012 IF R(I, 1) = 2 THEN 11018
11014 IF R(I, 1) = 4 THEN 11018
11016 IF R(I, 1) <> 7 THEN 11034
11018 LET W7$ = W7$ & R$(I) & "="
11020 IF R(I, 4) = 0 THEN 11032
11022 FOR K5 = R(I, 3) TO R(I, 3) + R(I, 4) - 1
11024 LET W8$ = "t"
11025 IF F(K5, 1) = 8 THEN 11030
11026 LET W8$ = "l"
11027 IF F(K5, 1) = 9 THEN 11030
11028 LET W8$ = "."
11030 LET W7$ = W7$ & W8$
11031 NEXT K5
11032 LET W7$ = W7$ & "|"
11034 NEXT I
11036 RETURN
11037 REM ---- 11040: V7$ = the field codes (11005) of the record Z1$, found by its opcode (P5 bytes);
11038 REM a record of no H HF HL kind is a bug
11040 LET P5 = POS(Z1$ & " ", " ") - 1
11042 LET P6 = POS(W7$, "|" & SEG$(Z1$, 1, P5) & "=")
11044 IF P6 > 0 THEN 11048
11046 CALL "dg_bug": P$, "a record of no kind of sea.hirf"
11048 LET V7$ = SEG$(W7$, P6 + P5 + 2, POS(W7$, "|", P6 + 1) - 1)
11050 RETURN
11052 REM ---- 11055: W8$ = the code in V7$ of field P3 of the record (1 its opcode: "."); a field past
11053 REM the last code repeats the last field (in passes.txt a repeated field, ty*n or lid?*n, is last)
11055 LET W8$ = "."
11057 IF P3 < 2 THEN 11064
11058 IF LEN(V7$) = 0 THEN 11064
11060 LET P0 = P3 - 1
11061 IF P0 <= LEN(V7$) THEN 11063
11062 LET P0 = LEN(V7$)
11063 LET W8$ = SEG$(V7$, P0, P0)
11064 RETURN
11066 REM ---- 11070: each ^e of a ty field of the record Z1$ numbered at its first reference (10234);
11067 REM a ^ in any other field is a byte of an escaped string, no reference (11005)
11070 IF POS(Z1$, "^") = 0 THEN 11090
11072 GOSUB 11040
11074 LET J3 = 1
11076 LET P3 = 1
11078 LET J4 = POS(Z1$ & " ", " ", J3)
11080 GOSUB 11055
11082 IF W8$ & SEG$(Z1$, J3, J3) <> "t^" THEN 11086
11084 LET E3 = VAL(SEG$(Z1$, J3 + 1, J4 - 1))
11085 GOSUB 10234
11086 LET J3 = J4 + 1
11087 LET P3 = P3 + 1
11088 IF J3 <= LEN(Z1$) THEN 11078
11090 RETURN
