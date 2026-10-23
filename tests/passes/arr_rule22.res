#sea 1
#target arm64-macos
#file arr_rule22.sea
rtvec 10 4
rtype 0:1:13 f64 v 0 10
param 0:1:10 x 0 0
rtype 0:1:23 f64 s 0 4
rpname 0:2:9 z 2
rname 0:2:13 x loc 1
float 0:2:17 #4000000000000000
bin 0:2:13 mul
let 0:2:5 0
rpname 0:3:9 s 3
float 0:3:13 #0000000000000000
var 0:3:5 0
rname 0:4:14 z loc 2
rname 0:5:9 s loc 3
rname 0:5:14 e loc 4
asg 0:5:9 add
block 0:4:16 1
rfor 0:4:5 e 0:4:9 4
rname 0:7:12 s loc 3
return 0:7:5 1
block 0:1:27 4
rfn 0:1:1 twice 0 1 1 2 4 10
rname 0:9:1 printf pd 0
str 0:9:8 %25g%0A
rname 0:9:16 twice fn 2
rname 0:9:22 ones pd 0
rint 0:9:27 3 #4008000000000000
call 0:9:22 1
call 0:9:16 1
call 0:9:1 2
cstmt 0:9:1
rname 0:10:1 printf pd 0
str 0:10:8 %25g%0A
rname 0:10:16 twice fn 2
rname 0:10:22 zeros pd 0
rint 0:10:28 2 #4000000000000000
call 0:10:22 1
call 0:10:16 1
call 0:10:1 2
cstmt 0:10:1
prog 3
#end
