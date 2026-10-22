#sea 1
#target arm64-macos
#file type_powk.sea
rint 0:4:11 6 #4018000000000000
rint 0:4:15 4 #4010000000000000
bin 0:4:11 mod
rcni 0:4:1 K 0 1 2
rpname 0:5:5 x 1
float 0:5:9 #3FF8000000000000
let 0:5:1 0
rpname 0:6:5 a 2
rname 0:6:9 x loc 1
rint 0:6:13 2 #4000000000000000
rpowk 0:6:9 2
let 0:6:1 0
rpname 0:7:5 b 3
rname 0:7:9 x loc 1
float 0:7:13 #4000000000000000
rpowk 0:7:9 2
let 0:7:1 0
rpname 0:8:5 c 4
rname 0:8:9 x loc 1
rint 0:8:14 1 #3FF0000000000000
neg 0:8:13
rpowk 0:8:9 -1
let 0:8:1 0
rpname 0:9:5 d 5
rname 0:9:9 x loc 1
rname 0:9:13 K cst 1
rpowk 0:9:9 2
let 0:9:1 0
rpname 0:10:5 e 6
rname 0:10:9 x loc 1
rint 0:10:14 1 #3FF0000000000000
rint 0:10:18 3 #4008000000000000
bin 0:10:14 add
rpowk 0:10:9 4
let 0:10:1 0
rpname 0:11:5 f 7
rname 0:11:9 x loc 1
float 0:11:14 #0000000000000000
neg 0:11:13
rpowk 0:11:9 0
let 0:11:1 0
rpname 0:12:5 g 8
rint 0:12:9 2 #4000000000000000
rint 0:12:13 3 #4008000000000000
rpowk 0:12:9 3
let 0:12:1 0
rpname 0:13:5 h 9
rname 0:13:9 x loc 1
rint 0:13:13 0 #0000000000000000
rpowk 0:13:9 0
let 0:13:1 0
rpname 0:14:5 i 10
rname 0:14:9 x loc 1
float 0:14:14 #4020000000000000
float 0:14:20 #4000000000000000
bin 0:14:14 div
rpowk 0:14:9 4
let 0:14:1 0
rpname 0:15:5 n 11
rint 0:15:9 3 #4008000000000000
let 0:15:1 0
rpname 0:16:5 j 12
rname 0:16:9 n loc 11
rint 0:16:13 2 #4000000000000000
rpowk 0:16:9 2
let 0:16:1 0
prog 13
#end
