13000 REM ==== sn9str: the match statements and str constants of sub-phase 4g-1 (DESIGN 3.4.2) ======
13005 REM ---- rs_mt: match I (LANGUAGE 7.6) is a resolved region from 4g-1 (DESIGN 3.4.2): its
13010 REM scrutinee, then each arm's block in order (the string patterns name nothing) -------------
13015 SUB "rs_mt": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
13020 LET E = N(I, 7)
13025 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
13030 LET A = N(E, 8)
13035 FOR H = 1 TO N(I, 1)
13040 REM the block is the arm's last child, after its k patterns
13045 LET B = N(A, 7)
13050 FOR K = 1 TO N(A, 1)
13055 LET B = N(B, 8)
13060 NEXT K
13065 CALL "rs_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
13070 LET A = N(A, 8)
13075 NEXT H
13080 SUBEND
13085 REM ---- sbin: binary operator J (O) whose left operand is a str, the right of type G2, on the
13090 REM typed path: + of two str is a str, a comparison of two str a bool (LANGUAGE 7.2, lead
13095 REM decision L-g); anything else fails it (fl) -----------------------------------------------
13100 SUB "sbin": M(), X(), J, O, G2
13105 IF G2 <> 5 THEN 13135
13110 LET M(J, 1) = 5
13115 IF O = 1 THEN 13140
13120 LET M(J, 1) = 2
13125 IF ABS(O - 10.5) < 3 THEN 13140
13130 LET M(J, 1) = 0
13135 CALL "fl": X()
13140 SUBEND
13145 REM ---- evs: the str value of node J for evx with F = 1 (a const item, cval; LANGUAGE 7.2, DESIGN
13150 REM 3.4.2): a literal, a str constant (its bytes in G$(cid)), + of two str, each value at most
13155 REM LIM_LINE_BYTES bytes (else program too large: strings at the const item X(19), lead decision
13160 REM L-f), or a comparison of two str (V 3, R0 0 or 1: byte-wise and unsigned, a proper prefix
13165 REM the smaller, lead decision L-g). The str of the stack value at P0 (evx's base B9) is
13170 REM G$(50001 + (P0 - B9) / 5), so the right operand of a bin is the next one. F = 0: V 0. --------
13175 SUB "evs": N(), M(), Y(), W(), X(), X$(), S$(), G$(), J, P0, B9, F, V, R0
13180 LET V = 0
13185 IF F = 0 THEN 13335
13190 LET G = 50001 + (P0 - B9) / 5
13195 LET K = N(J, 0)
13200 IF K = 34 THEN 13230
13205 IF K = 30 THEN 13220
13210 LET G$(G) = S$(N(J, 6))
13215 GOTO 13315
13220 LET G$(G) = G$(Y(M(J, 2), 5))
13225 GOTO 13315
13230 LET O = N(J, 1)
13235 IF O <> 1 THEN 13255
13240 IF LEN(G$(G)) + LEN(G$(G + 1)) > X(45) THEN 13325
13245 LET G$(G) = G$(G) & G$(G + 1)
13250 GOTO 13315
13255 REM a comparison: Z the sign of the first differing byte, else of the length difference
13260 LET L1 = LEN(G$(G))
13265 LET L2 = LEN(G$(G + 1))
13270 LET Z = SGN(L1 - L2)
13275 LET I = 1
13280 IF I > L1 THEN 13305
13285 IF I > L2 THEN 13305
13290 LET D = ASC(SEG$(G$(G), I, I)) - ASC(SEG$(G$(G + 1), I, I))
13295 LET I = I + 1
13300 IF D = 0 THEN 13280
13302 LET Z = SGN(D)
13305 LET V = 3
13310 LET R0 = VAL(SEG$("010010111000110000100110", 4 * (O - 8) + Z + 2, 4 * (O - 8) + Z + 2))
13312 GOTO 13335
13315 IF LEN(G$(G)) > X(45) THEN 13325
13320 LET V = 5
13322 GOTO 13335
13325 CALL "fatal": N(), X(), X$(), X(19), "strings"
13335 SUBEND
