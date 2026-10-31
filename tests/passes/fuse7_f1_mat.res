#sea 1
#target arm64-macos
#file fuse7_f1_mat.sea
rtmat 10 4
rpname 0:4:5 A 1
rtype 0:4:8 f64 m 0 10
float 0:4:18 #3FF0000000000000
float 0:4:23 #4000000000000000
row 0:4:18 2
float 0:4:28 #4008000000000000
float 0:4:33 #4010000000000000
row 0:4:28 2
array 0:4:17 2
let 0:4:1 1
rpname 0:5:5 B 2
rname 0:5:9 A loc 1
float 0:5:13 #4000000000000000
bin 0:5:9 mul
rname 0:5:19 A loc 1
bin 0:5:9 add
let 0:5:1 0
rname 0:6:1 printf pd 0
str 0:6:8 %25g%20%25g%20%25g%20%25g%0A
rname 0:6:25 B loc 2
rint 0:6:27 0 #0000000000000000
rint 0:6:30 0 #0000000000000000
index 0:6:25 2
rname 0:6:34 B loc 2
rint 0:6:36 1 #3FF0000000000000
rint 0:6:39 0 #0000000000000000
index 0:6:34 2
rname 0:6:43 B loc 2
rint 0:6:45 0 #0000000000000000
rint 0:6:48 1 #3FF0000000000000
index 0:6:43 2
rname 0:6:52 B loc 2
rint 0:6:54 1 #3FF0000000000000
rint 0:6:57 1 #3FF0000000000000
index 0:6:52 2
call 0:6:1 5
cstmt 0:6:1
prog 3
#end
