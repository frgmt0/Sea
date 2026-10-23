#sea 1
#target arm64-macos
#file arr_rule28.sea
rtmat 10 4
rtype 0:1:15 f64 m 0 10
param 0:1:12 A 0 0
rtype 0:1:26 i64 s 0 3
param 0:1:23 k 0 0
rtype 0:1:34 f64 s 0 4
rpname 0:3:9 e 3
rname 0:3:13 A loc 1
dot 0:3:13 flat
rname 0:3:20 k loc 2
index 0:3:13 1
let 0:3:5 0
rpname 0:4:9 s 4
rname 0:4:13 e loc 3
var 0:4:5 0
rint 0:5:14 0 #0000000000000000
rname 0:5:17 k loc 2
range 0:5:14 0 0
rname 0:6:9 s loc 4
float 0:6:14 #3FF0000000000000
asg 0:6:9 add
block 0:5:19 1
rfor 0:5:5 i 0:5:9 5
rname 0:8:12 s loc 4
return 0:8:5 1
block 0:1:38 4
rfn 0:1:1 flat_at 0 2 1 2 4 10 3
rpname 0:10:5 M 1
rname 0:10:9 zeros pd 0
rint 0:10:15 2 #4000000000000000
rint 0:10:18 3 #4008000000000000
call 0:10:9 2
var 0:10:1 0
rname 0:11:1 M loc 1
rint 0:11:3 0 #0000000000000000
rint 0:11:6 2 #4000000000000000
index 0:11:1 2
float 0:11:11 #401E000000000000
asg 0:11:1 set
rname 0:12:1 printf pd 0
str 0:12:8 %25g%0A
rname 0:12:16 flat_at fn 2
rname 0:12:24 M loc 1
rint 0:12:27 4 #4010000000000000
call 0:12:16 2
call 0:12:1 2
cstmt 0:12:1
rname 0:13:1 printf pd 0
str 0:13:8 %25g%0A
rname 0:13:16 flat_at fn 2
rname 0:13:24 M loc 1
rint 0:13:27 1 #3FF0000000000000
call 0:13:16 2
call 0:13:1 2
cstmt 0:13:1
prog 5
#end
