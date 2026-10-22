12360 REM ---- sn_emit: the body of sea.res (DESIGN 3.4.1, 3.4.2): the rerr of the first error, the type
12365 REM table in id order (rtup rtvec rtmat), then every node of sea.ast in file order (= node order),
12370 REM copied as read (D$) or replaced (rfn rst rcn* rpname rfor rint rname rpowk rtype), and
12375 REM prog. A replacement keeps the record's fields and adds its own (rpowk drops pow). -------
12380 SUB "sn_emit": N(), M(), Y(), T(), C(), S$(), D$(), X(), X$(), E(), E$(), E0, P$
12385 IF X(6) = 0 THEN 12450
12390 CALL "dg_find": X$(1), E$(), E0, R
12395 IF R > 0 THEN 12405
12400 CALL "dg_bug": P$, "error " & X$(1) & " is not in the error table"
12405 CALL "pos": N(), X(7), B$
12410 LET L$ = "rerr " & B$ & " " & STR$(E(R)) & " " & STR$(X(8))
12415 FOR J = 1 TO X(8)
12420 CALL "io_esc": X$(J + 1), 0, A$
12425 LET L$ = L$ & " " & A$
12430 NEXT J
12435 PRINT #2, L$
12450 REM the types created (ttup, tarr), in id order = row order
12455 LET R = 10
12460 IF R > X(4) THEN 12510
12461 IF T(R, 0) = 7 THEN 12465
12462 LET L$ = SEG$("rtvecrtmat", 5 * T(R, 0) - 4, 5 * T(R, 0)) & " " & STR$(T(R, 9)) & " " & STR$(T(R, 1))
12463 GOTO 12485
12465 LET L$ = "rtup " & STR$(T(R, 9)) & " " & STR$(T(R, 1))
12470 FOR J = 1 TO T(R, 1)
12475 LET L$ = L$ & " " & STR$(T(R + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)))
12480 NEXT J
12485 PRINT #2, L$
12490 CALL "tnext": T(), R
12495 GOTO 12460
12510 FOR I = 1 TO X(1)
12515 CALL "sn_rec": N(), M(), Y(), T(), C(), S$(), D$(), X(), I, L$
12520 PRINT #2, L$
12525 NEXT I
12530 PRINT #2, D$(0)
12535 SUBEND
12540 REM ---- sn_rec: L$ = the sea.res record of node I --------------------------------------------
12545 SUB "sn_rec": N(), M(), Y(), T(), C(), S$(), D$(), X(), I, L$
12550 LET L$ = D$(I)
12555 LET K = N(I, 0)
12560 IF K = 25 THEN 12605
12565 IF K = 30 THEN 12645
12570 IF K = 10 THEN 12710
12575 IF K = 18 THEN 12710
12580 IF K = 34 THEN 12725
12585 IF K = 2 THEN 12750
12590 IF K = 3 THEN 12840
12595 IF K = 5 THEN 12860
12597 IF K = 7 THEN 12920
12600 GOTO 12935
12605 REM rint: the literal's value as f64 bits when exact in f64 (2^63 is read as -2^63, whose
12610 REM bits #C3E0000000000000 3.4.1 asks for), else -
12615 LET H = M(I, 5)
12620 CALL "FEFRI": C(H, 1), C(H, 2), C(H, 3), C(H, 4), R3, R2, R1, R0, Z
12625 LET A$ = "-"
12630 IF Z <> 0 THEN 12640
12635 CALL "LMHEX": R3, R2, R1, R0, A$
12640 LET L$ = "r" & L$ & " " & A$
12642 GOTO 12935
12645 REM rname k ref: loc lid, cst cid, fn fid, st sid, pd 0, none 0
12650 IF M(I, 4) <> 1 THEN 12935
12655 LET S = M(I, 2)
12660 LET A$ = "none 0"
12665 IF S = 0 THEN 12700
12670 LET A$ = "pd 0"
12675 IF S < 0 THEN 12700
12680 LET Q = Y(S, 0)
12682 LET A$ = "fn"
12684 IF Q = 1 THEN 12695
12686 LET A$ = "cst"
12688 IF Q = 2 THEN 12695
12690 LET A$ = "st"
12692 IF Q = 3 THEN 12695
12694 LET A$ = "loc"
12695 LET A$ = A$ & " " & STR$(Y(S, 5))
12700 LET L$ = "r" & L$ & " " & A$
12705 GOTO 12935
12710 REM rpname, rfor: the lid of the local declared
12715 IF M(I, 4) <> 1 THEN 12935
12720 LET L$ = "r" & L$ & " " & STR$(Y(M(I, 2), 5))
12722 GOTO 12935
12725 REM rpowk k: the operator field (pow) is dropped
12730 IF M(I, 8) <= 0 THEN 12935
12735 CALL "pos": N(), I, B$
12740 LET L$ = "rpowk " & B$ & " " & STR$(M(I, 8) - 10)
12745 GOTO 12935
12750 REM an entered const: its outcome (cval): rcni rcnf rcnb a value, rcne a failure, rcn none
12755 LET S = M(I, 2)
12760 IF S = 0 THEN 12935
12765 LET L$ = SEG$(L$, 6, LEN(L$)) & " " & STR$(Y(S, 5))
12770 LET V = Y(S, 7)
12775 IF V = 3 THEN 12825
12780 IF V > 3 THEN 12800
12785 LET H = Y(S, 8)
12787 LET G = Y(S, 9)
12790 LET R3 = INT(H / 65536)
12792 LET R1 = INT(G / 65536)
12794 IF V = 2 THEN 12815
12796 CALL "LMFMT": R3, H - 65536 * R3, R1, G - 65536 * R1, A$
12798 LET L$ = "rcni" & L$ & " " & A$
12799 GOTO 12935
12800 IF Y(S, 4) = 0 THEN 12835
12805 CALL "pos": N(), Y(S, 9), B$
12810 LET L$ = "rcne" & L$ & " " & SEG$("ovf div0", 4 * Y(S, 4) - 3, 5 * Y(S, 4) - 2) & " " & B$
12812 GOTO 12935
12815 CALL "LMHEX": R3, H - 65536 * R3, R1, G - 65536 * R1, A$
12820 LET L$ = "rcnf" & L$ & " " & A$
12822 GOTO 12935
12825 LET L$ = "rcnb" & L$ & " " & STR$(Y(S, 8))
12830 GOTO 12935
12835 LET L$ = "rcn" & L$
12837 GOTO 12935
12840 REM an entered struct: its sid
12845 IF M(I, 2) = 0 THEN 12935
12850 LET L$ = "rst" & SEG$(L$, 7, LEN(L$)) & " " & STR$(Y(M(I, 2), 5))
12855 GOTO 12935
12860 REM an entered fn: fid, the result type and the parameter types (an rtup by its id)
12865 LET S = M(I, 2)
12870 IF S = 0 THEN 12935
12875 LET Q = Y(S, 2)
12880 IF Q < 10 THEN 12890
12885 LET Q = T(Q, 9)
12890 LET L$ = "rfn" & SEG$(L$, 3, LEN(L$)) & " " & STR$(Y(S, 5)) & " " & STR$(Q)
12895 LET G = N(I, 7)
12900 FOR J = 1 TO Y(S, 6)
12905 LET Q = M(G, 1)
12906 IF Q < 10 THEN 12908
12907 LET Q = T(Q, 9)
12908 LET L$ = L$ & " " & STR$(Q)
12910 LET G = N(G, 8)
12915 NEXT J
12917 GOTO 12935
12920 REM rtype: the resolved type of a type node (0 after an error; a created type by its id)
12922 IF M(I, 4) <> 1 THEN 12935
12924 LET Q = M(I, 1)
12926 IF Q < 10 THEN 12930
12928 LET Q = T(Q, 9)
12930 LET L$ = "r" & L$ & " " & STR$(Q)
12935 SUBEND
