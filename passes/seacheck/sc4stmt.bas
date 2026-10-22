7100 REM ---- ck_blk: block B (LANGUAGE 7.2, 7.7; its scope is resolved in sea.res); M(B,9) = 1 when a
7105 REM statement ends every path ----------------------------------------------------------------
7110 SUB "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
7115 LET M(B, 9) = 0
7120 LET I = N(B, 7)
7125 IF I = 0 THEN 7155
7130 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
7135 IF M(I, 9) = 0 THEN 7145
7140 LET M(B, 9) = 1
7145 LET I = N(I, 8)
7150 GOTO 7125
7155 SUBEND
7160 REM ---- fin: an untyped constant that no context typed is i64 (LANGUAGE 4.2) ------------------
7165 SUB "fin": N(), M(), C(), X(), X$(), I
7170 IF M(I, 1) <> -1 THEN 7180
7175 CALL "stl": N(), M(), C(), X(), X$(), I, 3
7180 SUBEND
7185 REM ---- ck_cond: condition I must be a scalar bool (LANGUAGE 4.3) -----------------------------
7190 SUB "ck_cond": N(), M(), T(), C(), X(), X$(), I
7195 CALL "vu": N(), M(), T(), X(), X$(), I, D
7200 IF D <> -1 THEN 7215
7205 CALL "stl": N(), M(), C(), X(), X$(), I, 3
7210 LET D = 3
7215 IF D = 2 THEN 7230
7220 IF D = 0 THEN 7230
7225 CALL "er": N(), X(), X$(), I, "COND_BOOL", "", "", "", 0
7230 SUBEND
7235 REM ---- ck_tgt: R = the local assigned by target G (a var or a ref parameter, LANGUAGE 7.3), or
7240 REM 0 after an error: immutable locals, constants, functions and other expressions ----------
7245 SUB "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
7250 LET R = 0
7255 IF N(G, 0) = 30 THEN 7275
7260 IF M(G, 1) = 0 THEN 7330
7265 CALL "er": N(), X(), X$(), G, "BAD_TARGET", "", "", "", 0
7270 GOTO 7330
7275 LET S = M(G, 2)
7280 IF S = 0 THEN 7330
7285 IF S < 0 THEN 7325
7290 IF Y(S, 0) <> 4 THEN 7325
7295 IF Y(S, 4) = 2 THEN 7315
7300 IF Y(S, 4) = 5 THEN 7315
7305 CALL "er": N(), X(), X$(), G, "ASSIGN_IMMUTABLE", S$(N(G, 6)), "", "", 1
7310 GOTO 7330
7315 LET R = S
7320 GOTO 7330
7325 CALL "er": N(), X(), X$(), G, "BAD_TARGET", "", "", "", 0
7330 SUBEND
7335 REM ---- ck_st: statement I (LANGUAGE 7.1-7.6) ---------------------------------------------
7340 SUB "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
7345 LET M(I, 9) = 0
7350 LET X(19) = I
7355 LET K = N(I, 0)
7360 IF K < 8 THEN 7690
7365 IF K > 24 THEN 7690
7370 ON K - 7 GOTO 7375, 7375, 7690, 7690, 7690, 7385, 7395, 7405, 7415, 7540, 7575, 7635, 7690, 7645, 7660, 7675, 7685
7375 CALL "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
7380 GOTO 7690
7385 CALL "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
7390 GOTO 7690
7395 CALL "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
7400 GOTO 7690
7405 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(I, 7)
7410 GOTO 7690
7415 REM an else-if chain is walked here link by link (no recursion over its length); it ends
7420 REM every path when every block does and the chain ends with an else block
7425 LET L1 = I
7430 LET Z = 1
7435 LET X(19) = L1
7440 LET M(L1, 9) = 0
7445 LET E = N(L1, 7)
7450 LET B = N(E, 8)
7455 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
7460 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
7465 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
7470 IF M(B, 9) = 1 THEN 7480
7475 LET Z = 0
7480 IF N(L1, 1) = 1 THEN 7495
7485 LET Z = 0
7490 GOTO 7530
7495 LET G = N(B, 8)
7500 IF N(G, 0) = 24 THEN 7515
7505 LET L1 = G
7510 GOTO 7435
7515 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
7520 IF M(G, 9) = 1 THEN 7530
7525 LET Z = 0
7530 LET M(I, 9) = Z
7535 GOTO 7690
7540 LET E = N(I, 7)
7545 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
7550 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
7555 LET X(15) = X(15) + 1
7560 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
7565 LET X(15) = X(15) - 1
7570 GOTO 7690
7575 REM a range loop; any other iterable is an array (phase 1: not supported yet)
7580 LET E = N(I, 7)
7585 IF N(E, 0) = 41 THEN 7600
7590 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "arrays", "", "", 1
7595 GOTO 7690
7600 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
7605 CALL "nloc": N(), Y(), X(), X$(), S$(), N(I, 6), 3, 3, I, 1, N(I, 3), R
7610 LET M(I, 2) = R
7615 LET X(15) = X(15) + 1
7620 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
7625 LET X(15) = X(15) - 1
7630 GOTO 7690
7635 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "match", "", "", 1
7640 GOTO 7690
7645 IF X(15) > 0 THEN 7690
7650 CALL "er": N(), X(), X$(), I, "BREAK_OUTSIDE", "", "", "", 0
7655 GOTO 7690
7660 IF X(15) > 0 THEN 7690
7665 CALL "er": N(), X(), X$(), I, "CONTINUE_OUTSIDE", "", "", "", 0
7670 GOTO 7690
7675 CALL "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
7680 GOTO 7690
7685 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
7690 SUBEND
7695 REM ---- ck_let: let/var I: pattern, [type], value (LANGUAGE 7.2, 4.2, 8.4) --------------------
7700 SUB "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
7705 LET P = N(I, 7)
7710 LET E = N(P, 8)
7715 LET D = 0
7720 LET Z0 = 0
7725 LET A = N(I, 1)
7730 IF A = 0 THEN 7745
7735 LET G = E
7740 LET E = N(E, 8)
7745 LET U = N(I, 0) - 7
7750 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
7755 IF A = 0 THEN 7820
7760 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G, D
7765 IF N(P, 0) = 12 THEN 7820
7770 REM a multiple-result call for one name or _ is a result count error, before any conversion
7775 LET V = M(E, 1)
7780 IF V < 10 THEN 7800
7785 IF T(V, 0) <> 7 THEN 7800
7790 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(V, 1)), "1", "", 2
7795 GOTO 7820
7800 IF D = 0 THEN 7815
7805 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
7810 GOTO 7820
7815 CALL "fin": N(), M(), C(), X(), X$(), E
7820 LET K = N(P, 0)
7825 IF K = 11 THEN 7960
7830 IF K = 12 THEN 7975
7835 REM one name: its type is the annotation, or the value's
7840 IF A = 1 THEN 7925
7845 LET D = M(E, 1)
7850 IF D < 10 THEN 7875
7855 IF T(D, 0) <> 7 THEN 7875
7860 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(D, 1)), "1", "", 2
7865 LET D = 0
7870 GOTO 7925
7875 IF D <> -1 THEN 7920
7880 REM an untyped constant: i64, or for an unannotated var the candidate of the var rule
7885 LET D = 3
7890 IF U = 1 THEN 7910
7895 LET Z0 = 1
7900 IF M(P, 4) = 0 THEN 7910
7905 LET D = 4
7910 CALL "stl": N(), M(), C(), X(), X$(), E, D
7915 GOTO 7925
7920 CALL "vu": N(), M(), T(), X(), X$(), E, D
7925 CALL "nloc": N(), Y(), X(), X$(), S$(), N(P, 6), D, U, P, 1, N(P, 1), R
7930 LET M(P, 2) = R
7935 IF R = 0 THEN 8150
7940 IF Z0 = 0 THEN 8150
7945 REM the candidate of the var rule: an unannotated var whose initialiser was untyped
7950 LET Y(R, 6) = P
7955 GOTO 8150
7960 IF A = 1 THEN 8150
7965 CALL "fin": N(), M(), C(), X(), X$(), E
7970 GOTO 8150
7975 REM a tuple pattern: one name or _ per result of a multiple-result call
7980 LET H = N(P, 1)
7985 LET V = M(E, 1)
7990 LET V0 = 1
7995 IF V = 0 THEN 8045
8000 IF V = -1 THEN 8030
8005 IF V = 1 THEN 8040
8010 IF V < 10 THEN 8045
8015 IF T(V, 0) <> 7 THEN 8045
8020 LET V0 = T(V, 1)
8025 GOTO 8045
8030 CALL "fin": N(), M(), C(), X(), X$(), E
8035 GOTO 8045
8040 LET V0 = 0
8045 IF A = 0 THEN 8080
8050 IF D = 0 THEN 8080
8055 IF V = 0 THEN 8080
8060 CALL "tyn": T(), D, A$
8065 CALL "tyn": T(), V, B$
8070 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
8075 LET V = 0
8080 IF V = 0 THEN 8100
8085 IF V0 = H THEN 8100
8090 CALL "er": N(), X(), X$(), P, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
8095 LET V = 0
8100 LET Q = N(P, 7)
8105 FOR J = 1 TO H
8110 IF N(Q, 0) <> 10 THEN 8140
8115 LET D = 0
8120 IF V < 10 THEN 8130
8125 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
8130 CALL "nloc": N(), Y(), X(), X$(), S$(), N(Q, 6), D, U, Q, 1, N(Q, 1), R
8135 LET M(Q, 2) = R
8140 LET Q = N(Q, 8)
8145 NEXT J
8150 SUBEND
8155 REM ---- ck_asg: target op= value (LANGUAGE 7.3; x op= e is x = x op e) ------------------------
8160 SUB "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
8165 LET G = N(I, 7)
8170 LET E = N(G, 8)
8175 LET O = N(I, 1)
8180 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
8185 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
8190 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
8195 LET D = M(G, 1)
8200 IF R = 0 THEN 8450
8205 IF D = 0 THEN 8450
8210 IF O > 1 THEN 8285
8215 REM =: a multiple-result call to one target is a result count error (LANGUAGE 8.4)
8220 LET V = M(E, 1)
8225 IF V < 10 THEN 8245
8230 IF T(V, 0) <> 7 THEN 8245
8235 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(V, 1)), "1", "", 2
8240 GOTO 8455
8245 REM a candidate var stores an f64 (Decision 8), else the value converts to the target
8250 IF Y(R, 6) = 0 THEN 8275
8255 IF D <> 3 THEN 8275
8260 IF M(E, 1) <> 4 THEN 8275
8265 CALL "cand": M(), Y(), X(), R
8270 GOTO 8455
8275 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
8280 GOTO 8455
8285 CALL "vu": N(), M(), T(), X(), X$(), E, V
8290 IF V = 0 THEN 8455
8295 IF D = 2 THEN 8420
8300 IF V = 2 THEN 8420
8305 IF V > 4 THEN 8420
8310 IF D > 4 THEN 8420
8315 IF V <> -1 THEN 8330
8320 CALL "stl": N(), M(), C(), X(), X$(), E, D
8325 LET V = M(E, 1)
8330 REM the result of x op e: f64 for / and beside an f64, else i64 (LANGUAGE 6.5)
8335 LET Z = 3
8340 IF O = 5 THEN 8360
8345 IF D = 4 THEN 8360
8350 IF V = 4 THEN 8360
8355 GOTO 8365
8360 LET Z = 4
8365 IF Z = 4 THEN 8375
8370 GOTO 8455
8375 IF D = 4 THEN 8405
8380 IF Y(R, 6) = 0 THEN 8395
8385 CALL "cand": M(), Y(), X(), R
8390 GOTO 8455
8395 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", "i64", "f64", "", 2
8400 GOTO 8455
8405 IF V <> 3 THEN 8455
8410 LET M(E, 7) = 1
8415 GOTO 8455
8420 CALL "fin": N(), M(), C(), X(), X$(), E
8425 CALL "opn": O - 1, A$
8430 CALL "tyn": T(), D, B$
8435 CALL "tyn": T(), M(E, 1), C$
8440 CALL "er": N(), X(), X$(), I, "BAD_OPERANDS", A$ & "=", B$, C$, 3
8445 GOTO 8455
8450 CALL "fin": N(), M(), C(), X(), X$(), E
8455 SUBEND
8460 REM ---- ck_tasg: (t1, ..., tn) = call (LANGUAGE 7.3, 8.4, 4.2 (b)): each result to its target ---
8465 SUB "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
8470 LET H = N(I, 1)
8475 LET G = N(I, 7)
8480 FOR J = 1 TO H
8485 IF N(G, 0) = 11 THEN 8495
8490 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
8495 LET G = N(G, 8)
8500 NEXT J
8505 LET E = G
8510 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
8515 LET V = M(E, 1)
8520 LET V0 = 1
8525 IF V = 0 THEN 8590
8530 IF V = 1 THEN 8570
8535 IF V = -1 THEN 8560
8540 IF V < 10 THEN 8575
8545 IF T(V, 0) <> 7 THEN 8575
8550 LET V0 = T(V, 1)
8555 GOTO 8575
8560 CALL "fin": N(), M(), C(), X(), X$(), E
8565 GOTO 8575
8570 LET V0 = 0
8575 IF V0 = H THEN 8590
8580 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
8585 LET V = 0
8590 LET G = N(I, 7)
8595 FOR J = 1 TO H
8600 REM M(target,4) = 1: the i64 result is converted to the f64 target (the cv flag of tasg)
8605 LET M(G, 4) = 0
8610 IF N(G, 0) = 11 THEN 8710
8615 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
8620 IF R = 0 THEN 8710
8625 IF V < 10 THEN 8710
8630 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
8635 LET D0 = M(G, 1)
8640 IF D = D0 THEN 8710
8645 IF D0 = 0 THEN 8710
8650 IF D <> 3 THEN 8670
8655 IF D0 <> 4 THEN 8670
8660 LET M(G, 4) = 1
8665 GOTO 8710
8670 IF Y(R, 6) = 0 THEN 8695
8675 IF D <> 4 THEN 8695
8680 IF D0 <> 3 THEN 8695
8685 CALL "cand": M(), Y(), X(), R
8690 GOTO 8710
8695 CALL "tyn": T(), D0, A$
8700 CALL "tyn": T(), D, B$
8705 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
8710 LET G = N(G, 8)
8715 NEXT J
8720 SUBEND
8725 REM ---- ck_ret: return I of the current function X(14) (LANGUAGE 8.1, 8.4); M(I,4) = 1: tret --
8730 SUB "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
8735 LET M(I, 4) = 0
8740 LET M(I, 9) = 1
8745 LET F = X(14)
8750 LET R0 = Y(F, 7)
8755 LET D = Y(F, 2)
8760 LET H = N(I, 1)
8765 LET E = N(I, 7)
8770 FOR J = 1 TO H
8775 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
8780 LET E = N(E, 8)
8785 NEXT J
8790 LET E = N(I, 7)
8795 IF H = 0 THEN 8890
8800 IF H = 1 THEN 8900
8805 IF R0 = H THEN 8840
8810 LET J = 1
8815 IF J > H THEN 9000
8820 CALL "fin": N(), M(), C(), X(), X$(), E
8825 LET E = N(E, 8)
8830 LET J = J + 1
8835 GOTO 8815
8840 REM return (e1, ..., ek): each value to its result type
8845 FOR J = 1 TO H
8850 LET D0 = T(D + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
8855 IF D = 0 THEN 8870
8860 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D0
8865 GOTO 8875
8870 CALL "fin": N(), M(), C(), X(), X$(), E
8875 LET E = N(E, 8)
8880 NEXT J
8885 GOTO 9005
8890 IF R0 = 0 THEN 9005
8895 GOTO 9000
8900 LET V = M(E, 1)
8905 IF V < 10 THEN 8975
8910 IF T(V, 0) <> 7 THEN 8975
8915 REM return f(...) of a multiple-result call: tret when the results are exactly the function's
8920 IF R0 = 0 THEN 8965
8925 IF V = D THEN 8955
8930 IF D = 0 THEN 9005
8935 CALL "tyn": T(), D, A$
8940 CALL "tyn": T(), V, B$
8945 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
8950 GOTO 9005
8955 LET M(I, 4) = 1
8960 GOTO 9005
8965 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", "0", STR$(T(V, 1)), "", 2
8970 GOTO 9005
8975 IF R0 <> 1 THEN 8990
8980 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
8985 GOTO 9005
8990 CALL "fin": N(), M(), C(), X(), X$(), E
8995 IF V = 0 THEN 9005
9000 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(R0), STR$(H), "", 2
9005 SUBEND
