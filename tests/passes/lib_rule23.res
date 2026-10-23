#sea 1
#target arm64-macos
#file lib_rule23.sea
rtvec 10 4
rtype 0:1:13 f64 v 0 10
param 0:1:10 x 0 0
rtype 0:1:23 f64 s 0 4
rpname 0:3:9 s 2
rname 0:3:13 sum pd 0
rname 0:3:17 x loc 1
call 0:3:13 1
let 0:3:5 0
rname 0:4:12 s loc 2
return 0:4:5 1
block 0:1:27 2
rfn 0:1:1 total 0 1 1 2 4 10
rname 0:6:1 printf pd 0
str 0:6:8 %25g%0A
rname 0:6:16 total fn 2
rname 0:6:22 ones pd 0
rint 0:6:27 9 #4022000000000000
call 0:6:22 1
call 0:6:16 1
call 0:6:1 2
cstmt 0:6:1
rname 0:7:1 printf pd 0
str 0:7:8 %25g%0A
rname 0:7:16 total fn 2
rname 0:7:22 zeros pd 0
rint 0:7:28 2 #4000000000000000
call 0:7:22 1
call 0:7:16 1
call 0:7:1 2
cstmt 0:7:1
prog 3
#end
