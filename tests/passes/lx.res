#sea 1
#target arm64-macos
#file lx.sea
type 0:1:11 i64 s 0
param 0:1:8 n 0 0
type 0:1:19 f64 s 0
param 0:1:16 x 0 0
type 0:1:27 f64 s 0
rpname 0:2:9 s 3
float 0:2:13 #0000000000000000
var 0:2:5 0
rint 0:3:14 0 #0000000000000000
rname 0:3:17 n loc 1
range 0:3:14 0 0
rname 0:4:9 s loc 3
rname 0:4:13 s loc 3
rname 0:4:17 x loc 2
rname 0:4:21 i loc 4
bin 0:4:17 mul
bin 0:4:13 add
asg 0:4:9 set
block 0:3:19 1
rfor 0:3:5 i 0:3:9 4
rname 0:6:12 s loc 3
return 0:6:5 1
block 0:1:31 3
rfn 0:1:1 tri 0 2 1 2 4 3 4
rpname 0:8:5 a 1
rname 0:8:9 tri fn 2
rint 0:8:13 10 #4024000000000000
float 0:8:17 #3FE0000000000000
call 0:8:9 2
let 0:8:1 0
rpname 0:9:5 b 2
rname 0:9:9 tri fn 2
rint 0:9:13 4 #4010000000000000
rname 0:9:16 a loc 1
call 0:9:9 2
let 0:9:1 0
prog 3
#end
