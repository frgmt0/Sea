10000 REM ====================================================================================
10005 REM sealoop part 2 (lines 10000-14999): (C) numbering and writing sea.hirl (DESIGN 3.5.9).
10010 REM The new locals of a function F get the lids after its np + nl in the order of their
10015 REM declaring records (tmp, bind, hloop) in the output, named .l1 .l2 ...; U(.,5) lists them
10020 REM in that order, G(F,5) its first entry. The tptr types get the ids after the last of
10025 REM sea.hir's table in order of first reference in the file: the loc record of a tmp of an
10030 REM adat comes before every other reference (its function's loc records precede its body).
10035 REM Then the header, the records in list order (the tptr records before the first fn; a fn
10040 REM record with nl + its new locals, their loc records after its own), and #end.
10045 REM ====================================================================================
10050 LET U5 = 0
10055 LET F0 = 0
10060 LET J = O(0, 0)
10065 IF J = 0 THEN 10165
10070 IF O(J, 1) = 0 THEN 10095
10075 IF R(P(O(J, 1), 0), 0) <> 33 THEN 10155
10080 LET F0 = P(O(J, 1), 1)
10085 LET G(F0, 5) = U5 + 1
10090 GOTO 10155
10095 REM a generated record: tmp, bind or hloop of @p declares the new local p
10100 LET Z1$ = O$(J)
10105 LET J3 = POS(Z1$, " ")
10110 IF POS("|tmp|bind|hloop|", "|" & SEG$(Z1$, 1, J3 - 1) & "|") = 0 THEN 10155
10115 LET J3 = LEN(Z1$)
10120 IF SEG$(Z1$, J3, J3) = " " THEN 10135
10125 LET J3 = J3 - 1
10130 GOTO 10120
10135 IF SEG$(Z1$, J3 + 1, J3 + 1) <> "@" THEN 10155
10140 LET V1 = VAL(SEG$(Z1$, J3 + 2, LEN(Z1$)))
10145 LET U5 = U5 + 1
10147 LET U(U5, 5) = V1
10150 LET U(V1, 4) = G(F0, 2) + G(F0, 3) + U5 - G(F0, 5) + 1
10155 LET J = O(J, 0)
10160 GOTO 10065
10165 IF U5 = U0 THEN 10175
10170 CALL "dg_bug": P$, "a new local has no declaring record"
10175 REM the tptr ids, in the order of the new locals (file order)
10180 LET Y8 = Y9
10185 FOR K5 = 1 TO U5
10190 LET V1 = U(K5, 5)
10195 IF U(V1, 1) >= 0 THEN 10215
10200 IF Y(-U(V1, 1)) <> 1 THEN 10215
10205 LET Y9 = Y9 + 1
10210 LET Y(-U(V1, 1)) = Y9
10215 NEXT K5
10220 FOR E3 = 2 TO 4
10225 IF Y(E3) <> 1 THEN 10235
10230 CALL "dg_bug": P$, "a tptr type is the type of no local"
10235 NEXT E3
10240 REM ---- writing --------------------------------------------------------------------------------
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
10525 LET Z$ = STR$(Y(-U(V1, 1)))
10530 LET Z1$ = "let"
10535 IF U(V1, 2) = 0 THEN 10545
10540 LET Z1$ = "for"
10545 LET R2 = U(V1, 3)
10550 GOSUB 8400
10555 CALL "io_put": 2, "loc .l" & STR$(K5) & " " & Z$ & " " & Z1$ & " " & P9$
10558 NEXT K5
10560 RETURN
10595 REM ---- 10600: the tptr records, in id order -----------------------------------------------------
10600 FOR K5 = Y8 + 1 TO Y9
10605 FOR E3 = 2 TO 4
10610 IF Y(E3) <> K5 THEN 10620
10615 CALL "io_put": 2, "tptr " & STR$(K5) & " " & STR$(E3)
10620 NEXT E3
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
10795 REM ---- 10800: Z$ = the generated record of row J, @p and ^e replaced by the lid and the tptr id --
10800 LET Z1$ = O$(J)
10805 LET Z$ = ""
10810 LET J3 = 1
10815 LET J4 = POS(Z1$, " ", J3)
10820 IF J4 > 0 THEN 10830
10825 LET J4 = LEN(Z1$) + 1
10830 LET Z2$ = SEG$(Z1$, J3, J4 - 1)
10835 IF SEG$(Z2$, 1, 1) <> "@" THEN 10845
10840 LET Z2$ = STR$(U(VAL(SEG$(Z2$, 2, LEN(Z2$))), 4))
10845 IF SEG$(Z2$, 1, 1) <> "^" THEN 10855
10850 LET Z2$ = STR$(Y(VAL(SEG$(Z2$, 2, LEN(Z2$)))))
10855 IF J3 = 1 THEN 10870
10860 LET Z$ = Z$ & " " & Z2$
10865 GOTO 10875
10870 LET Z$ = Z2$
10875 LET J3 = J4 + 1
10880 IF J4 <= LEN(Z1$) THEN 10815
10885 RETURN
