#sea 1
#target arm64-macos
#file res_arr_types.sea
rtmat 10 4
rtvec 11 3
rtvec 12 2
rtup 13 2 12 10
rtvec 14 4
rtype 0:3:9 f64 m 0 10
param 0:3:6 a 0 0
rtype 0:3:20 i64 v 0 11
param 0:3:17 b 0 0
rtype 0:3:31 bool v 0 12
rtype 0:3:39 f64 m 0 10
rpname 0:4:9 r 3
rname 0:4:13 filled pd 0
true 0:4:20
rname 0:4:26 len pd 0
rname 0:4:30 b loc 2
call 0:4:26 1
call 0:4:13 2
var 0:4:5 0
rname 0:5:14 b loc 2
rname 0:6:9 r loc 3
rint 0:6:11 0 #0000000000000000
index 0:6:9 1
rname 0:6:16 x loc 4
rint 0:6:20 0 #0000000000000000
bin 0:6:16 gt
asg 0:6:9 set
block 0:5:16 1
rfor 0:5:5 x 0:5:9 4
rname 0:8:13 r loc 3
rname 0:8:16 a loc 1
return 0:8:5 2
block 0:3:47 3
rfn 0:3:1 f 0 2 2 2 13 10 11
rpname 0:10:5 m 1
rtype 0:10:8 f64 m 0 10
rname 0:10:17 zeros pd 0
rint 0:10:23 2 #4000000000000000
rint 0:10:26 2 #4000000000000000
call 0:10:17 2
let 0:10:1 1
rpname 0:11:5 v 2
rtype 0:11:8 i64 v 0 11
rname 0:11:16 filled pd 0
rint 0:11:23 1 #3FF0000000000000
rint 0:11:26 3 #4008000000000000
call 0:11:16 2
let 0:11:1 1
rpname 0:12:5 w 3
rtype 0:12:8 f64 v 0 14
rname 0:12:16 zeros pd 0
rint 0:12:22 1 #3FF0000000000000
call 0:12:16 1
let 0:12:1 1
rpname 0:13:6 p 4
rpname 0:13:9 q 5
ptuple 0:13:5 2
rname 0:13:14 f fn 2
rname 0:13:16 m loc 1
rname 0:13:19 v loc 2
call 0:13:14 2
let 0:13:1 0
prog 5
#end
