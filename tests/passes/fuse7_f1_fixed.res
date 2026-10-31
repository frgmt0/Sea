#sea 1
#target arm64-macos
#file fuse7_f1_fixed.sea
rtfmat 10 4 2 2
rpname 0:3:5 F 1
rint 0:3:12 2 #4000000000000000
rint 0:3:14 2 #4000000000000000
rtype 0:3:8 f64 fm 2 10
float 0:3:20 #3FF0000000000000
float 0:3:25 #4000000000000000
row 0:3:20 2
float 0:3:30 #4008000000000000
float 0:3:35 #4010000000000000
row 0:3:30 2
array 0:3:19 2
let 0:3:1 1
rpname 0:4:5 G 2
rname 0:4:9 F loc 1
float 0:4:13 #4000000000000000
bin 0:4:9 mul
rname 0:4:19 F loc 1
bin 0:4:9 add
let 0:4:1 0
rname 0:5:1 printf pd 0
str 0:5:8 %25g%20%25g%20%25g%20%25g%0A
rname 0:5:25 G loc 2
rint 0:5:27 0 #0000000000000000
rint 0:5:30 0 #0000000000000000
index 0:5:25 2
rname 0:5:34 G loc 2
rint 0:5:36 1 #3FF0000000000000
rint 0:5:39 0 #0000000000000000
index 0:5:34 2
rname 0:5:43 G loc 2
rint 0:5:45 0 #0000000000000000
rint 0:5:48 1 #3FF0000000000000
index 0:5:43 2
rname 0:5:52 G loc 2
rint 0:5:54 1 #3FF0000000000000
rint 0:5:57 1 #3FF0000000000000
index 0:5:52 2
call 0:5:1 5
cstmt 0:5:1
prog 3
#end
