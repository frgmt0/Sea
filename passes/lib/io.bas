60000 REM ====================================================================================
60005 REM io.bas -- shared pass module: records, fields, %-escapes, headers (DESIGN 2.2, 3.1-3.3)
60010 REM Lines 60000-62999 (DESIGN 2.6.3); no DATA, END or globals; every SUB gets its state as
60015 REM parameters. Needs diag.bas, and tables.bas for io_hdr. The API (every SUB, parameters,
60020 REM results) is in passes/lib/API.md; each SUB below has a one-line summary.
60025 REM Common: K file number, L$ a record, P$ pass name, E() E$() E0 the error table.
60030 REM Size: the long-string SUB variants DIM 65536 words (SEA_LIM_RECORD_BYTES); strings of up
60035 REM to 256 bytes use a 256-word list.
60040 REM ====================================================================================
60045 REM ---- io_read -----------------------------------------------------------------------
60050 SUB "io_read": K, L$, L9, P$, E(), E$(), E0
60055 IF END #K THEN 60080
60060 LINPUT #K, L$
60065 LET L9 = L9 + 1
60070 GOTO 60085
60075 REM the input ended before #end: the internal error
60080 CALL "dg_internal": P$, "TRUNCATED", E(), E$(), E0
60085 SUBEND
60090 REM ---- io_end ------------------------------------------------------------------------
60095 SUB "io_end": K, P$, E(), E$(), E0
60100 REM after #end the input must be at its end
60105 IF END #K THEN 60115
60110 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
60115 SUBEND
60120 REM ---- io_put / io_fin ---------------------------------------------------------------
60125 SUB "io_put": K, L$
60130 PRINT #K, L$
60135 SUBEND
60140 SUB "io_fin": K
60145 PRINT #K, "#end"
60150 SUBEND
60155 REM ---- io_split ----------------------------------------------------------------------
60160 REM locals: L0 length, P field start, Q next blank
60165 SUB "io_split": L$, F$(), M, N
60170 LET N = 0
60175 LET L0 = LEN(L$)
60180 IF L0 = 0 THEN 60265
60185 LET P = 1
60190 LET Q = POS(L$, " ", P)
60195 IF Q = 0 THEN 60245
60200 REM a blank at the field start is an empty field
60205 IF Q = P THEN 60265
60210 LET N = N + 1
60215 IF N > M THEN 60265
60220 LET F$(N) = SEG$(L$, P, Q - 1)
60225 LET P = Q + 1
60230 REM a blank at the very end leaves an empty last field
60235 IF P > L0 THEN 60265
60240 GOTO 60190
60245 LET N = N + 1
60250 IF N > M THEN 60265
60255 LET F$(N) = SEG$(L$, P, L0)
60260 GOTO 60270
60265 LET N = -1
60270 SUBEND
60275 REM ---- io_plain (core + two sizes) ---------------------------------------------------
60280 REM core: W() is a work list of at least LEN(L$) + 1 elements
60285 SUB "io_pc": L$, W(), O
60290 LET O = 1
60295 LET N = LEN(L$)
60300 IF N = 0 THEN 60340
60305 CHANGE L$ TO W
60310 FOR I = 1 TO N
60315 IF W(I) < 32 THEN 60335
60320 IF W(I) > 126 THEN 60335
60325 NEXT I
60330 GOTO 60340
60335 LET O = 0
60340 SUBEND
60345 SUB "io_plain": L$, O
60350 DIM W(256)
60355 IF LEN(L$) > 256 THEN 60370
60360 CALL "io_pc": L$, W(), O
60365 GOTO 60375
60370 CALL "io_plain_l": L$, O
60375 SUBEND
60380 SUB "io_plain_l": L$, O
60385 DIM W(65536)
60390 CALL "io_pc": L$, W(), O
60395 SUBEND
60400 REM ---- io_unesc (core + two sizes) ---------------------------------------------------
60405 REM core: W() holds at least LEN(S$) + 1 elements. The codes are decoded in place:
60410 REM W(1..O) is the output, written behind the read position, W(0) the length for CHANGE.
60415 REM locals: N length, I read index, O output count, C byte, X hex digit value, V byte value
60420 SUB "io_uc": S$, M, W(), R$, T
60425 LET T = 0
60430 LET R$ = ""
60435 LET N = LEN(S$)
60440 IF N = 0 THEN 60640
60445 CHANGE S$ TO W
60450 REM the field "%" alone is the empty string
60455 IF N > 1 THEN 60465
60460 IF W(1) = 37 THEN 60665
60465 LET I = 1
60470 LET O = 0
60475 IF I > N THEN 60625
60480 LET C = W(I)
60485 IF C = 37 THEN 60540
60490 REM a raw byte must be 0x21-0x7E, and in DATA mode not a quote
60495 IF C < 33 THEN 60655
60500 IF C > 126 THEN 60655
60505 IF M = 0 THEN 60515
60510 IF C = 34 THEN 60655
60515 LET O = O + 1
60520 LET W(O) = C
60525 LET I = I + 1
60530 GOTO 60475
60535 REM % and two upper-case hex digits
60540 IF I + 2 > N THEN 60640
60545 LET X = POS("0123456789ABCDEF", SEG$(S$, I + 1, I + 1))
60550 IF X = 0 THEN 60640
60555 LET V = (X - 1) * 16
60560 LET X = POS("0123456789ABCDEF", SEG$(S$, I + 2, I + 2))
60565 IF X = 0 THEN 60640
60570 LET V = V + X - 1
60575 REM an escape is canonical only for bytes <= 0x20, >= 0x7F, % and (DATA mode) the quote
60580 IF V <= 32 THEN 60605
60585 IF V >= 127 THEN 60605
60590 IF V = 37 THEN 60605
60595 IF M = 0 THEN 60655
60600 IF V <> 34 THEN 60655
60605 LET O = O + 1
60610 LET W(O) = V
60615 LET I = I + 3
60620 GOTO 60475
60625 LET W(0) = O
60630 CHANGE W TO R$
60635 GOTO 60665
60640 LET T = 1
60645 LET R$ = ""
60650 GOTO 60665
60655 LET T = 2
60660 LET R$ = ""
60665 SUBEND
60670 SUB "io_unesc": S$, M, R$, T
60675 DIM W(256)
60680 IF LEN(S$) > 256 THEN 60695
60685 CALL "io_uc": S$, M, W(), R$, T
60690 GOTO 60700
60695 CALL "io_unesc_l": S$, M, R$, T
60700 SUBEND
60705 SUB "io_unesc_l": S$, M, R$, T
60710 DIM W(65536)
60715 CALL "io_uc": S$, M, W(), R$, T
60720 SUBEND
60725 REM ---- io_esc (core + two sizes) -----------------------------------------------------
60730 REM core: runs of bytes that need no escape are appended with one SEG$.
60735 REM locals: N length, I scan index, B start of the current run, C byte, H high nibble
60740 SUB "io_ec": S$, M, W(), R$
60745 LET N = LEN(S$)
60750 IF N > 0 THEN 60765
60755 LET R$ = "%"
60760 GOTO 60880
60765 CHANGE S$ TO W
60770 LET R$ = ""
60775 LET I = 1
60780 LET B = 1
60785 IF I > N THEN 60870
60790 LET C = W(I)
60795 IF C < 33 THEN 60835
60800 IF C > 126 THEN 60835
60805 IF C = 37 THEN 60835
60810 IF M = 0 THEN 60820
60815 IF C = 34 THEN 60835
60820 LET I = I + 1
60825 GOTO 60785
60830 REM flush the run before I, then the escape of byte C
60835 IF I = B THEN 60845
60840 LET R$ = R$ & SEG$(S$, B, I - 1)
60845 LET H = INT(C / 16)
60850 LET R$ = R$ & "%" & SEG$("0123456789ABCDEF", H + 1, H + 1) & SEG$("0123456789ABCDEF", C - H * 16 + 1, C - H * 16 + 1)
60855 LET I = I + 1
60860 LET B = I
60865 GOTO 60785
60870 IF B > N THEN 60880
60875 LET R$ = R$ & SEG$(S$, B, N)
60880 SUBEND
60885 SUB "io_esc": S$, M, R$
60890 DIM W(256)
60895 IF LEN(S$) > 256 THEN 60910
60900 CALL "io_ec": S$, M, W(), R$
60905 GOTO 60915
60910 CALL "io_esc_l": S$, M, R$
60915 SUBEND
60920 SUB "io_esc_l": S$, M, R$
60925 DIM W(65536)
60930 CALL "io_ec": S$, M, W(), R$
60935 SUBEND
60940 REM ---- io_u --------------------------------------------------------------------------
60945 REM locals: N length, W() the digit codes
60950 SUB "io_u": F$, V, T
60955 DIM W(15)
60960 LET V = 0
60965 LET T = 1
60970 LET N = LEN(F$)
60975 IF N = 0 THEN 61035
60980 IF N > 9 THEN 61035
60985 CHANGE F$ TO W
60990 FOR I = 1 TO N
60995 IF W(I) < 48 THEN 61035
61000 IF W(I) > 57 THEN 61035
61005 NEXT I
61010 REM no leading zero except the number 0 itself
61015 IF N = 1 THEN 61025
61020 IF W(1) = 48 THEN 61035
61025 LET V = VAL(F$)
61030 LET T = 0
61035 SUBEND
61040 REM ---- io_hx: four hex digits at position P of S$ -> V -------------------------------
61045 SUB "io_hx": S$, P, V, T
61050 LET V = 0
61055 LET T = 1
61060 IF P + 3 > LEN(S$) THEN 61105
61065 FOR I = 0 TO 3
61070 LET X = POS("0123456789ABCDEF", SEG$(S$, P + I, P + I))
61075 IF X = 0 THEN 61100
61080 LET V = V * 16 + X - 1
61085 NEXT I
61090 LET T = 0
61095 GOTO 61105
61100 LET V = 0
61105 SUBEND
61110 REM ---- io_f --------------------------------------------------------------------------
61115 SUB "io_f": F$, L(), T
61120 LET T = 1
61125 IF LEN(F$) <> 17 THEN 61160
61130 IF SEG$(F$, 1, 1) <> "#" THEN 61160
61135 FOR J = 1 TO 4
61140 CALL "io_hx": F$, 4 * J - 2, L(J), T1
61145 IF T1 <> 0 THEN 61160
61150 NEXT J
61155 LET T = 0
61160 SUBEND
61165 REM ---- io_i --------------------------------------------------------------------------
61170 REM locals: N length, S sign, B first digit, A magnitude, W low 32 bits of a negative value
61175 SUB "io_i": F$, V, K, L(), T
61180 LET T = 1
61185 LET V = 0
61190 LET K = 0
61195 FOR J = 1 TO 4
61200 LET L(J) = 0
61205 NEXT J
61210 LET N = LEN(F$)
61215 IF N = 0 THEN 61450
61220 IF SEG$(F$, 1, 1) = "#" THEN 61340
61225 LET S = 1
61230 LET B = 1
61235 IF SEG$(F$, 1, 1) <> "-" THEN 61250
61240 LET S = -1
61245 LET B = 2
61250 IF B > N THEN 61450
61255 CALL "io_u": SEG$(F$, B, N), A, T1
61260 IF T1 <> 0 THEN 61450
61265 REM "-0" is not written
61270 IF S > 0 THEN 61280
61275 IF A = 0 THEN 61450
61280 LET V = S * A
61285 IF V < 0 THEN 61305
61290 LET L(3) = INT(V / 65536)
61295 LET L(4) = V - L(3) * 65536
61300 GOTO 61415
61305 LET W = 65536 * 65536 + V
61310 LET L(1) = 65535
61315 LET L(2) = 65535
61320 LET L(3) = INT(W / 65536)
61325 LET L(4) = W - L(3) * 65536
61330 GOTO 61415
61335 REM hexadecimal: only for |v| >= 1E9 (DESIGN 3.1)
61340 IF N <> 17 THEN 61450
61345 FOR J = 1 TO 4
61350 CALL "io_hx": F$, 4 * J - 2, L(J), T1
61355 IF T1 <> 0 THEN 61425
61360 NEXT J
61365 LET W = L(3) * 65536 + L(4)
61370 IF L(1) = 65535 THEN 61400
61375 IF L(1) <> 0 THEN 61410
61380 IF L(2) <> 0 THEN 61410
61385 IF W < 1E9 THEN 61425
61390 GOTO 61410
61395 REM top 32 bits all ones: a negative value > -1E9 must be decimal
61400 IF L(2) <> 65535 THEN 61410
61405 IF W > 65536 * 65536 - 1E9 THEN 61425
61410 LET K = 1
61415 LET T = 0
61420 GOTO 61450
61425 LET V = 0
61430 LET K = 0
61435 FOR J = 1 TO 4
61440 LET L(J) = 0
61445 NEXT J
61450 SUBEND
61455 REM ---- io_hex ------------------------------------------------------------------------
61460 REM locals: H$ digits, X remaining limb value, D digit
61465 SUB "io_hex": L(), R$
61470 LET H$ = "0123456789ABCDEF"
61475 LET R$ = "#"
61480 FOR I = 1 TO 4
61485 LET X = L(I)
61490 LET D = INT(X / 4096)
61495 LET X = X - D * 4096
61500 LET R$ = R$ & SEG$(H$, D + 1, D + 1)
61505 LET D = INT(X / 256)
61510 LET X = X - D * 256
61515 LET R$ = R$ & SEG$(H$, D + 1, D + 1)
61520 LET D = INT(X / 16)
61525 LET X = X - D * 16
61530 LET R$ = R$ & SEG$(H$, D + 1, D + 1) & SEG$(H$, X + 1, X + 1)
61535 NEXT I
61540 SUBEND
61545 REM ---- io_pos / io_site --------------------------------------------------------------
61550 REM F:L:C with three u fields; locals Q, R the two colons
61555 SUB "io_pos": F$, F, L, C, T
61560 LET T = 1
61565 LET F = 0
61570 LET L = 0
61575 LET C = 0
61580 LET Q = POS(F$, ":")
61585 IF Q < 2 THEN 61680
61590 LET R = POS(F$, ":", Q + 1)
61595 IF R < Q + 2 THEN 61680
61600 IF R >= LEN(F$) THEN 61680
61605 REM a third colon is not allowed
61610 IF POS(F$, ":", R + 1) > 0 THEN 61680
61615 CALL "io_u": SEG$(F$, 1, Q - 1), F, T1
61620 IF T1 <> 0 THEN 61665
61625 CALL "io_u": SEG$(F$, Q + 1, R - 1), L, T1
61630 IF T1 <> 0 THEN 61665
61635 CALL "io_u": SEG$(F$, R + 1, LEN(F$)), C, T1
61640 IF T1 <> 0 THEN 61665
61645 IF L < 1 THEN 61665
61650 IF C < 1 THEN 61665
61655 LET T = 0
61660 GOTO 61680
61665 LET F = 0
61670 LET L = 0
61675 LET C = 0
61680 SUBEND
61685 SUB "io_site": F$, F, L, T
61690 LET T = 1
61695 LET F = 0
61700 LET L = 0
61705 LET Q = POS(F$, ":")
61710 IF Q < 2 THEN 61770
61715 IF Q >= LEN(F$) THEN 61770
61720 IF POS(F$, ":", Q + 1) > 0 THEN 61770
61725 CALL "io_u": SEG$(F$, 1, Q - 1), F, T1
61730 IF T1 <> 0 THEN 61760
61735 CALL "io_u": SEG$(F$, Q + 1, LEN(F$)), L, T1
61740 IF T1 <> 0 THEN 61760
61745 IF L < 1 THEN 61760
61750 LET T = 0
61755 GOTO 61770
61760 LET F = 0
61765 LET L = 0
61770 SUBEND
61775 REM ---- io_hdr: #sea V, #target T, #file P ... ----------------------------------------
61780 REM locals: G$() the fields of the record, G count, L9 line number, Y word
61785 REM position in the enum, R enum row
61790 SUB "io_hdr": K, P$, E(), E$(), E0, N(), N$(), W$(), N0, V, T$, F$(), M, N1, L$
61795 DIM G$(3)
61800 LET N1 = 0
61805 LET L9 = 0
61810 REM line 1: #sea V
61815 CALL "io_read": K, L$, L9, P$, E(), E$(), E0
61820 CALL "io_split": L$, G$(), 3, G
61825 IF G <> 2 THEN 61925
61830 IF G$(1) <> "#sea" THEN 61925
61835 CALL "io_u": G$(2), Y, T
61840 IF T <> 0 THEN 61925
61845 IF Y <> V THEN 61925
61850 REM line 2: #target T
61855 CALL "io_read": K, L$, L9, P$, E(), E$(), E0
61860 CALL "io_split": L$, G$(), 3, G
61865 IF G <> 2 THEN 61925
61870 IF G$(1) <> "#target" THEN 61925
61875 LET T$ = G$(2)
61880 CALL "tb_enum": N$(), N0, "target", R
61885 IF R = 0 THEN 61925
61890 CALL "tb_word": N(), W$(), R, T$, Y
61895 IF Y = 0 THEN 61925
61900 REM #file records until the first other record
61905 CALL "io_read": K, L$, L9, P$, E(), E$(), E0
61910 CALL "io_file": P$, E(), E$(), E0, L$, F$(), M, N1, Y
61915 IF Y = 1 THEN 61905
61920 GOTO 61930
61925 CALL "dg_internal": P$, "BAD_HEADER", E(), E$(), E0
61930 SUBEND
61935 REM ---- io_hdr_put --------------------------------------------------------------------
61940 SUB "io_hdr_put": K, V, T$, F$(), N1
61945 PRINT #K, "#sea " & STR$(V)
61950 PRINT #K, "#target " & T$
61955 FOR I = 1 TO N1
61960 CALL "io_esc": F$(I), 0, R$
61965 PRINT #K, "#file " & R$
61970 NEXT I
61975 SUBEND
61980 REM ---- io_file: one #file record, appended to F$() ---------------------------------------
61985 REM locals: G$() the fields of the record, G count, T decode status
61990 SUB "io_file": P$, E(), E$(), E0, L$, F$(), M, N1, Y
61995 DIM G$(3)
62000 LET Y = 0
62005 IF LEN(L$) < 5 THEN 62075
62010 IF SEG$(L$, 1, 5) <> "#file" THEN 62075
62015 IF LEN(L$) = 5 THEN 62070
62020 REM a longer first field (#files ...) is not a #file record
62025 IF SEG$(L$, 6, 6) <> " " THEN 62075
62030 CALL "io_split": L$, G$(), 3, G
62035 IF G <> 2 THEN 62070
62040 LET N1 = N1 + 1
62045 IF N1 > M THEN 62070
62050 CALL "io_unesc": G$(2), 0, F$(N1), T
62055 IF T <> 0 THEN 62070
62060 LET Y = 1
62065 GOTO 62075
62070 CALL "dg_internal": P$, "BAD_HEADER", E(), E$(), E0
62075 SUBEND
