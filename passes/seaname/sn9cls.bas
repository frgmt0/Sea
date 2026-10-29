14000 REM ==== sn9cls: the defaults and the call pre-pass of sub-phase 6b (DESIGN 2.11.2, 2.11.3) =========
14005 REM ---- rsdef: the default expression E of a parameter of fn item F, a resolved region from 6b
14010 REM (DESIGN 3.4.1 as amended, Decision 91, L-bx): its names resolved like those of a const item's
14015 REM value (no local in scope; in a prelude fn only the prelude's items, as its body), its ^ marked
14020 REM rpowk (rs_expr); no outcome is written, seacheck evaluates and checks it -----------------
14025 SUB "rsdef": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E, F
14030 LET X(11) = 0
14035 LET X(12) = 200000
14040 LET X(46) = 0
14045 IF X(44) < 2 THEN 14060
14050 IF N(F, 4) >= 1E9 THEN 14060
14055 LET X(46) = 1
14060 CALL "rs_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
14065 LET X(46) = 0
14070 SUBEND
14075 REM ---- sn_cls: the call pre-pass (Decision 81), after every body is resolved: Y(s,8) of each fn
14080 REM its call sites, the call nodes of the whole stream whose callee names it (each counts once,
14085 REM wherever it stands, L-ch); Y(s,9) 2 for an ordinary fn of the program's file that LANGUAGE
14090 REM 8.6 covers: (b) one call site, or (c) on no cycle of the call graph (crec, L-cj), no while
14095 REM or for in its body, at most LIM_INLINE_STMTS statements (cstm, L-ci); else 0. Prelude
14100 REM functions (inlined by rule 37) and elemental ones (8.6 (a), el 1) are not classed. ---------
14105 SUB "sn_cls": N(), M(), Y(), W(), X()
14110 FOR S = 2 TO X(33)
14115 REM the marks of crec start clear (W held the constant order's stack and evx's values)
14120 LET W(S) = 0
14125 IF Y(S, 0) <> 1 THEN 14140
14130 LET Y(S, 8) = 0
14135 LET Y(S, 9) = 0
14140 NEXT S
14145 FOR J = 1 TO X(1)
14150 IF N(J, 0) <> 35 THEN 14170
14155 CALL "cfn": N(), M(), Y(), J, R
14160 IF R = 0 THEN 14170
14165 LET Y(R, 8) = Y(R, 8) + 1
14170 NEXT J
14175 FOR S = 2 TO X(33)
14180 IF Y(S, 0) <> 1 THEN 14245
14185 IF Y(S, 4) <> 0 THEN 14245
14190 IF X(44) < 2 THEN 14200
14195 IF N(Y(S, 3), 4) < 1E9 THEN 14245
14200 IF Y(S, 8) <> 1 THEN 14215
14205 LET Y(S, 9) = 2
14210 GOTO 14245
14215 CALL "cstm": N(), M(), Y(), S, K, L
14220 IF L = 1 THEN 14245
14225 IF K > X(47) THEN 14245
14230 CALL "crec": N(), M(), Y(), W(), X(), S, Z
14235 IF Z = 1 THEN 14245
14240 LET Y(S, 9) = 2
14245 NEXT S
14250 SUBEND
14255 REM ---- cfn: R = the fn symbol the callee of call node J names (an rname fn), else 0 ----------
14260 SUB "cfn": N(), M(), Y(), J, R
14265 LET R = 0
14270 LET G = N(J, 7)
14275 IF N(G, 0) <> 30 THEN 14305
14280 IF M(G, 4) <> 1 THEN 14305
14285 IF M(G, 2) <= 0 THEN 14305
14290 IF Y(M(G, 2), 0) <> 1 THEN 14305
14295 LET R = M(G, 2)
14305 SUBEND
14310 REM ---- cbody: B = the body block of fn S, its last child (after the parameters and results) ---
14315 SUB "cbody": N(), Y(), S, B
14320 LET B = N(Y(S, 3), 7)
14325 FOR H = 1 TO Y(S, 6) + Y(S, 7)
14330 LET B = N(B, 8)
14335 NEXT H
14340 SUBEND
14345 REM ---- cstm: K = the statements of the body of fn S as LANGUAGE 8.6 counts them (L-ci), L = 1
14350 REM when it holds a while or a for. One per node of let var asg tasg cstmt while for match break
14355 REM continue return; an if except the else child of an if (an else if of one chain); a block
14360 REM that is a statement (a child of a block), not a body of a fn, loop, if branch or arm --------
14365 SUB "cstm": N(), M(), Y(), S, K, L
14370 CALL "cbody": N(), Y(), S, B
14375 LET K = 0
14380 LET L = 0
14385 FOR J = M(B, 0) TO B
14390 LET T = N(J, 0)
14395 IF T = 16 THEN 14430
14400 IF T = 24 THEN 14440
14405 IF POS("|8|9|13|14|15|17|18|19|21|22|23|", "|" & STR$(T) & "|") = 0 THEN 14450
14410 LET K = K + 1
14415 IF T < 17 THEN 14450
14420 IF T > 18 THEN 14450
14425 LET L = 1
14427 GOTO 14450
14430 IF N(N(J, 9), 0) = 16 THEN 14450
14435 LET K = K + 1
14437 GOTO 14450
14440 IF N(N(J, 9), 0) <> 24 THEN 14450
14445 LET K = K + 1
14450 NEXT J
14455 SUBEND
14460 REM ---- crec: Z = 1 when fn S lies on a cycle of the call graph (L-cj): a breadth-first search
14465 REM from the callees of S's body, over the calls of each reached fn's body, that meets S again.
14470 REM Iterative (no Baysick recursion): the marks W(s) = S (s <= X(33), cleared by sn_cls) and
14475 REM the queue W(X(33)+1..), each fn queued at most once per search --------------------------
14480 SUB "crec": N(), M(), Y(), W(), X(), S, Z
14485 LET Z = 0
14490 LET Q0 = X(33)
14495 LET H = 0
14500 LET T = 0
14505 LET G = S
14510 CALL "cbody": N(), Y(), G, B
14515 FOR J = M(B, 0) TO B
14520 IF N(J, 0) <> 35 THEN 14560
14525 CALL "cfn": N(), M(), Y(), J, R
14530 IF R = 0 THEN 14560
14535 IF R <> S THEN 14550
14540 LET Z = 1
14545 GOTO 14580
14550 IF W(R) = S THEN 14560
14552 LET W(R) = S
14555 LET T = T + 1
14557 LET W(Q0 + T) = R
14560 NEXT J
14565 IF H = T THEN 14580
14570 LET H = H + 1
14575 LET G = W(Q0 + H)
14577 GOTO 14510
14580 SUBEND
