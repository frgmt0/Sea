#sea 1
#target arm64-macos
#file arr_rule21.sea
rtvec 10 4
rtvec 11 2
rtup 12 2 10 11
rpname 0:1:6 v 1
rpname 0:1:9 m 2
ptuple 0:1:5 2
rname 0:1:14 two fn 2
call 0:1:14 0
var 0:1:1 0
rname 0:5:1 v loc 1
rname 0:5:3 m loc 2
index 0:5:1 1
float 0:5:8 #0000000000000000
asg 0:5:1 set
rname 0:6:1 printf pd 0
str 0:6:8 %25g%20%25g%20%25g%0A
rname 0:6:22 v loc 1
rint 0:6:24 0 #0000000000000000
index 0:6:22 1
rname 0:6:28 v loc 1
rint 0:6:30 1 #3FF0000000000000
index 0:6:28 1
rname 0:6:34 v loc 1
rint 0:6:36 2 #4000000000000000
index 0:6:34 1
call 0:6:1 4
cstmt 0:6:1
rpname 0:7:6 w 3
pskip 0:7:9
ptuple 0:7:5 2
rname 0:7:14 two fn 2
call 0:7:14 0
let 0:7:1 0
rname 0:8:1 printf pd 0
str 0:8:8 %25g%0A
rname 0:8:16 w loc 3
rint 0:8:18 3 #4008000000000000
index 0:8:16 1
call 0:8:1 2
cstmt 0:8:1
rtype 0:9:14 f64 v 0 10
rtype 0:9:21 bool v 0 11
rpname 0:10:9 v 1
rname 0:10:13 ones pd 0
rint 0:10:18 4 #4010000000000000
call 0:10:13 1
var 0:10:5 0
rpname 0:11:9 m 2
rname 0:11:13 filled pd 0
true 0:11:20
rint 0:11:26 4 #4010000000000000
call 0:11:13 2
var 0:11:5 0
rint 0:12:14 0 #0000000000000000
rint 0:12:17 2 #4000000000000000
range 0:12:14 0 0
rname 0:13:9 m loc 2
rint 0:13:11 2 #4000000000000000
rname 0:13:15 k loc 3
bin 0:13:11 mul
rint 0:13:19 1 #3FF0000000000000
bin 0:13:11 add
index 0:13:9 1
false 0:13:24
asg 0:13:9 set
block 0:12:19 1
rfor 0:12:5 k 0:12:9 3
rname 0:15:13 v loc 1
rname 0:15:16 m loc 2
return 0:15:5 2
block 0:9:29 4
rfn 0:9:1 two 0 0 2 2 12
prog 6
#end
