82000 REM fltlit.bas: float literal -> binary64 bits (needs limb); lines 82000-88999; API: API-arith.md
82010 SUB "FLCVT": S$,R3,R2,R1,R0,E ' float_lit -> binary64; E 1 out of range, 2 invalid, 3 > 4096 bytes
82020     DIM M(1400),D(1400),Q(20)
82030     LET L = LEN(S$)
82040     LET W3 = 0
82050     LET W2 = 0
82060     LET W1 = 0
82070     LET W0 = 0
82080     LET Z = 3
82090     IF L > 4096 THEN 83180
82100     LET Z = 2
82110     LET M(0) = 0
82120     LET C = 0 ' current chunk of up to 9 digits, K digits in it
82130     LET K = 0
82140     LET N = 0 ' significant digits pushed into M (with C)
82150     LET Y = 0 ' zeros after the last nonzero digit, not yet pushed
82160     LET F = 0 ' digits after the point
82170     LET H = 0 ' 1 after the point
82180     LET I = 1
82190     IF I > L THEN 83180
82200     LET X = ASC(SEG$(S$,I,I))-48
82210     IF X < 0 THEN 83180
82220     IF X > 9 THEN 83180 ' digits start with a digit
82230     IF I > L THEN 82350
82240     LET T = ASC(SEG$(S$,I,I))
82250     IF T = 95 THEN 82330
82260     LET X = T-48
82270     IF X < 0 THEN 82350
82280     IF X > 9 THEN 82350
82290     LET F = F+H
82300     GOSUB 83290
82310     LET I = I+1
82320     GOTO 82230
82330     LET I = I+1
82340     GOTO 82230
82350     IF SEG$(S$,I-1,I-1) = "_" THEN 83180 ' _ before . or e or at the end
82360     IF I > L THEN 82420
82370     IF T <> 46 THEN 82420
82380     IF H = 1 THEN 83180
82390     LET H = 1
82400     LET I = I+1
82410     GOTO 82190
82420     LET G = 1
82430     LET Q = 0
82440     IF I > L THEN 82650
82450     IF T = 69 THEN 82470
82460     IF T <> 101 THEN 83180
82470     LET I = I+1
82480     IF I > L THEN 83180
82490     LET T = ASC(SEG$(S$,I,I))
82500     IF T = 43 THEN 82530
82510     IF T <> 45 THEN 82540
82520     LET G = -1
82530     LET I = I+1
82540     IF I > L THEN 83180
82550     LET X = ASC(SEG$(S$,I,I))-48
82560     IF X < 0 THEN 83180
82570     IF X > 9 THEN 83180
82580     IF Q >= 1E8 THEN 82610
82590     LET Q = Q*10+X
82600     GOTO 82620
82610     LET Q = 1E9 ' far beyond every range below
82620     LET I = I+1
82630     IF I <= L THEN 82550
82640     GOTO 82660
82650     IF H = 0 THEN 83180 ' neither . nor exponent: an int_lit
82660     IF K = 0 THEN 82720
82670     LET P = 1
82680     FOR J = 1 TO K
82690         LET P = P*10
82700     NEXT J
82710     CALL "LBMAD": M(),P,C
82720     LET Z = 0
82730     IF N = 0 THEN 83180 ' zero: +0
82740     LET D = G*Q-F+Y ' value = M * 10^D, M has N digits
82750     IF N+D <= -324 THEN 83180 ' below 1E-324 < 2^-1075: +0
82760     IF N-1+D < 309 THEN 82800
82770     LET Z = 1 ' at least 1E309: infinity
82780     LET W3 = 32752
82790     GOTO 83180
82800     IF D < 0 THEN 82930
82810     LET T = 0
82820     IF D-T < 9 THEN 82860
82830     CALL "LBMAD": M(),1E9,0
82840     LET T = T+9
82850     GOTO 82820
82860     LET P = 1
82870     FOR J = 1 TO D-T
82880         LET P = P*10
82890     NEXT J
82900     CALL "LBMAD": M(),P,0
82910     CALL "LBTOF": M(),0,0,0,W3,W2,W1,W0,V
82920     GOTO 83160
82930     CALL "LBSET": D(),1 ' D() = 10^-D
82940     LET T = 0
82950     IF -D-T < 9 THEN 82990
82960     CALL "LBMAD": D(),1E9,0
82970     LET T = T+9
82980     GOTO 82950
82990     LET P = 1
83000     FOR J = 1 TO -D-T
83010         LET P = P*10
83020     NEXT J
83030     CALL "LBMAD": D(),P,0
83040     CALL "LBLEN": M(),N1
83050     CALL "LBLEN": D(),N2
83060     LET S = 55+N2-N1 ' quotient M*2^S/D() >= 2^54
83070     IF S < 0 THEN 83100
83080     CALL "LBSHL": M(),S
83090     GOTO 83110
83100     CALL "LBSHL": D(),-S
83110     CALL "LBDIV": M(),D(),Q()
83120     LET T = 0
83130     IF M(0) = 0 THEN 83150
83140     LET T = 1
83150     CALL "LBTOF": Q(),-S,0,T,W3,W2,W1,W0,V
83160     IF V < 2 THEN 83180
83170     LET Z = 1
83180     IF Z < 2 THEN 83230
83190     LET W3 = 0
83200     LET W2 = 0
83210     LET W1 = 0
83220     LET W0 = 0
83230     LET R3 = W3
83240     LET R2 = W2
83250     LET R1 = W1
83260     LET R0 = W0
83270     LET E = Z
83280     GOTO 83510
83290     IF X > 0 THEN 83330
83300     IF N+K = 0 THEN 83500
83310     LET Y = Y+1
83320     GOTO 83500
83330     IF Y = 0 THEN 83430
83340     LET C = C*10
83350     LET K = K+1
83360     LET N = N+1
83370     LET Y = Y-1
83380     IF K < 9 THEN 83330
83390     CALL "LBMAD": M(),1E9,C
83400     LET C = 0
83410     LET K = 0
83420     GOTO 83330
83430     LET C = C*10+X
83440     LET K = K+1
83450     LET N = N+1
83460     IF K < 9 THEN 83500
83470     CALL "LBMAD": M(),1E9,C
83480     LET C = 0
83490     LET K = 0
83500     RETURN
83510 SUBEND
