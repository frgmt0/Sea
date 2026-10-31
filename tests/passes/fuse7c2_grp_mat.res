#sea 1
#target arm64-macos
#file fuse7c2_grp_mat.sea
rtmat 10 4
rpname 0:4:5 T 1
rtype 0:4:8 f64 m 0 10
float 0:4:18 #3FF0000000000000
float 0:4:23 #4000000000000000
row 0:4:18 2
float 0:4:28 #4008000000000000
float 0:4:33 #4010000000000000
row 0:4:28 2
float 0:4:38 #4014000000000000
float 0:4:43 #4018000000000000
row 0:4:38 2
array 0:4:17 3
let 0:4:1 1
rpname 0:5:5 Tc 2
rname 0:5:10 T loc 1
rint 0:5:12 1 #3FF0000000000000
rint 0:5:15 3 #4008000000000000
range 0:5:12 0 0
all 0:5:18
index 0:5:10 2
let 0:5:1 0
rpname 0:6:5 Tn 3
rname 0:6:10 Tc loc 2
float 0:6:15 #4000000000000000
bin 0:6:10 mul
let 0:6:1 0
rname 0:7:1 printf pd 0
str 0:7:8 %25g%20%25g%20%25g%20%25g%0A
rname 0:7:25 Tn loc 3
rint 0:7:28 0 #0000000000000000
rint 0:7:31 0 #0000000000000000
index 0:7:25 2
rname 0:7:35 Tn loc 3
rint 0:7:38 1 #3FF0000000000000
rint 0:7:41 0 #0000000000000000
index 0:7:35 2
rname 0:7:45 Tn loc 3
rint 0:7:48 0 #0000000000000000
rint 0:7:51 1 #3FF0000000000000
index 0:7:45 2
rname 0:7:55 Tn loc 3
rint 0:7:58 1 #3FF0000000000000
rint 0:7:61 1 #3FF0000000000000
index 0:7:55 2
call 0:7:1 5
cstmt 0:7:1
prog 4
#end
