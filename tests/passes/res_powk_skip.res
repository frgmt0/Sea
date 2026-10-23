#sea 1
#target arm64-macos
#file res_powk_skip.sea
rerr 0:11:1 235 1 g
rtup 10 2 4 3
rint 0:3:11 2 #4000000000000000
rcni 0:3:1 K 0 1 2
rtype 0:4:9 f64 s 0 4
param 0:4:6 x 0 0
rtype 0:4:18 f64 s 0 4
rtype 0:4:23 i64 s 0 3
rname 0:5:13 x loc 1
rname 0:5:17 K cst 1
rpowk 0:5:13 2
rint 0:5:20 1 #3FF0000000000000
return 0:5:5 2
block 0:4:28 1
rfn 0:4:1 g 0 1 2 2 10 4
rtype 0:7:9 f64 s 0 4
param 0:7:6 x 0 0
rtype 0:7:18 f64 s 0 4
rtype 0:7:23 i64 s 0 3
rpname 0:8:9 K 2
rint 0:8:13 3 #4008000000000000
let 0:8:5 0
rname 0:9:13 x loc 1
rname 0:9:17 K loc 2
bin 0:9:13 pow
rname 0:9:20 K loc 2
return 0:9:5 2
block 0:7:28 2
rfn 0:7:1 h 0 1 2 3 10 4
type 0:11:9 f64 s 0
param 0:11:6 y 0 0
type 0:11:17 f64 s 0
name 0:12:12 y
name 0:12:16 K
bin 0:12:12 pow
return 0:12:5 1
block 0:11:21 1
fn 0:11:1 g 0 1 1
rint 0:14:11 1 #3FF0000000000000
rint 0:14:14 2 #4000000000000000
row 0:14:11 2
array 0:14:10 1
rpname 0:15:9 w 2
rname 0:15:13 e loc 1
let 0:15:5 0
block 0:14:17 1
rfor 0:14:1 e 0:14:5 1
str 0:17:7 a
str 0:18:5 a
rpname 0:18:18 m 3
rint 0:18:22 1 #3FF0000000000000
let 0:18:14 0
block 0:18:12 1
arm 0:18:5 1
rpname 0:19:16 m 4
rint 0:19:20 2 #4000000000000000
let 0:19:12 0
block 0:19:10 1
arm 0:19:5 0
match 0:17:1 2
rpname 0:21:5 t 5
rname 0:21:9 g fn 2
float 0:21:11 #4000000000000000
call 0:21:9 1
let 0:21:1 0
prog 7
#end
