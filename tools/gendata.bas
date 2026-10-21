10 REM GENDATA -- the DATA generator of Sea (docs/DESIGN.md 2.6.2, 2.6.3).
11 REM A Baysick program: reads Sea's contract files, writes DATA lines to stdout.
12 REM
13 REM FILES (Baysick names files at compile time, so the program is run in a
14 REM directory that holds them under these names; the build runs it in sea/include):
15 REM    file 1 limits.inc   file 2 errors.inc   file 3 rt.inc   file 4 passes.txt   file 5 math_tables.inc
16 REM
17 REM STANDARD INPUT = the selection: one block name per line, each block at most
18 REM once, in the order  errors errno exits consts entries records mtab.
19 REM    errors   error records of errors.inc          (file 2)
20 REM    errno    errno records of errors.inc          (file 2)
21 REM    exits    SEA_EXIT_ constants of errors.inc    (file 2)
22 REM    consts   constants of limits.inc then rt.inc  (files 1, 3), one table
23 REM    entries  SEA_ENTRY_LIST records of rt.inc     (file 3)
24 REM    records  enum, head, rec lines of passes.txt  (file 4)
25 REM    mtab     the pow words of math_tables.inc     (file 5): sea_mt_const exp log, 8 per line
26 REM STANDARD OUTPUT = the DATA lines of the selected blocks, numbered
27 REM consecutively from 89000 across the blocks; each table ends with its sentinel.
28 REM A malformed record, an over-long DATA line (255 bytes, line number included),
29 REM a bad selection or a missing file: message on stderr, exit status 1.
30 REM Variables: N next line number; K file; G line count of the file read;
31 REM L$ input line; R$ rest of a record; W$ field; S$ in / E$ out of ENC;
32 REM D$ statement text of the DATA line being built; Z$ record id; M$ message;
33 REM X$ file name; O result flag of the validators; M() limbs of a constant.
100 FILES "limits.inc"; "errors.inc"; "rt.inc"; "passes.txt"; "math_tables.inc"
110 DIM C(1)
120 DIM M(3)
130 DIM S(7)
140 REM the quote character cannot be written in a string constant
150 LET C(0)=1
160 LET C(1)=34
170 CHANGE C TO Q$
180 LET H$="0123456789ABCDEF"
190 LET N=89000
200 LET P0=0
210 LET X$="standard input"
220 LET G=0
230 LET Z$=""
240 IF END #0 THEN 440
250 LINPUT #0, L$
260 LET G=G+1
270 REM rank of the requested block name
280 RESTORE
290 LET P=0
300 FOR I=1 TO 7
310 READ A$
320 IF L$<>A$ THEN 340
325 IF LEN(L$)<>LEN(A$) THEN 340
330 LET P=I
340 NEXT I
350 IF P>0 THEN 380
360 LET M$="unknown block "&Q$&L$&Q$
370 GOTO 900
380 IF P>P0 THEN 410
390 LET M$="each block at most once, in the order errors errno exits consts entries records mtab"
400 GOTO 900
410 LET P0=P
420 LET S(P)=1
430 GOTO 240
440 REM end of the selection: generate the selected blocks in rank order
441 IF G>0 THEN 446
442 LET M$="empty selection (no block named on standard input)"
444 GOTO 900
446 FOR I=1 TO 7
448 IF S(I)=0 THEN 484
450 ON I GOTO 452,456,460,464,468,472,476
452 GOSUB 6000
453 GOTO 484
456 GOSUB 6100
457 GOTO 484
460 GOSUB 6200
461 GOTO 484
464 GOSUB 6300
465 GOTO 484
468 GOSUB 6800
469 GOTO 484
472 GOSUB 6400
473 GOTO 484
476 GOSUB 6900
477 GOTO 484
484 NEXT I
486 GOTO 9999
500 REM ---- validators: W$ in, O out (1 = valid) ----
501 REM ISDEC: canonical decimal, optional leading minus, 1..9 digits, no leading zero
502 LET O=0
503 IF LEN(W$)=0 THEN 529
504 LET A1=1
505 IF SEG$(W$,1,1)<>"-" THEN 507
506 LET A1=2
507 LET B1=LEN(W$)-A1+1
508 IF B1<1 THEN 529
509 IF B1>9 THEN 529
510 LET C1=A1
511 IF C1>LEN(W$) THEN 520
512 LET Y8=ASC(SEG$(W$,C1,C1))
513 IF Y8<48 THEN 529
514 IF Y8>57 THEN 529
515 LET C1=C1+1
516 GOTO 511
520 IF ASC(SEG$(W$,A1,A1))<>48 THEN 528
521 IF B1>1 THEN 529
522 IF A1=2 THEN 529
528 LET O=1
529 RETURN
550 REM ISNAME: one or more of A-Z 0-9 _
551 LET O=0
552 IF LEN(W$)=0 THEN 579
553 LET A2=1
554 IF A2>LEN(W$) THEN 578
555 LET C2=ASC(SEG$(W$,A2,A2))
556 IF C2<48 THEN 579
557 IF C2<=57 THEN 575
558 IF C2<65 THEN 579
559 IF C2<=90 THEN 575
560 IF C2<>95 THEN 579
575 LET A2=A2+1
576 GOTO 554
578 LET O=1
579 RETURN
580 REM ISTOK: one or more bytes 0x21..0x7E other than quote and comma
581 LET O=0
582 IF LEN(W$)=0 THEN 599
583 LET A2=1
584 IF A2>LEN(W$) THEN 597
585 LET C2=ASC(SEG$(W$,A2,A2))
586 IF C2<33 THEN 599
587 IF C2>126 THEN 599
588 IF C2=34 THEN 599
589 IF C2=44 THEN 599
590 LET A2=A2+1
591 GOTO 584
597 LET O=1
599 RETURN
600 REM SPLIT: R$ = field ", " rest  ->  W$ = field, R$ = rest
601 LET P=POS(R$,", ")
602 IF P>0 THEN 606
603 LET M$="too few fields in the record"
604 GOTO 900
606 LET W$=SEG$(R$,1,P-1)
607 LET R$=SEG$(R$,P+2,LEN(R$))
608 RETURN
700 REM ENC: S$ -> E$, a quoted DATA string (DESIGN 2.6.2): bytes 0x21..0x7E other
701 REM than % and quote as themselves, every other byte %XX, empty string %.
702 REM U=1: S$ is the inside of a quoted record text, where \" is quote and \\ is backslash.
703 LET E$=""
704 LET J=1
705 IF J>LEN(S$) THEN 760
706 LET Y=ASC(SEG$(S$,J,J))
707 IF U=0 THEN 718
708 IF Y=34 THEN 780
709 IF Y<>92 THEN 718
710 LET J=J+1
711 IF J>LEN(S$) THEN 785
712 LET Y=ASC(SEG$(S$,J,J))
713 IF Y=34 THEN 718
714 IF Y=92 THEN 718
715 GOTO 790
718 IF Y<33 THEN 730
719 IF Y>126 THEN 730
720 IF Y=37 THEN 730
721 IF Y=34 THEN 730
722 LET E$=E$&SEG$(S$,J,J)
723 GOTO 750
730 LET Y1=INT(Y/16)
731 LET Y2=Y-16*Y1
732 LET E$=E$&"%"&SEG$(H$,Y1+1,Y1+1)&SEG$(H$,Y2+1,Y2+1)
750 LET J=J+1
751 GOTO 705
760 IF LEN(E$)>0 THEN 765
762 LET E$="%"
765 LET E$=Q$&E$&Q$
766 RETURN
780 LET M$="unescaped quote inside a record text"
781 GOTO 900
785 LET M$="record text ends in a lone backslash"
786 GOTO 900
790 LET M$="bad escape in a record text (only backslash-quote and backslash-backslash)"
791 GOTO 900
800 REM EMIT: write "<N> <D$>" to stdout and count the line
801 IF N<=99998 THEN 805
802 LET M$="more DATA lines than the range 89000..99998 holds"
803 GOTO 900
805 LET A$=STR$(N)&" "&D$
806 IF LEN(A$)<=255 THEN 810
807 LET M$="generated DATA line is "&STR$(LEN(A$))&" bytes, more than 255"
808 GOTO 900
810 PRINT A$
811 LET N=N+1
812 RETURN
900 REM FAIL: M$ message, X$ file, G line, Z$ record id (may be empty)
901 IF LEN(Z$)=0 THEN 904
902 LET M$=M$&" (record "&Z$&")"
904 PRINT #-1, "gendata: "&X$&":"&STR$(G)&": "&M$
905 STOP 1
3000 REM NUMF: next field must be a decimal number; appended to D$ as is, then a comma
3001 GOSUB 600
3002 GOSUB 500
3003 IF O=1 THEN 3007
3004 LET M$="field is not a canonical decimal number: "&W$
3005 GOTO 900
3007 IF LEN(Z$)>0 THEN 3010
3008 LET Z$=W$
3010 LET D$=D$&W$&","
3011 RETURN
3100 REM NAMEF: next field must be a name (A-Z 0-9 _); appended as a DATA string, then a comma
3101 GOSUB 600
3102 GOSUB 550
3103 IF O=1 THEN 3107
3104 LET M$="field is not a name: "&W$
3105 GOTO 900
3107 LET S$=W$
3108 LET U=0
3109 GOSUB 700
3110 LET D$=D$&E$&","
3111 RETURN
3200 REM TOKF: next field must be a token (printable, no quote or comma); as a DATA string, then a comma
3201 GOSUB 600
3202 GOSUB 580
3203 IF O=1 THEN 3207
3204 LET M$="field is empty or has a forbidden byte: "&W$
3205 GOTO 900
3207 LET S$=W$
3208 LET U=0
3209 GOSUB 700
3210 LET D$=D$&E$&","
3211 RETURN
3300 REM TXTF: the rest R$ must be a quoted text; \" and \\ unescaped, then DATA-escaped; last field
3301 IF LEN(R$)>=2 THEN 3305
3302 LET M$="text field missing or not quoted"
3303 GOTO 900
3305 IF ASC(SEG$(R$,1,1))<>34 THEN 3302
3306 IF ASC(SEG$(R$,LEN(R$),LEN(R$)))<>34 THEN 3302
3307 LET S$=SEG$(R$,2,LEN(R$)-1)
3308 LET U=1
3309 GOSUB 700
3310 LET D$=D$&E$
3311 RETURN
3400 REM LASTF: the rest R$ is the last field, a token; as a DATA string
3401 IF POS(R$,", ")=0 THEN 3405
3402 LET M$="too many fields in the record"
3403 GOTO 900
3405 LET W$=R$
3406 GOSUB 580
3407 IF O=1 THEN 3411
3408 LET M$="last field is empty or has a forbidden byte: "&W$
3409 GOTO 900
3411 LET S$=W$
3412 LET U=0
3413 GOSUB 700
3414 LET D$=D$&E$
3415 RETURN
4000 REM CPARSE: L$ begins with a prefix of P9 bytes (".equiv SEA_" or ".equiv SEA_EXIT_").
4001 REM Recognises NAME ", " blanks VALUE [blanks /* ... */]; O=1 with N8$, V$ set.
4002 REM O=0: not a constant line (no name, or no comma after it, or an include guard
4003 REM SEA_..._INC); a recognised constant with a bad tail stops the program.
4004 LET O=0
4005 LET A3=P9+1
4006 IF A3>LEN(L$) THEN 4099
4007 LET C3=ASC(SEG$(L$,A3,A3))
4008 IF C3<48 THEN 4020
4009 IF C3<=57 THEN 4015
4010 IF C3<65 THEN 4020
4011 IF C3<=90 THEN 4015
4012 IF C3=95 THEN 4015
4013 GOTO 4020
4015 LET A3=A3+1
4016 GOTO 4006
4020 IF A3=P9+1 THEN 4099
4021 IF C3<>44 THEN 4099
4022 LET N8$=SEG$(L$,P9+1,A3-1)
4023 IF LEN(N8$)<4 THEN 4026
4024 IF SEG$(N8$,LEN(N8$)-3,LEN(N8$))="_INC" THEN 4099
4026 LET A3=A3+1
4027 LET B3=A3
4028 IF A3>LEN(L$) THEN 4033
4029 IF ASC(SEG$(L$,A3,A3))<>32 THEN 4033
4030 LET A3=A3+1
4031 GOTO 4028
4033 IF A3>B3 THEN 4037
4034 LET M$="a constant needs a blank after the comma, then its value"
4035 GOTO 900
4037 LET B3=A3
4038 IF A3>LEN(L$) THEN 4043
4039 IF ASC(SEG$(L$,A3,A3))=32 THEN 4043
4040 LET A3=A3+1
4041 GOTO 4038
4043 LET V$=SEG$(L$,B3,A3-1)
4044 IF LEN(V$)>0 THEN 4048
4045 LET M$="a constant has no value"
4046 GOTO 900
4048 IF A3>LEN(L$) THEN 4060
4049 IF ASC(SEG$(L$,A3,A3))<>32 THEN 4053
4050 LET A3=A3+1
4051 GOTO 4048
4053 IF SEG$(L$,A3,A3+1)<>"/*" THEN 4057
4054 IF LEN(L$)-A3<3 THEN 4057
4055 IF SEG$(L$,LEN(L$)-1,LEN(L$))="*/" THEN 4060
4057 LET M$="text after a constant is not a /* ... */ comment"
4058 GOTO 900
4060 LET O=1
4099 RETURN
4200 REM CONSFILE: every constant of file K as a consts DATA line
4201 RESTORE #K
4202 LET G=0
4203 IF END #K THEN 4230
4204 LINPUT #K, L$
4205 LET G=G+1
4206 IF POS(L$,".equiv SEA_")<>1 THEN 4203
4207 LET P9=11
4208 GOSUB 4000
4209 IF O=0 THEN 4203
4210 LET Z$=N8$
4211 GOSUB 4400
4212 LET S$=N8$
4213 LET U=0
4214 GOSUB 700
4215 LET D$="DATA "&E$&","&STR$(M(3))&","&STR$(M(2))&","&STR$(M(1))&","&STR$(M(0))
4216 GOSUB 800
4217 LET Z$=""
4218 LET C9=C9+1
4219 GOTO 4203
4230 RETURN
4400 REM LIMB: V$ (decimal with optional minus, or 0x and upper-case hexadecimal digits)
4401 REM -> the 64-bit two's-complement pattern in M(3) .. M(0), 16 bits each, M(3) the top
4402 FOR A4=0 TO 3
4403 LET M(A4)=0
4404 NEXT A4
4405 IF SEG$(V$,1,2)="0x" THEN 4460
4406 LET N9=0
4407 LET A5=1
4408 IF SEG$(V$,1,1)<>"-" THEN 4412
4409 LET N9=1
4410 LET A5=2
4412 IF A5<=LEN(V$) THEN 4416
4413 LET M$="constant has no digits: "&V$
4414 GOTO 900
4416 LET C5=ASC(SEG$(V$,A5,A5))
4417 IF C5<48 THEN 4425
4418 IF C5>57 THEN 4425
4419 LET F9=10
4420 LET D9=C5-48
4421 GOSUB 4600
4422 LET A5=A5+1
4423 IF A5<=LEN(V$) THEN 4416
4424 GOTO 4428
4425 LET M$="constant is not a decimal or upper-case 0x hexadecimal number: "&V$
4426 GOTO 900
4428 REM range: a positive decimal is below 2^63, a negative one at least -2^63
4429 IF M(3)<32768 THEN 4435
4430 IF N9=0 THEN 4452
4431 IF M(3)<>32768 THEN 4452
4432 IF M(2)+M(1)+M(0)<>0 THEN 4452
4435 IF N9=0 THEN 4442
4436 LET C4=1
4437 FOR B4=0 TO 3
4438 LET T4=65535-M(B4)+C4
4439 LET C4=INT(T4/65536)
4440 LET M(B4)=T4-65536*C4
4441 NEXT B4
4442 RETURN
4452 LET M$="decimal constant does not fit 64 bits: "&V$
4453 GOTO 900
4460 IF LEN(V$)>=3 THEN 4464
4462 GOTO 4413
4464 IF LEN(V$)<=18 THEN 4467
4465 LET M$="hexadecimal constant has more than 16 digits: "&V$
4466 GOTO 900
4467 LET A5=3
4468 LET C5=ASC(SEG$(V$,A5,A5))
4469 IF C5<48 THEN 4425
4470 IF C5<=57 THEN 4476
4471 IF C5<65 THEN 4425
4472 IF C5>70 THEN 4425
4473 LET D9=C5-55
4474 GOTO 4477
4476 LET D9=C5-48
4477 LET F9=16
4478 GOSUB 4600
4479 LET A5=A5+1
4480 IF A5<=LEN(V$) THEN 4468
4481 RETURN
4600 REM MULADD: M = M * F9 + D9 over the four limbs; a carry out of M(3) is an overflow
4601 LET C4=D9
4602 FOR B4=0 TO 3
4603 LET T4=M(B4)*F9+C4
4604 LET C4=INT(T4/65536)
4605 LET M(B4)=T4-65536*C4
4606 NEXT B4
4607 IF C4=0 THEN 4611
4608 LET M$="constant does not fit 64 bits: "&V$
4609 GOTO 900
4611 RETURN
5000 REM SCANM: records of the macro whose header line is H1$ in file K; T1 selects the
5001 REM record handler (1 error, 2 errno, 3 entry). Inside the macro every line is a
5002 REM comment (//), empty, ".endm" or a record; anything else stops the program.
5003 RESTORE #K
5004 LET G=0
5005 LET I2=0
5006 LET C9=0
5007 IF END #K THEN 5060
5008 LINPUT #K, L$
5009 LET G=G+1
5010 IF I2=1 THEN 5016
5011 IF POS(L$,H1$)<>1 THEN 5007
5012 LET I2=1
5013 GOTO 5007
5016 IF LEN(L$)=0 THEN 5007
5017 IF POS(L$,".endm")<>1 THEN 5021
5018 LET I2=0
5019 GOTO 5007
5021 IF POS(L$,"//")=1 THEN 5007
5022 IF POS(L$,"    \m ")=1 THEN 5026
5023 LET M$="line inside "&H1$&" is not a comment, a record or .endm"
5024 GOTO 900
5026 LET C9=C9+1
5027 LET Z$=""
5028 ON T1 GOTO 5030,5034,5038
5030 GOSUB 6500
5031 GOTO 5042
5034 GOSUB 6600
5035 GOTO 5042
5038 GOSUB 6700
5042 LET Z$=""
5043 GOTO 5007
5060 IF I2=0 THEN 5064
5061 LET M$="macro not closed by .endm: "&H1$
5062 GOTO 900
5064 IF C9>0 THEN 5068
5065 LET M$="no records in "&H1$
5066 GOTO 900
5068 RETURN
6000 REM block errors: error records of errors.inc, then the sentinel -1
6001 LET K=2
6002 LET X$="errors.inc"
6003 LET H1$=".macro SEA_ERROR_LIST m"
6004 LET T1=1
6005 GOSUB 5000
6006 LET D$="DATA -1"
6007 GOSUB 800
6008 RETURN
6100 REM block errno: errno records of errors.inc, then the sentinel -1
6101 LET K=2
6102 LET X$="errors.inc"
6103 LET H1$=".macro SEA_ERRNO_LIST m"
6104 LET T1=2
6105 GOSUB 5000
6106 LET D$="DATA -1"
6107 GOSUB 800
6108 RETURN
6200 REM block exits: .equiv SEA_EXIT_<NAME>, <decimal> lines of errors.inc, then -1
6201 LET K=2
6202 LET X$="errors.inc"
6203 RESTORE #K
6204 LET G=0
6205 LET C9=0
6206 IF END #K THEN 6240
6207 LINPUT #K, L$
6208 LET G=G+1
6209 IF POS(L$,".equiv SEA_EXIT_")<>1 THEN 6206
6210 LET P9=16
6211 GOSUB 4000
6212 IF O=0 THEN 6206
6213 LET Z$=N8$
6214 LET W$=V$
6215 GOSUB 500
6216 IF O=1 THEN 6220
6217 LET M$="exit status is not a canonical decimal number: "&V$
6218 GOTO 900
6220 LET S$=N8$
6221 LET U=0
6222 GOSUB 700
6223 LET D$="DATA "&V$&","&E$
6224 GOSUB 800
6225 LET Z$=""
6226 LET C9=C9+1
6227 GOTO 6206
6240 IF C9>0 THEN 6244
6241 LET M$="no .equiv SEA_EXIT_ constants in errors.inc"
6242 GOTO 900
6244 LET D$="DATA -1"
6245 GOSUB 800
6246 RETURN
6300 REM block consts: constants of limits.inc then rt.inc as one table, then "-"
6301 LET C9=0
6302 LET K=1
6303 LET X$="limits.inc"
6304 GOSUB 4200
6305 LET K=3
6306 LET X$="rt.inc"
6307 GOSUB 4200
6308 IF C9>0 THEN 6312
6309 LET M$="no .equiv SEA_ constants in limits.inc and rt.inc"
6310 GOTO 900
6312 LET D$="DATA "&Q$&"-"&Q$
6313 GOSUB 800
6314 RETURN
6400 REM block records: enum, head and rec lines of passes.txt, then "end",0
6401 LET K=4
6402 LET X$="passes.txt"
6403 RESTORE #K
6404 LET G=0
6405 LET C9=0
6406 IF END #K THEN 6490
6407 LINPUT #K, L$
6408 LET G=G+1
6409 IF LEN(L$)=0 THEN 6406
6410 IF SEG$(L$,1,1)=";" THEN 6406
6411 LET Z$=SEG$(L$,1,40)
6412 LET R$=L$
6413 LET Q9=0
6414 LET D$=""
6415 LET P=POS(R$," ")
6416 IF P>0 THEN 6420
6417 LET W$=R$
6418 LET Y9=1
6419 GOTO 6423
6420 LET W$=SEG$(R$,1,P-1)
6421 LET R$=SEG$(R$,P+1,LEN(R$))
6422 LET Y9=0
6423 IF LEN(W$)>0 THEN 6427
6424 LET M$="empty field (leading, trailing or doubled blank)"
6425 GOTO 900
6427 IF Q9>0 THEN 6440
6428 LET T$=W$
6429 IF T$="enum" THEN 6450
6430 IF T$="head" THEN 6450
6431 IF T$="rec" THEN 6450
6432 LET M$="line is not empty, a ; comment, enum, head or rec"
6433 GOTO 900
6440 LET S$=W$
6441 LET U=0
6442 GOSUB 700
6443 LET D$=D$&","&E$
6450 LET Q9=Q9+1
6451 IF Y9=0 THEN 6415
6452 REM Q9-1 fields follow the kind: enum needs 2, head 1, rec 4 (set code op pops)
6453 LET A9=4
6454 IF T$="rec" THEN 6458
6455 LET A9=1
6456 IF T$="head" THEN 6458
6457 LET A9=2
6458 IF Q9-1>=A9 THEN 6462
6459 LET M$="too few fields for "&T$
6460 GOTO 900
6462 LET D$="DATA "&Q$&T$&Q$&","&STR$(Q9-1)&D$
6463 GOSUB 800
6464 LET Z$=""
6465 LET C9=C9+1
6466 GOTO 6406
6490 IF C9>0 THEN 6494
6491 LET M$="no enum, head or rec lines in passes.txt"
6492 GOTO 900
6494 LET D$="DATA "&Q$&"end"&Q$&",0"
6495 GOSUB 800
6496 RETURN
6500 REM record handler 1: \m code, NAME, phase, at, args, "text"
6501 LET R$=SEG$(L$,8,LEN(L$))
6502 LET D$="DATA "
6503 GOSUB 3000
6504 GOSUB 3100
6505 GOSUB 3200
6506 GOSUB 3200
6507 GOSUB 3200
6508 GOSUB 3300
6509 GOSUB 800
6510 RETURN
6600 REM record handler 2: \m id, NAME, darwin, linux, "text"
6601 LET R$=SEG$(L$,8,LEN(L$))
6602 LET D$="DATA "
6603 GOSUB 3000
6604 GOSUB 3100
6605 GOSUB 3000
6606 GOSUB 3000
6607 GOSUB 3300
6608 GOSUB 800
6609 RETURN
6700 REM record handler 3: \m id, NAME, symbol, site, args, results
6701 LET R$=SEG$(L$,8,LEN(L$))
6702 LET D$="DATA "
6703 GOSUB 3000
6704 GOSUB 3100
6705 GOSUB 3200
6706 GOSUB 3200
6707 GOSUB 3200
6708 GOSUB 3400
6709 GOSUB 800
6710 RETURN
6800 REM block entries: SEA_ENTRY_LIST records of rt.inc, then the sentinel -1
6801 LET K=3
6802 LET X$="rt.inc"
6803 LET H1$=".macro SEA_ENTRY_LIST m"
6804 LET T1=3
6805 GOSUB 5000
6806 LET D$="DATA -1"
6807 GOSUB 800
6808 RETURN
6900 REM block mtab: "DATA 32,128,128", the words of sea_mt_const, sea_mt_exp, sea_mt_log of
6901 REM math_tables.inc as limbs, 8 words per line (no line mixes two tables), then -1.
6902 REM T7 = the table being read (1 const, 2 exp, 3 log, 0 none, 4 another label), E7 the
6903 REM next table expected, W7 its words so far, Q7 the words in D$, A7$ its name.
6904 LET K=5
6905 LET X$="math_tables.inc"
6906 RESTORE #K
6907 LET G=0
6908 LET T7=0
6909 LET E7=1
6910 LET D$="DATA 32,128,128"
6911 GOSUB 800
6912 IF END #K THEN 6980
6913 LINPUT #K, L$
6914 LET G=G+1
6915 IF LEN(L$)<>28 THEN 6930
6916 IF SEG$(L$,1,12)<>"    .quad 0x" THEN 6930
6917 IF T7=0 THEN 6912
6918 IF T7=4 THEN 6912
6919 GOTO 7000
6930 IF LEN(L$)<9 THEN 6912
6931 IF SEG$(L$,1,7)<>"sea_mt_" THEN 6912
6932 IF ASC(SEG$(L$,LEN(L$),LEN(L$)))<>58 THEN 6912
6933 IF POS(L$," ")>0 THEN 6912
6934 GOSUB 7100
6935 LET A7$=SEG$(L$,8,LEN(L$)-1)
6936 LET Z$=A7$
6937 LET T7=4
6938 IF A7$="const" THEN 6945
6939 IF A7$="exp" THEN 6947
6940 IF A7$="log" THEN 6949
6941 LET Z$=""
6942 GOTO 6912
6945 LET T7=1
6946 GOTO 6950
6947 LET T7=2
6948 GOTO 6950
6949 LET T7=3
6950 IF T7=E7 THEN 6955
6951 REM
6952 LET M$="the tables sea_mt_const, sea_mt_exp, sea_mt_log must come once each, in this order"
6953 GOTO 900
6955 LET W7=0
6956 LET Q7=0
6957 LET D$="DATA "
6958 LET Z$=""
6959 GOTO 6912
6980 GOSUB 7100
6981 LET Z$=""
6982 IF E7=4 THEN 6986
6983 LET M$="math_tables.inc lacks one of the tables sea_mt_const, sea_mt_exp, sea_mt_log"
6984 GOTO 900
6986 LET D$="DATA -1"
6987 GOSUB 800
6988 RETURN
7000 REM a word line of the table T7: 16 upper-case hexadecimal digits -> 4 limbs in D$
7001 FOR A7=0 TO 3
7002 LET V7=0
7003 FOR B7=1 TO 4
7004 LET C7=ASC(SEG$(L$,12+4*A7+B7,12+4*A7+B7))
7005 IF C7<48 THEN 7020
7006 IF C7<=57 THEN 7011
7007 IF C7<65 THEN 7020
7008 IF C7>70 THEN 7020
7009 LET V7=16*V7+C7-55
7010 GOTO 7012
7011 LET V7=16*V7+C7-48
7012 NEXT B7
7013 IF Q7+A7=0 THEN 7016
7014 LET D$=D$&","&STR$(V7)
7015 GOTO 7017
7016 LET D$=D$&STR$(V7)
7017 NEXT A7
7018 GOTO 7030
7020 LET M$="a .quad word is not 16 upper-case hexadecimal digits"
7021 LET Z$=A7$
7022 GOTO 900
7030 LET W7=W7+1
7031 LET Q7=Q7+1
7032 IF Q7<8 THEN 6912
7033 GOSUB 800
7034 LET Q7=0
7035 LET D$="DATA "
7036 GOTO 6912
7100 REM end of the table T7 (if one of the three is open): the last line, then its word count
7101 IF T7=0 THEN 7130
7102 IF T7=4 THEN 7130
7103 IF Q7=0 THEN 7108
7104 GOSUB 800
7105 LET Q7=0
7108 LET C7=32
7109 IF T7=1 THEN 7113
7110 LET C7=256
7111 IF T7=2 THEN 7113
7112 LET C7=384
7113 IF W7=C7 THEN 7120
7114 LET M$="table sea_mt_"&A7$&" has "&STR$(W7)&" words, not "&STR$(C7)
7115 LET Z$=A7$
7116 GOTO 900
7120 LET E7=E7+1
7130 RETURN
9990 DATA "errors","errno","exits","consts","entries","records","mtab"
9999 END
