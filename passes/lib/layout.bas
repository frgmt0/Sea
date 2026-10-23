86000 REM layout.bas: struct, record, fixed-size array layouts (DESIGN 2.6.3, 4.8); lines 86000-88999
86005 REM API: API.md. Needs diag, tables. Q(M,6), the caller's: row 0 header, 1..T9 types, above fields
86010 SUB "ly_init": Q(), C(), C$(), C0, T9, M, P$ ' predefined types 1-9 with rt.inc's SEA_ESIZE_*
86015 IF M <= T9 THEN 86090
86020 LET Q(0, 2) = T9
86025 LET Q(0, 3) = M
86030 FOR I = 2 TO 9
86035 LET N$ = "ESIZE_PTR"
86040 IF I > 4 THEN 86050
86045 LET N$ = "ESIZE_" & SEG$("BOOL I64 F64", 4 * I - 5 - INT(4 / I), 4 * I - 4) ' 2 BOOL, 3 I64, 4 F64
86050 CALL "tb_cval": C(), C$(), C0, N$, V, T
86055 IF T <> 0 THEN 86090
86060 LET Q(I, 0) = 1 + INT(I / 5) ' 2-4 scalar (1), 5-9 str and handles (2): one reference
86065 LET Q(I, 1) = V
86070 LET Q(I, 2) = V
86075 LET Q(I, 3) = INT(I / 5)
86080 NEXT I
86082 LET Q(0, 5) = Q(5, 1)
86085 GOTO 86095
86090 CALL "dg_bug": P$, "ly_init: Q has no field rows, or a constant SEA_ESIZE_* is missing"
86095 SUBEND
86100 SUB "ly_dyn": Q(), I ' type I is a dynamic array (tvec, tmat): one reference
86105 LET Q(I, 0) = 2
86110 LET Q(I, 1) = Q(0, 5)
86115 LET Q(I, 2) = Q(0, 5)
86120 LET Q(I, 3) = 1
86125 SUBEND
86130 SUB "ly_fix": Q(), I, E, N, T ' type I is N elements of type E inline (tfvec, tfmat)
86135 LET T = 1
86140 IF Q(E, 0) = 0 THEN 86185
86145 IF Q(0, 4) <> 0 THEN 86185
86150 LET Q(I, 0) = 3
86155 LET Q(I, 1) = N * Q(E, 1)
86160 LET Q(I, 2) = Q(E, 2)
86165 LET Q(I, 3) = N * Q(E, 3)
86170 LET Q(I, 4) = E
86175 LET Q(I, 5) = N
86180 LET T = 0
86185 SUBEND
86190 SUB "ly_st": Q(), I, N, T ' opens struct or record type I with N fields (tstruct, trec)
86195 LET T = 1
86200 IF Q(0, 4) <> 0 THEN 86240
86205 IF Q(0, 2) + N > Q(0, 3) THEN 86240
86210 LET Q(I, 0) = 4
86212 LET Q(I, 1) = 0
86214 LET Q(I, 3) = 0
86215 LET Q(I, 2) = 1
86220 LET Q(I, 4) = Q(0, 2) + 1
86225 LET Q(I, 5) = N
86230 LET T = 0
86235 IF N = 0 THEN 86240
86237 LET Q(0, 4) = I
86240 SUBEND
86245 SUB "ly_fd": Q(), F, T ' the next field of the open struct, of type F; the last one closes it
86250 LET T = 1
86255 LET S = Q(0, 4)
86260 IF S = 0 THEN 86340
86265 IF Q(F, 0) = 0 THEN 86340
86270 IF F = S THEN 86340
86275 LET R = Q(0, 2) + 1
86280 LET A = Q(F, 2)
86285 LET Q(R, 0) = F
86290 LET Q(R, 1) = INT((Q(S, 1) + A - 1) / A) * A ' the next multiple of the field's alignment
86295 LET Q(R, 2) = Q(S, 3)
86300 LET Q(S, 1) = Q(R, 1) + Q(F, 1)
86305 IF A <= Q(S, 2) THEN 86310
86307 LET Q(S, 2) = A
86310 LET Q(S, 3) = Q(S, 3) + Q(F, 3)
86315 LET Q(0, 2) = R
86320 LET T = 0
86325 IF R < Q(S, 4) + Q(S, 5) - 1 THEN 86340
86330 LET Q(S, 1) = INT((Q(S, 1) + Q(S, 2) - 1) / Q(S, 2)) * Q(S, 2) ' size rounded up to the alignment
86335 LET Q(0, 4) = 0
86340 SUBEND
86345 SUB "ly_fld": Q(), S, I, F, O ' F the type, O the byte offset of field I (from 0) of S
86350 LET F = Q(Q(S, 4) + I, 0)
86355 LET O = Q(Q(S, 4) + I, 1)
86360 SUBEND
86365 SUB "ly_ref": Q(), S, K, O ' O the offset of the K-th reference value of S, ascending; else -1
86370 LET O = -1
86375 IF K < 1 THEN 86460
86380 IF K > Q(S, 3) THEN 86460
86385 LET O = 0
86390 LET J = K
86392 LET U = S
86395 IF Q(U, 0) = 2 THEN 86460
86400 IF Q(U, 0) = 4 THEN 86430
86405 LET E = Q(U, 4) ' a fixed-size array: element X (from 0) holds it, as its J-th
86410 LET X = INT((J - 1) / Q(E, 3))
86415 LET O = O + X * Q(E, 1)
86420 LET J = J - X * Q(E, 3)
86425 LET U = E
86427 GOTO 86395
86430 LET R = Q(U, 4) ' a struct or record: the first field whose references reach J holds it
86435 IF Q(R, 2) + Q(Q(R, 0), 3) >= J THEN 86445
86440 LET R = R + 1
86442 GOTO 86435
86445 LET O = O + Q(R, 1)
86450 LET J = J - Q(R, 2)
86455 LET U = Q(R, 0)
86457 GOTO 86395
86460 SUBEND
86465 SUB "ly_at": Q(), S, O, F, Y ' Y 1 if S has a field (nested ones too) of type F at offset O
86470 LET Y = 0
86475 LET X = O
86477 LET U = S
86480 IF Q(U, 0) <> 4 THEN 86560
86485 LET R = Q(U, 4)
86490 LET Z = 0
86495 IF R >= Q(U, 4) + Q(U, 5) THEN 86540
86500 IF X <> Q(R, 1) THEN 86510
86505 IF Q(R, 0) = F THEN 86555
86510 IF X < Q(R, 1) THEN 86525
86515 IF X >= Q(R, 1) + Q(Q(R, 0), 1) THEN 86525
86520 LET Z = R ' the one field whose bytes hold offset X
86525 LET R = R + 1
86530 GOTO 86495
86540 IF Z = 0 THEN 86560
86545 LET X = X - Q(Z, 1)
86550 LET U = Q(Z, 0)
86552 GOTO 86480
86555 LET Y = 1
86560 SUBEND
