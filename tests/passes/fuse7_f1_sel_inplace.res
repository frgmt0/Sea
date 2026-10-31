#sea 1
#target arm64-macos
#file fuse7_f1_sel_inplace.sea
rtvec 10 4
rpname 0:4:5 x 1
rtype 0:4:8 f64 v 0 10
float 0:4:17 #3FF0000000000000
float 0:4:22 #4000000000000000
row 0:4:17 2
array 0:4:16 1
let 0:4:1 1
rpname 0:5:5 v 2
rtype 0:5:8 f64 v 0 10
float 0:5:17 #0000000000000000
float 0:5:22 #0000000000000000
float 0:5:27 #0000000000000000
row 0:5:17 3
array 0:5:16 1
var 0:5:1 1
rname 0:6:1 v loc 2
rint 0:6:3 1 #3FF0000000000000
rint 0:6:6 3 #4008000000000000
range 0:6:3 0 0
index 0:6:1 1
rname 0:6:11 x loc 1
float 0:6:15 #4000000000000000
bin 0:6:11 mul
float 0:6:21 #3FF0000000000000
bin 0:6:11 add
asg 0:6:1 set
rname 0:7:1 printf pd 0
str 0:7:8 %25g%20%25g%20%25g%0A
rname 0:7:22 v loc 2
rint 0:7:24 0 #0000000000000000
index 0:7:22 1
rname 0:7:28 v loc 2
rint 0:7:30 1 #3FF0000000000000
index 0:7:28 1
rname 0:7:34 v loc 2
rint 0:7:36 2 #4000000000000000
index 0:7:34 1
call 0:7:1 4
cstmt 0:7:1
prog 4
#end
