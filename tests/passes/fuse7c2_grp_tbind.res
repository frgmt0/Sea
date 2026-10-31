#sea 1
#target arm64-macos
#file fuse7c2_grp_tbind.sea
rtup 10 2 4 4
rtvec 11 4
rtype 0:4:21 f64 s 0 4
param 0:4:18 x 0 0
rtype 0:4:29 f64 s 0 4
param 0:4:26 k 0 0
rtype 0:4:38 f64 s 0 4
rtype 0:4:43 f64 s 0 4
rname 0:5:13 x loc 1
rname 0:5:17 k loc 2
bin 0:5:13 mul
rname 0:5:20 x loc 1
rname 0:5:24 k loc 2
bin 0:5:20 add
return 0:5:5 2
block 0:4:48 1
rfn 0:4:1 two 1 2 2 2 10 4 4
rpname 0:7:5 lo 1
rtype 0:7:9 f64 v 0 11
float 0:7:18 #0000000000000000
float 0:7:23 #3FF0000000000000
float 0:7:28 #4000000000000000
row 0:7:18 3
array 0:7:17 1
var 0:7:1 1
rpname 0:8:5 hi 2
rtype 0:8:9 f64 v 0 11
float 0:8:18 #3FF0000000000000
float 0:8:23 #4000000000000000
float 0:8:28 #4010000000000000
row 0:8:18 3
array 0:8:17 1
let 0:8:1 1
rpname 0:9:5 mid 3
rname 0:9:12 lo loc 1
rname 0:9:17 hi loc 2
bin 0:9:12 add
float 0:9:23 #3FE0000000000000
bin 0:9:11 mul
let 0:9:1 0
rpname 0:10:6 a 4
pskip 0:10:9
ptuple 0:10:5 2
rname 0:10:14 two fn 2
rname 0:10:18 mid loc 3
float 0:10:23 #4000000000000000
call 0:10:14 2
let 0:10:1 0
rpname 0:11:5 up 5
rname 0:11:10 a loc 4
float 0:11:14 #4004000000000000
bin 0:11:10 gt
let 0:11:1 0
rname 0:12:1 lo loc 1
rname 0:12:6 where pd 0
rname 0:12:12 up loc 5
rname 0:12:16 mid loc 3
rname 0:12:21 lo loc 1
call 0:12:6 3
asg 0:12:1 set
rname 0:13:1 printf pd 0
str 0:13:8 %25g%20%25g%20%25g%0A
rname 0:13:22 lo loc 1
rint 0:13:25 0 #0000000000000000
index 0:13:22 1
rname 0:13:29 lo loc 1
rint 0:13:32 1 #3FF0000000000000
index 0:13:29 1
rname 0:13:36 lo loc 1
rint 0:13:39 2 #4000000000000000
index 0:13:36 1
call 0:13:1 4
cstmt 0:13:1
prog 8
#end
