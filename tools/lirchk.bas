100 REM ====================================================================================
105 REM lirchk -- validator of sea.lir, the vector classes and the LF records included (DESIGN
110 REM 2.6.3, 2.12.6; Decision 116, L-gk). A Baysick program built like a pass: this file
115 REM (lines 100-59999), the modules io diag tables and the shared main-program part lirrw,
120 REM the generated DATA blocks errors exits consts entries records, then 99999 END
125 REM (tools/lirchk.build.list). It is a tool of the test harness (tests/run.sh and
130 REM tests/stage.sh run it on every sea.lir they produce), not a compiler pass, and is not
135 REM gated by make check-limits.
140 REM USAGE   the file to check is sea.lir in the working directory (the name lirrw's input
145 REM         has; Baysick has no command-line arguments). Example: ( cd DIR && lirchk )
150 REM FLOW    lirrw (passes/lib/lirrw.bas, contract in passes/lib/API.md) reads and validates
155 REM         every function and data record of sea.lir with V8 = 3, the input kind that alone
160 REM         accepts the register classes x y m and the set-LF records, and checks them: lane
165 REM         counts, vfeat only on x86_64-linux, no vector or mask register as a parameter,
170 REM         argument, result or chk argument, and the field rules of every other record
175 REM         (DESIGN 2.12.6). Nothing is transformed and nothing is written: lirrw's copy of
180 REM         the header and data records goes to the second file, /dev/null.
185 REM EXIT    0 the file is valid (nothing is printed); 11 it is not: lirrw's failure, one
190 REM         line on standard error, "lirchk: internal error: bad record" (a truncated
195 REM         file: "lirchk: ... truncated input"; a capacity limit: status 10, "program too
200 REM         large"). lirrw prints no detail of a rejection (L-gp): the harness names the file.
205 REM TABLES  the DIMs below are lirrw's contract (24 numeric and 14 string array letters,
210 REM         its reserved scalars); the numeric array letters S and V are not used.
215 REM ====================================================================================
360 FILES "sea.lir"; "/dev/null"
365 DIM E(299), E$(299,5), N(39,2), N$(39), W$(299), Q(399,9), Q$(399), F(1499,3), F$(1499), Z(8)
370 DIM J(299,4), J$(299), Y(399), Y$(399,5), D(39), D$(39), B(399), A(399)
375 DIM I(199999,4), O(799999), R(99999,9), K(19999,4), C(199999,4), S$(199999)
380 DIM X(131071), T(10000), G$(300), U(40), L(4), H$(100), A$(2)
382 DIM M(301), P(262143), H(199999), V$(49999), U$(131071), G(199999,3), W(199999,4)
385 LET P$ = "lirchk"
386 LET V8 = 3
390 REM ---- the main program: lirrw's entries (passes/lib/API.md), reading only -----------------
395 GOSUB 69400
400 GOSUB 69410
405 IF Y0 < 0 THEN 420
410 REM a function is complete and validated (its endfunc included): the next one
415 GOTO 400
420 GOSUB 69420
425 STOP
