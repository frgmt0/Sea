#sea 1
#target arm64-macos
#file lib_variance.sea
rtvec 10 4
rtype 0:1:14 f64 v 0 10
param 0:1:11 x 0 0
rpname 0:2:9 v 2
rname 0:2:13 variance pd 0
rname 0:2:22 x loc 1
call 0:2:13 1
let 0:2:5 0
rpname 0:3:9 d 3
rname 0:3:13 std pd 0
rname 0:3:17 x loc 1
call 0:3:13 1
let 0:3:5 0
rname 0:4:5 printf pd 0
str 0:4:12 %25g%20%25g%0A
rname 0:4:23 v loc 2
rname 0:4:26 d loc 3
call 0:4:5 3
cstmt 0:4:5
block 0:1:21 3
rfn 0:1:1 spread 2 1 0 2 1 10
rname 0:6:1 spread fn 2
rname 0:6:8 ones pd 0
rint 0:6:13 3 #4008000000000000
call 0:6:8 1
call 0:6:1 1
cstmt 0:6:1
rname 0:7:1 spread fn 2
rname 0:7:8 zeros pd 0
rint 0:7:14 0 #0000000000000000
call 0:7:8 1
call 0:7:1 1
cstmt 0:7:1
prog 3
#end
