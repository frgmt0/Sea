#sea 1
#target arm64-macos
#file fuse7_f1_mat1.sea
rtmat 10 4
rpname 0:3:5 A 1
rtype 0:3:8 f64 m 0 10
float 0:3:18 #3FF0000000000000
float 0:3:23 #4000000000000000
float 0:3:28 #4008000000000000
row 0:3:18 3
float 0:3:33 #4010000000000000
float 0:3:38 #4014000000000000
float 0:3:43 #4018000000000000
row 0:3:33 3
array 0:3:17 2
let 0:3:1 1
rpname 0:4:5 B 2
rname 0:4:9 A loc 1
float 0:4:13 #4000000000000000
bin 0:4:9 mul
let 0:4:1 0
rname 0:5:1 printf pd 0
str 0:5:8 %25g%20%25g%20%25g%0A
rname 0:5:22 B loc 2
rint 0:5:24 1 #3FF0000000000000
rint 0:5:27 0 #0000000000000000
index 0:5:22 2
rname 0:5:31 B loc 2
rint 0:5:33 0 #0000000000000000
rint 0:5:36 2 #4000000000000000
index 0:5:31 2
rname 0:5:40 B loc 2
rint 0:5:42 1 #3FF0000000000000
rint 0:5:45 2 #4000000000000000
index 0:5:40 2
call 0:5:1 4
cstmt 0:5:1
prog 3
#end
