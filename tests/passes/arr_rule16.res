#sea 1
#target arm64-macos
#file arr_rule16.sea
rtype 0:1:9 i64 s 0 3
param 0:1:6 n 0 0
rtype 0:1:17 i64 s 0 3
rpname 0:2:9 k 2
rint 0:2:13 0 #0000000000000000
var 0:2:5 0
rname 0:3:11 k loc 2
rname 0:3:15 n loc 1
bin 0:3:11 lt
rpname 0:4:13 v 3
rname 0:4:17 zeros pd 0
rname 0:4:23 n loc 1
call 0:4:17 1
let 0:4:9 0
rname 0:5:12 k loc 2
rint 0:5:17 3 #4008000000000000
bin 0:5:12 eq
break 0:5:21
block 0:5:19 1
if 0:5:9 0
rname 0:6:9 k loc 2
rint 0:6:14 1 #3FF0000000000000
asg 0:6:9 add
block 0:3:17 3
while 0:3:5
rname 0:8:12 k loc 2
return 0:8:5 1
block 0:1:21 3
rfn 0:1:1 f 0 1 1 2 3 3
rname 0:10:1 printf pd 0
str 0:10:8 %25d%0A
rname 0:10:16 f fn 2
rint 0:10:18 5 #4014000000000000
call 0:10:16 1
call 0:10:1 2
cstmt 0:10:1
rname 0:11:1 printf pd 0
str 0:11:8 %25d%0A
rname 0:11:16 f fn 2
rint 0:11:18 2 #4000000000000000
call 0:11:16 1
call 0:11:1 2
cstmt 0:11:1
prog 3
#end
