#sea 1
#target arm64-macos
#file type_cvt.sea
rtype 0:4:13 i64 s 0 3
param 0:4:10 k 0 0
rtype 0:4:21 f64 s 0 4
rname 0:5:12 k loc 1
return 0:5:5 1
block 0:4:25 1
rfn 0:4:1 widen 2 1 1 2 4 3
rtype 0:7:13 f64 s 0 4
param 0:7:10 x 0 0
rtype 0:7:21 f64 s 0 4
rname 0:8:12 x loc 1
float 0:8:16 #4000000000000000
bin 0:8:12 mul
return 0:8:5 1
block 0:7:25 1
rfn 0:7:1 scale 2 1 1 3 4 4
rpname 0:10:5 n 1
rint 0:10:9 3 #4008000000000000
let 0:10:1 0
rpname 0:11:5 a 2
rname 0:11:9 n loc 1
float 0:11:13 #3FE0000000000000
bin 0:11:9 mul
let 0:11:1 0
rpname 0:12:5 b 3
rtype 0:12:8 f64 s 0 4
rname 0:12:14 n loc 1
let 0:12:1 1
rpname 0:13:5 c 4
float 0:13:9 #0000000000000000
var 0:13:1 0
rname 0:14:1 c loc 4
rname 0:14:5 n loc 1
rint 0:14:9 1 #3FF0000000000000
bin 0:14:5 add
asg 0:14:1 set
rpname 0:15:5 d 5
rname 0:15:9 scale fn 3
rname 0:15:15 n loc 1
call 0:15:9 1
let 0:15:1 0
rpname 0:16:5 e 6
rname 0:16:9 widen fn 2
rname 0:16:15 n loc 1
call 0:16:9 1
rname 0:16:20 n loc 1
bin 0:16:9 lt
let 0:16:1 0
rpname 0:17:5 f 7
rname 0:17:13 n loc 1
conv 0:17:9 f64
float 0:17:22 #4004000000000000
conv 0:17:18 i64
bin 0:17:9 add
let 0:17:1 0
prog 10
#end
