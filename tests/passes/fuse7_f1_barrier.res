#sea 1
#target arm64-macos
#file fuse7_f1_barrier.sea
rtvec 10 3
rtvec 11 4
rpname 0:4:5 a 1
rtype 0:4:8 i64 v 0 10
rint 0:4:17 1 #3FF0000000000000
rint 0:4:20 2 #4000000000000000
rint 0:4:23 3 #4008000000000000
row 0:4:17 3
array 0:4:16 1
let 0:4:1 1
rpname 0:5:5 x 2
rtype 0:5:8 f64 v 0 11
float 0:5:17 #3FE0000000000000
float 0:5:22 #3FD0000000000000
float 0:5:28 #3FC0000000000000
row 0:5:17 3
array 0:5:16 1
let 0:5:1 1
rpname 0:6:5 y 3
rname 0:6:13 a loc 1
rint 0:6:17 2 #4000000000000000
bin 0:6:13 mul
conv 0:6:9 f64
rname 0:6:22 x loc 2
bin 0:6:9 add
let 0:6:1 0
rname 0:7:1 printf pd 0
str 0:7:8 %25g%20%25g%20%25g%0A
rname 0:7:22 y loc 3
rint 0:7:24 0 #0000000000000000
index 0:7:22 1
rname 0:7:28 y loc 3
rint 0:7:30 1 #3FF0000000000000
index 0:7:28 1
rname 0:7:34 y loc 3
rint 0:7:36 2 #4000000000000000
index 0:7:34 1
call 0:7:1 4
cstmt 0:7:1
prog 4
#end
