40000 REM ====================================================================================
40002 REM sealoop part 8 (lines 40000-44999): the rewrites of 4g-1 (DESIGN 3.5.9, "What sealoop
40004 REM rewrites in 4g"): L16 match (rule 33) and the entries of L17, the stores of reference and
40006 REM aggregate elements and field paths (lp9agg 45400). Every node they write takes the position P of
40008 REM the rewritten node; the patterns, arm blocks, indices and values keep their own (L-l).
40010 REM ====================================================================================
40015 REM ==== L16: match S a1 ... an (X): block P 2 { tmp S0 = S; C(1) }, C(i) = if P 1 (cond i)
40016 REM (arm block i) (C(i + 1)), the _ arm's block the innermost else part; cond i is bin eq
40017 REM (lv S0) (cs p1) for one pattern, else xblk P 2 k { tmp Qj = bin eq (lv S0) (cs pj) }
40018 REM with the value (... (Q1 bor Q2) ...) bor Qk. M1 S0, M2 the pattern arms, Q3 an arm's k, M3 its block.
40020 LET R2 = H(X, 6)
40022 GOSUB 8400
40024 LET X4 = H(X, 3)
40026 IF H(X4, 2) <> 5 THEN 2900
40028 LET N7 = N7 - 1
40030 LET U1 = 5
40032 GOSUB 8100
40034 LET M1 = U0
40036 LET C9 = H(X4, 8)
40038 LET V1 = M1
40040 GOSUB 8250
40042 LET M2 = 0
40044 LET X5 = H(X4, 4)
40046 REM ---- each arm X5: its k patterns (cs of a str) and its block X6; the last one the _ arm
40048 IF X5 = 0 THEN 2900
40050 IF H(X5, 1) <> 52 THEN 2900
40052 LET Q3 = 0
40054 LET X6 = H(X5, 3)
40056 IF H(X6, 4) = 0 THEN 40066
40058 IF H(X6, 1) <> 4 THEN 2900
40060 IF H(X6, 2) <> 5 THEN 2900
40062 LET Q3 = Q3 + 1
40064 LET X6 = H(X6, 4)
40066 IF H(X6, 4) > 0 THEN 40058
40068 IF H(X6, 1) <> 32 THEN 2900
40069 LET M3 = X6
40070 IF Q3 = 0 THEN 40140
40072 LET M2 = M2 + 1
40074 IF Q3 = 1 THEN 40078
40076 GOSUB 9115
40078 REM the cursor is the row before the arm's first pattern: lv S0 before each, its eq after
40080 LET X6 = H(X5, 3)
40082 FOR J6 = 1 TO Q3
40084 LET V1 = M1
40086 GOSUB 8200
40088 LET C9 = H(X6, 8)
40090 LET Z$ = "bin " & P9$ & " 2 eq"
40092 GOSUB 8050
40094 IF Q3 = 1 THEN 40104
40096 LET U1 = 2
40098 GOSUB 8100
40100 LET H(X6, 5) = U0
40102 LET V1 = U0
40103 GOSUB 8250
40104 LET X6 = H(X6, 4)
40106 NEXT J6
40108 IF Q3 = 1 THEN 40132
40110 REM the xblk's value: the Q tmps joined left to right by bor
40112 LET X6 = H(X5, 3)
40114 LET V1 = H(X6, 5)
40116 GOSUB 8200
40118 FOR J6 = 2 TO Q3
40120 LET X6 = H(X6, 4)
40122 LET V1 = H(X6, 5)
40124 GOSUB 8200
40126 LET Z$ = "bin " & P9$ & " 2 bor"
40128 GOSUB 8050
40129 NEXT J6
40130 LET L8 = 2
40131 GOSUB 9150
40132 LET C9 = H(M3, 8)
40134 LET X5 = H(X5, 4)
40136 GOTO 40048
40138 REM ---- the _ arm (the last), then the ifs innermost first and the block
40140 IF H(X5, 4) > 0 THEN 2900
40142 LET C9 = O9
40144 FOR J6 = 1 TO M2
40146 LET Z$ = "if " & P9$ & " 1"
40148 GOSUB 8050
40150 NEXT J6
40152 LET Z$ = "block " & P9$ & " 2"
40154 GOSUB 8050
40156 GOTO 5180
40195 REM ---- arm: written by its match's L16 only
40200 IF H(W(X), 1) <> 51 THEN 2905
40202 GOTO 5170
40495 REM ==== L17: asg X (any op) to a field path or an element by scalar indices holding counts or of
40496 REM a struct or record (4g-1: str elements; 4g-2 in general: lp9agg 45400) ======================
40500 LET X3 = X1
40502 LET R2 = H(X, 6)
40504 GOSUB 8400
40506 LET F9 = 3
40508 GOSUB 8440
40510 LET O6$ = F9$
40512 LET P6 = H(X3, 0)
40514 LET V6 = H(H(X3, 4), 2)
40516 LET V5 = 1
40517 GOSUB 40550
40518 GOSUB 45400
40520 LET N7 = N7 - 1
40522 GOTO 5180
40525 REM ---- 40530: an L12 store (lp6tup 30300) of the .l local W3 to the target X3: converted (S$
40526 REM not lv W3 alone) its conversion written as the value, as is a W3 holding no counts; else step 1's
40527 REM exception, no tmp Vv, the est storing lv W3 itself (R25)
40530 IF S$ = "L T" THEN 40538
40531 GOSUB 9000
40532 LET V6 = W6
40533 LET V5 = 1
40534 LET O6$ = "set"
40536 GOTO 45400
40538 IF C(U(W3, 1), 3) > 0 THEN 40540
40539 GOTO 40531
40540 LET V5 = 0
40542 LET O6$ = "set"
40544 LET V(7) = W3
40546 GOTO 45400
40547 REM ---- 40550 (7b): a set whose value is lv R of a .l local of sea.hirf (a home of L19's tasg
40548 REM form, seafuse) holding counts is R25's store, as L12's store (40540) of that local: V5 = 0,
40549 REM V(7) its new local, its lv row not written (the form the old L19 wrote, DESIGN 3.5.9 R25)
40550 IF O6$ <> "set" THEN 40574
40552 LET X5 = H(X3, 4)
40554 IF H(X5, 1) <> 5 THEN 40574
40556 LET R2 = H(X5, 6)
40558 LET F9 = 4
40560 GOSUB 8440
40562 IF SEG$(D$(G(F0, 6) + VAL(F9$)), 1, 6) <> "loc .l" THEN 40574
40564 FOR U4 = 1 TO U0
40566 IF U(U4, 0) = G(F0, 1) + VAL(F9$) THEN 40570
40568 NEXT U4
40569 CALL "dg_bug": P$, "a .l local of sea.hirf is not a new local"
40570 IF U(U4, 1) < 1 THEN 40574
40571 IF C(U(U4, 1), 3) = 0 THEN 40574
40572 LET V5 = 0
40573 LET V(7) = U4
40574 LET N7 = N7 - 1 + V5
40576 LET R2 = H(X, 6)
40578 RETURN
