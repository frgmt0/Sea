14000 REM ==== sn9cls: the defaults and the call pre-pass of sub-phases 6b, 6c (DESIGN 2.11.2, 2.11.3) =====
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
14105 SUB "sn_cls": N(), M(), Y(), W(), S$(), X(), X$()
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
14247 REM then the effects and the cycles of 6c: 228, 232 (cpre)
14248 CALL "cpre": N(), M(), Y(), S$(), X(), X$()
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
14585 REM ---- cpre: the effects and the cycles of the call pre-pass (DESIGN 2.11.2, L-cq; LANGUAGE 8.1,
14590 REM 8.5). A fn has effects when it has a ref parameter, calls printf print write_json make_dir
14595 REM save_svg or a plotting function of LANGUAGE 12, or calls a fn with effects (error is none): a
14600 REM worklist fixpoint over the callers. 228 at every call in an elemental fn's body of a library
14605 REM fn or a fn with effects; 232 at every call F -> G with F reached from an elemental fn E and G
14610 REM reaching E (the call lies on a cycle through E). er keeps the first in source order, 228
14615 REM before 232 at one call. Every search is iterative (queue Z), never a recursive CALL.
14620 REM A(e,0) the caller, A(e,1) the call node, A(e,2) the callee, A(e,3) the next edge of the same
14625 REM callee; B(s,0) 1: effects, B(s,1) the first edge of callee s, B(s,2..3) the edges of s's
14630 REM body (first, last), B(s,4) B(s,5) the marks (E) of the forward and the backward search.
14635 SUB "cpre": N(), M(), Y(), S$(), X(), X$()
14640 DIM A(99999,3), B(49999,5), Z(49999)
14645 LET L$ = "|printf|print|write_json|make_dir|save_svg|axis_equal|bar|barh|contour|figure|grid|"
14650 LET L$ = L$ & "image|legend|panel|plot|title|twin_y|x_ticks|xlabel|xline|xlim|y_reverse|y_ticks|"
14655 LET L$ = L$ & "ylabel|ylim|"
14660 LET E = 0
14665 FOR S = 2 TO X(33)
14670 FOR H = 0 TO 5
14675 LET B(S, H) = 0
14680 NEXT H
14685 NEXT S
14690 REM the edges, each fn's in its body order; the ref parameters and the library calls with effects
14695 FOR S = 2 TO X(33)
14700 IF Y(S, 0) <> 1 THEN 14820
14705 LET G = N(Y(S, 3), 7)
14710 FOR H = 1 TO Y(S, 6)
14715 IF N(G, 1) = 0 THEN 14725
14720 LET B(S, 0) = 1
14725 LET G = N(G, 8)
14730 NEXT H
14735 CALL "cbody": N(), Y(), S, B0
14740 LET B(S, 2) = E + 1
14745 FOR J = M(B0, 0) TO B0
14750 IF N(J, 0) <> 35 THEN 14810
14755 CALL "cfn": N(), M(), Y(), J, R
14760 IF R = 0 THEN 14790
14765 LET E = E + 1
14770 LET A(E, 0) = S
14775 LET A(E, 1) = J
14780 LET A(E, 2) = R
14782 LET A(E, 3) = B(R, 1)
14785 LET B(R, 1) = E
14787 GOTO 14810
14790 REM a predeclared callee (rname pd) with effects
14792 LET G = N(J, 7)
14794 IF N(G, 0) <> 30 THEN 14810
14796 IF M(G, 2) >= 0 THEN 14810
14798 IF POS(L$, "|" & S$(N(G, 6)) & "|") = 0 THEN 14810
14800 LET B(S, 0) = 1
14802 IF Y(S, 4) = 0 THEN 14810
14805 CALL "er": N(), X(), X$(), J, "ELEM_EFFECTS", "", "", "", 0
14810 NEXT J
14815 LET B(S, 3) = E
14820 NEXT S
14825 REM the fixpoint: a worklist of the fns with effects, each marking its callers
14830 LET T = 0
14835 FOR S = 2 TO X(33)
14840 IF B(S, 0) = 0 THEN 14855
14845 LET T = T + 1
14850 LET Z(T) = S
14855 NEXT S
14860 LET H = 0
14865 IF H = T THEN 14915
14870 LET H = H + 1
14875 LET Q = B(Z(H), 1)
14880 IF Q = 0 THEN 14865
14885 LET C = A(Q, 0)
14890 IF B(C, 0) = 1 THEN 14905
14895 LET B(C, 0) = 1
14897 LET T = T + 1
14900 LET Z(T) = C
14905 LET Q = A(Q, 3)
14910 GOTO 14880
14915 FOR Q = 1 TO E
14920 IF Y(A(Q, 0), 4) = 0 THEN 14935
14925 IF B(A(Q, 2), 0) = 0 THEN 14935
14930 CALL "er": N(), X(), X$(), A(Q, 1), "ELEM_EFFECTS", "", "", "", 0
14935 NEXT Q
14940 REM the cycles through each elemental fn S: forward from S (B(.,4)), backward to S (B(.,5))
14945 FOR S = 2 TO X(33)
14950 IF Y(S, 0) <> 1 THEN 15075
14955 IF Y(S, 4) = 0 THEN 15075
14960 LET B(S, 4) = S
14965 LET T = 1
14970 LET Z(1) = S
14975 LET H = 0
14980 IF H = T THEN 15015
14985 LET H = H + 1
14990 FOR Q = B(Z(H), 2) TO B(Z(H), 3)
14995 IF B(A(Q, 2), 4) = S THEN 15010
15000 LET B(A(Q, 2), 4) = S
15003 LET T = T + 1
15005 LET Z(T) = A(Q, 2)
15010 NEXT Q
15012 GOTO 14980
15015 LET B(S, 5) = S
15020 LET T = 1
15025 LET Z(1) = S
15030 LET H = 0
15035 IF H = T THEN 15060
15040 LET H = H + 1
15042 LET Q = B(Z(H), 1)
15044 IF Q = 0 THEN 15035
15046 LET C = A(Q, 0)
15048 IF B(C, 5) = S THEN 15056
15050 LET B(C, 5) = S
15052 LET T = T + 1
15054 LET Z(T) = C
15056 LET Q = A(Q, 3)
15058 GOTO 15044
15060 FOR Q = 1 TO E
15062 IF B(A(Q, 0), 4) <> S THEN 15070
15064 IF B(A(Q, 2), 5) <> S THEN 15070
15066 CALL "er": N(), X(), X$(), A(Q, 1), "ELEM_RECURSIVE", "", "", "", 0
15070 NEXT Q
15075 NEXT S
15080 SUBEND
