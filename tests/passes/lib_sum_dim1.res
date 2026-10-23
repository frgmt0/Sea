#sea 1
#target arm64-macos
#file lib_sum_dim1.sea
rtfmat 10 4 2 3
rint 0:1:18 2 #4000000000000000
rint 0:1:20 3 #4008000000000000
rtype 0:1:14 f64 fm 2 10
param 0:1:11 A 0 0
rtype 0:1:27 i64 s 0 3
param 0:1:24 k 0 0
rtype 0:1:35 f64 s 0 4
rpname 0:2:9 s 3
rname 0:2:13 sum pd 0
rname 0:2:17 A loc 1
rint 0:2:25 1 #3FF0000000000000
narg 0:2:20 dim
call 0:2:13 2
let 0:2:5 0
rname 0:3:12 s loc 3
rname 0:3:14 k loc 2
index 0:3:12 1
return 0:3:5 1
block 0:1:39 2
rfn 0:1:1 rowsum 0 2 1 2 4 10 3
rpname 0:5:5 M 1
float 0:5:10 #3FF0000000000000
float 0:5:15 #4000000000000000
float 0:5:20 #4008000000000000
row 0:5:10 3
float 0:5:25 #4010000000000000
float 0:5:30 #4014000000000000
float 0:5:35 #4018000000000000
row 0:5:25 3
array 0:5:9 2
let 0:5:1 0
rname 0:6:1 printf pd 0
str 0:6:8 %25g%0A
rname 0:6:16 rowsum fn 2
rname 0:6:23 M loc 1
rint 0:6:26 0 #0000000000000000
call 0:6:16 2
call 0:6:1 2
cstmt 0:6:1
rname 0:7:1 printf pd 0
str 0:7:8 %25g%0A
rname 0:7:16 rowsum fn 2
rname 0:7:23 M loc 1
rint 0:7:26 1 #3FF0000000000000
call 0:7:16 2
call 0:7:1 2
cstmt 0:7:1
prog 4
#end
