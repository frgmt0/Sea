7580 REM ---- ck_blk: block B (LANGUAGE 7.2, 7.7; its scope is resolved in sea.res); M(B,9) = 1 when a
7585 REM statement ends every path ----------------------------------------------------------------
7590 SUB "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
7595 LET M(B, 9) = 0
7600 LET I = N(B, 7)
7605 IF I = 0 THEN 7635
7610 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
7615 IF M(I, 9) = 0 THEN 7625
7620 LET M(B, 9) = 1
7625 LET I = N(I, 8)
7630 GOTO 7605
7635 SUBEND
7640 REM ---- fin: an untyped constant that no context typed is i64 (LANGUAGE 4.2) ------------------
7645 SUB "fin": N(), M(), C(), X(), X$(), I
7650 IF M(I, 1) <> -1 THEN 7660
7655 CALL "stl": N(), M(), C(), X(), X$(), I, 3
7660 SUBEND
7665 REM ---- ck_cond: condition I must be a scalar bool (LANGUAGE 4.3) -----------------------------
7670 SUB "ck_cond": N(), M(), T(), C(), X(), X$(), I
7675 CALL "vu": N(), M(), T(), X(), X$(), I, D
7680 IF D <> -1 THEN 7695
7685 CALL "stl": N(), M(), C(), X(), X$(), I, 3
7690 LET D = 3
7695 IF D = 2 THEN 7710
7700 IF D = 0 THEN 7710
7705 CALL "er": N(), X(), X$(), I, "COND_BOOL", "", "", "", 0
7710 SUBEND
7715 REM ---- ck_tgt: R = the local assigned by target G (a var or a ref parameter, one element or a
7720 REM selection of such a local, or of its .flat view; LANGUAGE 7.3, 5.5, 5.6), or 0 after an
7725 REM error: immutable locals, constants, functions, .T .col .row and other expressions ---------
7730 SUB "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
7735 LET R = 0
7740 LET B = G
7745 IF N(G, 0) = 30 THEN 7775
7750 IF M(G, 1) = 0 THEN 7830
7755 IF N(G, 0) <> 39 THEN 7825
7760 REM an element or a selection: the base is the local assigned, or its .flat view
7765 LET B = N(G, 7)
7770 IF N(B, 0) = 30 THEN 7775
7771 IF N(B, 0) <> 43 THEN 7825
7772 IF S$(N(B, 6)) <> "flat" THEN 7825
7773 LET B = N(B, 7)
7774 IF N(B, 0) <> 30 THEN 7825
7775 LET S = M(B, 2)
7780 IF S = 0 THEN 7830
7785 IF S < 0 THEN 7825
7790 IF Y(S, 0) <> 4 THEN 7825
7795 IF Y(S, 4) = 2 THEN 7815
7800 IF Y(S, 4) = 5 THEN 7815
7805 CALL "er": N(), X(), X$(), B, "ASSIGN_IMMUTABLE", S$(N(B, 6)), "", "", 1
7810 GOTO 7830
7815 LET R = S
7820 GOTO 7830
7825 CALL "er": N(), X(), X$(), G, "BAD_TARGET", "", "", "", 0
7830 SUBEND
7835 REM ---- ck_st: statement I (LANGUAGE 7.1-7.6) ---------------------------------------------
7840 SUB "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
7845 LET M(I, 9) = 0
7850 LET X(19) = I
7855 LET K = N(I, 0)
7860 IF K < 8 THEN 8235
7865 IF K > 24 THEN 8235
7870 ON K - 7 GOTO 7875, 7875, 8235, 8235, 8235, 7885, 7895, 7905, 7915, 8040, 8075, 8180, 8235, 8190, 8205, 8220, 8230
7875 CALL "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
7880 GOTO 8235
7885 CALL "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
7890 GOTO 8235
7895 CALL "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
7900 GOTO 8235
7905 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(I, 7)
7910 GOTO 8235
7915 REM an else-if chain is walked here link by link (no recursion over its length); it ends
7920 REM every path when every block does and the chain ends with an else block
7925 LET L1 = I
7930 LET Z = 1
7935 LET X(19) = L1
7940 LET M(L1, 9) = 0
7945 LET E = N(L1, 7)
7950 LET B = N(E, 8)
7955 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
7960 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
7965 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
7970 IF M(B, 9) = 1 THEN 7980
7975 LET Z = 0
7980 IF N(L1, 1) = 1 THEN 7995
7985 LET Z = 0
7990 GOTO 8030
7995 LET G = N(B, 8)
8000 IF N(G, 0) = 24 THEN 8015
8005 LET L1 = G
8010 GOTO 7935
8015 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
8020 IF M(G, 9) = 1 THEN 8030
8025 LET Z = 0
8030 LET M(I, 9) = Z
8035 GOTO 8235
8040 LET E = N(I, 7)
8045 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
8050 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
8055 LET X(15) = X(15) + 1
8060 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
8065 LET X(15) = X(15) - 1
8070 GOTO 8235
8075 REM a range loop (the loop variable i64), or an element loop over a vector (the variable has
8080 REM the element type; anything else: cannot iterate over, at the iterable; LANGUAGE 7.5)
8085 LET E = N(I, 7)
8090 LET D = 3
8095 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
8100 IF N(E, 0) = 41 THEN 8150
8105 CALL "vu": N(), M(), T(), X(), X$(), E, V
8110 LET D = 0
8115 IF V = 0 THEN 8150
8120 CALL "fin": N(), M(), C(), X(), X$(), E
8125 CALL "elt": T(), M(E, 1), D, K
8130 IF K = 1 THEN 8150
8135 CALL "tyn": T(), M(E, 1), A$
8140 CALL "er": N(), X(), X$(), E, "NOT_ITERABLE", A$, "", "", 1
8145 LET D = 0
8150 CALL "nloc": N(), Y(), T(), X(), X$(), S$(), N(I, 6), D, 3, I, 1, N(I, 3), R
8155 LET M(I, 2) = R
8160 LET X(15) = X(15) + 1
8165 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
8170 LET X(15) = X(15) - 1
8175 GOTO 8235
8180 CALL "ck_match": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
8185 GOTO 8235
8190 IF X(15) > 0 THEN 8235
8195 CALL "er": N(), X(), X$(), I, "BREAK_OUTSIDE", "", "", "", 0
8200 GOTO 8235
8205 IF X(15) > 0 THEN 8235
8210 CALL "er": N(), X(), X$(), I, "CONTINUE_OUTSIDE", "", "", "", 0
8215 GOTO 8235
8220 CALL "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
8225 GOTO 8235
8230 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
8235 SUBEND
8240 REM ---- ck_let: let/var I: pattern, [type], value (LANGUAGE 7.2, 4.2, 8.4) --------------------
8245 SUB "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
8250 LET P = N(I, 7)
8255 LET E = N(P, 8)
8260 LET D = 0
8265 LET Z0 = 0
8270 LET A = N(I, 1)
8275 IF A = 0 THEN 8290
8280 LET G = E
8285 LET E = N(E, 8)
8290 LET U = N(I, 0) - 7
8295 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
8300 IF A = 0 THEN 8365
8305 CALL "tyof": N(), G, D
8310 IF N(P, 0) = 12 THEN 8365
8315 REM a multiple-result call for one name or _ is a result count error, before any conversion
8320 LET V = M(E, 1)
8325 IF V < 10 THEN 8345
8330 IF T(V, 0) <> 7 THEN 8345
8335 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(V, 1)), "1", "", 2
8340 GOTO 8365
8345 IF D = 0 THEN 8360
8350 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
8355 GOTO 8365
8360 CALL "fin": N(), M(), C(), X(), X$(), E
8365 LET K = N(P, 0)
8370 IF K = 11 THEN 8505
8375 IF K = 12 THEN 8520
8380 REM one name: its type is the annotation, or the value's
8385 IF A = 1 THEN 8470
8390 LET D = M(E, 1)
8395 IF D < 10 THEN 8420
8400 IF T(D, 0) <> 7 THEN 8420
8405 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(D, 1)), "1", "", 2
8410 LET D = 0
8415 GOTO 8470
8420 IF D <> -1 THEN 8465
8425 REM an untyped constant: i64, or for an unannotated var the candidate of the var rule
8430 LET D = 3
8435 IF U = 1 THEN 8455
8440 LET Z0 = 1
8445 IF M(P, 4) = 0 THEN 8455
8450 LET D = 4
8455 CALL "stl": N(), M(), C(), X(), X$(), E, D
8460 GOTO 8470
8465 CALL "vu": N(), M(), T(), X(), X$(), E, D
8470 CALL "nloc": N(), Y(), T(), X(), X$(), S$(), N(P, 6), D, U, P, 1, N(P, 1), R
8475 LET M(P, 2) = R
8480 IF R = 0 THEN 8695
8485 IF Z0 = 0 THEN 8695
8490 REM the candidate of the var rule: an unannotated var whose initialiser was untyped
8495 LET Y(R, 6) = P
8500 GOTO 8695
8505 IF A = 1 THEN 8695
8510 CALL "fin": N(), M(), C(), X(), X$(), E
8515 GOTO 8695
8520 REM a tuple pattern: one name or _ per result of a multiple-result call
8525 LET H = N(P, 1)
8530 LET V = M(E, 1)
8535 LET V0 = 1
8540 IF V = 0 THEN 8590
8545 IF V = -1 THEN 8575
8550 IF V = 1 THEN 8585
8555 IF V < 10 THEN 8590
8560 IF T(V, 0) <> 7 THEN 8590
8565 LET V0 = T(V, 1)
8570 GOTO 8590
8575 CALL "fin": N(), M(), C(), X(), X$(), E
8580 GOTO 8590
8585 LET V0 = 0
8590 IF A = 0 THEN 8625
8595 IF D = 0 THEN 8625
8600 IF V = 0 THEN 8625
8605 CALL "tyn": T(), D, A$
8610 CALL "tyn": T(), V, B$
8615 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
8620 LET V = 0
8625 IF V = 0 THEN 8645
8630 IF V0 = H THEN 8645
8635 CALL "er": N(), X(), X$(), P, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
8640 LET V = 0
8645 LET Q = N(P, 7)
8650 FOR J = 1 TO H
8655 IF N(Q, 0) <> 10 THEN 8685
8660 LET D = 0
8665 IF V < 10 THEN 8675
8670 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
8675 CALL "nloc": N(), Y(), T(), X(), X$(), S$(), N(Q, 6), D, U, Q, 1, N(Q, 1), R
8680 LET M(Q, 2) = R
8685 LET Q = N(Q, 8)
8690 NEXT J
8695 SUBEND
8700 REM ---- ck_asg: target op= value (LANGUAGE 7.3; x op= e is x = x op e) ------------------------
8705 SUB "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
8710 LET G = N(I, 7)
8715 LET E = N(G, 8)
8720 LET O = N(I, 1)
8725 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
8730 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
8735 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
8740 LET D = M(G, 1)
8745 IF R = 0 THEN 9035
8750 IF D = 0 THEN 9035
8752 CALL "elt": T(), D, D1, K1
8753 REM S8 = 1: a selection target (an index whose type is an array, LANGUAGE 5.5)
8754 LET S8 = 0
8756 IF N(G, 0) <> 39 THEN 8758
8757 LET S8 = INT((K1 + 1) / 2)
8758 IF O > 1 THEN 8830
8760 REM =: a multiple-result call to one target is a result count error (LANGUAGE 8.4)
8765 LET V = M(E, 1)
8770 IF V < 10 THEN 8786
8775 IF T(V, 0) <> 7 THEN 8786
8780 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(V, 1)), "1", "", 2
8785 GOTO 9040
8786 IF S8 = 0 THEN 8790
8787 CALL "csel": N(), M(), T(), C(), X(), X$(), E, D
8788 GOTO 9040
8790 REM a candidate var stores an f64 (Decision 8), else the value converts to the target
8795 IF Y(R, 6) = 0 THEN 8820
8800 IF D <> 3 THEN 8820
8805 IF M(E, 1) <> 4 THEN 8820
8810 CALL "cand": M(), Y(), X(), R
8815 GOTO 9040
8820 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
8825 GOTO 9040
8830 CALL "vu": N(), M(), T(), X(), X$(), E, V
8835 IF V = 0 THEN 9040
8840 REM the element types must suit the operator (+= of str and str: Decision 45); an array target or value is broadcast (aop)
8845 CALL "elt": T(), D, D1, K1
8850 CALL "elt": T(), V, V1, K2
8851 IF D1 * V1 <> 25 THEN 8855
8852 IF O <> 2 THEN 9005
8853 IF K1 + K2 > 0 THEN 8880
8854 GOTO 9040
8855 IF D1 = 2 THEN 9005
8860 IF V1 = 2 THEN 9005
8865 IF V1 > 4 THEN 9005
8870 IF D1 > 4 THEN 9005
8875 IF K1 + K2 = 0 THEN 8900
8880 CALL "aop": N(), M(), T(), C(), X(), X$(), I, E, D, V, O
8885 GOTO 9040
8900 IF V <> -1 THEN 8915
8905 CALL "stl": N(), M(), C(), X(), X$(), E, D
8910 LET V = M(E, 1)
8915 REM the result of x op e: f64 for / and beside an f64, else i64 (LANGUAGE 6.5)
8920 LET Z = 3
8925 IF O = 5 THEN 8945
8930 IF D = 4 THEN 8945
8935 IF V = 4 THEN 8945
8940 GOTO 8950
8945 LET Z = 4
8950 IF Z = 4 THEN 8960
8955 GOTO 9040
8960 IF D = 4 THEN 8990
8965 IF Y(R, 6) = 0 THEN 8980
8970 CALL "cand": M(), Y(), X(), R
8975 GOTO 9040
8980 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", "i64", "f64", "", 2
8985 GOTO 9040
8990 IF V <> 3 THEN 9040
8995 LET M(E, 7) = 1
9000 GOTO 9040
9005 CALL "fin": N(), M(), C(), X(), X$(), E
9010 CALL "opn": O - 1, A$
9015 CALL "tyn": T(), D, B$
9020 CALL "tyn": T(), M(E, 1), C$
9025 CALL "er": N(), X(), X$(), I, "BAD_OPERANDS", A$ & "=", B$, C$, 3
9030 GOTO 9040
9035 CALL "fin": N(), M(), C(), X(), X$(), E
9040 SUBEND
9045 REM ---- ck_tasg: (t1, ..., tn) = call (LANGUAGE 7.3, 8.4, 4.2 (b)): each result to its target ---
9050 SUB "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
9055 LET H = N(I, 1)
9060 LET G = N(I, 7)
9065 FOR J = 1 TO H
9070 IF N(G, 0) = 11 THEN 9080
9075 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
9080 LET G = N(G, 8)
9085 NEXT J
9090 LET E = G
9095 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
9100 LET V = M(E, 1)
9105 LET V0 = 1
9110 IF V = 0 THEN 9175
9115 IF V = 1 THEN 9155
9120 IF V = -1 THEN 9145
9125 IF V < 10 THEN 9160
9130 IF T(V, 0) <> 7 THEN 9160
9135 LET V0 = T(V, 1)
9140 GOTO 9160
9145 CALL "fin": N(), M(), C(), X(), X$(), E
9150 GOTO 9160
9155 LET V0 = 0
9160 IF V0 = H THEN 9175
9165 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
9170 LET V = 0
9175 LET G = N(I, 7)
9180 FOR J = 1 TO H
9185 REM M(target,4): the cv of tasg (1 i64 to f64, 2 dyn, 4 fix; tcv for arrays, Decision 37)
9190 LET M(G, 4) = 0
9195 IF N(G, 0) = 11 THEN 9295
9200 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
9205 IF R = 0 THEN 9295
9210 IF V < 10 THEN 9295
9215 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
9220 LET D0 = M(G, 1)
9225 IF D = D0 THEN 9295
9230 IF D0 = 0 THEN 9295
9231 CALL "tcv": N(), M(), T(), X(), X$(), G, D, D0, Z
9232 IF Z = 1 THEN 9295
9235 IF D <> 3 THEN 9255
9240 IF D0 <> 4 THEN 9255
9245 LET M(G, 4) = 1
9250 GOTO 9295
9255 IF Y(R, 6) = 0 THEN 9280
9260 IF D <> 4 THEN 9280
9265 IF D0 <> 3 THEN 9280
9270 CALL "cand": M(), Y(), X(), R
9275 GOTO 9295
9280 CALL "tyn": T(), D0, A$
9285 CALL "tyn": T(), D, B$
9290 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
9295 LET G = N(G, 8)
9300 NEXT J
9305 SUBEND
9310 REM ---- ck_ret: return I of the current function X(14) (LANGUAGE 8.1, 8.4); M(I,4) = 1: tret --
9315 SUB "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
9320 LET M(I, 4) = 0
9325 LET M(I, 9) = 1
9330 LET F = X(14)
9335 LET R0 = Y(F, 7)
9340 LET D = Y(F, 2)
9345 LET H = N(I, 1)
9350 LET E = N(I, 7)
9355 FOR J = 1 TO H
9360 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
9365 LET E = N(E, 8)
9370 NEXT J
9375 LET E = N(I, 7)
9380 IF H = 0 THEN 9475
9385 IF H = 1 THEN 9485
9390 IF R0 = H THEN 9425
9395 LET J = 1
9400 IF J > H THEN 9585
9405 CALL "fin": N(), M(), C(), X(), X$(), E
9410 LET E = N(E, 8)
9415 LET J = J + 1
9420 GOTO 9400
9425 REM return (e1, ..., ek): each value to its result type
9430 FOR J = 1 TO H
9435 LET D0 = T(D + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
9440 IF D = 0 THEN 9455
9445 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D0
9450 GOTO 9460
9455 CALL "fin": N(), M(), C(), X(), X$(), E
9460 LET E = N(E, 8)
9465 NEXT J
9470 GOTO 9590
9475 IF R0 = 0 THEN 9590
9480 GOTO 9585
9485 LET V = M(E, 1)
9490 IF V < 10 THEN 9560
9495 IF T(V, 0) <> 7 THEN 9560
9500 REM return f(...) of a multiple-result call: tret when the results are exactly the function's
9505 IF R0 = 0 THEN 9550
9510 IF V = D THEN 9540
9515 IF D = 0 THEN 9590
9520 CALL "tyn": T(), D, A$
9525 CALL "tyn": T(), V, B$
9530 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
9535 GOTO 9590
9540 LET M(I, 4) = 1
9545 GOTO 9590
9550 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", "0", STR$(T(V, 1)), "", 2
9555 GOTO 9590
9560 IF R0 <> 1 THEN 9575
9565 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
9570 GOTO 9590
9575 CALL "fin": N(), M(), C(), X(), X$(), E
9580 IF V = 0 THEN 9590
9585 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(R0), STR$(H), "", 2
9590 SUBEND
