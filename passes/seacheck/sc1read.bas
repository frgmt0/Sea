450 REM ---- sc_read: the header and the whole tree of sea.ast into N M C S$ (DESIGN 2.2, 3.1-3.4) ----
455 REM Every record is checked against passes.txt (opcode of set A, field count, field encodings,
460 REM enumeration words) and built with one stack (DESIGN 3.3). Fields go to the node in order:
465 REM pos to N(i,4..5), a string to N(i,6) (interned), u and enum fields to N(i,1..3) (enums as
470 REM the private codes of E1$; a second pos, the npos of for, to the next two), an i or f literal
475 REM to a C row (M(i,5), one row per distinct value). prog is row 0 (not counted as a node).
480 REM locals: B B$ V$ enums, R R$ records, Q Q$ fields (tb_records), G record row of each kind,
485 REM K1$ kind slots, E1$ enum codes, G$ fields, U u values, L limbs, D0 stack depth, D9 prog seen
490 SUB "sc_read": P$, E(), E$(), E0, N(), M(), C(), S$(), W(), X(), X$(), F$(), N1, T$, H(), O()
495 DIM B(39,2), B$(39), V$(299), R(399,9), R$(399), Q(1499,3), Q$(1499), Z(8), G$(12), U(12), L(4)
500 DIM G(49), A$(1)
505 REM the 49 AST record kinds, in this pass's private order (10-byte slots "|name    ")
510 LET L$ = "prog const struct field fn param type let var pname pskip ptuple asg tasg cstmt if while "
515 LET L$ = L$ & "for match arm break continue return block int float str true false name dollar neg "
520 LET L$ = L$ & "not bin call narg ref conv index all range rangev dot array row slit rlit init ifx "
525 LET K1$ = ""
530 LET S = 1
535 LET P = POS(L$, " ", S)
540 IF P = 0 THEN 560
545 LET K1$ = K1$ & SEG$("|" & SEG$(L$, S, P - 1) & "          ", 1, 10)
550 LET S = P + 1
555 GOTO 535
560 REM the enumeration words of sea.ast and their private codes: "|binop.add=01|..."
565 LET L$ = "binop:add sub mul div mod pow matmul eq ne lt le gt ge band bor and or;"
570 LET L$ = L$ & "asgop:set add sub mul div;shape:s v m fv fm;cvtype:f64 i64 str;"
575 LET E1$ = ""
580 LET S = 1
585 IF S > LEN(L$) THEN 670
590 LET P = POS(L$, ":", S)
595 LET A$ = SEG$(L$, S, P - 1)
600 LET S = P + 1
605 LET V = 0
610 LET P = POS(L$, " ", S)
615 LET P1 = POS(L$, ";", S)
620 IF P = 0 THEN 650
625 IF P > P1 THEN 650
630 LET V = V + 1
635 LET E1$ = E1$ & "|" & A$ & "." & SEG$(L$, S, P - 1) & "=" & SEG$(STR$(100 + V), 2, 3)
640 LET S = P + 1
645 GOTO 610
650 LET V = V + 1
655 LET E1$ = E1$ & "|" & A$ & "." & SEG$(L$, S, P1 - 1) & "=" & SEG$(STR$(100 + V), 2, 3)
660 LET S = P1 + 1
665 GOTO 585
670 LET E1$ = E1$ & "|"
675 REM passes.txt, and the record row of every kind
680 LET Z(1) = 39
685 LET Z(2) = 299
690 LET Z(3) = 399
695 LET Z(4) = 1499
700 CALL "tb_records": P$, E(), E$(), E0, B(), B$(), V$(), R(), R$(), Q(), Q$(), Z()
705 FOR K = 1 TO 49
710 LET G(K) = 0
715 LET A$ = SEG$(K1$, 10 * K - 8, 10 * K)
720 FOR J = 1 TO Z(7)
725 IF R(J, 1) <> 1 THEN 740
730 IF R$(J) <> A$ THEN 740 ' = ignores the padding blanks of A$
735 LET G(K) = J
740 NEXT J
745 IF G(K) > 0 THEN 755
750 CALL "dg_bug": P$, "passes.txt has no sea.ast record " & A$
755 NEXT K
760 CALL "io_hdr": 1, P$, E(), E$(), E0, B(), B$(), V$(), Z(5), X(34), T$, F$(), 100, N1, L$
765 LET L9 = N1 + 3
770 LET D0 = 0
775 LET D9 = 0
780 REM ---- one record per pass of this loop; L$ holds it
785 IF LEN(L$) <> 4 THEN 795
790 IF L$ = "#end" THEN 1365
795 IF D9 = 1 THEN 1380
800 CALL "io_split": L$, G$(), 12, G0
805 IF G0 < 1 THEN 1380
810 LET P1 = POS(K1$, "|" & G$(1) & " ")
815 IF P1 = 0 THEN 1380
820 LET K = (P1 - 1) / 10 + 1
825 LET R0 = G(K)
830 IF G0 - 1 <> R(R0, 4) THEN 1380
835 REM prog, the last record, takes row 0: it is not counted against LIM_NODES
840 LET I = 0
845 IF K = 1 THEN 890
850 IF X(1) < X(23) THEN 880
855 REM more nodes than the table holds: reported at the position of the node being read
860 CALL "io_pos": G$(2), F1, L1, C1, T
865 IF T <> 0 THEN 1380
870 LET A$(1) = "nodes"
875 CALL "dg_compile": P$, F$(), N1, F1, L1, C1, "TOO_LARGE", A$(), 1, E(), E$(), E0
880 LET I = X(1) + 1
885 LET X(1) = I
890 LET N(I, 0) = K
895 LET S1 = 0
900 LET Y9 = 0
905 FOR J = 1 TO R(R0, 4)
910 LET Q0 = R(R0, 3) + J - 1
915 LET Y1 = Q(Q0, 1)
920 LET F0$ = G$(J + 1)
925 LET U(J) = 0
930 IF Y1 = 1 THEN 965
935 IF Y1 = 2 THEN 995
940 IF Y1 = 3 THEN 1010
945 IF Y1 = 4 THEN 1060
950 IF Y1 = 5 THEN 1105
955 IF Y1 > 100 THEN 1170
960 GOTO 1380
965 CALL "io_u": F0$, V, T
970 IF T <> 0 THEN 1380
975 LET U(J) = V
980 LET S1 = S1 + 1
985 LET N(I, S1) = V
990 GOTO 1210
995 CALL "io_i": F0$, V, K2, L(), T
1000 IF T <> 0 THEN 1380
1005 GOTO 1020
1010 CALL "io_f": F0$, L(), T
1015 IF T <> 0 THEN 1380
1020 REM one C row per distinct value (LIM_CONSTS counts distinct values, DESIGN 2.7)
1025 CALL "cnew": C(), H(), X(), Y1 + 1, L(1), L(2), L(3), L(4), H1
1030 IF H1 > 0 THEN 1050
1035 LET A$(1) = "constants"
1040 LET F1 = INT(N(I, 4) / 1E9)
1045 CALL "dg_compile": P$, F$(), N1, F1, N(I, 4) - F1 * 1E9, N(I, 5), "TOO_LARGE", A$(), 1, E(), E$(), E0
1050 LET M(I, 5) = H1
1055 GOTO 1210
1060 CALL "io_unesc": F0$, 0, S0$, T
1065 IF T <> 0 THEN 1380
1070 CALL "intern": S$(), X(), O(), S0$, H
1075 IF H > 0 THEN 1095
1080 LET A$(1) = "strings"
1085 LET F1 = INT(N(I, 4) / 1E9)
1090 CALL "dg_compile": P$, F$(), N1, F1, N(I, 4) - F1 * 1E9, N(I, 5), "TOO_LARGE", A$(), 1, E(), E$(), E0
1095 LET N(I, 6) = H
1100 GOTO 1210
1105 CALL "io_pos": F0$, F1, L1, C1, T
1110 IF T <> 0 THEN 1380
1115 IF F1 >= N1 THEN 1380
1120 IF Y9 = 1 THEN 1150
1125 LET Y9 = 1
1130 LET N(I, 4) = F1 * 1E9 + L1
1135 LET N(I, 5) = C1
1140 GOTO 1210
1145 REM a later pos field (the npos of for) takes the next two of N(I,1..3)
1150 LET N(I, S1 + 1) = F1 * 1E9 + L1
1155 LET N(I, S1 + 2) = C1
1160 LET S1 = S1 + 2
1165 GOTO 1210
1170 CALL "tb_word": B(), V$(), Y1 - 100, F0$, H
1175 IF H = 0 THEN 1380
1180 LET A$ = B$(Y1 - 100)
1185 LET H = POS(E1$, "|" & A$ & "." & F0$ & "=")
1190 IF H > 0 THEN 1200
1195 CALL "dg_bug": P$, "enumeration word " & A$ & "." & F0$ & " unknown to this pass"
1200 LET S1 = S1 + 1
1205 LET N(I, S1) = VAL(SEG$(E1$, H + LEN(A$) + LEN(F0$) + 3, H + LEN(A$) + LEN(F0$) + 4))
1210 NEXT J
1215 REM ---- the children: the pops of the record (DESIGN 3.3), the earliest-written first
1220 LET P0 = 0
1225 FOR H = 1 TO R(R0, 5)
1230 LET V = R(R0, 5 + H)
1235 IF V < 0 THEN 1250
1240 LET P0 = P0 + V
1245 GOTO 1255
1250 LET P0 = P0 + U(-V)
1255 NEXT H
1260 IF P0 > D0 THEN 1385
1265 LET M(I, 6) = P0
1270 LET M(I, 0) = I
1275 IF P0 = 0 THEN 1320
1280 LET N(I, 7) = W(D0 - P0 + 1)
1285 LET M(I, 0) = M(W(D0 - P0 + 1), 0)
1290 FOR H = D0 - P0 + 1 TO D0
1295 LET N(W(H), 9) = I
1300 IF H = D0 THEN 1310
1305 LET N(W(H), 8) = W(H + 1)
1310 NEXT H
1315 LET D0 = D0 - P0
1320 IF K = 1 THEN 1340
1325 LET D0 = D0 + 1
1330 LET W(D0) = I
1335 GOTO 1355
1340 IF D0 <> 0 THEN 1385
1345 LET D9 = 1
1350 LET X(17) = I
1355 CALL "io_read": 1, L$, L9, P$, E(), E$(), E0
1360 GOTO 785
1365 IF D9 = 0 THEN 1385
1370 CALL "io_end": 1, P$, E(), E$(), E0
1375 GOTO 1390
1380 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
1385 CALL "dg_internal": P$, "BAD_TREE", E(), E$(), E0
1390 SUBEND
