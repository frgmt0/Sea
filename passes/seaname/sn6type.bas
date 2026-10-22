8600 REM ---- tylk: type node I of an entered item or a resolved region becomes rtype (M(I,4) 1,
8605 REM not yet resolved: M(I,9) 0). Its names are looked up where it stands (DESIGN 3.4.2 "Type
8610 REM nodes"; the caller sets the scope, X(12) 200000 for no locals): a base that is not one of
8615 REM f64 i64 bool str Figure Axes Lu Chol (M(I,3) its id) is a name (M(I,2) its symbol), and
8620 REM every name dim becomes rname (M(dim,2), M(dim,4)). The type itself is found by tyres. --
8625 SUB "tylk": N(), M(), Y(), W(), S$(), X(), X$(), I
8630 LET M(I, 4) = 1
8635 LET M(I, 9) = 0
8640 LET M(I, 2) = 0
8645 CALL "tyb": S$(N(I, 6)), B
8650 LET M(I, 3) = B
8655 IF B > 0 THEN 8670
8660 CALL "lk": Y(), W(), X(), X$(), S$(), N(I, 6), R
8665 LET M(I, 2) = R
8670 REM the dims, left to right: an int stays a literal (rint), a name is looked up
8675 LET J = N(I, 7)
8680 FOR K = 1 TO N(I, 2)
8685 IF N(J, 0) <> 30 THEN 8705
8690 CALL "lk": Y(), W(), X(), X$(), S$(), N(J, 6), R
8695 LET M(J, 2) = R
8700 LET M(J, 4) = 1
8705 LET J = N(J, 8)
8710 NEXT K
8715 SUBEND
8720 REM ---- tyb: B = the id of a predefined base word (f64 4, i64 3, bool 2, str 5, Figure Axes Lu
8725 REM Chol 6-9), else 0 (an identifier) -------------------------------------------------------
8730 SUB "tyb": B$, B
8735 LET B = 0
8740 LET L0 = LEN(B$)
8745 IF L0 > 6 THEN 8780
8750 IF L0 < 2 THEN 8780
8755 LET P = POS("|f64   |i64   |bool  |str   |Figure|Axes  |Lu    |Chol  |", "|" & SEG$(B$ & "      ", 1, 6) & "|")
8760 IF P = 0 THEN 8780
8765 LET P = (P - 1) / 7 + 1
8770 LET B = VAL(SEG$("43256789", P, P))
8780 SUBEND
8785 REM ---- tyres: the type of type node I, looked up by tylk (DESIGN 3.4.2 "Resolving a type
8790 REM node"): the base, then the dims left to right, then the shape, then the phase rule (2.6.2,
8795 REM step 4d: fixed-size arrays, struct types, handle types); the first error is the node's
8800 REM and its type is then 0. M(I,1) = the type (a predefined id or a T row), M(I,9) = 1 (done).
8805 REM A new array type is created here (tarr; the types limit at node X(19), set by the caller).
8810 REM Locals: B base (-1 a struct), H shape (1 s 2 v 3 m 4 fv 5 fm), V(k,0) the node of dim k,
8815 REM V(k,1..4) its value's limbs (L3..L0, two's complement), R the type. ----------------------
8820 SUB "tyres": N(), M(), Y(), T(), C(), S$(), X(), X$(), I
8825 DIM V(2, 4)
8830 LET R = 0
8835 LET M(I, 9) = 1
8840 LET H = N(I, 1)
8845 LET B = M(I, 3)
8850 IF B > 0 THEN 8885
8855 REM an identifier: an entered struct where the node stands, else no type
8860 LET S = M(I, 2)
8865 IF S <= 0 THEN 8875
8870 IF Y(S, 0) = 3 THEN 8880
8875 CALL "er": N(), X(), X$(), I, "UNKNOWN_STRUCT", "", "", "", 0
8877 GOTO 9200
8880 LET B = -1
8885 REM the dims: an rint is its value; a name must be an entered i64 constant with a value
8890 LET J = N(I, 7)
8895 FOR K = 1 TO N(I, 2)
8900 LET V(K, 0) = J
8905 IF N(J, 0) <> 25 THEN 8935
8910 LET G = M(J, 5)
8915 FOR Q = 1 TO 4
8920 LET V(K, Q) = C(G, Q)
8925 NEXT Q
8930 GOTO 9030
8935 LET S = M(J, 2)
8940 IF S <> 0 THEN 8955
8945 CALL "er": N(), X(), X$(), J, "UNDECLARED", S$(N(J, 6)), "", "", 1
8950 GOTO 9200
8955 IF S < 0 THEN 8965
8960 IF Y(S, 0) = 2 THEN 8975
8965 CALL "er": N(), X(), X$(), J, "NOT_CONSTANT", "", "", "", 0
8970 GOTO 9200
8975 LET Q = Y(S, 7)
8980 IF Q = 1 THEN 9010
8985 IF Q < 2 THEN 9200
8990 IF Q > 3 THEN 9200
8995 REM an f64 or bool constant: the extent must be i64 (rcne and rcn: no value, no error here)
9000 CALL "er": N(), X(), X$(), J, "TYPE_MISMATCH", "i64", SEG$("f64 bool", 4 * Q - 7, 5 * Q - 7), "", 2
9005 GOTO 9200
9010 LET V(K, 1) = INT(Y(S, 8) / 65536)
9015 LET V(K, 2) = Y(S, 8) - 65536 * V(K, 1)
9020 LET V(K, 3) = INT(Y(S, 9) / 65536)
9025 LET V(K, 4) = Y(S, 9) - 65536 * V(K, 3)
9030 LET J = N(J, 8)
9035 NEXT K
9040 IF H < 4 THEN 9130
9045 REM the extents of a fixed-size shape: none below 0, their product at most LIM_FIXED_ELEMS
9050 FOR K = 1 TO N(I, 2)
9055 IF V(K, 1) < 32768 THEN 9070
9060 CALL "dec": V(K, 1), V(K, 2), V(K, 3), V(K, 4), A$
9065 CALL "er": N(), X(), X$(), V(K, 0), "ARRAY_SIZE_C", A$, "", "", 1
9067 GOTO 9200
9070 NEXT K
9075 FOR K = 1 TO N(I, 2)
9080 IF V(K, 1) + V(K, 2) + V(K, 3) + V(K, 4) = 0 THEN 9130
9085 NEXT K
9090 LET P = 1
9095 FOR K = 1 TO N(I, 2)
9100 IF V(K, 1) + V(K, 2) > 0 THEN 9120
9105 LET P = P * (V(K, 3) * 65536 + V(K, 4))
9110 IF P > X(43) THEN 9120
9115 NEXT K
9117 GOTO 9130
9120 CALL "er": N(), X(), X$(), I, "FIXED_TOO_LARGE", "", "", "", 0
9125 GOTO 9200
9130 REM arrays of a handle type: never (LANGUAGE 4.1)
9135 IF B < 6 THEN 9155
9140 IF H = 1 THEN 9155
9145 CALL "er": N(), X(), X$(), I, "ELEMENT_TYPE", S$(N(I, 6)), "", "", 1
9150 GOTO 9200
9155 REM the phase rule (DESIGN 2.6.2, step 4d), after every error above
9160 LET A$ = "arrays"
9165 IF H >= 4 THEN 9195
9170 LET A$ = "structs"
9175 IF B = -1 THEN 9195
9180 LET A$ = "handle types"
9185 IF B >= 6 THEN 9195
9186 REM a str type in a signature (X(44) 1) has type 0: the signature reports it (DESIGN 2.6.2)
9187 IF B <> 5 THEN 9190
9188 IF X(44) = 1 THEN 9200
9190 LET R = B
9191 IF H = 1 THEN 9200
9192 CALL "tarr": T(), N(), X(), X$(), H - 1, B, R
9193 GOTO 9200
9195 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", A$, "", "", 1
9200 LET M(I, 1) = R
9205 SUBEND
9210 REM ---- tarr: R = the T row of the dynamic array type K (1 T[], 2 T[,]) of element id E; a new
9215 REM one takes the next id (DESIGN 3.4.2 "The type table": structurally equal types are one) --
9220 SUB "tarr": T(), N(), X(), X$(), K, E, R
9225 LET R = 10
9230 IF R > X(4) THEN 9255
9235 IF T(R, 0) <> K THEN 9245
9240 IF T(R, 1) = E THEN 9280
9245 CALL "tnext": T(), R
9250 GOTO 9230
9255 CALL "tnew": T(), N(), X(), X$(), 1, R
9260 IF R = 0 THEN 9280
9265 LET T(R, 0) = K
9270 LET T(R, 1) = E
9275 LET T(R, 9) = 9 + X(38)
9280 SUBEND
9335 REM ---- dec: R$ = the decimal text of the i64 of limbs A3..A0 (two's complement), exact for
9340 REM every value (the %d of 'invalid array size', DESIGN 2.6.2); the magnitude is divided by
9345 REM 10000 limb by limb (each step below 2^30: exact in doubles) ---------------------------
9350 SUB "dec": A3, A2, A1, A0, R$
9355 LET B3 = A3
9360 LET B2 = A2
9365 LET B1 = A1
9370 LET B0 = A0
9375 LET G = 0
9380 IF A3 < 32768 THEN 9395
9385 LET G = 1
9390 CALL "LMSUB": 0, 0, 0, 0, A3, A2, A1, A0, B3, B2, B1, B0, W
9395 LET R$ = ""
9400 REM one base-10000 digit per pass: the quotient replaces the limbs, the remainder is U
9405 LET U = 0
9410 LET V = U * 65536 + B3
9415 LET B3 = INT(V / 10000)
9420 LET U = V - 10000 * B3
9425 LET V = U * 65536 + B2
9430 LET B2 = INT(V / 10000)
9435 LET U = V - 10000 * B2
9440 LET V = U * 65536 + B1
9445 LET B1 = INT(V / 10000)
9450 LET U = V - 10000 * B1
9455 LET V = U * 65536 + B0
9460 LET B0 = INT(V / 10000)
9465 LET U = V - 10000 * B0
9470 IF B3 + B2 + B1 + B0 = 0 THEN 9485
9475 LET R$ = SEG$(STR$(10000 + U), 2, 5) & R$
9480 GOTO 9405
9485 LET R$ = STR$(U) & R$
9490 IF G = 0 THEN 9500
9495 LET R$ = "-" & R$
9500 SUBEND
9505 REM ---- tyconst: the annotations of the entered constants (DESIGN 3.4.2), looked up with no
9510 REM local in scope; those of shape s are resolved now (the constant evaluation needs them), the
9515 REM others with every other type node in file order (tyfin) ----------------------------------
9520 SUB "tyconst": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
9525 LET X(12) = 200000
9530 FOR S = 2 TO X(33)
9535 IF Y(S, 0) <> 2 THEN 9565
9540 LET F = Y(S, 3)
9545 IF N(F, 1) = 0 THEN 9565
9550 LET G = N(F, 7)
9555 CALL "tylk": N(), M(), Y(), W(), S$(), X(), X$(), G
9557 IF N(G, 1) <> 1 THEN 9565
9558 LET X(19) = G
9560 CALL "tyres": N(), M(), Y(), T(), C(), S$(), X(), X$(), G
9565 NEXT S
9570 SUBEND
9575 REM ---- tyfld: the field types of the entered structs, in sid order, each struct's fields in
9580 REM declaration order (DESIGN 3.4.2, type table step 2), with no local in scope -------------
9585 SUB "tyfld": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
9590 LET X(12) = 200000
9595 FOR S = 2 TO X(33)
9600 IF Y(S, 0) <> 3 THEN 9645
9605 LET F = Y(S, 3)
9610 LET G = N(F, 7)
9615 FOR K = 1 TO N(F, 1)
9620 LET Q = N(G, 7)
9625 LET X(19) = Q
9630 CALL "tylk": N(), M(), Y(), W(), S$(), X(), X$(), Q
9635 CALL "tyres": N(), M(), Y(), T(), C(), S$(), X(), X$(), Q
9640 LET G = N(G, 8)
9642 NEXT K
9645 NEXT S
9650 SUBEND
9655 REM ---- tyfin: every type node looked up but not yet resolved (the non-scalar annotations of
9660 REM constants, those of let and var in the walked bodies), in file order (DESIGN 3.4.2 step 4) -
9665 SUB "tyfin": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
9670 FOR I = 1 TO X(1)
9675 IF N(I, 0) <> 7 THEN 9695
9680 IF M(I, 4) <> 1 THEN 9695
9685 IF M(I, 9) = 1 THEN 9695
9688 LET X(19) = I
9690 CALL "tyres": N(), M(), Y(), T(), C(), S$(), X(), X$(), I
9695 NEXT I
9700 SUBEND
