#sea 1
#target arm64-macos
#file fuse7_f4_cat.sea
rtvec 10 4
rpname 0:3:5 x 1
rtype 0:3:8 f64 v 0 10
float 0:3:17 #3FF0000000000000
float 0:3:22 #4000000000000000
float 0:3:27 #4008000000000000
row 0:3:17 3
array 0:3:16 1
let 0:3:1 1
rpname 0:4:5 c 2
rname 0:4:10 x loc 1
rint 0:4:12 1 #3FF0000000000000
rint 0:4:15 3 #4008000000000000
range 0:4:12 0 0
index 0:4:10 1
float 0:4:19 #4014000000000000
row 0:4:10 2
array 0:4:9 1
let 0:4:1 0
rname 0:5:1 printf pd 0
str 0:5:8 %25g%20%25g%20%25g%0A
rname 0:5:22 c loc 2
rint 0:5:24 0 #0000000000000000
index 0:5:22 1
rname 0:5:28 c loc 2
rint 0:5:30 1 #3FF0000000000000
index 0:5:28 1
rname 0:5:34 c loc 2
rint 0:5:36 2 #4000000000000000
index 0:5:34 1
call 0:5:1 4
cstmt 0:5:1
prog 3
#end
