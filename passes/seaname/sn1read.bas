530 REM ---- sc_read: the header and the whole tree of sea.ast into N M C S$ D$ (DESIGN 2.2, 3.1-3.4) --
535 REM Every record is checked against passes.txt (opcode of set A, field count, field encodings,
540 REM enumeration words) and built with one stack (DESIGN 3.3). Fields go to the node in order:
545 REM pos to N(i,4..5), a string to N(i,6) (interned), u and enum fields to N(i,1..3) (enums as
550 REM the private codes of E1$; a second pos, the npos of for, to the next two), an i or f literal
555 REM to a C row (M(i,5), one row per distinct value), the record as read to D$(i). prog is row 0 (not counted).
560 REM locals: B B$ V$ enums, R R$ records, Q Q$ fields (tb_records), G record row of each kind,
565 REM K1$ kind slots, E1$ enum codes, G$ fields, U u values, L limbs, D0 stack depth, D9 prog seen
570 SUB "sc_read": P$, E(), E$(), E0, N(), M(), C(), S$(), W(), X(), D$(), F$(), N1, T$, H(), O()
575 DIM B(39,2), B$(39), V$(299), R(399,9), R$(399), Q(1499,3), Q$(1499), Z(8), G$(12), U(12), L(4)
580 DIM G(49), A$(1)
585 REM the 49 AST record kinds, in this pass's private order (10-byte slots "|name    ")
590 LET L$ = "prog const struct field fn param type let var pname pskip ptuple asg tasg cstmt if while "
595 LET L$ = L$ & "for match arm break continue return block int float str true false name dollar neg "
600 LET L$ = L$ & "not bin call narg ref conv index all range rangev dot array row slit rlit init ifx "
605 LET K1$ = ""
610 LET S = 1
615 LET P = POS(L$, " ", S)
620 IF P = 0 THEN 640
625 LET K1$ = K1$ & SEG$("|" & SEG$(L$, S, P - 1) & "          ", 1, 10)
630 LET S = P + 1
635 GOTO 615
640 REM the enumeration words of sea.ast and their private codes: "|binop.add=01|..."
645 LET L$ = "binop:add sub mul div mod pow matmul eq ne lt le gt ge band bor and or;"
650 LET L$ = L$ & "asgop:set add sub mul div;shape:s v m fv fm;cvtype:f64 i64 str;"
655 LET E1$ = ""
660 LET S = 1
665 IF S > LEN(L$) THEN 750
670 LET P = POS(L$, ":", S)
675 LET A$ = SEG$(L$, S, P - 1)
680 LET S = P + 1
685 LET V = 0
690 LET P = POS(L$, " ", S)
695 LET P1 = POS(L$, ";", S)
700 IF P = 0 THEN 730
705 IF P > P1 THEN 730
710 LET V = V + 1
715 LET E1$ = E1$ & "|" & A$ & "." & SEG$(L$, S, P - 1) & "=" & SEG$(STR$(100 + V), 2, 3)
720 LET S = P + 1
725 GOTO 690
730 LET V = V + 1
735 LET E1$ = E1$ & "|" & A$ & "." & SEG$(L$, S, P1 - 1) & "=" & SEG$(STR$(100 + V), 2, 3)
740 LET S = P1 + 1
745 GOTO 665
750 LET E1$ = E1$ & "|"
755 REM passes.txt, and the record row of every kind
760 LET Z(1) = 39
765 LET Z(2) = 299
770 LET Z(3) = 399
775 LET Z(4) = 1499
780 CALL "tb_records": P$, E(), E$(), E0, B(), B$(), V$(), R(), R$(), Q(), Q$(), Z()
785 FOR K = 1 TO 49
790 LET G(K) = 0
795 LET A$ = SEG$(K1$, 10 * K - 8, 10 * K)
800 FOR J = 1 TO Z(7)
805 IF R(J, 1) <> 1 THEN 820
810 IF R$(J) <> A$ THEN 820 ' = ignores the padding blanks of A$
815 LET G(K) = J
820 NEXT J
825 IF G(K) > 0 THEN 835
830 CALL "dg_bug": P$, "passes.txt has no sea.ast record " & A$
835 NEXT K
840 CALL "io_hdr": 1, P$, E(), E$(), E0, B(), B$(), V$(), Z(5), X(34), T$, F$(), 100, N1, L$
845 LET L9 = N1 + 3
850 LET D0 = 0
855 LET D9 = 0
860 REM ---- one record per pass of this loop; L$ holds it
865 IF LEN(L$) <> 4 THEN 875
870 IF L$ = "#end" THEN 1445
875 IF D9 = 1 THEN 1460
880 CALL "io_split": L$, G$(), 12, G0
885 IF G0 < 1 THEN 1460
890 LET P1 = POS(K1$, "|" & G$(1) & " ")
895 IF P1 = 0 THEN 1460
900 LET K = (P1 - 1) / 10 + 1
905 LET R0 = G(K)
910 IF G0 - 1 <> R(R0, 4) THEN 1460
915 REM prog, the last record, takes row 0: it is not counted against LIM_NODES
920 LET I = 0
925 IF K = 1 THEN 970
930 IF X(1) < X(23) THEN 960
935 REM more nodes than the table holds: reported at the position of the node being read
940 CALL "io_pos": G$(2), F1, L1, C1, T
945 IF T <> 0 THEN 1460
950 LET A$(1) = "nodes"
955 CALL "dg_compile": P$, F$(), N1, F1, L1, C1, "TOO_LARGE", A$(), 1, E(), E$(), E0
960 LET I = X(1) + 1
965 LET X(1) = I
970 LET N(I, 0) = K
972 LET D$(I) = L$
975 LET S1 = 0
980 LET Y9 = 0
985 FOR J = 1 TO R(R0, 4)
990 LET Q0 = R(R0, 3) + J - 1
995 LET Y1 = Q(Q0, 1)
1000 LET F0$ = G$(J + 1)
1005 LET U(J) = 0
1010 IF Y1 = 1 THEN 1045
1015 IF Y1 = 2 THEN 1075
1020 IF Y1 = 3 THEN 1090
1025 IF Y1 = 4 THEN 1140
1030 IF Y1 = 5 THEN 1185
1035 IF Y1 > 100 THEN 1250
1040 GOTO 1460
1045 CALL "io_u": F0$, V, T
1050 IF T <> 0 THEN 1460
1055 LET U(J) = V
1060 LET S1 = S1 + 1
1065 LET N(I, S1) = V
1070 GOTO 1290
1075 CALL "io_i": F0$, V, K2, L(), T
1080 IF T <> 0 THEN 1460
1085 GOTO 1100
1090 CALL "io_f": F0$, L(), T
1095 IF T <> 0 THEN 1460
1100 REM one C row per distinct value (LIM_CONSTS counts distinct values, DESIGN 2.7)
1105 CALL "cnew": C(), H(), X(), Y1 + 1, L(1), L(2), L(3), L(4), H1
1110 IF H1 > 0 THEN 1130
1115 LET A$(1) = "constants"
1120 LET F1 = INT(N(I, 4) / 1E9)
1125 CALL "dg_compile": P$, F$(), N1, F1, N(I, 4) - F1 * 1E9, N(I, 5), "TOO_LARGE", A$(), 1, E(), E$(), E0
1130 LET M(I, 5) = H1
1135 GOTO 1290
1140 CALL "io_unesc": F0$, 0, S0$, T
1145 IF T <> 0 THEN 1460
1150 CALL "intern": S$(), X(), O(), S0$, H
1155 IF H > 0 THEN 1175
1160 LET A$(1) = "strings"
1165 LET F1 = INT(N(I, 4) / 1E9)
1170 CALL "dg_compile": P$, F$(), N1, F1, N(I, 4) - F1 * 1E9, N(I, 5), "TOO_LARGE", A$(), 1, E(), E$(), E0
1175 LET N(I, 6) = H
1180 GOTO 1290
1185 CALL "io_pos": F0$, F1, L1, C1, T
1190 IF T <> 0 THEN 1460
1195 IF F1 >= N1 THEN 1460
1200 IF Y9 = 1 THEN 1230
1205 LET Y9 = 1
1210 LET N(I, 4) = F1 * 1E9 + L1
1215 LET N(I, 5) = C1
1220 GOTO 1290
1225 REM a later pos field (the npos of for) takes the next two of N(I,1..3)
1230 LET N(I, S1 + 1) = F1 * 1E9 + L1
1235 LET N(I, S1 + 2) = C1
1240 LET S1 = S1 + 2
1245 GOTO 1290
1250 CALL "tb_word": B(), V$(), Y1 - 100, F0$, H
1255 IF H = 0 THEN 1460
1260 LET A$ = B$(Y1 - 100)
1265 LET H = POS(E1$, "|" & A$ & "." & F0$ & "=")
1270 IF H > 0 THEN 1280
1275 CALL "dg_bug": P$, "enumeration word " & A$ & "." & F0$ & " unknown to this pass"
1280 LET S1 = S1 + 1
1285 LET N(I, S1) = VAL(SEG$(E1$, H + LEN(A$) + LEN(F0$) + 3, H + LEN(A$) + LEN(F0$) + 4))
1290 NEXT J
1295 REM ---- the children: the pops of the record (DESIGN 3.3), the earliest-written first
1300 LET P0 = 0
1305 FOR H = 1 TO R(R0, 5)
1310 LET V = R(R0, 5 + H)
1315 IF V < 0 THEN 1330
1320 LET P0 = P0 + V
1325 GOTO 1335
1330 LET P0 = P0 + U(-V)
1335 NEXT H
1340 IF P0 > D0 THEN 1465
1345 LET M(I, 6) = P0
1350 LET M(I, 0) = I
1355 IF P0 = 0 THEN 1400
1360 LET N(I, 7) = W(D0 - P0 + 1)
1365 LET M(I, 0) = M(W(D0 - P0 + 1), 0)
1370 FOR H = D0 - P0 + 1 TO D0
1375 LET N(W(H), 9) = I
1380 IF H = D0 THEN 1390
1385 LET N(W(H), 8) = W(H + 1)
1390 NEXT H
1395 LET D0 = D0 - P0
1400 IF K = 1 THEN 1420
1405 LET D0 = D0 + 1
1410 LET W(D0) = I
1415 GOTO 1435
1420 IF D0 <> 0 THEN 1465
1425 LET D9 = 1
1430 LET X(17) = I
1435 CALL "io_read": 1, L$, L9, P$, E(), E$(), E0
1440 GOTO 865
1445 IF D9 = 0 THEN 1465
1450 CALL "io_end": 1, P$, E(), E$(), E0
1455 GOTO 1470
1460 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
1465 CALL "dg_internal": P$, "BAD_TREE", E(), E$(), E0
1470 SUBEND
