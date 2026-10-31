#sea 1
#target arm64-macos
#file fuse7_f1_asg1.sea
rtvec 10 4
rpname 0:4:5 y 1
rtype 0:4:8 f64 v 0 10
float 0:4:17 #3FF0000000000000
float 0:4:22 #4000000000000000
float 0:4:27 #4008000000000000
row 0:4:17 3
array 0:4:16 1
var 0:4:1 1
rname 0:5:1 y loc 1
rname 0:5:5 y loc 1
float 0:5:9 #4000000000000000
bin 0:5:5 mul
asg 0:5:1 set
rname 0:6:1 printf pd 0
str 0:6:8 %25g%20%25g%20%25g%0A
rname 0:6:22 y loc 1
rint 0:6:24 0 #0000000000000000
index 0:6:22 1
rname 0:6:28 y loc 1
rint 0:6:30 1 #3FF0000000000000
index 0:6:28 1
rname 0:6:34 y loc 1
rint 0:6:36 2 #4000000000000000
index 0:6:34 1
call 0:6:1 4
cstmt 0:6:1
prog 3
#end
