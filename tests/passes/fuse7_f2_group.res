#sea 1
#target arm64-macos
#file fuse7_f2_group.sea
rtvec 10 4
rpname 0:4:5 x 1
rtype 0:4:8 f64 v 0 10
float 0:4:17 #3FF0000000000000
float 0:4:22 #4000000000000000
float 0:4:27 #4008000000000000
row 0:4:17 3
array 0:4:16 1
let 0:4:1 1
rpname 0:5:5 y 2
rtype 0:5:8 f64 v 0 10
float 0:5:17 #3FF0000000000000
float 0:5:22 #4000000000000000
float 0:5:27 #4008000000000000
float 0:5:32 #4010000000000000
row 0:5:17 4
array 0:5:16 1
let 0:5:1 1
rpname 0:6:5 a 3
rname 0:6:9 x loc 1
float 0:6:13 #4000000000000000
bin 0:6:9 mul
let 0:6:1 0
rpname 0:7:5 b 4
rname 0:7:9 y loc 2
float 0:7:13 #4008000000000000
bin 0:7:9 mul
let 0:7:1 0
rname 0:8:1 printf pd 0
str 0:8:8 %25g%20%25g%20%25g%20%25g%0A
rname 0:8:25 a loc 3
rint 0:8:27 0 #0000000000000000
index 0:8:25 1
rname 0:8:31 a loc 3
rint 0:8:33 2 #4000000000000000
index 0:8:31 1
rname 0:8:37 b loc 4
rint 0:8:39 0 #0000000000000000
index 0:8:37 1
rname 0:8:43 b loc 4
rint 0:8:45 3 #4008000000000000
index 0:8:43 1
call 0:8:1 5
cstmt 0:8:1
prog 5
#end
