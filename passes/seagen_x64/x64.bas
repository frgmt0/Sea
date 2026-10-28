10 REM ====================================================================================
11 REM seagen_x64 -- Sea pass 4 for x86_64-linux: sea.lir -> sea.s (DESIGN 2.1, 3.6, 4.6, 4.8,
12 REM 4.9, 4.9.1, 4.9.2). Built as DESIGN 2.6.3: this file and x64data.bas (lines 1-59999),
13 REM the modules io diag tables ralloc, the DATA blocks errors exits consts entries records,
14 REM 99999 END. seagen_a64 with the target changed (DESIGN 4.9.1): the same reading,
15 REM validation, sites, constants, cold blocks and labels; GNU as AT&T syntax for ELF. Reads
16 REM sea.lir twice: pass A collects every function's parameter and result classes, pass B
17 REM writes sea.s. Each function is buffered and analysed: sweep V (W0 = 3) validates and
18 REM counts writes, reads and immediates and finds the fused comparisons; sweep R (W0 = 4)
19 REM reports every register reference to ralloc, which allocates (ra_end); then the code
20 REM sweep (W0 = 1) and the cold sweep (W0 = 2: sea_err calls, f64 and 16-byte constants).
21 REM Allocation (DESIGN 4.9.2): ralloc's linear scan over the registers of x64data.bas;
22 REM D(r,8) is the location of register r: a machine register (1-16 %rax ... %r15, 17-32
23 REM %xmm0 ... %xmm15, names U$(n,3), 32-bit U$(n,4), 8-bit U$(n,5)) or -s, spill slot s.
24 REM Scratch, never allocated: %rax %rcx %rdx (operands 1-3 of a spilled i / p register,
25 REM 1 also a spilled destination), %xmm14 %xmm15 (the same for f), %r11 (addresses, the
26 REM cycle of a parallel move, with %xmm15). Templates: direct forms (W4 > 0) on the
27 REM allocated registers, staged ones (W4 = 0) on the scratch registers between two
28 REM parallel moves (L-an). An li written once whose every use takes an immediate is not
29 REM emitted; a comparison read only by the next if / ifz / selection sets the flags only.
30 REM Frame, from %rsp up: [0,A1) outgoing stack arguments and the sea_err argument slots;
31 REM [A1,A1+A2) the results area of calls; the LIR slots; the spill slots from A5 (slot s at
32 REM A5 + 8(s-1)); the A4 saved callee-saved registers from A3; F9 the saved address of this
33 REM function's own results area; A6 bytes in all; %rbp and the return address above. A7 =
34 REM 16 + A6 (+ realignment); the check compares A7 - 8 (DESIGN 4.9.1); A9 = 1.
35 REM Arrays: E E$ errors; X X$ exits; C C$ consts; Y Y$ entries; N N$ W$ R R$ F F$ Z
36 REM passes.txt; K K$ the needed constants (x64data.bas order: K(1) SLOT_SIZE, K(2)
37 REM STACK_LEAF_MAX, K(3) RC_STATIC, K(4) TAG_STR, K(5-8) STR_RC TAG LEN BYTES, K(9-11)
38 REM FMT_NPIECE NCONV PIECES, K(12-20) FP_KIND CONV FLAGS CLS WIDTH PREC TEXT TLEN SIZE,
39 REM K(21-22) FPK_TEXT CONV, K(23-27) FF_LEFT PLUS SPACE ZERO ALT, K(28-30) CLS_I F P,
40 REM K(31-33) SITE_FILE LINE SIZE, K(34) DATA_ALIGN, K(35-37) ESIZE_I64 F64 BOOL, K(38-45)
41 REM LIM_LIR_INSTRS OPERANDS REGS BLOCKS SLOTS IMMS LABELS SITES, K(46) FILE_VERSION,
42 REM K(47-49) SL_SIZE NREF REFS, K(50) ESIZE_PTR);
43 REM A(row,1) special code, A(row,2) template of each LIR record row; P$ M Q$ T$ templates
44 REM (M: first line, code lines, cold lines, error rows of @C @D, argument slots, form;
45 REM T$: errors of @C @D, flags); V$ cc map (x64data.bas); B$ the function's records, O(J,0)
46 REM their rows, O(J,1) the register of a fused comparison; G their callee, entry or error
47 REM row; G$ fields; U u values, U(41-46) the integer argument and U(51-57) result
48 REM registers; L limbs; Q P the source registers and classes; J$ the parallel moves'
49 REM sources that are no register (tags); D ralloc's table, D(r,0) the class (1 i, 2 f, 3 p);
50 REM T(r,1) writes, T(r,2) the record of a first write by li, T(r,3) reads that need the
51 REM register, T(r,4) reads, T(r,5-8) the li's limbs; J slots (size, align, offset); B blocks
52 REM (kind 1 loop 2 do 3 if, else seen, step register, ind); I open blocks; S sites (file,
53 REM line), H their hash (pass A: function names); S$ signatures (name, parameter and result
54 REM classes); H$ #file paths; V limbs, V(11..) the callee-saved registers in table order,
55 REM V(21..) those saved by this function; W byte codes; A$ message arguments.
56 REM Scalars: W0 mode (1 code, 2 cold, 3 sweep V, 4 sweep R); F0 function number; F1 F2 F3
57 REM its pos; F4 kind; F5$ name; F6$ F7$ classes; F8 own extra results; N0 records; M0
58 REM registers; S0 slots; S8 spill slots; A0 largest alignment; B7 blocks; K7 open blocks;
59 REM L1 leaf; X8 definition site; X9 sites; D9 data section; D8 last label; M9 mains; L8
60 REM highest label referenced; Z0$ the hex text of 9050; C3 C4 the abs / neg constants
61 REM used; C5 K5$ the kind (1 icmp 2 fcmp 3 bnot) and cc of the fused comparison; Q7 the
62 REM record a folded if has replaced; W4 G5$ the record's form and flags.
63 REM ====================================================================================
200 DIM E(299), E$(299,5), X(19), X$(19), C(299,4), C$(299), Y(64), Y$(64,5)
201 DIM N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), Z(8)
202 DIM K(60), K$(60), A(399,2), P$(199), M(199,7), Q$(1999), T$(199,3), V$(10,9), U$(32,5)
203 DIM B$(219999), O(219999,1), G(219999), G$(300), U(60), L(4), Q(200), P(200), J$(300)
204 DIM D(111110,8), T(99999,8), J(9999,3), B(9999,4), I(10000), S(49999,2), H(131071)
205 DIM S$(19999,3), H$(100), W(65536), A$(4), V(30)
206 FILES "sea.lir"; "sea.s"
207 LET P$ = "seagen_x64"
208 REM Q9$ = a double quote, for the section flags of GNU as
209 LET W(0) = 1
210 LET W(1) = 34
211 CHANGE W TO Q9$
212 REM ---- own DATA (x64data.bas), read before the generated blocks ------------------------
213 LET K0 = 0
214 READ Z$
215 IF Z$ = "-" THEN 220
216 LET K0 = K0 + 1
217 IF K0 > 60 THEN 9970
218 LET K$(K0) = Z$
219 GOTO 214
220 LET S9$ = "|"
221 READ Z$
222 IF Z$ = "-" THEN 226
223 READ V0
224 LET S9$ = S9$ & Z$ & "=" & STR$(V0) & "|"
225 GOTO 221
226 LET V8 = 0
227 READ Z$
228 IF Z$ = "-" THEN 234
229 LET V8 = V8 + 1
230 IF V8 > 10 THEN 9970
231 LET V$(V8,1) = Z$
232 READ V$(V8,2), V$(V8,3), V$(V8,4), V$(V8,5), V$(V8,6), V$(V8,7), V$(V8,8), V$(V8,9)
233 GOTO 227
234 REM the integer argument registers U(41..40+U8) and result registers U(51..50+U9)
235 LET U8 = 0
236 READ V0
237 IF V0 < 0 THEN 242
238 LET U8 = U8 + 1
239 IF U8 > 6 THEN 9970
240 LET U(40 + U8) = V0
241 GOTO 236
242 LET U9 = 0
243 READ V0
244 IF V0 < 0 THEN 249
245 LET U9 = U9 + 1
246 IF U9 > 7 THEN 9970
247 LET U(50 + U9) = V0
248 GOTO 243
249 REM the register names: 64 bits (1-32), 32 and 8 bits (1-16)
250 FOR I5 = 1 TO 32
251 READ U$(I5,3)
252 NEXT I5
253 FOR I5 = 1 TO 16
254 READ U$(I5,4)
255 NEXT I5
256 FOR I5 = 1 TO 16
257 READ U$(I5,5)
258 NEXT I5
259 READ Z$
260 IF Z$ <> "-" THEN 9970
261 REM the register table rows (register, class, ranks, callee-saved) into B(1..N2,0..4),
262 REM declared to ralloc once the consts are known
263 LET N2 = 0
264 READ V0
265 IF V0 < 0 THEN 271
266 LET N2 = N2 + 1
267 IF N2 > 30 THEN 9970
268 LET B(N2,0) = V0
269 READ B(N2,1), B(N2,2), B(N2,3), B(N2,4)
270 GOTO 264
271 LET T7 = 0
272 LET Q8 = 0
273 READ Z$
274 IF Z$ = "-" THEN 303
275 LET T7 = T7 + 1
276 IF T7 > 199 THEN 9970
277 LET P$(T7) = Z$
278 READ T$(T7,1), T$(T7,2)
279 READ V2
280 READ T$(T7,3)
281 READ V0, V1
282 IF Q8 + V0 + V1 > 1999 THEN 9970
283 LET M(T7,1) = Q8 + 1
284 LET M(T7,2) = V0
285 LET M(T7,3) = V1
286 LET M(T7,6) = 0
287 LET M(T7,7) = V2
288 REM chkb's cold block stores idx, dim and ext: three argument slots
289 IF V2 <> 17 THEN 291
290 LET M(T7,6) = 3
291 FOR I5 = 1 TO V0 + V1
292 LET Q8 = Q8 + 1
293 READ Q$(Q8)
294 IF I5 <= V0 THEN 301
295 REM a cold line's @k: argument slot k is used
296 FOR I6 = 0 TO 9
297 IF POS(Q$(Q8), "@" & STR$(I6)) = 0 THEN 300
298 IF I6 + 1 <= M(T7,6) THEN 300
299 LET M(T7,6) = I6 + 1
300 NEXT I6
301 NEXT I5
302 GOTO 273
303 REM ---- the generated blocks (DESIGN 2.6.3), in their canonical order -----------------
304 CALL "tb_errors": P$, E(), E$(), 299, E0
305 CALL "tb_exits": P$, E(), E$(), E0, X(), X$(), 19, N7
306 CALL "tb_consts": P$, E(), E$(), E0, C(), C$(), 299, C9
307 CALL "tb_entries": P$, E(), E$(), E0, Y(), Y$(), 64, Y9
308 LET Z(1) = 39
309 LET Z(2) = 299
310 LET Z(3) = 399
311 LET Z(4) = 1499
312 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), R(), R$(), F(), F$(), Z()
313 REM the constants this pass needs, as numbers
314 FOR I5 = 1 TO K0
315 CALL "tb_cval": C(), C$(), C9, K$(I5), V0, T
316 IF T = 0 THEN 319
317 LET M$ = "constant " & K$(I5) & " is not in the consts table"
318 GOTO 9975
319 LET K(I5) = V0
320 NEXT I5
321 LET M$ = "a LIR limit is larger than the arrays of seagen_x64"
322 IF K(38) + K(42) + 2 > 219999 THEN 9975
323 IF K(40) > 99999 THEN 9975
324 IF K(41) > 9999 THEN 9975
325 IF K(42) > 9999 THEN 9975
326 IF K(45) > 49999 THEN 9975
327 REM ralloc (DESIGN 4.9.2): its table D and the allocatable registers; V(11..10+C2) the
328 REM callee-saved ones in table order (the prologue saves those a function uses)
329 CALL "ra_init": D(), K(40), K(41), 111110, T
330 LET M$ = "ralloc's table D is too small for the LIR limits"
331 IF T <> 0 THEN 9975
332 LET C2 = 0
333 FOR I5 = 1 TO N2
334 CALL "ra_tab": D(), B(I5,0), B(I5,1), B(I5,2), B(I5,3), B(I5,4)
335 IF B(I5,4) = 0 THEN 338
336 LET C2 = C2 + 1
337 LET V(10 + C2) = B(I5,0)
338 NEXT I5
339 REM the error rows of the templates' cold blocks and of the stack check
340 FOR I5 = 1 TO T7
341 FOR I6 = 1 TO 2
342 LET M(I5, 3 + I6) = 0
343 IF T$(I5,I6) = "-" THEN 348
344 CALL "dg_find": T$(I5,I6), E$(), E0, V0
345 LET M$ = "template error " & T$(I5,I6) & " is not in the error table"
346 IF V0 = 0 THEN 9975
347 LET M(I5, 3 + I6) = V0
348 NEXT I6
349 NEXT I5
350 CALL "dg_find": "STACK_OVERFLOW", E$(), E0, E9
351 LET M$ = "STACK_OVERFLOW is not in the error table"
352 IF E9 = 0 THEN 9975
353 REM every LIR record row: special code, template; O$ = |name=row|... for the lookup
354 LET O$ = "|"
355 FOR I5 = 1 TO Z(7)
356 LET A(I5,1) = 0
357 LET A(I5,2) = 0
358 IF R(I5,1) < 5 THEN 372
359 IF R(I5,1) > 6 THEN 372
360 LET O$ = O$ & R$(I5) & "=" & STR$(I5) & "|"
361 LET V0 = POS(S9$, "|" & R$(I5) & "=")
362 IF V0 = 0 THEN 365
363 LET V1 = POS(S9$, "|", V0 + 1)
364 LET A(I5,1) = VAL(SEG$(S9$, V0 + LEN(R$(I5)) + 2, V1 - 1))
365 LET Z$ = R$(I5)
366 IF Z$ <> "rcount" THEN 368
367 LET Z$ = "rcount0"
368 FOR I6 = 1 TO T7
369 IF P$(I6) <> Z$ THEN 371
370 LET A(I5,2) = I6
371 NEXT I6
372 NEXT I5
373 LET T9 = 0
374 FOR I6 = 1 TO T7
375 IF P$(I6) <> "rcount1" THEN 377
376 LET T9 = I6
377 NEXT I6
378 LET M$ = "template rcount1 missing"
379 IF T9 = 0 THEN 9975
1000 REM ---- pass A: the signature of every function ---------------------------------------
1005 CALL "io_hdr": 1, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), K(46), T$, H$(), 100, N1, L$
1010 IF T$ <> "x86_64-linux" THEN 9980
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
1225 LET X$ = "# sea.s -- written by seagen_x64 from sea.lir (Sea DESIGN.md 4.8, 4.9)"
1230 GOSUB 9000
1235 LET X$ = ".text"
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
3015 FOR I6 = 0 TO 4
3016 LET T(I5,I6) = 0
3017 NEXT I6
3020 NEXT I5
3022 CALL "ra_fn": D()
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
3082 LET C3 = 0
3083 LET C4 = 0
3084 LET C7 = 0
3085 LET W0 = 3
3090 FOR J = 1 TO N0 - 1
3095 CALL "io_split": B$(J), G$(), 300, C0
3100 IF C0 < 1 THEN 9990
3105 LET Z$ = G$(1)
3110 GOSUB 9350
3115 IF I0 = 0 THEN 9990
3120 LET O(J,0) = I0
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
3268 ON Y0 GOTO 9990,9990,9990,3290,3290,9990,3295,3320,3360,3320,3360,3320,3320,3380,3360,3400,3400,3410,3420,3442,3460
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
3350 LET B(B7,3) = Q(4)
3351 GOTO 3480
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
3480 GOSUB 4700
3481 NEXT J
3482 IF K7 <> 0 THEN 9990
3483 LET A$(1) = "instructions"
3484 IF N9 > K(38) THEN 9960
3485 LET A$(1) = "operands"
3486 IF O0 > K(39) THEN 9960
3487 LET A$(1) = "immediates"
3488 IF I9 > K(43) THEN 9960
3489 GOSUB 3650
3490 GOSUB 4500
3491 GOSUB 3800
3492 GOSUB 3900
3493 RETURN
3550 REM ---- arguments P() against classes Z7$, result registers G$(Y4..) against Z6$ (Y7 of
3551 REM them, or 0); the stack bytes of the arguments (Y6 = 1: %rdi holds the results area;
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
3576 IF G1 <= U8 THEN 3580
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
3621 IF R$(I0) = "release" THEN 3640
3622 IF R$(I0) <> "la" THEN 3480
3624 IF H0 <= L8 THEN 3480
3626 LET L8 = H0
3628 GOTO 3480
3630 REM a loop: its ind is not the ind of an enclosing loop (the loop writes it at each step)
3632 LET R0 = Q(1)
3634 GOSUB 9660
3636 LET B(B7,1) = 1
3638 RETURN
3640 REM release calls entry FREE (DESIGN 4.9): the function is non-leaf; G(J) = the entry
3641 LET L1 = 0
3642 LET M$ = "entry FREE is not in the entries table"
3643 FOR I5 = 1 TO Y9
3644 IF Y$(I5,1) = "FREE" THEN 3648
3645 NEXT I5
3646 GOTO 9975
3648 LET G(J) = I5
3649 GOTO 3480
3650 REM ---- a fusion candidate stays fused only when its register has one write and one read
3651 FOR J = 2 TO N0 - 1
3652 IF O(J,1) = 0 THEN 3656
3653 IF T(O(J,1),4) <> 1 THEN 3655
3654 IF T(O(J,1),1) = 1 THEN 3656
3655 LET O(J,1) = 0
3656 NEXT J
3657 RETURN
3660 REM ---- T5 the template row of record row I0 (rcount: by its incl), W4 its form (-1: a
3661 REM record of its own), G5$ its flags
3662 LET W4 = -1
3663 LET G5$ = "-"
3664 LET T5 = A(I0,2)
3665 IF R$(I0) <> "rcount" THEN 3668
3666 IF U0 <> 1 THEN 3668
3667 LET T5 = T9
3668 IF T5 = 0 THEN 3671
3669 LET W4 = M(T5,7)
3670 LET G5$ = T$(T5,3)
3671 RETURN
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
3801 LET Y7 = A1 + A2
3802 FOR I5 = 1 TO S0
3803 LET Y1 = J(I5,2)
3804 LET Y7 = INT((Y7 + Y1 - 1) / Y1) * Y1
3805 LET J(I5,3) = Y7
3806 LET Y7 = Y7 + J(I5,1)
3807 NEXT I5
3808 LET Y7 = INT((Y7 + 7) / 8) * 8
3809 LET A5 = Y7
3810 LET Y7 = Y7 + 8 * S8
3811 LET A3 = Y7
3812 LET A4 = 0
3813 FOR I5 = 1 TO C2
3814 CALL "ra_used": D(), V(10 + I5), W5
3815 IF W5 = 0 THEN 3818
3816 LET A4 = A4 + 1
3817 LET V(20 + A4) = V(10 + I5)
3818 NEXT I5
3819 LET Y7 = Y7 + 8 * A4
3820 LET F9 = 0
3821 IF F8 = 0 THEN 3824
3822 LET F9 = Y7
3823 LET Y7 = Y7 + 8
3824 LET A6 = INT((Y7 + 15) / 16) * 16
3825 LET A8 = 0
3826 IF A0 <= 16 THEN 3828
3827 LET A8 = 1
3828 LET A7 = 16 + A6
3829 IF A8 = 0 THEN 3831
3830 LET A7 = A7 + A0 - 16
3831 LET A9 = 0
3832 IF L1 = 0 THEN 3834
3833 IF A7 <= K(2) THEN 3835
3834 LET A9 = 1
3835 RETURN
3900 REM ---- the definition site (DESIGN 4.6, 4.9), then the two sweeps -----------------------
3901 LET X1 = F1
3902 LET X2 = F2
3903 LET W0 = 1
3904 GOSUB 9300
3905 LET X8 = X0
3906 LET L9$ = ".L" & STR$(F0) & "_"
3907 REM no line count and no far form: GNU as picks short or near branches (DESIGN 4.9.1)
3908 LET W0 = 1
3909 LET Q7 = 0
3910 LET C5 = 0
3911 CALL "ra_rew": D()
3912 GOSUB 4000
3913 GOSUB 4300
3914 GOSUB 4400
3915 LET W0 = 2
3916 LET Q7 = 0
3917 GOSUB 4415
3918 GOSUB 4300
3919 GOSUB 4426
3920 RETURN
4000 REM ---- label, stack check, frame, saved registers, parameters (DESIGN 4.9.1, 4.9.2) ----
4001 LET X$ = "# " & F5$ & " at " & STR$(F1) & ":" & STR$(F2) & ":" & STR$(F3)
4002 GOSUB 9000
4003 LET X$ = ".p2align 4"
4004 GOSUB 9010
4005 IF F4 <> 1 THEN 4012
4006 LET X$ = ".globl sea_main"
4007 GOSUB 9010
4008 LET X$ = ".type sea_main, @function"
4009 GOSUB 9010
4010 LET X$ = "sea_main:"
4011 GOTO 4013
4012 LET X$ = ".Lfn_" & F5$ & ":"
4013 GOSUB 9000
4014 IF A9 = 0 THEN 4036
4015 REM r = %rsp - sea_stack_limit: a borrow (CF) or r < N, unsigned, is a stack overflow; N =
4016 REM A7 - 8 the bytes the prologue allocates below the return address (DESIGN 4.6, 4.9.1)
4017 LET X$ = "movq sea_stack_limit(%rip), %r11"
4018 GOSUB 9010
4019 LET X$ = "movq %rsp, %r10"
4020 GOSUB 9010
4021 LET X$ = "subq %r11, %r10"
4022 GOSUB 9010
4023 LET X$ = "jb .L" & STR$(F0) & "_so"
4024 GOSUB 9010
4025 LET Z5 = A7 - 8
4026 GOSUB 9050
4027 IF Z5 > 999999999 THEN 4030
4028 LET X$ = "cmpq $" & Z0$ & ", %r10"
4029 GOTO 4033
4030 LET X$ = "movabsq $" & Z0$ & ", %r11"
4031 GOSUB 9010
4032 LET X$ = "cmpq %r11, %r10"
4033 GOSUB 9010
4034 LET X$ = "jb .L" & STR$(F0) & "_so"
4035 GOSUB 9010
4036 LET X$ = "pushq %rbp"
4037 GOSUB 9010
4038 LET X$ = "movq %rsp, %rbp"
4039 GOSUB 9010
4040 IF A6 = 0 THEN 4050
4041 LET Z5 = A6
4042 GOSUB 9050
4043 IF A6 > 999999999 THEN 4046
4044 LET X$ = "subq $" & Z0$ & ", %rsp"
4045 GOTO 4049
4046 LET X$ = "movabsq $" & Z0$ & ", %r10"
4047 GOSUB 9010
4048 LET X$ = "subq %r10, %rsp"
4049 GOSUB 9010
4050 IF A8 = 0 THEN 4053
4051 LET X$ = "andq $-" & STR$(A0) & ", %rsp"
4052 GOSUB 9010
4053 REM the callee-saved registers the function allocates, in table order
4054 FOR I5 = 1 TO A4
4055 LET Z1$ = "str"
4056 LET Z2$ = U$(V(20 + I5),3)
4057 LET Z3 = A3 + 8 * (I5 - 1)
4058 LET Z4$ = "%rsp"
4059 GOSUB 9020
4060 NEXT I5
4061 REM the parameters: the results-area address to F9; the others one parallel move from the
4062 REM argument registers and the stack at 16+8k(%rbp) to their locations (DESIGN 4.9.2)
4063 LET G1 = 0
4064 LET G2 = 0
4065 LET G3 = 0
4066 LET G7 = 0
4067 IF F8 = 0 THEN 4074
4068 LET Z1$ = "str"
4069 LET Z2$ = U$(U(41),3)
4070 LET Z3 = F9
4071 LET Z4$ = "%rsp"
4072 GOSUB 9020
4073 LET G1 = 1
4074 FOR K2 = 1 TO LEN(F6$)
4075 LET E6 = 1
4076 IF SEG$(F6$, K2, K2) = "f" THEN 4081
4077 IF G1 >= U8 THEN 4086
4078 LET G1 = G1 + 1
4079 LET E7 = U(40 + G1)
4080 GOTO 4090
4081 LET E6 = 2
4082 IF G2 >= 8 THEN 4086
4083 LET E7 = 17 + G2
4084 LET G2 = G2 + 1
4085 GOTO 4090
4086 LET G7 = G7 + 1
4087 LET J$(G7) = "@" & STR$(16 + 8 * G3) & "(%rbp)"
4088 LET G3 = G3 + 1
4089 LET E7 = 3000 + G7
4090 LET E8 = D(K2,8)
4091 IF E8 = 0 THEN 4093
4092 GOSUB 8333
4093 NEXT K2
4094 GOSUB 8338
4095 RETURN
4300 REM ---- the records of the function (slots have no code) ---------------------------------
4301 FOR J = 2 TO N0 - 1
4302 IF A(O(J,0),1) = 2 THEN 4304
4303 GOSUB 5000
4304 NEXT J
4305 RETURN
4400 REM ---- epilogue: every ret jumps here; the saved callee-saved registers restored ---------
4401 LET X$ = L9$ & "ret:"
4402 GOSUB 9000
4403 FOR I5 = 1 TO A4
4404 LET Z1$ = "ldr"
4405 LET Z2$ = U$(V(20 + I5),3)
4406 LET Z3 = A3 + 8 * (I5 - 1)
4407 LET Z4$ = "%rsp"
4408 GOSUB 9020
4409 NEXT I5
4410 LET X$ = "leave"
4411 GOSUB 9010
4412 LET X$ = "ret"
4413 GOSUB 9010
4414 RETURN
4415 REM ---- the stack check's cold block: sea_err(STACK_OVERFLOW, definition site), reached with
4416 REM %rsp = 8 (mod 16) and nothing allocated: realigned first (DESIGN 4.9.1)
4417 IF A9 = 0 THEN 4425
4418 LET X$ = L9$ & "so:"
4419 GOSUB 9000
4420 LET X$ = "subq $8, %rsp"
4421 GOSUB 9010
4422 LET Z8 = E(E9)
4423 LET X0 = X8
4424 GOSUB 9375
4425 RETURN
4426 REM ---- the 16-byte constants of fabs / fneg after the f64 constants (DESIGN 4.9.2, L-ah)
4427 IF C3 = 0 THEN 4431
4428 LET Z$ = "abs"
4429 LET Z0$ = "0x7FFFFFFFFFFFFFFF"
4430 GOSUB 4436
4431 IF C4 = 0 THEN 4435
4432 LET Z$ = "neg"
4433 LET Z0$ = "0x8000000000000000"
4434 GOSUB 4436
4435 RETURN
4436 LET X$ = ".p2align 4"
4437 GOSUB 9010
4438 LET X$ = L9$ & Z$ & ":"
4439 GOSUB 9000
4440 LET X$ = ".quad " & Z0$
4441 GOSUB 9010
4442 GOSUB 9010
4443 RETURN
4500 REM ---- sweep R (W0 = 4): every register reference of the code the sweeps write, in record
4501 REM order (ralloc API: reads, ra_call, writes, ra_hint, ra_open / ra_else / ra_close); an immediate
4502 REM use, an li not emitted and a fused comparison are not references (DESIGN 4.9.2)
4503 LET W0 = 4
4504 FOR I5 = 1 TO LEN(F6$)
4505 CALL "ra_par": D(), I5
4506 NEXT I5
4507 FOR J = 2 TO N0 - 1
4508 LET I0 = O(J,0)
4509 LET Y0 = A(I0,1)
4510 IF Y0 = 2 THEN 4601
4511 CALL "io_split": B$(J), G$(), 300, C0
4512 GOSUB 9400
4513 GOSUB 3660
4514 IF Y0 <> 4 THEN 4519
4515 LET R0 = D1
4516 GOSUB 8270
4517 IF W2 = 0 THEN 4519
4518 IF T(D1,3) = 0 THEN 4601
4519 LET K5 = 1
4520 IF Y0 <> 8 THEN 4522
4521 LET K5 = 2
4522 FOR K6 = K5 TO P0
4523 IF K6 > 1 THEN 4526
4524 REM the condition of a consumer of a fused comparison
4525 IF O(J - 1,1) > 0 THEN 4529
4526 GOSUB 8282
4527 IF W3 = 1 THEN 4529
4528 CALL "ra_ref": D(), J, Q(K6), 0
4529 NEXT K6
4530 IF Y0 = 19 THEN 4533
4531 IF Y0 = 20 THEN 4533
4532 IF W4 <> 19 THEN 4536
4533 CALL "ra_call": D(), J
4534 IF Y0 = 19 THEN 4576
4535 IF Y0 = 20 THEN 4576
4536 IF D1 = 0 THEN 4540
4537 REM a fused comparison writes no register
4538 IF O(J,1) > 0 THEN 4540
4539 CALL "ra_ref": D(), J, D1, 1
4540 IF E1 = 0 THEN 4542
4541 CALL "ra_ref": D(), J, E1, 1
4542 IF Y0 <> 8 THEN 4544
4543 CALL "ra_ref": D(), J, Q(1), 1
4544 IF Y0 <> 0 THEN 4585
4545 IF W4 <> 21 THEN 4551
4546 LET K6 = 1
4547 GOSUB 8282
4548 IF W3 = 1 THEN 4601
4549 CALL "ra_hint": D(), J, D1, Q(1), 0
4550 GOTO 4601
4551 IF W4 < 1 THEN 4601
4552 IF W4 > 5 THEN 4572
4553 IF W4 > 2 THEN 4570
4554 REM d = a op b prefers a's register, for a commuting operation b's (a: the operand that is
4555 REM no immediate)
4556 LET K6 = 2
4557 GOSUB 8282
4558 LET H6 = W3
4559 LET K6 = 1
4560 GOSUB 8282
4561 IF W3 = 0 THEN 4564
4562 CALL "ra_hint": D(), J, D1, Q(2), 0
4563 GOTO 4601
4564 LET W5 = 0
4565 IF H6 = 1 THEN 4568
4566 IF POS(G5$, "c") = 0 THEN 8665
4567 LET W5 = Q(2)
4568 CALL "ra_hint": D(), J, D1, Q(1), W5
4569 GOTO 4601
4570 CALL "ra_hint": D(), J, D1, Q(1), 0
4571 GOTO 4601
4572 IF W4 < 13 THEN 4601
4573 IF W4 > 14 THEN 4601
4574 CALL "ra_hint": D(), J, D1, Q(2), Q(3)
4575 GOTO 4601
4576 LET Y4 = 5
4577 IF Y0 = 20 THEN 4579
4578 LET Y4 = 4
4579 LET Y8 = VAL(G$(Y4 - 1))
4580 FOR K2 = 1 TO Y8
4581 LET R0 = VAL(SEG$(G$(Y4 + K2 - 1), 2, LEN(G$(Y4 + K2 - 1))))
4582 CALL "ra_ref": D(), J, R0, 1
4583 NEXT K2
4584 GOTO 4601
4585 IF Y0 < 8 THEN 4601
4586 IF Y0 > 15 THEN 4601
4587 LET Y7 = VAL(G$(2))
4588 ON Y0 - 7 GOTO 4589,4600,4596,4600,4598,4598,4606,4600
4589 LET K6 = 4
4590 GOSUB 8282
4591 LET W5 = 0
4592 IF W3 = 1 THEN 4594
4593 LET W5 = Q(4)
4594 CALL "ra_open": D(), J, Y7, 1, Q(1), W5
4595 GOTO 4601
4596 CALL "ra_open": D(), J, Y7, 2, 0, 0
4597 GOTO 4601
4598 CALL "ra_open": D(), J, Y7, 3, 0, 0
4599 GOTO 4601
4600 CALL "ra_close": D(), J, Y7
4601 NEXT J
4602 CALL "ra_end": D(), M0, S8, T
4603 LET M$ = "ralloc: a block still open at ra_end"
4604 IF T <> 0 THEN 9975
4605 RETURN
4606 CALL "ra_else": D(), J, Y7
4607 GOTO 4601
4700 REM ---- sweep V bookkeeping of record J: T(r,1) writes, T(r,2) the li record of a first
4701 REM write by li and T(r,5..8) its limbs, T(r,0) the source of a first write by mov, T(r,3) the reads that need the register, T(r,4)
4702 REM the reads; O(J-1,1) a fusion candidate (DESIGN 4.9.2 Immediates, fusion); C3 C4
4703 LET O(J,1) = 0
4704 IF J = 1 THEN 4767
4705 IF Y0 = 2 THEN 4756
4706 GOSUB 3660
4707 LET K5 = 1
4708 IF Y0 <> 8 THEN 4710
4709 LET K5 = 2
4710 FOR K6 = K5 TO P0
4711 LET T(Q(K6),4) = T(Q(K6),4) + 1
4712 GOSUB 8282
4713 IF W3 = 1 THEN 4715
4714 LET T(Q(K6),3) = T(Q(K6),3) + 1
4715 NEXT K6
4716 IF Y0 = 19 THEN 4757
4717 IF Y0 = 20 THEN 4757
4718 LET R0 = D1
4719 GOSUB 4772
4720 LET R0 = E1
4721 GOSUB 4772
4722 IF Y0 <> 8 THEN 4725
4723 LET R0 = Q(1)
4724 GOSUB 4772
4725 REM the previous record is a comparison whose register this one reads as the condition
4726 REM of an if / ifz, or of a selection when it is no fcmp eq / ne (L-as)
4727 IF C7 = 0 THEN 4737
4728 IF P0 = 0 THEN 4737
4729 IF Q(1) <> C7 THEN 4737
4730 IF Y0 = 12 THEN 4736
4731 IF Y0 = 13 THEN 4736
4732 IF Y0 <> 0 THEN 4737
4733 IF C8 = 2 THEN 4737
4734 IF W4 = 13 THEN 4736
4735 IF W4 <> 14 THEN 4737
4736 LET O(J - 1,1) = C7
4737 LET C7 = 0
4738 IF Y0 <> 0 THEN 4756
4739 IF W4 = 5 THEN 4752
4740 IF W4 = 9 THEN 4749
4741 IF W4 = 11 THEN 4749
4742 IF W4 <> 10 THEN 4756
4743 LET C7 = D1
4744 LET C8 = 3
4745 IF K1$ = "eq" THEN 4747
4746 IF K1$ <> "ne" THEN 4756
4747 LET C8 = 2
4748 GOTO 4756
4749 LET C7 = D1
4750 LET C8 = 1
4751 GOTO 4756
4752 IF POS(G5$, "n") = 0 THEN 4755
4753 LET C4 = 1
4754 GOTO 4756
4755 LET C3 = 1
4756 RETURN
4757 LET Y4 = 5
4758 IF Y0 = 20 THEN 4760
4759 LET Y4 = 4
4760 LET Y8 = VAL(G$(Y4 - 1))
4761 FOR K2 = 1 TO Y8
4762 LET R0 = VAL(SEG$(G$(Y4 + K2 - 1), 2, LEN(G$(Y4 + K2 - 1))))
4763 GOSUB 4772
4764 NEXT K2
4765 LET C7 = 0
4766 RETURN
4767 REM the parameters are written at the function's entry
4768 FOR K6 = 1 TO P0
4769 LET T(Q(K6),1) = T(Q(K6),1) + 1
4770 NEXT K6
4771 RETURN
4772 IF R0 = 0 THEN 4780
4773 LET T(R0,1) = T(R0,1) + 1
4774 IF T(R0,1) <> 1 THEN 4780
4775 IF Y0 <> 4 THEN 8640
4776 LET T(R0,2) = J
4777 FOR I5 = 1 TO 4
4778 LET T(R0,4 + I5) = L(I5)
4779 NEXT I5
4780 RETURN
5000 REM ---- one record: code (mode 1) and cold part (mode 2) ---------------------------------
5001 LET I0 = O(J,0)
5002 LET Y0 = A(I0,1)
5003 CALL "io_split": B$(J), G$(), 300, C0
5004 GOSUB 9400
5005 GOSUB 3660
5006 IF J = Q7 THEN 5290
5007 IF Y0 = 0 THEN 5100
5008 ON Y0 GOTO 9990,9990,9990,5300,5315,9990,5330,5344,5368,5422,5427,5435,5435,5457,5465,5475,5480,5488,5526,5574,5628
5100 REM ---- an instruction of the template table: direct (W4 > 0) or staged (W4 = 0) ---------
5101 IF W0 = 2 THEN 5200
5102 ON W4 + 1 GOTO 5649,5687,5737,5764,5784,5793,5805,5811,5819,5847,5847,5847,5847,5903,5921,5968,5968,6036,6065,6081,6109,6113
5200 REM the cold blocks: @C (the template's cold lines, or chkb's stores), @D
5201 IF M(T5,4) = 0 THEN 5213
5202 LET X$ = L9$ & "e" & STR$(J) & ":"
5203 GOSUB 9000
5204 IF W4 <> 17 THEN 5207
5205 GOSUB 6054
5206 GOTO 5211
5207 FOR I6 = M(T5,1) + M(T5,2) TO M(T5,1) + M(T5,2) + M(T5,3) - 1
5208 LET Z$ = Q$(I6)
5209 GOSUB 9150
5210 NEXT I6
5211 LET Z8 = E(M(T5,4))
5212 GOSUB 9375
5213 IF M(T5,5) = 0 THEN 5290
5214 LET X$ = L9$ & "f" & STR$(J) & ":"
5215 GOSUB 9000
5216 LET Z8 = E(M(T5,5))
5217 GOSUB 9375
5290 RETURN
5300 REM ---- li: not emitted when every use is an immediate; movq $v (32 bits) or movabsq -----
5301 IF W0 = 2 THEN 5290
5302 LET R0 = D1
5303 GOSUB 8270
5304 IF W2 = 0 THEN 5306
5305 IF T(D1,3) = 0 THEN 5290
5306 FOR I5 = 1 TO 4
5307 LET V(I5) = L(I5)
5308 NEXT I5
5309 GOSUB 8244
5310 GOSUB 8219
5311 LET R6$ = Z3$
5312 GOSUB 8547
5313 GOSUB 8232
5314 GOTO 5290
5315 REM ---- lf: the constant is a .quad in the cold part, loaded rip-relative ------------------
5316 LET Y6$ = L9$ & "c" & STR$(J)
5317 IF W0 = 2 THEN 5323
5318 GOSUB 8219
5319 LET X$ = "movsd " & Y6$ & "(%rip), " & Z3$
5320 GOSUB 9010
5321 GOSUB 8232
5322 GOTO 5290
5323 LET X$ = ".p2align 3"
5324 GOSUB 9010
5325 LET X$ = Y6$ & ":"
5326 GOSUB 9000
5327 LET X$ = ".quad 0x" & SEG$(G$(3), 2, 17)
5328 GOSUB 9010
5329 GOTO 5290
5330 REM ---- sa: the address of a LIR slot --------------------------------------------------------
5331 IF W0 = 2 THEN 5290
5332 GOSUB 8219
5333 LET Z5 = J(H1,3)
5334 GOSUB 9050
5335 IF Z5 >= 2 ^ 31 THEN 5338
5336 LET X$ = "leaq " & Z0$ & "(%rsp), " & Z3$
5337 GOTO 5341
5338 LET X$ = "movabsq $" & Z0$ & ", " & Z3$
5339 GOSUB 9010
5340 LET X$ = "addq %rsp, " & Z3$
5341 GOSUB 9010
5342 GOSUB 8232
5343 GOTO 5290
5344 REM ---- loop b ind start last step: one parallel move ind <- start, the hidden count <- last
5345 REM (and the hidden step <- step), then the top (DESIGN 4.9.2 Moves, Loop closing)
5346 IF W0 = 2 THEN 5290
5347 LET Y7 = VAL(G$(2))
5348 CALL "ra_blk": D(), Y7, L5, L6, L7
5349 LET G7 = 0
5350 LET E6 = 1
5351 LET R0 = Q(2)
5352 GOSUB 8321
5353 LET E8 = D(Q(1),8)
5354 GOSUB 8333
5355 LET R0 = Q(3)
5356 GOSUB 8321
5357 LET E8 = L5
5358 GOSUB 8333
5359 IF L6 = 0 THEN 5364
5360 LET R0 = Q(4)
5361 GOSUB 8321
5362 LET E8 = L6
5363 GOSUB 8333
5364 GOSUB 8338
5365 LET X$ = L9$ & STR$(Y7) & "_top:"
5366 GOSUB 9000
5367 GOTO 5290
5368 REM ---- endloop b: ind + step, count - 1, back while no borrow; or, when ind is read after
5369 REM the loop, the count tested first (DESIGN 4.9.2 Loop closing, L-ai)
5370 IF W0 = 2 THEN 5290
5371 LET Y7 = VAL(G$(2))
5372 LET Y6$ = L9$ & STR$(Y7) & "_"
5373 CALL "ra_blk": D(), Y7, L5, L6, L7
5374 LET X$ = Y6$ & "next:"
5375 GOSUB 9000
5376 IF L7 = 0 THEN 5390
5377 LET W1 = L5
5378 GOSUB 8446
5379 LET X$ = "testq " & Z2$ & ", " & Z2$
5380 GOSUB 9010
5381 LET X$ = "je " & Y6$ & "exit"
5382 GOSUB 9010
5383 LET X$ = "decq " & Z2$
5384 GOSUB 9010
5385 GOSUB 8463
5386 GOSUB 5401
5387 LET X$ = "jmp " & Y6$ & "top"
5388 GOSUB 9010
5389 GOTO 5398
5390 GOSUB 5401
5391 LET W1 = L5
5392 GOSUB 8446
5393 LET X$ = "subq $1, " & Z2$
5394 GOSUB 9010
5395 GOSUB 8463
5396 LET X$ = "jae " & Y6$ & "top"
5397 GOSUB 9010
5398 LET X$ = Y6$ & "exit:"
5399 GOSUB 9000
5400 GOTO 5290
5401 REM ind + step: the step's hidden register, its immediate (an li, or a mov of one: 8655) or
5402 REM its register (in %rcx when spilled); ind in place, or through %rax when spilled
5403 IF L6 = 0 THEN 5406
5404 LET W1 = L6
5405 GOTO 5413
5406 LET R0 = B(Y7,3)
5407 GOSUB 8655
5408 IF W2 = 0 THEN 5412
5409 IF V9 = 0 THEN 5412
5410 LET H6$ = Z2$
5411 GOTO 5416
5412 LET W1 = D(B(Y7,3),8)
5413 LET N5 = 2
5414 GOSUB 8454
5415 LET H6$ = Z2$
5416 LET W1 = D(B(Y7,4),8)
5417 GOSUB 8446
5418 LET X$ = "addq " & H6$ & ", " & Z2$
5419 GOSUB 9010
5420 GOSUB 8463
5421 RETURN
5422 REM ---- do b: the top label -----------------------------------------------------------------
5423 IF W0 = 2 THEN 5290
5424 LET X$ = L9$ & G$(2) & "_top:"
5425 GOSUB 9000
5426 GOTO 5290
5427 REM ---- enddo b -------------------------------------------------------------------------------
5428 IF W0 = 2 THEN 5290
5429 LET Y6$ = L9$ & G$(2) & "_"
5430 LET X$ = "jmp " & Y6$ & "top"
5431 GOSUB 9010
5432 LET X$ = Y6$ & "exit:"
5433 GOSUB 9000
5434 GOTO 5290
5435 REM ---- if b c / ifz b c: to the else label when the condition fails / holds; an if without
5436 REM else whose first part is one exit / next is one branch to its label (DESIGN 4.9.2)
5437 IF W0 = 2 THEN 5290
5438 LET X7 = 0
5439 IF Y0 = 12 THEN 5441
5440 LET X7 = 1
5441 LET T6$ = L9$ & G$(2) & "_else"
5442 IF J + 2 >= N0 THEN 5455
5443 IF R$(O(J + 2,0)) <> "endif" THEN 5455
5444 LET Z$ = R$(O(J + 1,0))
5445 IF Z$ = "exit" THEN 5447
5446 IF Z$ <> "next" THEN 5455
5447 LET Y7 = VAL(SEG$(B$(J + 1), 6, LEN(B$(J + 1))))
5448 LET T6$ = L9$ & STR$(Y7) & "_exit"
5449 IF Z$ = "exit" THEN 5453
5450 LET T6$ = L9$ & STR$(Y7) & "_top"
5451 IF B(Y7,1) <> 1 THEN 5453
5452 LET T6$ = L9$ & STR$(Y7) & "_next"
5453 LET X7 = 1 - X7
5454 LET Q7 = J + 1
5455 GOSUB 8472
5456 GOTO 5290
5457 REM ---- else b -------------------------------------------------------------------------------
5458 IF W0 = 2 THEN 5290
5459 LET Y6$ = L9$ & G$(2) & "_"
5460 LET X$ = "jmp " & Y6$ & "end"
5461 GOSUB 9010
5462 LET X$ = Y6$ & "else:"
5463 GOSUB 9000
5464 GOTO 5290
5465 REM ---- endif b (the else label too when there was no else) --------------------------------
5466 IF W0 = 2 THEN 5290
5467 LET Y7 = VAL(G$(2))
5468 LET Y6$ = L9$ & G$(2) & "_"
5469 IF B(Y7,2) = 1 THEN 5472
5470 LET X$ = Y6$ & "else:"
5471 GOSUB 9000
5472 LET X$ = Y6$ & "end:"
5473 GOSUB 9000
5474 GOTO 5290
5475 REM ---- exit b ------------------------------------------------------------------------------
5476 IF W0 = 2 THEN 5290
5477 LET X$ = "jmp " & L9$ & G$(2) & "_exit"
5478 GOSUB 9010
5479 GOTO 5290
5480 REM ---- next b: a loop's closing sequence, a do's top --------------------------------------
5481 IF W0 = 2 THEN 5290
5482 LET Y7 = VAL(G$(2))
5483 LET X$ = "jmp " & L9$ & G$(2) & "_top"
5484 IF B(Y7,1) <> 1 THEN 5486
5485 LET X$ = "jmp " & L9$ & G$(2) & "_next"
5486 GOSUB 9010
5487 GOTO 5290
5488 REM ---- ret: the results beyond the registers into the caller's results area (its address
5489 REM from F9 in %r11, through %rax), then one parallel move into the result registers, the
5490 REM epilogue (DESIGN 4.8, 4.9.2)
5491 IF W0 = 2 THEN 5290
5492 IF F8 = 0 THEN 5498
5493 LET Z1$ = "ldr"
5494 LET Z2$ = "%r11"
5495 LET Z3 = F9
5496 LET Z4$ = "%rsp"
5497 GOSUB 9020
5498 LET G1 = 0
5499 LET G2 = 0
5500 LET G4 = 0
5501 LET G7 = 0
5502 FOR K6 = 1 TO P0
5503 LET R0 = Q(K6)
5504 IF P(K6) = 2 THEN 5510
5505 IF G1 >= U9 THEN 5517
5506 LET G1 = G1 + 1
5507 LET E8 = U(50 + G1)
5508 LET E6 = 1
5509 GOTO 5514
5510 IF G2 >= 8 THEN 5517
5511 LET E8 = 17 + G2
5512 LET G2 = G2 + 1
5513 LET E6 = 2
5514 GOSUB 8321
5515 GOSUB 8333
5516 GOTO 5521
5517 LET Z6 = 8 * G4
5518 LET O6$ = "%r11"
5519 GOSUB 8520
5520 LET G4 = G4 + 1
5521 NEXT K6
5522 GOSUB 8338
5523 LET X$ = "jmp " & L9$ & "ret"
5524 GOSUB 9010
5525 GOTO 5290
5526 REM ---- call: the saves, one parallel move of the arguments, call, the results, the
5527 REM reloads (DESIGN 4.8 calling convention, 4.9.2 Calls)
5528 IF W0 = 2 THEN 5290
5529 LET Y7 = G(J)
5530 LET Z6$ = S$(Y7,3)
5531 GOSUB 9630
5532 LET Y4 = 4
5533 LET Y8 = VAL(G$(3))
5534 GOSUB 8422
5535 LET G1 = 0
5536 LET G2 = 0
5537 LET G3 = 0
5538 LET G7 = 0
5539 IF Z8 = 0 THEN 5547
5540 LET G7 = 1
5541 LET J$(1) = "&" & STR$(A1) & "(%rsp)"
5542 LET E7 = 3001
5543 LET E8 = U(41)
5544 LET E6 = 1
5545 GOSUB 8333
5546 LET G1 = 1
5547 GOSUB 5553
5548 GOSUB 8338
5549 LET X$ = "call .Lfn_" & S$(Y7,1)
5550 GOSUB 9010
5551 GOSUB 5602
5552 GOTO 5290
5553 REM ---- the arguments Q() P() to the integer registers from G1, xmm from G2 and the stack
5554 REM slots from G3 (codes 1000 + k), listed in argument order
5555 FOR K2 = 1 TO P0
5556 LET R0 = Q(K2)
5557 GOSUB 8321
5558 IF P(K2) = 2 THEN 5564
5559 LET E6 = 1
5560 IF G1 >= U8 THEN 5569
5561 LET G1 = G1 + 1
5562 LET E8 = U(40 + G1)
5563 GOTO 5571
5564 LET E6 = 2
5565 IF G2 >= 8 THEN 5569
5566 LET E8 = 17 + G2
5567 LET G2 = G2 + 1
5568 GOTO 5571
5569 LET E8 = 1000 + G3
5570 LET G3 = G3 + 1
5571 GOSUB 8333
5572 NEXT K2
5573 RETURN
5574 REM ---- rcall: the saves, the arguments and the site index (entries with site S), call
5575 REM <symbol>, the results, the reloads
5576 IF W0 = 2 THEN 5290
5577 LET Y7 = G(J)
5578 LET Y4 = 5
5579 LET Y8 = VAL(G$(4))
5580 GOSUB 8422
5581 LET G1 = 0
5582 LET G2 = 0
5583 LET G3 = 0
5584 LET G7 = 0
5585 GOSUB 5553
5586 IF X3 = 0 THEN 5597
5587 LET G7 = G7 + 1
5588 LET J$(G7) = "$" & STR$(X0)
5589 LET E7 = 3000 + G7
5590 LET E6 = 1
5591 IF G1 >= U8 THEN 5595
5592 LET G1 = G1 + 1
5593 LET E8 = U(40 + G1)
5594 GOTO 5596
5595 LET E8 = 1000 + G3
5596 GOSUB 8333
5597 GOSUB 8338
5598 LET X$ = "call " & Y$(Y7,2)
5599 GOSUB 9010
5600 GOSUB 5602
5601 GOTO 5290
5602 REM ---- the Y8 results, registers G$(Y4 ...), from the result registers, %xmm0-%xmm7 and the
5603 REM results area at A1 (codes 2000 + k): one parallel move; then the reloads
5604 LET G1 = 0
5605 LET G2 = 0
5606 LET G4 = 0
5607 FOR K3 = 1 TO Y8
5608 LET Y5$ = G$(Y4 + K3 - 1)
5609 LET E8 = D(VAL(SEG$(Y5$, 2, LEN(Y5$))),8)
5610 IF SEG$(Y5$, 1, 1) = "f" THEN 5616
5611 LET E6 = 1
5612 IF G1 >= U9 THEN 5621
5613 LET G1 = G1 + 1
5614 LET E7 = U(50 + G1)
5615 GOTO 5623
5616 LET E6 = 2
5617 IF G2 >= 8 THEN 5621
5618 LET E7 = 17 + G2
5619 LET G2 = G2 + 1
5620 GOTO 5623
5621 LET E7 = 2000 + G4
5622 LET G4 = G4 + 1
5623 GOSUB 8333
5624 NEXT K3
5625 GOSUB 8338
5626 GOSUB 8431
5627 RETURN
5628 REM ---- chk c err site n a...: to the cold block when c <> 0; the cold block stores the
5629 REM arguments into the slots from their locations
5630 LET Y6$ = L9$ & "e" & STR$(J)
5631 IF W0 = 2 THEN 5639
5632 LET K6 = 1
5633 GOSUB 8302
5634 LET X$ = "testq " & Z2$ & ", " & Z2$
5635 GOSUB 9010
5636 LET X$ = "jne " & Y6$
5637 GOSUB 9010
5638 GOTO 5290
5639 LET X$ = Y6$ & ":"
5640 GOSUB 9000
5641 FOR K6 = 2 TO P0
5642 LET Z6 = (K6 - 2) * K(1)
5643 LET O6$ = "%rsp"
5644 GOSUB 8520
5645 NEXT K6
5646 LET Z8 = E(G(J))
5647 GOSUB 9375
5648 GOTO 5290
5649 REM ---- staged (L-an): the operands into %rax %rcx %rdx / %xmm14 %xmm15 by one parallel
5650 REM move, the sequence, the results out of %rax / %xmm14 (rcount's flag %rcx) by another
5651 LET G7 = 0
5652 LET W5 = 0
5653 LET W6 = 0
5654 FOR K6 = 1 TO P0
5655 LET R0 = Q(K6)
5656 GOSUB 8321
5657 IF P(K6) = 2 THEN 5662
5658 LET W5 = W5 + 1
5659 LET E8 = W5
5660 LET E6 = 1
5661 GOTO 5665
5662 LET W6 = W6 + 1
5663 LET E8 = 30 + W6
5664 LET E6 = 2
5665 GOSUB 8333
5666 NEXT K6
5667 GOSUB 8338
5668 FOR I6 = M(T5,1) TO M(T5,1) + M(T5,2) - 1
5669 LET Z$ = Q$(I6)
5670 GOSUB 9150
5671 NEXT I6
5672 IF D1 = 0 THEN 5290
5673 LET E7 = 1
5674 LET E6 = 1
5675 IF D2 <> 2 THEN 5678
5676 LET E7 = 31
5677 LET E6 = 2
5678 LET E8 = D(D1,8)
5679 GOSUB 8333
5680 IF E1 = 0 THEN 5685
5681 LET E7 = 2
5682 LET E6 = 1
5683 LET E8 = D(E1,8)
5684 GOSUB 8333
5685 GOSUB 8338
5686 GOTO 5290
5687 REM ---- d = a op b, general registers (L-ah): d = a: op b, d; d = b commuting: op a, d;
5688 REM d = b otherwise: in %rax, then moved; else movq a, d and op b, d. An immediate b (or a,
5689 REM for a commuting operation): leaq v(a), d (iadd, padd with d <> a), imulq $v, a, d
5690 LET K6 = 1
5691 GOSUB 8302
5692 LET H5$ = Z2$
5693 LET H5 = W3
5694 LET K6 = 2
5695 GOSUB 8302
5696 LET H6$ = Z2$
5697 LET H6 = W3
5698 GOSUB 8219
5699 LET G6$ = Q$(M(T5,1))
5700 LET O3$ = H5$
5701 LET O4$ = H6$
5702 LET O4 = H6
5703 IF H5 = 0 THEN 5707
5704 LET O3$ = H6$
5705 LET O4$ = H5$
5706 LET O4 = 1
5707 IF O4 = 0 THEN 5715
5708 IF POS(G5$, "l") = 0 THEN 5712
5709 IF Z3$ = O3$ THEN 5712
5710 LET X$ = "leaq " & SEG$(O4$, 2, LEN(O4$)) & "(" & O3$ & "), " & Z3$
5711 GOTO 5731
5712 IF POS(G5$, "m") = 0 THEN 5725
5713 LET X$ = "imulq " & O4$ & ", " & O3$ & ", " & Z3$
5714 GOTO 5731
5715 IF Z3$ = O3$ THEN 5728
5716 IF Z3$ <> O4$ THEN 5725
5717 IF POS(G5$, "c") > 0 THEN 5730
5718 IF O3$ = "%rax" THEN 5721
5719 LET X$ = "movq " & O3$ & ", %rax"
5720 GOSUB 9010
5721 LET X$ = G6$ & " " & O4$ & ", %rax"
5722 GOSUB 9010
5723 LET X$ = "movq %rax, " & Z3$
5724 GOTO 5731
5725 IF Z3$ = O3$ THEN 5728
5726 LET X$ = "movq " & O3$ & ", " & Z3$
5727 GOSUB 9010
5728 LET X$ = G6$ & " " & O4$ & ", " & Z3$
5729 GOTO 5731
5730 LET X$ = G6$ & " " & O3$ & ", " & Z3$
5731 GOSUB 9010
5732 IF POS(G5$, "o") = 0 THEN 5735
5733 LET X$ = "jo " & L9$ & "e" & STR$(J)
5734 GOSUB 9010
5735 GOSUB 8232
5736 GOTO 5290
5737 REM ---- d = a op b, xmm registers: the same forms with movapd, %xmm14 as the scratch
5738 LET K6 = 1
5739 GOSUB 8302
5740 LET H5$ = Z2$
5741 LET K6 = 2
5742 GOSUB 8302
5743 LET H6$ = Z2$
5744 GOSUB 8219
5745 LET G6$ = Q$(M(T5,1))
5746 IF Z3$ = H5$ THEN 5758
5747 IF Z3$ <> H6$ THEN 5756
5748 IF POS(G5$, "c") > 0 THEN 5760
5749 IF H5$ = "%xmm14" THEN 5752
5750 LET X$ = "movapd " & H5$ & ", %xmm14"
5751 GOSUB 9010
5752 LET X$ = G6$ & " " & H6$ & ", %xmm14"
5753 GOSUB 9010
5754 LET X$ = "movapd %xmm14, " & Z3$
5755 GOTO 5761
5756 LET X$ = "movapd " & H5$ & ", " & Z3$
5757 GOSUB 9010
5758 LET X$ = G6$ & " " & H6$ & ", " & Z3$
5759 GOTO 5761
5760 LET X$ = G6$ & " " & H5$ & ", " & Z3$
5761 GOSUB 9010
5762 GOSUB 8232
5763 GOTO 5290
5764 REM ---- shifts: an immediate count in the two-address form; a register count via %rcx
5765 REM (movq b, %rcx first, omitted when b is spilled: then it is in %rcx), then %cl
5766 LET K6 = 1
5767 GOSUB 8302
5768 LET H5$ = Z2$
5769 LET K6 = 2
5770 GOSUB 8302
5771 LET H6$ = Z2$
5772 LET H6 = W3
5773 GOSUB 8219
5774 IF H6 = 1 THEN 5779
5775 IF H6$ = "%rcx" THEN 5778
5776 LET X$ = "movq " & H6$ & ", %rcx"
5777 GOSUB 9010
5778 LET H6$ = "%cl"
5779 IF Z3$ = H5$ THEN 5782
5780 LET X$ = "movq " & H5$ & ", " & Z3$
5781 GOSUB 9010
5782 LET X$ = Q$(M(T5,1)) & " " & H6$ & ", " & Z3$
5783 GOTO 5761
5784 REM ---- negation: movq a, d (omitted when d = a), negq d (inegc: jo to the cold block)
5785 LET K6 = 1
5786 GOSUB 8302
5787 GOSUB 8219
5788 IF Z3$ = Z2$ THEN 5791
5789 LET X$ = "movq " & Z2$ & ", " & Z3$
5790 GOSUB 9010
5791 LET X$ = Q$(M(T5,1)) & " " & Z3$
5792 GOTO 5731
5793 REM ---- fneg / fabs: xorpd / andpd with the function's 16-byte constant (L-ah)
5794 LET K6 = 1
5795 GOSUB 8302
5796 GOSUB 8219
5797 IF Z3$ = Z2$ THEN 5800
5798 LET X$ = "movapd " & Z2$ & ", " & Z3$
5799 GOSUB 9010
5800 LET W6$ = "abs"
5801 IF POS(G5$, "n") = 0 THEN 5803
5802 LET W6$ = "neg"
5803 LET X$ = Q$(M(T5,1)) & " " & L9$ & W6$ & "(%rip), " & Z3$
5804 GOTO 5761
5805 REM ---- fsqrt
5806 LET K6 = 1
5807 GOSUB 8302
5808 GOSUB 8219
5809 LET X$ = "sqrtsd " & Z2$ & ", " & Z3$
5810 GOTO 5761
5811 REM ---- itof: xorpd d, d first, so that the conversion does not depend on d (L-ah)
5812 LET K6 = 1
5813 GOSUB 8302
5814 GOSUB 8219
5815 LET X$ = "xorpd " & Z3$ & ", " & Z3$
5816 GOSUB 9010
5817 LET X$ = "cvtsi2sdq " & Z2$ & ", " & Z3$
5818 GOTO 5761
5819 REM ---- imulh: a into %rax (omitted when spilled: it is there), imulq b (b's register, or
5820 REM %rcx when spilled: 8302 loads it there), the high half from %rdx (L-an)
5821 LET K6 = 1
5822 GOSUB 8302
5823 LET H5$ = Z2$
5824 LET H5 = W3
5825 LET K6 = 2
5826 GOSUB 8302
5827 LET H6$ = Z2$
5828 LET H6 = W3
5829 GOSUB 8219
5830 IF H5$ = "%rax" THEN 5843
5831 IF H5 = 0 THEN 5836
5832 LET Z2$ = H5$
5833 LET R6$ = "%rax"
5834 GOSUB 8547
5835 GOTO 5843
5836 LET X$ = "movq " & H5$ & ", %rax"
5837 GOSUB 9010
5843 LET X$ = "imulq " & H6$
5844 GOSUB 9010
5845 LET X$ = "movq %rdx, " & Z3$
5846 GOTO 5761
5847 REM ---- icmp fcmp bnot fnan: the comparison (testq for the constant 0); a fused one stops
5848 REM there (C5 K5$ for its consumer); else set<cc> %al (fcmp eq / ne: two sets) and movzbl
5849 LET K6 = 1
5850 GOSUB 8302
5851 LET H5$ = Z2$
5852 IF W4 >= 11 THEN 5882
5853 LET K6 = 2
5854 GOSUB 8302
5855 LET H6$ = Z2$
5856 LET Z$ = K1$
5857 GOSUB 8514
5858 IF W4 = 10 THEN 5868
5859 LET W5 = 1
5860 LET X$ = "cmpq " & H6$ & ", " & H5$
5861 IF H6$ <> "$0" THEN 5863
5862 LET X$ = "testq " & H5$ & ", " & H5$
5863 GOSUB 9010
5864 IF O(J,1) > 0 THEN 5900
5865 LET X$ = "set" & V$(I2,2) & " %al"
5866 GOSUB 9010
5867 GOTO 5894
5868 LET W5 = 2
5869 LET X$ = "ucomisd " & H5$ & ", " & H6$
5870 IF V$(I2,3) <> "ba" THEN 5872
5871 LET X$ = "ucomisd " & H6$ & ", " & H5$
5872 GOSUB 9010
5873 IF O(J,1) > 0 THEN 5900
5874 LET X$ = "set" & V$(I2,4) & " %al"
5875 GOSUB 9010
5876 IF V$(I2,5) = "-" THEN 5894
5877 LET X$ = "set" & V$(I2,5) & " %cl"
5878 GOSUB 9010
5879 LET X$ = V$(I2,6) & " %cl, %al"
5880 GOSUB 9010
5881 GOTO 5894
5882 IF W4 = 12 THEN 5890
5883 LET W5 = 3
5884 LET X$ = "testq " & H5$ & ", " & H5$
5885 GOSUB 9010
5886 IF O(J,1) > 0 THEN 5900
5887 LET X$ = "sete %al"
5888 GOSUB 9010
5889 GOTO 5894
5890 LET X$ = "ucomisd " & H5$ & ", " & H5$
5891 GOSUB 9010
5892 LET X$ = "setp %al"
5893 GOSUB 9010
5894 GOSUB 8219
5895 GOSUB 8239
5896 LET X$ = "movzbl %al, " & W6$
5897 GOSUB 9010
5898 GOSUB 8232
5899 GOTO 5290
5900 LET C5 = W5
5901 LET K5$ = K1$
5902 GOTO 5290
5903 REM ---- isel / psel after the flags (fused, or testq c, c with cc ne): d = a: cmov<not cc>
5904 REM b, d; else movq b, d (omitted when d = b), cmov<cc> a, d (L-an)
5905 GOSUB 5948
5906 LET K6 = 2
5907 GOSUB 8302
5908 LET H6$ = Z2$
5909 LET K6 = 3
5910 GOSUB 8302
5911 LET H7$ = Z2$
5912 GOSUB 8219
5913 IF Z3$ <> H6$ THEN 5916
5914 LET X$ = "cmov" & O5$ & "q " & H7$ & ", " & Z3$
5915 GOTO 5761
5916 IF Z3$ = H7$ THEN 5919
5917 LET X$ = "movq " & H7$ & ", " & Z3$
5918 GOSUB 9010
5919 LET X$ = "cmov" & W6$ & "q " & H6$ & ", " & Z3$
5920 GOTO 5761
5921 REM ---- fsel: d = a: j<cc> 1f, movapd b, d; else movapd b, d (omitted when d = b),
5922 REM j<not cc> 1f, movapd a, d; then 1:
5923 GOSUB 5948
5924 LET K6 = 2
5925 GOSUB 8302
5926 LET H6$ = Z2$
5927 LET K6 = 3
5928 GOSUB 8302
5929 LET H7$ = Z2$
5930 GOSUB 8219
5931 IF Z3$ <> H6$ THEN 5937
5932 LET X$ = "j" & W6$ & " 1f"
5933 GOSUB 9010
5934 LET X$ = "movapd " & H7$ & ", " & Z3$
5935 GOSUB 9010
5936 GOTO 5944
5937 IF Z3$ = H7$ THEN 5940
5938 LET X$ = "movapd " & H7$ & ", " & Z3$
5939 GOSUB 9010
5940 LET X$ = "j" & O5$ & " 1f"
5941 GOSUB 9010
5942 LET X$ = "movapd " & H6$ & ", " & Z3$
5943 GOSUB 9010
5944 LET X$ = "1:"
5945 GOSUB 9000
5946 GOSUB 8232
5947 GOTO 5290
5948 REM the condition of a selection: W6$ its cc, O5$ the inverse (L-as)
5949 IF O(J - 1,1) = 0 THEN 5961
5950 LET W6$ = "e"
5951 LET O5$ = "ne"
5952 IF C5 = 3 THEN 5960
5953 LET Z$ = K5$
5954 GOSUB 8514
5955 LET W6$ = V$(I2,2)
5956 LET O5$ = V$(I2,7)
5957 IF C5 = 1 THEN 5960
5958 LET W6$ = V$(I2,8)
5959 LET O5$ = V$(I2,9)
5960 RETURN
5961 LET K6 = 1
5962 GOSUB 8302
5963 LET X$ = "testq " & Z2$ & ", " & Z2$
5964 GOSUB 9010
5965 LET W6$ = "ne"
5966 LET O5$ = "e"
5967 RETURN
5968 REM ---- loads and stores: a spilled base in %rcx, a spilled idx in %rdx, the address (6870);
5969 REM a stored value as an immediate, or (spilled) loaded into %rax / %xmm14 after the address
5970 LET R0 = Q(B1)
5971 LET N5 = 2
5972 GOSUB 8200
5973 LET W7$ = Z2$
5974 IF B2 = 0 THEN 5979
5975 LET R0 = Q(B2)
5976 LET N5 = 3
5977 GOSUB 8200
5978 LET W8$ = Z2$
5979 GOSUB 6003
5980 IF W4 = 16 THEN 5987
5981 GOSUB 8219
5982 LET W6$ = Z3$
5983 IF POS(G5$, "z") = 0 THEN 5985
5984 GOSUB 8239
5985 LET X$ = Q$(M(T5,1)) & " " & M$ & ", " & W6$
5986 GOTO 5761
5987 LET K6 = 1
5988 GOSUB 8282
5989 IF W3 = 0 THEN 5993
5990 LET R0 = Q(1)
5991 GOSUB 8270
5992 GOTO 6000
5993 LET R0 = Q(1)
5994 LET N5 = 1
5995 GOSUB 8200
5996 IF POS(G5$, "z") = 0 THEN 6000
5997 LET Z2$ = "%al"
5998 IF D(Q(1),8) < 0 THEN 6000
5999 LET Z2$ = U$(D(Q(1),8),5)
6000 LET X$ = Q$(M(T5,1)) & " " & Z2$ & ", " & M$
6001 GOSUB 9010
6002 GOTO 5290
6003 REM M$ = off(base, idx, scale) when the scale is 1 2 4 8 (or there is no idx) and off fits
6004 REM 32 bits; else the address formed in %r11 (imulq, addq; movabsq $off, %rcx) (DESIGN 4.9.2)
6005 FOR I8 = 1 TO 4
6006 LET V(I8) = L(I8)
6007 NEXT I8
6008 GOSUB 8244
6009 LET O5$ = SEG$(Z2$, 2, LEN(Z2$))
6010 IF V9 = 0 THEN 6019
6011 IF B2 = 0 THEN 6015
6012 IF POS("|1|2|4|8|", "|" & STR$(U2) & "|") = 0 THEN 6019
6013 LET M$ = "(" & W7$ & ", " & W8$ & ", " & STR$(U2) & ")"
6014 GOTO 6016
6015 LET M$ = "(" & W7$ & ")"
6016 IF O1 = 0 THEN 6018
6017 LET M$ = O5$ & M$
6018 RETURN
6019 LET W5 = V9
6020 IF B2 = 0 THEN 6025
6021 LET X$ = "imulq $" & STR$(U2) & ", " & W8$ & ", %r11"
6022 GOSUB 9010
6023 LET X$ = "addq " & W7$ & ", %r11"
6024 GOTO 6026
6025 LET X$ = "movq " & W7$ & ", %r11"
6026 GOSUB 9010
6027 LET M$ = "(%r11)"
6028 IF O1 = 0 THEN 6018
6029 IF W5 = 0 THEN 6032
6030 LET X$ = "addq $" & O5$ & ", %r11"
6031 GOTO 9010
6032 LET X$ = "movabsq $" & O5$ & ", %rcx"
6033 GOSUB 9010
6034 LET X$ = "addq %rcx, %r11"
6035 GOTO 9010
6036 REM ---- chkb: an immediate index (0 <= idx < 2^31): cmpq $idx, ext, jbe; else cmpq ext, idx
6037 REM (ext may be an immediate), jae: unsigned, so idx < 0 fails too (DESIGN 4.9.2)
6038 LET K6 = 1
6039 GOSUB 8302
6040 LET H5$ = Z2$
6041 LET H5 = W3
6042 LET K6 = 2
6043 GOSUB 8302
6044 LET H6$ = Z2$
6045 LET X$ = "cmpq " & H6$ & ", " & H5$
6046 LET W6$ = "jae "
6047 IF H5 = 0 THEN 6050
6048 LET X$ = "cmpq " & H5$ & ", " & H6$
6049 LET W6$ = "jbe "
6050 GOSUB 9010
6051 LET X$ = W6$ & L9$ & "e" & STR$(J)
6052 GOSUB 9010
6053 GOTO 5290
6054 REM chkb's cold block: idx, dim and ext into the argument slots 0, 1, 2
6055 LET O6$ = "%rsp"
6056 LET K6 = 1
6057 LET Z6 = 0
6058 GOSUB 8520
6059 LET X$ = "movq $" & STR$(U0) & ", " & STR$(K(1)) & "(%rsp)"
6060 GOSUB 9010
6061 LET K6 = 2
6062 LET Z6 = 2 * K(1)
6063 GOSUB 8520
6064 RETURN
6065 REM ---- retain a: the count in %rcx; a static object (count 0) unchanged
6066 LET K6 = 1
6067 GOSUB 8302
6068 LET X$ = "movq (" & Z2$ & "), %rcx"
6069 GOSUB 9010
6070 LET X$ = "testq %rcx, %rcx"
6071 GOSUB 9010
6072 LET X$ = "je 1f"
6073 GOSUB 9010
6074 LET X$ = "incq %rcx"
6075 GOSUB 9010
6076 LET X$ = "movq %rcx, (" & Z2$ & ")"
6077 GOSUB 9010
6078 LET X$ = "1:"
6079 GOSUB 9000
6080 GOTO 5290
6081 REM ---- release a: the count in %rcx; at 0 the free path calls sea_free with the saves of
6082 REM DESIGN 4.9.2 Calls around it (nothing is written: Y8 = 0)
6083 LET K6 = 1
6084 GOSUB 8302
6085 LET H5$ = Z2$
6086 LET X$ = "movq (" & H5$ & "), %rcx"
6087 GOSUB 9010
6088 LET X$ = "testq %rcx, %rcx"
6089 GOSUB 9010
6090 LET X$ = "je 1f"
6091 GOSUB 9010
6092 LET X$ = "decq %rcx"
6093 GOSUB 9010
6094 LET X$ = "movq %rcx, (" & H5$ & ")"
6095 GOSUB 9010
6096 LET X$ = "jne 1f"
6097 GOSUB 9010
6098 LET Y8 = 0
6099 GOSUB 8422
6100 IF H5$ = "%rdi" THEN 6103
6101 LET X$ = "movq " & H5$ & ", %rdi"
6102 GOSUB 9010
6103 LET X$ = "call " & Y$(G(J),2)
6104 GOSUB 9010
6105 GOSUB 8431
6106 LET X$ = "1:"
6107 GOSUB 9000
6108 GOTO 5290
6109 REM ---- la: the data label, rip-relative
6110 GOSUB 8219
6111 LET X$ = "leaq .Ld" & STR$(H0) & "(%rip), " & Z3$
6112 GOTO 5761
6113 REM ---- mov: nothing between equal locations; an immediate (32 bits); a spilled side
6114 REM loaded or stored directly, both spilled through %rax / %xmm14
6115 LET K6 = 1
6116 GOSUB 8282
6117 IF W3 = 0 THEN 6123
6118 LET R0 = Q(1)
6119 GOSUB 8270
6120 GOSUB 8219
6121 LET X$ = "movq " & Z2$ & ", " & Z3$
6122 GOTO 5761
6123 LET W1 = D(Q(1),8)
6124 LET E8 = D(D1,8)
6125 IF W1 = 0 THEN 8470
6126 IF E8 = 0 THEN 8470
6127 IF W1 = E8 THEN 5290
6128 IF E8 < 0 THEN 6141
6129 IF W1 < 0 THEN 6135
6130 LET X$ = "movq " & U$(W1,3) & ", " & U$(E8,3)
6131 IF D2 <> 2 THEN 6133
6132 LET X$ = "movapd " & U$(W1,3) & ", " & U$(E8,3)
6133 GOSUB 9010
6134 GOTO 5290
6135 LET Z1$ = "ldr"
6136 LET Z2$ = U$(E8,3)
6137 LET Z3 = A5 + 8 * (-W1 - 1)
6138 LET Z4$ = "%rsp"
6139 GOSUB 9020
6140 GOTO 5290
6141 IF W1 > 0 THEN 6150
6142 LET Z1$ = "ldr"
6143 LET Z2$ = U$(1,3)
6144 IF D2 <> 2 THEN 6146
6145 LET Z2$ = U$(31,3)
6146 LET Z3 = A5 + 8 * (-W1 - 1)
6147 LET Z4$ = "%rsp"
6148 GOSUB 9020
6149 GOTO 6151
6150 LET Z2$ = U$(W1,3)
6151 LET Z1$ = "str"
6152 LET Z3 = A5 + 8 * (-E8 - 1)
6153 LET Z4$ = "%rsp"
6154 GOSUB 9020
6155 GOTO 5290
7000 REM ---- data: str lab v -- a static string object (rt.inc SEA_STR_*) ---------------------
7005 GOSUB 7900
7010 GOSUB 9400
7015 IF H0 <> D8 + 1 THEN 9990
7020 LET D8 = H0
7025 CALL "io_unesc": G$(3), 0, R9$, T
7030 IF T <> 0 THEN 9990
7035 LET Z9$ = ".Ld" & STR$(H0)
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
7185 LET X$ = ".Ld" & STR$(V4) & ":"
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
7240 LET X$ = ".Ld" & STR$(V4) & "_t" & STR$(I3) & ":"
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
7402 LET X$ = ".Ld" & STR$(H0) & ":"
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
7455 REM ---- data: slay lab size n, then n soff -- a struct layout descriptor (rt.inc SEA_SL_*):
7456 REM offsets strictly ascending multiples of ESIZE_PTR, each <= size - ESIZE_PTR (DESIGN 3.6.5)
7457 GOSUB 7900
7458 GOSUB 9400
7459 IF H0 <> D8 + 1 THEN 9990
7460 LET D8 = H0
7461 LET Y8 = U(2)
7462 LET Y7 = U(3)
7463 LET X$ = ".p2align 3"
7464 GOSUB 9010
7465 LET X$ = ".Ld" & STR$(H0) & ":"
7466 GOSUB 9000
7467 LET Z7 = 0
7468 LET Z6 = K(47)
7469 LET Z5 = Y8
7470 GOSUB 7493
7471 LET Z6 = K(48)
7472 LET Z5 = Y7
7473 GOSUB 7493
7474 LET Y6 = -1
7475 FOR I3 = 1 TO Y7
7476 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7477 CALL "io_split": L$, G$(), 300, C0
7478 IF C0 < 1 THEN 9990
7479 IF G$(1) <> "soff" THEN 9990
7480 LET Z$ = G$(1)
7481 GOSUB 9350
7482 GOSUB 9400
7483 IF U(1) <= Y6 THEN 9990
7484 IF U(1) - INT(U(1) / K(50)) * K(50) <> 0 THEN 9990
7485 IF U(1) > Y8 - K(50) THEN 9990
7486 LET Y6 = U(1)
7487 LET Z6 = K(49) + 8 * (I3 - 1)
7488 LET Z5 = Y6
7489 GOSUB 7493
7490 NEXT I3
7491 CALL "io_read": 1, L$, L0, P$, E(), E$(), E0
7492 GOTO 1250
7493 REM ---- .quad Z5 at offset Z6 (the gap before it .zero, 7600) ----------------------------
7494 GOSUB 7600
7495 GOSUB 9050
7496 LET X$ = ".quad " & Z0$
7497 GOSUB 9010
7498 LET Z7 = Z7 + 8
7499 RETURN
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
7600 REM ---- a field at offset Z6 of a record whose next free byte is Z7: .zero the gap -------
7602 LET M$ = "a rt.inc layout whose fields are not in ascending order"
7604 IF Z6 < Z7 THEN 9975
7606 IF Z6 = Z7 THEN 7614
7608 LET X$ = ".zero " & STR$(Z6 - Z7)
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
7772 LET X$ = ".quad .Ld" & STR$(V4) & "_t" & STR$(I3)
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
7908 LET X$ = ".section .data.rel.ro," & Q9$ & "aw" & Q9$ & ",@progbits"
7910 GOSUB 9010
7914 RETURN
7960 REM ---- fconv: class p exactly for %s, i or f for the numeric conversions (DESIGN 3.6.5) --
7962 IF G$(5) <> "s" THEN 7968
7964 IF G$(6) <> "p" THEN 9990
7966 RETURN
7968 IF G$(6) = "p" THEN 9990
7970 RETURN
8000 REM ---- #end: the #file strings, sea_sites (rt.inc SEA_SITE_*), the non-executable stack note
8005 CALL "io_end": 1, P$, E(), E$(), E0
8010 IF M9 <> 1 THEN 9990
8012 IF L8 > D8 THEN 9990
8015 GOSUB 7900
8020 FOR I4 = 1 TO N1
8025 LET Z9$ = ".Lsf" & STR$(I4 - 1)
8030 LET R9$ = H$(I4)
8035 GOSUB 7500
8040 NEXT I4
8045 LET X$ = ".globl sea_sites"
8047 GOSUB 9010
8049 LET X$ = ".type sea_sites, @object"
8050 GOSUB 9010
8055 LET X$ = ".p2align 3"
8060 GOSUB 9010
8065 LET X$ = "sea_sites:"
8070 GOSUB 9000
8075 FOR I4 = 1 TO X9
8080 LET Z7 = 0
8085 LET Z6 = K(31)
8090 GOSUB 7600
8095 LET X$ = ".quad .Lsf" & STR$(S(I4,1))
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
8146 LET X$ = ".section .note.GNU-stack," & Q9$ & Q9$ & ",@progbits"
8148 GOSUB 9010
8150 GOTO 99999
8200 REM ---- Z2$ = register R0 read as operand N5 (1-3) of its class: its register, or its spill
8201 REM slot loaded into scratch register N5 (%rax %rcx %rdx; %xmm14 %xmm15), DESIGN 4.9.2
8202 LET W1 = D(R0,8)
8203 IF W1 > 0 THEN 8211
8204 IF W1 = 0 THEN 8470
8205 GOSUB 8213
8206 LET Z1$ = "ldr"
8207 LET Z3 = A5 + 8 * (-W1 - 1)
8208 LET Z4$ = "%rsp"
8209 GOSUB 9020
8210 RETURN
8211 LET Z2$ = U$(W1,3)
8212 RETURN
8213 IF D(R0,0) = 2 THEN 8216
8214 LET Z2$ = U$(N5,3)
8215 RETURN
8216 IF N5 > 2 THEN 8470
8217 LET Z2$ = U$(30 + N5,3)
8218 RETURN
8219 REM ---- Z3$ = the destination D1: its register, or scratch 1 of its class with Z9 = its
8220 REM spill slot's offset (else Z9 = -1); 8270 then stores the scratch register
8221 LET Z9 = -1
8222 LET W1 = D(D1,8)
8223 IF W1 > 0 THEN 8230
8224 IF W1 = 0 THEN 8470
8225 LET Z9 = A5 + 8 * (-W1 - 1)
8226 LET Z3$ = U$(1,3)
8227 IF D(D1,0) <> 2 THEN 8229
8228 LET Z3$ = U$(31,3)
8229 RETURN
8230 LET Z3$ = U$(W1,3)
8231 RETURN
8232 IF Z9 < 0 THEN 8238
8233 LET Z1$ = "str"
8234 LET Z2$ = Z3$
8235 LET Z3 = Z9
8236 LET Z4$ = "%rsp"
8237 GOSUB 9020
8238 RETURN
8239 REM ---- W6$ = the 32-bit name of the destination of 8250 (for movzbl)
8240 LET W6$ = "%eax"
8241 IF Z9 >= 0 THEN 8243
8242 LET W6$ = U$(D(D1,8),4)
8243 RETURN
8244 REM ---- the i64 of the limbs V(1..4): V9 = 1 and W9 = v if -2^31 <= v < 2^31 (Z2$ = "$"
8245 REM and its decimal text); else V9 = 0 and Z2$ = "$0x" and 16 hex digits (movabsq only)
8246 LET V9 = 0
8247 IF V(1) + V(2) <> 0 THEN 8251
8248 IF V(3) >= 32768 THEN 8267
8249 LET W9 = V(3) * 65536 + V(4)
8250 GOTO 8255
8251 IF V(1) <> 65535 THEN 8267
8252 IF V(2) <> 65535 THEN 8267
8253 IF V(3) < 32768 THEN 8267
8254 LET W9 = V(3) * 65536 + V(4) - 65536 * 65536
8255 LET V9 = 1
8256 LET Z2$ = "$" & STR$(W9)
8257 IF ABS(W9) <= 999999999 THEN 8269
8258 REM Baysick's STR$ is exact only below 10^9: the digits in two parts
8259 LET W8 = ABS(W9)
8260 LET W7 = INT(W8 / 1E9)
8261 LET Z$ = "000000000" & STR$(W8 - W7 * 1E9)
8262 LET Z2$ = STR$(W7) & SEG$(Z$, LEN(Z$) - 8, LEN(Z$))
8263 IF W9 >= 0 THEN 8265
8264 LET Z2$ = "-" & Z2$
8265 LET Z2$ = "$" & Z2$
8266 RETURN
8267 GOSUB 9060
8268 LET Z2$ = "$" & Z0$
8269 RETURN
8270 REM ---- W2 = 1 if register R0 is an immediate candidate: written once, by an li (DESIGN
8271 REM 4.9.2 Immediates); then its value as 8300 gives it
8272 LET W2 = 0
8273 IF R0 < 1 THEN 8281
8274 IF T(R0,1) <> 1 THEN 8281
8275 IF T(R0,2) = 0 THEN 8281
8276 LET W2 = 1
8277 FOR I8 = 1 TO 4
8278 LET V(I8) = T(R0,4 + I8)
8279 NEXT I8
8280 GOSUB 8244
8281 RETURN
8282 REM ---- W3 = 1 if the read operand Q(K6) of record J is written as an immediate: its context
8283 REM G6 (8800) admits the candidate's value (0 any, 1 32 bits, 2 a shift 0-63, 3 a chkb index
8284 REM 0 <= v < 2^31, 4 a byte, 9 none)
8285 LET W3 = 0
8286 GOSUB 8552
8287 IF G6 = 9 THEN 8301
8288 LET R0 = Q(K6)
8289 GOSUB 8645
8290 IF W2 = 0 THEN 8301
8291 IF G6 = 0 THEN 8300
8292 IF V9 = 0 THEN 8301
8293 IF G6 = 1 THEN 8300
8294 IF W9 < 0 THEN 8301
8295 IF G6 = 3 THEN 8300
8296 IF G6 = 2 THEN 8299
8297 IF W9 > 255 THEN 8301
8298 GOTO 8300
8299 IF W9 > 63 THEN 8301
8300 LET W3 = 1
8301 RETURN
8302 REM ---- Z2$ = the operand Q(K6): its immediate (W3 = 1), or (8200) its register, a spilled
8303 REM one in the scratch register of its position among the operands of its class
8304 GOSUB 8282
8305 IF W3 = 0 THEN 8309
8306 LET R0 = Q(K6)
8307 GOSUB 8645
8308 RETURN
8309 LET N5 = 0
8310 FOR I7 = 1 TO K6
8311 IF P(I7) = 2 THEN 8315
8312 IF P(K6) = 2 THEN 8317
8313 LET N5 = N5 + 1
8314 GOTO 8317
8315 IF P(K6) <> 2 THEN 8317
8316 LET N5 = N5 + 1
8317 NEXT I7
8318 LET R0 = Q(K6)
8319 GOSUB 8200
8320 RETURN
8321 REM ---- E7 = the parallel-move source of register R0: an immediate (tag 3000 + k, J$(k) its
8322 REM text), else its location (DESIGN 4.9.2 Moves)
8323 GOSUB 8270
8324 IF W2 = 0 THEN 8330
8325 LET G7 = G7 + 1
8326 IF G7 > 300 THEN 8470
8327 LET J$(G7) = Z2$
8328 LET E7 = 3000 + G7
8329 RETURN
8330 LET E7 = D(R0,8)
8331 IF E7 = 0 THEN 8470
8332 RETURN
8333 REM ---- lists the move E7 -> E8 of class E6
8334 IF E8 = 0 THEN 8470
8335 CALL "ra_mv": D(), E7, E8, E6, T
8336 IF T <> 0 THEN 8470
8337 RETURN
8338 REM ---- sequences the listed moves (ralloc: three steps) and writes each step
8339 CALL "ra_pm": D(), N6
8340 FOR I4 = 1 TO N6
8341 CALL "ra_st": D(), I4, E7, E8, E6, E5
8342 GOSUB 8345
8343 NEXT I4
8344 RETURN
8345 REM a step E7 -> E8 (class E6). The source O3$, of kind W5: 1 a register (0: the cycle
8346 REM scratch %r11 / %xmm15), 2 a frame slot at W6, 3 a 32-bit immediate, 4 a 64-bit one, 5 an
8347 REM address (leaq), 6 another memory operand; tags J$(k) start with $ & @. A memory
8348 REM destination (spill, stack argument, results area) is stored from a register source, any
8349 REM other source through %r11 (an f value as its bits)
8350 LET W5 = 1
8351 IF E7 = 0 THEN 8365
8352 IF E7 < 0 THEN 8371
8353 IF E7 <= 64 THEN 8369
8354 IF E7 < 3000 THEN 8374
8355 LET O3$ = J$(E7 - 3000)
8356 LET W5 = 3
8357 IF SEG$(O3$, 1, 3) <> "$0x" THEN 8359
8358 LET W5 = 4
8359 IF SEG$(O3$, 1, 1) = "$" THEN 8376
8360 LET W5 = 5
8361 IF SEG$(O3$, 1, 1) = "&" THEN 8363
8362 LET W5 = 6
8363 LET O3$ = SEG$(O3$, 2, LEN(O3$))
8364 GOTO 8376
8365 LET O3$ = "%r11"
8366 IF E6 <> 2 THEN 8376
8367 LET O3$ = "%xmm15"
8368 GOTO 8376
8369 LET O3$ = U$(E7,3)
8370 GOTO 8376
8371 LET W5 = 2
8372 LET W6 = A5 + 8 * (-E7 - 1)
8373 GOTO 8376
8374 LET W5 = 2
8375 LET W6 = A1 + 8 * (E7 - 2000)
8376 IF E8 = 0 THEN 8386
8377 IF E8 < 0 THEN 8384
8378 IF E8 <= 64 THEN 8390
8379 IF E8 < 2000 THEN 8382
8380 LET W7 = A1 + 8 * (E8 - 2000)
8381 GOTO 8413
8382 LET W7 = 8 * (E8 - 1000)
8383 GOTO 8413
8384 LET W7 = A5 + 8 * (-E8 - 1)
8385 GOTO 8413
8386 LET O4$ = "%r11"
8387 IF E6 <> 2 THEN 8391
8388 LET O4$ = "%xmm15"
8389 GOTO 8391
8390 LET O4$ = U$(E8,3)
8391 ON W5 GOTO 8392,8397,8402,8404,8406,8408
8392 IF O3$ = O4$ THEN 8412
8393 LET X$ = "movq " & O3$ & ", " & O4$
8394 IF E6 <> 2 THEN 9010
8395 LET X$ = "movapd " & O3$ & ", " & O4$
8396 GOTO 9010
8397 LET Z1$ = "ldr"
8398 LET Z2$ = O4$
8399 LET Z3 = W6
8400 LET Z4$ = "%rsp"
8401 GOTO 9020
8402 LET X$ = "movq " & O3$ & ", " & O4$
8403 GOTO 9010
8404 LET X$ = "movabsq " & O3$ & ", " & O4$
8405 GOTO 9010
8406 LET X$ = "leaq " & O3$ & ", " & O4$
8407 GOTO 9010
8408 LET X$ = "movq " & O3$ & ", " & O4$
8409 IF SEG$(O4$, 1, 4) <> "%xmm" THEN 9010
8410 LET X$ = "movsd " & O3$ & ", " & O4$
8411 GOTO 9010
8412 RETURN
8413 IF W5 = 1 THEN 8417
8414 LET O4$ = "%r11"
8415 GOSUB 8391
8416 LET O3$ = "%r11"
8417 LET Z1$ = "str"
8418 LET Z2$ = O3$
8419 LET Z3 = W7
8420 LET Z4$ = "%rsp"
8421 GOTO 9020
8422 REM ---- the saves before the call / rcall / free path of record J: every interval in a
8423 REM caller-saved register crossing J (ralloc's list), but those record J writes (its results
8424 REM G$(Y4 ...), Y8 of them), stored to its save slot; 8530 loads them back (DESIGN 4.9.2)
8425 REM (ra_sv T is not used: an interval record J writes may have no save slot; it is skipped,
8426 REM and any other without one is caught below)
8427 CALL "ra_sv": D(), J, N8, T
8428 LET Z1$ = "str"
8429 GOSUB 8434
8430 RETURN
8431 LET Z1$ = "ldr"
8432 GOSUB 8434
8433 RETURN
8434 FOR I3 = 1 TO N8
8435 CALL "ra_svi": D(), I3, W5, W6, W7
8436 FOR K4 = 1 TO Y8
8437 IF VAL(SEG$(G$(Y4 + K4 - 1), 2, LEN(G$(Y4 + K4 - 1)))) = W7 THEN 8444
8438 NEXT K4
8439 IF W6 = 0 THEN 8470
8440 LET Z2$ = U$(W5,3)
8441 LET Z3 = A5 + 8 * (W6 - 1)
8442 LET Z4$ = "%rsp"
8443 GOSUB 9020
8444 NEXT I3
8445 RETURN
8446 REM ---- Z2$ = location W1: a register, or a spill slot loaded into %rax (Z9 its offset,
8447 REM else -1; 8570 stores %rax back); 8565: loaded into scratch N5 instead, never stored
8448 LET Z9 = -1
8449 IF W1 > 0 THEN 8461
8450 IF W1 = 0 THEN 8470
8451 LET Z9 = A5 + 8 * (-W1 - 1)
8452 LET Z2$ = "%rax"
8453 GOTO 8457
8454 IF W1 > 0 THEN 8461
8455 IF W1 = 0 THEN 8470
8456 LET Z2$ = U$(N5,3)
8457 LET Z1$ = "ldr"
8458 LET Z3 = A5 + 8 * (-W1 - 1)
8459 LET Z4$ = "%rsp"
8460 GOTO 9020
8461 LET Z2$ = U$(W1,3)
8462 RETURN
8463 IF Z9 < 0 THEN 8469
8464 LET Z1$ = "str"
8465 LET Z2$ = "%rax"
8466 LET Z3 = Z9
8467 LET Z4$ = "%rsp"
8468 GOSUB 9020
8469 RETURN
8470 LET M$ = "allocation state inconsistent at record " & STR$(J)
8471 GOTO 9975
8472 REM ---- the branch to T6$ when the condition of record J holds (X7 = 1) or fails (X7 = 0):
8473 REM a fused comparison's flags (L-as; fcmp eq / ne as jp with je / jne), else testq c, c
8474 IF O(J - 1,1) > 0 THEN 8483
8475 LET K6 = 1
8476 GOSUB 8302
8477 LET X$ = "testq " & Z2$ & ", " & Z2$
8478 GOSUB 9010
8479 LET X$ = "je " & T6$
8480 IF X7 = 0 THEN 9010
8481 LET X$ = "jne " & T6$
8482 GOTO 9010
8483 IF C5 <> 3 THEN 8488
8484 LET X$ = "je " & T6$
8485 IF X7 = 1 THEN 9010
8486 LET X$ = "jne " & T6$
8487 GOTO 9010
8488 LET Z$ = K5$
8489 GOSUB 8514
8490 IF C5 = 1 THEN 8510
8491 IF V$(I2,8) <> "-" THEN 8506
8492 LET W5 = X7
8493 IF K5$ <> "ne" THEN 8495
8494 LET W5 = 1 - X7
8495 IF W5 = 0 THEN 8502
8496 LET X$ = "jp 1f"
8497 GOSUB 9010
8498 LET X$ = "je " & T6$
8499 GOSUB 9010
8500 LET X$ = "1:"
8501 GOTO 9000
8502 LET X$ = "jp " & T6$
8503 GOSUB 9010
8504 LET X$ = "jne " & T6$
8505 GOTO 9010
8506 LET X$ = "j" & V$(I2,8) & " " & T6$
8507 IF X7 = 1 THEN 9010
8508 LET X$ = "j" & V$(I2,9) & " " & T6$
8509 GOTO 9010
8510 LET X$ = "j" & V$(I2,2) & " " & T6$
8511 IF X7 = 1 THEN 9010
8512 LET X$ = "j" & V$(I2,7) & " " & T6$
8513 GOTO 9010
8514 REM ---- I2 = the row of cc Z$ in V$
8515 FOR I2 = 1 TO V8
8516 IF V$(I2,1) = Z$ THEN 8519
8517 NEXT I2
8518 GOTO 9990
8519 RETURN
8520 REM ---- the operand Q(K6) stored to Z6(O6$): an immediate (through %rax when wider than 32
8521 REM bits), a register, or a spill slot through %rax (cold blocks, a ret's memory results)
8522 GOSUB 8282
8523 IF W3 = 0 THEN 8533
8524 LET R0 = Q(K6)
8525 GOSUB 8270
8526 IF V9 = 0 THEN 8529
8527 LET X$ = "movq " & Z2$ & ", " & STR$(Z6) & "(" & O6$ & ")"
8528 GOTO 9010
8529 LET R6$ = "%rax"
8530 GOSUB 8547
8531 LET Z2$ = "%rax"
8532 GOTO 8543
8533 LET W1 = D(Q(K6),8)
8534 IF W1 = 0 THEN 8470
8535 IF W1 < 0 THEN 8538
8536 LET Z2$ = U$(W1,3)
8537 GOTO 8543
8538 LET Z1$ = "ldr"
8539 LET Z2$ = "%rax"
8540 LET Z3 = A5 + 8 * (-W1 - 1)
8541 LET Z4$ = "%rsp"
8542 GOSUB 9020
8543 LET Z1$ = "str"
8544 LET Z3 = Z6
8545 LET Z4$ = O6$
8546 GOTO 9020
8547 REM ---- the immediate Z2$ into register R6$: movq (32 bits) or movabsq
8548 LET X$ = "movq " & Z2$ & ", " & R6$
8549 IF SEG$(Z2$, 1, 3) <> "$0x" THEN 9010
8550 LET X$ = "movabsq " & Z2$ & ", " & R6$
8551 GOTO 9010
8552 REM ---- G6 = the immediate context of operand K6 of record J (see 8355): moves take any
8553 REM value (call, rcall, ret, chk arguments, loop start and last, staged operands, imulh a); the
8554 REM loop step, binary operations, icmp, sti, mov 32 bits; shifts 0-63; chkb; stb a byte
8555 LET G6 = 9
8556 IF Y0 = 0 THEN 8569
8557 IF Y0 = 8 THEN 8565
8558 IF Y0 = 21 THEN 8563
8559 IF Y0 < 18 THEN 8562
8560 IF Y0 > 20 THEN 8562
8561 LET G6 = 0
8562 RETURN
8563 IF K6 > 1 THEN 8561
8564 RETURN
8565 IF K6 = 1 THEN 8562
8566 IF K6 < 4 THEN 8561
8567 LET G6 = 1
8568 RETURN
8569 IF W4 = 0 THEN 8561
8570 IF W4 = 8 THEN 8635
8571 IF W4 = 1 THEN 8578
8572 IF W4 = 3 THEN 8590
8573 IF W4 = 9 THEN 8593
8574 IF W4 = 16 THEN 8598
8575 IF W4 = 17 THEN 8603
8576 IF W4 = 21 THEN 8593
8577 RETURN
8578 IF K6 = 2 THEN 8587
8579 IF POS(G5$, "s") = 0 THEN 8562
8580 REM the first operand only when the second is no immediate
8581 LET R0 = Q(2)
8582 GOSUB 8270
8583 IF W2 = 0 THEN 8588
8584 IF V9 = 0 THEN 8588
8585 IF POS(G5$, "i") = 0 THEN 8588
8586 RETURN
8587 IF POS(G5$, "i") = 0 THEN 8562
8588 LET G6 = 1
8589 RETURN
8590 IF K6 <> 2 THEN 8562
8591 LET G6 = 2
8592 RETURN
8593 IF W4 = 21 THEN 8596
8594 IF K6 = 2 THEN 8588
8595 RETURN
8596 IF K6 = 1 THEN 8588
8597 RETURN
8598 IF K6 > 1 THEN 8562
8599 IF POS(G5$, "i") > 0 THEN 8588
8600 IF POS(G5$, "b") = 0 THEN 8562
8601 LET G6 = 4
8602 RETURN
8603 IF K6 = 2 THEN 8606
8604 LET G6 = 3
8605 RETURN
8606 LET R0 = Q(1)
8607 GOSUB 8270
8608 IF W2 = 0 THEN 8588
8609 IF V9 = 0 THEN 8588
8610 IF W9 < 0 THEN 8588
8611 RETURN
8612 IF Z1$ = "str" THEN 8621
8613 IF R7$ <> "movq" THEN 8621
8614 REM a general load: the offset into the destination itself
8615 LET Z5 = Z3
8616 GOSUB 9050
8617 LET X$ = "movabsq $" & Z0$ & ", " & Z2$
8618 GOSUB 9010
8619 LET R8$ = "(" & Z4$ & "," & Z2$ & ")"
8620 GOTO 9029
8621 REM else through %rax (%rcx when Z2$ is %rax), pushed and popped (the offset 8 more)
8622 LET R5$ = "%rax"
8623 IF Z2$ <> "%rax" THEN 8625
8624 LET R5$ = "%rcx"
8625 LET X$ = "pushq " & R5$
8626 GOSUB 9010
8627 LET Z5 = Z3 + 8
8628 GOSUB 9050
8629 LET X$ = "movabsq $" & Z0$ & ", " & R5$
8630 GOSUB 9010
8631 LET R8$ = "(" & Z4$ & "," & R5$ & ")"
8632 GOSUB 9029
8633 LET X$ = "popq " & R5$
8634 GOTO 9010
8635 REM imulh: a takes any value (moved into %rax); b none, the one-operand imulq has no
8636 REM immediate form, so b is in its register (DESIGN 4.9.2 Immediates, Templates)
8637 IF K6 = 1 THEN 8561
8638 RETURN
8640 REM ---- (4772) a first write by a mov: its source in T(r,0), for a loop's step (8655)
8641 IF Y0 <> 0 THEN 4780
8642 IF W4 <> 21 THEN 4780
8643 LET T(R0,0) = Q(1)
8644 GOTO 4780
8645 REM ---- W2 as 8270 for register R0, operand K6 of record J: a loop's step through 8655
8646 IF Y0 <> 8 THEN 8270
8647 IF K6 <> 4 THEN 8270
8655 REM ---- W2 as 8270 for the step R0 of a loop, which is also a constant when its only
8656 REM definition is a mov of an li register (DESIGN 4.9.2 Loop closing, Decision 76): R0 then
8657 REM that li register, its value as 8270 gives it
8658 GOSUB 8270
8659 IF W2 = 1 THEN 8664
8660 IF T(R0,1) <> 1 THEN 8664
8661 IF T(R0,0) < 1 THEN 8664
8662 LET R0 = T(R0,0)
8663 GOTO 8270
8664 RETURN
8665 REM ---- (4566) d = a op b not commuting: the hint a; d avoids b's register when b is a
8666 REM register other than a (DESIGN 4.9.2 The scan, Decision 77)
8667 CALL "ra_hint": D(), J, D1, Q(1), 0
8668 IF Q(2) = Q(1) THEN 4601
8669 CALL "ra_avoid": D(), J, D1, Q(2)
8670 GOTO 4601
9000 REM ---- emit X$; 9010: indented ---------------------------------------------------------------
9004 PRINT #2, X$
9005 RETURN
9010 LET X$ = "    " & X$
9012 GOTO 9004
9020 REM ---- Z1$ (ldr: load, str: store) of register Z2$ and the 8-byte slot Z3(Z4$): movq, or
9021 REM movsd for an xmm register; an offset of 2^31 or more (%rsp only) through a register
9022 LET R7$ = "movq"
9023 IF SEG$(Z2$, 1, 4) <> "%xmm" THEN 9025
9024 LET R7$ = "movsd"
9025 IF Z3 >= 2 ^ 31 THEN 8612
9026 LET Z5 = Z3
9027 GOSUB 9050
9028 LET R8$ = Z0$ & "(" & Z4$ & ")"
9029 IF Z1$ = "str" THEN 9032
9030 LET X$ = R7$ & " " & R8$ & ", " & Z2$
9031 GOTO 9010
9032 LET X$ = R7$ & " " & Z2$ & ", " & R8$
9033 GOTO 9010
9050 REM ---- Z0$ = the text of Z5 (an integer 0 <= Z5 < 2^53): decimal up to 10^9 - 1, else 0x
9051 REM and 16 hex digits (Baysick's STR$ is exact only below 10^9); 9060: from the limbs V()
9052 LET Z0$ = STR$(Z5)
9053 IF Z5 <= 999999999 THEN 9078
9054 LET V5 = Z5
9055 FOR I8 = 4 TO 1 STEP -1
9056 LET V(I8) = V5 - INT(V5 / 65536) * 65536
9057 LET V5 = INT(V5 / 65536)
9058 NEXT I8
9060 LET Z0$ = "0x"
9062 FOR I8 = 1 TO 4
9064 FOR V7 = 3 TO 0 STEP -1
9066 LET V6 = INT(V(I8) / 16 ^ V7) - 16 * INT(V(I8) / 16 ^ (V7 + 1))
9068 LET Z0$ = Z0$ & SEG$("0123456789ABCDEF", V6 + 1, V6 + 1)
9070 NEXT V7
9072 NEXT I8
9078 RETURN
9150 REM ---- one template line Z$: placeholders @x replaced (AT&T keeps its $ immediates) ------
9152 LET R$ = ""
9154 LET Y1 = 1
9156 LET Y2 = POS(Z$, "@", Y1)
9158 IF Y2 = 0 THEN 9170
9160 LET R$ = R$ & SEG$(Z$, Y1, Y2 - 1)
9162 LET Y3$ = SEG$(Z$, Y2 + 1, Y2 + 1)
9164 LET Y1 = Y2 + 2
9166 GOSUB 9200
9168 GOTO 9156
9170 LET R$ = R$ & SEG$(Z$, Y1, LEN(Z$))
9178 LET X$ = R$
9180 IF SEG$(R$, LEN(R$), LEN(R$)) = ":" THEN 9000
9182 GOTO 9010
9200 REM ---- the value of placeholder Y3$, appended to R$: @C @D the cold labels, @0-@9 slot k
9201 IF Y3$ <> "C" THEN 9204
9202 LET R$ = R$ & L9$ & "e" & STR$(J)
9203 RETURN
9204 IF Y3$ <> "D" THEN 9207
9205 LET R$ = R$ & L9$ & "f" & STR$(J)
9206 RETURN
9207 LET Y5 = POS("0123456789", Y3$)
9208 LET M$ = "unknown template placeholder @" & Y3$
9209 IF Y5 = 0 THEN 9975
9210 LET R$ = R$ & STR$((Y5 - 1) * K(1))
9211 RETURN
9300 REM ---- X0 = the index of site X1:X2 in sea_sites; added in mode 1 (first occurrence) ----
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
9375 REM ---- cold tail: sea_err(Z8, site X0, slots at %rsp) ------------------------------------
9377 LET X$ = "movl $" & STR$(Z8) & ", %edi"
9379 GOSUB 9010
9383 LET X$ = "movq $" & STR$(X0) & ", %rsi"
9385 GOSUB 9010
9389 LET X$ = "movq %rsp, %rdx"
9391 GOSUB 9010
9393 LET X$ = "call sea_err"
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
9533 IF R$(I0) <> "mcopy" THEN 9690
9534 GOTO 9536
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
9572 IF D(R0,0) = 0 THEN 9577
9574 IF D(R0,0) <> R1 THEN 9990
9576 RETURN
9577 IF R0 <> M0 + 1 THEN 9990
9578 LET D(R0,0) = R1
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
9630 REM ---- Z8 = the results of classes Z6$ beyond the U9 integer and 8 xmm result registers ----
9632 LET Z8 = 0
9634 LET Y1 = 0
9636 LET Y2 = 0
9638 FOR I1 = 1 TO LEN(Z6$)
9640 IF SEG$(Z6$, I1, I1) = "f" THEN 9648
9642 LET Y1 = Y1 + 1
9644 IF Y1 <= U9 THEN 9654
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
9688 REM ---- a destination d (not mcopy's: its d is an address it reads, DESIGN 3.6.4) --------
9690 LET D1 = R0
9691 LET D2 = R1
9692 GOTO 9547
9960 CALL "dg_compile": P$, H$(), N1, F1, F2, F3, "TOO_LARGE", A$(), 1, E(), E$(), E0
9970 CALL "dg_boot": P$
9975 CALL "dg_bug": P$, M$
9980 CALL "dg_internal": P$, "BAD_HEADER", E(), E$(), E0
9990 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
