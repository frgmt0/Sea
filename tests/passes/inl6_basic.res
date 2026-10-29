#sea 1
#target arm64-macos
#file inl6_basic.sea
rtype 0:5:13 f64 s 0 4
param 0:5:10 x 0 0
rtype 0:5:21 f64 s 0 4
rname 0:6:12 x loc 1
float 0:6:16 #4000000000000000
bin 0:6:12 mul
return 0:6:5 1
block 0:5:25 1
rfn 0:5:1 twice 2 1 1 2 4 4
rtype 0:8:12 i64 s 0 3
param 0:8:9 n 0 0
rtype 0:8:20 i64 s 0 3
rpname 0:9:9 s 2
rint 0:9:13 0 #0000000000000000
var 0:9:5 0
rint 0:10:14 0 #0000000000000000
rname 0:10:17 n loc 1
range 0:10:14 0 0
rname 0:11:9 s loc 2
rname 0:11:14 i loc 3
asg 0:11:9 add
block 0:10:19 1
rfor 0:10:5 i 0:10:9 3
rname 0:13:12 s loc 2
return 0:13:5 1
block 0:8:24 3
rfn 0:8:1 keep 0 1 1 3 3 3
rpname 0:15:5 a 1
rname 0:15:9 twice fn 2
float 0:15:15 #3FF8000000000000
call 0:15:9 1
let 0:15:1 0
rpname 0:16:5 b 2
rname 0:16:9 twice fn 2
rname 0:16:15 a loc 1
call 0:16:9 1
float 0:16:20 #3FF0000000000000
bin 0:16:9 add
let 0:16:1 0
rname 0:17:1 printf pd 0
str 0:17:8 %25g%20%25g%20%25d%20%25d%0A
rname 0:17:25 a loc 1
rname 0:17:28 b loc 2
rname 0:17:31 keep fn 3
rint 0:17:36 3 #4008000000000000
call 0:17:31 1
rname 0:17:40 keep fn 3
rint 0:17:45 4 #4010000000000000
call 0:17:40 1
call 0:17:1 5
cstmt 0:17:1
prog 5
#end
