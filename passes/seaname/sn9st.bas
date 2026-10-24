13400 REM ==== sn9st: the struct types and struct literals of sub-phase 4g-2 (DESIGN 3.4.2) =============
13405 REM ---- tyst: step 1 of the type table: one struct type per entered struct, in sid order, created
13410 REM before every other type (so its row is its id, 9 + sid): T(r,0) 5, T(r,1) the struct's symbol;
13415 REM Y(s,2) of the struct = its row (0 when the types limit stopped it, at the struct item) ------
13420 SUB "tyst": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
13425 FOR S = 2 TO X(33)
13430 IF Y(S, 0) <> 3 THEN 13465
13435 LET X(19) = Y(S, 3)
13440 CALL "tnew": T(), N(), X(), X$(), 1, R
13445 LET Y(S, 2) = R
13450 IF R = 0 THEN 13465
13455 LET T(R, 0) = 5
13460 LET T(R, 1) = S
13462 LET T(R, 9) = 9 + X(38)
13465 NEXT S
13470 SUBEND
13475 REM ---- stfd: the declaration checks of field G of the struct node F (DESIGN 3.4.2 "Struct
13480 REM declarations"): redefinition (235) at the later of two fields of one name (names are
13485 REM interned: one S$ index per name), then a name reserved for views (222) at the field -------
13490 SUB "stfd": N(), X(), X$(), S$(), F, G
13495 LET Q = N(G, 6)
13500 LET H = N(F, 7)
13505 IF H = G THEN 13530
13510 IF N(H, 6) <> Q THEN 13520
13515 CALL "er": N(), X(), X$(), G, "REDEFINITION", S$(Q), "", "", 1
13517 GOTO 13530
13520 LET H = N(H, 8)
13525 GOTO 13505
13530 IF POS("|T|flat|col|row|", "|" & S$(Q) & "|") = 0 THEN 13540
13535 CALL "er": N(), X(), X$(), G, "RESERVED_FIELD", "", "", "", 0
13540 SUBEND
13545 REM ---- strec: recursive struct (221) at the struct node of every entered struct whose type
13550 REM contains itself through its fields' types, the fields of the structs they contain and the
13555 REM elements of fixed and dynamic arrays among them, however deep: a breadth-first search from
13560 REM each struct S0 over the structs its fields contain (queue W(1..), free after the constants;
13565 REM Y(s,6) = S0 marks a struct already queued for S0) -------------------------------------
13570 SUB "strec": N(), M(), Y(), T(), W(), X(), X$()
13575 FOR S0 = 2 TO X(33)
13580 IF Y(S0, 0) <> 3 THEN 13680
13585 LET W(1) = S0
13590 LET Q = 1
13595 LET P = 0
13600 IF P >= Q THEN 13680
13605 LET P = P + 1
13610 LET G = N(Y(W(P), 3), 7)
13615 IF G = 0 THEN 13600
13620 REM the struct the field's type contains (itself, or the element of an array type), else 0
13625 LET D = M(N(G, 7), 1)
13630 LET U = 0
13635 IF D < 10 THEN 13665
13640 IF T(D, 0) = 5 THEN 13662
13645 IF T(D, 0) > 4 THEN 13665
13650 LET D = T(D, 1)
13655 IF D < 10 THEN 13665
13662 LET U = T(D, 1)
13665 IF U = 0 THEN 13675
13667 IF U <> S0 THEN 13671
13668 CALL "er": N(), X(), X$(), Y(S0, 3), "RECURSIVE_STRUCT", "", "", "", 0
13669 GOTO 13680
13671 IF Y(U, 6) = S0 THEN 13675
13672 LET Y(U, 6) = S0
13673 LET Q = Q + 1
13674 LET W(Q) = U
13675 LET G = N(G, 8)
13677 GOTO 13615
13680 NEXT S0
13685 SUBEND
13690 REM ---- rsl: struct literal J (DESIGN 3.4.2 "Struct literals"): the entered struct its name denotes
13695 REM where it stands, looked up as names are (a local of that name hides it), else none (M(J,2)
13700 REM 0); M(J,4) 1: it becomes rslit. A literal is no constant expression: the typed path fails --
13705 SUB "rsl": N(), M(), Y(), W(), S$(), X(), X$(), J
13710 CALL "fl": X()
13715 CALL "lk": N(), Y(), W(), X(), X$(), S$(), N(J, 6), R
13720 LET M(J, 2) = 0
13725 LET M(J, 4) = 1
13730 IF R <= 0 THEN 13745
13735 IF Y(R, 0) <> 3 THEN 13745
13740 LET M(J, 2) = R
13745 SUBEND
13750 REM ---- emst: the rtst record of the struct type at row R (= its id) and its rtfd records, one per
13755 REM field in declaration order: the field's name and type (0 after an error at its type node) --
13760 SUB "emst": N(), M(), Y(), T(), S$(), R
13765 LET S = T(R, 1)
13770 LET F = Y(S, 3)
13775 CALL "io_esc": S$(Y(S, 1)), 0, A$
13780 PRINT #2, "rtst " & STR$(R) & " " & A$ & " " & STR$(Y(S, 5)) & " " & STR$(N(F, 1))
13785 LET G = N(F, 7)
13790 IF G = 0 THEN 13825
13795 LET Q = M(N(G, 7), 1)
13800 IF Q < 10 THEN 13810
13805 LET Q = T(Q, 9)
13810 CALL "io_esc": S$(N(G, 6)), 0, A$
13815 PRINT #2, "rtfd " & A$ & " " & STR$(Q)
13820 LET G = N(G, 8)
13822 GOTO 13790
13825 SUBEND
