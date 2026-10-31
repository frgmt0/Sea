#sea 1
#target arm64-macos
#file fuse7_f4_idxvec.sea
rtvec 10 4
rtvec 11 3
rpname 0:3:5 x 1
rtype 0:3:8 f64 v 0 10
float 0:3:17 #3FF0000000000000
float 0:3:22 #4000000000000000
float 0:3:27 #4008000000000000
row 0:3:17 3
array 0:3:16 1
let 0:3:1 1
rpname 0:4:5 k 2
rtype 0:4:8 i64 v 0 11
rint 0:4:17 2 #4000000000000000
rint 0:4:20 0 #0000000000000000
row 0:4:17 2
array 0:4:16 1
let 0:4:1 1
rpname 0:5:5 y 3
rname 0:5:9 x loc 1
rname 0:5:11 k loc 2
index 0:5:9 1
float 0:5:16 #4000000000000000
bin 0:5:9 mul
let 0:5:1 0
rname 0:6:1 printf pd 0
str 0:6:8 %25g%20%25g%0A
rname 0:6:19 y loc 3
rint 0:6:21 0 #0000000000000000
index 0:6:19 1
rname 0:6:25 y loc 3
rint 0:6:27 1 #3FF0000000000000
index 0:6:25 1
call 0:6:1 3
cstmt 0:6:1
prog 4
#end
