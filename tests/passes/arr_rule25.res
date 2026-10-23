#sea 1
#target arm64-macos
#file arr_rule25.sea
rtype 0:1:15 i64 s 0 3
param 0:1:9 nBin 0 0
rtype 0:1:23 i64 s 0 3
rpname 0:4:9 edges 2
rint 0:4:18 0 #0000000000000000
rname 0:4:22 nBin loc 1
range 0:4:18 1 0
rangev 0:4:17
let 0:4:5 0
rpname 0:5:9 t 3
rint 0:5:13 0 #0000000000000000
var 0:5:5 0
rname 0:6:14 edges loc 2
rname 0:7:9 t loc 3
rname 0:7:14 e loc 4
asg 0:7:9 add
block 0:6:20 1
rfor 0:6:5 e 0:6:9 4
rname 0:9:12 t loc 3
return 0:9:5 1
block 0:1:27 4
rfn 0:1:1 hist 0 1 1 2 3 3
rname 0:11:1 printf pd 0
str 0:11:8 %25d%0A
rname 0:11:16 hist fn 2
rint 0:11:21 3 #4008000000000000
call 0:11:16 1
call 0:11:1 2
cstmt 0:11:1
rname 0:12:1 printf pd 0
str 0:12:8 %25d%0A
rname 0:12:16 hist fn 2
rint 0:12:21 0 #0000000000000000
call 0:12:16 1
call 0:12:1 2
cstmt 0:12:1
prog 3
#end
