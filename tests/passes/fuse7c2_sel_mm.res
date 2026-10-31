#sea 1
#target arm64-macos
#file fuse7c2_sel_mm.sea
rtmat 10 4
rtmat 11 2
rtvec 12 4
rpname 0:3:5 A 1
rtype 0:3:8 f64 m 0 10
float 0:3:18 #0000000000000000
float 0:3:23 #0000000000000000
row 0:3:18 2
float 0:3:28 #0000000000000000
float 0:3:33 #0000000000000000
row 0:3:28 2
array 0:3:17 2
var 0:3:1 1
rpname 0:4:5 m 2
rtype 0:4:8 bool m 0 11
true 0:4:19
false 0:4:25
row 0:4:19 2
false 0:4:32
true 0:4:39
row 0:4:32 2
array 0:4:18 2
let 0:4:1 1
rpname 0:5:5 x 3
rtype 0:5:8 f64 v 0 12
float 0:5:17 #3FF0000000000000
float 0:5:22 #4000000000000000
row 0:5:17 2
array 0:5:16 1
let 0:5:1 1
rname 0:6:1 A loc 1
rname 0:6:3 m loc 2
index 0:6:1 1
rname 0:6:8 x loc 3
float 0:6:12 #4000000000000000
bin 0:6:8 mul
float 0:6:18 #3FF0000000000000
bin 0:6:8 add
asg 0:6:1 set
rname 0:7:1 printf pd 0
str 0:7:8 %25g%20%25g%20%25g%20%25g%0A
rname 0:7:25 A loc 1
rint 0:7:27 0 #0000000000000000
rint 0:7:30 0 #0000000000000000
index 0:7:25 2
rname 0:7:34 A loc 1
rint 0:7:36 1 #3FF0000000000000
rint 0:7:39 0 #0000000000000000
index 0:7:34 2
rname 0:7:43 A loc 1
rint 0:7:45 0 #0000000000000000
rint 0:7:48 1 #3FF0000000000000
index 0:7:43 2
rname 0:7:52 A loc 1
rint 0:7:54 1 #3FF0000000000000
rint 0:7:57 1 #3FF0000000000000
index 0:7:52 2
call 0:7:1 5
cstmt 0:7:1
prog 5
#end
