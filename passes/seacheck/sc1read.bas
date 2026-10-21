485 REM ---- sc_read: the header and the whole tree of sea.ast into N M C S$ (DESIGN 2.2, 3.1-3.4) ----
490 REM Every record is checked against passes.txt (opcode of set A, field count, field encodings,
495 REM enumeration words) and built with one stack (DESIGN 3.3). Fields go to the node in order:
500 REM pos to N(i,4..5), a string to N(i,6) (interned), u and enum fields to N(i,1..3) (enums as
505 REM the private codes of E1$; a second pos, the npos of for, to the next two), an i or f literal
510 REM to a C row (M(i,5), one row per distinct value). prog is row 0 (not counted as a node).
515 REM locals: B B$ V$ enums, R R$ records, Q Q$ fields (tb_records), G record row of each kind,
520 REM K1$ kind slots, E1$ enum codes, G$ fields, U u values, L limbs, D0 stack depth, D9 prog seen
525 SUB "sc_read": P$, E(), E$(), E0, N(), M(), C(), S$(), W(), X(), X$(), F$(), N1, T$, H(), O()
530 DIM B(39,2), B$(39), V$(299), R(399,9), R$(399), Q(1499,3), Q$(1499), Z(8), G$(12), U(12), L(4)
535 DIM G(49), A$(1)
540 REM the 49 AST record kinds, in this pass's private order (10-byte slots "|name    ")
545 LET L$ = "prog const struct field fn param type let var pname pskip ptuple asg tasg cstmt if while "
550 LET L$ = L$ & "for match arm break continue return block int float str true false name dollar neg "
555 LET L$ = L$ & "not bin call narg ref conv index all range rangev dot array row slit rlit init ifx "
560 LET K1$ = ""
565 LET S = 1
570 LET P = POS(L$, " ", S)
575 IF P = 0 THEN 595
580 LET K1$ = K1$ & SEG$("|" & SEG$(L$, S, P - 1) & "          ", 1, 10)
585 LET S = P + 1
590 GOTO 570
595 REM the enumeration words of sea.ast and their private codes: "|binop.add=01|..."
600 LET L$ = "binop:add sub mul div mod pow matmul eq ne lt le gt ge band bor and or;"
605 LET L$ = L$ & "asgop:set add sub mul div;shape:s v m fv fm;cvtype:f64 i64 str;"
610 LET E1$ = ""
615 LET S = 1
620 IF S > LEN(L$) THEN 705
625 LET P = POS(L$, ":", S)
630 LET A$ = SEG$(L$, S, P - 1)
635 LET S = P + 1
640 LET V = 0
645 LET P = POS(L$, " ", S)
650 LET P1 = POS(L$, ";", S)
655 IF P = 0 THEN 685
660 IF P > P1 THEN 685
665 LET V = V + 1
670 LET E1$ = E1$ & "|" & A$ & "." & SEG$(L$, S, P - 1) & "=" & SEG$(STR$(100 + V), 2, 3)
675 LET S = P + 1
680 GOTO 645
685 LET V = V + 1
690 LET E1$ = E1$ & "|" & A$ & "." & SEG$(L$, S, P1 - 1) & "=" & SEG$(STR$(100 + V), 2, 3)
695 LET S = P1 + 1
700 GOTO 620
705 LET E1$ = E1$ & "|"
710 REM passes.txt, and the record row of every kind
715 LET Z(1) = 39
720 LET Z(2) = 299
725 LET Z(3) = 399
730 LET Z(4) = 1499
735 CALL "tb_records": P$, E(), E$(), E0, B(), B$(), V$(), R(), R$(), Q(), Q$(), Z()
740 FOR K = 1 TO 49
745 LET G(K) = 0
750 LET A$ = SEG$(K1$, 10 * K - 8, 10 * K)
755 FOR J = 1 TO Z(7)
760 IF R(J, 1) <> 1 THEN 775
765 IF R$(J) <> A$ THEN 775 ' = ignores the padding blanks of A$
770 LET G(K) = J
775 NEXT J
780 IF G(K) > 0 THEN 790
785 CALL "dg_bug": P$, "passes.txt has no sea.ast record " & A$
790 NEXT K
795 CALL "io_hdr": 1, P$, E(), E$(), E0, B(), B$(), V$(), Z(5), X(34), T$, F$(), 100, N1, L$
800 LET L9 = N1 + 3
805 LET D0 = 0
810 LET D9 = 0
815 REM ---- one record per pass of this loop; L$ holds it
820 IF LEN(L$) <> 4 THEN 830
825 IF L$ = "#end" THEN 1400
830 IF D9 = 1 THEN 1415
835 CALL "io_split": L$, G$(), 12, G0
840 IF G0 < 1 THEN 1415
845 LET P1 = POS(K1$, "|" & G$(1) & " ")
850 IF P1 = 0 THEN 1415
855 LET K = (P1 - 1) / 10 + 1
860 LET R0 = G(K)
865 IF G0 - 1 <> R(R0, 4) THEN 1415
870 REM prog, the last record, takes row 0: it is not counted against LIM_NODES
875 LET I = 0
880 IF K = 1 THEN 925
885 IF X(1) < X(23) THEN 915
890 REM more nodes than the table holds: reported at the position of the node being read
895 CALL "io_pos": G$(2), F1, L1, C1, T
900 IF T <> 0 THEN 1415
905 LET A$(1) = "nodes"
910 CALL "dg_compile": P$, F$(), N1, F1, L1, C1, "TOO_LARGE", A$(), 1, E(), E$(), E0
915 LET I = X(1) + 1
920 LET X(1) = I
925 LET N(I, 0) = K
930 LET S1 = 0
935 LET Y9 = 0
940 FOR J = 1 TO R(R0, 4)
945 LET Q0 = R(R0, 3) + J - 1
950 LET Y1 = Q(Q0, 1)
955 LET F0$ = G$(J + 1)
960 LET U(J) = 0
965 IF Y1 = 1 THEN 1000
970 IF Y1 = 2 THEN 1030
975 IF Y1 = 3 THEN 1045
980 IF Y1 = 4 THEN 1095
985 IF Y1 = 5 THEN 1140
990 IF Y1 > 100 THEN 1205
995 GOTO 1415
1000 CALL "io_u": F0$, V, T
1005 IF T <> 0 THEN 1415
1010 LET U(J) = V
1015 LET S1 = S1 + 1
1020 LET N(I, S1) = V
1025 GOTO 1245
1030 CALL "io_i": F0$, V, K2, L(), T
1035 IF T <> 0 THEN 1415
1040 GOTO 1055
1045 CALL "io_f": F0$, L(), T
1050 IF T <> 0 THEN 1415
1055 REM one C row per distinct value (LIM_CONSTS counts distinct values, DESIGN 2.7)
1060 CALL "cnew": C(), H(), X(), Y1 + 1, L(1), L(2), L(3), L(4), H1
1065 IF H1 > 0 THEN 1085
1070 LET A$(1) = "constants"
1075 LET F1 = INT(N(I, 4) / 1E9)
1080 CALL "dg_compile": P$, F$(), N1, F1, N(I, 4) - F1 * 1E9, N(I, 5), "TOO_LARGE", A$(), 1, E(), E$(), E0
1085 LET M(I, 5) = H1
1090 GOTO 1245
1095 CALL "io_unesc": F0$, 0, S0$, T
1100 IF T <> 0 THEN 1415
1105 CALL "intern": S$(), X(), O(), S0$, H
1110 IF H > 0 THEN 1130
1115 LET A$(1) = "strings"
1120 LET F1 = INT(N(I, 4) / 1E9)
1125 CALL "dg_compile": P$, F$(), N1, F1, N(I, 4) - F1 * 1E9, N(I, 5), "TOO_LARGE", A$(), 1, E(), E$(), E0
1130 LET N(I, 6) = H
1135 GOTO 1245
1140 CALL "io_pos": F0$, F1, L1, C1, T
1145 IF T <> 0 THEN 1415
1150 IF F1 >= N1 THEN 1415
1155 IF Y9 = 1 THEN 1185
1160 LET Y9 = 1
1165 LET N(I, 4) = F1 * 1E9 + L1
1170 LET N(I, 5) = C1
1175 GOTO 1245
1180 REM a later pos field (the npos of for) takes the next two of N(I,1..3)
1185 LET N(I, S1 + 1) = F1 * 1E9 + L1
1190 LET N(I, S1 + 2) = C1
1195 LET S1 = S1 + 2
1200 GOTO 1245
1205 CALL "tb_word": B(), V$(), Y1 - 100, F0$, H
1210 IF H = 0 THEN 1415
1215 LET A$ = B$(Y1 - 100)
1220 LET H = POS(E1$, "|" & A$ & "." & F0$ & "=")
1225 IF H > 0 THEN 1235
1230 CALL "dg_bug": P$, "enumeration word " & A$ & "." & F0$ & " unknown to this pass"
1235 LET S1 = S1 + 1
1240 LET N(I, S1) = VAL(SEG$(E1$, H + LEN(A$) + LEN(F0$) + 3, H + LEN(A$) + LEN(F0$) + 4))
1245 NEXT J
1250 REM ---- the children: the pops of the record (DESIGN 3.3), the earliest-written first
1255 LET P0 = 0
1260 FOR H = 1 TO R(R0, 5)
1265 LET V = R(R0, 5 + H)
1270 IF V < 0 THEN 1285
1275 LET P0 = P0 + V
1280 GOTO 1290
1285 LET P0 = P0 + U(-V)
1290 NEXT H
1295 IF P0 > D0 THEN 1420
1300 LET M(I, 6) = P0
1305 LET M(I, 0) = I
1310 IF P0 = 0 THEN 1355
1315 LET N(I, 7) = W(D0 - P0 + 1)
1320 LET M(I, 0) = M(W(D0 - P0 + 1), 0)
1325 FOR H = D0 - P0 + 1 TO D0
1330 LET N(W(H), 9) = I
1335 IF H = D0 THEN 1345
1340 LET N(W(H), 8) = W(H + 1)
1345 NEXT H
1350 LET D0 = D0 - P0
1355 IF K = 1 THEN 1375
1360 LET D0 = D0 + 1
1365 LET W(D0) = I
1370 GOTO 1390
1375 IF D0 <> 0 THEN 1420
1380 LET D9 = 1
1385 LET X(17) = I
1390 CALL "io_read": 1, L$, L9, P$, E(), E$(), E0
1395 GOTO 820
1400 IF D9 = 0 THEN 1420
1405 CALL "io_end": 1, P$, E(), E$(), E0
1410 GOTO 1425
1415 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
1420 CALL "dg_internal": P$, "BAD_TREE", E(), E$(), E0
1425 SUBEND
