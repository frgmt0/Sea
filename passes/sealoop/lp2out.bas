10000 REM ====================================================================================
10005 REM sealoop part 2 (lines 10000-14999): (C) numbering and writing sea.hirl (DESIGN 3.5.9).
10010 REM The new locals of a function F get the lids after its np + nl in the order of their
10015 REM declaring records (tmp, bind, hloop; rcnt its l then its e) in the output, named .l1 .l2
10020 REM ...; U(.,5) lists them in that order, G(F,5) its first entry. The tptr types get the ids
10025 REM after the last of sea.hir's table in order of first reference in the file: a function's
10030 REM new locals (their loc records follow its own), then the ^e fields of its records. 7b: a .l local
10031 REM of sea.hirf is a new local too (8730), its tptr types renumbered so (10900-10990).
10035 REM Then the header, the records in list order (the tptr records before the first fn; a fn
10040 REM record with nl + its new locals, their loc records after its own), and #end.
10045 REM ====================================================================================
10046 IF A2 + A3 = 0 THEN 10050
10047 GOSUB 52000
10048 GOSUB 10990
10050 LET U5 = 0
10055 LET F0 = 0
10060 LET J = O(0, 0)
10065 IF J = 0 THEN 10165
10070 IF O(J, 1) = 0 THEN 10101
10075 IF R(P(O(J, 1), 0), 0) <> 33 THEN 10092
10080 LET F0 = P(O(J, 1), 1)
10085 LET G(F0, 5) = U5 + 1
10086 GOSUB 52050
10090 GOTO 10155
10091 REM a copied record: the .i it declares (52100); 7b: rewritten (10950) and scanned as a generated
10092 LET Z$ = D$(O(J, 1))
10093 GOSUB 52100
10094 IF A3 = 0 THEN 10155
10096 GOSUB 10950
10098 IF Z1$ = "" THEN 10155
10099 GOTO 10105
10100 REM a generated record: tmp, bind, tbind, hloop or rcnt declares each new local @p it names
10101 LET Z1$ = O$(J)
10102 LET Z$ = Z1$
10103 GOSUB 52100
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
10150 LET U(V1, 4) = G(F0, 2) + G(F0, 3) - G(F0, 0) + U5 - G(F0, 5) + 1
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
10186 IF O(J, 1) = 0 THEN 10203
10188 IF R(P(O(J, 1), 0), 0) <> 33 THEN 10201
10190 LET F0 = P(O(J, 1), 1)
10191 GOSUB 52050
10192 FOR K5 = G(F0, 5) TO G(F0, 5) + G(F0, 4) - 1
10194 LET E3 = -U(U(K5, 5), 1)
10196 GOSUB 10234
10198 NEXT K5
10200 GOTO 10216
10201 IF A3 = 0 THEN 10216
10202 GOSUB 10950
10203 IF O(J, 1) = 0 THEN 10205
10204 GOTO 10206
10205 LET Z1$ = O$(J)
10206 LET J3 = POS(Z1$, "^")
10207 IF J3 = 0 THEN 10216
10208 LET J4 = POS(Z1$ & " ", " ", J3)
10209 LET E3 = VAL(SEG$(Z1$, J3 + 1, J4 - 1))
10210 GOSUB 10234
10212 LET J3 = POS(Z1$, "^", J3 + 1)
10213 GOTO 10207
10216 LET J = O(J, 0)
10218 GOTO 10184
10220 FOR E3 = 1 TO Y8
10225 IF C(E3, 6) <> 1 THEN 10231
10230 CALL "dg_bug": P$, "a tptr type is referred to by no record"
10231 NEXT E3
10232 GOTO 10245
10233 REM ---- 10234: the tptr of element type E3 (1 the F8 type of R14; < 1 nothing) is numbered at
10234 REM its first reference; C(id,6) of the new id names E3 (10600)
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
10292 IF A2 + A3 > 0 THEN 52200
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
10342 GOSUB 52050
10345 LET Z$ = D$(R1)
10350 IF G(F0, 4) > 0 THEN 10700
10352 CALL "io_put": 2, Z$
10354 LET M5 = G(F0, 2) + G(F0, 3)
10356 IF M5 <> 0 THEN 10370
10358 GOSUB 10500
10360 GOTO 10370
10365 GOSUB 52300
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
10546 IF R2 < 0 THEN 10890
10550 GOSUB 8400
10555 CALL "io_put": 2, "loc .l" & STR$(K5) & " " & Z$ & " " & Z1$ & " " & P9$
10558 NEXT K5
10560 IF G(F0, 0) > 0 THEN 52400
10562 RETURN
10595 REM ---- 10600: the tptr records (and R14's F8, tfvec of f64 with n 8: element 1), in id order --
10600 FOR K5 = Y8 + 1 TO Y9
10605 LET E3 = C(K5, 6)
10610 IF E3 > 1 THEN 10615
10613 CALL "io_put": 2, "tfvec " & STR$(K5) & " 4 8"
10614 GOTO 10625
10615 CALL "io_put": 2, "tptr " & STR$(K5) & " " & STR$(E3)
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
10850 LET Z2$ = STR$(C(VAL(SEG$(Z2$, 2, LEN(Z2$))), 6))
10855 IF J3 = 1 THEN 10870
10860 LET Z$ = Z$ & " " & Z2$
10865 GOTO 10875
10870 LET Z$ = Z2$
10875 LET J3 = J4 + 1
10880 IF J4 <= LEN(Z1$) THEN 10815
10885 RETURN
10887 REM ---- 10890 (7b): the loc pos of a .l local of sea.hirf: that of its loc record -R2 (8730)
10890 LET R2 = -R2
10892 LET F9 = 5
10894 GOSUB 8440
10896 LET P9$ = F9$
10898 GOTO 10555
10899 REM ---- 10900 (7b): in the record Z$, a tptr id of sea.hirf (> A6) in its second field as ^e
10900 IF A6 = 0 THEN 10918
10902 LET J3 = POS(Z$ & " ", " ")
10904 IF POS(Y6$, "|" & SEG$(Z$, 1, J3 - 1) & "|") = 0 THEN 10918
10906 LET J4 = POS(Z$ & " ", " ", J3 + 1)
10908 LET A7 = POS(Z$ & " ", " ", J4 + 1)
10910 LET Z2$ = SEG$(Z$, J4 + 1, A7 - 1)
10912 IF POS("0123456789", SEG$(Z2$, 1, 1)) = 0 THEN 10918
10914 IF VAL(Z2$) <= A6 THEN 10918
10916 LET Z$ = SEG$(Z$, 1, J4) & "^" & STR$(T(VAL(Z2$), 2)) & SEG$(Z$, A7, LEN(Z$))
10918 RETURN
10945 REM ---- 10950 (7b): Z1$ = the copied record of row J as written (52500, 10900) before its @p
10946 REM and ^e are resolved; "" for the loc record of a .l local of sea.hirf (written by 10500)
10950 LET Z$ = D$(O(J, 1))
10952 LET Z1$ = ""
10954 IF SEG$(Z$, 1, 6) = "loc .l" THEN 10964
10956 LET V4 = 1
10958 GOSUB 52500
10960 GOSUB 10900
10962 LET Z1$ = Z$
10964 RETURN
10985 REM ---- 10990 (7b): Y6$ = |name|... of the records of sea.hirf whose second field is a ty (10900)
10990 LET Y6$ = "|"
10992 FOR I = 1 TO Z(7)
10993 IF R(I, 4) < 2 THEN 10999
10994 IF POS("|2|4|7|", "|" & STR$(R(I, 1)) & "|") = 0 THEN 10999
10996 IF F(R(I, 3) + 1, 1) <> 8 THEN 10999
10998 LET Y6$ = Y6$ & R$(I) & "|"
10999 NEXT I
11000 RETURN
