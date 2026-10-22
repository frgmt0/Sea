#sea 1
#target arm64-macos
#file const_pow.sea
float 0:3:11 #4000000000000000
float 0:3:17 #3FE0000000000000
bin 0:3:11 pow
rcnf 0:3:1 C 0 1 #3FF6A09E667F3BCD
rname 0:4:11 pow pd 0
rint 0:4:15 10 #4024000000000000
rint 0:4:20 2 #4000000000000000
neg 0:4:19
call 0:4:11 2
rcnf 0:4:1 P 0 2 #3F847AE147AE147B
rint 0:5:11 2 #4000000000000000
float 0:5:16 #4008000000000000
float 0:5:22 #4000000000000000
bin 0:5:16 div
bin 0:5:11 pow
rcnf 0:5:1 Q 0 3 #4006A09E667F3BCD
rname 0:6:11 pow pd 0
float 0:6:15 #4022000000000000
float 0:6:20 #3FE0000000000000
call 0:6:11 2
rcnf 0:6:1 K 0 4 #4008000000000000
rname 0:7:11 pow pd 0
float 0:7:16 #4020000000000000
neg 0:7:15
float 0:7:21 #3FE0000000000000
call 0:7:11 2
rcnf 0:7:1 Z 0 5 #7FF8000000000000
float 0:8:11 #4008000000000000
rint 0:8:17 2 #4000000000000000
rpowk 0:8:11 2
rcnf 0:8:1 W 0 6 #4022000000000000
rpname 0:9:5 x 1
float 0:9:9 #3FF4CCCCCCCCCCCD
let 0:9:1 0
rpname 0:10:5 a 2
rname 0:10:9 C cst 1
let 0:10:1 0
rpname 0:11:5 b 3
rname 0:11:9 P cst 2
rname 0:11:13 Q cst 3
bin 0:11:9 add
let 0:11:1 0
rpname 0:12:5 e 4
rname 0:12:9 x loc 1
rname 0:12:13 K cst 4
rpowk 0:12:9 3
let 0:12:1 0
rpname 0:13:5 f 5
rname 0:13:9 x loc 1
rname 0:13:13 C cst 1
bin 0:13:9 pow
let 0:13:1 0
rpname 0:14:5 z 6
rname 0:14:9 Z cst 5
let 0:14:1 0
rpname 0:15:5 w 7
rname 0:15:9 W cst 6
let 0:15:1 0
prog 13
#end
