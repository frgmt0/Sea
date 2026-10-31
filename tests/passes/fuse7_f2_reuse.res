#sea 1
#target arm64-macos
#file fuse7_f2_reuse.sea
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
float 0:5:17 #0000000000000000
float 0:5:22 #0000000000000000
float 0:5:27 #0000000000000000
row 0:5:17 3
array 0:5:16 1
var 0:5:1 1
rpname 0:6:5 a 3
rname 0:6:9 x loc 1
float 0:6:13 #3FF0000000000000
bin 0:6:9 add
let 0:6:1 0
rname 0:7:1 y loc 2
rname 0:7:5 a loc 3
float 0:7:9 #4000000000000000
bin 0:7:5 mul
asg 0:7:1 set
rname 0:8:1 printf pd 0
str 0:8:8 %25g%20%25g%20%25g%0A
rname 0:8:22 y loc 2
rint 0:8:24 0 #0000000000000000
index 0:8:22 1
rname 0:8:28 y loc 2
rint 0:8:30 1 #3FF0000000000000
index 0:8:28 1
rname 0:8:34 y loc 2
rint 0:8:36 2 #4000000000000000
index 0:8:34 1
call 0:8:1 4
cstmt 0:8:1
prog 5
#end
