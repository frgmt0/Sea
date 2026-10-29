#sea 1
#target arm64-macos
#file lib_sum_dim0.sea
rtmat 10 4
rtype 0:1:14 f64 m 0 10
param 0:1:11 A 0 0
rtype 0:1:25 f64 s 0 4
rpname 0:2:9 s 2
rname 0:2:13 sum pd 0
rname 0:2:17 A loc 1
rint 0:2:25 0 #0000000000000000
narg 0:2:20 dim
call 0:2:13 2
let 0:2:5 0
rname 0:3:12 s loc 2
rint 0:3:14 0 #0000000000000000
index 0:3:12 1
return 0:3:5 1
block 0:1:29 2
rfn 0:1:1 colsum 2 1 1 2 4 10
rname 0:5:1 printf pd 0
str 0:5:8 %25g%0A
rname 0:5:16 colsum fn 2
rname 0:5:23 ones pd 0
rint 0:5:28 2 #4000000000000000
rint 0:5:31 3 #4008000000000000
call 0:5:23 2
call 0:5:16 1
call 0:5:1 2
cstmt 0:5:1
rname 0:6:1 printf pd 0
str 0:6:8 %25g%0A
rname 0:6:16 colsum fn 2
rname 0:6:23 zeros pd 0
rint 0:6:29 3 #4008000000000000
rint 0:6:32 1 #3FF0000000000000
call 0:6:23 2
call 0:6:16 1
call 0:6:1 2
cstmt 0:6:1
prog 3
#end
