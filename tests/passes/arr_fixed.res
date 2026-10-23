#sea 1
#target arm64-macos
#file arr_fixed.sea
rtfvec 10 4 2
rtype 0:1:10 f64 s 0 4
param 0:1:7 a 0 0
rint 0:1:22 2 #4000000000000000
rtype 0:1:18 f64 fv 1 10
rpname 0:2:9 r 2
rname 0:2:14 a loc 1
rname 0:2:17 a loc 1
row 0:2:14 2
array 0:2:13 1
var 0:2:5 0
rint 0:3:14 0 #0000000000000000
rint 0:3:17 2 #4000000000000000
range 0:3:14 0 0
rname 0:4:9 r loc 2
rname 0:4:11 k loc 3
index 0:4:9 1
rname 0:4:16 r loc 2
rname 0:4:18 k loc 3
index 0:4:16 1
float 0:4:23 #3FF0000000000000
bin 0:4:16 add
asg 0:4:9 set
block 0:3:19 1
rfor 0:3:5 k 0:3:9 3
rname 0:6:12 r loc 2
return 0:6:5 1
block 0:1:25 3
rfn 0:1:1 mk 0 1 1 2 10 4
rpname 0:8:5 p 1
rname 0:8:9 mk fn 2
float 0:8:12 #3FF8000000000000
call 0:8:9 1
let 0:8:1 0
rpname 0:9:5 q 2
rname 0:9:9 mk fn 2
float 0:9:12 #3FE0000000000000
call 0:9:9 1
let 0:9:1 0
rname 0:10:1 printf pd 0
str 0:10:8 %25g%20%25g%0A
rname 0:10:19 p loc 1
rint 0:10:21 1 #3FF0000000000000
index 0:10:19 1
rname 0:10:25 q loc 2
rint 0:10:27 0 #0000000000000000
index 0:10:25 1
call 0:10:1 3
cstmt 0:10:1
prog 4
#end
