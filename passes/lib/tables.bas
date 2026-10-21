66000 REM ====================================================================================
66005 REM tables.bas -- shared pass module: loaders for the generated DATA blocks (DESIGN 2.6.3)
66010 REM Lines 66000-68999 (DESIGN 2.6.3); no DATA, END or globals. Needs io.bas and diag.bas.
66015 REM Call the loaders in the order errors, errno, exits, consts, entries, records, only for
66020 REM the blocks of the pass's build.list (numeric and string DATA are separate streams). A
66025 REM table over its capacity, a missing sentinel or a misaligned stream: BAD_DATA, STOP 11.
66030 REM The API (parameters, row layouts, type codes) is in passes/lib/API.md.
66035 REM ====================================================================================
66040 REM ---- tb_fail / tb_dec --------------------------------------------------------------
66045 SUB "tb_fail": P$, E(), E$(), E0
66050 IF E0 > 0 THEN 66060
66055 CALL "dg_boot": P$
66060 CALL "dg_internal": P$, "BAD_DATA", E(), E$(), E0
66065 SUBEND
66070 REM decode one DATA string; a malformed one is a bad table
66075 SUB "tb_dec": P$, E(), E$(), E0, S$, R$
66080 CALL "io_unesc": S$, 1, R$, T
66085 IF T = 0 THEN 66095
66090 CALL "tb_fail": P$, E(), E$(), E0
66095 SUBEND
66100 REM ---- tb_errors ---------------------------------------------------------------------
66105 REM numeric: code; strings: NAME, phase, at, args, text. Sentinel: the number -1.
66110 REM locals: I row, J column, V code, S$ raw string, X$ decoded string, Q$ the phase
66115 SUB "tb_errors": P$, E(), E$(), M, N
66120 LET N = 0
66125 FOR I = 1 TO M + 1
66130 READ V
66135 IF V = -1 THEN 66230
66140 IF I > M THEN 66225
66145 LET E(I) = V
66150 FOR J = 1 TO 5
66155 READ S$
66160 CALL "tb_dec": P$, E(), E$(), 0, S$, X$
66165 LET E$(I, J) = X$
66170 NEXT J
66175 REM the phase letter proves the stream is aligned with the error table
66180 LET Q$ = E$(I, 2)
66185 IF Q$ = "R" THEN 66220
66190 IF Q$ = "D" THEN 66220
66195 IF Q$ = "C1" THEN 66220
66200 IF Q$ = "C2" THEN 66220
66205 IF Q$ = "CX" THEN 66220
66210 IF Q$ = "P" THEN 66220
66215 GOTO 66225
66220 NEXT I
66225 CALL "dg_boot": P$
66230 LET N = I - 1
66235 SUBEND
66240 REM ---- tb_errno ----------------------------------------------------------------------
66245 REM numeric: id, darwin, linux; strings: NAME, text. Sentinel: -1.
66250 SUB "tb_errno": P$, E(), E$(), E0, R(), R$(), M, N
66255 LET N = 0
66260 FOR I = 1 TO M + 1
66265 READ V
66270 IF V = -1 THEN 66335
66275 IF I > M THEN 66330
66280 LET R(I, 1) = V
66285 READ A, B
66290 LET R(I, 2) = A
66295 LET R(I, 3) = B
66300 FOR J = 1 TO 2
66305 READ S$
66310 CALL "tb_dec": P$, E(), E$(), E0, S$, X$
66315 LET R$(I, J) = X$
66320 NEXT J
66325 NEXT I
66330 CALL "tb_fail": P$, E(), E$(), E0
66335 LET N = I - 1
66340 SUBEND
66345 REM ---- tb_exits ----------------------------------------------------------------------
66350 REM numeric: value; string: NAME. Sentinel: -1.
66355 SUB "tb_exits": P$, E(), E$(), E0, X(), X$(), M, N
66360 LET N = 0
66365 LET E$(0, 1) = ""
66370 LET E$(0, 2) = ""
66375 FOR I = 1 TO M + 1
66380 READ V
66385 IF V = -1 THEN 66425
66390 IF I > M THEN 66420
66395 LET X(I) = V
66400 READ S$
66405 CALL "tb_dec": P$, E(), E$(), E0, S$, Q$
66410 LET X$(I) = Q$
66415 NEXT I
66420 CALL "tb_fail": P$, E(), E$(), E0
66425 LET N = I - 1
66430 REM keep the two statuses dg_internal and dg_compile stop with (E$(0,1) internal, E$(0,2) compile)
66435 FOR J = 1 TO N
66440 IF X$(J) <> "PASS_INTERNAL" THEN 66450
66445 LET E$(0, 1) = STR$(X(J))
66450 IF X$(J) <> "PASS_COMPILE" THEN 66460
66455 LET E$(0, 2) = STR$(X(J))
66460 NEXT J
66465 IF LEN(E$(0, 1)) = 0 THEN 66420
66470 IF LEN(E$(0, 2)) = 0 THEN 66420
66475 SUBEND
66480 REM ---- tb_consts ---------------------------------------------------------------------
66485 REM string: name, then four limbs 0..65535. Sentinel: the string "-".
66490 SUB "tb_consts": P$, E(), E$(), E0, C(), C$(), M, N
66495 LET N = 0
66500 FOR I = 1 TO M + 1
66505 READ S$
66510 CALL "tb_dec": P$, E(), E$(), E0, S$, X$
66515 IF X$ = "-" THEN 66570
66520 IF I > M THEN 66565
66525 LET C$(I) = X$
66530 FOR J = 1 TO 4
66535 READ V
66540 IF V < 0 THEN 66565
66545 IF V > 65535 THEN 66565
66550 LET C(I, J) = V
66555 NEXT J
66560 NEXT I
66565 CALL "tb_fail": P$, E(), E$(), E0
66570 LET N = I - 1
66575 SUBEND
66580 REM ---- tb_entries --------------------------------------------------------------------
66585 REM numeric: id; strings: NAME, symbol, site, args, results. Sentinel: -1.
66590 SUB "tb_entries": P$, E(), E$(), E0, Y(), Y$(), M, N
66595 LET N = 0
66600 FOR I = 1 TO M + 1
66605 READ V
66610 IF V = -1 THEN 66660
66615 IF I > M THEN 66655
66620 LET Y(I) = V
66625 FOR J = 1 TO 5
66630 READ S$
66635 CALL "tb_dec": P$, E(), E$(), E0, S$, X$
66640 LET Y$(I, J) = X$
66645 NEXT J
66650 NEXT I
66655 CALL "tb_fail": P$, E(), E$(), E0
66660 LET N = I - 1
66665 SUBEND
66670 REM ---- lookups -----------------------------------------------------------------------
66675 SUB "tb_find": K$(), N, S$, R
66680 LET R = 0
66685 FOR I = 1 TO N
66690 IF K$(I) <> S$ THEN 66705
66695 LET R = I
66700 GOTO 66710
66705 NEXT I
66710 SUBEND
66715 SUB "tb_enum": N$(), N0, S$, R
66720 LET R = 0
66725 FOR I = 1 TO N0
66730 IF N$(I) <> S$ THEN 66745
66735 LET R = I
66740 GOTO 66750
66745 NEXT I
66750 SUBEND
66755 SUB "tb_word": N(), W$(), R1, S$, R
66760 LET R = 0
66765 FOR K = 1 TO N(R1, 2)
66770 IF W$(N(R1, 1) + K - 1) <> S$ THEN 66785
66775 LET R = K
66780 GOTO 66790
66785 NEXT K
66790 SUBEND
66795 REM tb_cval: limbs A B C D (most significant first); a negative pattern is negated first.
66800 SUB "tb_cval": C(), C$(), N, Q$, V, T
66805 LET V = 0
66810 LET T = 1
66815 CALL "tb_find": C$(), N, Q$, R
66820 IF R = 0 THEN 66945
66825 LET A = C(R, 1)
66830 LET B = C(R, 2)
66835 LET C1 = C(R, 3)
66840 LET D = C(R, 4)
66845 LET S = 1
66850 IF A < 32768 THEN 66930
66855 REM two's complement negation: invert all limbs, add one with carry
66860 LET A = 65535 - A
66865 LET B = 65535 - B
66870 LET C1 = 65535 - C1
66875 LET D = 65536 - D
66880 LET S = -1
66885 IF D < 65536 THEN 66930
66890 LET D = 0
66895 LET C1 = C1 + 1
66900 IF C1 < 65536 THEN 66930
66905 LET C1 = 0
66910 LET B = B + 1
66915 IF B < 65536 THEN 66930
66920 LET B = 0
66925 LET A = A + 1
66930 IF A >= 32 THEN 66945
66935 LET V = S * (((A * 65536 + B) * 65536 + C1) * 65536 + D)
66940 LET T = 0
66945 SUBEND
66950 REM ---- tb_fspec: "name:type", "name:type?", "name:type*count", "name:type?*count" ----
66955 SUB "tb_fspec": S$, A$, B$, O, D$, T
66960 LET T = 1
66965 LET A$ = ""
66970 LET B$ = ""
66975 LET D$ = ""
66980 LET O = 0
66985 LET P = POS(S$, ":")
66990 IF P < 2 THEN 67070
66995 LET A$ = SEG$(S$, 1, P - 1)
67000 LET Q$ = SEG$(S$, P + 1, LEN(S$))
67005 LET Q = POS(Q$, "*")
67010 IF Q = 0 THEN 67035
67015 REM the count field name follows the star and must not be empty
67020 IF Q = LEN(Q$) THEN 67070
67025 LET D$ = SEG$(Q$, Q + 1, LEN(Q$))
67030 LET Q$ = SEG$(Q$, 1, Q - 1)
67035 IF LEN(Q$) = 0 THEN 67070
67040 IF SEG$(Q$, LEN(Q$), LEN(Q$)) <> "?" THEN 67055
67045 LET O = 1
67050 LET Q$ = SEG$(Q$, 1, LEN(Q$) - 1)
67055 IF LEN(Q$) = 0 THEN 67070
67060 LET B$ = Q$
67065 LET T = 0
67070 SUBEND
67075 REM ---- tb_type: type name -> code (the table of the header) ---------------------------
67080 REM fixed-width list of the 22 built-in types, 5 bytes each; = ignores the padding blanks
67085 SUB "tb_type": B$, N$(), N9, C
67090 LET C = 0
67095 LET T$ = "u    i    f    s    pos  site fl   ty   lid  fid  cid  iid  blk  lab  slot reg  ri   rf   rp   rx   ry   rm   "
67100 FOR K = 1 TO 22
67105 IF SEG$(T$, 5 * K - 4, 5 * K) <> B$ THEN 67120
67110 LET C = K
67115 GOTO 67150
67120 NEXT K
67125 FOR K = 1 TO N9
67130 IF N$(K) <> B$ THEN 67145
67135 LET C = 100 + K
67140 GOTO 67150
67145 NEXT K
67150 SUBEND
67155 REM ---- tb_records --------------------------------------------------------------------
67160 REM Lines are read as: kind string, n number, then n strings. kind enum / head / rec build
67165 REM the tables; "end" (with n = 0) is the sentinel. Locals: I line, J field, V field count of
67170 REM the line, G$() the line's strings, K$ kind, A$ opcode name, Q$ pops text, S0 index of the
67175 REM first field spec in G$, Y0 set, C0 code, U the record row, K row of the current field.
67180 SUB "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), R(), R$(), F(), F$(), Z()
67185 DIM G$(40)
67190 LET Z(5) = 0
67195 LET Z(6) = 0
67200 LET Z(7) = 0
67205 LET Z(8) = 0
67210 FOR I = 1 TO Z(1) + Z(3) + 1
67215 READ S$
67220 CALL "tb_dec": P$, E(), E$(), E0, S$, K$
67225 READ V
67230 IF K$ = "end" THEN 67740
67235 IF V < 1 THEN 67735
67240 IF V > 40 THEN 67735
67245 FOR J = 1 TO V
67250 READ S$
67255 CALL "tb_dec": P$, E(), E$(), E0, S$, X$
67260 LET G$(J) = X$
67265 NEXT J
67270 IF K$ = "enum" THEN 67295
67275 IF K$ = "head" THEN 67365
67280 IF K$ = "rec" THEN 67400
67285 GOTO 67735
67290 REM ---- enum <name> <word>...
67295 IF V < 2 THEN 67735
67300 LET Z(5) = Z(5) + 1
67305 IF Z(5) > Z(1) THEN 67735
67310 IF Z(6) + V - 1 > Z(2) THEN 67735
67315 LET U = Z(5)
67320 LET N$(U) = G$(1)
67325 LET N(U, 1) = Z(6) + 1
67330 LET N(U, 2) = V - 1
67335 FOR J = 2 TO V
67340 LET Z(6) = Z(6) + 1
67345 LET W$(Z(6)) = G$(J)
67350 NEXT J
67355 GOTO 67725
67360 REM ---- head <name> <field>...
67365 LET A$ = G$(1)
67370 LET S0 = 2
67375 LET Y0 = 0
67380 LET C0 = 0
67385 LET Q$ = "0"
67390 GOTO 67525
67395 REM ---- rec <set> <code> <opcode> <pops> <field>...
67400 IF V < 4 THEN 67735
67405 LET A$ = G$(3)
67410 LET Q$ = G$(4)
67415 LET S0 = 5
67420 IF G$(1) = "A" THEN 67455
67425 IF G$(1) = "H" THEN 67465
67430 IF G$(1) = "H1" THEN 67475
67435 IF G$(1) = "HF" THEN 67485
67440 IF G$(1) = "L" THEN 67495
67445 IF G$(1) = "LF" THEN 67505
67450 GOTO 67735
67455 LET Y0 = 1
67460 GOTO 67510
67465 LET Y0 = 2
67470 GOTO 67510
67475 LET Y0 = 3
67480 GOTO 67510
67485 LET Y0 = 4
67490 GOTO 67510
67495 LET Y0 = 5
67500 GOTO 67510
67505 LET Y0 = 6
67510 CALL "io_u": G$(2), C0, T
67515 IF T <> 0 THEN 67735
67520 REM ---- the record row and its fields
67525 LET Z(7) = Z(7) + 1
67530 IF Z(7) > Z(3) THEN 67735
67535 LET U = Z(7)
67540 LET R$(U) = A$
67545 LET R(U, 1) = Y0
67550 LET R(U, 2) = C0
67555 LET R(U, 3) = Z(8) + 1
67560 LET R(U, 4) = V - S0 + 1
67565 IF Z(8) + R(U, 4) > Z(4) THEN 67735
67570 LET R(U, 5) = 0
67575 FOR J = S0 TO V
67580 CALL "tb_fspec": G$(J), X$, Y$, O, D$, T
67585 IF T <> 0 THEN 67735
67590 LET K = Z(8) + 1
67595 LET Z(8) = K
67600 LET F$(K) = X$
67605 CALL "tb_type": Y$, N$(), Z(5), Y1
67610 IF Y1 = 0 THEN 67735
67615 LET F(K, 1) = Y1
67620 LET F(K, 2) = O
67625 LET F(K, 3) = 0
67630 IF LEN(D$) = 0 THEN 67670
67635 REM the count must name an earlier u field of this record
67640 FOR H = R(U, 3) TO K - 1
67645 IF F$(H) <> D$ THEN 67660
67650 IF F(H, 1) <> 1 THEN 67660
67655 LET F(K, 3) = H - R(U, 3) + 1
67660 NEXT H
67665 IF F(K, 3) = 0 THEN 67735
67670 NEXT J
67675 REM ---- the pops expression: terms joined by +, each a number or a u field of the record
67680 LET S = 1
67685 LET P = POS(Q$, "+", S)
67690 IF P = 0 THEN 67715
67695 LET X$ = SEG$(Q$, S, P - 1)
67700 GOSUB 67755
67705 LET S = P + 1
67710 GOTO 67685
67715 LET X$ = SEG$(Q$, S, LEN(Q$))
67720 GOSUB 67755
67725 NEXT I
67730 REM falling out of the counted loop means the sentinel is missing
67735 CALL "tb_fail": P$, E(), E$(), E0
67740 IF V <> 0 THEN 67735
67745 GOTO 67830
67750 REM subroutine: add the pop term X$ to row U
67755 IF LEN(X$) = 0 THEN 67735
67760 CALL "io_u": X$, V1, T
67765 IF T = 0 THEN 67810
67770 REM a name: the u field of that name in this record
67775 LET V1 = 0
67780 FOR H = R(U, 3) TO R(U, 3) + R(U, 4) - 1
67785 IF F$(H) <> X$ THEN 67800
67790 IF F(H, 1) <> 1 THEN 67800
67795 LET V1 = -(H - R(U, 3) + 1)
67800 NEXT H
67805 IF V1 = 0 THEN 67735
67810 IF R(U, 5) >= 4 THEN 67735
67815 LET R(U, 5) = R(U, 5) + 1
67820 LET R(U, 5 + R(U, 5)) = V1
67825 RETURN
67830 SUBEND
