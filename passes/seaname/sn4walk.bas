5145 REM ---- rs_fn: the resolution walk of fn S (S = 1: .main, the top-level statements): its
5150 REM parameters are locals 1..np, then the locals of its body in source order (DESIGN 3.4.1
5155 REM "Names", 3.5.4); the walk is that of phase 1's single pass 2a, without its checks --------
5160 SUB "rs_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
5165 LET F = Y(S, 3)
5170 LET X(11) = 0
5175 LET X(12) = 200000
5180 LET X(13) = 0
5185 LET X(14) = S
5190 IF S = 1 THEN 5250
5195 LET I = N(F, 7)
5200 FOR J = 1 TO Y(S, 6)
5205 CALL "nloc": N(), Y(), W(), X(), X$(), N(I, 6), I, R
5210 LET M(I, 2) = R
5215 LET I = N(I, 8)
5220 NEXT J
5225 REM the body is the last child, after the result types
5230 FOR J = 1 TO Y(S, 7)
5235 LET I = N(I, 8)
5240 NEXT J
5245 CALL "rs_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5247 GOTO 5300
5250 REM .main: one scope for the top-level statements; the items are not statements
5255 LET X(12) = X(12) - 2
5260 LET W(X(12)) = -1
5265 LET I = N(X(17), 7)
5270 IF I = 0 THEN 5300
5275 LET K = N(I, 0)
5280 IF K = 2 THEN 5295
5285 IF K = 3 THEN 5295
5290 IF K = 5 THEN 5295
5292 CALL "rs_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5295 LET I = N(I, 8)
5297 GOTO 5270
5300 SUBEND
5305 REM ---- rs_blk: block B, a scope (LANGUAGE 7.7) ---------------------------------------------
5310 SUB "rs_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
5315 CALL "sc_push": N(), W(), X(), X$(), B
5320 LET I = N(B, 7)
5325 IF I = 0 THEN 5340
5330 CALL "rs_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5335 LET I = N(I, 8)
5337 GOTO 5325
5340 CALL "sc_pop": W(), X()
5345 SUBEND
5350 REM ---- sc_push / sc_pop: open and close a scope (marker -1 on the scope stack in W) -----------
5355 SUB "sc_push": N(), W(), X(), X$(), I
5360 IF X(12) - 2 > X(11) THEN 5375
5365 CALL "fatal": N(), X(), X$(), I, "symbols"
5370 GOTO 5385
5375 LET X(12) = X(12) - 2
5380 LET W(X(12)) = -1
5385 SUBEND
5390 SUB "sc_pop": W(), X()
5395 IF X(12) >= 200000 THEN 5420
5400 IF W(X(12)) = -1 THEN 5415
5405 LET X(12) = X(12) + 2
5410 GOTO 5395
5415 LET X(12) = X(12) + 2
5420 SUBEND
5425 REM ---- rs_st: statement I (LANGUAGE 7.1-7.6): its expressions are resolved and typed
5430 REM (rs_expr), its type annotations looked up (tylk), its names declared (nloc); a match (rs_mt)
5435 REM is a resolved region from 4g-1 (DESIGN 3.4.2) ------------------------------------------
5440 SUB "rs_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5445 LET X(19) = I
5450 LET K = N(I, 0)
5455 IF K < 8 THEN 5760
5460 IF K > 24 THEN 5760
5465 ON K - 7 GOTO 5470, 5470, 5760, 5760, 5760, 5560, 5575, 5610, 5620, 5680, 5695, 5757, 5760, 5760, 5760, 5740, 5755
5470 REM let/var: the value first (a name is visible from the statement after it, LANGUAGE 7.2),
5475 REM then the annotation (its names where the statement stands), then the names of the pattern
5477 REM from left to right
5480 LET P = N(I, 7)
5485 LET E = N(P, 8)
5490 IF N(I, 1) = 0 THEN 5500
5495 LET E = N(E, 8)
5500 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5501 IF N(I, 1) = 0 THEN 5505
5502 CALL "tylk": N(), M(), Y(), W(), S$(), X(), X$(), N(P, 8)
5505 IF N(P, 0) <> 10 THEN 5525
5510 CALL "nloc": N(), Y(), W(), X(), X$(), N(P, 6), P, R
5515 LET M(P, 2) = R
5520 LET M(P, 4) = 1
5522 GOTO 5760
5525 IF N(P, 0) <> 12 THEN 5760
5530 LET Q = N(P, 7)
5535 FOR J = 1 TO N(P, 1)
5540 IF N(Q, 0) <> 10 THEN 5555
5545 CALL "nloc": N(), Y(), W(), X(), X$(), N(Q, 6), Q, R
5550 LET M(Q, 2) = R
5552 LET M(Q, 4) = 1
5555 LET Q = N(Q, 8)
5557 NEXT J
5558 GOTO 5760
5560 LET G = N(I, 7)
5565 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
5570 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
5572 GOTO 5760
5575 REM (t1, ..., tn) = e: the targets other than _, then the value
5580 LET G = N(I, 7)
5585 FOR J = 1 TO N(I, 1)
5590 IF N(G, 0) = 11 THEN 5600
5595 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
5600 LET G = N(G, 8)
5602 NEXT J
5605 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
5607 GOTO 5760
5610 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(I, 7)
5615 GOTO 5760
5620 REM an else-if chain is walked here link by link (no recursion over its length)
5625 LET L1 = I
5630 LET E = N(L1, 7)
5635 LET B = N(E, 8)
5640 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5645 CALL "rs_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
5650 IF N(L1, 1) = 0 THEN 5760
5655 LET G = N(B, 8)
5660 IF N(G, 0) = 24 THEN 5672
5665 LET L1 = G
5670 GOTO 5630
5672 CALL "rs_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
5675 GOTO 5760
5680 LET E = N(I, 7)
5685 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5690 CALL "rs_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
5692 GOTO 5760
5695 REM a loop over a range or a vector (DESIGN 3.4.2): the iterable, then the loop variable (a
5700 REM local before those of the body) in a scope of its own
5705 LET E = N(I, 7)
5715 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5720 CALL "sc_push": N(), W(), X(), X$(), I
5725 CALL "nloc": N(), Y(), W(), X(), X$(), N(I, 6), I, R
5730 LET M(I, 2) = R
5732 LET M(I, 4) = 1
5734 CALL "rs_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
5736 CALL "sc_pop": W(), X()
5738 GOTO 5760
5740 LET E = N(I, 7)
5742 FOR J = 1 TO N(I, 1)
5744 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5746 LET E = N(E, 8)
5748 NEXT J
5750 GOTO 5760
5755 CALL "rs_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5756 GOTO 5760
5757 CALL "rs_mt": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5760 SUBEND
