10 REM ====================================================================================
20 REM seaparse -- pass 1 of the Sea compiler (docs/DESIGN.md 2.1, 2.2): reads the driver's
30 REM |-tagged stream on standard input, lexes (LANGUAGE.md 3), parses the whole grammar of
40 REM LANGUAGE.md Appendix A and writes sea.ast (DESIGN 3.4) in post-order. Compile errors C1
50 REM (codes 101-114) and the pass-1 capacity limits (DESIGN 2.7) via dg_compile.
60 REM Built with the modules io diag tables limb fltlit and the DATA errors exits consts records.
70 REM Design: the lexer runs on demand (SUB lx) into a 16-token ring, so lexical errors become
80 REM ERR tokens reported when the parser reaches them (source order). The parser is recursive
90 REM descent with precedence climbing; node records are buffered (the header lists every #file,
100 REM known only at the end of the input) and written after the whole input is read.
110 REM Every parser SUB takes Z() X$() L() E() E$() F$() first (the main program's Z S$ L E E$ H$):
120 REM  Z  1 P current token number   2 Q tokens lexed   3 file index   4 line   5 column
130 REM     6 line length   7 line state (0 read next, 1 in line, 2 done, 3 record waiting)
140 REM     8 bracket depth   9 in block comment   10 comment holds a line break   11 NL pending
150 REM     12 last token continues the line (LANGUAGE 3.7 rule 2)   13 E0   14 N1 (files)
160 REM     15 nesting depth   16 header mode   17 index-list depth ($)   18 nodes   19 strings
170 REM     20 bare 2^63 literal pending   21 last expression is a target   22 last node is a call
180 REM     23 records read   40-49 FILE_VERSION and the limits NESTING PARAMS RESULTS FIELDS
190 REM     NODES STRINGS IDENT_BYTES UESC_DIGITS UESC_MAX   101-999 bracket stack (1 ( 2 [ 3 {)
200 REM     1001-1016 ring token kinds   100001-500009 string hash (DESIGN 2.7 strings limit)
210 REM  X$ 1-199999 interned strings (escaped)   200001-299999 node records
220 REM     300001-300048 ring: raw text, value, position F:L:C per slot   300100 current line
230 REM     300101 waiting record   300102 /* position   300103 its line break   300104 NL
240 REM     300105 the 2^63 literal   300106 position of a parsed primary   300107 end of file
250 REM Token kinds: 1 IDENT 2 INT 3 FLOAT 4 STRING 5 symbol (keyword, operator, _ , other byte)
260 REM 6 NL 7 EOF 8 ERR (value = the error name). INT/FLOAT values are the i/f fields, STRING
270 REM values the escaped s field (DESIGN 3.1).
280 REM ====================================================================================
290 DIM Z(500010), S$(300200), L(65536), E(299), E$(299,5), H$(100), C(299,4), C$(299)
300 DIM N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), Q(8), Y(20), Y$(20)
310 FILES "sea.ast"
320 LET P$ = "seaparse"
330 CALL "tb_errors": P$, E(), E$(), 299, E0
340 CALL "tb_exits": P$, E(), E$(), E0, Y(), Y$(), 20, N9
350 CALL "tb_consts": P$, E(), E$(), E0, C(), C$(), 299, N5
360 LET Q(1) = 39
370 LET Q(2) = 299
380 LET Q(3) = 399
390 LET Q(4) = 1499
400 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), R(), R$(), F(), F$(), Q()
410 REM the constants this pass uses, into Z(40..49)
420 LET K$ = "FILE_VERSION LIM_NESTING LIM_PARAMS LIM_RESULTS LIM_FIELDS LIM_NODES LIM_STRINGS LIM_IDENT_BYTES LIM_UESC_DIGITS LIM_UESC_MAX "
430 LET J = 1
440 FOR I = 0 TO 9
450 LET J2 = POS(K$, " ", J)
460 LET W1$ = SEG$(K$, J, J2 - 1)
470 LET J = J2 + 1
480 CALL "tb_cval": C(), C$(), N5, W1$, V, T
490 IF T = 0 THEN 510
500 CALL "dg_bug": P$, "constant " & W1$ & " is not in the consts table"
510 LET Z(40 + I) = V
520 NEXT I
530 REM the node buffer and the string table are DIMmed for the limits of DESIGN 2.7
540 IF Z(45) > 99999 THEN 560
550 IF Z(46) <= 199999 THEN 570
560 CALL "dg_bug": P$, "node or string limit larger than the pass's tables"
570 CALL "io_hdr": 0, P$, E(), E$(), E0, N(), N$(), W$(), Q(5), Z(40), T$, H$(), 100, N1, L$
580 LET Z(1) = 1
590 LET Z(13) = E0
600 LET Z(14) = N1
610 LET Z(23) = N1 + 3
620 LET Z(3) = N1 - 1
630 REM the first body record is handed to the lexer
640 LET S$(300101) = L$
650 LET Z(7) = 3
660 FOR I = 1 TO N1
670 CALL "io_esc": H$(I), 0, V$
680 CALL "pi": Z(), S$(), L(), E(), E$(), H$(), V$, STR$(I - 1) & ":1:1"
690 NEXT I
700 CALL "p_prog": Z(), S$(), L(), E(), E$(), H$(), N
710 REM the whole input is read: header (every #file), the buffered nodes, prog, #end
720 SCRATCH #1
730 CALL "io_hdr_put": 1, Z(40), T$, H$(), Z(14)
740 FOR I = 1 TO Z(18)
750 PRINT #1, S$(200000 + I)
760 NEXT I
770 PRINT #1, "prog " & STR$(N)
780 CALL "io_fin": 1
790 REM ---- lx: one lexer step (LANGUAGE 3): reads lines as needed, appends >= 1 token ----------
800 REM locals: L$ record, S token start, C D codes, J K M N U scratch, R$ raw, V$ value, P$ pos,
810 REM Q$ escape pos, B byte, H 0x flag, G float flag, W() one byte for CHANGE
820 SUB "lx": Z(), X$(), L(), E(), E$(), F$()
830 DIM W(1)
840 LET H$ = "0123456789ABCDEF"
850 IF Z(7) = 1 THEN 1370
860 IF Z(7) = 2 THEN 1250
870 IF Z(7) = 3 THEN 900
880 CALL "io_read": 0, L$, Z(23), "seaparse", E(), E$(), Z(13)
890 GOTO 920
900 LET L$ = X$(300101)
910 LET Z(7) = 0
920 IF LEN(L$) <> 4 THEN 940
930 IF L$ = "#end" THEN 1130
940 IF SEG$(L$, 1, 1) = "|" THEN 1040
950 CALL "io_file": "seaparse", E(), E$(), Z(13), L$, F$(), 100, Z(14), Y
960 IF Y = 1 THEN 990
970 CALL "dg_internal": "seaparse", "BAD_RECORD", E(), E$(), Z(13)
980 REM a new #file: an open block comment ends with its file
990 IF Z(9) = 1 THEN 1270
1000 LET Z(3) = Z(14) - 1
1010 LET Z(4) = 0
1020 LET Z(6) = 0
1030 GOTO 850
1040 LET Z(4) = Z(4) + 1
1050 LET X$(300100) = SEG$(L$, 2, LEN(L$))
1060 LET Z(6) = LEN(L$) - 1
1070 LET Z(5) = 1
1080 LET Z(7) = 1
1090 IF Z(6) = 0 THEN 850
1100 CHANGE X$(300100) TO L
1110 GOTO 850
1120 REM #end: EOF just after the last byte of the last line (DESIGN 2.6.2, at token)
1130 CALL "io_end": 0, "seaparse", E(), E$(), Z(13)
1140 IF Z(9) = 1 THEN 1270
1150 LET Z(7) = 2
1160 LET P$ = STR$(Z(3)) & ":1:1"
1170 IF Z(4) = 0 THEN 1190
1180 LET P$ = STR$(Z(3)) & ":" & STR$(Z(4)) & ":" & STR$(Z(6) + 1)
1190 LET X$(300107) = P$
1200 LET K = 7
1210 LET R$ = ""
1220 LET V$ = ""
1230 GOSUB 4270
1240 GOTO 4650
1250 LET P$ = X$(300107)
1260 GOTO 1200
1270 LET V$ = "UNTERMINATED_COMMENT"
1280 LET P$ = X$(300102)
1290 REM an ERR token (V$ = error name, P$ = its position); the lexer stops after it
1300 LET K = 8
1310 LET R$ = ""
1320 GOSUB 4270
1330 LET Z(7) = 2
1340 LET X$(300107) = P$
1350 GOTO 4650
1360 REM ---- inside a line
1370 LET C0 = Z(5)
1380 IF C0 <= Z(6) THEN 1500
1390 REM the LF that ends the line
1400 LET Z(7) = 0
1410 LET P$ = STR$(Z(3)) & ":" & STR$(Z(4)) & ":" & STR$(Z(6) + 1)
1420 IF Z(9) = 0 THEN 1480
1430 REM in a block comment: its first line break counts once, when the comment ends
1440 IF Z(10) = 1 THEN 850
1450 LET Z(10) = 1
1460 LET X$(300103) = P$
1470 GOTO 850
1480 GOSUB 4180
1490 GOTO 850
1500 IF Z(9) = 0 THEN 1620
1510 LET J = POS(X$(300100), "*/", C0)
1520 IF J > 0 THEN 1550
1530 LET Z(5) = Z(6) + 1
1540 GOTO 850
1550 LET Z(5) = J + 2
1560 LET Z(9) = 0
1570 IF Z(10) = 0 THEN 850
1580 LET Z(10) = 0
1590 LET P$ = X$(300103)
1600 GOSUB 4180
1610 GOTO 850
1620 LET C = L(C0)
1630 IF C = 32 THEN 1650
1640 IF C <> 9 THEN 1670
1650 LET Z(5) = C0 + 1
1660 GOTO 850
1670 LET S = C0
1680 LET P$ = STR$(Z(3)) & ":" & STR$(Z(4)) & ":" & STR$(S)
1690 LET D = 0
1700 IF S >= Z(6) THEN 1720
1710 LET D = L(S + 1)
1720 IF C <> 47 THEN 1830
1730 IF D <> 47 THEN 1770
1740 REM // comment: to the end of the line
1750 LET Z(5) = Z(6) + 1
1760 GOTO 850
1770 IF D <> 42 THEN 3720
1780 LET Z(9) = 1
1790 LET Z(10) = 0
1800 LET X$(300102) = P$
1810 LET Z(5) = S + 2
1820 GOTO 850
1830 IF C = 95 THEN 1940
1840 IF C < 48 THEN 1910
1850 IF C <= 57 THEN 2210
1860 IF C < 65 THEN 3720
1870 IF C <= 90 THEN 1940
1880 IF C < 97 THEN 3720
1890 IF C <= 122 THEN 1940
1900 GOTO 3720
1910 IF C = 34 THEN 2750
1920 GOTO 3720
1930 REM ---- identifier or keyword (LANGUAGE 3.3)
1940 LET J = S + 1
1950 IF J > Z(6) THEN 2060
1960 LET C = L(J)
1970 IF C = 95 THEN 2040
1980 IF C < 48 THEN 2060
1990 IF C <= 57 THEN 2040
2000 IF C < 65 THEN 2060
2010 IF C <= 90 THEN 2040
2020 IF C < 97 THEN 2060
2030 IF C > 122 THEN 2060
2040 LET J = J + 1
2050 GOTO 1950
2060 LET R$ = SEG$(X$(300100), S, J - 1)
2070 LET Z(5) = J
2080 IF J - S <= Z(47) THEN 2110
2090 LET V$ = "IDENT_TOO_LONG"
2100 GOTO 1300
2110 LET K = 5
2120 LET V$ = ""
2130 IF R$ = "_" THEN 2170
2140 IF POS(" break const continue elemental else false fn for if in let match ref return step struct true var while bool f64 i64 str ", " " & R$ & " ") > 0 THEN 2170
2150 LET K = 1
2160 LET V$ = R$
2170 GOSUB 4270
2180 GOTO 4650
2190 REM ---- numeric literal (LANGUAGE 3.4): the token is digits, letters, _, a . not before a .,
2200 REM and a sign after e/E of a decimal literal; then it is checked by LMINT or FLCVT
2210 LET J = S + 1
2220 LET H = 0
2230 LET G = 0
2240 IF C <> 48 THEN 2270
2250 IF D <> 120 THEN 2270
2260 LET H = 1
2270 IF J > Z(6) THEN 2530
2280 LET C = L(J)
2290 IF C = 46 THEN 2450
2300 IF C = 43 THEN 2490
2310 IF C = 45 THEN 2490
2320 IF C = 95 THEN 2430
2330 IF C < 48 THEN 2530
2340 IF C <= 57 THEN 2430
2350 IF C < 65 THEN 2530
2360 IF C <= 90 THEN 2390
2370 IF C < 97 THEN 2530
2380 IF C > 122 THEN 2530
2390 IF H = 1 THEN 2430
2400 IF C = 101 THEN 2420
2410 IF C <> 69 THEN 2430
2420 LET G = 1
2430 LET J = J + 1
2440 GOTO 2270
2450 IF J >= Z(6) THEN 2470
2460 IF L(J + 1) = 46 THEN 2530
2470 LET G = 1
2480 GOTO 2430
2490 IF H = 1 THEN 2530
2500 LET C = L(J - 1)
2510 IF C = 101 THEN 2430
2520 IF C = 69 THEN 2430
2530 LET R$ = SEG$(X$(300100), S, J - 1)
2540 LET Z(5) = J
2550 IF G = 1 THEN 2640
2560 CALL "LMINT": R$, A3, A2, A1, A0, T
2570 IF T = 3 THEN 2670
2580 IF T < 2 THEN 2610
2590 LET V$ = "INT_TOO_LARGE"
2600 GOTO 1300
2610 CALL "LMFMT": A3, A2, A1, A0, V$
2620 LET K = 2
2630 GOTO 2170
2640 CALL "FLCVT": R$, A3, A2, A1, A0, T
2650 IF T = 0 THEN 2710
2660 IF T = 1 THEN 2690
2670 LET V$ = "BAD_NUMBER"
2680 GOTO 1300
2690 LET V$ = "FLOAT_RANGE"
2700 GOTO 1300
2710 CALL "LMHEX": A3, A2, A1, A0, V$
2720 LET K = 3
2730 GOTO 2170
2740 REM ---- string literal (LANGUAGE 3.5): the value is built escaped (DESIGN 3.1)
2750 LET V$ = ""
2760 LET I = S + 1
2770 IF I <= Z(6) THEN 2810
2780 LET V$ = "UNTERMINATED_STRING"
2790 LET Z(5) = Z(6) + 1
2800 GOTO 1300
2810 LET C = L(I)
2820 IF C = 34 THEN 3640
2830 IF C = 92 THEN 2890
2840 LET B = C
2850 GOSUB 3930
2860 LET I = I + 1
2870 GOTO 2770
2880 REM an escape; an error is reported at its backslash
2890 LET Q$ = STR$(Z(3)) & ":" & STR$(Z(4)) & ":" & STR$(I)
2900 IF I >= Z(6) THEN 3610
2910 LET D = L(I + 1)
2920 LET I = I + 2
2930 LET B = 10
2940 IF D = 110 THEN 3070
2950 LET B = 9
2960 IF D = 116 THEN 3070
2970 LET B = 13
2980 IF D = 114 THEN 3070
2990 LET B = 0
3000 IF D = 48 THEN 3070
3010 LET B = D
3020 IF D = 34 THEN 3070
3030 IF D = 92 THEN 3070
3040 IF D = 120 THEN 3100
3050 IF D = 117 THEN 3220
3060 GOTO 3610
3070 GOSUB 3930
3080 GOTO 2770
3090 REM \xHH: exactly two hex digits
3100 IF I + 1 > Z(6) THEN 3610
3110 LET C = L(I)
3120 GOSUB 4040
3130 IF M < 0 THEN 3610
3140 LET B = M * 16
3150 LET C = L(I + 1)
3160 GOSUB 4040
3170 IF M < 0 THEN 3610
3180 LET B = B + M
3190 LET I = I + 2
3200 GOTO 3070
3210 REM \u{H...}: 1..UESC_DIGITS hex digits, at most UESC_MAX, no surrogate; then UTF-8
3220 IF I > Z(6) THEN 3610
3230 IF L(I) <> 123 THEN 3610
3240 LET I = I + 1
3250 LET N = 0
3260 LET U = 0
3270 IF I > Z(6) THEN 3610
3280 LET C = L(I)
3290 IF C = 125 THEN 3370
3300 GOSUB 4040
3310 IF M < 0 THEN 3610
3320 LET N = N + 1
3330 IF N > Z(48) THEN 3610
3340 LET U = U * 16 + M
3350 LET I = I + 1
3360 GOTO 3270
3370 LET I = I + 1
3380 IF N = 0 THEN 3610
3390 IF U > Z(49) THEN 3610
3400 IF U < 55296 THEN 3420
3410 IF U <= 57343 THEN 3610
3420 IF U >= 128 THEN 3450
3430 LET B = U
3440 GOTO 3070
3450 IF U >= 2048 THEN 3490
3460 LET B = 192 + INT(U / 64)
3470 GOSUB 3930
3480 GOTO 3590
3490 IF U >= 65536 THEN 3530
3500 LET B = 224 + INT(U / 4096)
3510 GOSUB 3930
3520 GOTO 3570
3530 LET B = 240 + INT(U / 262144)
3540 GOSUB 3930
3550 LET B = 128 + INT(U / 4096) - 64 * INT(U / 262144)
3560 GOSUB 3930
3570 LET B = 128 + INT(U / 64) - 64 * INT(U / 4096)
3580 GOSUB 3930
3590 LET B = 128 + U - 64 * INT(U / 64)
3600 GOTO 3070
3610 LET V$ = "BAD_ESCAPE"
3620 LET P$ = Q$
3630 GOTO 1300
3640 LET R$ = SEG$(X$(300100), S, I)
3650 LET Z(5) = I + 1
3660 IF LEN(V$) > 0 THEN 3680
3670 LET V$ = "%"
3680 LET K = 4
3690 GOTO 2170
3700 REM ---- operators and punctuation, longest match (LANGUAGE 3.6); another printable byte is
3710 REM a one-byte symbol that no rule accepts (unexpected token), any other byte illegal (3.1)
3720 LET N = 0
3730 IF SEG$(X$(300100), S, S + 2) <> "..=" THEN 3760
3740 LET N = 3
3750 GOTO 3870
3760 LET T$ = SEG$(X$(300100), S, S + 1)
3770 IF LEN(T$) < 2 THEN 3810
3780 IF POS(" == != <= >= && || += -= *= /= -> => .. ", " " & T$ & " ") = 0 THEN 3810
3790 LET N = 2
3800 GOTO 3870
3810 IF C < 33 THEN 3850
3820 IF C > 126 THEN 3850
3830 LET N = 1
3840 GOTO 3870
3850 LET V$ = "ILLEGAL_CHAR"
3860 GOTO 1300
3870 LET R$ = SEG$(X$(300100), S, S + N - 1)
3880 LET Z(5) = S + N
3890 LET K = 5
3900 LET V$ = ""
3910 GOTO 2170
3920 REM ---- GOSUB lxapp: append byte B to V$ in the s-field escaping of DESIGN 3.1
3930 IF B < 33 THEN 4010
3940 IF B > 126 THEN 4010
3950 IF B = 37 THEN 4010
3960 LET W(0) = 1
3970 LET W(1) = B
3980 CHANGE W TO C$
3990 LET V$ = V$ & C$
4000 RETURN
4010 LET V$ = V$ & "%" & SEG$(H$, INT(B / 16) + 1, INT(B / 16) + 1) & SEG$(H$, B - 16 * INT(B / 16) + 1, B - 16 * INT(B / 16) + 1)
4020 RETURN
4030 REM ---- GOSUB lxhex: M = value of hex digit code C, or -1
4040 LET M = -1
4050 IF C < 48 THEN 4160
4060 IF C <= 57 THEN 4130
4070 IF C < 65 THEN 4160
4080 IF C <= 70 THEN 4150
4090 IF C < 97 THEN 4160
4100 IF C > 102 THEN 4160
4110 LET M = C - 87
4120 RETURN
4130 LET M = C - 48
4140 RETURN
4150 LET M = C - 55
4160 RETURN
4170 REM ---- GOSUB lxbrk: a line break at P$ gives an NL unless rule 1 or 2 of LANGUAGE 3.7
4180 IF Z(8) = 0 THEN 4200
4190 IF Z(100 + Z(8)) <> 3 THEN 4240
4200 IF Z(12) = 1 THEN 4240
4210 IF Z(11) = 1 THEN 4240
4220 LET Z(11) = 1
4230 LET X$(300104) = P$
4240 RETURN
4250 REM ---- GOSUB lxpush: token K R$ V$ P$ into the ring, after a pending NL unless the token
4260 REM is else (rule 3; consecutive NLs are one); then rule 2 and the bracket stack
4270 IF Z(2) - Z(1) < 13 THEN 4290
4280 CALL "dg_bug": "seaparse", "token ring overflow"
4290 IF Z(11) = 0 THEN 4410
4300 LET Z(11) = 0
4310 IF K <> 5 THEN 4330
4320 IF R$ = "else" THEN 4410
4330 LET Q = Z(2) + 1
4340 LET Z(2) = Q
4350 LET J = Q - 16 * INT((Q - 1) / 16)
4360 LET Z(1000 + J) = 6
4370 LET J = 300000 + 3 * (J - 1)
4380 LET X$(J + 1) = ""
4390 LET X$(J + 2) = ""
4400 LET X$(J + 3) = X$(300104)
4410 LET Q = Z(2) + 1
4420 LET Z(2) = Q
4430 LET J = Q - 16 * INT((Q - 1) / 16)
4440 LET Z(1000 + J) = K
4450 LET J = 300000 + 3 * (J - 1)
4460 LET X$(J + 1) = R$
4470 LET X$(J + 2) = V$
4480 LET X$(J + 3) = P$
4490 LET Z(12) = 0
4500 IF K <> 5 THEN 4640
4510 IF POS(" + - * / % ^ @ == != < <= > >= ! & | && || = += -= *= /= , : . .. ..= -> => ( [ { step ", " " & R$ & " ") = 0 THEN 4530
4520 LET Z(12) = 1
4530 IF LEN(R$) <> 1 THEN 4640
4540 LET J = POS("([{)]}", R$)
4550 IF J = 0 THEN 4640
4560 IF J > 3 THEN 4620
4570 LET Z(8) = Z(8) + 1
4580 IF Z(8) < 900 THEN 4600
4590 CALL "dg_bug": "seaparse", "bracket stack overflow"
4600 LET Z(100 + Z(8)) = J
4610 GOTO 4640
4620 IF Z(8) = 0 THEN 4640
4630 LET Z(8) = Z(8) - 1
4640 RETURN
4650 SUBEND
4660 REM ---- pt: token N ahead (1 = current): kind K, raw text T$, ring base B ------------------
4670 REM (value X$(B + 2), position X$(B + 3))
4680 SUB "pt": Z(), X$(), L(), E(), E$(), F$(), N, K, T$, B
4690 IF Z(2) >= Z(1) + N - 1 THEN 4720
4700 CALL "lx": Z(), X$(), L(), E(), E$(), F$()
4710 GOTO 4690
4720 LET I = Z(1) + N - 1
4730 LET J = I - 16 * INT((I - 1) / 16)
4740 LET K = Z(1000 + J)
4750 LET B = 300000 + 3 * (J - 1)
4760 LET T$ = X$(B + 1)
4770 SUBEND
4780 REM ---- pl / ps: skip NL tokens / separators (NL and ;) ---------------------------------
4790 SUB "pl": Z(), X$(), L(), E(), E$(), F$()
4800 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
4810 IF K <> 6 THEN 4840
4820 LET Z(1) = Z(1) + 1
4830 GOTO 4800
4840 SUBEND
4850 SUB "ps": Z(), X$(), L(), E(), E$(), F$()
4860 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
4870 IF K = 6 THEN 4890
4880 IF T$ <> ";" THEN 4910
4890 LET Z(1) = Z(1) + 1
4900 GOTO 4860
4910 SUBEND
4920 REM ---- pc: compile error Q$ at position P$ with substitution A1$ ("" = none) ------------
4930 SUB "pc": Z(), X$(), L(), E(), E$(), F$(), Q$, P$, A1$
4940 DIM A$(1)
4950 CALL "io_pos": P$, F, L1, C, T
4960 LET N = 0
4970 IF LEN(A1$) = 0 THEN 5000
4980 LET A$(1) = A1$
4990 LET N = 1
5000 CALL "dg_compile": "seaparse", F$(), Z(14), F, L1, C, Q$, A$(), N, E(), E$(), Z(13)
5010 SUBEND
5020 REM ---- pe: the token of kind K at ring base B is not allowed here (113, 114, 112, or the
5030 REM lexical error an ERR token carries)
5040 SUB "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
5050 LET P$ = X$(B + 3)
5060 IF K = 6 THEN 5100
5070 IF K = 7 THEN 5110
5080 IF K = 8 THEN 5120
5090 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "UNEXPECTED_TOKEN", P$, X$(B + 1)
5100 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "UNEXPECTED_NEWLINE", P$, ""
5110 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "UNEXPECTED_EOF", P$, ""
5120 LET Q$ = X$(B + 2)
5130 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), Q$, P$, ""
5140 SUBEND
5150 REM ---- px: the current token must be the symbol S$; consume it ---------------------------
5160 SUB "px": Z(), X$(), L(), E(), E$(), F$(), S$
5170 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
5180 IF K <> 5 THEN 5200
5190 IF T$ = S$ THEN 5210
5200 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
5210 LET Z(1) = Z(1) + 1
5220 SUBEND
5230 REM ---- pn: open a nesting level at P$ (DESIGN 2.7: depth 65 is program too large) -------
5240 SUB "pn": Z(), X$(), L(), E(), E$(), F$(), P$
5250 LET Z(15) = Z(15) + 1
5260 IF Z(15) <= Z(41) THEN 5280
5270 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "TOO_LARGE", P$, "nesting"
5280 SUBEND
5290 REM ---- pi: count the escaped string V$ among the distinct strings (hash table in Z) -----
5300 REM locals: N length, H hash, I J index
5310 SUB "pi": Z(), X$(), L(), E(), E$(), F$(), V$, P$
5320 LET N = LEN(V$)
5330 LET H = N
5340 LET J = N
5350 IF J <= 24 THEN 5370
5360 LET J = 24
5370 FOR I = 1 TO J
5380 LET H = H * 31 + ASC(SEG$(V$, I, I))
5390 LET H = H - 400009 * INT(H / 400009)
5400 NEXT I
5410 IF N <= 24 THEN 5470
5420 FOR I = N - 23 TO N
5430 LET H = H * 31 + ASC(SEG$(V$, I, I))
5440 LET H = H - 400009 * INT(H / 400009)
5450 NEXT I
5460 REM escaped strings hold no blank, so = compares them exactly
5470 LET I = Z(100001 + H)
5480 IF I = 0 THEN 5550
5490 IF LEN(X$(I)) <> N THEN 5510
5500 IF X$(I) = V$ THEN 5610
5510 LET H = H + 1
5520 IF H < 400009 THEN 5470
5530 LET H = 0
5540 GOTO 5470
5550 LET I = Z(19) + 1
5560 IF I <= Z(46) THEN 5580
5570 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "TOO_LARGE", P$, "strings"
5580 LET Z(19) = I
5590 LET X$(I) = V$
5600 LET Z(100001 + H) = I
5610 SUBEND
5620 REM ---- pw: buffer the node record O$ P$ [S$] [R$] (DESIGN 3.4); counts nodes -------------
5630 SUB "pw": Z(), X$(), L(), E(), E$(), F$(), O$, P$, S$, R$
5640 REM a 2^63 literal is legal only directly under neg (LANGUAGE 3.4); the parser checks each
5650 REM place first, this is the last line of defence
5660 IF Z(20) = 0 THEN 5690
5670 IF O$ = "neg" THEN 5690
5680 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "INT_TOO_LARGE", X$(300105), ""
5690 LET N = Z(18) + 1
5700 IF N <= Z(45) THEN 5720
5710 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "TOO_LARGE", P$, "nodes"
5720 LET Z(18) = N
5730 LET W$ = O$ & " " & P$
5740 IF LEN(S$) = 0 THEN 5760
5750 LET W$ = W$ & " " & S$
5760 IF LEN(R$) = 0 THEN 5780
5770 LET W$ = W$ & " " & R$
5780 LET X$(200000 + N) = W$
5790 LET Z(21) = 0
5800 LET Z(22) = 0
5810 IF O$ <> "call" THEN 5830
5820 LET Z(22) = 1
5830 SUBEND
5840 REM ---- pd: the current token must be an identifier: V$ name, P$ position; consume -------
5850 SUB "pd": Z(), X$(), L(), E(), E$(), F$(), V$, P$
5860 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
5870 IF K = 1 THEN 5890
5880 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
5890 LET V$ = X$(B + 2)
5900 LET P$ = X$(B + 3)
5910 CALL "pi": Z(), X$(), L(), E(), E$(), F$(), V$, P$
5920 LET Z(1) = Z(1) + 1
5930 SUBEND
5940 REM ---- p_prog: program = nl { item sep } [ item ] nl EOF; N = number of items ---------
5950 SUB "p_prog": Z(), X$(), L(), E(), E$(), F$(), N
5960 LET N = 0
5970 CALL "pl": Z(), X$(), L(), E(), E$(), F$()
5980 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
5990 IF K = 7 THEN 6090
6000 CALL "p_item": Z(), X$(), L(), E(), E$(), F$()
6010 LET N = N + 1
6020 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
6030 IF K = 7 THEN 6090
6040 IF K = 6 THEN 6070
6050 IF T$ = ";" THEN 6070
6060 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
6070 CALL "ps": Z(), X$(), L(), E(), E$(), F$()
6080 GOTO 5980
6090 SUBEND
6100 REM ---- p_item: const, struct, fn or a statement --------------------------------------
6110 SUB "p_item": Z(), X$(), L(), E(), E$(), F$()
6120 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
6130 IF K <> 5 THEN 6180
6140 IF T$ = "const" THEN 6200
6150 IF T$ = "struct" THEN 6220
6160 IF T$ = "fn" THEN 6240
6170 IF T$ = "elemental" THEN 6240
6180 CALL "p_stmt": Z(), X$(), L(), E(), E$(), F$()
6190 GOTO 6250
6200 CALL "p_const": Z(), X$(), L(), E(), E$(), F$()
6210 GOTO 6250
6220 CALL "p_struct": Z(), X$(), L(), E(), E$(), F$()
6230 GOTO 6250
6240 CALL "p_fn": Z(), X$(), L(), E(), E$(), F$()
6250 SUBEND
6260 REM ---- p_const: const IDENT [ : type ] = expr -----------------------------------------
6270 SUB "p_const": Z(), X$(), L(), E(), E$(), F$()
6280 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
6290 LET P$ = X$(B + 3)
6300 LET Z(1) = Z(1) + 1
6310 CALL "pd": Z(), X$(), L(), E(), E$(), F$(), V$, Q$
6320 LET T = 0
6330 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
6340 IF T$ <> ":" THEN 6380
6350 LET Z(1) = Z(1) + 1
6360 CALL "p_type": Z(), X$(), L(), E(), E$(), F$()
6370 LET T = 1
6380 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "="
6390 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
6400 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "const", P$, V$, STR$(T)
6410 SUBEND
6420 REM ---- p_struct: struct IDENT { nl [ field { ( sep | , nl ) field } [ , ] ] nl } --------
6430 REM locals: N fields, M a ; among the separators (then a field must follow)
6440 SUB "p_struct": Z(), X$(), L(), E(), E$(), F$()
6450 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
6460 LET P$ = X$(B + 3)
6470 LET Z(1) = Z(1) + 1
6480 CALL "pd": Z(), X$(), L(), E(), E$(), F$(), V$, Q$
6490 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "{"
6500 CALL "pl": Z(), X$(), L(), E(), E$(), F$()
6510 LET N = 0
6520 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
6530 IF T$ = "}" THEN 6810
6540 IF N < Z(44) THEN 6570
6550 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
6560 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "TOO_LARGE", X$(B + 3), "fields"
6570 CALL "pd": Z(), X$(), L(), E(), E$(), F$(), W$, Q$
6580 CALL "px": Z(), X$(), L(), E(), E$(), F$(), ":"
6590 CALL "p_type": Z(), X$(), L(), E(), E$(), F$()
6600 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "field", Q$, W$, ""
6610 LET N = N + 1
6620 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
6630 IF T$ = "}" THEN 6810
6640 IF T$ <> "," THEN 6680
6650 LET Z(1) = Z(1) + 1
6660 CALL "pl": Z(), X$(), L(), E(), E$(), F$()
6670 GOTO 6520
6680 LET M = 0
6690 IF K = 6 THEN 6720
6700 IF T$ = ";" THEN 6720
6710 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
6720 IF K = 6 THEN 6740
6730 LET M = 1
6740 LET Z(1) = Z(1) + 1
6750 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
6760 IF K = 6 THEN 6720
6770 IF T$ = ";" THEN 6720
6780 IF T$ <> "}" THEN 6540
6790 IF M = 0 THEN 6810
6800 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
6810 LET Z(1) = Z(1) + 1
6820 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "struct", P$, V$, STR$(N)
6830 SUBEND
6840 REM ---- p_fn: [ elemental ] fn IDENT ( params ) [ -> result ] block --------------------
6850 REM locals: E1 elemental, N parameters, M results
6860 SUB "p_fn": Z(), X$(), L(), E(), E$(), F$()
6870 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
6880 LET P$ = X$(B + 3)
6890 LET E1 = 0
6900 IF T$ <> "elemental" THEN 6950
6910 LET E1 = 1
6920 LET Z(1) = Z(1) + 1
6930 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "fn"
6940 GOTO 6960
6950 LET Z(1) = Z(1) + 1
6960 CALL "pd": Z(), X$(), L(), E(), E$(), F$(), V$, Q$
6970 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "("
6980 LET N = 0
6990 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
7000 IF T$ = ")" THEN 7110
7010 IF N < Z(42) THEN 7030
7020 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "TOO_LARGE", X$(B + 3), "parameters"
7030 CALL "p_param": Z(), X$(), L(), E(), E$(), F$()
7040 LET N = N + 1
7050 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
7060 IF T$ = ")" THEN 7110
7070 IF T$ = "," THEN 7090
7080 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
7090 LET Z(1) = Z(1) + 1
7100 GOTO 6990
7110 LET Z(1) = Z(1) + 1
7120 LET M = 0
7130 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
7140 IF T$ <> "->" THEN 7360
7150 LET Z(1) = Z(1) + 1
7160 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
7170 IF T$ = "(" THEN 7220
7180 CALL "p_type": Z(), X$(), L(), E(), E$(), F$()
7190 LET M = 1
7200 GOTO 7360
7210 REM a tuple result: ( type , type { , type } )
7220 LET Z(1) = Z(1) + 1
7230 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
7240 IF M < Z(43) THEN 7260
7250 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "TOO_LARGE", X$(B + 3), "results"
7260 CALL "p_type": Z(), X$(), L(), E(), E$(), F$()
7270 LET M = M + 1
7280 IF M > 1 THEN 7310
7290 CALL "px": Z(), X$(), L(), E(), E$(), F$(), ","
7300 GOTO 7230
7310 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
7320 IF T$ <> "," THEN 7350
7330 LET Z(1) = Z(1) + 1
7340 GOTO 7230
7350 CALL "px": Z(), X$(), L(), E(), E$(), F$(), ")"
7360 CALL "p_block": Z(), X$(), L(), E(), E$(), F$()
7370 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "fn", P$, V$, STR$(E1) & " " & STR$(N) & " " & STR$(M)
7380 SUBEND
7390 REM ---- p_param: [ ref ] IDENT : type [ = expr ] -----------------------------------------
7400 SUB "p_param": Z(), X$(), L(), E(), E$(), F$()
7410 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
7420 LET P$ = X$(B + 3)
7430 LET R = 0
7440 IF T$ <> "ref" THEN 7470
7450 LET R = 1
7460 LET Z(1) = Z(1) + 1
7470 CALL "pd": Z(), X$(), L(), E(), E$(), F$(), V$, Q$
7480 CALL "px": Z(), X$(), L(), E(), E$(), F$(), ":"
7490 CALL "p_type": Z(), X$(), L(), E(), E$(), F$()
7500 LET D = 0
7510 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
7520 IF T$ <> "=" THEN 7560
7530 LET Z(1) = Z(1) + 1
7540 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
7550 LET D = 1
7560 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "param", P$, V$, STR$(R) & " " & STR$(D)
7570 SUBEND
7580 REM ---- p_type: base_type [ shape ] (Appendix A); dims are int or name nodes -------------
7590 SUB "p_type": Z(), X$(), L(), E(), E$(), F$()
7600 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
7610 IF K = 1 THEN 7670
7620 IF T$ = "f64" THEN 7670
7630 IF T$ = "i64" THEN 7670
7640 IF T$ = "bool" THEN 7670
7650 IF T$ = "str" THEN 7670
7660 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
7670 LET V$ = T$
7680 LET P$ = X$(B + 3)
7690 CALL "pi": Z(), X$(), L(), E(), E$(), F$(), V$, P$
7700 LET Z(1) = Z(1) + 1
7710 LET S$ = "s"
7720 LET N = 0
7730 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
7740 IF T$ <> "[" THEN 7950
7750 LET Z(1) = Z(1) + 1
7760 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
7770 LET S$ = "v"
7780 IF T$ = "]" THEN 7940
7790 LET S$ = "m"
7800 IF T$ <> "," THEN 7830
7810 LET Z(1) = Z(1) + 1
7820 GOTO 7920
7830 CALL "p_dim": Z(), X$(), L(), E(), E$(), F$()
7840 LET N = 1
7850 LET S$ = "fv"
7860 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
7870 IF T$ <> "," THEN 7920
7880 LET Z(1) = Z(1) + 1
7890 CALL "p_dim": Z(), X$(), L(), E(), E$(), F$()
7900 LET N = 2
7910 LET S$ = "fm"
7920 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "]"
7930 GOTO 7950
7940 LET Z(1) = Z(1) + 1
7950 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "type", P$, V$, S$ & " " & STR$(N)
7960 SUBEND
7970 REM ---- p_dim: dim = INT | IDENT ---------------------------------------------------------
7980 SUB "p_dim": Z(), X$(), L(), E(), E$(), F$()
7990 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
8000 IF K = 2 THEN 8040
8010 CALL "pd": Z(), X$(), L(), E(), E$(), F$(), V$, P$
8020 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "name", P$, V$, ""
8030 GOTO 8100
8040 LET V$ = X$(B + 2)
8050 LET P$ = X$(B + 3)
8060 IF V$ <> "#8000000000000000" THEN 8080
8070 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "INT_TOO_LARGE", P$, ""
8080 LET Z(1) = Z(1) + 1
8090 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "int", P$, "", V$
8100 SUBEND
8110 REM ---- p_block: { nl [ statement { sep statement } ] [ sep ] } ------------------------
8120 SUB "p_block": Z(), X$(), L(), E(), E$(), F$()
8130 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
8140 IF T$ = "{" THEN 8160
8150 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
8160 LET P$ = X$(B + 3)
8170 CALL "pn": Z(), X$(), L(), E(), E$(), F$(), P$
8180 LET Z(1) = Z(1) + 1
8190 CALL "pl": Z(), X$(), L(), E(), E$(), F$()
8200 LET N = 0
8210 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
8220 IF T$ = "}" THEN 8330
8230 CALL "p_stmt": Z(), X$(), L(), E(), E$(), F$()
8240 LET N = N + 1
8250 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
8260 IF T$ = "}" THEN 8330
8270 IF K = 6 THEN 8300
8280 IF T$ = ";" THEN 8300
8290 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
8300 CALL "ps": Z(), X$(), L(), E(), E$(), F$()
8310 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
8320 IF T$ <> "}" THEN 8230
8330 LET Z(1) = Z(1) + 1
8340 LET Z(15) = Z(15) - 1
8350 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "block", P$, "", STR$(N)
8360 SUBEND
8370 REM ---- p_stmt: one statement (Appendix A statement) ----------------------------------
8380 SUB "p_stmt": Z(), X$(), L(), E(), E$(), F$()
8390 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
8400 IF K <> 5 THEN 8720
8410 IF T$ = "let" THEN 8560
8420 IF T$ = "var" THEN 8560
8430 IF T$ = "if" THEN 8580
8440 IF T$ = "while" THEN 8600
8450 IF T$ = "for" THEN 8620
8460 IF T$ = "match" THEN 8640
8470 IF T$ = "return" THEN 8660
8480 IF T$ = "{" THEN 8680
8490 IF T$ = "(" THEN 8700
8500 IF T$ = "break" THEN 8520
8510 IF T$ <> "continue" THEN 8720
8520 LET O$ = T$
8530 LET Z(1) = Z(1) + 1
8540 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), O$, X$(B + 3), "", ""
8550 GOTO 8730
8560 CALL "p_let": Z(), X$(), L(), E(), E$(), F$()
8570 GOTO 8730
8580 CALL "p_if": Z(), X$(), L(), E(), E$(), F$()
8590 GOTO 8730
8600 CALL "p_while": Z(), X$(), L(), E(), E$(), F$()
8610 GOTO 8730
8620 CALL "p_for": Z(), X$(), L(), E(), E$(), F$()
8630 GOTO 8730
8640 CALL "p_match": Z(), X$(), L(), E(), E$(), F$()
8650 GOTO 8730
8660 CALL "p_return": Z(), X$(), L(), E(), E$(), F$()
8670 GOTO 8730
8680 CALL "p_block": Z(), X$(), L(), E(), E$(), F$()
8690 GOTO 8730
8700 CALL "p_tasg": Z(), X$(), L(), E(), E$(), F$()
8710 GOTO 8730
8720 CALL "p_exst": Z(), X$(), L(), E(), E$(), F$()
8730 SUBEND
8740 REM ---- p_exst: assignment (a target, then = += -= *= /=) or a call statement; any other
8750 REM expression is expression statement has no effect, at the statement (LANGUAGE 7.1)
8760 SUB "p_exst": Z(), X$(), L(), E(), E$(), F$()
8770 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
8780 LET P$ = X$(B + 3)
8790 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
8800 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
8810 IF Z(21) = 0 THEN 8970
8820 IF K <> 5 THEN 8970
8830 LET O$ = "set"
8840 IF T$ = "=" THEN 8930
8850 LET O$ = "add"
8860 IF T$ = "+=" THEN 8930
8870 LET O$ = "sub"
8880 IF T$ = "-=" THEN 8930
8890 LET O$ = "mul"
8900 IF T$ = "*=" THEN 8930
8910 LET O$ = "div"
8920 IF T$ <> "/=" THEN 8970
8930 LET Z(1) = Z(1) + 1
8940 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
8950 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "asg", P$, "", O$
8960 GOTO 9000
8970 IF Z(22) = 1 THEN 8990
8980 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "NO_EFFECT", P$, ""
8990 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "cstmt", P$, "", ""
9000 SUBEND
9010 REM ---- p_let: let/var pattern [ : type ] = expr ---------------------------------------
9020 SUB "p_let": Z(), X$(), L(), E(), E$(), F$()
9030 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
9040 LET O$ = T$
9050 LET P$ = X$(B + 3)
9060 LET Z(1) = Z(1) + 1
9070 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
9080 IF T$ = "(" THEN 9120
9090 CALL "p_pel": Z(), X$(), L(), E(), E$(), F$()
9100 GOTO 9260
9110 REM ( pat_elem , pat_elem { , pat_elem } )
9120 LET Q$ = X$(B + 3)
9130 LET Z(1) = Z(1) + 1
9140 LET N = 0
9150 CALL "p_pel": Z(), X$(), L(), E(), E$(), F$()
9160 LET N = N + 1
9170 IF N > 1 THEN 9200
9180 CALL "px": Z(), X$(), L(), E(), E$(), F$(), ","
9190 GOTO 9150
9200 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
9210 IF T$ <> "," THEN 9240
9220 LET Z(1) = Z(1) + 1
9230 GOTO 9150
9240 CALL "px": Z(), X$(), L(), E(), E$(), F$(), ")"
9250 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "ptuple", Q$, "", STR$(N)
9260 LET T = 0
9270 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
9280 IF T$ <> ":" THEN 9320
9290 LET Z(1) = Z(1) + 1
9300 CALL "p_type": Z(), X$(), L(), E(), E$(), F$()
9310 LET T = 1
9320 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "="
9330 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
9340 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), O$, P$, "", STR$(T)
9350 SUBEND
9360 REM ---- p_pel: IDENT (pname) or _ (pskip) ------------------------------------------------
9370 SUB "p_pel": Z(), X$(), L(), E(), E$(), F$()
9380 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
9390 IF T$ = "_" THEN 9430
9400 CALL "pd": Z(), X$(), L(), E(), E$(), F$(), V$, P$
9410 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "pname", P$, V$, ""
9420 GOTO 9460
9430 LET P$ = X$(B + 3)
9440 LET Z(1) = Z(1) + 1
9450 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "pskip", P$, "", ""
9460 SUBEND
9470 REM ---- p_tasg: ( tgt_elem , tgt_elem { , tgt_elem } ) = expr --------------------------
9480 SUB "p_tasg": Z(), X$(), L(), E(), E$(), F$()
9490 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
9500 LET P$ = X$(B + 3)
9510 LET Z(1) = Z(1) + 1
9520 LET N = 0
9530 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
9540 IF T$ <> "_" THEN 9570
9550 CALL "p_pel": Z(), X$(), L(), E(), E$(), F$()
9560 GOTO 9580
9570 CALL "p_tgt": Z(), X$(), L(), E(), E$(), F$()
9580 LET N = N + 1
9590 IF N > 1 THEN 9620
9600 CALL "px": Z(), X$(), L(), E(), E$(), F$(), ","
9610 GOTO 9530
9620 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
9630 IF T$ <> "," THEN 9660
9640 LET Z(1) = Z(1) + 1
9650 GOTO 9530
9660 CALL "px": Z(), X$(), L(), E(), E$(), F$(), ")"
9670 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "="
9680 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
9690 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "tasg", P$, "", STR$(N)
9700 SUBEND
9710 REM ---- p_tgt: target = IDENT { [ index_list ] | . IDENT } ------------------------------
9720 SUB "p_tgt": Z(), X$(), L(), E(), E$(), F$()
9730 CALL "pd": Z(), X$(), L(), E(), E$(), F$(), V$, P$
9740 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "name", P$, V$, ""
9750 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
9760 IF T$ = "[" THEN 9820
9770 IF T$ <> "." THEN 9840
9780 LET Z(1) = Z(1) + 1
9790 CALL "pd": Z(), X$(), L(), E(), E$(), F$(), W$, Q$
9800 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "dot", P$, W$, ""
9810 GOTO 9750
9820 CALL "p_ix": Z(), X$(), L(), E(), E$(), F$(), P$
9830 GOTO 9750
9840 SUBEND
9850 REM ---- p_if: if head block { else if head block } [ else block ]; the chain is parsed
9860 REM iteratively and its if nodes written innermost first (A$ holds their positions)
9870 SUB "p_if": Z(), X$(), L(), E(), E$(), F$()
9880 LET C = 0
9890 LET A$ = ""
9900 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
9910 LET A$ = X$(B + 3) & " " & A$
9920 LET Z(1) = Z(1) + 1
9930 CALL "p_head": Z(), X$(), L(), E(), E$(), F$()
9940 CALL "p_block": Z(), X$(), L(), E(), E$(), F$()
9950 LET C = C + 1
9960 LET E1 = 0
9970 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
9980 IF T$ <> "else" THEN 10040
9990 LET Z(1) = Z(1) + 1
10000 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
10010 IF T$ = "if" THEN 9900
10020 CALL "p_block": Z(), X$(), L(), E(), E$(), F$()
10030 LET E1 = 1
10040 FOR I = 1 TO C
10050 LET J = POS(A$, " ")
10060 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "if", SEG$(A$, 1, J - 1), "", STR$(E1)
10070 LET A$ = SEG$(A$, J + 1, LEN(A$))
10080 LET E1 = 1
10090 NEXT I
10100 SUBEND
10110 REM ---- p_head: an expression in header mode (LANGUAGE 6.11) ---------------------------
10120 SUB "p_head": Z(), X$(), L(), E(), E$(), F$()
10130 LET H = Z(16)
10140 LET Z(16) = 1
10150 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
10160 LET Z(16) = H
10170 SUBEND
10180 REM ---- p_while: while head block ------------------------------------------------------
10190 SUB "p_while": Z(), X$(), L(), E(), E$(), F$()
10200 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
10210 LET P$ = X$(B + 3)
10220 LET Z(1) = Z(1) + 1
10230 CALL "p_head": Z(), X$(), L(), E(), E$(), F$()
10240 CALL "p_block": Z(), X$(), L(), E(), E$(), F$()
10250 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "while", P$, "", ""
10260 SUBEND
10270 REM ---- p_for: for IDENT in ( head_range | head_expr ) block ---------------------------
10280 SUB "p_for": Z(), X$(), L(), E(), E$(), F$()
10290 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
10300 LET P$ = X$(B + 3)
10310 LET Z(1) = Z(1) + 1
10320 CALL "pd": Z(), X$(), L(), E(), E$(), F$(), V$, Q$
10330 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "in"
10340 LET H = Z(16)
10350 LET Z(16) = 1
10360 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
10370 LET S$ = X$(B + 3)
10380 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
10390 CALL "p_rng": Z(), X$(), L(), E(), E$(), F$(), S$, R
10400 LET Z(16) = H
10410 CALL "p_block": Z(), X$(), L(), E(), E$(), F$()
10420 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "for", P$, V$, Q$
10430 SUBEND
10440 REM ---- p_rng: after a bound starting at S$, an optional ( .. | ..= ) or_expr [ step
10450 REM or_expr ]; R = 1 if a range node was written
10460 SUB "p_rng": Z(), X$(), L(), E(), E$(), F$(), S$, R
10470 LET R = 0
10480 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
10490 LET I = 0
10500 IF T$ = ".." THEN 10530
10510 LET I = 1
10520 IF T$ <> "..=" THEN 10630
10530 LET Z(1) = Z(1) + 1
10540 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
10550 LET T = 0
10560 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
10570 IF T$ <> "step" THEN 10610
10580 LET Z(1) = Z(1) + 1
10590 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
10600 LET T = 1
10610 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "range", S$, "", STR$(I) & " " & STR$(T)
10620 LET R = 1
10630 SUBEND
10640 REM ---- p_match: match head { nl { arm ( sep | , nl ) } [ arm ] nl } -------------------
10650 SUB "p_match": Z(), X$(), L(), E(), E$(), F$()
10660 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
10670 LET P$ = X$(B + 3)
10680 LET Z(1) = Z(1) + 1
10690 CALL "p_head": Z(), X$(), L(), E(), E$(), F$()
10700 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "{"
10710 CALL "pl": Z(), X$(), L(), E(), E$(), F$()
10720 LET N = 0
10730 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
10740 IF T$ = "}" THEN 10880
10750 CALL "p_arm": Z(), X$(), L(), E(), E$(), F$()
10760 LET N = N + 1
10770 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
10780 IF T$ = "}" THEN 10880
10790 IF T$ = "," THEN 10830
10800 IF K = 6 THEN 10860
10810 IF T$ = ";" THEN 10860
10820 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
10830 LET Z(1) = Z(1) + 1
10840 CALL "pl": Z(), X$(), L(), E(), E$(), F$()
10850 GOTO 10730
10860 CALL "ps": Z(), X$(), L(), E(), E$(), F$()
10870 GOTO 10730
10880 LET Z(1) = Z(1) + 1
10890 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "match", P$, "", STR$(N)
10900 SUBEND
10910 REM ---- p_arm: ( STRING { | STRING } | _ ) => block ------------------------------------
10920 SUB "p_arm": Z(), X$(), L(), E(), E$(), F$()
10930 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
10940 LET P$ = X$(B + 3)
10950 LET N = 0
10960 IF T$ <> "_" THEN 10990
10970 LET Z(1) = Z(1) + 1
10980 GOTO 11120
10990 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
11000 IF K = 4 THEN 11020
11010 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
11020 LET V$ = X$(B + 2)
11030 LET Q$ = X$(B + 3)
11040 CALL "pi": Z(), X$(), L(), E(), E$(), F$(), V$, Q$
11050 LET Z(1) = Z(1) + 1
11060 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "str", Q$, V$, ""
11070 LET N = N + 1
11080 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
11090 IF T$ <> "|" THEN 11120
11100 LET Z(1) = Z(1) + 1
11110 GOTO 10990
11120 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "=>"
11130 CALL "p_block": Z(), X$(), L(), E(), E$(), F$()
11140 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "arm", P$, "", STR$(N)
11150 SUBEND
11160 REM ---- p_return: return [ expr | ( expr , expr { , expr } ) ] ------------------------
11170 SUB "p_return": Z(), X$(), L(), E(), E$(), F$()
11180 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
11190 LET P$ = X$(B + 3)
11200 LET Z(1) = Z(1) + 1
11210 LET N = 0
11220 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
11230 IF K = 6 THEN 11370
11240 IF K = 7 THEN 11370
11250 IF T$ = ";" THEN 11370
11260 IF T$ = "}" THEN 11370
11270 LET N = 1
11280 IF T$ <> "(" THEN 11360
11290 REM a parenthesis: a tuple, or the first primary of an expression that goes on
11300 LET Q$ = X$(B + 3)
11310 CALL "p_paren": Z(), X$(), L(), E(), E$(), F$(), 1, N
11320 IF N > 1 THEN 11370
11330 LET X$(300106) = Q$
11340 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 1
11350 GOTO 11370
11360 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
11370 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "return", P$, "", STR$(N)
11380 SUBEND
11390 REM ---- p_expr: precedence climbing over the binary levels (LANGUAGE 6.1, Appendix B):
11400 REM 1 || 2 && 3 | 4 & 5 comparisons (non-associative) 6 + - 7 * / % @; M lowest level
11410 REM accepted, A = 1 lets a bare 2^63 literal through (inside parentheses), R = 1 when the
11420 REM first primary is already parsed (position X$(300106)). C: last operator was a comparison
11430 SUB "p_expr": Z(), X$(), L(), E(), E$(), F$(), M, A, R
11440 IF R = 1 THEN 11480
11450 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
11460 LET S$ = X$(B + 3)
11470 GOTO 11490
11480 LET S$ = X$(300106)
11490 CALL "p_un": Z(), X$(), L(), E(), E$(), F$(), R
11500 LET C = 0
11510 LET W$ = " ||:1or &&:2and |:3bor &:4band ==:5eq !=:5ne <:5lt <=:5le >:5gt >=:5ge +:6add -:6sub *:7mul /:7div %:7mod @:7matmul "
11520 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
11530 IF K <> 5 THEN 11720
11540 LET J = POS(W$, " " & T$ & ":")
11550 IF J = 0 THEN 11720
11560 LET J = J + LEN(T$) + 2
11570 LET V = VAL(SEG$(W$, J, J))
11580 IF V < M THEN 11720
11590 LET O$ = SEG$(W$, J + 1, POS(W$, " ", J) - 1)
11600 IF Z(20) = 0 THEN 11620
11610 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "INT_TOO_LARGE", X$(300105), ""
11620 IF V <> 5 THEN 11650
11630 IF C = 0 THEN 11650
11640 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "CHAINED_COMPARE", X$(B + 3), ""
11650 LET Z(1) = Z(1) + 1
11660 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), V + 1, 0, 0
11670 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "bin", S$, "", O$
11680 LET C = 0
11690 IF V <> 5 THEN 11520
11700 LET C = 1
11710 GOTO 11520
11720 IF A = 1 THEN 11750
11730 IF Z(20) = 0 THEN 11750
11740 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "INT_TOO_LARGE", X$(300105), ""
11750 SUBEND
11760 REM ---- p_un: unary = ( - | ! ) unary | power; power = postfix [ ^ unary ] --------------
11770 SUB "p_un": Z(), X$(), L(), E(), E$(), F$(), R
11780 IF R = 1 THEN 11980
11790 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
11800 IF T$ = "-" THEN 11820
11810 IF T$ <> "!" THEN 11980
11820 LET O$ = T$
11830 LET P$ = X$(B + 3)
11840 CALL "pn": Z(), X$(), L(), E(), E$(), F$(), P$
11850 LET Z(1) = Z(1) + 1
11860 CALL "p_un": Z(), X$(), L(), E(), E$(), F$(), 0
11870 IF O$ = "!" THEN 11920
11880 LET O$ = "neg"
11890 REM the operand of a unary minus may be 2^63
11900 LET Z(20) = 0
11910 GOTO 11950
11920 LET O$ = "not"
11930 IF Z(20) = 0 THEN 11950
11940 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "INT_TOO_LARGE", X$(300105), ""
11950 LET Z(15) = Z(15) - 1
11960 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), O$, P$, "", ""
11970 GOTO 12110
11980 CALL "p_post": Z(), X$(), L(), E(), E$(), F$(), R, S$
11990 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
12000 IF T$ <> "^" THEN 12110
12010 IF Z(20) = 0 THEN 12030
12020 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "INT_TOO_LARGE", X$(300105), ""
12030 LET Q$ = X$(B + 3)
12040 CALL "pn": Z(), X$(), L(), E(), E$(), F$(), Q$
12050 LET Z(1) = Z(1) + 1
12060 CALL "p_un": Z(), X$(), L(), E(), E$(), F$(), 0
12070 IF Z(20) = 0 THEN 12090
12080 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "INT_TOO_LARGE", X$(300105), ""
12090 LET Z(15) = Z(15) - 1
12100 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "bin", S$, "", "pow"
12110 SUBEND
12120 REM ---- p_post: postfix = primary { call_args | [ index_list ] | . IDENT }; S$ = its
12130 REM position; Z(21) = 1 when it is a target (a name with only [ ] and . suffixes)
12140 SUB "p_post": Z(), X$(), L(), E(), E$(), F$(), R, S$
12150 LET T = 0
12160 IF R = 0 THEN 12190
12170 LET S$ = X$(300106)
12180 GOTO 12220
12190 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
12200 LET S$ = X$(B + 3)
12210 CALL "p_prim": Z(), X$(), L(), E(), E$(), F$(), T
12220 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
12230 IF K <> 5 THEN 12590
12240 IF T$ = "(" THEN 12270
12250 IF T$ = "[" THEN 12270
12260 IF T$ <> "." THEN 12590
12270 IF Z(20) = 0 THEN 12290
12280 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "INT_TOO_LARGE", X$(300105), ""
12290 IF T$ = "[" THEN 12530
12300 IF T$ = "." THEN 12550
12310 REM call_args = ( [ arg { , arg } [ , ] ] )
12320 LET Q$ = X$(B + 3)
12330 CALL "pn": Z(), X$(), L(), E(), E$(), F$(), Q$
12340 LET Z(1) = Z(1) + 1
12350 LET H = Z(16)
12360 LET Z(16) = 0
12370 LET N = 0
12380 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
12390 IF T$ = ")" THEN 12470
12400 CALL "p_arg": Z(), X$(), L(), E(), E$(), F$()
12410 LET N = N + 1
12420 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
12430 IF T$ = ")" THEN 12470
12440 CALL "px": Z(), X$(), L(), E(), E$(), F$(), ","
12450 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
12460 IF T$ <> ")" THEN 12400
12470 LET Z(1) = Z(1) + 1
12480 LET Z(16) = H
12490 LET Z(15) = Z(15) - 1
12500 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "call", S$, "", STR$(N)
12510 LET T = 0
12520 GOTO 12220
12530 CALL "p_ix": Z(), X$(), L(), E(), E$(), F$(), S$
12540 GOTO 12220
12550 LET Z(1) = Z(1) + 1
12560 CALL "pd": Z(), X$(), L(), E(), E$(), F$(), V$, Q$
12570 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "dot", S$, V$, ""
12580 GOTO 12220
12590 LET Z(21) = T
12600 SUBEND
12610 REM ---- p_arg: arg = [ IDENT : ] expr | ref target -------------------------------------
12620 SUB "p_arg": Z(), X$(), L(), E(), E$(), F$()
12630 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
12640 IF T$ <> "ref" THEN 12700
12650 LET P$ = X$(B + 3)
12660 LET Z(1) = Z(1) + 1
12670 CALL "p_tgt": Z(), X$(), L(), E(), E$(), F$()
12680 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "ref", P$, "", ""
12690 GOTO 12790
12700 IF K <> 1 THEN 12780
12710 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 2, K2, T2$, B2
12720 IF T2$ <> ":" THEN 12780
12730 CALL "pd": Z(), X$(), L(), E(), E$(), F$(), V$, P$
12740 LET Z(1) = Z(1) + 1
12750 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
12760 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "narg", P$, V$, ""
12770 GOTO 12790
12780 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
12790 SUBEND
12800 REM ---- p_ix: [ index_list ] after a base at P$; index_list = index [ , index ] --------
12810 SUB "p_ix": Z(), X$(), L(), E(), E$(), F$(), P$
12820 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
12830 LET Q$ = X$(B + 3)
12840 CALL "pn": Z(), X$(), L(), E(), E$(), F$(), Q$
12850 LET Z(1) = Z(1) + 1
12860 LET H = Z(16)
12870 LET Z(16) = 0
12880 LET Z(17) = Z(17) + 1
12890 CALL "p_idx": Z(), X$(), L(), E(), E$(), F$()
12900 LET N = 1
12910 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
12920 IF T$ <> "," THEN 12960
12930 LET Z(1) = Z(1) + 1
12940 CALL "p_idx": Z(), X$(), L(), E(), E$(), F$()
12950 LET N = 2
12960 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "]"
12970 LET Z(17) = Z(17) - 1
12980 LET Z(16) = H
12990 LET Z(15) = Z(15) - 1
13000 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "index", P$, "", STR$(N)
13010 SUBEND
13020 REM ---- p_idx: index = : | range | expr --------------------------------------------------
13030 SUB "p_idx": Z(), X$(), L(), E(), E$(), F$()
13040 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
13050 LET S$ = X$(B + 3)
13060 IF T$ <> ":" THEN 13100
13070 LET Z(1) = Z(1) + 1
13080 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "all", S$, "", ""
13090 GOTO 13120
13100 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
13110 CALL "p_rng": Z(), X$(), L(), E(), E$(), F$(), S$, R
13120 SUBEND
13130 REM ---- p_paren: ( expr ) or ( range ) (rangev); with U = 1 also the tuple of return:
13140 REM N = 1, or the number of tuple elements. The 2^63 flag passes through ( expr )
13150 SUB "p_paren": Z(), X$(), L(), E(), E$(), F$(), U, N
13160 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
13170 LET P$ = X$(B + 3)
13180 CALL "pn": Z(), X$(), L(), E(), E$(), F$(), P$
13190 LET Z(1) = Z(1) + 1
13200 LET H = Z(16)
13210 LET Z(16) = 0
13220 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
13230 LET S$ = X$(B + 3)
13240 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 1, 0
13250 LET N = 1
13260 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
13270 IF T$ = ".." THEN 13390
13280 IF T$ = "..=" THEN 13390
13290 IF T$ <> "," THEN 13430
13300 IF U = 0 THEN 13430
13310 IF Z(20) = 0 THEN 13330
13320 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "INT_TOO_LARGE", X$(300105), ""
13330 LET Z(1) = Z(1) + 1
13340 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
13350 LET N = N + 1
13360 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
13370 IF T$ = "," THEN 13330
13380 GOTO 13430
13390 IF Z(20) = 0 THEN 13410
13400 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "INT_TOO_LARGE", X$(300105), ""
13410 CALL "p_rng": Z(), X$(), L(), E(), E$(), F$(), S$, R
13420 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "rangev", P$, "", ""
13430 CALL "px": Z(), X$(), L(), E(), E$(), F$(), ")"
13440 LET Z(16) = H
13450 LET Z(15) = Z(15) - 1
13460 SUBEND
13470 REM ---- p_prim: primary (Appendix A); T = 1 for a plain name ---------------------------
13480 SUB "p_prim": Z(), X$(), L(), E(), E$(), F$(), T
13490 LET T = 0
13500 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
13510 LET P$ = X$(B + 3)
13520 LET V$ = X$(B + 2)
13530 ON K GOTO 13550, 13650, 13710, 13740, 13780, 14240, 14240, 14240
13540 REM IDENT, or IDENT { a struct literal outside header mode
13550 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 2, K2, T2$, B2
13560 IF T2$ <> "{" THEN 13600
13570 IF Z(16) = 1 THEN 13600
13580 CALL "p_lit": Z(), X$(), L(), E(), E$(), F$(), 1
13590 GOTO 14250
13600 CALL "pi": Z(), X$(), L(), E(), E$(), F$(), V$, P$
13610 LET Z(1) = Z(1) + 1
13620 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "name", P$, V$, ""
13630 LET T = 1
13640 GOTO 14250
13650 LET Z(1) = Z(1) + 1
13660 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "int", P$, "", V$
13670 IF V$ <> "#8000000000000000" THEN 14250
13680 LET Z(20) = 1
13690 LET X$(300105) = P$
13700 GOTO 14250
13710 LET Z(1) = Z(1) + 1
13720 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "float", P$, "", V$
13730 GOTO 14250
13740 CALL "pi": Z(), X$(), L(), E(), E$(), F$(), V$, P$
13750 LET Z(1) = Z(1) + 1
13760 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "str", P$, V$, ""
13770 GOTO 14250
13780 IF T$ = "true" THEN 13920
13790 IF T$ = "false" THEN 13920
13800 IF T$ = "$" THEN 13960
13810 IF T$ = "(" THEN 14010
13820 IF T$ = "f64" THEN 14040
13830 IF T$ = "i64" THEN 14040
13840 IF T$ = "str" THEN 14040
13850 IF T$ = "[" THEN 14200
13860 IF T$ = "if" THEN 14220
13870 IF T$ <> "{" THEN 14240
13880 REM { starts a record literal, except in header mode (LANGUAGE 6.11)
13890 IF Z(16) = 1 THEN 14240
13900 CALL "p_lit": Z(), X$(), L(), E(), E$(), F$(), 0
13910 GOTO 14250
13920 LET O$ = T$
13930 LET Z(1) = Z(1) + 1
13940 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), O$, P$, "", ""
13950 GOTO 14250
13960 IF Z(17) > 0 THEN 13980
13970 CALL "pc": Z(), X$(), L(), E(), E$(), F$(), "DOLLAR_OUTSIDE", P$, ""
13980 LET Z(1) = Z(1) + 1
13990 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "dollar", P$, "", ""
14000 GOTO 14250
14010 CALL "p_paren": Z(), X$(), L(), E(), E$(), F$(), 0, N
14020 GOTO 14250
14030 REM conv_type ( expr )
14040 LET O$ = T$
14050 LET Z(1) = Z(1) + 1
14060 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
14070 IF T$ = "(" THEN 14090
14080 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
14090 LET Q$ = X$(B + 3)
14100 CALL "pn": Z(), X$(), L(), E(), E$(), F$(), Q$
14110 LET Z(1) = Z(1) + 1
14120 LET H = Z(16)
14130 LET Z(16) = 0
14140 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
14150 CALL "px": Z(), X$(), L(), E(), E$(), F$(), ")"
14160 LET Z(16) = H
14170 LET Z(15) = Z(15) - 1
14180 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "conv", P$, "", O$
14190 GOTO 14250
14200 CALL "p_arr": Z(), X$(), L(), E(), E$(), F$()
14210 GOTO 14250
14220 CALL "p_ifx": Z(), X$(), L(), E(), E$(), F$()
14230 GOTO 14250
14240 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
14250 SUBEND
14260 REM ---- p_arr: array_lit = [ [ row { ; row } [ ; ] ] ]; row = expr { , expr } [ , ] ----
14270 REM locals: R rows, N expressions of the row, Q$ row position
14280 SUB "p_arr": Z(), X$(), L(), E(), E$(), F$()
14290 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
14300 LET P$ = X$(B + 3)
14310 CALL "pn": Z(), X$(), L(), E(), E$(), F$(), P$
14320 LET Z(1) = Z(1) + 1
14330 LET H = Z(16)
14340 LET Z(16) = 0
14350 LET R = 0
14360 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
14370 IF T$ = "]" THEN 14580
14380 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
14390 LET Q$ = X$(B + 3)
14400 LET N = 0
14410 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
14420 LET N = N + 1
14430 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
14440 IF T$ <> "," THEN 14490
14450 LET Z(1) = Z(1) + 1
14460 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
14470 IF T$ = ";" THEN 14490
14480 IF T$ <> "]" THEN 14410
14490 IF T$ = ";" THEN 14520
14500 IF T$ = "]" THEN 14520
14510 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
14520 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "row", Q$, "", STR$(N)
14530 LET R = R + 1
14540 IF T$ = "]" THEN 14580
14550 LET Z(1) = Z(1) + 1
14560 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
14570 IF T$ <> "]" THEN 14380
14580 LET Z(1) = Z(1) + 1
14590 LET Z(16) = H
14600 LET Z(15) = Z(15) - 1
14610 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "array", P$, "", STR$(R)
14620 SUBEND
14630 REM ---- p_lit: W = 1 struct_lit IDENT { nl [ init { , nl init } [ , ] ] nl }; W = 0
14640 REM record_lit { nl init { , nl init } [ , ] nl }; init = IDENT : expr
14650 SUB "p_lit": Z(), X$(), L(), E(), E$(), F$(), W
14660 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
14670 LET P$ = X$(B + 3)
14680 IF W = 0 THEN 14730
14690 LET V$ = X$(B + 2)
14700 CALL "pi": Z(), X$(), L(), E(), E$(), F$(), V$, P$
14710 LET Z(1) = Z(1) + 1
14720 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
14730 LET Q$ = X$(B + 3)
14740 CALL "pn": Z(), X$(), L(), E(), E$(), F$(), Q$
14750 LET Z(1) = Z(1) + 1
14760 CALL "pl": Z(), X$(), L(), E(), E$(), F$()
14770 LET N = 0
14780 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
14790 IF T$ <> "}" THEN 14820
14800 IF W = 1 THEN 14970
14810 CALL "pe": Z(), X$(), L(), E(), E$(), F$(), K, B
14820 CALL "pd": Z(), X$(), L(), E(), E$(), F$(), W$, Q$
14830 CALL "px": Z(), X$(), L(), E(), E$(), F$(), ":"
14840 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
14850 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "init", Q$, W$, ""
14860 LET N = N + 1
14870 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
14880 IF T$ <> "," THEN 14940
14890 LET Z(1) = Z(1) + 1
14900 CALL "pl": Z(), X$(), L(), E(), E$(), F$()
14910 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
14920 IF T$ = "}" THEN 14970
14930 GOTO 14820
14940 CALL "pl": Z(), X$(), L(), E(), E$(), F$()
14950 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "}"
14960 GOTO 14980
14970 LET Z(1) = Z(1) + 1
14980 LET Z(15) = Z(15) - 1
14990 IF W = 0 THEN 15020
15000 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "slit", P$, V$, STR$(N)
15010 GOTO 15030
15020 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "rlit", P$, "", STR$(N)
15030 SUBEND
15040 REM ---- p_ifx: if head_expr { nl expr nl } else ( if_expr | { nl expr nl } ) -------------
15050 SUB "p_ifx": Z(), X$(), L(), E(), E$(), F$()
15060 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
15070 LET P$ = X$(B + 3)
15080 CALL "pn": Z(), X$(), L(), E(), E$(), F$(), P$
15090 LET Z(1) = Z(1) + 1
15100 CALL "p_head": Z(), X$(), L(), E(), E$(), F$()
15110 CALL "p_brx": Z(), X$(), L(), E(), E$(), F$()
15120 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "else"
15130 CALL "pt": Z(), X$(), L(), E(), E$(), F$(), 1, K, T$, B
15140 IF T$ <> "if" THEN 15170
15150 CALL "p_ifx": Z(), X$(), L(), E(), E$(), F$()
15160 GOTO 15180
15170 CALL "p_brx": Z(), X$(), L(), E(), E$(), F$()
15180 LET Z(15) = Z(15) - 1
15190 CALL "pw": Z(), X$(), L(), E(), E$(), F$(), "ifx", P$, "", ""
15200 SUBEND
15210 REM ---- p_brx: { nl expr nl } -------------------------------------------------------------
15220 SUB "p_brx": Z(), X$(), L(), E(), E$(), F$()
15230 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "{"
15240 CALL "pl": Z(), X$(), L(), E(), E$(), F$()
15250 CALL "p_expr": Z(), X$(), L(), E(), E$(), F$(), 1, 0, 0
15260 CALL "pl": Z(), X$(), L(), E(), E$(), F$()
15270 CALL "px": Z(), X$(), L(), E(), E$(), F$(), "}"
15280 SUBEND
