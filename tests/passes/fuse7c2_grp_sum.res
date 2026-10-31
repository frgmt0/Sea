#sea 1
#target arm64-macos
#file fuse7c2_grp_sum.sea
rtvec 10 4
rpname 0:4:5 x 1
rtype 0:4:8 f64 v 0 10
float 0:4:17 #3FF0000000000000
float 0:4:22 #4000000000000000
float 0:4:27 #4008000000000000
row 0:4:17 3
array 0:4:16 1
let 0:4:1 1
rpname 0:5:5 d 2
rname 0:5:9 x loc 1
float 0:5:13 #4000000000000000
bin 0:5:9 mul
let 0:5:1 0
rpname 0:6:5 s 3
rname 0:6:9 sum pd 0
rname 0:6:13 d loc 2
float 0:6:17 #3FF0000000000000
bin 0:6:13 add
call 0:6:9 1
let 0:6:1 0
rname 0:7:1 printf pd 0
str 0:7:8 %25g%0A
rname 0:7:16 s loc 3
call 0:7:1 2
cstmt 0:7:1
prog 4
#end
