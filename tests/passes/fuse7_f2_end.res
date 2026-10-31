#sea 1
#target arm64-macos
#file fuse7_f2_end.sea
rtvec 10 4
rpname 0:5:5 x 1
rtype 0:5:8 f64 v 0 10
float 0:5:17 #3FF0000000000000
float 0:5:22 #4000000000000000
float 0:5:27 #4008000000000000
row 0:5:17 3
array 0:5:16 1
let 0:5:1 1
rpname 0:6:5 a 2
rname 0:6:9 x loc 1
float 0:6:13 #3FF0000000000000
bin 0:6:9 add
let 0:6:1 0
rpname 0:7:5 b 3
rname 0:7:9 a loc 2
float 0:7:13 #4000000000000000
bin 0:7:9 mul
let 0:7:1 0
rpname 0:8:5 c 4
rname 0:8:9 b loc 3
rint 0:8:11 0 #0000000000000000
rint 0:8:14 2 #4000000000000000
range 0:8:11 0 0
index 0:8:9 1
float 0:8:19 #4008000000000000
bin 0:8:9 mul
let 0:8:1 0
rname 0:9:1 printf pd 0
str 0:9:8 %25g%20%25g%0A
rname 0:9:19 c loc 4
rint 0:9:21 0 #0000000000000000
index 0:9:19 1
rname 0:9:25 c loc 4
rint 0:9:27 1 #3FF0000000000000
index 0:9:25 1
call 0:9:1 3
cstmt 0:9:1
prog 5
#end
