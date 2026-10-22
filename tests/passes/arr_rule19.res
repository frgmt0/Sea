#sea 1
#target arm64-macos
#file arr_rule19.sea
rtmat 10 4
rpname 0:1:5 T 1
rname 0:1:9 mk fn 2
call 0:1:9 0
var 0:1:1 0
rpname 0:2:5 j 2
rint 0:2:9 1 #3FF0000000000000
var 0:2:1 0
rpname 0:3:5 i 3
rint 0:3:9 0 #0000000000000000
var 0:3:1 0
rpname 0:4:5 tn 4
float 0:4:10 #4004000000000000
let 0:4:1 0
rtype 0:5:12 f64 m 0 10
rpname 0:6:9 A 1
rname 0:6:13 zeros pd 0
rint 0:6:19 2 #4000000000000000
rint 0:6:22 2 #4000000000000000
call 0:6:13 2
var 0:6:5 0
rint 0:7:14 0 #0000000000000000
rint 0:7:17 2 #4000000000000000
range 0:7:14 0 0
rname 0:8:9 A loc 1
rname 0:8:11 k loc 2
rname 0:8:14 k loc 2
index 0:8:9 2
float 0:8:19 #3FF0000000000000
asg 0:8:9 set
block 0:7:19 1
rfor 0:7:5 k 0:7:9 2
rname 0:10:12 A loc 1
return 0:10:5 1
block 0:5:19 3
rfn 0:5:1 mk 0 0 1 2 10
rname 0:12:1 T loc 1
rname 0:12:3 j loc 2
rname 0:12:6 i loc 3
index 0:12:1 2
rname 0:12:11 tn loc 4
asg 0:12:1 set
rname 0:13:1 printf pd 0
str 0:13:8 %25g%0A
rname 0:13:16 T loc 1
rint 0:13:18 1 #3FF0000000000000
rint 0:13:21 0 #0000000000000000
index 0:13:16 2
call 0:13:1 2
cstmt 0:13:1
rpname 0:14:5 U 5
rname 0:14:9 mk fn 2
call 0:14:9 0
let 0:14:1 0
rname 0:15:1 printf pd 0
str 0:15:8 %25g%0A
rname 0:15:16 U loc 5
rint 0:15:18 1 #3FF0000000000000
rint 0:15:21 0 #0000000000000000
index 0:15:16 2
call 0:15:1 2
cstmt 0:15:1
prog 9
#end
