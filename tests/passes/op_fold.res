#sea 1
#target arm64-macos
#file op_fold.sea
rpname 0:4:5 a 1
rint 0:4:9 2 #4000000000000000
rint 0:4:13 3 #4008000000000000
bin 0:4:9 mul
rint 0:4:17 4 #4010000000000000
bin 0:4:9 add
let 0:4:1 0
rpname 0:5:5 b 2
float 0:5:9 #3FF8000000000000
float 0:5:15 #4000000000000000
bin 0:5:9 mul
float 0:5:21 #3FE0000000000000
bin 0:5:9 sub
let 0:5:1 0
rpname 0:6:5 c 3
rint 0:6:9 #7FFFFFFFFFFFFFFF -
rint 0:6:31 1 #3FF0000000000000
bin 0:6:9 add
let 0:6:1 0
rpname 0:7:5 d 4
float 0:7:9 #7E37E43C8800759C
float 0:7:17 #4202A05F20000000
bin 0:7:9 mul
let 0:7:1 0
rpname 0:8:5 e 5
float 0:8:9 #6974E718D7D7625A
float 0:8:17 #54B249AD2594C37D
bin 0:8:9 mul
let 0:8:1 0
rpname 0:9:5 f 6
float 0:9:9 #3FF0000000000000
float 0:9:15 #0000000000000000
bin 0:9:9 div
let 0:9:1 0
rpname 0:10:5 g 7
float 0:10:9 #3FF0000000000000
float 0:10:15 #4008000000000000
bin 0:10:9 div
let 0:10:1 0
rpname 0:11:5 h 8
rname 0:11:9 inf pd 0
float 0:11:15 #3FF0000000000000
bin 0:11:9 sub
let 0:11:1 0
rpname 0:12:5 i 9
rname 0:12:10 nan pd 0
neg 0:12:9
let 0:12:1 0
rpname 0:13:5 j 10
rint 0:13:9 7 #401C000000000000
rint 0:13:13 3 #4008000000000000
bin 0:13:9 mod
let 0:13:1 0
rpname 0:14:5 k 11
rint 0:14:9 2 #4000000000000000
rint 0:14:13 3 #4008000000000000
bin 0:14:9 lt
let 0:14:1 0
rpname 0:15:5 m 12
rint 0:15:9 7 #401C000000000000
rint 0:15:13 2 #4000000000000000
bin 0:15:9 div
let 0:15:1 0
rpname 0:16:5 n 13
rint 0:16:11 2 #4000000000000000
rint 0:16:15 3 #4008000000000000
bin 0:16:11 add
neg 0:16:9
let 0:16:1 0
rpname 0:17:5 p 14
float 0:17:9 #4000000000000000
rname 0:17:15 pi pd 0
bin 0:17:9 mul
rname 0:17:20 a loc 1
bin 0:17:9 mul
rint 0:17:24 60 #404E000000000000
bin 0:17:9 div
let 0:17:1 0
prog 14
#end
