#sea 1
#target arm64-macos
#file fuse7_f3_sum.sea
rtvec 10 4
rpname 0:3:5 x 1
rtype 0:3:8 f64 v 0 10
float 0:3:17 #3FF0000000000000
float 0:3:22 #4000000000000000
float 0:3:27 #4008000000000000
row 0:3:17 3
array 0:3:16 1
let 0:3:1 1
rpname 0:4:5 s 2
rname 0:4:9 sum pd 0
rname 0:4:13 x loc 1
float 0:4:17 #4000000000000000
bin 0:4:13 mul
float 0:4:23 #3FF0000000000000
bin 0:4:13 add
call 0:4:9 1
let 0:4:1 0
rname 0:5:1 printf pd 0
str 0:5:8 %25g%0A
rname 0:5:16 s loc 2
call 0:5:1 2
cstmt 0:5:1
prog 3
#end
