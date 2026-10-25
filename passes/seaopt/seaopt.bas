100 REM ====================================================================================
105 REM seaopt -- pass 3b: sea.lir1 -> sea.lir2 (DESIGN 2.1, 3.6, 3.6.5). Lines 100-59999.
110 REM Built as DESIGN 2.6.3 says: this file, io diag tables and the shared main-program part lirrw,
115 REM the DATA blocks errors exits consts entries records, then 99999 END (passes/seaopt/build.list).
120 REM
125 REM PHASES 1-4 (DESIGN 3.6.5, 8): reading, validating and writing LIR is lirrw's (passes/lib/lirrw.bas,
130 REM lines 69000-81999; its contract: passes/lib/API.md). It reads sea.lir1 against passes.txt (set L),
135 REM enforces the LIR capacity limits, copies the header and the data records, and writes each function
140 REM from the tables, renumbered. A malformed input is an internal error (status 11, 2.2): exactly one
145 REM line, "seaopt: " and the text of BAD_RECORD of errors.inc. A capacity limit (2.6.1) is the compile
150 REM error "program too large: <word>" at the position of the func record (2.6.2).
155 REM PHASE 5 (5c-1, DESIGN 5.8): at endfunc the function is transformed by T1 T2 T3 T4 and lirrw's T10
160 REM (lines 6000-19999, the SUB op_magic at 58000); see the REM at 6000.
165 REM FLOW (the main program below): lirrw reads one function into the tables, this pass transforms it
170 REM in the tables (OPT), lirrw writes it from them; at #end lirrw closes the output.
175 REM TABLES: the DIMs below are lirrw's contract (24 numeric and 14 string array letters, bounds as
180 REM written; its 173 reserved scalars: API.md). Free for this pass: the numeric arrays S and V, the
185 REM columns of R other than 1 and 2, W between lirrw's entries, unreserved string arrays and scalars.
190 REM seaopt's uses of R and W: the REM at 6000.
195 REM ====================================================================================
360 FILES "sea.lir1"; "sea.lir2"
365 DIM E(299), E$(299,5), N(39,2), N$(39), W$(299), Q(399,9), Q$(399), F(1499,3), F$(1499), Z(8)
370 DIM J(299,4), J$(299), Y(399), Y$(399,5), D(39), D$(39), B(399), A(399)
375 DIM I(199999,4), O(799999), R(99999,9), K(19999,4), C(199999,4), S$(199999)
380 DIM X(131071), T(10000), G$(300), U(40), L(4), H$(100), A$(2)
382 DIM M(301), P(262143), H(199999), V$(49999), U$(131071), G(199999,3), W(199999,4)
385 LET P$ = "seaopt"
386 LET V8 = 1
390 REM ---- the main program: lirrw's entries (passes/lib/API.md) around OPT --------------------
395 GOSUB 69400
400 GOSUB 69410
405 IF Y0 < 0 THEN 425
410 GOSUB 7090
415 GOSUB 69430
420 GOTO 400
425 GOSUB 69420
430 STOP
6000 REM ====================================================================================
6005 REM PHASE 5, sub-phase 5c-1 (DESIGN 5.8, 3.6.5; Decisions 58-73, L-ac-L-at, L-au-L-bb): at
6010 REM endfunc, after the validation, the function in the tables is transformed by T1 (checks and
6015 REM overflow, on the facts F1-F6), T2 (division by constants), T3 (value numbering, load
6020 REM forwarding, copy propagation), T4 (if-conversion) and T10 (clean-up, renumbering), in that
6025 REM order; the writer then rebuilds every record from the tables. A transformation whose result
6030 REM would exceed a LIR capacity limit is not applied (Decision 72; only T2 can grow a function).
6035 REM Representation: a deleted instruction has I(n,1) = 0 until the next compaction, which keeps
6040 REM the operands of O in record order (each instruction's after the previous one's).
6045 REM Columns of R (L-ad): 1 class; T1: 0 stamp of the scope that logged it, 2-5 its state, 6 kind
6050 REM (i: 0 plain, 1 symbol, 2 constant symbol; p: the shape code below), 7 constant value (i, or
6055 REM N8), 8-9 the join marks; elsewhere 8 the number of definitions, 9 the last definition.
6057 REM T4 (L-bq): 3 the depth + 1 and 4 the serial of the outermost open effective part of a write, 5 the latest write's, 6 the last read.
6060 REM State (T1): i plain: 2 lo.sym 3 lo.k 4 hi.sym 5 hi.k (sym -1 unknown, 0 a constant, r a symbol,
6065 REM 100000+A or 200000+A the pseudo-symbols <A,rows>, <A,cols>); i symbol: 2 L 3 U; p: 2 L 3 U of
6070 REM <A,rows>, 4 L 5 U of <A,cols>; N8 = unknown L or U. Shape code of a p register: n > 0 rows(A)
6075 REM and cols(A) are the operands of the rcall at n; -1 a dynamic-array parameter (L-ba); -2 an
6080 REM array register that is not shape-stable; -3 a shape-stable one with pseudo-symbols; 0 none.
6085 REM W (the one new array, L-ad): T1 rows 0-9999 the frame of each block, 10000.. the trail (one
6090 REM row per logged register: stamp*100000+r and its four state values), the save stack from
6095 REM 199999 down; T2 the sequence being built and the maps of the renumbering; T3 two hash tables.
6100 REM ====================================================================================
7078 REM ---- 7080: the RETURN that the tests of the transformations jump to ---------------------------
7080 RETURN
7085 REM ====================================================================================
7090 REM OPT: the transformations of one function, in the order of DESIGN 5.8 restricted to 5c-1
7095 REM ====================================================================================
7100 LET Y2 = Y2 + 1
7105 GOSUB 8280
7110 GOSUB 69450
7115 GOSUB 14555
7120 GOSUB 16880
7125 GOSUB 69450
7130 GOSUB 18710
7135 GOSUB 69450
7140 GOSUB 69440
7155 RETURN
7160 REM ---- VIS: visit the register operands of instruction N0 in field order; for each, O(P0) is
7165 REM the register and R0 its role (1 read, 2 written), and mode V0 selects the callback. Locals
7170 REM P0 W9 J9 B3 J0 J8 R0 and U(field) (the u fields, for the repeat counts); callbacks keep them.
7175 LET P0 = I(N0, 2)
7180 LET W9 = I(N0, 1)
7185 IF W9 = 0 THEN 7080
7190 FOR J9 = 1 TO Q(W9, 4)
7195 LET B3 = Q(W9, 3) + J9 - 1
7200 LET R0 = F(B3, 0)
7205 IF R0 = 0 THEN 7275
7210 LET J0 = 1
7215 IF F(B3, 3) = 0 THEN 7225
7220 LET J0 = U(F(B3, 3))
7225 FOR J8 = 1 TO J0
7230 IF R0 > 2 THEN 7245
7235 IF O(P0) = 0 THEN 7245
7240 GOSUB 7290
7245 IF R0 <> 5 THEN 7255
7250 LET U(J9) = O(P0)
7255 LET P0 = P0 + 1
7260 IF R0 <> 7 THEN 7270
7265 LET P0 = P0 + 1
7270 NEXT J8
7275 NEXT J9
7280 RETURN
7285 REM CBD: the callback of mode V0 (it returns to VIS)
7290 ON V0 GOTO 7300, 7325, 7365, 7080, 7395, 7430, 7565, 7655, 7680, 7720, 7080, 7760, 7785
7295 REM CB1 (DEFS): count the definitions of a written register, remember the last
7300 IF R0 <> 2 THEN 7080
7305 LET R(O(P0), 8) = R(O(P0), 8) + 1
7310 LET R(O(P0), 9) = N0
7315 RETURN
7320 REM CB2 (T3): count the reads of a register, its first and last reading instruction
7325 IF R0 <> 1 THEN 7080
7330 LET X6 = O(P0)
7335 LET R(X6, 2) = R(X6, 2) + 1
7340 IF R(X6, 3) > 0 THEN 7350
7345 LET R(X6, 3) = N0
7350 LET R(X6, 4) = N0
7355 RETURN
7360 REM CB3: H5 = 1 when the instruction writes H3 or H4
7365 IF R0 <> 2 THEN 7080
7370 IF O(P0) = H3 THEN 7380
7375 IF O(P0) <> H4 THEN 7080
7380 LET H5 = 1
7385 RETURN
7390 REM CB5 (T1): a written i register becomes unknown (a symbol: its L and U)
7395 IF R0 <> 2 THEN 7080
7400 LET X6 = O(P0)
7405 IF R(X6, 1) <> 1 THEN 7080
7410 GOSUB 14020
7415 RETURN
7420 REM CB6 (array registers): a definition of a candidate p register that is not one of DESIGN
7425 REM 5.8's array-register forms removes the candidate (H9 = 1: changed)
7430 IF R0 <> 2 THEN 7080
7435 LET X6 = O(P0)
7440 IF R(X6, 1) <> 3 THEN 7080
7445 IF R(X6, 6) <> 1 THEN 7080
7450 LET X4 = Q(W9, 6)
7455 IF X4 = 5 THEN 7525
7460 IF X4 <> 68 THEN 7540
7465 LET X4 = O(I(N0, 2))
7470 IF X4 = Y3 THEN 7080
7475 IF X4 = Y4 THEN 7080
7480 IF X4 = Y5 THEN 7080
7485 IF X4 = Y6 THEN 7080
7490 IF X4 = Y7 THEN 7080
7495 IF X4 = Y8 THEN 7080
7500 IF X4 <> Y9 THEN 7540
7505 LET X4 = O(I(N0, 2) + 4)
7510 IF R(X4, 1) <> 3 THEN 7540
7515 IF R(X4, 6) = 1 THEN 7080
7520 GOTO 7540
7525 LET X4 = O(I(N0, 2) + 1)
7530 IF R(X4, 1) <> 3 THEN 7540
7535 IF R(X4, 6) = 1 THEN 7080
7540 LET R(X6, 6) = 0
7545 LET H9 = 1
7550 RETURN
7555 REM CB7 (shape-stable): count the definitions of an array register that are not its own copy
7560 REM on write (mov A N, N the only result of rcall sea_arr_unique ... N 1 A); R(A,2) = the last
7565 IF R0 <> 2 THEN 7080
7570 LET X6 = O(P0)
7575 IF R(X6, 1) <> 3 THEN 7080
7580 IF R(X6, 6) <> 1 THEN 7080
7585 IF Q(W9, 6) <> 5 THEN 7635
7590 LET X4 = O(I(N0, 2) + 1)
7595 IF R(X4, 8) <> 1 THEN 7635
7600 LET H3 = R(X4, 9)
7605 IF H3 <= 0 THEN 7635
7610 IF Q(I(H3, 1), 6) <> 68 THEN 7635
7615 LET H4 = I(H3, 2)
7620 IF O(H4) <> Y9 THEN 7635
7625 IF O(H4 + 2) <> X4 THEN 7635
7630 IF O(H4 + 4) = X6 THEN 7080
7635 LET R(X6, 7) = R(X6, 7) + 1
7640 LET R(X6, 2) = N0
7645 RETURN
7650 REM CB8 (T3): a read of D3 reads S3
7655 IF R0 <> 1 THEN 7080
7660 IF O(P0) <> D3 THEN 7080
7665 LET O(P0) = S3
7670 RETURN
7675 REM CB9 (T4, L-bq): the effective part (DESIGN 4.9.2) of a write: R(r,3) - 1 and R(r,4) the depth and
7677 REM serial of the outermost still open one of r's writes, R(r,5) the serial of its latest write's
7680 IF R0 <> 2 THEN 7080
7682 LET T8 = O(P0)
7684 LET T9 = T6
7686 LET U2 = W(T6, 0)
7687 REM in an else part, after a write whose effective part is that block's first part: the part around
7688 IF W(T6, 1) = 0 THEN 7696
7690 IF R(T8, 5) <> W(T6, 1) THEN 7696
7692 LET T9 = T6 - 1
7694 LET U2 = W(T9, 0)
7696 LET R(T8, 5) = U2
7698 IF R(T8, 3) = 0 THEN 7706
7700 IF R(T8, 3) - 1 > T9 THEN 7706
7702 IF W(R(T8, 3) - 1, 0) <> R(T8, 4) THEN 7706
7704 RETURN
7706 LET R(T8, 3) = T9 + 1
7708 LET R(T8, 4) = U2
7710 RETURN
7715 REM CB10 (T4, L-bq): R(r,6) = the last record that reads r
7720 IF R0 <> 1 THEN 7080
7725 LET R(O(P0), 6) = N0
7730 RETURN
7755 REM CB12 (T3): the instruction is the last write of its registers so far
7760 IF R0 <> 2 THEN 7080
7765 LET R(O(P0), 0) = N0
7770 RETURN
7775 REM CB13 (private bases): a read of a candidate p register outside the base field of a load or
7780 REM store without idx removes it
7785 IF R0 <> 1 THEN 7080
7790 LET X6 = O(P0)
7795 IF R(X6, 1) <> 3 THEN 7080
7800 IF R(X6, 7) <> 1 THEN 7080
7805 LET X4 = Q(W9, 7)
7810 IF X4 < 3 THEN 7830
7815 IF X4 > 4 THEN 7830
7820 IF P0 <> I(N0, 2) + 1 THEN 7830
7825 IF O(I(N0, 2) + 2) = 0 THEN 7080
7830 LET R(X6, 7) = -1
7835 RETURN
8050 REM ---- DEFS: R(r,8) the number of definitions of r (a parameter's func record counts), R(r,9)
8055 REM the last defining instruction (0: the func record) ----------------------------------------
8060 FOR R2 = 1 TO M7
8065 LET R(R2, 8) = 0
8070 LET R(R2, 9) = -1
8075 NEXT R2
8080 FOR R2 = 1 TO M(5)
8085 LET R(R2, 8) = 1
8090 LET R(R2, 9) = 0
8095 NEXT R2
8100 LET V0 = 1
8105 FOR N0 = 1 TO A0
8110 GOSUB 7175
8115 NEXT N0
8120 RETURN
8125 REM ---- CVAL: V2 = the i64 immediate of row C2 of C when it lies in -2^52 .. 2^52, else N8 -----
8130 LET V2 = N8
8135 IF C(C2, 1) <= 16 THEN 8160
8140 IF C(C2, 1) < 65520 THEN 7080
8145 LET V2 = (((C(C2, 1) - 65536) * 65536 + C(C2, 2)) * 65536 + C(C2, 3)) * 65536 + C(C2, 4)
8150 IF V2 >= -U9 THEN 7080
8155 GOTO 8175
8160 LET V2 = ((C(C2, 1) * 65536 + C(C2, 2)) * 65536 + C(C2, 3)) * 65536 + C(C2, 4)
8165 IF V2 <= U9 THEN 7080
8175 LET V2 = N8
8180 RETURN
8185 REM ---- ARRREG: R(r,6) = 1 exactly for the array registers (DESIGN 5.8 Terms), as the largest set
8190 REM closed under the allowed definitions ---------------------------------------------------
8195 FOR R2 = 1 TO M7
8200 IF R(R2, 1) <> 3 THEN 8225
8205 LET R(R2, 6) = 0
8210 IF R(R2, 8) < 1 THEN 8225
8215 IF R2 <= M(5) THEN 8225
8220 LET R(R2, 6) = 1
8225 NEXT R2
8230 LET H9 = 0
8235 LET V0 = 6
8240 FOR N0 = 1 TO A0
8245 GOSUB 7175
8250 NEXT N0
8255 IF H9 = 1 THEN 8230
8260 RETURN
8265 REM ====================================================================================
8270 REM T1: the fact walk (F1-F6) with check and overflow elimination (DESIGN 5.8, L-ap, L-au, L-av)
8275 REM ====================================================================================
8280 GOSUB 8060
8285 REM loop depth of every record in I(n,0) (a loop's opening and closing records count as inside)
8290 LET D3 = 0
8295 FOR N3 = 1 TO A0
8300 LET X3 = Q(I(N3, 1), 6)
8305 IF X3 = 56 THEN 8315
8310 IF X3 <> 58 THEN 8320
8315 LET D3 = D3 + 1
8320 LET I(N3, 0) = D3
8325 IF X3 = 57 THEN 8335
8330 IF X3 <> 59 THEN 8340
8335 LET D3 = D3 - 1
8340 NEXT N3
8345 REM kinds of the i registers: constants (one li) and symbols (one definition outside loops)
8350 FOR R2 = 1 TO M7
8355 LET R(R2, 6) = 0
8360 LET R(R2, 7) = N8
8365 IF R(R2, 1) <> 1 THEN 8430
8370 IF R(R2, 8) <> 1 THEN 8430
8375 LET X4 = R(R2, 9)
8380 IF X4 = 0 THEN 8425
8385 IF Q(I(X4, 1), 6) <> 1 THEN 8405
8390 LET C2 = O(I(X4, 2) + 1)
8395 GOSUB 8130
8400 LET R(R2, 7) = V2
8405 IF I(X4, 0) > 0 THEN 8430
8410 IF Q(I(X4, 1), 6) <> 1 THEN 8425
8415 LET R(R2, 6) = 2
8420 GOTO 8430
8425 LET R(R2, 6) = 1
8430 NEXT R2
8435 REM array registers, their definitions other than their own copy on write, and the parameters
8440 REM used as the base of a store or as an operand of call or mcopy (R(r,3) = 1)
8445 GOSUB 8195
8450 FOR R2 = 1 TO M7
8455 IF R(R2, 1) <> 3 THEN 8475
8460 LET R(R2, 2) = 0
8465 LET R(R2, 3) = 0
8470 LET R(R2, 7) = 0
8475 NEXT R2
8480 LET V0 = 7
8485 FOR N0 = 1 TO A0
8490 GOSUB 7175
8495 NEXT N0
8500 FOR N3 = 1 TO A0
8505 LET X3 = Q(I(N3, 1), 6)
8510 LET P4 = I(N3, 2)
8515 IF X3 = 55 THEN 8540
8520 IF X3 = 67 THEN 8555
8525 IF Q(I(N3, 1), 7) <> 4 THEN 8575
8530 LET R(O(P4 + 1), 3) = 1
8535 GOTO 8575
8540 LET R(O(P4), 3) = 1
8545 LET R(O(P4 + 1), 3) = 1
8550 GOTO 8575
8555 LET X4 = P4 + 3 + O(P4 + 1)
8560 FOR X7 = 1 TO O(X4 - 1)
8565 LET R(O(X4 + X7 - 1), 3) = 1
8570 NEXT X7
8575 NEXT N3
8577 GOSUB 19300
8580 REM the shape code of each p register (R(r,6))
8585 FOR R2 = 1 TO M7
8590 IF R(R2, 1) <> 3 THEN 8710
8595 IF R(R2, 6) = 1 THEN 8630
8600 LET R(R2, 6) = 0
8605 IF R2 > M(5) THEN 8710
8610 IF R(R2, 8) <> 1 THEN 8710
8615 IF R(R2, 3) <> 0 THEN 8710
8617 REM a dynamic-array parameter only: rule 18's chkb on its extent and indexed data (L-ba)
8618 IF R(R2, 4) + R(R2, 5) <> 2 THEN 8710
8620 LET R(R2, 6) = -1
8625 GOTO 8710
8630 LET R(R2, 6) = -2
8635 IF R(R2, 7) <> 1 THEN 8710
8640 LET R(R2, 6) = -3
8645 LET X4 = R(R2, 2)
8650 IF Q(I(X4, 1), 6) <> 68 THEN 8710
8655 LET P4 = I(X4, 2)
8660 IF O(P4) = Y3 THEN 8675
8665 IF O(P4) = Y4 THEN 8675
8670 IF O(P4) <> Y5 THEN 8710
8675 LET X6 = O(P4 + 6)
8680 GOSUB 8725
8685 IF F0 = 0 THEN 8710
8690 LET X6 = O(P4 + 7)
8695 GOSUB 8725
8700 IF F0 = 0 THEN 8710
8705 LET R(R2, 6) = X4
8710 NEXT R2
8715 GOTO 8765
8720 REM T1H_SC: F0 = 1 when X6 is a symbol or a constant
8725 LET F0 = 1
8730 IF R(X6, 6) > 0 THEN 7080
8735 IF R(X6, 8) <> 1 THEN 8750
8740 IF R(X6, 9) <= 0 THEN 8750
8745 IF Q(I(R(X6, 9), 1), 6) = 1 THEN 7080
8750 LET F0 = 0
8755 RETURN
8760 REM the state at the function's entry
8765 FOR R2 = 1 TO M7
8770 LET R(R2, 0) = 0
8775 LET R(R2, 8) = 0
8780 LET R(R2, 9) = 0
8785 LET R(R2, 2) = 0
8790 LET R(R2, 3) = 0
8795 LET R(R2, 4) = 0
8800 LET R(R2, 5) = 0
8805 IF R(R2, 1) = 3 THEN 8855
8810 IF R(R2, 1) <> 1 THEN 8865
8815 IF R(R2, 6) = 2 THEN 8865
8820 IF R(R2, 6) = 1 THEN 8840
8825 LET R(R2, 2) = -1
8830 LET R(R2, 4) = -1
8835 GOTO 8865
8840 LET R(R2, 2) = N8
8845 LET R(R2, 3) = N8
8850 GOTO 8865
8855 LET R(R2, 3) = K0
8860 LET R(R2, 5) = K0
8865 NEXT R2
8870 REM the walk: S0 scopes opened, S1 the current scope, D1 depth (T() the open blocks), D5 the
8875 REM trail top, D6 the save stack top, D2 = 1 after exit/next/ret, Z9 the last record that ends
8880 REM a region, X5 = 1 when W is full (the walk then stops: what it did is proven)
8885 LET S0 = 0
8890 LET S1 = 0
8895 LET D1 = 0
8900 LET D5 = 9999
8905 LET D6 = 200000
8910 LET D2 = 0
8915 LET Z9 = 0
8920 LET X5 = 0
8925 LET N4 = 1
8930 IF X5 = 1 THEN 7080
8935 IF N4 > A0 THEN 7080
8940 LET P5 = I(N4, 2)
8945 LET X3 = Q(I(N4, 1), 6)
8950 IF X3 >= 56 THEN 9025
8955 IF X3 = 1 THEN 9035
8960 IF X3 = 5 THEN 9115
8965 IF X3 = 6 THEN 9150
8970 IF X3 = 7 THEN 9150
8975 IF X3 = 9 THEN 9150
8980 IF X3 = 10 THEN 9150
8985 IF X3 = 11 THEN 9745
8990 IF X3 = 13 THEN 9845
8995 IF X3 = 47 THEN 9935
9000 LET N0 = N4
9005 LET V0 = 5
9010 GOSUB 7175
9015 LET N4 = N4 + 1
9020 GOTO 8930
9025 ON X3 - 55 GOTO 11515, 11690, 11660, 11690, 10530, 10530, 10600, 10715, 11835, 11835, 11835, 9000, 10230, 10335, 9000, 9000, 9000
9030 REM ---- li (F1) -----------------------------------------------------------------------------
9035 LET X6 = O(P5)
9040 IF R(X6, 6) <> 0 THEN 9015
9045 LET C2 = O(P5 + 1)
9050 GOSUB 8130
9055 LET Z2 = 0
9060 LET Z3 = V2
9065 LET Z4 = 0
9070 LET Z5 = V2
9075 IF V2 <> N8 THEN 9100
9080 LET Z2 = -1
9085 LET Z3 = 0
9090 LET Z4 = -1
9095 LET Z5 = 0
9100 GOSUB 13965
9105 GOTO 9015
9110 REM ---- mov (F1) ----------------------------------------------------------------------------
9115 IF R(O(P5), 1) <> 1 THEN 9015
9120 LET X6 = O(P5 + 1)
9125 GOSUB 13045
9130 LET X6 = O(P5)
9135 GOSUB 14090
9140 GOTO 9015
9145 REM ---- iadd isub iaddc isubc: T1 on the checked ones, then F1 ---------------------------------
9150 LET D3 = O(P5)
9155 LET D4 = O(P5 + 1)
9160 LET D9 = O(P5 + 2)
9165 IF X3 < 9 THEN 9500
9170 REM the added constant (b, or a of an iaddc, DESIGN 5.8 T1); else both operands made constant
9175 LET X6 = D9
9180 GOSUB 13045
9185 LET V3 = S4
9190 LET V4 = T4
9195 LET V5 = S5
9200 LET V6 = T5
9205 LET X6 = D4
9210 GOSUB 13045
9215 IF R(D9, 7) <> N8 THEN 9305
9220 IF X3 = 10 THEN 9395
9225 IF R(D4, 7) = N8 THEN 9395
9230 REM iaddc with a constant: the roles swap, b is the s + c of the rule
9235 LET H6 = S4
9240 LET S4 = V3
9245 LET V3 = H6
9250 LET H6 = T4
9255 LET T4 = V4
9260 LET V4 = H6
9265 LET H6 = S5
9270 LET S5 = V5
9275 LET V5 = H6
9280 LET H6 = T5
9285 LET T5 = V6
9290 LET V6 = H6
9295 LET F3 = R(D4, 7)
9300 GOTO 9320
9305 LET F3 = R(D9, 7)
9310 IF X3 = 9 THEN 9320
9315 LET F3 = -F3
9320 LET M2 = 0
9325 LET M3 = F3
9330 LET S2 = S5
9335 LET T2 = T5
9340 GOSUB 13450
9345 GOSUB 13725
9350 IF F0 = 0 THEN 9500
9355 LET M2 = 0
9360 LET M3 = F3
9365 LET S2 = S4
9370 LET T2 = T4
9375 GOSUB 13515
9380 GOSUB 13760
9385 IF F0 = 0 THEN 9500
9390 GOTO 9480
9395 REM two operands without a constant: all four bounds must have constant values through L, U
9400 LET S2 = S4
9405 LET T2 = T4
9410 GOSUB 13390
9415 IF F0 = 0 THEN 9500
9420 LET S2 = S5
9425 LET T2 = T5
9430 GOSUB 13390
9435 IF F0 = 0 THEN 9500
9440 LET S2 = V3
9445 LET T2 = V4
9450 GOSUB 13390
9455 IF F0 = 0 THEN 9500
9460 LET S2 = V5
9465 LET T2 = V6
9470 GOSUB 13390
9475 IF F0 = 0 THEN 9500
9480 LET I(N4, 1) = E5
9485 IF X3 = 9 THEN 9495
9490 LET I(N4, 1) = E6
9495 LET I(N4, 4) = 0
9500 REM F1: a constant operand moves the other operand's bounds
9505 IF R(D9, 7) = N8 THEN 9545
9510 LET X6 = D4
9515 GOSUB 13045
9520 LET F3 = R(D9, 7)
9525 IF X3 = 6 THEN 9575
9530 IF X3 = 9 THEN 9575
9535 LET F3 = -F3
9540 GOTO 9575
9545 IF X3 = 7 THEN 9725
9550 IF X3 = 10 THEN 9725
9555 IF R(D4, 7) = N8 THEN 9725
9560 LET X6 = D9
9565 GOSUB 13045
9570 LET F3 = R(D4, 7)
9575 IF X3 >= 9 THEN 9655
9580 REM a wrapping one: only under the no-overflow condition
9585 LET M2 = 0
9590 LET M3 = F3
9595 LET S2 = S5
9600 LET T2 = T5
9605 GOSUB 13450
9610 GOSUB 13725
9615 IF F0 = 0 THEN 9725
9620 LET M2 = 0
9625 LET M3 = F3
9630 LET S2 = S4
9635 LET T2 = T4
9640 GOSUB 13515
9645 GOSUB 13760
9650 IF F0 = 0 THEN 9725
9655 LET S2 = S4
9660 LET T2 = T4
9665 LET H6 = F3
9670 GOSUB 13355
9675 LET S4 = S2
9680 LET T4 = T2
9685 LET S2 = S5
9690 LET T2 = T5
9695 GOSUB 13355
9700 LET S5 = S2
9705 LET T5 = T2
9710 LET X6 = D3
9715 GOSUB 14090
9720 GOTO 9015
9725 LET X6 = D3
9730 GOSUB 14020
9735 GOTO 9015
9740 REM ---- imulc: imul when both operands have constant bounds with small products -------------
9745 LET X6 = O(P5 + 1)
9750 GOSUB 13045
9755 LET V3 = S4
9760 LET V4 = T4
9765 LET V5 = S5
9770 LET V6 = T5
9775 LET X6 = O(P5 + 2)
9780 GOSUB 13045
9785 IF V3 <> 0 THEN 9000
9790 IF V5 <> 0 THEN 9000
9795 IF S4 <> 0 THEN 9000
9800 IF S5 <> 0 THEN 9000
9805 IF ABS(V4 * T4) > U9 THEN 9000
9810 IF ABS(V4 * T5) > U9 THEN 9000
9815 IF ABS(V6 * T4) > U9 THEN 9000
9820 IF ABS(V6 * T5) > U9 THEN 9000
9825 LET I(N4, 1) = E7
9830 LET I(N4, 4) = 0
9835 GOTO 9000
9840 REM ---- inegc: ineg when -a stays in range: -a.lo <= 2^63 - 1 and -a.hi >= -2^63 ---------------
9845 LET X6 = O(P5 + 1)
9850 GOSUB 13045
9855 LET M2 = 0
9860 LET M3 = 0
9865 LET S2 = S4
9870 LET T2 = T4
9875 GOSUB 13590
9880 GOSUB 13725
9885 IF F0 = 0 THEN 9000
9890 LET S2 = S5
9895 LET T2 = T5
9900 GOSUB 13655
9905 GOSUB 13760
9910 IF F0 = 0 THEN 9000
9915 LET I(N4, 1) = E8
9920 LET I(N4, 4) = 0
9925 GOTO 9000
9930 REM ---- ldi of a header extent (F2) -----------------------------------------------------------
9935 IF O(P5 + 2) <> 0 THEN 9000
9940 LET X4 = O(P5 + 4)
9945 IF G(X4, 0) <> 0 THEN 9000
9950 IF G(X4, 1) <> 0 THEN 9000
9955 LET X4 = G(X4, 2) * 65536 + G(X4, 3)
9960 LET X7 = O(P5 + 1)
9965 LET X8 = R(X7, 6)
9970 IF X8 = 0 THEN 9000
9975 IF X8 = -2 THEN 9000
9980 IF X4 = K6 THEN 10005
9985 IF X4 <> K7 THEN 9000
9990 LET H7 = 200000
9995 LET H8 = 7
10000 GOTO 10015
10005 LET H7 = 100000
10010 LET H8 = 6
10015 IF X8 < 0 THEN 10070
10020 REM rows(A) or cols(A) is the operand R (or C) of the rcall that makes A
10025 LET X6 = O(I(X8, 2) + H8)
10030 LET S4 = 0
10035 LET T4 = R(X6, 7)
10040 IF T4 <> N8 THEN 10080
10045 LET S4 = -1
10050 LET T4 = 0
10055 IF R(X6, 6) <> 1 THEN 10080
10060 LET S4 = X6
10065 GOTO 10080
10070 LET S4 = H7 + X7
10075 LET T4 = 0
10080 LET S5 = S4
10085 LET T5 = T4
10090 LET X6 = O(P5)
10095 IF R(X6, 6) <> 1 THEN 10215
10100 REM E is a symbol: its L, U are narrowed by x's constant bounds (L-au)
10105 LET O3 = -1
10110 LET O4 = 0
10115 LET O5 = -1
10120 LET O6 = 0
10125 IF S4 < 0 THEN 10205
10130 LET O3 = 0
10135 LET O4 = T4
10140 LET O5 = 0
10145 LET O6 = T4
10150 IF S4 = 0 THEN 10205
10155 LET S7 = S4
10160 GOSUB 13170
10165 LET O3 = -1
10170 LET O5 = -1
10175 IF L4 = N8 THEN 10190
10180 LET O3 = 0
10185 LET O4 = L4
10190 IF U4 = N8 THEN 10205
10195 LET O5 = 0
10200 LET O6 = U4
10205 GOSUB 14195
10210 GOTO 9015
10215 GOSUB 14090
10220 GOTO 9015
10225 REM ---- rcall: F2's L(R) >= 0 and U(R) <= SEA_LIM_EXTENT for the symbol extents of A ---------
10230 LET N0 = N4
10235 LET V0 = 5
10240 GOSUB 7175
10245 IF O(P5 + 1) = 0 THEN 9015
10250 LET X7 = O(P5 + 2)
10255 IF R(X7, 1) <> 3 THEN 9015
10260 IF R(X7, 6) <> N4 THEN 9015
10265 LET X8 = O(P5 + 6)
10270 GOSUB 10290
10275 LET X8 = O(P5 + 7)
10280 GOSUB 10290
10285 GOTO 9015
10290 IF R(X8, 6) <> 1 THEN 7080
10295 LET S7 = X8
10300 LET H6 = 0
10305 GOSUB 14390
10310 LET S7 = X8
10315 LET H6 = K0
10320 GOSUB 14415
10325 RETURN
10330 REM ---- chkb I E: deleted when proven (before F4), then F4 -----------------------------------
10335 LET X6 = O(P5)
10340 GOSUB 13045
10345 LET V3 = S4
10350 LET V4 = T4
10355 LET V5 = S5
10360 LET V6 = T5
10365 LET X6 = O(P5 + 1)
10370 GOSUB 13045
10375 LET S2 = 0
10380 LET T2 = 0
10385 LET S3 = V3
10390 LET T3 = V4
10395 GOSUB 13230
10400 IF F0 = 0 THEN 10460
10405 LET S2 = S4
10410 LET T2 = T4
10415 LET H6 = -1
10420 GOSUB 13355
10425 LET S3 = S2
10430 LET T3 = T2
10435 LET S2 = V5
10440 LET T2 = V6
10445 GOSUB 13230
10450 IF F0 = 0 THEN 10460
10455 LET I(N4, 1) = 0
10460 REM F4 (not on a symbol, L-av): I.lo by 0, I.hi by E's upper bound - 1
10465 LET X6 = O(P5)
10470 IF R(X6, 6) <> 0 THEN 9015
10475 LET S2 = S5
10480 LET T2 = T5
10485 LET H6 = -1
10490 GOSUB 13355
10495 LET O3 = 0
10500 LET O4 = 0
10505 LET O5 = S2
10510 LET O6 = T2
10515 GOSUB 14195
10520 GOTO 9015
10525 REM ---- if / ifz: F5 is found in the region before it; a scope opens -------------------------
10530 LET B5 = O(P5)
10535 LET B6 = O(P5 + 1)
10540 GOSUB 12310
10545 GOSUB 11770
10550 LET W(B5, 2) = D6
10555 LET W(B5, 3) = 0
10560 LET W(B5, 4) = 0
10565 LET H7 = 0
10570 IF X3 = 60 THEN 10580
10575 LET H7 = 1
10580 GOSUB 12495
10585 LET Z9 = N4
10590 GOTO 9015
10595 REM ---- else: the end of the first part --------------------------------------------------------
10600 LET B5 = O(P5)
10605 GOSUB 10630
10610 LET Z9 = N4
10615 GOTO 9015
10620 REM PART1: saves the first part's changes (dead flag in W(b,3), save boundary in W(b,4)),
10625 REM returns to the state at the if, and applies F5's negation for the second part
10630 LET W(B5, 3) = D2
10635 LET D2 = 0
10640 LET X7 = W(B5, 0) + 1
10645 IF X7 > D5 THEN 10670
10650 LET X6 = W(X7, 0) - INT(W(X7, 0) / 100000) * 100000
10655 GOSUB 13870
10660 LET X7 = X7 + 1
10665 GOTO 10645
10670 LET W(B5, 4) = D6
10675 LET H7 = W(B5, 0)
10680 GOSUB 13915
10685 LET H7 = 1
10690 IF K(B5, 1) = 3 THEN 10700
10695 LET H7 = 0
10700 GOSUB 12495
10705 RETURN
10710 REM ---- endif: the join (F6) ---------------------------------------------------------------
10715 LET B5 = O(P5)
10720 IF W(B5, 4) > 0 THEN 10730
10725 GOSUB 10630
10730 LET X8 = D2
10735 LET X4 = W(B5, 3)
10740 IF X4 = 0 THEN 10770
10745 IF X8 = 0 THEN 11020
10750 REM both parts end in exit, next or ret: the state at the if
10755 LET H7 = W(B5, 0)
10760 GOSUB 13915
10765 GOTO 11020
10770 IF X8 = 0 THEN 10840
10775 REM only the second part ends so: the first part's state
10780 LET H7 = W(B5, 0)
10785 GOSUB 13915
10790 GOSUB 11805
10795 FOR X7 = W(B5, 4) TO W(B5, 2) - 1
10800 LET X6 = W(X7, 0)
10805 LET Z2 = W(X7, 1)
10810 LET Z3 = W(X7, 2)
10815 LET Z4 = W(X7, 3)
10820 LET Z5 = W(X7, 4)
10825 GOSUB 13965
10830 NEXT X7
10835 GOTO 11025
10840 REM the join of the two parts: save the second part's changes, back to the if, then join
10845 LET X7 = W(B5, 0) + 1
10850 IF X7 > D5 THEN 10875
10855 LET X6 = W(X7, 0) - INT(W(X7, 0) / 100000) * 100000
10860 GOSUB 13870
10865 LET X7 = X7 + 1
10870 GOTO 10850
10875 LET H7 = W(B5, 0)
10880 GOSUB 13915
10885 GOSUB 11805
10890 FOR X7 = W(B5, 4) TO W(B5, 2) - 1
10895 LET R(W(X7, 0), 8) = X7
10900 NEXT X7
10905 FOR X7 = D6 TO W(B5, 4) - 1
10910 LET R(W(X7, 0), 9) = X7
10915 NEXT X7
10920 REM first the L, U of symbols and pseudo-symbols, then the intervals (compared with the joined
10925 REM L, U, L-av)
10930 FOR F5 = 1 TO 2
10935 FOR X7 = D6 TO W(B5, 2) - 1
10940 LET X6 = W(X7, 0)
10945 IF X7 >= W(B5, 4) THEN 10955
10950 IF R(X6, 8) > 0 THEN 10985
10955 LET F4 = 1
10960 IF R(X6, 1) = 3 THEN 10975
10965 IF R(X6, 6) = 1 THEN 10975
10970 LET F4 = 2
10975 IF F4 <> F5 THEN 10985
10980 GOSUB 11055
10985 NEXT X7
10990 NEXT F5
10995 FOR X7 = D6 TO W(B5, 2) - 1
11000 LET R(W(X7, 0), 8) = 0
11005 LET R(W(X7, 0), 9) = 0
11010 NEXT X7
11015 GOTO 11025
11020 GOSUB 11805
11025 LET D6 = W(B5, 2)
11030 LET D2 = 0
11035 LET Z9 = N4
11040 GOTO 9015
11045 REM JOIN: register X6 gets the join of its two parts' values (marks R(r,8), R(r,9) name the
11050 REM saved rows; an unmarked part has the state at the if, which is current)
11055 LET V3 = R(X6, 2)
11060 LET V4 = R(X6, 3)
11065 LET V5 = R(X6, 4)
11070 LET V6 = R(X6, 5)
11075 LET O3 = V3
11080 LET O4 = V4
11085 LET O5 = V5
11090 LET O6 = V6
11095 LET H3 = R(X6, 8)
11100 IF H3 = 0 THEN 11125
11105 LET V3 = W(H3, 1)
11110 LET V4 = W(H3, 2)
11115 LET V5 = W(H3, 3)
11120 LET V6 = W(H3, 4)
11125 LET H3 = R(X6, 9)
11130 IF H3 = 0 THEN 11155
11135 LET O3 = W(H3, 1)
11140 LET O4 = W(H3, 2)
11145 LET O5 = W(H3, 3)
11150 LET O6 = W(H3, 4)
11155 IF R(X6, 1) = 3 THEN 11360
11160 IF R(X6, 6) = 1 THEN 11360
11165 REM an interval: the lower of the lower bounds, the higher of the upper ones, when comparable
11170 LET S2 = V3
11175 LET T2 = V4
11180 LET S3 = O3
11185 LET T3 = O4
11190 GOSUB 13230
11195 LET Z2 = V3
11200 LET Z3 = V4
11205 IF F0 = 1 THEN 11260
11210 LET S2 = O3
11215 LET T2 = O4
11220 LET S3 = V3
11225 LET T3 = V4
11230 GOSUB 13230
11235 LET Z2 = O3
11240 LET Z3 = O4
11245 IF F0 = 1 THEN 11260
11250 LET Z2 = -1
11255 LET Z3 = 0
11260 LET S2 = V5
11265 LET T2 = V6
11270 LET S3 = O5
11275 LET T3 = O6
11280 GOSUB 13230
11285 LET Z4 = O5
11290 LET Z5 = O6
11295 IF F0 = 1 THEN 11350
11300 LET S2 = O5
11305 LET T2 = O6
11310 LET S3 = V5
11315 LET T3 = V6
11320 GOSUB 13230
11325 LET Z4 = V5
11330 LET Z5 = V6
11335 IF F0 = 1 THEN 11350
11340 LET Z4 = -1
11345 LET Z5 = 0
11350 GOSUB 13965
11355 RETURN
11360 REM L the smaller, U the larger, unknown when either is (the pairs 2,3 and 4,5)
11365 LET Z2 = N8
11370 IF V3 = N8 THEN 11395
11375 IF O3 = N8 THEN 11395
11380 LET Z2 = V3
11385 IF O3 >= V3 THEN 11395
11390 LET Z2 = O3
11395 LET Z3 = N8
11400 IF V4 = N8 THEN 11425
11405 IF O4 = N8 THEN 11425
11410 LET Z3 = V4
11415 IF O4 <= V4 THEN 11425
11420 LET Z3 = O4
11425 LET Z4 = V5
11430 LET Z5 = V6
11435 IF R(X6, 1) <> 3 THEN 11500
11440 LET Z4 = N8
11445 IF V5 = N8 THEN 11470
11450 IF O5 = N8 THEN 11470
11455 LET Z4 = V5
11460 IF O5 >= V5 THEN 11470
11465 LET Z4 = O5
11470 LET Z5 = N8
11475 IF V6 = N8 THEN 11500
11480 IF O6 = N8 THEN 11500
11485 LET Z5 = V6
11490 IF O6 <= V6 THEN 11500
11495 LET Z5 = O6
11500 GOSUB 13965
11505 RETURN
11510 REM ---- loop: F3 and the non-emptiness on symbols (in the guard's part), then the loop scope -----
11515 LET B5 = O(P5)
11520 GOSUB 11890
11525 IF O3 <> 0 THEN 11560
11530 IF O5 <= 0 THEN 11590
11535 LET S7 = O5
11540 LET H6 = O4 - O6
11545 IF ABS(H6) > U9 THEN 11590
11550 GOSUB 14390
11555 GOTO 11590
11560 IF O3 <= 0 THEN 11590
11565 IF O5 <> 0 THEN 11590
11570 LET S7 = O3
11575 LET H6 = O6 - O4
11580 IF ABS(H6) > U9 THEN 11590
11585 GOSUB 14415
11590 LET L2 = O3
11595 LET L3 = O4
11600 LET L5 = O5
11605 LET L6 = O6
11610 GOSUB 11770
11615 GOSUB 11735
11620 LET X6 = O(P5 + 1)
11625 LET Z2 = L2
11630 LET Z3 = L3
11635 LET Z4 = L5
11640 LET Z5 = L6
11645 GOSUB 13965
11650 LET Z9 = N4
11655 GOTO 9015
11660 LET B5 = O(P5)
11665 GOSUB 11770
11670 GOSUB 11735
11675 LET Z9 = N4
11680 GOTO 9015
11685 REM ---- endloop / enddo: the entry state with every register the loop writes unknown ----------
11690 LET B5 = O(P5)
11695 LET H7 = W(B5, 0)
11700 GOSUB 13915
11705 GOSUB 11805
11710 GOSUB 11735
11715 LET D2 = 0
11720 LET Z9 = N4
11725 GOTO 9015
11730 REM T1_LW: every register written in loop B5 becomes unknown
11735 LET V0 = 5
11740 FOR L9 = K(B5, 2) TO K(B5, 4) - 1
11745 LET N0 = L9
11750 GOSUB 7175
11755 NEXT L9
11760 RETURN
11765 REM T1_PUSH / T1_POP: open block B5's scope (W(b,0) the trail mark, W(b,1) its id) / close one
11770 LET D1 = D1 + 1
11775 LET T(D1) = B5
11780 LET W(B5, 0) = D5
11785 LET S0 = S0 + 1
11790 LET W(B5, 1) = S0
11795 LET S1 = S0
11800 RETURN
11805 LET D1 = D1 - 1
11810 LET S1 = 0
11815 IF D1 = 0 THEN 7080
11820 LET S1 = W(T(D1), 1)
11825 RETURN
11830 REM ---- exit, next, ret: the rest of the block part never runs ---------------------------------
11835 LET D2 = 1
11840 LET Z9 = N4
11845 IF D1 = 0 THEN 7080
11850 LET B5 = T(D1)
11855 LET N4 = K(B5, 4)
11860 IF K(B5, 1) < 3 THEN 8930
11865 IF W(B5, 4) > 0 THEN 8930
11870 IF K(B5, 3) = 0 THEN 8930
11875 LET N4 = K(B5, 3)
11880 GOTO 8930
11885 REM ---- F3: the bounds (O3,O4) (O5,O6) of the ind of loop B5 at N4 (sym -1 when unknown) -------
11890 LET O3 = -1
11895 LET O4 = 0
11900 LET O5 = -1
11905 LET O6 = 0
11910 IF N4 < 3 THEN 7080
11915 LET F2 = I(N4 - 1, 2)
11920 LET F3 = I(N4 - 2, 2)
11925 IF Q(I(N4 - 1, 1), 6) <> 60 THEN 12115
11930 IF O(F2) <> B5 - 1 THEN 12115
11935 IF Q(I(N4 - 2, 1), 6) <> 28 THEN 12115
11940 IF O(F2 + 1) <> O(F3 + 1) THEN 12115
11945 IF O(P5 + 2) <> O(F3 + 2) THEN 12115
11950 IF O(P5 + 3) <> O(F3) THEN 12115
11955 IF O(P5 + 4) <> O(F3 + 4) THEN 12115
11960 LET F4 = R(O(P5 + 4), 7)
11965 IF F4 = N8 THEN 7080
11970 IF F4 = 0 THEN 7080
11975 LET F5 = O(F3 + 5)
11980 IF F4 < 0 THEN 12050
11985 LET X6 = O(F3 + 2)
11990 GOSUB 13045
11995 LET O3 = S4
12000 LET O4 = T4
12005 LET X6 = O(F3 + 3)
12010 GOSUB 13045
12015 LET S2 = S5
12020 LET T2 = T5
12025 LET H6 = F5 - 1
12030 GOSUB 13355
12035 LET O5 = S2
12040 LET O6 = T2
12045 RETURN
12050 LET X6 = O(F3 + 3)
12055 GOSUB 13045
12060 LET S2 = S4
12065 LET T2 = T4
12070 LET H6 = 1 - F5
12075 GOSUB 13355
12080 LET O3 = S2
12085 LET O4 = T2
12090 LET X6 = O(F3 + 2)
12095 GOSUB 13045
12100 LET O5 = S5
12105 LET O6 = T5
12110 RETURN
12115 REM rule 17: li Z 0, icmp gt E N Z, if B E, li O 1, isub L N O, loop B+1 K Z L O
12120 IF N4 < 6 THEN 7080
12125 IF Q(I(N4 - 5, 1), 6) <> 1 THEN 7080
12130 IF Q(I(N4 - 4, 1), 6) <> 24 THEN 7080
12135 IF Q(I(N4 - 3, 1), 6) <> 60 THEN 7080
12140 IF Q(I(N4 - 2, 1), 6) <> 1 THEN 7080
12145 IF Q(I(N4 - 1, 1), 6) <> 7 THEN 7080
12150 LET F2 = I(N4 - 5, 2)
12155 LET F3 = I(N4 - 4, 2)
12160 LET F4 = I(N4 - 3, 2)
12165 LET F5 = I(N4 - 1, 2)
12170 LET C2 = O(F2 + 1)
12175 GOSUB 8130
12180 IF V2 <> 0 THEN 7080
12185 LET C2 = O(I(N4 - 2, 2) + 1)
12190 GOSUB 8130
12195 IF V2 <> 1 THEN 7080
12200 IF O(F3) <> C8 THEN 7080
12205 IF O(F3 + 3) <> O(F2) THEN 7080
12210 IF O(F4) <> B5 - 1 THEN 7080
12215 IF O(F4 + 1) <> O(F3 + 1) THEN 7080
12220 IF O(F5 + 1) <> O(F3 + 2) THEN 7080
12225 IF O(F5 + 2) <> O(I(N4 - 2, 2)) THEN 7080
12230 IF O(P5 + 2) <> O(F2) THEN 7080
12235 IF O(P5 + 3) <> O(F5) THEN 7080
12240 IF O(P5 + 4) <> O(F5 + 2) THEN 7080
12245 LET X6 = O(F3 + 2)
12250 GOSUB 13045
12255 LET S2 = S5
12260 LET T2 = T5
12265 LET H6 = -1
12270 GOSUB 13355
12275 LET O3 = 0
12280 LET O4 = 0
12285 LET O5 = S2
12290 LET O6 = T2
12295 RETURN
12300 REM ---- F5SCAN: K(B5,0) = cc*1E10 + A*1E5 + B for an icmp writing B6 in the region before the
12305 REM if at N4 with A, B and B6 not written after it (0: none; cc 1 eq 2 ne 3 lt 4 le 5 gt 6 ge)
12310 LET K(B5, 0) = 0
12315 LET V0 = 3
12320 FOR L8 = N4 - 1 TO Z9 + 1 STEP -1
12325 LET N0 = L8
12330 LET H3 = B6
12335 LET H4 = -1
12340 LET H5 = 0
12345 GOSUB 7175
12350 IF H5 = 1 THEN 12365
12355 NEXT L8
12360 RETURN
12365 IF Q(I(L8, 1), 6) <> 24 THEN 7080
12370 LET P4 = I(L8, 2)
12375 IF O(P4 + 1) <> B6 THEN 7080
12380 LET H3 = O(P4 + 2)
12385 LET H4 = O(P4 + 3)
12390 LET H5 = 0
12395 FOR L7 = L8 + 1 TO N4 - 1
12400 LET N0 = L7
12405 GOSUB 7175
12410 IF H5 = 1 THEN 7080
12415 NEXT L7
12420 LET X4 = O(P4)
12425 LET F2 = 1
12430 IF X4 = C4 THEN 12480
12435 LET F2 = 2
12440 IF X4 = C5 THEN 12480
12445 LET F2 = 3
12450 IF X4 = C6 THEN 12480
12455 LET F2 = 4
12460 IF X4 = C7 THEN 12480
12465 LET F2 = 5
12470 IF X4 = C8 THEN 12480
12475 LET F2 = 6
12480 LET K(B5, 0) = F2 * 1E10 + H3 * 1E5 + H4
12485 RETURN
12490 REM ---- F5APPLY: the narrowing of block B5's comparison (H7 = 1: its negation) ----------------
12495 LET F2 = K(B5, 0)
12500 IF F2 = 0 THEN 7080
12505 LET F3 = INT(F2 / 1E10)
12510 LET F4 = INT((F2 - F3 * 1E10) / 1E5)
12515 LET F5 = F2 - F3 * 1E10 - F4 * 1E5
12520 IF H7 = 0 THEN 12540
12525 LET F3 = 9 - F3
12530 IF F3 < 7 THEN 12540
12535 LET F3 = F3 - 6
12540 LET X6 = F4
12545 GOSUB 13045
12550 LET V3 = S4
12555 LET V4 = T4
12560 LET V5 = S5
12565 LET V6 = T5
12570 LET X6 = F5
12575 GOSUB 13045
12580 LET O3 = -1
12585 LET O4 = 0
12590 LET O5 = -1
12595 LET O6 = 0
12600 LET L2 = -1
12605 LET L3 = 0
12610 LET L5 = -1
12615 LET L6 = 0
12620 ON F3 GOTO 12625, 12890, 12670, 12735, 12760, 12825
12625 LET O3 = S4
12630 LET O4 = T4
12635 LET O5 = S5
12640 LET O6 = T5
12645 LET L2 = V3
12650 LET L3 = V4
12655 LET L5 = V5
12660 LET L6 = V6
12665 GOTO 12845
12670 LET S2 = S5
12675 LET T2 = T5
12680 LET H6 = -1
12685 GOSUB 13355
12690 LET O5 = S2
12695 LET O6 = T2
12700 LET S2 = V3
12705 LET T2 = V4
12710 LET H6 = 1
12715 GOSUB 13355
12720 LET L2 = S2
12725 LET L3 = T2
12730 GOTO 12845
12735 LET O5 = S5
12740 LET O6 = T5
12745 LET L2 = V3
12750 LET L3 = V4
12755 GOTO 12845
12760 LET S2 = S4
12765 LET T2 = T4
12770 LET H6 = 1
12775 GOSUB 13355
12780 LET O3 = S2
12785 LET O4 = T2
12790 LET S2 = V5
12795 LET T2 = V6
12800 LET H6 = -1
12805 GOSUB 13355
12810 LET L5 = S2
12815 LET L6 = T2
12820 GOTO 12845
12825 LET O3 = S4
12830 LET O4 = T4
12835 LET L5 = V5
12840 LET L6 = V6
12845 LET X6 = F4
12850 GOSUB 14195
12855 LET O3 = L2
12860 LET O4 = L3
12865 LET O5 = L5
12870 LET O6 = L6
12875 LET X6 = F5
12880 GOSUB 14195
12885 RETURN
12890 REM B a single bound b: A.lo = b gives b + 1, A.hi = b gives b - 1 (a plain A only)
12895 IF S4 < 0 THEN 7080
12900 IF S4 <> S5 THEN 7080
12905 IF T4 <> T5 THEN 7080
12910 IF R(F4, 1) <> 1 THEN 7080
12915 IF R(F4, 6) <> 0 THEN 7080
12920 LET Z2 = V3
12925 LET Z3 = V4
12930 LET Z4 = V5
12935 LET Z5 = V6
12940 IF V3 <> S4 THEN 12980
12945 IF V4 <> T4 THEN 12980
12950 LET S2 = S4
12955 LET T2 = T4
12960 LET H6 = 1
12965 GOSUB 13355
12970 LET Z2 = S2
12975 LET Z3 = T2
12980 IF V5 <> S4 THEN 13020
12985 IF V6 <> T4 THEN 13020
12990 LET S2 = S4
12995 LET T2 = T4
13000 LET H6 = -1
13005 GOSUB 13355
13010 LET Z4 = S2
13015 LET Z5 = T2
13020 LET X6 = F4
13025 GOSUB 13965
13030 RETURN
13035 REM ---- helpers of the facts --------------------------------------------------------------
13040 REM IVL: the interval (S4,T4) (S5,T5) of i register X6 as read here
13045 IF R(X6, 1) <> 1 THEN 13140
13050 IF R(X6, 6) = 1 THEN 13085
13055 IF R(X6, 6) = 2 THEN 13110
13060 LET S4 = R(X6, 2)
13065 LET T4 = R(X6, 3)
13070 LET S5 = R(X6, 4)
13075 LET T5 = R(X6, 5)
13080 RETURN
13085 LET S4 = X6
13090 LET T4 = 0
13095 LET S5 = X6
13100 LET T5 = 0
13105 RETURN
13110 IF R(X6, 7) = N8 THEN 13140
13115 LET S4 = 0
13120 LET T4 = R(X6, 7)
13125 LET S5 = 0
13130 LET T5 = T4
13135 RETURN
13140 LET S4 = -1
13145 LET T4 = 0
13150 LET S5 = -1
13155 LET T5 = 0
13160 RETURN
13165 REM LU: L4, U4 = L and U of the symbol or pseudo-symbol S7
13170 IF S7 > 199999 THEN 13210
13175 IF S7 > 99999 THEN 13195
13180 LET L4 = R(S7, 2)
13185 LET U4 = R(S7, 3)
13190 RETURN
13195 LET L4 = R(S7 - 100000, 2)
13200 LET U4 = R(S7 - 100000, 3)
13205 RETURN
13210 LET L4 = R(S7 - 200000, 4)
13215 LET U4 = R(S7 - 200000, 5)
13220 RETURN
13225 REM LEQ: F0 = 1 when bound (S2,T2) <= bound (S3,T3) holds (DESIGN 5.8 Facts, L-au)
13230 LET F0 = 0
13235 IF S2 < 0 THEN 7080
13240 IF S3 < 0 THEN 7080
13245 IF S2 <> S3 THEN 13265
13250 IF T2 > T3 THEN 7080
13255 LET F0 = 1
13260 RETURN
13265 LET H3 = N8
13270 IF S2 = 0 THEN 13300
13275 LET S7 = S2
13280 GOSUB 13170
13285 IF U4 = N8 THEN 7080
13290 LET H3 = U4 + T2
13295 GOTO 13305
13300 LET H3 = T2
13305 LET H4 = T3
13310 IF S3 = 0 THEN 13335
13315 LET S7 = S3
13320 GOSUB 13170
13325 IF L4 = N8 THEN 7080
13330 LET H4 = L4 + T3
13335 IF H3 > H4 THEN 7080
13340 LET F0 = 1
13345 RETURN
13350 REM BADD: bound (S2,T2) moved by H6 (unknown outside -2^52 .. 2^52)
13355 IF S2 < 0 THEN 7080
13360 LET T2 = T2 + H6
13365 IF ABS(T2) <= U9 THEN 7080
13370 LET S2 = -1
13375 LET T2 = 0
13380 RETURN
13385 REM CBND: F0 = 1 when bound (S2,T2) has a constant value through L, U (L-av)
13390 LET F0 = 0
13395 IF S2 < 0 THEN 7080
13400 LET F0 = 1
13405 IF S2 = 0 THEN 7080
13410 LET S7 = S2
13415 GOSUB 13170
13420 IF L4 = N8 THEN 13430
13425 IF U4 <> N8 THEN 7080
13430 LET F0 = 0
13435 RETURN
13440 REM MAXI / MINI: the largest / smallest value of upper / lower bound (S2,T2) as (M0,M1): M0 -1
13445 REM unknown, 0 the value M1, 1 2^63 - 1 + M1 (resp. -2^63 + M1) for a symbol without U (L)
13450 LET M0 = -1
13455 LET M1 = 0
13460 IF S2 < 0 THEN 7080
13465 LET M0 = 0
13470 LET M1 = T2
13475 IF S2 = 0 THEN 7080
13480 LET S7 = S2
13485 GOSUB 13170
13490 IF U4 = N8 THEN 13505
13495 LET M1 = U4 + T2
13500 RETURN
13505 LET M0 = 1
13510 RETURN
13515 LET M0 = -1
13520 LET M1 = 0
13525 IF S2 < 0 THEN 7080
13530 LET M0 = 0
13535 LET M1 = T2
13540 IF S2 = 0 THEN 7080
13545 LET S7 = S2
13550 GOSUB 13170
13555 IF L4 = N8 THEN 13570
13560 LET M1 = L4 + T2
13565 RETURN
13570 LET M0 = 1
13575 RETURN
13580 REM NMAXI / NMINI: the same for -x, x having lower / upper bound (S2,T2); M0 = 2: 2^63 + M1
13585 REM (resp. -2^63 + 1 + M1) for a symbol without L (U)
13590 LET M0 = -1
13595 LET M1 = 0
13600 IF S2 < 0 THEN 7080
13605 LET M0 = 0
13610 LET M1 = -T2
13615 IF S2 = 0 THEN 7080
13620 LET S7 = S2
13625 GOSUB 13170
13630 IF L4 = N8 THEN 13645
13635 LET M1 = -(L4 + T2)
13640 RETURN
13645 LET M0 = 2
13650 RETURN
13655 LET M0 = -1
13660 LET M1 = 0
13665 IF S2 < 0 THEN 7080
13670 LET M0 = 0
13675 LET M1 = -T2
13680 IF S2 = 0 THEN 7080
13685 LET S7 = S2
13690 GOSUB 13170
13695 IF U4 = N8 THEN 13710
13700 LET M1 = -(U4 + T2)
13705 RETURN
13710 LET M0 = 2
13715 RETURN
13720 REM SUMHI / SUMLO: F0 = 1 when (M0,M1) plus the constant M3 (M2 = 0) stays <= 2^63 - 1 / >= -2^63
13725 LET F0 = 0
13730 IF M0 < 0 THEN 7080
13735 LET F0 = 1
13740 IF M0 = 0 THEN 7080
13745 IF M1 + M3 <= 1 - M0 THEN 7080
13750 LET F0 = 0
13755 RETURN
13760 LET F0 = 0
13765 IF M0 < 0 THEN 7080
13770 LET F0 = 1
13775 IF M0 = 0 THEN 7080
13780 IF M1 + M3 >= 1 - M0 THEN 7080
13785 LET F0 = 0
13790 RETURN
13795 REM LOG: before register X6's state changes in a scope, its old state goes on the trail
13800 IF D1 = 0 THEN 7080
13805 IF R(X6, 0) = S1 THEN 7080
13810 IF D5 + 1 >= D6 THEN 13855
13815 LET D5 = D5 + 1
13820 LET W(D5, 0) = R(X6, 0) * 100000 + X6
13825 LET W(D5, 1) = R(X6, 2)
13830 LET W(D5, 2) = R(X6, 3)
13835 LET W(D5, 3) = R(X6, 4)
13840 LET W(D5, 4) = R(X6, 5)
13845 LET R(X6, 0) = S1
13850 RETURN
13855 LET X5 = 1
13860 RETURN
13865 REM PUSHS: register X6 and its state on the save stack
13870 IF D6 - 1 <= D5 THEN 13855
13875 LET D6 = D6 - 1
13880 LET W(D6, 0) = X6
13885 LET W(D6, 1) = R(X6, 2)
13890 LET W(D6, 2) = R(X6, 3)
13895 LET W(D6, 3) = R(X6, 4)
13900 LET W(D6, 4) = R(X6, 5)
13905 RETURN
13910 REM UNDO: back to trail mark H7
13915 IF D5 <= H7 THEN 7080
13920 LET X6 = W(D5, 0) - INT(W(D5, 0) / 100000) * 100000
13925 LET R(X6, 0) = INT(W(D5, 0) / 100000)
13930 LET R(X6, 2) = W(D5, 1)
13935 LET R(X6, 3) = W(D5, 2)
13940 LET R(X6, 4) = W(D5, 3)
13945 LET R(X6, 5) = W(D5, 4)
13950 LET D5 = D5 - 1
13955 GOTO 13915
13960 REM SETV: register X6's state becomes Z2 Z3 Z4 Z5 (logged when it changes)
13965 IF R(X6, 2) <> Z2 THEN 13985
13970 IF R(X6, 3) <> Z3 THEN 13985
13975 IF R(X6, 4) <> Z4 THEN 13985
13980 IF R(X6, 5) = Z5 THEN 7080
13985 GOSUB 13800
13990 LET R(X6, 2) = Z2
13995 LET R(X6, 3) = Z3
14000 LET R(X6, 4) = Z4
14005 LET R(X6, 5) = Z5
14010 RETURN
14015 REM UNK: i register X6 is written by something F1-F3 does not describe
14020 IF R(X6, 6) = 2 THEN 7080
14025 LET Z2 = -1
14030 LET Z3 = 0
14035 LET Z4 = -1
14040 LET Z5 = 0
14045 IF R(X6, 6) = 0 THEN 14070
14050 LET Z2 = N8
14055 LET Z3 = N8
14060 LET Z4 = R(X6, 4)
14065 LET Z5 = R(X6, 5)
14070 GOSUB 13965
14075 RETURN
14080 REM SETRES: i register X6 is defined with the interval (S4,T4) (S5,T5); a symbol keeps [s, s]
14085 REM and takes the constant bounds as L(s), U(s)
14090 IF R(X6, 1) <> 1 THEN 7080
14095 IF R(X6, 6) = 2 THEN 7080
14100 IF R(X6, 6) = 1 THEN 14135
14105 LET Z2 = S4
14110 LET Z3 = T4
14115 LET Z4 = S5
14120 LET Z5 = T5
14125 GOSUB 13965
14130 RETURN
14135 LET Z2 = N8
14140 LET Z3 = N8
14145 IF S4 <> 0 THEN 14155
14150 LET Z2 = T4
14155 IF S5 <> 0 THEN 14165
14160 LET Z3 = T5
14165 LET Z4 = R(X6, 4)
14170 LET Z5 = R(X6, 5)
14175 GOSUB 13965
14180 RETURN
14185 REM NREG: register X6 narrowed by the candidates (O3,O4) (lower) and (O5,O6) (upper), sym < 0
14190 REM for none; a symbol by its constant candidates in L, U; a constant not at all
14195 IF R(X6, 1) <> 1 THEN 7080
14200 IF R(X6, 6) = 2 THEN 7080
14205 LET Z2 = R(X6, 2)
14210 LET Z3 = R(X6, 3)
14215 LET Z4 = R(X6, 4)
14220 LET Z5 = R(X6, 5)
14225 IF R(X6, 6) = 1 THEN 14340
14230 IF O3 < 0 THEN 14280
14235 IF Z2 < 0 THEN 14270
14240 LET S2 = Z2
14245 LET T2 = Z3
14250 LET S3 = O3
14255 LET T3 = O4
14260 GOSUB 13230
14265 IF F0 = 0 THEN 14280
14270 LET Z2 = O3
14275 LET Z3 = O4
14280 IF O5 < 0 THEN 14330
14285 IF Z4 < 0 THEN 14320
14290 LET S2 = O5
14295 LET T2 = O6
14300 LET S3 = Z4
14305 LET T3 = Z5
14310 GOSUB 13230
14315 IF F0 = 0 THEN 14330
14320 LET Z4 = O5
14325 LET Z5 = O6
14330 GOSUB 13965
14335 RETURN
14340 IF O3 <> 0 THEN 14360
14345 IF Z2 = N8 THEN 14355
14350 IF O4 <= Z2 THEN 14360
14355 LET Z2 = O4
14360 IF O5 <> 0 THEN 14330
14365 IF Z3 = N8 THEN 14375
14370 IF O6 >= Z3 THEN 14330
14375 LET Z3 = O6
14380 GOTO 14330
14385 REM NL / NU: L / U of the symbol or pseudo-symbol S7 narrowed by the constant H6
14390 GOSUB 13170
14395 IF L4 = N8 THEN 14405
14400 IF H6 <= L4 THEN 7080
14405 LET L4 = H6
14410 GOTO 14440
14415 GOSUB 13170
14420 IF U4 = N8 THEN 14430
14425 IF H6 >= U4 THEN 7080
14430 LET U4 = H6
14435 REM PUTLU: L4, U4 become L and U of S7
14440 LET X6 = S7
14445 LET H4 = 2
14450 IF S7 <= 99999 THEN 14475
14455 LET X6 = S7 - 100000
14460 IF S7 <= 199999 THEN 14475
14465 LET X6 = S7 - 200000
14470 LET H4 = 4
14475 LET Z2 = R(X6, 2)
14480 LET Z3 = R(X6, 3)
14485 LET Z4 = R(X6, 4)
14490 LET Z5 = R(X6, 5)
14495 IF H4 = 4 THEN 14520
14500 LET Z2 = L4
14505 LET Z3 = U4
14510 GOSUB 13965
14515 RETURN
14520 LET Z4 = L4
14525 LET Z5 = U4
14530 GOSUB 13965
14535 RETURN
14540 REM ====================================================================================
14545 REM T2: division by constants (DESIGN 5.8 T2, Decision 65, L-al, L-am; Decision 72)
14550 REM ====================================================================================
14555 GOSUB 69465
14560 GOSUB 16550
14565 GOSUB 8060
14567 GOSUB 69460
14570 REM the plan (I(n,0)): 1 % by 1, 2 idiv by 1, 3 % by 2^k, 4 idiv by 2^k, 5 % and 6 idiv by any
14575 REM other c >= 2, 7 fdiv by a normal power of two; the counts after it in U5 (instructions), U6
14580 REM (operands), U7 (registers), U8 (immediates); U0 = 1 when something is planned
14585 LET U5 = A0
14590 LET U6 = A1
14595 LET U7 = M7
14600 LET U8 = A2
14605 LET U0 = 0
14610 LET U1 = 0
14615 FOR N2 = 1 TO A0
14617 IF I(N2, 0) < 0 THEN 15000
14620 LET I(N2, 0) = 0
14625 LET X3 = Q(I(N2, 1), 6)
14630 IF X3 = 14 THEN 14650
14635 IF X3 = 15 THEN 14650
14640 IF X3 = 32 THEN 14860
14645 GOTO 15000
14650 LET X6 = O(I(N2, 2) + 2)
14655 LET X7 = 1
14660 GOSUB 15215
14665 IF X7 = 0 THEN 15000
14670 IF L(1) >= 32768 THEN 15000
14675 IF L(1) + L(2) + L(3) + L(4) = 0 THEN 15000
14680 IF L(1) + L(2) + L(3) <> 0 THEN 14720
14685 IF L(4) <> 1 THEN 14720
14690 LET X8 = 16 - X3
14695 LET D3 = 0
14700 LET D4 = -1
14705 LET D9 = 0
14710 LET V2 = X3 - 14
14715 GOTO 14930
14720 GOSUB 15275
14725 IF H5 < 0 THEN 14760
14730 LET X8 = 18 - X3
14735 LET D3 = 1
14740 LET D4 = 2
14745 LET D9 = 1
14750 LET V2 = 1
14755 GOTO 14930
14760 CALL "op_magic": L(), U(), V7
14765 LET X8 = 20 - X3
14770 LET D3 = 11
14775 LET D4 = 31
14780 LET D9 = 11
14785 LET V2 = 4
14790 IF X3 = 15 THEN 14815
14795 LET D3 = 12
14800 LET D4 = 33
14805 LET D9 = 12
14810 LET V2 = 5
14815 IF U(1) < 32768 THEN 14835
14820 LET D3 = D3 + 1
14825 LET D4 = D4 + 3
14830 LET D9 = D9 + 1
14835 IF V7 = 0 THEN 14930
14840 LET D3 = D3 + 1
14845 LET D4 = D4 + 3
14850 LET D9 = D9 + 1
14855 GOTO 14930
14860 LET X6 = O(I(N2, 2) + 2)
14865 LET X7 = 2
14870 GOSUB 15215
14875 IF X7 = 0 THEN 15000
14880 LET H3 = L(1) - INT(L(1) / 32768) * 32768
14885 IF H3 <> 16 * INT(H3 / 16) THEN 15000
14890 IF L(2) + L(3) + L(4) <> 0 THEN 15000
14895 IF H3 = 0 THEN 15000
14900 IF H3 = 32752 THEN 15000
14905 LET X8 = 7
14910 LET D3 = 1
14915 LET D4 = 2
14920 LET D9 = 1
14925 LET V2 = 1
14930 REM Decision 72: the instance is skipped when the function would exceed a limit (O: with U1)
14935 IF U5 + D3 > I9 THEN 15000
14940 IF U6 + U1 + D4 > O9 THEN 15000
14945 IF U7 + D9 > R9 THEN 15000
14950 IF U8 + V2 > M9 THEN 15000
14955 LET U5 = U5 + D3
14960 LET U6 = U6 + D4
14965 LET U7 = U7 + D9
14970 LET U8 = U8 + V2
14975 LET I(N2, 0) = X8
14980 LET U0 = 1
14985 IF X8 > 2 THEN 15000
14990 REM a replacement by 1 keeps its third operand slot empty, so the rebuild only moves up
14995 LET U1 = U1 + 1
15000 NEXT N2
15005 IF U0 = 0 THEN 7080
15010 REM the rebuild, from the end (only insertions now, so every move goes up)
15015 LET N3 = U5
15020 LET P4 = U6 + U1
15025 FOR N2 = A0 TO 1 STEP -1
15030 IF I(N2, 0) > 0 THEN 15100
15035 LET X3 = I(N2, 3)
15040 LET P3 = I(N2, 2)
15045 FOR X4 = X3 - 1 TO 0 STEP -1
15050 LET O(P4) = O(P3 + X4)
15055 LET P4 = P4 - 1
15060 NEXT X4
15065 LET I(N3, 1) = I(N2, 1)
15070 LET I(N3, 4) = I(N2, 4)
15075 LET I(N3, 0) = 0
15080 LET I(N3, 2) = P4 + 1
15085 LET I(N3, 3) = X3
15090 LET N3 = N3 - 1
15095 GOTO 15180
15100 IF I(N2, 0) > 2 THEN 15110
15105 LET P4 = P4 - 1
15110 GOSUB 15370
15115 FOR L8 = L7 TO 1 STEP -1
15120 LET X3 = Q(W(L8, 0), 4)
15125 FOR X4 = X3 TO 1 STEP -1
15130 LET O(P4) = W(L8, X4)
15135 LET P4 = P4 - 1
15140 NEXT X4
15145 LET I(N3, 1) = W(L8, 0)
15150 LET I(N3, 4) = 0
15155 LET I(N3, 0) = 0
15160 LET I(N3, 2) = P4 + 1
15165 LET I(N3, 3) = X3
15170 LET N3 = N3 - 1
15175 NEXT L8
15180 NEXT N2
15185 LET A0 = U5
15190 LET A1 = U6 + U1
15195 GOSUB 69455
15200 RETURN
15205 REM BLIMB: L(1..4) = the limbs of the immediate of X6's only definition when that is an li
15210 REM (X7 = 1) or an lf (X7 = 2); else X7 = 0
15215 IF R(X6, 8) <> 1 THEN 15260
15220 LET H3 = R(X6, 9)
15225 IF H3 <= 0 THEN 15260
15230 IF Q(I(H3, 1), 6) <> X7 THEN 15260
15235 LET H4 = O(I(H3, 2) + 1)
15240 FOR H5 = 1 TO 4
15245 LET L(H5) = C(H4, H5)
15250 NEXT H5
15255 RETURN
15260 LET X7 = 0
15265 RETURN
15270 REM POW2: H5 = k when L(1..4) is 2^k, else -1
15275 LET H5 = -1
15280 LET H6 = 0
15285 FOR H7 = 1 TO 4
15290 IF L(H7) = 0 THEN 15345
15295 IF H6 = 1 THEN 15355
15300 LET H6 = 1
15305 LET H8 = L(H7)
15310 LET H9 = 16 * (4 - H7)
15315 IF H8 = 1 THEN 15340
15320 IF H8 <> 2 * INT(H8 / 2) THEN 15355
15325 LET H8 = H8 / 2
15330 LET H9 = H9 + 1
15335 GOTO 15315
15340 LET H5 = H9
15345 NEXT H7
15350 RETURN
15355 LET H5 = -1
15360 RETURN
15365 REM T2SEQ: the replacement of instruction N2 in W(1..L7, 0..4) (row, then its operands)
15370 LET P3 = I(N2, 2)
15375 LET D3 = O(P3)
15380 LET D4 = O(P3 + 1)
15385 LET D9 = O(P3 + 2)
15390 LET L7 = 0
15395 LET X3 = I(N2, 0)
15400 IF X3 = 7 THEN 16270
15405 LET X6 = D9
15410 LET X7 = 1
15415 GOSUB 15215
15420 ON X3 GOTO 15425, 15465, 15490, 15590, 15680, 15680
15425 REM % by 1: li d 0
15430 GOSUB 16385
15435 LET H9 = 0
15440 GOSUB 16450
15445 LET H3 = E2
15450 LET H4 = D3
15455 LET H5 = H9
15460 GOTO 16510
15465 REM idiv by 1: mov d a
15470 LET H3 = E4
15475 LET H4 = D3
15480 LET H5 = D4
15485 GOTO 16510
15490 REM % by 2^k: li m c-1, iand d a m
15495 LET H5 = 4
15500 IF L(H5) > 0 THEN 15520
15505 LET L(H5) = 65535
15510 LET H5 = H5 - 1
15515 GOTO 15500
15520 LET L(H5) = L(H5) - 1
15525 GOSUB 16450
15530 LET H8 = 1
15535 GOSUB 16485
15540 LET U(1) = H9
15545 LET H3 = E2
15550 LET H4 = H9
15555 LET H5 = H2
15560 GOSUB 16510
15565 LET H3 = E9
15570 LET H4 = D3
15575 LET H5 = D4
15580 LET H6 = U(1)
15585 GOTO 16510
15590 REM idiv by 2^k: li m k, isar d a m
15595 GOSUB 15275
15600 LET V7 = H5
15605 GOSUB 16385
15610 LET L(4) = V7
15615 GOSUB 16450
15620 LET H8 = 1
15625 GOSUB 16485
15630 LET U(1) = H9
15635 LET H3 = E2
15640 LET H4 = H9
15645 LET H5 = H2
15650 GOSUB 16510
15655 LET H3 = G2
15660 LET H4 = D3
15665 LET H5 = D4
15670 LET H6 = U(1)
15675 GOTO 16510
15680 REM the multiply-high sequence; U(1..14): M H H2 S Q K N Q2 P R A O Z L
15685 CALL "op_magic": L(), U(), V7
15690 LET Q7 = U(1)
15695 LET Q8 = U(2)
15700 LET Z0 = U(3)
15705 LET Z1 = U(4)
15710 LET H8 = 1
15715 LET L(1) = Q7
15720 LET L(2) = Q8
15725 LET L(3) = Z0
15730 LET L(4) = Z1
15735 GOSUB 16450
15740 GOSUB 16485
15745 LET U(1) = H9
15750 LET H3 = E2
15755 LET H4 = H9
15760 LET H5 = H2
15765 GOSUB 16510
15770 GOSUB 16485
15775 LET U(2) = H9
15780 LET H3 = G3
15785 LET H4 = H9
15790 LET H5 = D4
15795 LET H6 = U(1)
15800 GOSUB 16510
15805 LET U(3) = U(2)
15810 IF Q7 < 32768 THEN 15850
15815 GOSUB 16485
15820 LET U(3) = H9
15825 LET H3 = E5
15830 LET H4 = H9
15835 LET H5 = U(2)
15840 LET H6 = D4
15845 GOSUB 16510
15850 GOSUB 16385
15855 LET L(4) = V7
15860 GOSUB 16405
15865 LET U(4) = H9
15870 LET U(5) = U(3)
15875 IF V7 = 0 THEN 15915
15880 GOSUB 16485
15885 LET U(5) = H9
15890 LET H3 = G2
15895 LET H4 = H9
15900 LET H5 = U(3)
15905 LET H6 = U(4)
15910 GOSUB 16510
15915 GOSUB 16385
15920 LET L(4) = 63
15925 GOSUB 16405
15930 LET U(6) = H9
15935 GOSUB 16485
15940 LET U(7) = H9
15945 LET H3 = G2
15950 LET H4 = H9
15955 LET H5 = D4
15960 LET H6 = U(6)
15965 GOSUB 16510
15970 GOSUB 16485
15975 LET U(8) = H9
15980 LET H3 = E6
15985 LET H4 = H9
15990 LET H5 = U(5)
15995 LET H6 = U(7)
16000 GOSUB 16510
16005 GOSUB 16485
16010 LET U(9) = H9
16015 LET H3 = E7
16020 LET H4 = H9
16025 LET H5 = U(8)
16030 LET H6 = D9
16035 GOSUB 16510
16040 GOSUB 16485
16045 LET U(10) = H9
16050 LET H3 = E6
16055 LET H4 = H9
16060 LET H5 = D4
16065 LET H6 = U(9)
16070 GOSUB 16510
16075 IF X3 = 6 THEN 16120
16080 GOSUB 16485
16085 LET U(11) = H9
16090 LET H3 = E5
16095 LET H4 = H9
16100 LET H5 = U(10)
16105 LET H6 = D9
16110 GOSUB 16510
16115 GOTO 16175
16120 GOSUB 16385
16125 LET L(4) = 1
16130 GOSUB 16405
16135 LET U(12) = H9
16140 GOSUB 16485
16145 LET U(11) = H9
16150 LET H3 = E6
16155 LET H4 = H9
16160 LET H5 = U(8)
16165 LET H6 = U(12)
16170 GOSUB 16510
16175 GOSUB 16385
16180 GOSUB 16405
16185 LET U(13) = H9
16190 GOSUB 16485
16195 LET U(14) = H9
16200 LET H3 = G4
16205 LET H4 = C6
16210 LET H5 = H9
16215 LET H6 = U(10)
16220 LET H7 = U(13)
16225 GOSUB 16510
16230 LET H3 = G5
16235 LET H4 = D3
16240 LET H5 = U(14)
16245 LET H6 = U(11)
16250 LET H7 = U(10)
16255 IF X3 = 5 THEN 16510
16260 LET H7 = U(8)
16265 GOTO 16510
16270 REM fdiv by +-2^e: lf R +-2^-e (2^-1023 subnormal), fmul d a R
16275 LET X6 = D9
16280 LET X7 = 2
16285 GOSUB 15215
16290 LET H3 = INT(L(1) / 32768)
16295 LET H4 = 2046 - (L(1) - 32768 * H3) / 16
16300 LET L(1) = 32768 * H3 + 16 * H4
16305 IF H4 > 0 THEN 16315
16310 LET L(1) = 32768 * H3 + 8
16315 GOSUB 16450
16320 LET H8 = 2
16325 GOSUB 16485
16330 LET U(1) = H9
16335 LET H3 = E3
16340 LET H4 = H9
16345 LET H5 = H2
16350 GOSUB 16510
16355 LET H3 = G8
16360 LET H4 = D3
16365 LET H5 = D4
16370 LET H6 = U(1)
16375 GOTO 16510
16380 REM SQ_L0: L(1..4) = 0; SQ_LI: li of L(1..4) into a new i register H9
16385 FOR H5 = 1 TO 4
16390 LET L(H5) = 0
16395 NEXT H5
16400 RETURN
16405 GOSUB 16450
16410 LET H8 = 1
16415 GOSUB 16485
16420 LET H3 = E2
16425 LET H4 = H9
16430 LET H5 = H2
16435 GOSUB 16510
16440 RETURN
16445 REM NEWC: a new row H2 of C holding L(1..4); NEWR: a new register H9 of class H8
16450 LET A2 = A2 + 1
16455 FOR H5 = 1 TO 4
16460 LET C(A2, H5) = L(H5)
16465 NEXT H5
16470 LET H2 = A2
16475 LET H9 = A2
16480 RETURN
16485 LET M7 = M7 + 1
16490 LET R(M7, 1) = H8
16495 LET H9 = M7
16500 RETURN
16505 REM EMIT: instruction row H3 with the operands H4 H5 H6 H7 joins the sequence
16510 LET L7 = L7 + 1
16515 LET W(L7, 0) = H3
16520 LET W(L7, 1) = H4
16525 LET W(L7, 2) = H5
16530 LET W(L7, 3) = H6
16535 LET W(L7, 4) = H7
16540 RETURN
16545 REM ---- CCOMP: the rows of C compacted to the li and lf instructions there are, in row order --
16550 FOR X4 = 1 TO A2
16555 LET W(X4, 3) = 0
16560 NEXT X4
16565 FOR N3 = 1 TO A0
16570 LET X3 = Q(I(N3, 1), 6)
16575 IF X3 > 2 THEN 16585
16580 LET W(O(I(N3, 2) + 1), 3) = 1
16585 NEXT N3
16590 LET H8 = 0
16595 FOR X4 = 1 TO A2
16600 IF W(X4, 3) = 0 THEN 16630
16605 LET H8 = H8 + 1
16610 FOR H5 = 1 TO 4
16615 LET C(H8, H5) = C(X4, H5)
16620 NEXT H5
16625 LET W(X4, 3) = H8
16630 NEXT X4
16635 FOR N3 = 1 TO A0
16640 LET X3 = Q(I(N3, 1), 6)
16645 IF X3 > 2 THEN 16660
16650 LET P4 = I(N3, 2) + 1
16655 LET O(P4) = W(O(P4), 3)
16660 NEXT N3
16665 LET A2 = H8
16670 RETURN
16865 REM ====================================================================================
16870 REM T3: value numbering in regions, load forwarding, copy propagation (DESIGN 5.8 T3, L-av)
16875 REM ====================================================================================
16880 GOSUB 8060
16885 FOR R2 = 1 TO M7
16890 LET R(R2, 0) = 0
16895 LET R(R2, 2) = 0
16900 LET R(R2, 3) = 0
16905 LET R(R2, 4) = 0
16910 LET R(R2, 5) = 0
16915 LET R(R2, 6) = 0
16920 LET R(R2, 7) = 0
16925 NEXT R2
16930 LET V0 = 2
16935 FOR N0 = 1 TO A0
16940 GOSUB 7175
16945 NEXT N0
16947 GOSUB 69460
16950 REM regions: I(n,0) = its region's number, 0 for a block record, exit, next, ret
16955 LET X4 = 0
16960 LET X6 = 0
16965 FOR N3 = 1 TO A0
16970 LET X3 = Q(I(N3, 1), 6)
16972 IF I(N3, 0) < 0 THEN 16990
16975 LET I(N3, 0) = 0
16980 IF X3 < 56 THEN 17000
16985 IF X3 > 66 THEN 17000
16990 LET X6 = 0
16995 GOTO 17020
17000 IF X6 = 1 THEN 17015
17005 LET X4 = X4 + 1
17010 LET X6 = 1
17015 LET I(N3, 0) = X4
17020 NEXT N3
17025 REM array registers (R(r,6) = 1) and private bases (R(r,6) = 2): candidates R(r,7) = 1, the
17030 REM slot of an sa candidate in R(r,5)
17035 GOSUB 8195
17040 FOR R2 = 1 TO M7
17045 IF R(R2, 1) <> 3 THEN 17085
17050 IF R(R2, 6) = 1 THEN 17085
17055 IF R(R2, 8) < 1 THEN 17085
17060 LET R(R2, 7) = 1
17065 IF R2 > M(5) THEN 17085
17070 IF R(R2, 8) <> 1 THEN 17080
17075 GOTO 17085
17080 LET R(R2, 7) = -1
17085 NEXT R2
17090 FOR N3 = 1 TO A0
17095 LET X3 = Q(I(N3, 1), 6)
17100 IF X3 <> 4 THEN 17150
17105 LET X6 = O(I(N3, 2))
17110 IF R(X6, 7) <> 1 THEN 17180
17115 IF X6 <= M(5) THEN 17180
17120 IF R(X6, 5) = 0 THEN 17140
17125 IF R(X6, 5) = O(I(N3, 2) + 1) THEN 17180
17130 LET R(X6, 7) = -1
17135 GOTO 17180
17140 LET R(X6, 5) = O(I(N3, 2) + 1)
17145 GOTO 17180
17150 REM any other definition of a candidate that is not a parameter removes it
17155 LET N0 = N3
17160 LET H3 = -1
17165 LET H4 = -1
17170 LET H5 = 0
17175 GOSUB 17430
17180 NEXT N3
17185 LET V0 = 13
17190 FOR N0 = 1 TO A0
17195 GOSUB 7175
17200 NEXT N0
17205 FOR R2 = 1 TO M7
17210 LET R(R2, 5) = 0
17215 IF R(R2, 7) <> 1 THEN 17225
17220 LET R(R2, 6) = 2
17225 LET R(R2, 7) = 0
17230 NEXT R2
17235 REM the walk; H0 the first record of the current region; trackers: U(31..34) the last store
17240 REM of kind 1..4 whose base is not private, V6 the last retain release call rcall, V7 the last
17245 REM mcopy call rcall, R(B,5) the last store with the private base B
17250 FOR X4 = 31 TO 34
17255 LET U(X4) = 0
17260 NEXT X4
17265 LET V6 = 0
17270 LET V7 = 0
17275 LET H0 = 1
17280 FOR N4 = 1 TO A0
17285 IF I(N4, 0) > 0 THEN 17300
17290 LET H0 = N4 + 1
17295 GOTO 17415
17300 LET P5 = I(N4, 2)
17305 LET X4 = Q(I(N4, 1), 7)
17310 IF X4 = 0 THEN 17335
17315 IF X4 > 2 THEN 17330
17320 GOSUB 17545
17325 GOTO 17335
17330 GOSUB 18020
17335 LET X3 = Q(I(N4, 1), 6)
17340 IF X3 = 71 THEN 17380
17345 IF X3 = 72 THEN 17380
17350 IF X3 = 67 THEN 17375
17355 IF X3 = 68 THEN 17375
17360 IF X3 <> 55 THEN 17385
17365 LET V7 = N4
17370 GOTO 17385
17375 LET V7 = N4
17380 LET V6 = N4
17385 IF X3 <> 5 THEN 17395
17390 GOSUB 18555
17395 IF I(N4, 1) = 0 THEN 17415
17400 LET N0 = N4
17405 LET V0 = 12
17410 GOSUB 7175
17415 NEXT N4
17420 RETURN
17425 REM T3S_D: candidate registers written by instruction N0 (other than sa) are removed
17430 LET P0 = I(N0, 2)
17435 LET W9 = I(N0, 1)
17440 FOR J9 = 1 TO Q(W9, 4)
17445 LET B3 = Q(W9, 3) + J9 - 1
17450 LET R0 = F(B3, 0)
17455 IF R0 = 0 THEN 17530
17460 LET J0 = 1
17465 IF F(B3, 3) = 0 THEN 17475
17470 LET J0 = U(F(B3, 3))
17475 FOR J8 = 1 TO J0
17480 IF R0 <> 2 THEN 17500
17485 IF O(P0) = 0 THEN 17500
17490 IF R(O(P0), 7) <> 1 THEN 17500
17495 LET R(O(P0), 7) = -1
17500 IF R0 <> 5 THEN 17510
17505 LET U(J9) = O(P0)
17510 LET P0 = P0 + 1
17515 IF R0 <> 7 THEN 17525
17520 LET P0 = P0 + 1
17525 NEXT J8
17530 NEXT J9
17535 RETURN
17540 REM ---- R1: an equal earlier pure (or checked arithmetic) instruction of the region ---------
17545 LET B7 = I(N4, 1)
17550 LET H3 = B7
17555 LET X7 = 0
17560 FOR J2 = 1 TO Q(B7, 4)
17565 LET B8 = F(Q(B7, 3) + J2 - 1, 0)
17570 IF B8 = 0 THEN 17665
17575 IF B8 <> 2 THEN 17590
17580 LET X7 = O(P5 + J2 - 1)
17585 GOTO 17665
17590 LET X8 = O(P5 + J2 - 1)
17595 IF B8 = 3 THEN 17620
17600 IF B8 = 4 THEN 17645
17605 LET H3 = H3 * 31 + X8
17610 LET H3 = H3 - INT(H3 / 399989) * 399989
17615 GOTO 17665
17620 FOR H4 = 1 TO 4
17625 LET H3 = H3 * 31 + C(X8, H4)
17630 LET H3 = H3 - INT(H3 / 399989) * 399989
17635 NEXT H4
17640 GOTO 17665
17645 FOR H4 = 0 TO 3
17650 LET H3 = H3 * 31 + G(X8, H4)
17655 LET H3 = H3 - INT(H3 / 399989) * 399989
17660 NEXT H4
17665 NEXT J2
17670 REM probe the table (W columns 0, 1): an entry is Y2*1E6 + n + 0.5
17675 LET H7 = 0
17680 LET H4 = W(INT(H3 / 2), H3 - 2 * INT(H3 / 2) + H7)
17685 GOSUB 17845
17690 IF H6 = 0 THEN 17830
17695 LET N0 = H6
17700 GOSUB 17890
17705 IF F0 = 1 THEN 17730
17710 LET H3 = H3 + 1
17715 IF H3 < 399989 THEN 17680
17720 LET H3 = 0
17725 GOTO 17680
17730 REM valid when no operand was written at or after H6 and its destination only at H6
17735 FOR J2 = 1 TO Q(B7, 4)
17740 LET B8 = F(Q(B7, 3) + J2 - 1, 0)
17745 IF B8 <> 1 THEN 17755
17750 IF R(O(P5 + J2 - 1), 0) >= H6 THEN 17830
17755 NEXT J2
17760 LET X8 = 0
17765 LET H8 = I(H6, 2)
17770 FOR J2 = 1 TO Q(B7, 4)
17775 IF F(Q(B7, 3) + J2 - 1, 0) <> 2 THEN 17785
17780 LET X8 = O(H8 + J2 - 1)
17785 NEXT J2
17790 IF R(X8, 0) <> H6 THEN 17830
17795 REM the instruction becomes mov D D0
17800 LET I(N4, 1) = E4
17805 LET I(N4, 3) = 2
17810 LET I(N4, 4) = 0
17815 LET O(P5) = X7
17820 LET O(P5 + 1) = X8
17825 RETURN
17830 LET W(INT(H3 / 2), H3 - 2 * INT(H3 / 2) + H7) = Y2 * 1E6 + N4 + 0.5
17835 RETURN
17840 REM HENT: H6 = the instruction of table entry H4 when it is of this function and region, else 0
17845 LET H6 = 0
17850 IF H4 - INT(H4) <> 0.5 THEN 7080
17855 IF INT(H4 / 1E6) <> Y2 THEN 7080
17860 LET H5 = INT(H4) - Y2 * 1E6
17865 IF H5 < H0 THEN 7080
17870 IF H5 >= N4 THEN 7080
17875 LET H6 = H5
17880 RETURN
17885 REM EQ1: F0 = 1 when instruction N0 equals N4 in every field but the destination and site
17890 LET F0 = 0
17895 IF I(N0, 1) <> B7 THEN 7080
17900 IF I(N0, 3) <> I(N4, 3) THEN 7080
17905 LET H8 = I(N0, 2)
17910 FOR J2 = 1 TO Q(B7, 4)
17915 LET B8 = F(Q(B7, 3) + J2 - 1, 0)
17920 IF B8 = 0 THEN 17995
17925 IF B8 = 2 THEN 17995
17930 LET X8 = O(P5 + J2 - 1)
17935 LET H5 = O(H8 + J2 - 1)
17940 IF B8 = 3 THEN 17960
17945 IF B8 = 4 THEN 17980
17950 IF X8 <> H5 THEN 7080
17955 GOTO 17995
17960 FOR H4 = 1 TO 4
17965 IF C(X8, H4) <> C(H5, H4) THEN 7080
17970 NEXT H4
17975 GOTO 17995
17980 FOR H4 = 0 TO 3
17985 IF G(X8, H4) <> G(H5, H4) THEN 7080
17990 NEXT H4
17995 NEXT J2
18000 LET F0 = 1
18005 RETURN
18010 REM ---- R2: a load at the location of an earlier load or store of the region; stores enter
18015 REM the table (W columns 2, 3) -------------------------------------------------------------
18020 LET B7 = I(N4, 1)
18025 LET X8 = O(P5 + 4)
18030 LET H3 = Q(B7, 8)
18035 LET H3 = H3 * 31 + O(P5 + 1)
18040 LET H3 = H3 * 31 + O(P5 + 2)
18045 LET H3 = H3 * 31 + O(P5 + 3)
18050 LET H3 = H3 - INT(H3 / 399989) * 399989
18055 FOR H4 = 0 TO 3
18060 LET H3 = H3 * 31 + G(X8, H4)
18065 LET H3 = H3 - INT(H3 / 399989) * 399989
18070 NEXT H4
18075 LET H7 = 2
18080 LET H4 = W(INT(H3 / 2), H3 - 2 * INT(H3 / 2) + H7)
18085 GOSUB 17845
18090 IF H6 = 0 THEN 18270
18095 LET H8 = I(H6, 2)
18100 IF Q(I(H6, 1), 8) <> Q(B7, 8) THEN 18140
18105 IF O(H8 + 1) <> O(P5 + 1) THEN 18140
18110 IF O(H8 + 2) <> O(P5 + 2) THEN 18140
18115 IF O(H8 + 3) <> O(P5 + 3) THEN 18140
18120 FOR H4 = 0 TO 3
18125 IF G(O(H8 + 4), H4) <> G(X8, H4) THEN 18140
18130 NEXT H4
18135 GOTO 18160
18140 LET H3 = H3 + 1
18145 IF H3 < 399989 THEN 18080
18150 LET H3 = 0
18155 GOTO 18080
18160 REM same location at H6 (H8 its operands): a store only replaces it in the table
18165 LET X3 = O(P5 + 1)
18170 IF Q(B7, 7) = 3 THEN 18200
18175 IF R(X3, 6) <> 2 THEN 18190
18180 LET R(X3, 5) = N4
18185 GOTO 18270
18190 LET U(30 + Q(B7, 8)) = N4
18195 GOTO 18270
18200 IF R(X3, 0) >= H6 THEN 18270
18205 IF O(P5 + 2) = 0 THEN 18215
18210 IF R(O(P5 + 2), 0) >= H6 THEN 18270
18215 IF R(O(H8), 0) > H6 THEN 18270
18220 GOSUB 18315
18225 IF F0 = 1 THEN 18270
18230 LET X8 = O(H8)
18235 LET X7 = O(P5)
18240 LET I(N4, 1) = E4
18245 LET I(N4, 3) = 2
18250 LET I(N4, 4) = 0
18255 LET O(P5) = X7
18260 LET O(P5 + 1) = X8
18265 RETURN
18270 LET W(INT(H3 / 2), H3 - 2 * INT(H3 / 2) + H7) = Y2 * 1E6 + N4 + 0.5
18275 IF Q(B7, 7) = 3 THEN 7080
18280 REM a store not met before: its tracker
18285 IF R(O(P5 + 1), 6) <> 2 THEN 18300
18290 LET R(O(P5 + 1), 5) = N4
18295 RETURN
18300 LET U(30 + Q(B7, 8)) = N4
18305 RETURN
18310 REM CLOB: F0 = 1 when an instruction after H6 and before N4 may change the load N4
18315 LET F0 = 0
18320 LET X3 = O(P5 + 1)
18325 LET X4 = O(P5 + 4)
18330 LET X6 = 1E30
18335 IF G(X4, 0) <> 0 THEN 18350
18340 IF G(X4, 1) <> 0 THEN 18350
18345 LET X6 = G(X4, 2) * 65536 + G(X4, 3)
18350 IF R(X3, 6) = 2 THEN 18410
18355 IF R(X3, 6) <> 1 THEN 18395
18360 IF O(P5 + 2) <> 0 THEN 18395
18365 IF X6 = K6 THEN 7080
18370 IF X6 = K7 THEN 7080
18375 IF X6 = K8 THEN 7080
18380 IF X6 <> K9 THEN 18395
18385 IF V6 > H6 THEN 18515
18390 RETURN
18395 IF U(30 + Q(B7, 8)) > H6 THEN 18515
18400 IF V7 > H6 THEN 18515
18405 RETURN
18410 REM a private location: a store with the same base whose bytes overlap
18415 IF R(X3, 5) <= H6 THEN 7080
18420 LET X6 = 8
18425 IF Q(B7, 8) <> 2 THEN 18435
18430 LET X6 = 1
18435 LET H4 = O(P5 + 4)
18440 GOSUB 18530
18445 LET X4 = H5
18450 FOR L8 = H6 + 1 TO N4 - 1
18455 IF Q(I(L8, 1), 7) <> 4 THEN 18505
18460 IF O(I(L8, 2) + 1) <> X3 THEN 18505
18465 LET H4 = O(I(L8, 2) + 4)
18470 GOSUB 18530
18475 LET X7 = 8
18480 IF Q(I(L8, 1), 8) <> 2 THEN 18490
18485 LET X7 = 1
18490 IF X4 >= H5 + X7 THEN 18505
18495 IF H5 >= X4 + X6 THEN 18505
18500 GOTO 18515
18505 NEXT L8
18510 RETURN
18515 LET F0 = 1
18520 RETURN
18525 REM OFFV: H5 = the value of the off field in row H4 of G (two's complement)
18530 LET H5 = ((G(H4, 0) * 65536 + G(H4, 1)) * 65536 + G(H4, 2)) * 65536 + G(H4, 3)
18535 IF G(H4, 0) < 32768 THEN 7080
18540 LET H5 = H5 - 2 ^ 64
18545 RETURN
18550 REM ---- R3: copy propagation of the mov at N4 ------------------------------------------------
18555 LET D3 = O(P5)
18560 LET S3 = O(P5 + 1)
18565 IF D3 = S3 THEN 7080
18570 IF R(D3, 8) <> 1 THEN 7080
18575 IF R(D3, 2) = 0 THEN 18685
18580 IF R(D3, 3) <= N4 THEN 7080
18585 LET X4 = R(D3, 4)
18590 IF I(X4, 0) <> I(N4, 0) THEN 7080
18595 REM S3 not written after the mov and before the last read of D3
18600 LET V0 = 3
18605 FOR L8 = N4 + 1 TO X4 - 1
18610 LET N0 = L8
18615 LET H3 = S3
18620 LET H4 = -1
18625 LET H5 = 0
18630 GOSUB 7175
18635 IF H5 = 1 THEN 7080
18640 NEXT L8
18645 LET V0 = 8
18650 FOR L8 = N4 + 1 TO X4
18655 LET N0 = L8
18660 GOSUB 7175
18665 NEXT L8
18670 LET R(S3, 2) = R(S3, 2) + R(D3, 2) - 1
18675 IF R(S3, 4) >= X4 THEN 18685
18680 LET R(S3, 4) = X4
18685 LET I(N4, 1) = 0
18690 RETURN
18695 REM ====================================================================================
18700 REM T4: if-conversion of the one-mov shapes (DESIGN 5.8 T4); a selection reading its destination only under L-bq
18705 REM ====================================================================================
18710 GOSUB 69460
18711 GOSUB 18960
18712 LET N2 = 1
18715 IF N2 > A0 THEN 7080
18720 LET X3 = Q(I(N2, 1), 6)
18722 IF I(N2, 0) < 0 THEN 18940
18725 IF X3 < 60 THEN 18940
18730 IF X3 > 61 THEN 18940
18735 IF N2 + 2 > A0 THEN 18940
18740 IF Q(I(N2 + 1, 1), 6) <> 5 THEN 18940
18745 LET P4 = I(N2, 2)
18750 LET B5 = O(P4)
18755 LET H3 = O(P4 + 1)
18760 LET H4 = O(I(N2 + 1, 2))
18765 LET H5 = O(I(N2 + 1, 2) + 1)
18770 LET H6 = H4
18775 LET X7 = 2
18780 IF Q(I(N2 + 2, 1), 6) <> 63 THEN 18795
18785 IF O(I(N2 + 2, 2)) = B5 THEN 18840
18790 GOTO 18940
18795 IF Q(I(N2 + 2, 1), 6) <> 62 THEN 18940
18800 IF O(I(N2 + 2, 2)) <> B5 THEN 18940
18805 IF N2 + 4 > A0 THEN 18940
18810 IF Q(I(N2 + 3, 1), 6) <> 5 THEN 18940
18815 IF O(I(N2 + 3, 2)) <> H4 THEN 18940
18820 IF Q(I(N2 + 4, 1), 6) <> 63 THEN 18940
18825 IF O(I(N2 + 4, 2)) <> B5 THEN 18940
18830 LET H6 = O(I(N2 + 3, 2) + 1)
18835 LET X7 = 4
18840 REM sel R c S1 S2 (if) or sel R c S2 S1 (ifz); one mov: S2 is R
18841 IF X7 = 4 THEN 18845
18842 GOSUB 19063
18843 IF P6 = 0 THEN 18940
18845 IF X3 = 60 THEN 18865
18850 LET H7 = H5
18855 LET H5 = H6
18860 LET H6 = H7
18865 LET I(N2, 1) = G5
18870 IF R(H4, 1) = 1 THEN 18890
18875 LET I(N2, 1) = G6
18880 IF R(H4, 1) = 2 THEN 18890
18885 LET I(N2, 1) = G7
18890 LET I(N2, 3) = 4
18895 LET I(N2, 4) = 0
18900 LET O(P4) = H4
18905 LET O(P4 + 1) = H3
18910 LET O(P4 + 2) = H5
18915 LET O(P4 + 3) = H6
18920 FOR X4 = 1 TO X7
18925 LET I(N2 + X4, 1) = 0
18930 NEXT X4
18933 GOSUB 19020
18935 LET N2 = N2 + X7
18937 GOTO 18942
18940 GOSUB 19020
18942 LET N2 = N2 + 1
18945 GOTO 18715
18950 REM T4I: the parts (T6 the depth of the innermost open part, W(d,0) the serial of the part at depth d,
18952 REM W(d,1) for an else part the serial of its first part, T7 the last serial; depth 0 the body)
18954 REM and R(r,3..6) of every register (CB9, CB10) before the walk of T4
18960 LET T6 = 0
18962 LET T7 = 1
18964 LET W(0, 0) = 1
18966 LET W(0, 1) = 0
18968 FOR R2 = 1 TO M7
18970 LET R(R2, 3) = 0
18972 LET R(R2, 4) = 0
18974 LET R(R2, 5) = 0
18976 LET R(R2, 6) = 0
18978 NEXT R2
18980 LET V0 = 10
18982 FOR N0 = 1 TO A0
18984 GOSUB 7175
18986 NEXT N0
18988 RETURN
19015 REM T4T: record N2 as T4 leaves it: its writes (CB9) in the parts open before it, then the part it
19017 REM opens (loop do if ifz), turns into the else part (else) or closes (endloop enddo endif)
19020 LET N0 = N2
19022 LET V0 = 9
19024 GOSUB 7175
19026 LET T8 = Q(I(N2, 1), 6)
19028 IF T8 = 56 THEN 19046
19030 IF T8 = 58 THEN 19046
19032 IF T8 = 60 THEN 19046
19034 IF T8 = 61 THEN 19046
19036 IF T8 = 62 THEN 19054
19038 IF T8 = 57 THEN 19044
19040 IF T8 = 59 THEN 19044
19042 IF T8 <> 63 THEN 7080
19044 LET T6 = T6 - 1
19045 RETURN
19046 LET T6 = T6 + 1
19048 LET W(T6, 1) = 0
19050 GOTO 19056
19054 LET W(T6, 1) = W(T6, 0)
19056 LET T7 = T7 + 1
19058 LET W(T6, 0) = T7
19059 RETURN
19061 REM T4C (L-bq): P6 = 1 when the selection of the if at N2 may read its destination H4: H4 is a
19062 REM parameter, or is read nowhere after the endif, or has an earlier write whose effective part is open
19063 LET P6 = 1
19064 IF H4 <= M(5) THEN 7080
19066 IF R(H4, 6) <= N2 + 2 THEN 7080
19068 IF R(H4, 3) = 0 THEN 19076
19070 IF R(H4, 3) - 1 > T6 THEN 19076
19072 IF W(R(H4, 3) - 1, 0) <> R(H4, 4) THEN 19076
19074 RETURN
19076 LET P6 = 0
19078 RETURN
19300 REM ---- DYNPAR (T1, DESIGN 5.8 Terms, L-ba): R(A,4) = 1 when a chkb's extent is the result of
19305 REM ldi ... A - 0 SEA_ARR_ROWS (or SEA_ARR_COLS); R(A,5) = 1 when an ldp D A - 0 SEA_ARR_DATA
19310 REM has its D as the base of a load or store with an idx. Locals N3 X3 P4 X6 X4 X7 X8 H7 H8.
19315 FOR R2 = 1 TO M7
19320 LET R(R2, 4) = 0
19325 LET R(R2, 5) = 0
19330 NEXT R2
19335 FOR N3 = 1 TO A0
19340 LET X3 = Q(I(N3, 1), 6)
19345 LET P4 = I(N3, 2)
19350 IF X3 = 69 THEN 19395
19355 REM an indexed load or store (ldi .. stp): its base defined once by ldp at the data offset
19360 IF X3 < 47 THEN 19425
19365 IF X3 > 54 THEN 19425
19370 IF O(P4 + 2) = 0 THEN 19425
19375 LET X6 = O(P4 + 1)
19380 LET H7 = 50
19385 GOSUB 19440
19387 IF X7 <> K8 THEN 19425
19390 LET R(X4, 5) = 1
19392 GOTO 19425
19395 REM chkb I E: E defined once by ldi at the rows or cols offset
19400 LET X6 = O(P4 + 1)
19405 LET H7 = 47
19410 GOSUB 19440
19412 IF X7 = K6 THEN 19420
19415 IF X7 <> K7 THEN 19425
19420 LET R(X4, 4) = 1
19425 NEXT N3
19430 RETURN
19435 REM DEFLD: X4 = the base and X7 the offset when X6's one definition is a load of opcode H7
19437 REM without idx at a non-negative offset below 2^32 (else X7 = -1)
19440 LET X7 = -1
19445 IF R(X6, 8) <> 1 THEN 7080
19450 LET X8 = R(X6, 9)
19455 IF X8 <= 0 THEN 7080
19460 IF Q(I(X8, 1), 6) <> H7 THEN 7080
19465 LET H8 = I(X8, 2)
19470 IF O(H8 + 2) <> 0 THEN 7080
19475 LET X8 = O(H8 + 4)
19480 IF G(X8, 0) <> 0 THEN 7080
19485 IF G(X8, 1) <> 0 THEN 7080
19490 LET X7 = G(X8, 2) * 65536 + G(X8, 3)
19495 LET X4 = O(H8 + 1)
19500 RETURN
58000 REM ---- op_magic: the magic number of DESIGN 5.8 T2 (Hacker's Delight 10-1, 64-bit signed; L-am)
58005 REM C(1..4): the divisor c, 16-bit limbs, most significant first, 3 <= c < 2^63, not 2^k.
58010 REM M(1..4): M = floor(2^p / c) + 1; S = p - 64, p the least integer >= 64 with
58015 REM 2^p > nc * (c - 2^p mod c), nc = 2^63 - 1 - (2^63 mod c). Numbers here: 8 limbs (128 bits).
58020 REM Locals: D c, R a remainder, Q a quotient, N nc, T c - R, A the product, B 2^p.
58025 SUB "op_magic": C(), M(), S
58030 DIM A(8), B(8), D(8), N(8), Q(8), R(8), T(8)
58035 FOR I = 1 TO 8
58040 LET D(I) = 0
58045 LET R(I) = 0
58050 LET Q(I) = 0
58055 NEXT I
58060 FOR I = 1 TO 4
58065 LET D(I + 4) = C(I)
58070 NEXT I
58075 REM R = 2^63 mod c
58080 LET R(8) = 1
58085 FOR K = 1 TO 63
58090 GOSUB 58520
58095 NEXT K
58100 REM N = 2^63 - 1 - R
58105 LET N(1) = 0
58110 LET N(2) = 0
58115 LET N(3) = 0
58120 LET N(4) = 0
58125 LET N(5) = 32767
58130 LET N(6) = 65535
58135 LET N(7) = 65535
58140 LET N(8) = 65535
58145 LET Y = 0
58150 FOR I = 8 TO 1 STEP -1
58155 LET N(I) = N(I) - R(I) - Y
58160 LET Y = 0
58165 IF N(I) >= 0 THEN 58180
58170 LET N(I) = N(I) + 65536
58175 LET Y = 1
58180 NEXT I
58185 REM Q = floor(2^64 / c), R = 2^64 mod c
58190 FOR I = 1 TO 8
58195 LET R(I) = 0
58200 NEXT I
58205 LET R(8) = 1
58210 FOR K = 1 TO 64
58215 GOSUB 58460
58220 NEXT K
58225 LET P = 64
58230 REM T = c - R, A = N * T, B = 2^P
58235 LET Y = 0
58240 FOR I = 8 TO 1 STEP -1
58245 LET T(I) = D(I) - R(I) - Y
58250 LET Y = 0
58255 IF T(I) >= 0 THEN 58270
58260 LET T(I) = T(I) + 65536
58265 LET Y = 1
58270 NEXT I
58275 FOR I = 1 TO 8
58280 LET A(I) = 0
58285 LET B(I) = 0
58290 NEXT I
58295 FOR I = 5 TO 8
58300 FOR J = 5 TO 8
58305 LET A(I + J - 8) = A(I + J - 8) + N(I) * T(J)
58310 NEXT J
58315 NEXT I
58320 FOR I = 8 TO 2 STEP -1
58325 LET Y = INT(A(I) / 65536)
58330 LET A(I) = A(I) - Y * 65536
58335 LET A(I - 1) = A(I - 1) + Y
58340 NEXT I
58345 LET I = 8 - INT(P / 16)
58350 LET B(I) = 2 ^ (P - 16 * INT(P / 16))
58355 REM 2^P > A ends the search
58360 FOR I = 1 TO 8
58365 IF B(I) > A(I) THEN 58395
58370 IF B(I) < A(I) THEN 58380
58375 NEXT I
58380 LET P = P + 1
58385 GOSUB 58460
58390 GOTO 58230
58395 REM M = Q + 1
58400 LET Y = 1
58405 FOR I = 8 TO 5 STEP -1
58410 LET Q(I) = Q(I) + Y
58415 LET Y = 0
58420 IF Q(I) < 65536 THEN 58435
58425 LET Q(I) = Q(I) - 65536
58430 LET Y = 1
58435 LET M(I - 4) = Q(I)
58440 NEXT I
58445 LET S = P - 64
58450 GOTO 58635
58455 REM MG_Q2: Q = 2Q, R = 2R; when R >= c, R = R - c and Q = Q + 1. MG_R2: the same for R only
58460 LET Y = 0
58465 FOR I = 8 TO 1 STEP -1
58470 LET Q(I) = Q(I) * 2 + Y
58475 LET Y = 0
58480 IF Q(I) < 65536 THEN 58495
58485 LET Q(I) = Q(I) - 65536
58490 LET Y = 1
58495 NEXT I
58500 GOSUB 58520
58505 IF Z = 0 THEN 58630
58510 LET Q(8) = Q(8) + 1
58515 RETURN
58520 LET Y = 0
58525 FOR I = 8 TO 1 STEP -1
58530 LET R(I) = R(I) * 2 + Y
58535 LET Y = 0
58540 IF R(I) < 65536 THEN 58555
58545 LET R(I) = R(I) - 65536
58550 LET Y = 1
58555 NEXT I
58560 LET Z = 0
58565 FOR I = 1 TO 8
58570 IF R(I) > D(I) THEN 58585
58575 IF R(I) < D(I) THEN 58630
58580 NEXT I
58585 LET Z = 1
58590 LET Y = 0
58595 FOR I = 8 TO 1 STEP -1
58600 LET R(I) = R(I) - D(I) - Y
58605 LET Y = 0
58610 IF R(I) >= 0 THEN 58625
58615 LET R(I) = R(I) + 65536
58620 LET Y = 1
58625 NEXT I
58630 RETURN
58635 SUBEND
