#sea 1
#target arm64-macos
#file type_untyped.sea
rtype 0:4:9 f64 s 0 4
param 0:4:6 v 0 0
rtype 0:4:17 f64 s 0 4
rname 0:5:12 v loc 1
return 0:5:5 1
block 0:4:21 1
rfn 0:4:1 h 2 1 1 2 4 4
rpname 0:7:5 x 1
float 0:7:9 #3FF8000000000000
let 0:7:1 0
rpname 0:8:5 a 2
rint 0:8:9 2 #4000000000000000
rname 0:8:13 x loc 1
bin 0:8:9 mul
let 0:8:1 0
rpname 0:9:5 b 3
rint 0:9:9 3 #4008000000000000
let 0:9:1 0
rpname 0:10:5 c 4
rint 0:10:9 2 #4000000000000000
rint 0:10:13 3 #4008000000000000
rpowk 0:10:9 3
let 0:10:1 0
rpname 0:11:5 d 5
rtype 0:11:8 f64 s 0 4
rint 0:11:14 4 #4010000000000000
rint 0:11:18 5 #4014000000000000
bin 0:11:14 add
let 0:11:1 1
rpname 0:12:5 e 6
rint 0:12:10 2 #4000000000000000
neg 0:12:9
rint 0:12:14 3 #4008000000000000
bin 0:12:9 mul
let 0:12:1 0
rpname 0:13:5 f 7
rname 0:13:9 x loc 1
rint 0:13:13 7 #401C000000000000
bin 0:13:9 lt
let 0:13:1 0
rpname 0:14:5 g 8
rint 0:14:9 10 #4024000000000000
rint 0:14:14 4 #4010000000000000
bin 0:14:9 div
let 0:14:1 0
rpname 0:15:5 k 9
rname 0:15:9 h fn 2
rint 0:15:11 6 #4018000000000000
call 0:15:9 1
let 0:15:1 0
prog 10
#end
