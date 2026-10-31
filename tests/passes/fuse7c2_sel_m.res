#sea 1
#target arm64-macos
#file fuse7c2_sel_m.sea
rtvec 10 4
rtvec 11 2
rpname 0:3:5 v 1
rtype 0:3:8 f64 v 0 10
float 0:3:17 #0000000000000000
float 0:3:22 #0000000000000000
float 0:3:27 #0000000000000000
float 0:3:32 #0000000000000000
row 0:3:17 4
array 0:3:16 1
var 0:3:1 1
rpname 0:4:5 m 2
rtype 0:4:8 bool v 0 11
true 0:4:18
false 0:4:24
false 0:4:31
true 0:4:38
row 0:4:18 4
array 0:4:17 1
let 0:4:1 1
rpname 0:5:5 x 3
rtype 0:5:8 f64 v 0 10
float 0:5:17 #3FF0000000000000
float 0:5:22 #4000000000000000
row 0:5:17 2
array 0:5:16 1
let 0:5:1 1
rname 0:6:1 v loc 1
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
rname 0:7:25 v loc 1
rint 0:7:27 0 #0000000000000000
index 0:7:25 1
rname 0:7:31 v loc 1
rint 0:7:33 1 #3FF0000000000000
index 0:7:31 1
rname 0:7:37 v loc 1
rint 0:7:39 2 #4000000000000000
index 0:7:37 1
rname 0:7:43 v loc 1
rint 0:7:45 3 #4008000000000000
index 0:7:43 1
call 0:7:1 5
cstmt 0:7:1
prog 5
#end
