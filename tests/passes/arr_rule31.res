#sea 1
#target arm64-macos
#file arr_rule31.sea
rtvec 10 4
rpname 0:1:5 v 1
rname 0:1:9 mkv fn 2
call 0:1:9 0
var 0:1:1 0
rpname 0:2:5 i 2
rint 0:2:9 1 #3FF0000000000000
var 0:2:1 0
rname 0:4:1 f fn 3
rname 0:4:7 v loc 1
rname 0:4:9 i loc 2
index 0:4:7 1
ref 0:4:3
call 0:4:1 1
cstmt 0:4:1
rname 0:5:1 f fn 3
rname 0:5:7 v loc 1
rint 0:5:9 0 #0000000000000000
index 0:5:7 1
ref 0:5:3
call 0:5:1 1
cstmt 0:5:1
rname 0:6:1 printf pd 0
str 0:6:8 %25g%0A
rname 0:6:16 v loc 1
rint 0:6:18 0 #0000000000000000
index 0:6:16 1
call 0:6:1 2
cstmt 0:6:1
rname 0:7:1 printf pd 0
str 0:7:8 %25g%0A
rname 0:7:16 v loc 1
rint 0:7:18 1 #3FF0000000000000
index 0:7:16 1
call 0:7:1 2
cstmt 0:7:1
rpname 0:8:5 w 3
rname 0:8:9 mkv fn 2
call 0:8:9 0
let 0:8:1 0
rname 0:9:1 printf pd 0
str 0:9:8 %25g%0A
rname 0:9:16 w loc 3
rint 0:9:18 1 #3FF0000000000000
index 0:9:16 1
call 0:9:1 2
cstmt 0:9:1
rtype 0:10:13 f64 v 0 10
rpname 0:11:9 a 1
rname 0:11:13 zeros pd 0
rint 0:11:19 2 #4000000000000000
call 0:11:13 1
var 0:11:5 0
rint 0:12:14 0 #0000000000000000
rint 0:12:17 2 #4000000000000000
range 0:12:14 0 0
rname 0:13:9 a loc 1
rname 0:13:11 k loc 2
index 0:13:9 1
rname 0:13:20 k loc 2
conv 0:13:16 f64
float 0:13:25 #3FE0000000000000
bin 0:13:16 add
asg 0:13:9 set
block 0:12:19 1
rfor 0:12:5 k 0:12:9 2
rname 0:15:12 a loc 1
return 0:15:5 1
block 0:10:19 3
rfn 0:10:1 mkv 0 0 1 2 10
rtype 0:17:13 f64 s 0 4
param 0:17:6 x 1 0
rint 0:18:14 0 #0000000000000000
rint 0:18:17 2 #4000000000000000
range 0:18:14 0 0
rname 0:19:9 x loc 1
float 0:19:14 #3FF0000000000000
asg 0:19:9 add
block 0:18:19 1
rfor 0:18:5 k 0:18:9 2
block 0:17:18 1
rfn 0:17:1 f 0 1 0 3 1 4
prog 10
#end
