430 REM ---- sc_read: the header and the whole tree of sea.ast into N M C S$ (DESIGN 2.2, 3.1-3.4) ----
435 REM Every record is checked against passes.txt (opcode of set A, field count, field encodings,
440 REM enumeration words) and built with one stack (DESIGN 3.3). Fields go to the node in order:
445 REM pos to N(i,4..5), a string to N(i,6) (interned), u and enum fields to N(i,1..3) (enums as
450 REM the private codes of E1$), an i or f literal to a C row (M(i,5)).
455 REM locals: B B$ V$ enums, R R$ records, Q Q$ fields (tb_records), G record row of each kind,
460 REM K1$ kind slots, E1$ enum codes, G$ fields, U u values, L limbs, D0 stack depth, D9 prog seen
465 SUB "sc_read": P$, E(), E$(), E0, N(), M(), C(), S$(), W(), X(), X$(), F$(), N1, T$
470 DIM B(39,2), B$(39), V$(299), R(399,9), R$(399), Q(1499,3), Q$(1499), Z(8), G$(12), U(12), L(4)
475 DIM G(49), A$(1)
480 REM the 49 AST record kinds, in this pass's private order (10-byte slots "|name    ")
485 LET L$ = "prog const struct field fn param type let var pname pskip ptuple asg tasg cstmt if while "
490 LET L$ = L$ & "for match arm break continue return block int float str true false name dollar neg "
495 LET L$ = L$ & "not bin call narg ref conv index all range rangev dot array row slit rlit init ifx "
500 LET K1$ = ""
505 LET S = 1
510 LET P = POS(L$, " ", S)
515 IF P = 0 THEN 535
520 LET K1$ = K1$ & SEG$("|" & SEG$(L$, S, P - 1) & "          ", 1, 10)
525 LET S = P + 1
530 GOTO 510
535 REM the enumeration words of sea.ast and their private codes: "|binop.add=01|..."
540 LET L$ = "binop:add sub mul div mod pow matmul eq ne lt le gt ge band bor and or;"
545 LET L$ = L$ & "asgop:set add sub mul div;shape:s v m fv fm;cvtype:f64 i64 str;"
550 LET E1$ = ""
555 LET S = 1
560 IF S > LEN(L$) THEN 645
565 LET P = POS(L$, ":", S)
570 LET A$ = SEG$(L$, S, P - 1)
575 LET S = P + 1
580 LET V = 0
585 LET P = POS(L$, " ", S)
590 LET P1 = POS(L$, ";", S)
595 IF P = 0 THEN 625
600 IF P > P1 THEN 625
605 LET V = V + 1
610 LET E1$ = E1$ & "|" & A$ & "." & SEG$(L$, S, P - 1) & "=" & SEG$(STR$(100 + V), 2, 3)
615 LET S = P + 1
620 GOTO 585
625 LET V = V + 1
630 LET E1$ = E1$ & "|" & A$ & "." & SEG$(L$, S, P1 - 1) & "=" & SEG$(STR$(100 + V), 2, 3)
635 LET S = P1 + 1
640 GOTO 560
645 LET E1$ = E1$ & "|"
650 REM passes.txt, and the record row of every kind
655 LET Z(1) = 39
660 LET Z(2) = 299
665 LET Z(3) = 399
670 LET Z(4) = 1499
675 CALL "tb_records": P$, E(), E$(), E0, B(), B$(), V$(), R(), R$(), Q(), Q$(), Z()
680 FOR K = 1 TO 49
685 LET G(K) = 0
690 LET A$ = SEG$(K1$, 10 * K - 8, 10 * K)
695 FOR J = 1 TO Z(7)
700 IF R(J, 1) <> 1 THEN 715
705 IF R$(J) <> A$ THEN 715 ' = ignores the padding blanks of A$
710 LET G(K) = J
715 NEXT J
720 IF G(K) > 0 THEN 730
725 CALL "dg_bug": P$, "passes.txt has no sea.ast record " & A$
730 NEXT K
735 CALL "io_hdr": 1, P$, E(), E$(), E0, B(), B$(), V$(), Z(5), X(34), T$, F$(), 100, N1, L$
740 LET L9 = N1 + 3
745 LET D0 = 0
750 LET D9 = 0
755 REM ---- one record per pass of this loop; L$ holds it
760 IF LEN(L$) <> 4 THEN 770
765 IF L$ = "#end" THEN 1295
770 IF D9 = 1 THEN 1310
775 CALL "io_split": L$, G$(), 12, G0
780 IF G0 < 1 THEN 1310
785 LET P1 = POS(K1$, "|" & G$(1) & " ")
790 IF P1 = 0 THEN 1310
795 LET K = (P1 - 1) / 10 + 1
800 LET R0 = G(K)
805 IF G0 - 1 <> R(R0, 4) THEN 1310
810 IF X(1) < X(23) THEN 840
815 REM more nodes than the table holds: reported at the position of the node being read
820 CALL "io_pos": G$(2), F1, L1, C1, T
825 IF T <> 0 THEN 1310
830 LET A$(1) = "nodes"
835 CALL "dg_compile": P$, F$(), N1, F1, L1, C1, "TOO_LARGE", A$(), 1, E(), E$(), E0
840 LET I = X(1) + 1
845 LET X(1) = I
850 LET N(I, 0) = K
855 LET S1 = 0
860 FOR J = 1 TO R(R0, 4)
865 LET Q0 = R(R0, 3) + J - 1
870 LET Y1 = Q(Q0, 1)
875 LET F0$ = G$(J + 1)
880 LET U(J) = 0
885 IF Y1 = 1 THEN 920
890 IF Y1 = 2 THEN 950
895 IF Y1 = 3 THEN 965
900 IF Y1 = 4 THEN 1025
905 IF Y1 = 5 THEN 1070
910 IF Y1 > 100 THEN 1100
915 GOTO 1310
920 CALL "io_u": F0$, V, T
925 IF T <> 0 THEN 1310
930 LET U(J) = V
935 LET S1 = S1 + 1
940 LET N(I, S1) = V
945 GOTO 1140
950 CALL "io_i": F0$, V, K2, L(), T
955 IF T <> 0 THEN 1310
960 GOTO 975
965 CALL "io_f": F0$, L(), T
970 IF T <> 0 THEN 1310
975 IF X(5) < X(22) THEN 995
980 LET A$(1) = "constants"
985 LET F1 = INT(N(I, 4) / 1E9)
990 CALL "dg_compile": P$, F$(), N1, F1, N(I, 4) - F1 * 1E9, N(I, 5), "TOO_LARGE", A$(), 1, E(), E$(), E0
995 LET X(5) = X(5) + 1
1000 FOR H = 1 TO 4
1005 LET C(X(5), H) = L(H)
1010 NEXT H
1015 LET M(I, 5) = X(5)
1020 GOTO 1140
1025 CALL "io_unesc": F0$, 0, S0$, T
1030 IF T <> 0 THEN 1310
1035 CALL "intern": S$(), X(), S0$, H
1040 IF H > 0 THEN 1060
1045 LET A$(1) = "strings"
1050 LET F1 = INT(N(I, 4) / 1E9)
1055 CALL "dg_compile": P$, F$(), N1, F1, N(I, 4) - F1 * 1E9, N(I, 5), "TOO_LARGE", A$(), 1, E(), E$(), E0
1060 LET N(I, 6) = H
1065 GOTO 1140
1070 CALL "io_pos": F0$, F1, L1, C1, T
1075 IF T <> 0 THEN 1310
1080 IF F1 >= N1 THEN 1310
1085 LET N(I, 4) = F1 * 1E9 + L1
1090 LET N(I, 5) = C1
1095 GOTO 1140
1100 CALL "tb_word": B(), V$(), Y1 - 100, F0$, H
1105 IF H = 0 THEN 1310
1110 LET A$ = B$(Y1 - 100)
1115 LET H = POS(E1$, "|" & A$ & "." & F0$ & "=")
1120 IF H > 0 THEN 1130
1125 CALL "dg_bug": P$, "enumeration word " & A$ & "." & F0$ & " unknown to this pass"
1130 LET S1 = S1 + 1
1135 LET N(I, S1) = VAL(SEG$(E1$, H + LEN(A$) + LEN(F0$) + 3, H + LEN(A$) + LEN(F0$) + 4))
1140 NEXT J
1145 REM ---- the children: the pops of the record (DESIGN 3.3), the earliest-written first
1150 LET P0 = 0
1155 FOR H = 1 TO R(R0, 5)
1160 LET V = R(R0, 5 + H)
1165 IF V < 0 THEN 1180
1170 LET P0 = P0 + V
1175 GOTO 1185
1180 LET P0 = P0 + U(-V)
1185 NEXT H
1190 IF P0 > D0 THEN 1315
1195 LET M(I, 6) = P0
1200 LET M(I, 0) = I
1205 IF P0 = 0 THEN 1250
1210 LET N(I, 7) = W(D0 - P0 + 1)
1215 LET M(I, 0) = M(W(D0 - P0 + 1), 0)
1220 FOR H = D0 - P0 + 1 TO D0
1225 LET N(W(H), 9) = I
1230 IF H = D0 THEN 1240
1235 LET N(W(H), 8) = W(H + 1)
1240 NEXT H
1245 LET D0 = D0 - P0
1250 IF K = 1 THEN 1270
1255 LET D0 = D0 + 1
1260 LET W(D0) = I
1265 GOTO 1285
1270 IF D0 <> 0 THEN 1315
1275 LET D9 = 1
1280 LET X(17) = I
1285 CALL "io_read": 1, L$, L9, P$, E(), E$(), E0
1290 GOTO 760
1295 IF D9 = 0 THEN 1315
1300 CALL "io_end": 1, P$, E(), E$(), E0
1305 GOTO 1320
1310 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
1315 CALL "dg_internal": P$, "BAD_TREE", E(), E$(), E0
1320 SUBEND
