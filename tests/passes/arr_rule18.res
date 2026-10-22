#sea 1
#target arm64-macos
#file arr_rule18.sea
rtmat 10 4
rpname 0:1:5 A 1
rname 0:1:9 zeros pd 0
rint 0:1:15 2 #4000000000000000
rint 0:1:18 3 #4008000000000000
call 0:1:9 2
var 0:1:1 0
rname 0:2:1 A loc 1
rint 0:2:3 1 #3FF0000000000000
rint 0:2:6 2 #4000000000000000
index 0:2:1 2
float 0:2:11 #4014000000000000
asg 0:2:1 set
rname 0:3:1 printf pd 0
str 0:3:8 %25g%0A
rname 0:3:16 g fn 2
rname 0:3:18 A loc 1
rint 0:3:21 2 #4000000000000000
rint 0:3:24 2 #4000000000000000
call 0:3:16 3
call 0:3:1 2
cstmt 0:3:1
rname 0:4:1 printf pd 0
str 0:4:8 %25g%0A
rname 0:4:16 g fn 2
rname 0:4:18 A loc 1
rint 0:4:21 0 #0000000000000000
rint 0:4:24 1 #3FF0000000000000
call 0:4:16 3
call 0:4:1 2
cstmt 0:4:1
rname 0:5:1 printf pd 0
str 0:5:8 %25g%0A
rname 0:5:16 A loc 1
dollar 0:5:18
rint 0:5:22 1 #3FF0000000000000
bin 0:5:18 sub
dollar 0:5:25
rint 0:5:29 1 #3FF0000000000000
bin 0:5:25 sub
index 0:5:16 2
call 0:5:1 2
cstmt 0:5:1
rtype 0:6:9 f64 m 0 10
param 0:6:6 T 0 0
rtype 0:6:20 i64 s 0 3
param 0:6:17 i 0 0
rtype 0:6:28 i64 s 0 3
param 0:6:25 j 0 0
rtype 0:6:36 f64 s 0 4
rpname 0:7:9 r 4
rname 0:7:13 T loc 1
rname 0:7:15 j loc 3
rint 0:7:17 1 #3FF0000000000000
bin 0:7:15 sub
rname 0:7:20 i loc 2
index 0:7:13 2
var 0:7:5 0
rname 0:8:11 r loc 4
float 0:8:15 #0000000000000000
bin 0:8:11 lt
rname 0:9:9 r loc 4
float 0:9:13 #0000000000000000
asg 0:9:9 set
block 0:8:19 1
while 0:8:5
rname 0:11:12 r loc 4
return 0:11:5 1
block 0:6:40 3
rfn 0:6:1 g 0 3 1 2 4 10 3 3
prog 6
#end
