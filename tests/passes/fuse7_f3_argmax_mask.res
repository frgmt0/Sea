#sea 1
#target arm64-macos
#file fuse7_f3_argmax_mask.sea
rtvec 10 4
rtvec 11 2
rpname 0:3:5 v 1
rtype 0:3:8 f64 v 0 10
float 0:3:17 #4022000000000000
float 0:3:22 #3FF0000000000000
float 0:3:27 #4014000000000000
row 0:3:17 3
array 0:3:16 1
let 0:3:1 1
rpname 0:4:5 m 2
rtype 0:4:8 bool v 0 11
false 0:4:18
true 0:4:25
true 0:4:31
row 0:4:18 3
array 0:4:17 1
let 0:4:1 1
rpname 0:5:5 k 3
rname 0:5:9 argmax pd 0
rname 0:5:16 v loc 1
rname 0:5:18 m loc 2
index 0:5:16 1
call 0:5:9 1
let 0:5:1 0
rname 0:6:1 printf pd 0
str 0:6:8 %25d%0A
rname 0:6:16 k loc 3
call 0:6:1 2
cstmt 0:6:1
prog 4
#end
