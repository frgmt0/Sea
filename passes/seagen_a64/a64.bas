10 REM ====================================================================================
12 REM seagen_a64 -- Sea pass 4 for arm64-macos: sea.lir -> sea.s (DESIGN 2.1, 3.6, 4.6, 4.8,
14 REM 4.9). Built as DESIGN 2.6.3: this file and a64data.bas (lines 1-59999), the modules io
16 REM diag tables, the DATA blocks errors exits consts entries records, 99999 END.
18 REM Reads sea.lir twice: pass A collects every function's parameter and result classes (a
20 REM call needs its callee's, even when it discards the results), pass B writes sea.s. Each
22 REM function is buffered and swept three times: mode 0 counts the lines it will need (more
24 REM than 240000 instructions do not fit the +-1 MiB conditional branches: the far form,
26 REM b.<inverse> 9f / b <label> / 9:), mode 1 writes the code, mode 2 the cold blocks
28 REM (_sea_err calls) and the f64 constants (.quad 0x...). Data records are copied as read.
30 REM Phase-1 allocator (DESIGN 4.9): every virtual register has an 8-byte frame slot;
32 REM operands are loaded into x9 x10 x11 (i, p) and d16 d17 d18 (f), results stored from
34 REM x9 / d16; x16 x17 address slots, data, the results area and the stack limit.
36 REM Frame, from sp up: [0,A1) outgoing stack arguments and the _sea_err argument slots;
38 REM [A1,A1+A2) the results area of calls; the LIR slots; 16 bytes per loop block (remaining
40 REM count, step); F9 the saved address of this function's own results area; the register
42 REM slots from A5 (register r at A5 + 8(r-1)); A6 bytes in all; the frame record above.
44 REM A7 = the frame (16 + A6, + realignment); A9 = 1: the prologue stack check (DESIGN 4.6).
46 REM Arrays: E E$ errors; X X$ exits; C C$ consts; Y Y$ entries; N N$ W$ R R$ F F$ Z
48 REM passes.txt; K K$ the needed constants (a64data.bas order: K(1) SLOT_SIZE, K(2)
50 REM STACK_LEAF_MAX, K(3) RC_STATIC, K(4) TAG_STR, K(5-8) STR_RC TAG LEN BYTES, K(9-11)
52 REM FMT_NPIECE NCONV PIECES, K(12-20) FP_KIND CONV FLAGS CLS WIDTH PREC TEXT TLEN SIZE,
54 REM K(21-22) FPK_TEXT CONV, K(23-27) FF_LEFT PLUS SPACE ZERO ALT, K(28-30) CLS_I F P,
56 REM K(31-33) SITE_FILE LINE SIZE, K(34) DATA_ALIGN, K(35-37) ESIZE_I64 F64 BOOL, K(38-45)
58 REM LIM_LIR_INSTRS OPERANDS REGS BLOCKS SLOTS IMMS LABELS SITES, K(46) FILE_VERSION, K(47-49)
59 REM SL_SIZE NREF REFS);
60 REM A(row,1) special code, A(row,2) template of each LIR record row; P$ M Q$ T$ templates
62 REM (M: first line, code lines, cold lines, error rows of $C $D, argument slots); V$ cc
64 REM map; U$ inversions; B$ the function's records, O their rows, G their callee, entry or
66 REM error row; G$ fields; U u values; L limbs; Q P J$ source registers, classes, scratch;
68 REM D register classes (1 i, 2 f, 3 p); T parameter registers; J slots (size, align,
70 REM offset); B blocks (kind 1 loop 2 do 3 if, else seen, hidden offset, ind); I open
72 REM blocks; S sites (file, line), H their hash; S$ signatures (name, parameter classes,
74 REM result classes); H$ #file paths; V helper limbs; W byte codes; A$ message argument.
76 REM Scalars: W0 mode (0 count, 1 code, 2 cold, 3 analysis), W1 far, W2 lines counted; F0
78 REM function number; F1 F2 F3 its pos; F4 kind; F5$ name; F6$ F7$ classes; F8 own extra
80 REM results; N0 records; M0 registers; S0 slots; A0 largest alignment; B7 blocks; K7 open
82 REM blocks; L1 leaf; X8 definition site; X9 sites; D9 data section; D8 last label; M9 mains;
83 REM Y3 the entries row of FREE (release calls it). Phase 4c: retain release mcopy slay soff.
84 REM ====================================================================================
200 DIM E(299), E$(299,5), X(19), X$(19), C(299,4), C$(299), Y(29), Y$(29,5)
205 DIM N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), Z(8)
210 DIM K(60), K$(60), A(399,2), P$(199), M(199,6), Q$(1999), T$(199,2), V$(10,3), U$(30,2)
215 DIM B$(219999), O(219999), G(219999), G$(300), U(40), L(4), Q(200), P(200), J$(200), V(4)
220 DIM D(99999), T(200), J(9999,3), B(9999,4), I(10000), S(49999,2), H(131071), S$(19999,3)
225 DIM H$(100), W(65536), A$(4)
230 FILES "sea.lir"; "sea.s"
235 LET P$ = "seagen_a64"
240 REM ---- own DATA (a64data.bas), read before the generated blocks ------------------------
245 LET K0 = 0
250 READ Z$
255 IF Z$ = "-" THEN 280
260 LET K0 = K0 + 1
265 IF K0 > 60 THEN 9970
270 LET K$(K0) = Z$
275 GOTO 250
280 LET S9$ = "|"
285 READ Z$
290 IF Z$ = "-" THEN 310
295 READ V0
300 LET S9$ = S9$ & Z$ & "=" & STR$(V0) & "|"
305 GOTO 285
310 LET V8 = 0
315 READ Z$
320 IF Z$ = "-" THEN 350
325 LET V8 = V8 + 1
330 IF V8 > 10 THEN 9970
335 LET V$(V8,1) = Z$
340 READ V$(V8,2), V$(V8,3)
345 GOTO 315
350 LET U8 = 0
355 READ Z$
360 IF Z$ = "-" THEN 390
365 LET U8 = U8 + 1
370 IF U8 > 30 THEN 9970
375 LET U$(U8,1) = Z$
380 READ U$(U8,2)
385 GOTO 355
390 LET T7 = 0
395 LET Q8 = 0
400 READ Z$
405 IF Z$ = "-" THEN 495
410 LET T7 = T7 + 1
415 IF T7 > 199 THEN 9970
420 LET P$(T7) = Z$
425 READ T$(T7,1), T$(T7,2)
430 READ V0, V1
435 IF Q8 + V0 + V1 > 1999 THEN 9970
440 LET M(T7,1) = Q8 + 1
445 LET M(T7,2) = V0
450 LET M(T7,3) = V1
455 LET M(T7,6) = 0
460 FOR I5 = 1 TO V0 + V1
465 LET Q8 = Q8 + 1
470 READ Q$(Q8)
475 IF I5 <= V0 THEN 490
477 REM a cold line's $k: argument slot k is used
478 FOR I6 = 0 TO 9
480 IF POS(Q$(Q8), "$" & STR$(I6)) = 0 THEN 486
482 IF I6 + 1 <= M(T7,6) THEN 486
484 LET M(T7,6) = I6 + 1
486 NEXT I6
490 NEXT I5
492 GOTO 400
495 REM ---- the generated blocks (DESIGN 2.6.3), in their canonical order ---------------------
500 CALL "tb_errors": P$, E(), E$(), 299, E0
505 CALL "tb_exits": P$, E(), E$(), E0, X(), X$(), 19, N7
510 CALL "tb_consts": P$, E(), E$(), E0, C(), C$(), 299, C9
515 CALL "tb_entries": P$, E(), E$(), E0, Y(), Y$(), 29, Y9
520 LET Z(1) = 39
525 LET Z(2) = 299
530 LET Z(3) = 399
535 LET Z(4) = 1499
540 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), R(), R$(), F(), F$(), Z()
545 REM the constants this pass needs, as numbers
550 FOR I5 = 1 TO K0
555 CALL "tb_cval": C(), C$(), C9, K$(I5), V0, T
560 IF T = 0 THEN 575
565 LET M$ = "constant " & K$(I5) & " is not in the consts table"
570 GOTO 9975
575 LET K(I5) = V0
580 NEXT I5
585 LET M$ = "a LIR limit is larger than the arrays of seagen_a64"
590 IF K(38) + K(42) + 2 > 219999 THEN 9975
595 IF K(40) > 99999 THEN 9975
600 IF K(41) > 9999 THEN 9975
605 IF K(42) > 9999 THEN 9975
610 IF K(45) > 49999 THEN 9975
615 REM the error rows of the templates' cold blocks and of the stack check
620 FOR I5 = 1 TO T7
625 FOR I6 = 1 TO 2
630 LET M(I5, 3 + I6) = 0
635 IF T$(I5,I6) = "-" THEN 660
640 CALL "dg_find": T$(I5,I6), E$(), E0, V0
645 LET M$ = "template error " & T$(I5,I6) & " is not in the error table"
650 IF V0 = 0 THEN 9975
655 LET M(I5, 3 + I6) = V0
660 NEXT I6
665 NEXT I5
670 CALL "dg_find": "STACK_OVERFLOW", E$(), E0, E9
675 LET M$ = "STACK_OVERFLOW is not in the error table"
680 IF E9 = 0 THEN 9975
685 REM every LIR record row: special code, template; O$ = |name=row|... for the lookup
690 LET O$ = "|"
695 FOR I5 = 1 TO Z(7)
700 LET A(I5,1) = 0
705 LET A(I5,2) = 0
710 IF R(I5,1) < 5 THEN 770
712 IF R(I5,1) > 6 THEN 770
715 LET O$ = O$ & R$(I5) & "=" & STR$(I5) & "|"
720 LET V0 = POS(S9$, "|" & R$(I5) & "=")
725 IF V0 = 0 THEN 740
730 LET V1 = POS(S9$, "|", V0 + 1)
735 LET A(I5,1) = VAL(SEG$(S9$, V0 + LEN(R$(I5)) + 2, V1 - 1))
740 LET Z$ = R$(I5)
745 IF Z$ <> "rcount" THEN 755
750 LET Z$ = "rcount0"
755 FOR I6 = 1 TO T7
760 IF P$(I6) <> Z$ THEN 768
765 LET A(I5,2) = I6
768 NEXT I6
770 NEXT I5
775 LET T9 = 0
780 FOR I6 = 1 TO T7
785 IF P$(I6) <> "rcount1" THEN 795
790 LET T9 = I6
795 NEXT I6
800 LET M$ = "template rcount1 missing"
805 IF T9 = 0 THEN 9975
810 REM the phase-4 records retain release mcopy (codes 22-24) are emitted from their templates
815 FOR I5 = 1 TO Z(7)
820 IF A(I5,1) < 22 THEN 840
825 IF A(I5,1) > 24 THEN 840
830 LET M$ = "template " & R$(I5) & " missing"
835 IF A(I5,2) = 0 THEN 9975
840 NEXT I5
845 REM Y3 = the row of the entry FREE, which release calls (DESIGN 4.8, 4.9); 0: checked at a
850 REM release
855 LET Y3 = 0
860 FOR I5 = 1 TO Y9
865 IF Y$(I5,1) <> "FREE" THEN 875
870 LET Y3 = I5
875 NEXT I5
1000 REM ---- pass A: the signature of every function ---------------------------------------
1005 CALL "io_hdr": 1, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), K(46), T$, H$(), 100, N1, L$
1010 IF T$ <> "arm64-macos" THEN 9980
1015 LET L0 = N1 + 3
1020 LET G0 = 0
1025 IF L$ = "#end" THEN 1120
1030 CALL "io_split": L$, G$(), 300, C0
1035 IF C0 < 1 THEN 9990
1040 IF G$(1) <> "func" THEN 1110
1045 IF C0 < 6 THEN 9990
1050 LET G0 = G0 + 1
1052 LET M$ = "more functions than the signature table holds"
1055 IF G0 > 19999 THEN 9975
1060 LET S$(G0,1) = G$(2)
1061 GOSUB 1130
1065 CALL "io_u": G$(5), V0, T
1070 IF T <> 0 THEN 9990
1075 IF 6 + V0 > C0 THEN 9990
1080 LET Z$ = ""
1085 FOR I8 = 1 TO V0
1090 LET Z$ = Z$ & SEG$(G$(5 + I8), 1, 1)
1095 NEXT I8
1097 LET S$(G0,2) = Z$
1099 CALL "io_u": G$(6 + V0), V1, T
1101 IF T <> 0 THEN 9990
1103 IF 6 + V0 + V1 <> C0 THEN 9990
1104 LET Z$ = ""
1105 FOR I8 = 1 TO V1
1106 LET Z$ = Z$ & G$(6 + V0 + I8)
1107 NEXT I8
1108 LET S$(G0,3) = Z$
1110 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
1115 GOTO 1025
1120 RESTORE #1
1122 FOR I8 = 0 TO 131071
1124 LET H(I8) = 0
1126 NEXT I8
1128 GOTO 1200
1130 REM ---- pass A: no two func records share a name (DESIGN 3.6.5); a hash set of them in H,
1131 REM cleared before pass B uses H for the sites
1132 CHANGE G$(2) TO W
1133 LET S5 = 0
1134 FOR I8 = 1 TO W(0)
1135 LET S5 = S5 * 31 + W(I8)
1136 LET S5 = S5 - INT(S5 / 131071) * 131071
1137 NEXT I8
1138 IF H(S5) = 0 THEN 1145
1139 IF S$(H(S5),1) = G$(2) THEN 9990
1140 LET S5 = S5 + 1
1141 IF S5 < 131071 THEN 1138
1142 LET S5 = 0
1143 GOTO 1138
1145 LET H(S5) = G0
1146 RETURN
1200 REM ---- pass B: the code ----------------------------------------------------------------
1205 CALL "io_hdr": 1, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), K(46), T$, H$(), 100, N1, L$
1210 LET L0 = N1 + 3
1215 SCRATCH #2
1220 LET W0 = 1
1225 LET X$ = "// sea.s -- written by seagen_a64 from sea.lir (Sea DESIGN.md 4.8, 4.9)"
1230 GOSUB 9000
1235 LET X$ = ".section __TEXT,__text,regular,pure_instructions"
1240 GOSUB 9010
1245 REM one top-level record per round: a function (buffered to endfunc) or a data record
1250 IF L$ = "#end" THEN 8000
1255 CALL "io_split": L$, G$(), 300, C0
1260 IF C0 < 1 THEN 9990
1265 LET Z$ = G$(1)
1270 GOSUB 9350
1275 IF I0 = 0 THEN 9990
1280 IF Y0 = 1 THEN 1300
1285 IF Y0 = 30 THEN 7000
1290 IF Y0 = 31 THEN 7100
1292 IF Y0 = 34 THEN 7300
1293 IF Y0 = 37 THEN 7455
1295 GOTO 9990
1300 IF D9 <> 0 THEN 9990
1305 GOSUB 3700
1310 LET B$(1) = L$
1315 LET N0 = 1
1320 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
1325 LET N0 = N0 + 1
1330 IF N0 <= 219999 THEN 1345
1335 LET A$(1) = "instructions"
1340 GOTO 9960
1345 LET B$(N0) = L$
1350 IF L$ = "#end" THEN 9990
1355 IF L$ <> "endfunc" THEN 1320
1360 GOSUB 3000
1365 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
1370 GOTO 1250
3000 REM ---- one function: analysis (W0 = 3), layout, sweeps ---------------------------------
3005 LET F0 = F0 + 1
3010 FOR I5 = 1 TO M0
3015 LET D(I5) = 0
3020 NEXT I5
3025 LET M0 = 0
3030 LET S0 = 0
3035 LET S9 = 0
3040 LET A0 = 16
3045 LET B7 = 0
3050 LET K7 = 0
3055 LET O0 = 0
3060 LET I9 = 0
3065 LET N9 = 0
3070 LET L1 = 1
3075 LET A1 = 0
3080 LET A2 = 0
3085 LET W0 = 3
3090 FOR J = 1 TO N0 - 1
3095 CALL "io_split": B$(J), G$(), 300, C0
3100 IF C0 < 1 THEN 9990
3105 LET Z$ = G$(1)
3110 GOSUB 9350
3115 IF I0 = 0 THEN 9990
3120 LET O(J) = I0
3125 LET G(J) = 0
3130 IF J > 1 THEN 3145
3135 IF Y0 <> 1 THEN 9990
3140 GOTO 3155
3145 IF Y0 = 1 THEN 9990
3150 IF Y0 >= 30 THEN 9990
3155 GOSUB 9400
3160 IF J > 1 THEN 3200
3165 REM the func record: parameter registers and classes, result classes
3170 LET F6$ = ""
3175 FOR I5 = 1 TO P0
3180 LET T(I5) = Q(I5)
3182 IF Q(I5) <> I5 THEN 9990
3185 LET F6$ = F6$ & SEG$("ifp", P(I5), P(I5))
3190 NEXT I5
3191 LET F7$ = ""
3192 FOR I5 = 1 TO U(6)
3193 LET F7$ = F7$ & G$(6 + U(4) + I5)
3194 NEXT I5
3195 LET Z6$ = F7$
3196 GOSUB 9630
3197 LET F8 = Z8
3198 IF F4 = 2 THEN 3480
3199 IF P0 + U(6) = 0 THEN 3480
3200 IF Y0 <> 2 THEN 3260
3205 REM a slot: right after func, numbered s1, s2, ...; the alignment a power of two
3210 IF S9 = 1 THEN 9990
3215 IF H1 <> S0 + 1 THEN 9990
3220 LET S0 = H1
3225 IF S0 <= K(42) THEN 3240
3230 LET A$(1) = "slots"
3235 GOTO 9960
3240 LET J(S0,1) = U(2)
3242 LET J(S0,2) = U(3)
3244 LET Y1 = 1
3246 IF Y1 = U(3) THEN 3254
3248 IF Y1 > U(3) THEN 9990
3250 LET Y1 = Y1 * 2
3252 GOTO 3246
3254 IF U(3) <= A0 THEN 3480
3256 LET A0 = U(3)
3258 GOTO 3480
3260 LET S9 = 1
3262 LET N9 = N9 + 1
3264 LET O0 = O0 + C0 - 1 - X5
3266 IF Y0 = 0 THEN 3300
3268 ON Y0 GOTO 9990,9990,9990,3290,3290,9990,3295,3320,3360,3320,3360,3320,3320,3380,3360,3400,3400,3410,3420,3442,3460,3480,3496,3480
3290 LET I9 = I9 + 1
3292 GOTO 3480
3295 IF H1 < 1 THEN 9990
3296 IF H1 > S0 THEN 9990
3297 GOTO 3480
3300 REM an instruction made from a template (rcount: by its incl)
3302 LET T5 = A(I0,2)
3303 IF T5 = 0 THEN 9990
3304 IF R$(I0) <> "rcount" THEN 3309
3305 IF U0 > 1 THEN 9990
3306 IF U0 = 0 THEN 3309
3307 LET T5 = T9
3309 IF R$(I0) <> "mov" THEN 3312
3311 IF D2 <> P(1) THEN 9990
3312 IF R$(I0) <> "chkb" THEN 3314
3313 IF U0 > 1 THEN 9990
3314 IF M(T5,6) * K(1) <= A1 THEN 3316
3315 LET A1 = M(T5,6) * K(1)
3316 LET A$(1) = "labels"
3318 IF H0 > K(44) THEN 9960
3319 GOTO 3620
3320 REM opening a block: numbered in order, pushed
3322 LET Y1 = VAL(G$(2))
3324 IF Y1 <> B7 + 1 THEN 9990
3326 LET B7 = Y1
3328 IF B7 <= K(41) THEN 3334
3330 LET A$(1) = "blocks"
3332 GOTO 9960
3334 LET K7 = K7 + 1
3336 LET I(K7) = B7
3338 LET B(B7,2) = 0
3340 LET B(B7,4) = 0
3342 LET B(B7,1) = 3
3344 IF Y0 <> 10 THEN 3347
3346 LET B(B7,1) = 2
3347 IF Y0 <> 8 THEN 3480
3348 GOSUB 3630
3349 LET B(B7,4) = Q(1)
3350 GOTO 3480
3360 REM closing: the innermost open block, of the matching kind
3362 LET Y1 = VAL(G$(2))
3364 IF K7 = 0 THEN 9990
3366 IF I(K7) <> Y1 THEN 9990
3368 LET Y2 = 3
3370 IF Y0 <> 9 THEN 3372
3371 LET Y2 = 1
3372 IF Y0 <> 11 THEN 3374
3373 LET Y2 = 2
3374 IF B(Y1,1) <> Y2 THEN 9990
3376 LET K7 = K7 - 1
3378 GOTO 3480
3380 REM else: of the innermost open if or ifz, once
3382 LET Y1 = VAL(G$(2))
3384 IF K7 = 0 THEN 9990
3386 IF I(K7) <> Y1 THEN 9990
3388 IF B(Y1,1) <> 3 THEN 9990
3390 IF B(Y1,2) <> 0 THEN 9990
3392 LET B(Y1,2) = 1
3394 GOTO 3480
3400 REM exit / next: an enclosing loop or do
3401 LET Y1 = VAL(G$(2))
3402 FOR I5 = 1 TO K7
3403 IF I(I5) = Y1 THEN 3406
3404 NEXT I5
3405 GOTO 9990
3406 IF B(Y1,1) = 3 THEN 9990
3407 GOTO 3480
3410 REM ret: the function's result count and classes
3411 IF P0 <> LEN(F7$) THEN 9990
3412 FOR I5 = 1 TO P0
3413 IF SEG$("ifp", P(I5), P(I5)) <> SEG$(F7$, I5, I5) THEN 9990
3414 NEXT I5
3415 GOTO 3480
3420 REM call: the callee's signature (pass A); its extra results need the results area
3421 LET L1 = 0
3422 IF G$(2) = ".main" THEN 9990
3423 FOR I5 = 1 TO G0
3424 IF S$(I5,1) = G$(2) THEN 3427
3425 NEXT I5
3426 GOTO 9990
3427 LET G(J) = I5
3428 LET Z6$ = S$(I5,3)
3429 GOSUB 9630
3430 LET Y6 = 0
3431 IF Z8 = 0 THEN 3435
3432 LET Y6 = 1
3433 IF 8 * Z8 <= A2 THEN 3435
3434 LET A2 = 8 * Z8
3435 LET Z7$ = S$(G(J),2)
3436 LET Y7 = U(2)
3437 LET Y4 = 4
3438 LET Y8 = 0
3439 GOSUB 3550
3440 GOTO 3480
3441 REM rcall: the entry of rt.inc; site S: the site index is one more integer argument
3442 LET L1 = 0
3443 FOR I5 = 1 TO Y9
3444 IF Y$(I5,2) = G$(2) THEN 3447
3445 NEXT I5
3446 GOTO 9990
3447 LET G(J) = I5
3448 LET Y8 = 0
3449 IF Y$(I5,3) <> "S" THEN 3451
3450 LET Y8 = 1
3451 IF Y8 <> X3 THEN 9990
3452 LET Z7$ = Y$(I5,4)
3453 IF Z7$ <> "-" THEN 3455
3454 LET Z7$ = ""
3455 LET Z6$ = Y$(I5,5)
3456 IF Z6$ <> "-" THEN 3458
3457 LET Z6$ = ""
3458 LET M$ = "a runtime entry with results beyond the registers"
3459 GOTO 3462
3460 REM chk: an error of phase R
3461 GOTO 3470
3462 GOSUB 9630
3463 IF Z8 > 0 THEN 9975
3464 LET Y6 = 0
3465 LET Y7 = U(3)
3466 LET Y4 = 5
3467 GOSUB 3550
3468 GOTO 3480
3470 CALL "dg_find": G$(3), E$(), E0, Y1
3471 IF Y1 = 0 THEN 9990
3472 IF E$(Y1,2) <> "R" THEN 9990
3473 LET G(J) = Y1
3474 GOSUB 3600
3475 IF Y2 <> U(4) THEN 9990
3476 IF (P0 - 1) * K(1) <= A1 THEN 3480
3478 LET A1 = (P0 - 1) * K(1)
3480 NEXT J
3482 IF K7 <> 0 THEN 9990
3484 LET A$(1) = "instructions"
3485 IF N9 > K(38) THEN 9960
3486 LET A$(1) = "operands"
3487 IF O0 > K(39) THEN 9960
3488 LET A$(1) = "immediates"
3489 IF I9 > K(43) THEN 9960
3490 GOSUB 3800
3492 GOSUB 3900
3494 RETURN
3496 REM release: its sequence calls the FREE entry, so the function is not a leaf (DESIGN 4.9)
3497 LET L1 = 0
3498 LET M$ = "entry FREE is not in the entries table"
3499 IF Y3 = 0 THEN 9975
3500 GOTO 3480
3550 REM ---- arguments P() against classes Z7$, result registers G$(Y4..) against Z6$ (Y7 of
3551 REM them, or 0); the stack bytes of the arguments (Y6 = 1: x0 holds the results area;
3552 REM Y8 = 1: the site index is one more integer argument) into A1
3553 IF P0 <> LEN(Z7$) THEN 9990
3554 FOR I5 = 1 TO P0
3555 IF SEG$("ifp", P(I5), P(I5)) <> SEG$(Z7$, I5, I5) THEN 9990
3556 NEXT I5
3557 IF Y7 = 0 THEN 3565
3558 IF Y7 <> LEN(Z6$) THEN 9990
3559 FOR I5 = 1 TO Y7
3560 IF SEG$(G$(Y4 + I5 - 1), 1, 1) <> SEG$(Z6$, I5, I5) THEN 9990
3561 NEXT I5
3565 LET G1 = Y6
3566 LET G2 = 0
3567 LET G3 = 0
3568 FOR I5 = 1 TO P0 + Y8
3569 IF I5 > P0 THEN 3575
3570 IF P(I5) <> 2 THEN 3575
3571 LET G2 = G2 + 1
3572 IF G2 <= 8 THEN 3580
3573 LET G3 = G3 + 1
3574 GOTO 3580
3575 LET G1 = G1 + 1
3576 IF G1 <= 8 THEN 3580
3577 LET G3 = G3 + 1
3580 NEXT I5
3582 IF 8 * G3 <= A1 THEN 3586
3584 LET A1 = 8 * G3
3586 RETURN
3600 REM ---- Y2 = the argument slots the args letters of error Y1 need: h two, the others one
3601 REM (DESIGN 2.6.2); a chk names exactly that many (DESIGN 3.6.5, 4.9)
3602 LET Y2 = 0
3604 LET Z$ = E$(Y1,4)
3606 IF Z$ = "-" THEN 3618
3608 FOR I5 = 1 TO LEN(Z$)
3610 LET Y2 = Y2 + 1
3612 IF SEG$(Z$, I5, I5) <> "h" THEN 3616
3614 LET Y2 = Y2 + 1
3616 NEXT I5
3618 RETURN
3620 REM la: the highest data label referenced, L8; the file must define it (checked at #end)
3622 IF R$(I0) <> "la" THEN 3480
3624 IF H0 <= L8 THEN 3480
3626 LET L8 = H0
3628 GOTO 3480
3630 REM a loop: its ind is not the ind of an enclosing loop (the loop writes it at each step)
3632 LET R0 = Q(1)
3634 GOSUB 9660
3636 LET B(B7,1) = 1
3638 RETURN
3700 REM ---- the func record (in G$): name, kind, position --------------------------------
3705 IF C0 < 6 THEN 9990
3710 LET F5$ = G$(2)
3715 CALL "io_pos": G$(4), F1, F2, F3, T
3720 IF T <> 0 THEN 9990
3725 IF F1 >= N1 THEN 9990
3730 LET F4 = 2
3735 IF G$(3) = "fn" THEN 3750
3740 IF G$(3) <> "main" THEN 9990
3745 LET F4 = 1
3750 IF F5$ = ".main" THEN 3790
3755 IF F4 = 1 THEN 9990
3760 REM a fn's name becomes the label Lfn_<name>: letters, digits, _ (LANGUAGE 3.3)
3765 CHANGE F5$ TO W
3770 FOR I5 = 1 TO W(0)
3772 LET Y1 = W(I5)
3774 IF Y1 = 95 THEN 3786
3776 IF Y1 < 48 THEN 9990
3778 IF Y1 <= 57 THEN 3786
3780 IF Y1 < 65 THEN 9990
3782 IF Y1 <= 90 THEN 3786
3783 IF Y1 < 97 THEN 9990
3784 IF Y1 > 122 THEN 9990
3786 NEXT I5
3788 RETURN
3790 IF F4 <> 1 THEN 9990
3792 LET M9 = M9 + 1
3794 IF M9 > 1 THEN 9990
3796 RETURN
3800 REM ---- frame layout (see the header) ---------------------------------------------------
3805 LET Y7 = A1 + A2
3810 FOR I5 = 1 TO S0
3815 LET Y1 = J(I5,2)
3820 LET Y7 = INT((Y7 + Y1 - 1) / Y1) * Y1
3825 LET J(I5,3) = Y7
3830 LET Y7 = Y7 + J(I5,1)
3835 NEXT I5
3840 LET Y7 = INT((Y7 + 7) / 8) * 8
3845 FOR I5 = 1 TO B7
3850 IF B(I5,1) <> 1 THEN 3860
3855 LET B(I5,3) = Y7
3858 LET Y7 = Y7 + 16
3860 NEXT I5
3862 LET F9 = 0
3864 IF F8 = 0 THEN 3870
3866 LET F9 = Y7
3868 LET Y7 = Y7 + 8
3870 LET A5 = Y7
3872 LET Y7 = Y7 + 8 * M0
3874 LET A6 = INT((Y7 + 15) / 16) * 16
3876 LET A8 = 0
3878 IF A0 <= 16 THEN 3882
3880 LET A8 = 1
3882 LET A7 = 16 + A6
3884 IF A8 = 0 THEN 3888
3886 LET A7 = A7 + A0 - 16
3888 LET A9 = 0
3890 IF L1 = 0 THEN 3894
3892 IF A7 <= K(2) THEN 3896
3894 LET A9 = 1
3896 RETURN
3900 REM ---- the definition site (DESIGN 4.6, 4.9), then the three sweeps ---------------------
3910 LET X1 = F1
3915 LET X2 = F2
3920 LET W0 = 1
3925 GOSUB 9300
3928 LET X8 = X0
3930 LET W0 = 0
3935 LET W2 = 0
3940 LET W1 = 0
3945 GOSUB 4000
3950 GOSUB 4300
3955 GOSUB 4400
3960 GOSUB 4450
3965 IF W2 <= 250000 THEN 3975
3970 LET W1 = 1
3975 LET W0 = 1
3980 GOSUB 4000
3982 GOSUB 4300
3984 GOSUB 4400
3986 LET W0 = 2
3988 GOSUB 4450
3990 GOSUB 4300
3995 RETURN
4000 REM ---- label, stack check, frame, parameters ---------------------------------------------
4005 LET X$ = "// " & F5$ & " at " & STR$(F1) & ":" & STR$(F2) & ":" & STR$(F3)
4010 GOSUB 9000
4015 LET X$ = ".p2align 2"
4020 GOSUB 9010
4025 IF F4 <> 1 THEN 4050
4030 LET X$ = ".globl _sea_main"
4035 GOSUB 9010
4040 LET X$ = "_sea_main:"
4045 GOTO 4055
4050 LET X$ = "Lfn_" & F5$ & ":"
4055 GOSUB 9000
4060 IF A9 = 0 THEN 4100
4062 REM r = sp - _sea_stack_limit; a borrow (sp below the limit) or r < the frame size, unsigned,
4063 REM is a stack overflow at the definition line; nothing wraps for any frame size (DESIGN 4.6)
4064 LET X$ = "adrp x17, _sea_stack_limit@PAGE"
4066 GOSUB 9010
4068 LET X$ = "ldr x17, [x17, _sea_stack_limit@PAGEOFF]"
4070 GOSUB 9010
4072 LET X$ = "subs x16, sp, x17"
4074 GOSUB 9010
4076 LET Z1$ = "b.lo"
4078 LET Z2$ = ""
4080 LET Z3$ = "L" & STR$(F0) & "_so"
4082 GOSUB 9100
4084 LET Z5 = A7
4086 LET Z5$ = "x17"
4088 GOSUB 9050
4090 LET X$ = "cmp x16, x17"
4092 GOSUB 9010
4094 LET Z1$ = "b.lo"
4095 LET Z2$ = ""
4096 LET Z3$ = "L" & STR$(F0) & "_so"
4097 GOSUB 9100
4100 LET X$ = "stp x29, x30, [sp, #-16]!"
4105 GOSUB 9010
4110 LET X$ = "mov x29, sp"
4115 GOSUB 9010
4120 IF A6 = 0 THEN 4160
4125 IF A6 > 4095 THEN 4140
4130 LET X$ = "sub sp, sp, #" & STR$(A6)
4135 GOTO 4155
4140 LET Z5 = A6
4145 LET Z5$ = "x16"
4150 GOSUB 9050
4152 LET X$ = "sub sp, sp, x16"
4155 GOSUB 9010
4160 IF A8 = 0 THEN 4180
4165 LET X$ = "mov x16, sp"
4170 GOSUB 9010
4175 LET X$ = "and sp, x16, #-" & STR$(A0)
4178 GOSUB 9010
4180 REM the parameters into their slots: x0-x7 (after the results area), d0-d7, the stack
4185 LET G1 = 0
4190 LET G2 = 0
4195 LET G3 = 0
4200 IF F8 = 0 THEN 4225
4205 LET Z1$ = "str"
4210 LET Z2$ = "x0"
4212 LET Z3 = F9
4214 LET Z4$ = "sp"
4216 GOSUB 9020
4220 LET G1 = 1
4225 FOR K2 = 1 TO LEN(F6$)
4230 LET V1 = A5 + 8 * (T(K2) - 1)
4232 LET Z1$ = "str"
4234 LET Z4$ = "sp"
4236 LET Z3 = V1
4238 IF SEG$(F6$, K2, K2) = "f" THEN 4250
4240 IF G1 >= 8 THEN 4260
4242 LET Z2$ = "x" & STR$(G1)
4244 LET G1 = G1 + 1
4246 GOSUB 9020
4248 GOTO 4290
4250 IF G2 >= 8 THEN 4260
4252 LET Z2$ = "d" & STR$(G2)
4254 LET G2 = G2 + 1
4256 GOSUB 9020
4258 GOTO 4290
4260 LET Z1$ = "ldr"
4262 LET Z2$ = "x9"
4264 LET Z3 = 16 + 8 * G3
4266 LET Z4$ = "x29"
4268 GOSUB 9020
4270 LET G3 = G3 + 1
4272 LET Z1$ = "str"
4274 LET Z3 = V1
4276 LET Z4$ = "sp"
4278 GOSUB 9020
4290 NEXT K2
4295 RETURN
4300 REM ---- the records of the function (slots have no code) ---------------------------------
4305 FOR J = 2 TO N0 - 1
4310 IF A(O(J),1) = 2 THEN 4320
4315 GOSUB 5000
4320 NEXT J
4325 RETURN
4400 REM ---- epilogue: every ret branches here ---------------------------------------------------
4405 LET X$ = "L" & STR$(F0) & "_ret:"
4410 GOSUB 9000
4415 LET X$ = "mov sp, x29"
4420 GOSUB 9010
4425 LET X$ = "ldp x29, x30, [sp], #16"
4430 GOSUB 9010
4435 LET X$ = "ret"
4440 GOSUB 9010
4445 RETURN
4450 REM ---- the stack check's cold block: _sea_err(STACK_OVERFLOW, definition site) -------------
4455 IF A9 = 0 THEN 4490
4460 LET X$ = "L" & STR$(F0) & "_so:"
4465 GOSUB 9000
4470 LET Z8 = E(E9)
4475 LET X0 = X8
4480 GOSUB 9375
4490 RETURN
5000 REM ---- one record: code (modes 0, 1) and cold part (modes 0, 2) ----------------------------
5005 LET I0 = O(J)
5010 LET Y0 = A(I0,1)
5015 CALL "io_split": B$(J), G$(), 300, C0
5020 GOSUB 9400
5025 LET L9$ = "L" & STR$(F0) & "_"
5030 IF Y0 = 0 THEN 5100
5035 ON Y0 GOTO 9990,9990,9990,5300,5350,9990,5400,5450,5500,5550,5600,5650,5650,5700,5750,5800,5850,5900,6000,6200,6400,6500,6500,6500
5100 REM ---- an instruction from its template --------------------------------------------------
5102 LET T5 = A(I0,2)
5104 IF R$(I0) <> "rcount" THEN 5110
5106 IF U0 <> 1 THEN 5110
5108 LET T5 = T9
5110 IF W0 = 2 THEN 5200
5112 LET G1 = 0
5114 LET G2 = 0
5116 FOR K2 = 1 TO P0
5118 LET Z1$ = "ldr"
5120 LET Z4$ = "sp"
5122 LET Z3 = A5 + 8 * (Q(K2) - 1)
5124 IF P(K2) = 2 THEN 5132
5126 LET G1 = G1 + 1
5128 LET Z2$ = "x" & STR$(8 + G1)
5130 GOTO 5136
5132 LET G2 = G2 + 1
5134 LET Z2$ = "d" & STR$(15 + G2)
5136 LET J$(K2) = Z2$
5138 GOSUB 9020
5140 NEXT K2
5142 LET M$ = "a template instruction with more than three operands of a class"
5144 IF G1 > 3 THEN 9975
5146 IF G2 > 3 THEN 9975
5148 IF B1 = 0 THEN 5152
5150 GOSUB 9250
5152 FOR I6 = M(T5,1) TO M(T5,1) + M(T5,2) - 1
5154 LET Z$ = Q$(I6)
5156 GOSUB 9150
5158 NEXT I6
5160 IF D1 = 0 THEN 5200
5162 LET Z1$ = "str"
5164 LET Z4$ = "sp"
5166 LET Z3 = A5 + 8 * (D1 - 1)
5168 LET Z2$ = "x9"
5170 IF D2 <> 2 THEN 5174
5172 LET Z2$ = "d16"
5174 GOSUB 9020
5176 IF E1 = 0 THEN 5200
5178 LET Z1$ = "str"
5180 LET Z4$ = "sp"
5182 LET Z3 = A5 + 8 * (E1 - 1)
5184 LET Z2$ = "x10"
5186 GOSUB 9020
5200 IF W0 = 1 THEN 5290
5205 IF M(T5,4) = 0 THEN 5240
5210 LET X$ = L9$ & "e" & STR$(J) & ":"
5215 GOSUB 9000
5220 FOR I6 = M(T5,1) + M(T5,2) TO M(T5,1) + M(T5,2) + M(T5,3) - 1
5225 LET Z$ = Q$(I6)
5228 GOSUB 9150
5230 NEXT I6
5232 LET Z8 = E(M(T5,4))
5235 GOSUB 9375
5240 IF M(T5,5) = 0 THEN 5290
5245 LET X$ = L9$ & "f" & STR$(J) & ":"
5250 GOSUB 9000
5255 LET Z8 = E(M(T5,5))
5260 GOSUB 9375
5290 RETURN
5300 REM ---- li: the constant into x9 -------------------------------------------------------------
5305 IF W0 = 2 THEN 5290
5310 FOR I1 = 1 TO 4
5315 LET V(I1) = L(I1)
5320 NEXT I1
5325 LET Z5$ = "x9"
5330 GOSUB 9060
5335 LET Z2$ = "x9"
5340 GOSUB 5960
5341 GOTO 5290
5350 REM ---- lf: the constant is a .quad in the cold part, loaded pc-relative ------------------
5355 LET Y6$ = L9$ & "c" & STR$(J)
5360 IF W0 = 2 THEN 5385
5365 LET X$ = "adrp x16, " & Y6$ & "@PAGE"
5370 GOSUB 9010
5375 LET X$ = "ldr d16, [x16, " & Y6$ & "@PAGEOFF]"
5378 GOSUB 9010
5380 LET Z2$ = "d16"
5382 GOSUB 5960
5383 IF W0 = 1 THEN 5290
5385 LET X$ = ".p2align 3"
5388 GOSUB 9010
5390 LET X$ = Y6$ & ":"
5392 GOSUB 9000
5394 LET X$ = ".quad 0x" & SEG$(G$(3), 2, 17)
5396 GOSUB 9010
5398 GOTO 5290
5400 REM ---- sa: the address of a LIR slot --------------------------------------------------------
5405 IF W0 = 2 THEN 5290
5410 LET Y7 = J(H1,3)
5415 IF Y7 > 4095 THEN 5430
5420 LET X$ = "add x9, sp, #" & STR$(Y7)
5425 GOTO 5440
5430 LET Z5 = Y7
5432 LET Z5$ = "x9"
5434 GOSUB 9050
5436 LET X$ = "add x9, sp, x9"
5440 GOSUB 9010
5445 LET Z2$ = "x9"
5448 GOSUB 5960
5449 GOTO 5290
5450 REM ---- loop b ind start last step: ind, remaining last - k and step stored; no entry test ----
5451 IF W0 = 2 THEN 5290
5452 LET Y7 = VAL(G$(2))
5453 LET Y6$ = L9$ & STR$(Y7) & "_"
5454 LET Z1$ = "ldr"
5455 LET Z4$ = "sp"
5456 LET Z2$ = "x9"
5457 LET Z3 = A5 + 8 * (Q(2) - 1)
5458 GOSUB 9020
5459 LET Z2$ = "x10"
5460 LET Z3 = A5 + 8 * (Q(3) - 1)
5461 GOSUB 9020
5462 LET Z2$ = "x11"
5463 LET Z3 = A5 + 8 * (Q(4) - 1)
5464 GOSUB 9020
5465 LET Z1$ = "str"
5466 LET Z2$ = "x9"
5467 LET Z3 = A5 + 8 * (Q(1) - 1)
5468 GOSUB 9020
5469 LET Z2$ = "x10"
5470 LET Z3 = B(Y7,3)
5471 GOSUB 9020
5472 LET Z2$ = "x11"
5473 LET Z3 = B(Y7,3) + 8
5474 GOSUB 9020
5475 LET X$ = Y6$ & "top:"
5476 GOSUB 9000
5485 GOTO 5290
5500 REM ---- endloop b: done when k = last (remaining 0), else count down, ind + step, the top --
5501 IF W0 = 2 THEN 5290
5502 LET Y7 = VAL(G$(2))
5503 LET Y6$ = L9$ & STR$(Y7) & "_"
5504 LET X$ = Y6$ & "next:"
5505 GOSUB 9000
5506 LET Z1$ = "ldr"
5507 LET Z2$ = "x10"
5508 LET Z3 = B(Y7,3)
5509 LET Z4$ = "sp"
5510 GOSUB 9020
5511 LET Z1$ = "cbz"
5512 LET Z2$ = "x10, "
5513 LET Z3$ = Y6$ & "exit"
5514 GOSUB 9100
5515 LET Z2$ = "x10"
5516 LET Z3 = B(Y7,3)
5517 LET Z4$ = "sp"
5518 LET X$ = "sub x10, x10, #1"
5519 GOSUB 9010
5520 LET Z1$ = "str"
5521 GOSUB 9020
5522 LET Z1$ = "ldr"
5523 LET Z2$ = "x9"
5524 LET Z3 = A5 + 8 * (B(Y7,4) - 1)
5525 GOSUB 9020
5526 LET Z2$ = "x11"
5527 LET Z3 = B(Y7,3) + 8
5528 GOSUB 9020
5529 LET X$ = "add x9, x9, x11"
5530 GOSUB 9010
5531 LET Z1$ = "str"
5532 LET Z2$ = "x9"
5533 LET Z3 = A5 + 8 * (B(Y7,4) - 1)
5534 GOSUB 9020
5535 LET X$ = "b " & Y6$ & "top"
5536 GOSUB 9010
5537 LET X$ = Y6$ & "exit:"
5538 GOSUB 9000
5539 GOTO 5290
5550 REM ---- do b: the top label -----------------------------------------------------------------
5552 IF W0 = 2 THEN 5290
5554 LET Y6$ = L9$ & G$(2) & "_"
5556 LET X$ = Y6$ & "top:"
5558 GOSUB 9000
5560 GOTO 5290
5600 REM ---- enddo b -------------------------------------------------------------------------------
5602 IF W0 = 2 THEN 5290
5604 LET Y6$ = L9$ & G$(2) & "_"
5606 LET X$ = "b " & Y6$ & "top"
5608 GOSUB 9010
5610 LET X$ = Y6$ & "exit:"
5612 GOSUB 9000
5614 GOTO 5290
5650 REM ---- if b c / ifz b c: to the else label when c = 0 / c <> 0 --------------------------
5652 IF W0 = 2 THEN 5290
5654 LET Y6$ = L9$ & G$(2) & "_"
5656 LET Z1$ = "ldr"
5658 LET Z2$ = "x9"
5660 LET Z3 = A5 + 8 * (Q(1) - 1)
5662 LET Z4$ = "sp"
5664 GOSUB 9020
5666 LET Z1$ = "cbz"
5668 IF Y0 = 12 THEN 5672
5670 LET Z1$ = "cbnz"
5672 LET Z2$ = "x9, "
5674 LET Z3$ = Y6$ & "else"
5676 GOSUB 9100
5678 GOTO 5290
5700 REM ---- else b -------------------------------------------------------------------------------
5702 IF W0 = 2 THEN 5290
5704 LET Y6$ = L9$ & G$(2) & "_"
5706 LET X$ = "b " & Y6$ & "end"
5708 GOSUB 9010
5710 LET X$ = Y6$ & "else:"
5712 GOSUB 9000
5714 GOTO 5290
5750 REM ---- endif b (the else label too when there was no else) --------------------------------
5752 IF W0 = 2 THEN 5290
5754 LET Y7 = VAL(G$(2))
5756 LET Y6$ = L9$ & G$(2) & "_"
5758 IF B(Y7,2) = 1 THEN 5766
5760 LET X$ = Y6$ & "else:"
5762 GOSUB 9000
5766 LET X$ = Y6$ & "end:"
5768 GOSUB 9000
5770 GOTO 5290
5800 REM ---- exit b ------------------------------------------------------------------------------
5802 IF W0 = 2 THEN 5290
5804 LET X$ = "b " & L9$ & G$(2) & "_exit"
5806 GOSUB 9010
5808 GOTO 5290
5850 REM ---- next b: a loop's step, a do's top -------------------------------------------------
5852 IF W0 = 2 THEN 5290
5854 LET Y7 = VAL(G$(2))
5856 LET X$ = "b " & L9$ & G$(2) & "_top"
5858 IF B(Y7,1) <> 1 THEN 5862
5860 LET X$ = "b " & L9$ & G$(2) & "_next"
5862 GOSUB 9010
5864 GOTO 5290
5900 REM ---- ret: results into x0-x7, d0-d7 and the results area, to the epilogue --------------
5902 IF W0 = 2 THEN 5290
5904 IF F8 = 0 THEN 5914
5906 LET Z1$ = "ldr"
5908 LET Z2$ = "x17"
5910 LET Z3 = F9
5912 LET Z4$ = "sp"
5913 GOSUB 9020
5914 LET G1 = 0
5916 LET G2 = 0
5918 LET G4 = 0
5920 FOR K2 = 1 TO P0
5922 LET Z1$ = "ldr"
5924 LET Z4$ = "sp"
5926 LET Z3 = A5 + 8 * (Q(K2) - 1)
5928 IF P(K2) = 2 THEN 5938
5930 IF G1 >= 8 THEN 5946
5932 LET Z2$ = "x" & STR$(G1)
5934 LET G1 = G1 + 1
5936 GOTO 5944
5938 IF G2 >= 8 THEN 5946
5940 LET Z2$ = "d" & STR$(G2)
5942 LET G2 = G2 + 1
5944 GOSUB 9020
5945 GOTO 5956
5946 LET Z2$ = "x9"
5948 GOSUB 9020
5950 LET Z1$ = "str"
5951 LET Z3 = 8 * G4
5952 LET Z4$ = "x17"
5953 GOSUB 9020
5954 LET G4 = G4 + 1
5956 NEXT K2
5957 LET X$ = "b " & L9$ & "ret"
5958 GOSUB 9010
5959 GOTO 5290
5960 REM ---- store Z2$ into the destination's slot ----------------------------------------------
5962 LET Z1$ = "str"
5964 LET Z4$ = "sp"
5966 LET Z3 = A5 + 8 * (D1 - 1)
5968 GOSUB 9020
5970 RETURN
6000 REM ---- call: arguments, bl, results (DESIGN 4.8 calling convention) ----------------------
6002 IF W0 = 2 THEN 5290
6004 LET Y7 = G(J)
6006 LET Z6$ = S$(Y7,3)
6008 GOSUB 9630
6010 LET G1 = 0
6012 LET G2 = 0
6014 LET G3 = 0
6016 IF Z8 = 0 THEN 6040
6018 IF A1 > 4095 THEN 6026
6020 LET X$ = "add x0, sp, #" & STR$(A1)
6022 GOSUB 9010
6024 GOTO 6038
6026 LET Z5 = A1
6028 LET Z5$ = "x0"
6030 GOSUB 9050
6032 LET X$ = "add x0, sp, x0"
6034 GOSUB 9010
6038 LET G1 = 1
6040 GOSUB 6100
6042 LET X$ = "bl Lfn_" & S$(Y7,1)
6044 GOSUB 9010
6046 LET Y8 = VAL(G$(3))
6048 LET Y4 = 4
6050 GOSUB 6300
6052 GOTO 5290
6100 REM ---- the arguments Q() P() into x<G1>.. d<G2>.. and the stack slots from G3 -------------
6102 FOR K2 = 1 TO P0
6104 LET Z1$ = "ldr"
6106 LET Z4$ = "sp"
6108 LET Z3 = A5 + 8 * (Q(K2) - 1)
6110 IF P(K2) = 2 THEN 6120
6112 IF G1 >= 8 THEN 6130
6114 LET Z2$ = "x" & STR$(G1)
6116 LET G1 = G1 + 1
6118 GOTO 6126
6120 IF G2 >= 8 THEN 6130
6122 LET Z2$ = "d" & STR$(G2)
6124 LET G2 = G2 + 1
6126 GOSUB 9020
6128 GOTO 6140
6130 LET Z2$ = "x9"
6132 GOSUB 9020
6134 LET Z1$ = "str"
6136 LET Z3 = 8 * G3
6137 GOSUB 9020
6138 LET G3 = G3 + 1
6140 NEXT K2
6142 RETURN
6200 REM ---- rcall: arguments, the site index (entries with site S), bl _<symbol>, results ----
6202 IF W0 = 2 THEN 5290
6204 LET Y7 = G(J)
6206 LET G1 = 0
6208 LET G2 = 0
6210 LET G3 = 0
6212 GOSUB 6100
6214 IF X3 = 0 THEN 6240
6216 LET Z5 = X0
6218 IF G1 >= 8 THEN 6226
6220 LET Z5$ = "x" & STR$(G1)
6222 GOSUB 9050
6224 GOTO 6240
6226 LET Z5$ = "x9"
6228 GOSUB 9050
6230 LET Z1$ = "str"
6232 LET Z2$ = "x9"
6234 LET Z3 = 8 * G3
6236 LET Z4$ = "sp"
6238 GOSUB 9020
6240 LET X$ = "bl _" & Y$(Y7,2)
6242 GOSUB 9010
6244 LET Y8 = VAL(G$(4))
6246 LET Y4 = 5
6248 GOSUB 6300
6250 GOTO 5290
6300 REM ---- Y8 results, registers G$(Y4 ...), from x0-x7, d0-d7, the results area at A1 ------
6302 LET G1 = 0
6304 LET G2 = 0
6306 LET G4 = 0
6308 FOR K3 = 1 TO Y8
6310 LET Y5$ = G$(Y4 + K3 - 1)
6312 LET V3 = A5 + 8 * (VAL(SEG$(Y5$, 2, LEN(Y5$))) - 1)
6314 LET Z1$ = "str"
6316 LET Z4$ = "sp"
6318 LET Z3 = V3
6320 IF SEG$(Y5$, 1, 1) = "f" THEN 6330
6322 IF G1 >= 8 THEN 6340
6324 LET Z2$ = "x" & STR$(G1)
6326 LET G1 = G1 + 1
6328 GOTO 6336
6330 IF G2 >= 8 THEN 6340
6332 LET Z2$ = "d" & STR$(G2)
6334 LET G2 = G2 + 1
6336 GOSUB 9020
6338 GOTO 6350
6340 LET Z1$ = "ldr"
6342 LET Z2$ = "x9"
6343 LET Z3 = A1 + 8 * G4
6344 GOSUB 9020
6345 LET Z1$ = "str"
6346 LET Z3 = V3
6347 GOSUB 9020
6348 LET G4 = G4 + 1
6350 NEXT K3
6352 RETURN
6400 REM ---- chk c err site n a...: to the cold block when c <> 0 ---------------------------------
6402 LET Y6$ = L9$ & "e" & STR$(J)
6404 IF W0 = 2 THEN 6430
6406 LET Z1$ = "ldr"
6408 LET Z2$ = "x9"
6410 LET Z3 = A5 + 8 * (Q(1) - 1)
6412 LET Z4$ = "sp"
6414 GOSUB 9020
6416 LET Z1$ = "cbnz"
6418 LET Z2$ = "x9, "
6420 LET Z3$ = Y6$
6422 GOSUB 9100
6424 IF W0 = 1 THEN 5290
6430 LET X$ = Y6$ & ":"
6432 GOSUB 9000
6434 FOR K2 = 2 TO P0
6436 LET Z1$ = "ldr"
6438 LET Z2$ = "x9"
6440 LET Z3 = A5 + 8 * (Q(K2) - 1)
6442 LET Z4$ = "sp"
6444 GOSUB 9020
6446 LET Z1$ = "str"
6448 LET Z3 = (K2 - 2) * K(1)
6450 GOSUB 9020
6452 NEXT K2
6454 LET Z8 = E(G(J))
6456 GOSUB 9375
6458 GOTO 5290
6500 REM ---- retain a / release a / mcopy d s n (DESIGN 4.9 phase-4 code): the operands into x9
6502 REM (x10 x11; mcopy's d first, it is read, not written), then the record's template; $M of
6504 REM release is _<symbol of FREE>
6506 IF W0 = 2 THEN 5290
6508 LET Z1$ = "ldr"
6510 LET Z4$ = "sp"
6512 LET G1 = 0
6514 IF D1 = 0 THEN 6524
6516 LET Z2$ = "x9"
6518 LET Z3 = A5 + 8 * (D1 - 1)
6520 GOSUB 9020
6522 LET G1 = 1
6524 FOR K2 = 1 TO P0
6526 LET Z2$ = "x" & STR$(8 + G1 + K2)
6528 LET Z3 = A5 + 8 * (Q(K2) - 1)
6530 GOSUB 9020
6532 NEXT K2
6534 LET M$ = "_" & Y$(Y3,2)
6536 LET T5 = A(I0,2)
6538 FOR I6 = M(T5,1) TO M(T5,1) + M(T5,2) - 1
6540 LET Z$ = Q$(I6)
6542 GOSUB 9150
6544 NEXT I6
6546 GOTO 5290
7000 REM ---- data: str lab v -- a static string object (rt.inc SEA_STR_*) ---------------------
7005 GOSUB 7900
7010 GOSUB 9400
7015 IF H0 <> D8 + 1 THEN 9990
7020 LET D8 = H0
7025 CALL "io_unesc": G$(3), 0, R9$, T
7030 IF T <> 0 THEN 9990
7035 LET Z9$ = "Ld" & STR$(H0)
7040 GOSUB 7500
7045 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7050 GOTO 1250
7100 REM ---- data: fmt lab k, then k ftext / fconv -- a pre-parsed format (SEA_FMT_*, SEA_FP_*) -
7105 GOSUB 7900
7110 GOSUB 9400
7115 IF H0 <> D8 + 1 THEN 9990
7120 LET D8 = H0
7125 LET V4 = H0
7130 LET Y7 = U(2)
7135 IF Y7 > 219999 THEN 9990
7140 LET Y8 = 0
7145 FOR I3 = 1 TO Y7
7150 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7155 LET B$(I3) = L$
7160 IF SEG$(L$, 1, 6) <> "fconv " THEN 7170
7165 LET Y8 = Y8 + 1
7170 NEXT I3
7175 LET X$ = ".p2align 3"
7180 GOSUB 9010
7185 LET X$ = "Ld" & STR$(V4) & ":"
7190 GOSUB 9000
7195 LET Z7 = 0
7200 LET Z6 = K(9)
7202 GOSUB 7600
7204 LET X$ = ".quad " & STR$(Y7)
7206 GOSUB 9010
7208 LET Z7 = Z7 + 8
7210 LET Z6 = K(10)
7212 GOSUB 7600
7214 LET X$ = ".quad " & STR$(Y8)
7216 GOSUB 9010
7218 LET Z7 = Z7 + 8
7220 LET Z6 = K(11)
7222 GOSUB 7600
7224 FOR I3 = 1 TO Y7
7226 GOSUB 7700
7228 NEXT I3
7230 REM the bytes of the text pieces
7232 FOR I3 = 1 TO Y7
7234 CALL "io_split": B$(I3), G$(), 300, C0
7236 IF G$(1) <> "ftext" THEN 7250
7238 CALL "io_unesc": G$(2), 0, R9$, T
7240 LET X$ = "Ld" & STR$(V4) & "_t" & STR$(I3) & ":"
7242 GOSUB 9000
7244 GOSUB 7650
7250 NEXT I3
7255 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7260 GOTO 1250
7300 REM ---- data: dat lab elt n, then n dvi / dvf -- a constant buffer, SEA_DATA_ALIGN ---------
7305 GOSUB 7900
7310 GOSUB 9400
7315 IF H0 <> D8 + 1 THEN 9990
7320 LET D8 = H0
7325 LET Y7 = U(3)
7330 LET Y5$ = G$(3)
7335 LET Y6$ = "dvi"
7340 LET Y8 = K(35)
7345 IF Y5$ <> "f64" THEN 7360
7350 LET Y6$ = "dvf"
7355 LET Y8 = K(36)
7360 IF Y5$ <> "bool" THEN 7370
7365 LET Y8 = K(37)
7370 LET M$ = "an element size other than 1 or 8 bytes"
7372 IF Y8 = 1 THEN 7378
7374 IF Y8 <> 8 THEN 9975
7376 IF Y5$ = "bool" THEN 9975
7378 IF Y5$ <> "bool" THEN 7382
7380 IF Y8 <> 1 THEN 9975
7382 LET M$ = "SEA_DATA_ALIGN is not a power of two"
7384 LET Y1 = 0
7386 LET Y2 = 1
7388 IF Y2 >= K(34) THEN 7396
7390 LET Y2 = Y2 * 2
7392 LET Y1 = Y1 + 1
7394 GOTO 7388
7396 IF Y2 <> K(34) THEN 9975
7398 LET X$ = ".p2align " & STR$(Y1)
7400 GOSUB 9010
7402 LET X$ = "Ld" & STR$(H0) & ":"
7404 GOSUB 9000
7406 FOR I3 = 1 TO Y7
7408 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7410 CALL "io_split": L$, G$(), 300, C0
7412 IF C0 < 1 THEN 9990
7414 IF G$(1) <> Y6$ THEN 9990
7416 LET Z$ = G$(1)
7418 GOSUB 9350
7420 GOSUB 9400
7422 IF Y8 = 8 THEN 7434
7424 IF L(1) + L(2) + L(3) <> 0 THEN 9990
7426 IF L(4) > 1 THEN 9990
7428 LET X$ = ".byte " & STR$(L(4))
7430 GOSUB 9010
7432 GOTO 7440
7434 CALL "io_hex": L(), R$
7436 LET X$ = ".quad 0x" & SEG$(R$, 2, 17)
7438 GOSUB 9010
7440 NEXT I3
7445 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7450 GOTO 1250
7455 REM ---- data: slay lab size n, then n soff -- a struct layout descriptor (SEA_SL_*, DESIGN
7456 REM 4.9); the offsets strictly ascending multiples of 8, each at most size - 8 (DESIGN 3.6.5)
7457 GOSUB 7900
7458 GOSUB 9400
7459 IF H0 <> D8 + 1 THEN 9990
7460 LET D8 = H0
7461 LET Y8 = U(2)
7462 LET Y7 = U(3)
7463 LET X$ = ".p2align 3"
7464 GOSUB 9010
7465 LET X$ = "Ld" & STR$(H0) & ":"
7466 GOSUB 9000
7467 LET Z7 = 0
7468 LET Z6 = K(47)
7469 GOSUB 7600
7470 LET X$ = ".quad " & STR$(Y8)
7471 GOSUB 9010
7472 LET Z7 = Z7 + 8
7473 LET Z6 = K(48)
7474 GOSUB 7600
7475 LET X$ = ".quad " & STR$(Y7)
7476 GOSUB 9010
7477 LET Z7 = Z7 + 8
7478 LET Z6 = K(49)
7479 GOSUB 7600
7480 LET V4 = -8
7481 FOR I3 = 1 TO Y7
7482 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7483 CALL "io_split": L$, G$(), 300, C0
7484 IF C0 < 1 THEN 9990
7485 LET Z$ = G$(1)
7486 GOSUB 9350
7487 IF Y0 <> 38 THEN 9990
7488 GOSUB 9400
7489 IF U(1) <= V4 THEN 9990
7490 IF U(1) <> INT(U(1) / 8) * 8 THEN 9990
7491 IF U(1) > Y8 - 8 THEN 9990
7492 LET V4 = U(1)
7493 LET X$ = ".quad " & STR$(V4)
7494 GOSUB 9010
7495 NEXT I3
7496 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7497 GOTO 1250
7500 REM ---- a static string object Z9$ with the bytes R9$ (rt.inc SEA_STR_*, 8-byte aligned) ---
7505 LET X$ = ".p2align 3"
7510 GOSUB 9010
7515 LET X$ = Z9$ & ":"
7520 GOSUB 9000
7525 LET Z7 = 0
7530 LET Z6 = K(5)
7532 GOSUB 7600
7534 LET X$ = ".quad " & STR$(K(3))
7536 GOSUB 9010
7538 LET Z7 = Z7 + 8
7540 LET Z6 = K(6)
7542 GOSUB 7600
7544 LET X$ = ".byte " & STR$(K(4))
7546 GOSUB 9010
7548 LET Z7 = Z7 + 1
7550 LET Z6 = K(7)
7552 GOSUB 7600
7554 LET X$ = ".quad " & STR$(LEN(R9$))
7556 GOSUB 9010
7558 LET Z7 = Z7 + 8
7560 LET Z6 = K(8)
7562 GOSUB 7600
7564 GOSUB 7650
7566 RETURN
7600 REM ---- a field at offset Z6 of a record whose next free byte is Z7: .space the gap ------
7602 LET M$ = "a rt.inc layout whose fields are not in ascending order"
7604 IF Z6 < Z7 THEN 9975
7606 IF Z6 = Z7 THEN 7614
7608 LET X$ = ".space " & STR$(Z6 - Z7)
7610 GOSUB 9010
7612 LET Z7 = Z6
7614 RETURN
7650 REM ---- the bytes of R9$ as .byte lines of 16 ---------------------------------------------
7652 IF LEN(R9$) = 0 THEN 7690
7654 CHANGE R9$ TO W
7656 LET X$ = ""
7658 FOR I2 = 1 TO W(0)
7660 IF LEN(X$) > 0 THEN 7666
7662 LET X$ = ".byte " & STR$(W(I2))
7664 GOTO 7668
7666 LET X$ = X$ & ", " & STR$(W(I2))
7668 IF I2 - INT(I2 / 16) * 16 <> 0 THEN 7676
7670 GOSUB 9010
7672 LET X$ = ""
7676 NEXT I2
7678 IF LEN(X$) = 0 THEN 7690
7680 GOSUB 9010
7690 RETURN
7700 REM ---- piece I3 of the format: B$(I3) is its ftext or fconv record ------------------------
7702 CALL "io_split": B$(I3), G$(), 300, C0
7704 IF C0 < 1 THEN 9990
7706 LET Z$ = G$(1)
7708 GOSUB 9350
7710 IF Y0 = 32 THEN 7716
7712 IF Y0 <> 33 THEN 9990
7716 GOSUB 9400
7718 LET Z7 = 0
7720 IF Y0 = 33 THEN 7800
7722 CALL "io_unesc": G$(2), 0, R9$, T
7724 IF T <> 0 THEN 9990
7726 LET Z6 = K(12)
7728 GOSUB 7600
7730 LET X$ = ".byte " & STR$(K(21))
7732 GOSUB 9010
7734 LET Z7 = Z7 + 1
7736 LET Z6 = K(13)
7738 GOSUB 7600
7740 LET X$ = ".byte 0"
7742 GOSUB 9010
7744 LET Z7 = Z7 + 1
7746 LET Z6 = K(14)
7748 GOSUB 7600
7749 LET X$ = ".byte 0"
7750 GOSUB 9010
7752 LET Z7 = Z7 + 1
7754 LET Z6 = K(15)
7756 GOSUB 7600
7757 LET X$ = ".byte 0"
7758 GOSUB 9010
7760 LET Z7 = Z7 + 1
7762 LET V5 = -1
7764 LET V6 = -1
7766 GOSUB 7860
7768 LET Z6 = K(18)
7770 GOSUB 7600
7772 LET X$ = ".quad Ld" & STR$(V4) & "_t" & STR$(I3)
7774 GOSUB 9010
7776 LET Z7 = Z7 + 8
7778 LET Z6 = K(19)
7780 GOSUB 7600
7782 LET X$ = ".quad " & STR$(LEN(R9$))
7784 GOSUB 9010
7786 LET Z7 = Z7 + 8
7788 LET Z6 = K(20)
7790 GOSUB 7600
7792 RETURN
7800 REM a conversion: letter, flags (fl letters l p s z a -> SEA_FF_*), class, width, precision
7801 GOSUB 7960
7802 LET Y1 = 0
7804 IF G$(2) = "-" THEN 7816
7806 FOR I2 = 1 TO LEN(G$(2))
7808 LET Y1 = Y1 + K(22 + POS("lpsza", SEG$(G$(2), I2, I2)))
7810 NEXT I2
7816 LET Y2 = K(28)
7818 IF G$(6) <> "f" THEN 7822
7820 LET Y2 = K(29)
7822 IF G$(6) <> "p" THEN 7826
7824 LET Y2 = K(30)
7826 LET V5 = -1
7828 IF G$(3) = "-" THEN 7832
7830 LET V5 = VAL(G$(3))
7832 LET V6 = -1
7834 IF G$(4) = "-" THEN 7838
7836 LET V6 = VAL(G$(4))
7838 LET Z6 = K(12)
7840 GOSUB 7600
7842 LET X$ = ".byte " & STR$(K(22))
7844 GOSUB 9010
7846 LET Z7 = Z7 + 1
7848 LET Z6 = K(13)
7850 GOSUB 7600
7852 LET X$ = ".byte " & STR$(ASC(G$(5)))
7854 GOSUB 9010
7856 LET Z7 = Z7 + 1
7857 GOTO 7880
7860 REM width V5 and precision V6 (i32 each)
7862 LET Z6 = K(16)
7864 GOSUB 7600
7866 LET X$ = ".long " & STR$(V5)
7868 GOSUB 9010
7870 LET Z7 = Z7 + 4
7872 LET Z6 = K(17)
7874 GOSUB 7600
7875 LET X$ = ".long " & STR$(V6)
7876 GOSUB 9010
7877 LET Z7 = Z7 + 4
7878 RETURN
7880 LET Z6 = K(14)
7881 GOSUB 7600
7882 LET X$ = ".byte " & STR$(Y1)
7883 GOSUB 9010
7884 LET Z7 = Z7 + 1
7885 LET Z6 = K(15)
7886 GOSUB 7600
7887 LET X$ = ".byte " & STR$(Y2)
7888 GOSUB 9010
7889 LET Z7 = Z7 + 1
7890 GOSUB 7860
7891 LET Z6 = K(18)
7892 GOSUB 7600
7893 LET X$ = ".quad 0"
7894 GOSUB 9010
7895 LET Z7 = Z7 + 8
7896 LET Z6 = K(19)
7897 GOSUB 7600
7898 LET X$ = ".quad 0"
7899 GOTO 7784
7900 REM ---- the data section starts at the first data record --------------------------------
7902 LET W0 = 1
7904 IF D9 = 1 THEN 7914
7906 LET D9 = 1
7908 LET X$ = ".section __DATA,__const"
7910 GOSUB 9010
7914 RETURN
7960 REM ---- fconv: class p exactly for %s, i or f for the numeric conversions (DESIGN 3.6.5) --
7962 IF G$(5) <> "s" THEN 7968
7964 IF G$(6) <> "p" THEN 9990
7966 RETURN
7968 IF G$(6) = "p" THEN 9990
7970 RETURN
8000 REM ---- #end: the #file strings and _sea_sites (rt.inc SEA_SITE_*) ------------------------
8005 CALL "io_end": 1, P$, E(), E$(), E0
8010 IF M9 <> 1 THEN 9990
8012 IF L8 > D8 THEN 9990
8015 GOSUB 7900
8020 FOR I4 = 1 TO N1
8025 LET Z9$ = "Lsf" & STR$(I4 - 1)
8030 LET R9$ = H$(I4)
8035 GOSUB 7500
8040 NEXT I4
8045 LET X$ = ".globl _sea_sites"
8050 GOSUB 9010
8055 LET X$ = ".p2align 3"
8060 GOSUB 9010
8065 LET X$ = "_sea_sites:"
8070 GOSUB 9000
8075 FOR I4 = 1 TO X9
8080 LET Z7 = 0
8085 LET Z6 = K(31)
8090 GOSUB 7600
8095 LET X$ = ".quad Lsf" & STR$(S(I4,1))
8100 GOSUB 9010
8105 LET Z7 = Z7 + 8
8110 LET Z6 = K(32)
8115 GOSUB 7600
8120 LET X$ = ".quad " & STR$(S(I4,2))
8125 GOSUB 9010
8130 LET Z7 = Z7 + 8
8135 LET Z6 = K(33)
8140 GOSUB 7600
8145 NEXT I4
8150 GOTO 99999
9000 REM ---- emit X$ (mode 0: count it); 9010: indented ---------------------------------------
9002 IF W0 = 0 THEN 9006
9004 PRINT #2, X$
9005 RETURN
9006 LET W2 = W2 + 1
9007 IF POS(X$, ".quad") = 0 THEN 9009
9008 LET W2 = W2 + 1
9009 RETURN
9010 LET X$ = "    " & X$
9012 GOTO 9002
9020 REM ---- Z1$ Z2$, [Z4$, #Z3]: a load or store of an 8-byte frame slot -------------------------
9022 IF Z3 > 32760 THEN 9036
9024 IF Z3 <> INT(Z3 / 8) * 8 THEN 9036
9026 IF Z3 = 0 THEN 9032
9028 LET X$ = Z1$ & " " & Z2$ & ", [" & Z4$ & ", #" & STR$(Z3) & "]"
9030 GOTO 9010
9032 LET X$ = Z1$ & " " & Z2$ & ", [" & Z4$ & "]"
9034 GOTO 9010
9036 LET Z5 = Z3
9038 LET Z5$ = "x16"
9040 GOSUB 9050
9042 LET X$ = "add x16, " & Z4$ & ", x16"
9044 GOSUB 9010
9046 LET X$ = Z1$ & " " & Z2$ & ", [x16]"
9048 GOTO 9010
9050 REM ---- Z5$ = Z5 (an integer 0 <= Z5 < 2^53); 9060: Z5$ = the limbs V(1..4) ---------------
9052 LET V5 = Z5
9053 FOR I1 = 4 TO 1 STEP -1
9054 LET V(I1) = V5 - INT(V5 / 65536) * 65536
9055 LET V5 = INT(V5 / 65536)
9056 NEXT I1
9060 LET V6 = 0
9061 LET V7 = 0
9062 FOR I1 = 1 TO 4
9063 IF V(I1) <> 0 THEN 9065
9064 LET V6 = V6 + 1
9065 IF V(I1) <> 65535 THEN 9067
9066 LET V7 = V7 + 1
9067 NEXT I1
9068 IF V7 > V6 THEN 9084
9070 LET X$ = "movz " & Z5$ & ", #" & STR$(V(4))
9071 GOSUB 9010
9072 FOR I1 = 3 TO 1 STEP -1
9073 IF V(I1) = 0 THEN 9076
9074 LET X$ = "movk " & Z5$ & ", #" & STR$(V(I1)) & ", lsl #" & STR$(16 * (4 - I1))
9075 GOSUB 9010
9076 NEXT I1
9077 RETURN
9084 LET X$ = "movn " & Z5$ & ", #" & STR$(65535 - V(4))
9085 GOSUB 9010
9086 FOR I1 = 3 TO 1 STEP -1
9087 IF V(I1) = 65535 THEN 9090
9088 LET X$ = "movk " & Z5$ & ", #" & STR$(V(I1)) & ", lsl #" & STR$(16 * (4 - I1))
9089 GOSUB 9010
9090 NEXT I1
9091 RETURN
9100 REM ---- conditional branch Z1$ Z2$Z3$ (Z2$ = "x9, " for cbz / cbnz); far: inverted over b --
9102 IF W1 = 1 THEN 9110
9104 LET X$ = Z1$ & " " & Z2$ & Z3$
9106 GOTO 9010
9110 FOR I1 = 1 TO U8
9112 IF U$(I1,1) = Z1$ THEN 9120
9114 NEXT I1
9116 LET M$ = "no inversion for the branch " & Z1$
9118 GOTO 9975
9120 LET X$ = U$(I1,2) & " " & Z2$ & "9f"
9122 GOSUB 9010
9124 LET X$ = "b " & Z3$
9126 GOSUB 9010
9128 LET X$ = "9:"
9130 GOTO 9000
9150 REM ---- one template line Z$: placeholders replaced; a branch to $C / $D through 9100 -------
9152 LET R$ = ""
9154 LET Y1 = 1
9156 LET Y2 = POS(Z$, "$", Y1)
9158 IF Y2 = 0 THEN 9170
9160 LET R$ = R$ & SEG$(Z$, Y1, Y2 - 1)
9162 LET Y3$ = SEG$(Z$, Y2 + 1, Y2 + 1)
9164 LET Y1 = Y2 + 2
9166 GOSUB 9200
9168 GOTO 9156
9170 LET R$ = R$ & SEG$(Z$, Y1, LEN(Z$))
9172 LET Y3$ = SEG$(Z$, LEN(Z$) - 1, LEN(Z$))
9174 IF Y3$ = "$C" THEN 9184
9176 IF Y3$ = "$D" THEN 9184
9178 LET X$ = R$
9180 IF SEG$(R$, LEN(R$), LEN(R$)) = ":" THEN 9000
9182 GOTO 9010
9184 LET Y2 = POS(R$, " ")
9186 LET Z1$ = SEG$(R$, 1, Y2 - 1)
9188 LET Z3$ = L9$ & "e" & STR$(J)
9190 IF Y3$ = "$C" THEN 9194
9192 LET Z3$ = L9$ & "f" & STR$(J)
9194 LET Z2$ = SEG$(R$, Y2 + 1, LEN(R$) - LEN(Z3$))
9196 GOTO 9100
9200 REM ---- the value of placeholder Y3$, appended to R$ ------------------------------------
9202 IF Y3$ <> "C" THEN 9206
9204 LET R$ = R$ & L9$ & "e" & STR$(J)
9205 RETURN
9206 IF Y3$ <> "D" THEN 9210
9208 LET R$ = R$ & L9$ & "f" & STR$(J)
9209 RETURN
9210 IF Y3$ <> "M" THEN 9214
9212 LET R$ = R$ & M$
9213 RETURN
9214 IF Y3$ <> "L" THEN 9218
9216 LET R$ = R$ & "Ld" & STR$(H0)
9217 RETURN
9218 IF Y3$ <> "U" THEN 9222
9220 LET R$ = R$ & STR$(U0)
9221 RETURN
9222 IF Y3$ <> "S" THEN 9226
9224 LET R$ = R$ & STR$(X0)
9225 RETURN
9226 LET Y5 = 2
9228 IF Y3$ = "K" THEN 9236
9230 LET Y5 = 3
9232 IF Y3$ = "F" THEN 9236
9234 GOTO 9244
9236 FOR I2 = 1 TO V8
9238 IF V$(I2,1) = K1$ THEN 9242
9240 NEXT I2
9241 GOTO 9990
9242 LET R$ = R$ & V$(I2,Y5)
9243 RETURN
9244 LET Y5 = POS("0123456789", Y3$)
9245 LET M$ = "unknown template placeholder $" & Y3$
9246 IF Y5 = 0 THEN 9975
9247 LET R$ = R$ & STR$((Y5 - 1) * K(1))
9248 RETURN
9250 REM ---- the memory operand M$ of base Q(B1) + idx Q(B2) * scale U2 + off L() --------------
9252 IF B2 > 0 THEN 9262
9254 IF O1 = 1 THEN 9258
9256 LET M$ = "[" & J$(B1) & "]"
9257 RETURN
9258 LET X$ = "mov x16, " & J$(B1)
9260 GOTO 9274
9262 IF U2 <> 1 THEN 9268
9264 LET X$ = "add x16, " & J$(B1) & ", " & J$(B2)
9266 GOTO 9274
9268 LET Z5 = U2
9270 LET Z5$ = "x17"
9271 GOSUB 9050
9272 LET X$ = "madd x16, " & J$(B2) & ", x17, " & J$(B1)
9274 GOSUB 9010
9276 LET M$ = "[x16]"
9278 IF O1 = 0 THEN 9290
9280 FOR I1 = 1 TO 4
9282 LET V(I1) = L(I1)
9284 NEXT I1
9285 LET Z5$ = "x17"
9286 GOSUB 9060
9287 LET X$ = "add x16, x16, x17"
9288 GOSUB 9010
9290 RETURN
9300 REM ---- X0 = the index of site X1:X2 in _sea_sites; added in mode 1 (first occurrence) ----
9302 LET S5 = X1 * 1E9 + X2
9304 LET S6 = S5 - INT(S5 / 131071) * 131071
9306 IF H(S6) = 0 THEN 9324
9308 LET S7 = H(S6)
9310 IF S(S7,1) <> X1 THEN 9318
9312 IF S(S7,2) <> X2 THEN 9318
9314 LET X0 = S7 - 1
9316 RETURN
9318 LET S6 = S6 + 1
9320 IF S6 < 131071 THEN 9306
9322 LET S6 = 0
9323 GOTO 9306
9324 IF W0 = 1 THEN 9334
9326 LET M$ = "a site missing from the site table"
9328 IF W0 = 2 THEN 9975
9330 LET X0 = 0
9332 RETURN
9334 LET X9 = X9 + 1
9336 IF X9 <= K(45) THEN 9342
9338 LET A$(1) = "sites"
9340 GOTO 9960
9342 LET S(X9,1) = X1
9344 LET S(X9,2) = X2
9346 LET H(S6) = X9
9348 LET X0 = X9 - 1
9349 RETURN
9350 REM ---- I0 = the LIR record row of opcode Z$ (0: none), Y0 its special code ----------------
9352 LET I0 = 0
9354 LET Y0 = 0
9356 IF POS(Z$, "|") > 0 THEN 9370
9358 IF POS(Z$, "=") > 0 THEN 9370
9360 LET Y1 = POS(O$, "|" & Z$ & "=")
9362 IF Y1 = 0 THEN 9370
9364 LET Y2 = POS(O$, "|", Y1 + 1)
9366 LET I0 = VAL(SEG$(O$, Y1 + LEN(Z$) + 2, Y2 - 1))
9368 LET Y0 = A(I0,1)
9370 RETURN
9375 REM ---- cold tail: _sea_err(Z8, site X0, slots at sp) ------------------------------------
9377 LET Z5 = Z8
9379 LET Z5$ = "x0"
9381 GOSUB 9050
9383 LET Z5 = X0
9385 LET Z5$ = "x1"
9387 GOSUB 9050
9389 LET X$ = "mov x2, sp"
9391 GOSUB 9010
9393 LET X$ = "bl _sea_err"
9395 GOTO 9010
9400 REM ---- the fields of G$(1..C0) against record row I0 (DESIGN 3.1, passes.txt): checks, ----
9401 REM registers (D1 D2 the destination d, E1 a second destination e, Q P J$ the sources, B1 B2
9402 REM base / idx), site X0, cc K1$, first u U0, scale U2, off limbs L() (O1 = 1 if not 0),
9403 REM label H0, slot H1, site fields X5
9404 LET T0 = 1
9406 LET P0 = 0
9408 LET D1 = 0
9409 LET E1 = 0
9410 LET D2 = 0
9412 LET B1 = 0
9414 LET B2 = 0
9416 LET X3 = 0
9418 LET X0 = 0
9419 LET X5 = 0
9420 LET U0 = -1
9422 LET U2 = 0
9424 LET O1 = 0
9426 LET H0 = 0
9428 LET H1 = 0
9430 LET K1$ = ""
9432 FOR J1 = 1 TO R(I0,4)
9434 LET J2 = R(I0,3) + J1 - 1
9436 LET U(J1) = 0
9438 LET X4 = 1
9440 IF F(J2,3) = 0 THEN 9444
9442 LET X4 = U(F(J2,3))
9444 FOR J3 = 1 TO X4
9446 LET T0 = T0 + 1
9448 IF T0 > C0 THEN 9990
9450 LET Z$ = G$(T0)
9452 LET T1 = F(J2,1)
9453 GOSUB 9680
9454 IF Z$ <> "-" THEN 9458
9456 IF F(J2,2) = 1 THEN 9540
9458 IF T1 >= 100 THEN 9524
9460 ON T1 GOTO 9462,9474,9484,9540,9488,9494,9504,9990,9990,9990,9990,9990,9508,9512,9518,9530,9530,9530,9530,9990,9990,9990
9462 CALL "io_u": Z$, V0, T
9464 IF T <> 0 THEN 9990
9466 LET U(J1) = V0
9468 IF F$(J2) <> "scale" THEN 9471
9470 LET U2 = V0
9471 IF U0 >= 0 THEN 9540
9472 LET U0 = V0
9473 GOTO 9540
9474 CALL "io_i": Z$, V0, K9, L(), T
9476 IF T <> 0 THEN 9990
9478 IF F$(J2) <> "off" THEN 9540
9480 IF L(1) + L(2) + L(3) + L(4) = 0 THEN 9540
9482 LET O1 = 1
9483 GOTO 9540
9484 CALL "io_f": Z$, L(), T
9486 IF T <> 0 THEN 9990
9487 GOTO 9540
9488 CALL "io_pos": Z$, V0, V1, V2, T
9490 IF T <> 0 THEN 9990
9492 IF V0 >= N1 THEN 9990
9493 GOTO 9540
9494 CALL "io_site": Z$, X1, X2, T
9496 IF T <> 0 THEN 9990
9498 IF X1 >= N1 THEN 9990
9500 LET X3 = 1
9502 GOSUB 9300
9503 GOTO 9540
9504 GOSUB 9600
9506 GOTO 9540
9508 CALL "io_u": Z$, V0, T
9509 IF T <> 0 THEN 9990
9510 IF V0 < 1 THEN 9990
9511 GOTO 9540
9512 IF SEG$(Z$, 1, 1) <> "d" THEN 9990
9514 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), H0, T
9515 IF T <> 0 THEN 9990
9516 IF H0 < 1 THEN 9990
9517 GOTO 9540
9518 IF SEG$(Z$, 1, 1) <> "s" THEN 9990
9520 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), H1, T
9522 IF T <> 0 THEN 9990
9523 GOTO 9540
9524 CALL "tb_word": N(), W$(), T1 - 100, Z$, V0
9526 IF V0 = 0 THEN 9990
9527 IF F$(J2) <> "cc" THEN 9540
9528 LET K1$ = Z$
9529 GOTO 9540
9530 GOSUB 9550
9531 IF F$(J2) = "e" THEN 9546
9532 IF F$(J2) <> "d" THEN 9536
9533 LET D1 = R0
9534 LET D2 = R1
9535 GOTO 9547
9536 LET P0 = P0 + 1
9537 LET Q(P0) = R0
9538 LET P(P0) = R1
9539 GOSUB 9590
9540 NEXT J3
9542 NEXT J1
9544 IF T0 = C0 THEN 9549
9545 GOTO 9990
9546 LET E1 = R0
9547 GOSUB 9660
9548 GOTO 9540
9549 RETURN
9550 REM ---- the register Z$ of field type T1 (16 reg, 17 ri, 18 rf, 19 rp): R0 number, R1 class
9551 REM (1 i, 2 f, 3 p); one class per register (D); a new one is M0 + 1, the highest (DESIGN 3.6.1)
9552 LET R1 = POS("ifp", SEG$(Z$, 1, 1))
9554 IF R1 = 0 THEN 9990
9556 IF T1 = 16 THEN 9560
9558 IF R1 <> T1 - 16 THEN 9990
9560 CALL "io_u": SEG$(Z$, 2, LEN(Z$)), R0, T
9562 IF T <> 0 THEN 9990
9564 IF R0 < 1 THEN 9990
9566 IF R0 <= K(40) THEN 9572
9568 LET A$(1) = "registers"
9570 GOTO 9960
9572 IF D(R0) = 0 THEN 9577
9574 IF D(R0) <> R1 THEN 9990
9576 RETURN
9577 IF R0 <> M0 + 1 THEN 9990
9578 LET D(R0) = R1
9582 LET M0 = R0
9584 RETURN
9590 REM the base and index fields of loads and stores
9592 IF F$(J2) <> "base" THEN 9595
9594 LET B1 = P0
9595 IF F$(J2) <> "idx" THEN 9599
9597 LET B2 = P0
9599 RETURN
9600 REM ---- a fl field: "-" or letters of l p s z a, each once, in this order (DESIGN 3.1) ----
9602 IF Z$ = "-" THEN 9618
9604 LET Y1 = 0
9606 FOR I2 = 1 TO LEN(Z$)
9608 LET Y2 = POS("lpsza", SEG$(Z$, I2, I2))
9610 IF Y2 <= Y1 THEN 9990
9612 LET Y1 = Y2
9614 NEXT I2
9618 RETURN
9630 REM ---- Z8 = the results of classes Z6$ beyond x0-x7 and d0-d7 (the results area) --------
9632 LET Z8 = 0
9634 LET Y1 = 0
9636 LET Y2 = 0
9638 FOR I1 = 1 TO LEN(Z6$)
9640 IF SEG$(Z6$, I1, I1) = "f" THEN 9648
9642 LET Y1 = Y1 + 1
9644 IF Y1 <= 8 THEN 9654
9646 GOTO 9652
9648 LET Y2 = Y2 + 1
9650 IF Y2 <= 8 THEN 9654
9652 LET Z8 = Z8 + 1
9654 NEXT I1
9656 RETURN
9660 REM ---- analysis (W0 = 3): register R0 is written; it is not the ind of an open loop ------
9661 REM (DESIGN 3.6.5: the body never writes ind)
9662 IF W0 <> 3 THEN 9672
9664 FOR I7 = 1 TO K7
9666 IF B(I(I7),1) <> 1 THEN 9670
9668 IF B(I(I7),4) = R0 THEN 9990
9670 NEXT I7
9672 RETURN
9680 REM ---- X5 counts the site fields of the record, present or -: they are no operands (DESIGN 2.7)
9682 IF T1 <> 6 THEN 9686
9684 LET X5 = X5 + 1
9686 RETURN
9960 CALL "dg_compile": P$, H$(), N1, F1, F2, F3, "TOO_LARGE", A$(), 1, E(), E$(), E0
9970 CALL "dg_boot": P$
9975 CALL "dg_bug": P$, M$
9980 CALL "dg_internal": P$, "BAD_HEADER", E(), E$(), E0
9990 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
