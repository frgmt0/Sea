#sea 1
#target arm64-macos
#file fn_ref_order.sea
rtype 0:4:13 i64 s 0 3
param 0:4:6 s 1 0
rtype 0:4:21 i64 s 0 3
rint 0:5:14 0 #0000000000000000
rint 0:5:17 2 #4000000000000000
range 0:5:14 0 0
rname 0:6:9 s loc 1
rint 0:6:14 5 #4014000000000000
asg 0:6:9 add
block 0:5:19 1
rfor 0:5:5 k 0:5:9 2
rname 0:8:12 s loc 1
rint 0:8:16 2 #4000000000000000
bin 0:8:12 mul
return 0:8:5 1
block 0:4:25 2
rfn 0:4:1 g 0 1 1 2 3 3
rtype 0:10:9 i64 s 0 3
param 0:10:6 a 0 0
rtype 0:10:17 i64 s 0 3
param 0:10:14 b 0 0
rtype 0:10:25 i64 s 0 3
rpname 0:11:9 r 3
rname 0:11:13 b loc 2
var 0:11:5 0
rint 0:12:14 0 #0000000000000000
rint 0:12:17 3 #4008000000000000
range 0:12:14 0 0
rname 0:13:9 r loc 3
rname 0:13:14 a loc 1
asg 0:13:9 add
block 0:12:19 1
rfor 0:12:5 k 0:12:9 4
rname 0:15:12 r loc 3
return 0:15:5 1
block 0:10:29 3
rfn 0:10:1 f 0 2 1 3 3 3 3
rpname 0:17:5 x 1
rint 0:17:9 1 #3FF0000000000000
var 0:17:1 0
rpname 0:18:5 y 2
rint 0:18:9 0 #0000000000000000
var 0:18:1 0
rname 0:19:1 y loc 2
rname 0:19:5 x loc 1
rname 0:19:9 g fn 2
rname 0:19:15 x loc 1
ref 0:19:11
call 0:19:9 1
bin 0:19:5 add
asg 0:19:1 set
rname 0:20:1 x loc 1
rname 0:20:6 g fn 2
rname 0:20:12 x loc 1
ref 0:20:8
call 0:20:6 1
asg 0:20:1 add
rpname 0:21:5 z 3
rname 0:21:9 f fn 3
rname 0:21:11 x loc 1
rname 0:21:14 g fn 2
rname 0:21:20 x loc 1
ref 0:21:16
call 0:21:14 1
call 0:21:9 2
let 0:21:1 0
rname 0:22:1 x loc 1
rname 0:22:5 g fn 2
rname 0:22:11 x loc 1
ref 0:22:7
call 0:22:5 1
asg 0:22:1 set
rpname 0:23:5 w 4
rname 0:23:9 g fn 2
rname 0:23:15 x loc 1
ref 0:23:11
call 0:23:9 1
rname 0:23:20 f fn 3
rname 0:23:22 x loc 1
rint 0:23:25 0 #0000000000000000
call 0:23:20 2
bin 0:23:9 add
let 0:23:1 0
rname 0:24:1 printf pd 0
str 0:24:8 %25d%20%25d%20%25d%20%25d%0A
rname 0:24:25 x loc 1
rname 0:24:28 y loc 2
rname 0:24:31 z loc 3
rname 0:24:34 w loc 4
call 0:24:1 5
cstmt 0:24:1
prog 10
#end
