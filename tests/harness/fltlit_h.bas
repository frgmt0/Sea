10 REM fltlit harness (tests/arith_check.sh): reads tests/vectors/float.txt on standard input
20 REM (literal, bits, status) and prints every literal with the bits and status of FLCVT.
30 IF END #0 THEN 140
40 LINPUT #0, L$
50 LET P = POS(L$," ")
60 IF P = 0 THEN 120
70 LET S$ = SEG$(L$,1,P-1)
80 CALL "FLCVT": S$,R3,R2,R1,R0,E
90 CALL "LMHEX": R3,R2,R1,R0,R$
100 PRINT S$ & " " & R$ & " " & STR$(E)
110 GOTO 30
120 PRINT "malformed vector: " & L$
130 GOTO 30
140 STOP
