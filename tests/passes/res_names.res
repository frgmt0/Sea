#sea 1
#target arm64-macos
#file res_names.sea
rint 0:3:11 2 #4000000000000000
rcni 0:3:1 K 0 1 2
rtype 0:4:10 i64 s 0 3
param 0:4:6 lo 0 0
rtype 0:4:18 i64 s 0 3
rpname 0:5:9 lo 2
rname 0:5:14 lo loc 1
var 0:5:5 0
rname 0:6:8 lo loc 2
rname 0:6:13 K cst 1
bin 0:6:8 gt
rpname 0:7:13 lo 3
rint 0:7:18 1 #3FF0000000000000
let 0:7:9 0
rname 0:8:16 lo loc 3
return 0:8:9 1
block 0:6:15 2
if 0:6:5 0
rname 0:10:12 lo loc 2
return 0:10:5 1
block 0:4:22 3
rfn 0:4:1 f 2 1 1 2 3 3
rpname 0:12:5 n 1
rname 0:12:9 f fn 2
rname 0:12:11 K cst 1
call 0:12:9 1
let 0:12:1 0
rint 0:13:10 0 #0000000000000000
rname 0:13:13 n loc 1
range 0:13:10 0 0
rpname 0:14:9 n 3
rname 0:14:13 i loc 2
rname 0:14:17 n loc 1
bin 0:14:13 add
let 0:14:5 0
block 0:13:15 1
rfor 0:13:1 i 0:13:5 2
rname 0:16:1 printf pd 0
str 0:16:8 %25d%0A
rname 0:16:16 n loc 1
rname 0:16:20 z none 0
bin 0:16:16 add
call 0:16:1 2
cstmt 0:16:1
prog 5
#end
