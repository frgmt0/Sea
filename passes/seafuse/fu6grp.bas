50000 REM ====================================================================================
50002 REM seafuse part 6 (lines 50000-54999): the units of statements (DESIGN 2.12.4 F1 (3), F2,
50004 REM F2 (6); Decision 96; L-eq, L-er, L-es, L-fe, L-ff; the lead's reading D1). Analysis
50006 REM (50030, from fu4fan): in each block a group grows greedily from its first groupable
50008 REM statement (a bind of a new local or an asg set to a whole array variable whose value is a
50010 REM fused tree) while the next one has the first one's rank, reads a value an earlier one
50012 REM binds or assigns only as a whole-array leaf of its tree (then a kind-5 leaf, read as that
50014 REM statement's element Ei), assigns no variable another one assigns or reads otherwise, and
50016 REM no failing root came before it; a group of two or more is a unit, and so is a lone asg set
50018 REM to a whole array whose tree reads that array only as whole-array leaves (F1 (5)), or to a
50020 REM selection of a variable its tree does not read. Statement table while building or writing
50022 REM a unit: V(3000 + 20 i + f), f: 1 the node, 2 kind (1 bind, 3 whole target, 4 selection
50024 REM target), 3 the tree's root, 4 stored (1) or not, 5 the local or target lid, 6 the record of
50026 REM its position, 7 its array in a copy (a U row or -lid), 8 O, 9 the test E, 10 its data in a
50028 REM copy, 11 the root's slot, 12 1 when its tree reads its own target only as whole leaves.
50029 REM A unit's statements: Y(S,2) the first, Y(S,5) i; Y(first,4) n. 16, 17: a tbind's components (52490).
50030 FOR E1 = 1 TO H0
50032 IF H(E1, 1) <> 32 THEN 50060
50034 LET E2 = 0
50036 LET X5 = H(E1, 3)
50038 IF X5 = 0 THEN 50056
50040 IF E2 = 0 THEN 50046
50042 GOSUB 50200
50044 IF C3 = 1 THEN 50052
50046 GOSUB 50400
50048 GOSUB 50300
50050 IF C3 = 0 THEN 50054
50052 GOSUB 50500
50054 LET X5 = H(X5, 4)
50055 GOTO 50038
50056 GOSUB 50400
50060 NEXT E1
50062 RETURN
50095 REM ---- 50100: the last statement X of a unit (role 6): its generation (51000)
50100 GOTO 51000
50195 REM ---- 50200: C3 = 1 if statement X5 joins the group S1 ... S(E2) (F2 (1)-(4), L-er)
50200 LET C3 = 0
50202 IF E4 = 1 THEN 50298
50204 IF E2 >= 60 THEN 50298
50206 LET G9 = E2 + 1
50208 GOSUB 50600
50210 IF C4 = 0 THEN 50298
50212 IF C4 = 4 THEN 50298
50214 IF V(3000 + 20 * G9 + 14) <> V(3034) THEN 50298
50215 IF V(3000 + 20 * G9 + 12) = 0 THEN 50298
50216 REM its reads: of a value of S1 ... S(E2) only as a whole-array leaf (a kind-5 leaf later)
50218 LET X6 = X5
50220 GOSUB 30660
50222 FOR X8 = X7 TO X5
50224 IF H(X8, 1) <> 5 THEN 50236
50226 IF Y(X8, 1) = 4 THEN 50236
50228 IF X8 = H(X5, 3) THEN 50236
50230 GOSUB 50700
50232 IF C5 = 0 THEN 50236
50234 IF C5 < 0 THEN 50296
50236 NEXT X8
50238 REM its target: no earlier one's; earlier reads of it only as whole-array leaves of a tree
50240 IF C4 <> 3 THEN 50290
50242 LET C6 = V(3000 + 20 * G9 + 5)
50244 FOR C7 = 1 TO E2
50246 IF V(3000 + 20 * C7 + 5) = C6 THEN 50296
50248 LET X6 = V(3000 + 20 * C7 + 1)
50250 GOSUB 30660
50252 FOR X8 = X7 TO X6
50254 IF H(X8, 1) <> 5 THEN 50262
50256 GOSUB 50750
50258 IF C5 <> C6 THEN 50262
50260 IF Y(X8, 7) * 10 + Y(X8, 4) <> V(3000 + 20 * C7 + 3) * 10 + 2 THEN 50296
50262 NEXT X8
50264 NEXT C7
50290 GOTO 52750
50296 RETURN
50298 RETURN
50299 REM ---- 50300: C3 = 1 if statement X5 starts a group (groupable, 50600; a whole target only when
50300 REM its tree reads it as its whole-array leaves alone, field 12, F1 (5)); a selection store ends it at once
50302 LET C3 = 0
50304 LET G9 = 1
50306 GOSUB 50600
50308 IF C4 = 0 THEN 50320
50309 IF V(3035) > 0 THEN 50320
50310 LET E2 = 0
50312 LET E4 = 0
50314 IF C4 < 4 THEN 50316
50315 LET E4 = 1
50316 IF C4 <> 3 THEN 50318
50317 IF V(3032) = 0 THEN 52790
50318 GOTO 52760
50320 RETURN
50395 REM ---- 50400: the group S1 ... S(E2) ends: a unit when it has two statements, or is one store
50396 REM whose tree reads its target only as whole-array leaves (a selection's: not at all); a
50397 REM lone store's tree is fused in place otherwise (role 2, Decision 111)
50400 IF E2 = 0 THEN 50498
50402 IF E2 > 1 THEN 50440
50403 IF Y(V(3023), 0) = 0 THEN 50496
50404 LET C4 = V(3022)
50406 IF C4 < 3 THEN 50496
50408 LET C6 = V(3025)
50410 LET X6 = V(3023)
50412 GOSUB 30660
50414 FOR X8 = X7 TO X6
50416 IF H(X8, 1) <> 5 THEN 50424
50418 GOSUB 50750
50420 IF C5 <> C6 THEN 50424
50422 IF C4 = 4 THEN 50490
50423 IF Y(X8, 7) * 10 + Y(X8, 4) <> X6 * 10 + 2 THEN 50490
50424 NEXT X8
50440 REM the unit: statements role 3 (the last 6), its trees' nodes not written, targets role 4
50442 FOR C7 = 1 TO E2
50444 LET X6 = V(3000 + 20 * C7 + 1)
50446 LET Y(X6, 1) = 3
50448 LET Y(X6, 2) = V(3021)
50450 LET Y(X6, 5) = C7
50452 LET X3 = V(3000 + 20 * C7 + 3)
50454 GOSUB 30600
50455 GOSUB 52317
50456 LET Y(X3, 1) = 1
50458 IF V(3000 + 20 * C7 + 2) < 3 THEN 50464
50460 LET X9 = H(V(3000 + 20 * C7 + 1), 3)
50462 GOSUB 50900
50464 NEXT C7
50466 LET Y(V(3021), 4) = E2
50468 LET Y(V(3000 + 20 * E2 + 1), 1) = 6
50470 GOTO 50496
50490 LET X3 = V(3023)
50492 GOTO 52780
50496 LET E2 = 0
50498 RETURN
50499 REM ---- 50500: X5 (statement G9 = E2 + 1, examined) joins: its reads of earlier values become
50500 REM kind-5 leaves (role 4, Y(.,5) the statement read); a failing root ends the group
50502 LET E2 = E2 + 1
50503 GOSUB 52420
50504 IF Y(V(3000 + 20 * E2 + 3), 0) < 2 THEN 50506
50505 LET E4 = 1
50506 IF E2 = 1 THEN 50520
50507 LET G9 = E2
50508 LET X6 = V(3000 + 20 * E2 + 3)
50510 GOSUB 30660
50512 FOR X8 = X7 TO X6
50513 IF H(X8, 1) <> 5 THEN 50519
50514 GOSUB 50700
50515 IF C5 <= 0 THEN 50519
50516 IF Y(X8, 7) <> X6 THEN 52430
50517 LET Y(X8, 4) = 5
50518 GOTO 52436
50519 NEXT X8
50520 RETURN
50595 REM ---- 50600: C4 = the kind of statement X5 as statement G9 (1 bind, 3 whole target, 4
50596 REM selection target of S R A indices, 0 not groupable): a bind or an asg set whose value is
50597 REM the root of a fused array tree; its table row filled
50600 LET C4 = 0
50602 LET V(3000 + 20 * G9 + 1) = X5
50604 LET V(3000 + 20 * G9 + 6) = H(X5, 6)
50605 LET V(3000 + 20 * G9 + 15) = 0
50606 LET V(3000 + 20 * G9 + 12) = 1
50607 GOSUB 52480
50608 LET R2 = H(X5, 6)
50610 LET Z$ = D$(R2)
50612 LET F9 = 3
50614 GOSUB 8440
50616 LET X9 = H(X5, 3)
50618 IF H(X5, 1) = 20 THEN 50644
50619 IF H(X5, 1) = 21 THEN 52490
50620 IF H(X5, 1) <> 23 THEN 50699
50622 IF F9$ <> "set" THEN 50699
50624 LET X8 = X9
50626 LET X9 = H(X9, 4)
50628 LET C4 = 3
50630 IF H(X8, 1) = 5 THEN 50650
50632 LET C4 = 0
50634 IF H(X8, 1) <> 39 THEN 50699
50636 IF H(H(X8, 3), 1) <> 5 THEN 50699
50638 GOSUB 50800
50639 IF C4 = 0 THEN 50699
50640 LET X8 = H(X8, 3)
50642 GOTO 50650
50644 LET C4 = 1
50646 LET V(3000 + 20 * G9 + 5) = VAL(F9$)
50648 GOTO 52360
50650 GOSUB 50750
50652 LET V(3000 + 20 * G9 + 5) = C5
50660 REM the value: a fused tree's root (not a leaf, not a barrier, no role yet), of an array type
50662 IF Y(X9, 0) = 0 THEN 52300
50664 IF Y(X9, 2) <> X9 THEN 50696
50666 IF Y(X9, 1) > H7 THEN 50696
50668 IF H(X9, 2) <= 9 THEN 50696
50670 LET V(3000 + 20 * G9 + 2) = C4
50672 LET V(3000 + 20 * G9 + 3) = X9
50673 GOSUB 52470
50674 IF C4 <> 3 THEN 50699
50675 REM a whole target: 12 = 0 when its tree reads it otherwise than as its whole-array leaves
50676 LET X6 = X9
50677 GOSUB 30660
50678 FOR X8 = X7 TO X9
50680 IF H(X8, 1) <> 5 THEN 50688
50682 GOSUB 50750
50684 IF C5 <> V(3000 + 20 * G9 + 5) THEN 50688
50686 IF Y(X8, 7) * 10 + Y(X8, 4) = X9 * 10 + 2 THEN 50688
50687 LET V(3000 + 20 * G9 + 12) = 0
50688 NEXT X8
50690 RETURN
50696 LET C4 = 0
50699 RETURN
50700 REM ---- 50700: C5 for the lv X8 in the tree of statement G9: 0 when it reads no value of S1
50701 REM ... S(G9 - 1), j when it reads Sj's as a whole-array leaf of that tree, else -1
50702 GOSUB 50750
50704 FOR C7 = 1 TO G9 - 1
50706 GOSUB 52500
50707 IF K3 > 0 THEN 50714
50708 NEXT C7
50710 LET C5 = 0
50712 RETURN
50714 LET C5 = C7
50716 IF Y(X8, 7) * 10 + Y(X8, 4) = V(3000 + 20 * G9 + 3) * 10 + 2 THEN 50712
50717 GOTO 52440
50718 LET C5 = -1
50720 RETURN
50745 REM ---- 50750: C5 = the lid of the lv X8
50750 LET R2 = H(X8, 6)
50752 LET Z$ = D$(R2)
50754 LET F9 = 4
50756 GOSUB 8440
50758 LET C5 = VAL(F9$)
50760 RETURN
50795 REM ---- 50800: C4 = 4 when the idx X8 (value X9) is an L6 target stored in place (F1 (3), (5)):
50796 REM one index per dimension of S R A or M, or one MM of a matrix; the kept count the value's
50797 REM rank; the value reads no lv of the target's root (5) (ii) read strictly, implementer reading)
50800 LET C4 = 0
50802 LET J8 = 0
50804 LET V7 = 0
50806 LET W8 = 0
50808 LET X7 = H(H(X8, 3), 4)
50810 IF X7 = 0 THEN 50840
50812 LET J8 = J8 + 1
50814 LET E7 = H(X7, 2)
50816 IF E7 = 3 THEN 50836
50818 IF H(X7, 1) = 16 THEN 50834
50820 IF H(X7, 1) = 46 THEN 50834
50822 IF E7 <= 9 THEN 50868
50824 IF T(E7, 2) <> 2 THEN 50868
50826 IF T(E7, 1) = 1 THEN 50834
50828 LET W8 = 1
50834 LET V7 = V7 + 1
50836 LET X7 = H(X7, 4)
50838 GOTO 50810
50840 IF J8 + W8 <> T(H(H(X8, 3), 2), 1) THEN 50868
50842 IF V7 <> T(H(X9, 2), 1) THEN 50868
50844 IF W8 * J8 > 1 THEN 50868
50846 LET J7 = X8
50848 LET X8 = H(J7, 3)
50850 GOSUB 50750
50852 LET W8 = C5
50854 LET X6 = X9
50856 GOSUB 30660
50858 FOR X8 = X7 TO X9
50860 IF H(X8, 1) <> 5 THEN 50864
50861 GOSUB 50750
50862 IF C5 = W8 THEN 50866
50864 NEXT X8
50865 LET C4 = 4
50866 LET X8 = J7
50868 RETURN
50895 REM ---- 50900: the target X9 of a unit's store not written (role 4): a whole target's lv, a
50896 REM selection's whole subtree (its index records are written by IX 1, 51450)
50900 LET Y(X9, 1) = 4
50902 IF H(X9, 1) <> 39 THEN 50912
50904 LET X6 = X9
50906 GOSUB 30660
50908 FOR X8 = X7 TO X9
50909 LET Y(X8, 1) = 4
50910 NEXT X8
50912 RETURN
50995 REM ---- 51000: the unit whose last statement is X (D1): its table (50600); each tree's leaf and
50996 REM check phase at P (S1's position); n = 1: a block in place of the store (51300); else the
50997 REM stored locals' bind X = anew, then block P n { the reuse prologues (51200), the space test
50998 REM (Si's extents equal S1's, folded by band), if (it) { the fused copy } { the split copy } }
50999 REM in the enclosing block, whose count grows by the statements added (H(block,5))
51000 LET H5 = Y(X, 2)
51001 LET I9 = H5
51002 LET H9 = Y(H5, 4)
51004 LET H7 = 1
51006 LET X5 = H5
51008 FOR H8 = 1 TO H9
51010 LET G9 = H8
51012 GOSUB 50600
51014 LET V(3000 + 20 * H8 + 4) = 0
51015 GOSUB 52624
51016 IF C4 < 3 THEN 51020
51018 LET V(3000 + 20 * H8 + 4) = 1
51020 LET V(3000 + 20 * H8 + 7) = -V(3000 + 20 * H8 + 5)
51022 LET X5 = H(X5, 4)
51024 NEXT H8
51026 GOSUB 51600
51028 LET R2 = H(H5, 6)
51030 GOSUB 8400
51032 LET U$ = P9$
51034 LET R9 = R2
51036 LET R7 = R2
51038 LET S0 = 199
51040 LET Z7 = 0
51042 LET Z8 = 0
51044 LET H6 = H9
51046 LET Q8 = 0
51048 GOSUB 9115
51050 FOR H8 = 1 TO H9
51052 LET R8 = V(3000 + 20 * H8 + 3)
51054 GOSUB 40100
51055 GOSUB 52330
51056 LET K8 = Y(R8, 3)
51058 LET V(3000 + 20 * H8 + 11) = K8
51059 GOSUB 51800
51060 GOSUB 52720
51062 NEXT H8
51064 IF H9 = 1 THEN 51300
51066 REM the stored locals: lv extents, anew at Si's position, bind lid (D1)
51068 FOR H8 = 1 TO H9
51069 GOSUB 52530
51070 IF V(3000 + 20 * H8 + 2) <> 1 THEN 51084
51072 IF V(3000 + 20 * H8 + 4) = 0 THEN 51084
51074 GOSUB 51900
51076 LET R2 = V(3000 + 20 * H8 + 6)
51078 GOSUB 8400
51080 LET Q9$ = P9$
51081 LET P9$ = U$
51082 LET S$ = A1$
51083 GOSUB 9000
51084 IF V(3000 + 20 * H8 + 2) <> 1 THEN 51088
51085 IF V(3000 + 20 * H8 + 4) = 0 THEN 51088
51086 LET Z$ = "bind " & Q9$ & " " & STR$(V(3000 + 20 * H8 + 5))
51087 GOSUB 8050
51088 NEXT H8
51089 GOSUB 56662
51090 LET K8 = 0
51091 LET S$ = "{"
51092 GOSUB 9000
51094 FOR H8 = 1 TO H9
51096 IF V(3000 + 20 * H8 + 2) <> 3 THEN 51100
51098 GOSUB 51204
51100 NEXT H8
51101 REM the space test: bin eq of Si's extents and S1's (G, or R C), folded by band (tmp f)
51102 LET R8 = V(3023)
51104 GOSUB 40990
51106 FOR H8 = 2 TO H9
51108 LET K8 = V(3000 + 20 * H8 + 11)
51110 LET S$ = "L n,L G,bin P 2 eq"
51112 IF R4 = 1 THEN 51116
51114 LET S$ = "L r,L R,bin P 2 eq,L c,L C,bin P 2 eq,bin P 2 band"
51116 IF H8 = 2 THEN 51120
51118 LET S$ = S$ & ",bin P 2 band"
51120 GOSUB 9000
51121 GOSUB 52460
51122 NEXT H8
51124 LET K8 = 0
51126 LET S$ = "= f,L f,?"
51128 GOSUB 9000
51130 REM the fused copy: the data of the stored locals and targets in statement order, then of the
51131 REM array leaves in leaf order; the nest of S1's space, each statement's F bound to its Ei
51132 LET Q8 = 1
51134 LET E8 = 1
51136 LET E9 = H9
51138 LET F8 = 0
51140 FOR H8 = 1 TO H9
51142 GOSUB 52340
51143 GOSUB 52550
51144 LET V(3000 + 20 * H8 + 10) = V(3000 + 20 * H8 + 4)
51146 IF V(3000 + 20 * H8 + 4) = 0 THEN 51150
51148 GOSUB 51500
51150 NEXT H8
51152 GOSUB 40640
51154 LET R8 = V(3023)
51156 GOSUB 40990
51158 GOSUB 40700
51160 LET S$ = "|"
51162 GOSUB 9000
51163 REM the split copy: per statement (an unstored local into a tmp of a new array), its result's
51164 REM data, then its leaves', its own nest
51166 LET Q8 = 2
51168 FOR H8 = 1 TO H9
51170 LET E8 = H8
51172 LET E9 = H8
51174 LET R8 = V(3000 + 20 * H8 + 3)
51176 LET V(3000 + 20 * H8 + 10) = 1
51177 IF V(3000 + 20 * H8 + 2) = 2 THEN 52450
51178 IF V(3000 + 20 * H8 + 4) = 1 THEN 51188
51179 IF V(3000 + 20 * H8 + 17) > 0 THEN 52594
51180 GOSUB 51900
51182 LET S$ = A2$
51184 GOSUB 9000
51186 LET V(3000 + 20 * H8 + 7) = V(48)
51188 GOSUB 51500
51190 GOSUB 40640
51192 LET R8 = V(3000 + 20 * H8 + 3)
51194 GOSUB 40990
51196 GOSUB 52710
51197 GOSUB 40700
51198 NEXT H8
51199 LET K8 = 0
51200 GOTO 51240
51201 REM ---- 51202: the reuse prologue of the whole target of statement H8 (R-f, F2 (6)): tmp X =
51202 REM ext(V, d) and E = their bin eq with the space's (band), if E { cow V }, bind O = lv V, if
51203 REM not E { asg set V anew }; O, E in its table row
51204 GOSUB 51900
51206 LET V(48) = V(3000 + 20 * H8 + 7)
51207 IF F4 = 1 THEN 51224
51208 LET S$ = "X v 0,= X,L X,L n,bin P 2 eq,= I"
51210 IF R4 = 1 THEN 51214
51212 LET S$ = "X v 0,= X,X v 1,= W,L X,L r,bin P 2 eq,L W,L c,bin P 2 eq,bin P 2 band,= I"
51214 LET S$ = S$ & ",L I,?,L v,cow P,),L v,B N,L I,un P 2 not,?,L v," & A3$ & ",asg P set,)"
51216 GOSUB 9000
51218 LET V(3000 + 20 * H8 + 8) = V(100 + 25 * K8 + 18)
51220 LET V(3000 + 20 * H8 + 9) = V(100 + 25 * K8 + 16)
51222 RETURN
51223 REM a fixed V: written in its home in place (rule 27), no prologue, no O
51224 LET V(3000 + 20 * H8 + 8) = 0
51226 RETURN
51240 LET S$ = "),}"
51242 GOSUB 9000
51243 GOSUB 56840
51244 LET H(W(H5), 5) = H(W(H5), 5) + M(Z0, 1) - H9
51246 LET Z0 = Z0 - 1
51248 LET N7 = N7 - 1
51250 LET H6 = 0
51252 LET H7 = 0
51254 GOTO 5190
51295 REM ---- 51300: a lone store (R-f): the block of the leaf and check phase, the prologue, the
51296 REM data of V then of the leaves (of O where the tree reads V), the nest storing into V
51300 IF V(3022) <> 3 THEN 52000
51302 LET H8 = 1
51304 GOSUB 51204
51306 LET Q8 = 2
51308 LET E8 = 1
51310 LET E9 = 1
51312 LET V(3030) = 1
51314 GOSUB 51500
51316 GOSUB 40640
51318 LET R8 = V(3023)
51320 GOSUB 40990
51322 LET F8 = Y(R8, 6)
51324 GOSUB 40700
51326 LET K8 = 0
51328 LET S$ = "}"
51330 GOSUB 9000
51332 LET N7 = N7 - 1
51334 LET H6 = 0
51336 LET H7 = 0
51338 GOTO 5190
51495 REM ---- 51500: the data w of statement H8's array v (its root's slot)
51500 LET K8 = V(3000 + 20 * H8 + 11)
51502 LET V(48) = V(3000 + 20 * H8 + 7)
51504 LET S$ = "D v,= w"
51506 GOTO 9000
51595 REM ---- 51600: the stored flag of each bind: its local read after the unit (an lv of its lid
51596 REM among the records after the current one, to the end of the function)
51600 FOR R2 = R1 + 1 TO D0
51602 IF R(P(R2, 0), 0) = 36 THEN 51622
51604 IF R(P(R2, 0), 0) <> 5 THEN 51620
51606 LET Z$ = D$(R2)
51608 LET F9 = 4
51610 GOSUB 8440
51611 LET K6 = VAL(F9$)
51612 FOR H8 = 1 TO H9
51613 GOSUB 52520
51614 IF V(3000 + 20 * H8 + 2) * 100000 + V(3000 + 20 * H8 + 5) <> 100000 + K6 THEN 51618
51616 LET V(3000 + 20 * H8 + 4) = 1
51618 NEXT H8
51620 NEXT R2
51622 RETURN
51695 REM ---- 51700: C6 = O when the whole-array leaf D2 is an lv of a whole target of the unit (R33)
51700 LET C6 = 0
51702 IF H6 = 0 THEN 51716
51704 IF H(D2, 1) <> 5 THEN 51716
51706 LET X8 = D2
51708 GOSUB 50750
51710 FOR C7 = 1 TO H6
51712 IF V(3000 + 20 * C7 + 2) * 1000000 + V(3000 + 20 * C7 + 5) <> 3000000 + C5 THEN 51715
51714 LET C6 = V(3000 + 20 * C7 + 8)
51715 NEXT C7
51716 RETURN
51795 REM ---- 51800: a fixed root's static extents into its slot's n or r c (ci tmps at P; a selection store: R-n)
51800 LET Q0 = 100 + 25 * K8
51801 GOSUB 41413
51802 IF V(Q0 + 21) = 0 THEN 51812
51803 IF V(3000 + 20 * H8 + 2) = 4 THEN 51814
51804 LET S$ = "C " & STR$(T(Y7, 0)) & ",= n"
51806 IF V(Q0 + 6) = 1 THEN 51810
51808 LET S$ = "C " & STR$(T(Y7, 0)) & ",= r,C " & STR$(T(Y7, 4)) & ",= c"
51810 GOSUB 9000
51812 RETURN
51813 REM a selection store's fixed matrix root: its first operand's extents (40490, R-n); a vector's static n
51814 IF V(Q0 + 6) = 1 THEN 51804
51815 LET V(Q0 + 8) = V(7)
51816 LET V(Q0 + 10) = V(18)
51817 LET V(Q0 + 3) = V(3)
51818 RETURN
51895 REM ---- 51900: of statement H8's root (slot K8): R4 F4, its type (%0), A1$ A2$ A3$ an anew of
51896 REM it with its extents (at Q, a tmp v at P, at P)
51900 LET K8 = V(3000 + 20 * H8 + 11)
51902 LET Q0 = 100 + 25 * K8
51904 LET R4 = V(Q0 + 6)
51906 LET F4 = V(Q0 + 21)
51908 LET V(53) = H(V(3000 + 20 * H8 + 3), 2)
51910 LET A3$ = "L n,anew P %0 0 1"
51912 IF R4 = 1 THEN 51916
51914 LET A3$ = "L r,L c,anew P %0 0 2"
51916 IF F4 = 0 THEN 51920
51918 LET A3$ = "anew P %0 0 0"
51920 LET A1$ = A3$
51922 LET C5 = POS(A1$, " P ")
51924 LET A1$ = SEG$(A1$, 1, C5) & "Q" & SEG$(A1$, C5 + 2, LEN(A1$))
51926 LET A2$ = A3$ & ",= v"
51928 RETURN
51995 REM ---- 52000: a lone selection store (R-g, L6 steps 2-7, F1 (3)): after the value's leaf and
51996 REM check phase, the target's IX 1 and IX 2 (its index records written here, 52200; kinds S R A
51997 REM M MM, 52180), IX 3 (kept extents n or r c), the shape check against the value's G or R C (at
51998 REM P), cow T (a dynamic T), data(T), the leaves' data, each mask's DM, the counter K = 0 (the
51999 REM value's index O) and I = 1, the IX 4 nest (52140) storing each element at its position
52000 LET R8 = V(3023)
52002 GOSUB 40990
52004 LET D1 = H(V(3021), 3)
52006 LET Y(D1, 4) = 4
52008 LET D3 = D1
52010 GOSUB 40900
52012 LET V(Q0 + 7) = 4
52014 LET V(Q0 + 1) = V(3027)
52016 LET V(30) = V(3027)
52018 LET R2 = H(D1, 6)
52020 GOSUB 8400
52022 LET Y8$ = P9$
52024 LET P9$ = U$
52026 LET H4 = 1
52028 GOSUB 40260
52030 LET H4 = 0
52032 LET K8 = Y(D1, 3)
52034 LET Q0 = 100 + 25 * K8
52035 LET V(4280) = K8
52036 GOSUB 40400
52037 LET V(4281) = V(Q0 + 9)
52038 LET R2 = V(3026)
52040 GOSUB 8400
52042 LET Q9$ = P9$
52044 LET P9$ = U$
52046 LET S$ = "L n,L G,bin P 2 ne,= S,"
52047 IF R4 = 2 THEN 52060
52048 IF Z8 = 1 THEN 52052
52050 LET S$ = S$ & "ci P 3 %6,= Z,"
52052 LET S$ = S$ & "L S,L n,L Z,L G,L Z,chk Q SHAPE_MISMATCH 4"
52054 LET Z8 = 1
52056 GOSUB 9000
52057 LET S$ = "L d,cow P,"
52058 IF T(H(H(D1, 3), 2), 3) = 0 THEN 52064
52059 LET S$ = ""
52060 IF R4 = 1 THEN 52064
52061 LET S$ = "L r,L R,bin P 2 ne,= s,L c,L C,bin P 2 ne,= t,L s,L t,bin P 2 bor,= S,L S,L r,L c,L R,L C,chk Q SHAPE_MISMATCH 4"
52062 LET R4 = 1
52063 GOTO 52056
52064 LET S$ = S$ & "D d,= w"
52066 GOSUB 9000
52068 LET Q8 = 2
52070 LET E8 = 1
52072 LET E9 = 1
52074 GOSUB 40640
52076 FOR J7 = 1 TO V(4281)
52078 LET K8 = V(4280) + J7
52080 IF V(100 + 25 * K8 + 9) < 5 THEN 52084
52082 LET S$ = "D M,= w"
52083 GOSUB 9000
52084 NEXT J7
52086 LET K8 = V(4280)
52088 LET S$ = "C 0,B K,C 1,= I"
52090 GOSUB 9000
52092 GOSUB 40990
52094 LET Q9 = 1
52095 LET V7 = 0
52096 IF R4 = 2 THEN 52098
52097 GOTO 52129
52098 LET F8 = Y(R8, 6)
52100 GOSUB 40970
52102 IF B8 = 0 THEN 52106
52104 LET S$ = "L p,?"
52105 GOSUB 9000
52106 LET V7 = SGN(F8)
52108 LET Q9 = 2 + V7
52110 GOSUB 52140
52112 IF B8 = 0 THEN 52130
52114 LET S$ = "|"
52116 GOSUB 9000
52118 LET D8 = Z7
52119 GOSUB 40760
52120 LET Q9 = 4
52121 LET V7 = 1
52122 GOSUB 52140
52123 LET Z7 = D8
52124 LET S$ = ")"
52126 GOSUB 9000
52128 GOTO 52130
52129 GOSUB 52140
52130 LET K8 = 0
52131 LET S$ = "}"
52132 GOSUB 9000
52134 LET N7 = N7 - 1
52135 LET H6 = 0
52136 LET H7 = 0
52138 GOTO 5190
52139 REM ---- 52140: copy Q9 of the store nest (V7 = 1: the value's element at the counters K L, else at O = K)
52140 IF V7 = 0 THEN 52144
52141 LET K8 = V(4280)
52142 LET S$ = "C 0,B L"
52143 GOSUB 9000
52144 FOR J7 = V(4281) TO 1 STEP -1
52146 LET K8 = V(4280) + J7
52148 LET S$ = "|L e,?,L a,L l,L c,K k|( X k||( X k,L w,L k,eld P 2 %2 0,?|( n k,L w,L k,eld P 2 %2 0,?"
52150 GOSUB 52182
52152 NEXT J7
52154 GOSUB 40800
52156 LET K8 = V(4280)
52157 LET S$ = "L w"
52158 GOSUB 9000
52159 LET K8 = V(4280) + 1
52160 GOSUB 52186
52161 IF V(4281) = 1 THEN 52167
52162 LET K8 = K8 + 1
52163 GOSUB 52186
52164 LET K8 = K8 - 1
52165 LET S$ = "L X,wbin P 3 mul,wbin P 3 add"
52166 GOSUB 9000
52167 LET K8 = V(4280)
52168 LET S$ = "est P %5 0,L K,L K,L I,wbin P 3 add,asg P set"
52169 GOSUB 9000
52171 FOR J7 = 1 TO V(4281)
52172 LET K8 = V(4280) + J7
52173 LET S$ = "|)|)||),)|),)"
52174 GOSUB 52182
52175 IF J7 * V7 <> 1 THEN 52179
52176 LET K8 = V(4280)
52177 LET S$ = "L K,L K,L K,wbin P 3 sub,asg P set,L L,L L,L I,wbin P 3 add,asg P set"
52178 GOSUB 9000
52179 NEXT J7
52180 RETURN
52181 REM ---- 52182: the part of S$ for the kind of index slot K8 (40960), written; 52186: its position k (S: I)
52182 LET C8 = V(100 + 25 * K8 + 9)
52183 GOSUB 40960
52184 IF S$ <> "" THEN 9000
52185 RETURN
52186 LET S$ = "L k"
52187 IF V(100 + 25 * K8 + 9) > 1 THEN 9000
52188 LET S$ = "L I"
52189 GOTO 9000
52195 REM ---- 52200: the records of the subtree of X4 (a target's index, not written in place) after
52196 REM the cursor, a dol the target's idx D1 claims as its base's extent (52230); H(X4,8) their last row (8900 writes after it)
52200 LET X6 = X4
52202 GOSUB 30660
52204 FOR H3 = X7 TO X4
52205 IF H(H3, 1) = 40 THEN 52230
52206 GOSUB 8060
52208 LET O(O0, 1) = H(H3, 6)
52210 LET N7 = N7 + 1
52212 LET Q2$ = "nodes"
52214 IF N7 <= N8 THEN 52216
52215 GOSUB 8088
52216 NEXT H3
52218 LET H(X4, 8) = C9
52220 RETURN
52229 REM ---- a dol H3: claimed by an idx inside the target D1's index, copied (52206); by D1, IX 1's lv of the base B (at the idx's position) and ext B d (at the dol's, d its dimension), L6
52230 LET J5 = H3
52232 LET J6 = W(J5)
52234 IF J6 = D1 THEN 52242
52236 IF H(J6, 1) <> 39 THEN 52238
52237 IF H(J6, 3) <> J5 THEN 52206
52238 LET J5 = J6
52240 GOTO 52232
52242 LET R2 = H(J6, 6)
52244 GOSUB 8400
52246 LET J5 = H(J6, 3)
52248 LET Z$ = "lv " & P9$ & " " & STR$(H(J5, 2)) & " "
52250 LET R2 = H(J5, 6)
52252 LET F9 = 4
52254 GOSUB 8440
52256 LET Z$ = Z$ & F9$
52258 GOSUB 8050
52260 LET R2 = H(H3, 6)
52262 GOSUB 8400
52264 LET F9 = 4
52266 GOSUB 8440
52268 LET Z$ = "ext " & P9$ & " 3 " & F9$
52270 GOSUB 8050
52272 GOTO 52216
52295 REM ---- 52300: (from 50662) a leaf root (F2 (1)): the value X9 of statement X5 a folded view
52296 REM or S R A V selection (Y(X9,4) 3 or 4 by 30502; C3 C4 kept), its own only leaf; else not groupable
52300 LET C8 = C4
52302 LET X3 = X9
52304 LET X6 = X5
52306 GOSUB 30502
52308 LET C4 = C8
52309 LET C3 = 0
52310 IF ABS(Y(X9, 4) - 3.5) = .5 THEN 50666
52312 LET Y(X9, 4) = 0
52314 GOTO 50696
52316 REM ---- 52317: a reduction statement C7: its lib not written; 52319: the leaf root X3 of a unit's statement: the leaf of its own tree, folded (30640)
52317 IF V(3000 + 20 * C7 + 2) <> 2 THEN 52319
52318 LET Y(V(3000 + 20 * C7 + 13), 1) = 1
52319 IF Y(X3, 0) <> 0 THEN 52328
52320 LET Y(X3, 7) = X3
52324 LET X8 = X3
52326 GOTO 30640
52328 RETURN
52329 REM ---- 52330: after a leaf root's leaf phase, its extents (40380: IX 3 of a selection), R-c (a reduction's: 56600)
52330 IF Y(R8, 0) <> 0 THEN 52338
52331 IF V(3000 + 20 * H8 + 2) = 2 THEN 52338
52332 LET K8 = Y(R8, 3)
52334 LET P9$ = U$
52336 GOSUB 40380
52338 RETURN
52339 REM ---- 52340: F8 += the folded leaves of statement H8's tree (a leaf root: itself, 1); 52350: F8 = those of R8
52340 LET C6 = F8
52341 LET R8 = V(3000 + 20 * H8 + 3)
52342 GOSUB 52350
52344 LET F8 = C6 + C5
52346 RETURN
52350 LET C5 = Y(R8, 6)
52352 IF Y(R8, 0) <> 0 THEN 52356
52354 LET C5 = 1
52356 LET F8 = C5
52358 RETURN
52359 REM ---- 52360: (from 50648) a bind of a scalar from a reduction F3 fuses (role 7, or 1 in a
52360 REM unit being written), not variance or std (F2 (1)): kind 2, its root the tree's (Y(lib,5)),
52361 REM 13 the lib, 14 the space's rank (1: a vector, a .flat's too, 52720; a masked one's: its mask's, 52380)
52362 IF H(X9, 1) <> 12 THEN 50660
52364 IF Y(X9, 0) <> 0 THEN 50660
52366 IF Y(X9, 5) = 0 THEN 50660
52368 IF Y(X9, 1) = 7 THEN 52372
52370 IF Y(X9, 1) * 10 + H7 <> 11 THEN 50660
52372 LET R2 = H(X9, 6)
52374 LET F9 = 4
52376 GOSUB 8440
52378 IF POS("|variance|std|", "|" & F9$ & "|") > 0 THEN 50696
52379 LET C4 = 2
52380 LET V(3000 + 20 * G9 + 2) = 2
52382 LET V(3000 + 20 * G9 + 13) = X9
52384 LET X9 = Y(X9, 5)
52386 LET V(3000 + 20 * G9 + 3) = X9
52388 LET V(3000 + 20 * G9 + 14) = 1
52390 LET V(3000 + 20 * G9 + 15) = 0
52392 IF Y(V(3000 + 20 * G9 + 13), 6) = 0 THEN 50699
52394 LET X6 = X9
52396 GOSUB 30660
52398 FOR X8 = X7 TO X9
52400 IF Y(X8, 7) <> X9 THEN 52406
52402 IF ABS(Y(X8, 4) - 7) <> 1 THEN 52406
52403 IF V(3000 + 20 * G9 + 15) > 0 THEN 52406
52404 LET V(3000 + 20 * G9 + 15) = X8
52406 NEXT X8
52408 LET X8 = V(3000 + 20 * G9 + 15)
52410 LET V(3000 + 20 * G9 + 14) = T(H(H(H(X8, 3), 4), 2), 1)
52412 GOTO 50699
52419 REM ---- 52420: a reduction statement E2 of sum or mean over i64 can fail: it ends the group (F2 (4))
52420 IF V(3000 + 20 * E2 + 2) <> 2 THEN 52428
52421 IF T(H(V(3000 + 20 * E2 + 3), 2), 2) <> 3 THEN 52428
52422 LET R2 = H(V(3000 + 20 * E2 + 13), 6)
52423 LET F9 = 4
52424 GOSUB 8440
52425 IF POS("|sum|mean|", "|" & F9$ & "|") = 0 THEN 52428
52426 LET E4 = 1
52428 RETURN
52429 REM ---- 52430: the lv X8 the base of a mask selection that reads statement C5's local: the idx a kind-8 leaf (Y(idx,5) = C5), the lv not written; 52436: a kind-5 leaf's
52430 LET X9 = W(X8)
52432 LET Y(X9, 4) = 8
52434 LET Y(X9, 5) = C5
52435 GOTO 52438
52436 LET Y(X8, 5) = C5
52438 GOSUB 52620
52439 GOTO 50519
52440 REM ---- 52440: (from 50717) or the lv X8 is the base of a mask selection of the tree of statement G9 (F2 (3)): C5 kept
52441 LET C6 = W(X8)
52442 IF H(C6, 1) <> 39 THEN 50718
52443 IF H(C6, 3) <> X8 THEN 50718
52444 IF Y(C6, 7) <> V(3000 + 20 * G9 + 3) THEN 50718
52445 IF ABS(Y(C6, 4) - 7) <> 1 THEN 50718
52446 GOTO 50712
52449 REM ---- 52450: in the split copy a reduction statement has no result array (F3's own nest)
52450 LET V(3000 + 20 * H8 + 10) = 0
52452 GOTO 51190
52459 REM ---- 52460: in the space test, a masked reduction H8's mask extent (N, or I W) with S1's, banded (R-q)
52460 IF V(3000 + 20 * H8 + 2) <> 2 THEN 52468
52461 IF V(3000 + 20 * H8 + 15) = 0 THEN 52468
52462 LET K8 = Y(V(3000 + 20 * H8 + 15), 3)
52463 LET S$ = "L N,L G,bin P 2 eq,bin P 2 band"
52464 IF R4 = 1 THEN 52466
52465 LET S$ = "L I,L R,bin P 2 eq,bin P 2 band,L W,L C,bin P 2 eq,bin P 2 band"
52466 GOSUB 9000
52468 RETURN
52469 REM ---- 52470: of statement G9 its rank (14) by its root's space type (41400: a k >= 2 emap's first component)
52470 LET Y7 = H(X9, 2)
52472 GOSUB 41400
52474 LET V(3000 + 20 * G9 + 14) = T(Y7, 1)
52476 RETURN
52478 REM ---- 52480: of statement G9 the first entry of its components (16, after statement G9 - 1's), their count 17 (0: no tbind)
52480 LET V(3000 + 20 * G9 + 16) = V(2980 + 20 * G9 + 16) + V(2980 + 20 * G9 + 17)
52482 LET V(3000 + 20 * G9 + 17) = 0
52484 RETURN
52486 REM ---- 52490: (from 50619) a tbind whose value is a fusible emap of k >= 2 results (F2 (1), F5; R-m): kind 1
52487 REM with no lid, 17 its k; its component c has four entries at V(35000 + 4 (16 + c - 1) + f), f: 0
52488 REM stored, 1 its Ei in the fused copy (0: a -), 2 its array in the split copy (-lid, a U row, 0: a -), 3 its data
52490 LET C4 = 1
52491 LET V(3000 + 20 * G9 + 5) = 0
52492 IF H(X9, 1) <> 64 THEN 50696
52493 IF Y(X9, 0) = 0 THEN 50696
52494 LET V(3000 + 20 * G9 + 17) = VAL(F9$)
52495 IF V(3000 + 20 * G9 + 16) + VAL(F9$) > 499 THEN 50696
52496 GOTO 50660
52498 REM ---- 52500: K3 = the component of statement C7 that the lid C5 names (its lid: 1; a tbind's: 52490), 0 none
52500 LET K3 = 0
52501 IF V(3000 + 20 * C7 + 5) <> C5 THEN 52503
52502 LET K3 = 1
52503 IF V(3000 + 20 * C7 + 17) = 0 THEN 52514
52504 LET R2 = V(3000 + 20 * C7 + 6)
52505 FOR K4 = 1 TO V(3000 + 20 * C7 + 17)
52506 LET F9 = 3 + K4
52507 GOSUB 8440
52508 IF F9$ = "-" THEN 52510
52509 IF VAL(F9$) = C5 THEN 52512
52510 NEXT K4
52511 RETURN
52512 LET K3 = K4
52514 RETURN
52516 REM ---- 52520: (51613) of statement H8 a tbind: its component the lid K6 names stored (R2 kept)
52520 IF V(3000 + 20 * H8 + 17) = 0 THEN 52529
52521 LET M6 = R2
52522 LET C5 = K6
52523 LET C7 = H8
52524 GOSUB 52500
52525 LET R2 = M6
52526 IF K3 = 0 THEN 52529
52527 LET V(35000 + 4 * (V(3000 + 20 * H8 + 16) + K3 - 1)) = 1
52529 RETURN
52530 REM ---- 52530: (51069) of a tbind H8 each stored component's array, before the group's block (F2 (b), D1):
52531 REM anew of the component's type at Si's position, bind lid
52532 IF V(3000 + 20 * H8 + 17) = 0 THEN 52549
52533 GOSUB 51900
52534 LET M7 = H8
52535 FOR K4 = 1 TO V(3000 + 20 * H8 + 17)
52536 IF V(35000 + 4 * (V(3000 + 20 * H8 + 16) + K4 - 1)) = 0 THEN 52548
52537 GOSUB 52630
52538 GOSUB 8400
52539 LET Q9$ = P9$
52540 LET P9$ = U$
52541 LET S$ = A1$
52542 GOSUB 9000
52543 LET R2 = V(3000 + 20 * H8 + 6)
52544 LET F9 = 3 + K4
52545 GOSUB 8440
52546 LET Z$ = "bind " & Q9$ & " " & F9$
52547 GOSUB 8050
52548 NEXT K4
52549 RETURN
52550 REM ---- 52550: (51143) the fused copy's data of a tbind H8's stored components
52551 IF V(3000 + 20 * H8 + 17) = 0 THEN 52559
52552 LET K8 = V(3000 + 20 * H8 + 11)
52553 LET P9$ = U$
52554 FOR K4 = 1 TO V(3000 + 20 * H8 + 17)
52555 LET M8 = 35000 + 4 * (V(3000 + 20 * H8 + 16) + K4 - 1)
52556 LET R2 = V(3000 + 20 * H8 + 6)
52557 GOSUB 52702
52558 NEXT K4
52559 RETURN
52560 REM ---- 52560: (41205) a tbind E1's element in a copy (R-m): {, tbind P k of new .l locals of its
52561 REM components' element types (- kept), the est of each stored (fused) or kept (split) one, which sealower takes only in the
52562 REM block its tbind begins (52640); then (fused) the rest of the body, the blocks closed at its end (41235, K7 of them); (split) } (L19's block form)
52563 LET P9$ = U$
52564 LET S$ = "{"
52565 GOSUB 9000
52566 LET M7 = E1
52567 LET Z2$ = "tbind " & U$ & " " & STR$(V(3000 + 20 * E1 + 17))
52568 FOR K4 = 1 TO V(3000 + 20 * E1 + 17)
52569 LET M8 = 35000 + 4 * (V(3000 + 20 * E1 + 16) + K4 - 1)
52570 LET V(M8 + 1) = 0
52571 GOSUB 52630
52572 LET F9 = 3 + K4
52573 GOSUB 8440
52574 LET Z1$ = " -"
52575 IF F9$ = "-" THEN 52580
52576 LET U1 = T(U1, 2)
52577 LET U2 = 0
52578 GOSUB 8100
52579 LET V(M8 + 1) = U0
52580 IF F9$ = "-" THEN 52582
52581 LET Z1$ = " @" & STR$(U0)
52582 LET Z2$ = Z2$ & Z1$
52583 NEXT K4
52584 LET Z$ = Z2$
52585 GOSUB 8050
52586 LET M(Z0, 1) = M(Z0, 1) + 1
52587 LET K7 = K7 + 2 - Q8
52588 GOSUB 52640
52589 IF Q8 = 1 THEN 41214
52590 LET S$ = "}"
52591 GOSUB 9000
52592 GOTO 41214
52594 REM ---- 52595: (51179) the split copy's arrays of a tbind H8's kept components (a stored one its lid,
52596 REM else a tmp of a new array), then their data; no result array of its own (10 = 0)
52597 LET V(3000 + 20 * H8 + 10) = 0
52598 GOSUB 51900
52599 LET M7 = H8
52600 FOR K4 = 1 TO V(3000 + 20 * H8 + 17)
52601 LET M8 = 35000 + 4 * (V(3000 + 20 * H8 + 16) + K4 - 1)
52602 LET V(M8 + 2) = 0
52603 GOSUB 52630
52604 LET F9 = 3 + K4
52605 GOSUB 8440
52606 IF F9$ = "-" THEN 52612
52607 LET V(M8 + 2) = -VAL(F9$)
52608 IF V(M8) = 1 THEN 52612
52609 LET S$ = A2$
52610 GOSUB 9000
52611 LET V(M8 + 2) = V(48)
52612 NEXT K4
52613 FOR K4 = 1 TO V(3000 + 20 * H8 + 17)
52614 LET M8 = 35000 + 4 * (V(3000 + 20 * H8 + 16) + K4 - 1)
52615 IF V(M8 + 2) = 0 THEN 52617
52616 GOSUB 52696
52617 NEXT K4
52618 GOTO 51190
52619 REM ---- 52620: (52438) the lv X8 not written; Y(X8,6) the component it reads (K3, 52500)
52620 LET Y(X8, 1) = 4
52621 LET Y(X8, 6) = K3
52622 RETURN
52623 REM ---- 52624: (51015) the stored flags of a tbind H8's components cleared
52624 FOR K4 = 1 TO V(3000 + 20 * H8 + 17)
52625 LET V(35000 + 4 * (V(3000 + 20 * H8 + 16) + K4 - 1)) = 0
52626 NEXT K4
52627 RETURN
52629 REM ---- 52630: of a tbind M7 (component K4) U1 the component's type, %0 it; R2 its record
52630 LET Y6 = H(V(3000 + 20 * M7 + 3), 2)
52631 LET L5 = V(3000 + 20 * M7 + 17)
52632 LET W4 = K4
52633 GOSUB 20966
52634 LET V(53) = U1
52635 LET R2 = V(3000 + 20 * M7 + 6)
52636 RETURN
52638 REM ---- 52640: (52588) of a tbind M7 the est of each component (fused Q8 = 1: a stored one; split: a kept one)
52639 REM from its Ei (1) into its data (3) at the position K (K L R), the root slot's M w set to them
52640 LET K8 = V(3000 + 20 * M7 + 11)
52641 FOR K4 = 1 TO V(3000 + 20 * M7 + 17)
52642 LET M8 = 35000 + 4 * (V(3000 + 20 * M7 + 16) + K4 - 1)
52643 IF V(M8 + 1) = 0 THEN 52653
52644 IF V(M8) + Q8 = 1 THEN 52653
52645 GOSUB 52630
52646 LET E5 = T(U1, 2)
52647 GOSUB 8730
52648 LET V(58) = V5
52649 LET V(100 + 25 * K8 + 17) = V(M8 + 1)
52650 LET V(100 + 25 * K8 + 14) = V(M8 + 3)
52651 LET S$ = "L M,L w,L K"
52652 GOSUB 52665
52653 NEXT K4
52654 RETURN
52660 REM ---- 52661: (41235) the blocks the tbinds of the fused copy opened closed (K7)
52661 IF K7 = 0 THEN 52654
52662 LET S$ = "}"
52663 LET K7 = K7 - 1
52664 GOTO 52668
52665 IF Q9 < 3 THEN 52667
52666 LET S$ = S$ & ",L L,L R,wbin P 3 mul,wbin P 3 add"
52667 LET S$ = S$ & ",est P %5 0"
52668 LET P9$ = U$
52669 GOSUB 9000
52670 IF S$ = "}" THEN 52661
52671 RETURN
52672 REM ---- 52673: (41248) the fused copy's element of the kind-5 or kind-8 leaf D2: the Ei of the
52673 REM statement M6 it reads (its root slot's M; a tbind's: its component's)
52674 LET M6 = Y(D2, 5)
52675 LET V(100 + 25 * Y(D2, 3) + 1) = V(100 + 25 * V(3000 + 20 * M6 + 11) + 17)
52676 IF V(3000 + 20 * M6 + 17) = 0 THEN 52654
52677 GOSUB 52690
52678 LET V(100 + 25 * Y(D2, 3) + 1) = V(M8 + 1)
52679 RETURN
52680 REM ---- 52681: (41136) the split copy's array of the statement M6 a kind-5 or kind-8 leaf D2 reads (7; a tbind's: its component's)
52681 LET M6 = Y(D2, 5)
52682 LET V(Q0 + 1) = V(3000 + 20 * M6 + 7)
52683 IF V(3000 + 20 * M6 + 17) = 0 THEN 52654
52684 GOSUB 52690
52685 LET V(Q0 + 1) = V(M8 + 2)
52686 RETURN
52689 REM ---- 52690: M8 = the entries of the component of statement M6 the leaf D2 reads (Y(lv,6), 52620)
52690 LET M8 = D2
52691 IF Y(D2, 4) <> 8 THEN 52693
52692 LET M8 = H(D2, 3)
52693 LET M8 = 35000 + 4 * (V(3000 + 20 * M6 + 16) + Y(M8, 6) - 1)
52694 RETURN
52695 REM ---- 52696: the data (3) of the component array V(M8 + 2) (its U row or -lid), slot K8's w
52696 LET V(48) = V(M8 + 2)
52697 LET S$ = "D v,= w"
52698 GOSUB 9000
52699 LET V(M8 + 3) = V(100 + 25 * K8 + 14)
52700 RETURN
52701 REM ---- 52702: a stored component (M8): its array its lid (2), its data (52696)
52702 IF V(M8) = 0 THEN 52700
52703 LET F9 = 3 + K4
52704 GOSUB 8440
52705 LET V(M8 + 2) = -VAL(F9$)
52706 GOTO 52696
52709 REM ---- 52710: (51196) the split copy's F8 (52350); a masked reduction's own nest runs over its mask's base positions (G = n of its mask's slot, F2 (2), F3), its counter J counting the selected ones
52710 GOSUB 52350
52712 IF V(3000 + 20 * H8 + 2) <> 2 THEN 52718
52714 IF V(3000 + 20 * H8 + 15) = 0 THEN 52718
52716 LET V(7) = V(100 + 25 * Y(V(3000 + 20 * H8 + 15), 3) + 8)
52718 RETURN
52719 REM ---- 52720: (51060, after 51800: fixed extents set before 56600 loads N) a .flat reduction H8 (root R8 a matrix tree, R-k): its slot made the vector n = r c (dynamic, rank 1), then 56600
52720 IF V(3000 + 20 * H8 + 2) <> 2 THEN 56600
52722 IF T(H(R8, 2), 1) <> 2 THEN 56600
52724 LET P9$ = U$
52726 LET K8 = Y(R8, 3)
52727 LET Q0 = 100 + 25 * K8
52728 LET S$ = "L r,L c,wbin P 3 mul,= n"
52730 GOSUB 9000
52732 LET V(Q0 + 6) = 1
52734 LET V(Q0 + 21) = 0
52736 GOTO 56600
52749 REM ---- 52750: (50290) statement X5 (G9) joins S1 ... S(E2) when it is not denied (30900) and the group's slots still fit a unit (30870; L-er, L-el): C3 = 1
52750 LET I5 = X5
52751 GOSUB 30900
52752 IF I6 = 1 THEN 50296
52753 LET I3 = 0
52754 FOR C7 = 1 TO G9
52755 LET I5 = V(3000 + 20 * C7 + 3)
52756 GOSUB 30870
52757 NEXT C7
52758 GOTO 52771
52759 REM ---- 52760: (50318) statement X5 starts a group when it is not denied (30900) and its slots fit a unit (30870; a selection target's 3 more): C3 = 1
52760 LET I5 = X5
52761 GOSUB 30900
52762 IF I6 = 1 THEN 50320
52763 LET I3 = 0
52764 IF C4 <> 4 THEN 52766
52765 LET I3 = 3
52766 LET I5 = V(3023)
52767 GOSUB 30870
52768 IF I3 > 1180 THEN 50320
52769 LET C3 = 1
52770 GOTO 50320
52771 IF I3 > 1180 THEN 50296
52772 LET C3 = 1
52773 GOTO 50296
52779 REM ---- 52780: (50492) a lone store's tree X3 fused in place (role 2) unless denied (30900)
52780 LET I5 = X3
52781 GOSUB 30900
52782 IF I6 = 1 THEN 50496
52783 LET Y(X3, 1) = 2
52784 GOSUB 30600
52785 GOTO 50496
52789 REM ---- 52790: (50317) a whole target whose tree reads it otherwise starts no group: its tree fused in place into RES (role 2, Decision 111, F1 (5)) when fusible, its slots fit (30864) and it is not denied (30900)
52790 LET X3 = V(3023)
52791 IF Y(X3, 0) = 0 THEN 50320
52792 GOSUB 30864
52793 IF I3 > 1180 THEN 50320
52794 GOSUB 30900
52795 IF I6 = 1 THEN 50320
52796 LET Y(X3, 1) = 2
52797 GOSUB 30600
52798 GOTO 50320
