#sea 1
#target arm64-macos
#file fuse7_inl.sea
rtvec 10 4
rtype 0:4:9 f64 v 0 10
param 0:4:6 v 0 0
rtype 0:4:19 f64 v 0 10
rname 0:5:12 v loc 1
float 0:5:16 #4000000000000000
bin 0:5:12 mul
float 0:5:22 #3FF0000000000000
bin 0:5:12 add
return 0:5:5 1
block 0:4:25 1
rfn 0:4:1 g 2 1 1 2 10 10
rpname 0:7:5 x 1
rtype 0:7:8 f64 v 0 10
float 0:7:17 #3FF0000000000000
float 0:7:22 #4000000000000000
float 0:7:27 #4008000000000000
row 0:7:17 3
array 0:7:16 1
let 0:7:1 1
rpname 0:8:5 y 2
rname 0:8:9 g fn 2
rname 0:8:11 x loc 1
call 0:8:9 1
let 0:8:1 0
rname 0:9:1 printf pd 0
str 0:9:8 %25g%20%25g%20%25g%0A
rname 0:9:22 y loc 2
rint 0:9:24 0 #0000000000000000
index 0:9:22 1
rname 0:9:28 y loc 2
rint 0:9:30 1 #3FF0000000000000
index 0:9:28 1
rname 0:9:34 y loc 2
rint 0:9:36 2 #4000000000000000
index 0:9:34 1
call 0:9:1 4
cstmt 0:9:1
prog 4
#end
