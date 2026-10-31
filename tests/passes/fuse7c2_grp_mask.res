#sea 1
#target arm64-macos
#file fuse7c2_grp_mask.sea
rtvec 10 4
rtvec 11 2
rpname 0:4:5 x 1
rtype 0:4:8 f64 v 0 10
float 0:4:17 #4008000000000000
float 0:4:22 #3FF0000000000000
float 0:4:27 #4010000000000000
float 0:4:32 #3FF0000000000000
row 0:4:17 4
array 0:4:16 1
let 0:4:1 1
rpname 0:5:5 m 2
rtype 0:5:8 bool v 0 11
true 0:5:18
true 0:5:24
false 0:5:30
true 0:5:37
row 0:5:18 4
array 0:5:17 1
let 0:5:1 1
rpname 0:6:5 d 3
rname 0:6:9 x loc 1
float 0:6:13 #4000000000000000
bin 0:6:9 mul
let 0:6:1 0
rpname 0:7:5 s 4
rname 0:7:9 max pd 0
rname 0:7:13 d loc 3
rname 0:7:15 m loc 2
index 0:7:13 1
call 0:7:9 1
let 0:7:1 0
rname 0:8:1 printf pd 0
str 0:8:8 %25g%0A
rname 0:8:16 s loc 4
call 0:8:1 2
cstmt 0:8:1
prog 5
#end
