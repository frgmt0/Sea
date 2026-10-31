#sea 1
#target arm64-macos
#file fuse7_f5_tree.sea
rtvec 10 4
rtype 0:3:19 f64 s 0 4
param 0:3:16 x 0 0
rtype 0:3:27 f64 s 0 4
param 0:3:24 k 0 0
rtype 0:3:35 f64 s 0 4
rname 0:4:12 x loc 1
rname 0:4:16 k loc 2
bin 0:4:12 mul
float 0:4:20 #3FF0000000000000
bin 0:4:12 add
return 0:4:5 1
block 0:3:39 1
rfn 0:3:1 f 1 2 1 2 4 4 4
rpname 0:6:5 x 1
rtype 0:6:8 f64 v 0 10
float 0:6:17 #3FF0000000000000
float 0:6:22 #4000000000000000
float 0:6:27 #4008000000000000
row 0:6:17 3
array 0:6:16 1
let 0:6:1 1
rpname 0:7:5 y 2
rname 0:7:9 f fn 2
rname 0:7:11 x loc 1
float 0:7:14 #4000000000000000
call 0:7:9 2
float 0:7:21 #3FF0000000000000
bin 0:7:9 add
let 0:7:1 0
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
prog 4
#end
