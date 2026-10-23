#sea 1
#target arm64-macos
#file arr_tasg_l12.sea
rtfvec 10 4 2
rtup 11 2 10 10
rpname 0:1:5 v 1
rname 0:1:9 zeros pd 0
rint 0:1:15 4 #4010000000000000
call 0:1:9 1
var 0:1:1 0
rpname 0:2:5 d 2
rname 0:2:9 zeros pd 0
rint 0:2:15 1 #3FF0000000000000
call 0:2:9 1
var 0:2:1 0
rname 0:3:2 v loc 1
rint 0:3:4 1 #3FF0000000000000
rint 0:3:7 3 #4008000000000000
range 0:3:4 0 0
index 0:3:2 1
rname 0:3:11 d loc 2
rname 0:3:16 two fn 2
float 0:3:20 #3FF8000000000000
call 0:3:16 1
tasg 0:3:1 2
rpname 0:4:6 p 3
rpname 0:4:9 q 4
ptuple 0:4:5 2
rname 0:4:14 two fn 2
float 0:4:18 #3FE0000000000000
call 0:4:14 1
let 0:4:1 0
rname 0:5:1 printf pd 0
str 0:5:8 %25g%20%25g%20%25g%20%25d%20%25g%0A
rname 0:5:28 v loc 1
rint 0:5:30 1 #3FF0000000000000
index 0:5:28 1
rname 0:5:34 v loc 1
rint 0:5:36 3 #4008000000000000
index 0:5:34 1
rname 0:5:40 d loc 2
rint 0:5:42 1 #3FF0000000000000
index 0:5:40 1
rname 0:5:46 len pd 0
rname 0:5:50 d loc 2
call 0:5:46 1
rname 0:5:54 q loc 4
rint 0:5:56 0 #0000000000000000
index 0:5:54 1
call 0:5:1 6
cstmt 0:5:1
rtype 0:9:11 f64 s 0 4
param 0:9:8 a 0 0
rint 0:9:24 2 #4000000000000000
rtype 0:9:20 f64 fv 1 10
rint 0:9:32 2 #4000000000000000
rtype 0:9:28 f64 fv 1 10
rpname 0:10:9 r 2
rname 0:10:14 a loc 1
rname 0:10:17 a loc 1
row 0:10:14 2
array 0:10:13 1
var 0:10:5 0
rint 0:11:14 0 #0000000000000000
rint 0:11:17 2 #4000000000000000
range 0:11:14 0 0
rname 0:12:9 r loc 2
rname 0:12:11 k loc 3
index 0:12:9 1
rname 0:12:16 r loc 2
rname 0:12:18 k loc 3
index 0:12:16 1
float 0:12:23 #3FF0000000000000
bin 0:12:16 add
asg 0:12:9 set
block 0:11:19 1
rfor 0:11:5 k 0:11:9 3
rname 0:14:13 r loc 2
rname 0:14:16 r loc 2
return 0:14:5 2
block 0:9:36 3
rfn 0:9:1 two 0 1 2 2 11 4
prog 6
#end
