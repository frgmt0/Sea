40000 REM ====================================================================================
40002 REM sealoop part 8 (lines 40000-44999): the rewrites of 4g-1 (DESIGN 3.5.9, "What sealoop
40004 REM rewrites in 4g"): L16 match (rule 33) and L17, the stores of str elements by scalar
40006 REM indices (rules 19 and 15 (i), R17, R25). Every node they write takes the position P of
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
40495 REM ==== L17: asg X (any op) to the str element X1 by scalar indices (4g-1) ===================
40500 LET X3 = X1
40502 LET R2 = H(X, 6)
40504 GOSUB 8400
40506 LET F9 = 3
40508 GOSUB 8440
40510 LET O6$ = F9$
40512 LET P6 = H(X3, 0)
40514 LET V6 = H(H(X3, 4), 2)
40516 LET V5 = 1
40518 GOSUB 40600
40520 LET N7 = N7 - 1
40522 GOTO 5180
40535 REM ---- 40540: an L12 store (lp6tup 30300) of the .l local W3 to the target X3: step 1's
40536 REM exception, no tmp Vv, the est storing lv W3 itself (R25)
40540 LET V5 = 0
40542 LET O6$ = "set"
40544 LET V(7) = W3
40546 GOTO 40600
40595 REM ---- 40600: the block of L17 for the target X3 (its rows after P6; the root's row first,
40596 REM then the indices'), the value (V5 = 1: its rows after the target's, of type V6; V5 = 0:
40597 REM the local G = V(7)), op O6$, at P9$. Script names (lp1walk 9000): R the root (-lid), B
40598 REM the base of the checks (R, or for a ref parameter tmp B = lv R), G the value, y the read
40599 REM of a compound store, the slots 11 ... of the indices (lp3sel IX 1, IX 2)
40600 LET Y5 = X3
40602 LET C7 = 3
40604 GOSUB 15100
40606 LET V(18) = V(2)
40608 LET Y7 = H(B6, 2)
40610 GOSUB 8700
40612 IF E5 <> 5 THEN 2900
40614 IF F5 <> 0 THEN 2900
40616 LET V(54) = E5
40618 LET V(58) = S(E5)
40620 LET Q4 = 0
40622 GOSUB 15300
40624 IF N2 > 0 THEN 2900
40626 REM Y4 = 1 when the root is a ref parameter (its par record's mode)
40628 LET Y4 = 0
40630 LET Q3 = -V(2)
40632 IF Q3 > G(F0, 2) THEN 40640
40634 LET Z$ = D$(G(F0, 6) + Q3)
40636 IF SEG$(Z$, LEN(Z$) - 3, LEN(Z$)) <> " ref" THEN 40640
40638 LET Y4 = 1
40640 REM the rows cut off: B7 the root's, G7 ... G9 the indices', G5 ... G8 the value's
40642 LET B7 = O(P6, 0)
40644 LET G7 = O(B7, 0)
40646 LET G9 = H(X3, 8)
40648 LET G5 = O(G9, 0)
40650 LET G8 = O9
40652 LET O(P6, 0) = 0
40654 LET O(G9, 0) = 0
40656 LET O9 = P6
40658 LET C9 = P6
40660 GOSUB 9115
40662 LET K8 = 0
40664 IF O6$ <> "set" THEN 40700
40666 REM set: (1) the value, (2) for a ref root tmp B, (3) the indices; the root's row dropped
40668 LET N7 = N7 - 1
40670 IF V5 = 0 THEN 40680
40672 GOSUB 40800
40674 LET L8 = V6
40676 LET S$ = "= G"
40678 GOSUB 9000
40680 GOSUB 40820
40682 GOSUB 40840
40684 GOTO 40750
40695 REM ---- op set aside: (3) the indices; tmp R0 = xblk P T 2 { tmp T0 = the read (the root's
40696 REM row, the indices' tmps, the idx record), tmp Vv = the value, value bin cat }; (2)
40700 GOSUB 40840
40702 GOSUB 9115
40704 LET O(O9, 0) = B7
40706 LET O(B7, 0) = 0
40708 LET O9 = B7
40710 LET C9 = B7
40712 FOR K7 = 1 TO N3
40714 LET K8 = 10 + K7
40716 LET S$ = "L I"
40718 GOSUB 9000
40720 NEXT K7
40722 LET N7 = N7 + 1
40724 LET Q2$ = "nodes"
40726 IF N7 > N8 THEN 2930
40728 GOSUB 8060
40730 LET O(O0, 1) = H(X3, 6)
40732 LET L8 = H(X3, 2)
40734 LET K8 = 0
40736 LET S$ = "= y"
40738 GOSUB 9000
40740 GOSUB 40800
40742 LET L8 = V6
40744 LET S$ = "= G,L y,L G,bin P %1 cat,],= G"
40746 GOSUB 9000
40748 GOSUB 40820
40750 REM (4) the checks (IX 2), (5) the cow of the root, (6) the store into adat of the root
40752 LET C9 = O9
40754 GOSUB 15600
40756 GOSUB 15800
40758 LET K8 = 0
40760 LET S$ = "L R,cow P,L G,D R," & Q6$ & ",est P %5 0,}"
40762 GOTO 9000
40795 REM ---- 40800: the value's rows G5 ... G8 back at the tail
40800 LET O(O9, 0) = G5
40802 LET O9 = G8
40804 LET C9 = O9
40806 RETURN
40815 REM ---- 40820: (2) a ref parameter root is loaded into tmp B (local: B is the root itself)
40820 IF Y4 = 0 THEN 40826
40822 LET S$ = "L R,= B"
40824 GOSUB 9000
40826 RETURN
40835 REM ---- 40840: (3) the indices' rows G7 ... G9 back at the tail, each named by tmp I (IX 1)
40840 LET O(O9, 0) = G7
40842 LET O9 = G9
40844 GOSUB 15500
40846 LET C9 = O9
40848 LET K8 = 0
40850 RETURN
