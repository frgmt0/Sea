#sea 1
#target arm64-macos
#file arr_rule20.sea
rtvec 10 4
rpname 0:1:5 a 1
rname 0:1:9 zeros pd 0
rint 0:1:15 5 #4014000000000000
call 0:1:9 1
var 0:1:1 0
rname 0:2:1 a loc 1
rint 0:2:3 2 #4000000000000000
index 0:2:1 1
float 0:2:8 #4000000000000000
asg 0:2:1 set
rname 0:3:1 a loc 1
rint 0:3:3 3 #4008000000000000
index 0:3:1 1
float 0:3:8 #4008000000000000
asg 0:3:1 set
rname 0:4:1 printf pd 0
str 0:4:8 %25g%0A
rname 0:4:16 pick fn 2
rname 0:4:21 a loc 1
call 0:4:16 1
call 0:4:1 2
cstmt 0:4:1
rname 0:5:1 printf pd 0
str 0:5:8 %25g%0A
rname 0:5:16 pick fn 2
rname 0:5:21 ones pd 0
rint 0:5:26 5 #4014000000000000
call 0:5:21 1
call 0:5:16 1
call 0:5:1 2
cstmt 0:5:1
rtype 0:29:12 f64 v 0 10
param 0:29:9 u 0 0
rtype 0:29:22 f64 s 0 4
rpname 0:30:9 u1 2
rname 0:30:14 u loc 1
rint 0:30:16 0 #0000000000000000
dollar 0:30:19
rint 0:30:26 2 #4000000000000000
range 0:30:16 0 1
index 0:30:14 1
let 0:30:5 0
rpname 0:31:9 s 3
float 0:31:13 #0000000000000000
var 0:31:5 0
rname 0:32:14 u1 loc 2
rname 0:33:9 s loc 3
rname 0:33:14 x loc 4
asg 0:33:9 add
block 0:32:17 1
rfor 0:32:5 x 0:32:9 4
rname 0:35:12 s loc 3
return 0:35:5 1
block 0:29:26 4
rfn 0:29:1 pick 0 1 1 2 4 10
prog 6
#end
