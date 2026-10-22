#sea 1
#target arm64-macos
#file stmt_tasg.sea
rtup 10 2 3 3
rtype 0:4:11 i64 s 0 3
param 0:4:8 n 0 0
rtype 0:4:20 i64 s 0 3
rtype 0:4:25 i64 s 0 3
rpname 0:5:9 s 2
rint 0:5:13 0 #0000000000000000
var 0:5:5 0
rint 0:6:14 0 #0000000000000000
rname 0:6:17 n loc 1
range 0:6:14 0 0
rname 0:7:9 s loc 2
rname 0:7:14 i loc 3
asg 0:7:9 add
block 0:6:19 1
rfor 0:6:5 i 0:6:9 3
rname 0:9:13 s loc 2
rname 0:9:16 n loc 1
return 0:9:5 2
block 0:4:30 3
rfn 0:4:1 two 0 1 2 2 10 3
rtype 0:11:16 i64 s 0 3
param 0:11:9 c 1 0
rtype 0:11:25 i64 s 0 3
rtype 0:11:30 i64 s 0 3
rint 0:12:14 0 #0000000000000000
rint 0:12:17 2 #4000000000000000
range 0:12:14 0 0
rname 0:13:9 c loc 1
rint 0:13:14 1 #3FF0000000000000
asg 0:13:9 add
block 0:12:19 1
rfor 0:12:5 i 0:12:9 2
rname 0:15:13 c loc 1
rint 0:15:17 10 #4024000000000000
bin 0:15:13 mul
rname 0:15:21 c loc 1
rint 0:15:25 100 #4059000000000000
bin 0:15:21 add
return 0:15:5 2
block 0:11:35 2
rfn 0:11:1 bump 0 1 2 3 10 3
rtype 0:17:15 f64 s 0 4
param 0:17:8 p 1 0
rtype 0:17:23 i64 s 0 3
param 0:17:20 n 0 0
rtype 0:17:31 i64 s 0 3
rpname 0:18:9 k 3
rint 0:18:13 0 #0000000000000000
var 0:18:5 0
rint 0:19:14 0 #0000000000000000
rint 0:19:17 1 #3FF0000000000000
range 0:19:14 0 0
rname 0:20:10 p loc 1
rname 0:20:13 k loc 3
rname 0:20:18 two fn 2
rname 0:20:22 n loc 2
call 0:20:18 1
tasg 0:20:9 2
block 0:19:19 1
rfor 0:19:5 i 0:19:9 4
rname 0:22:12 k loc 3
return 0:22:5 1
block 0:17:35 3
rfn 0:17:1 put 0 2 1 4 3 4 3
rpname 0:24:5 a 1
float 0:24:9 #3FE0000000000000
var 0:24:1 0
rpname 0:25:5 b 2
rint 0:25:9 0 #0000000000000000
var 0:25:1 0
rname 0:26:2 a loc 1
rname 0:26:5 b loc 2
rname 0:26:10 two fn 2
rint 0:26:14 4 #4010000000000000
call 0:26:10 1
tasg 0:26:1 2
pskip 0:27:2
rname 0:27:5 b loc 2
rname 0:27:10 two fn 2
rint 0:27:14 5 #4014000000000000
call 0:27:10 1
tasg 0:27:1 2
rpname 0:28:5 c 3
rint 0:28:9 1 #3FF0000000000000
var 0:28:1 0
rpname 0:29:5 d 4
rint 0:29:9 0 #0000000000000000
var 0:29:1 0
rname 0:30:2 d loc 4
rname 0:30:5 c loc 3
rname 0:30:10 bump fn 3
rname 0:30:19 c loc 3
ref 0:30:15
call 0:30:10 1
tasg 0:30:1 2
rname 0:31:2 d loc 4
pskip 0:31:5
rname 0:31:10 bump fn 3
rname 0:31:19 c loc 3
ref 0:31:15
call 0:31:10 1
tasg 0:31:1 2
rpname 0:32:5 x 5
float 0:32:9 #3FD0000000000000
var 0:32:1 0
rpname 0:33:5 k 6
rname 0:33:9 put fn 4
rname 0:33:17 x loc 5
ref 0:33:13
rint 0:33:20 3 #4008000000000000
call 0:33:9 2
let 0:33:1 0
rpname 0:34:5 k2 7
rname 0:34:10 put fn 4
rname 0:34:18 x loc 5
ref 0:34:14
rint 0:34:21 5 #4014000000000000
call 0:34:10 2
let 0:34:1 0
rname 0:35:1 printf pd 0
str 0:35:8 %25f%20%25d%20%25d%20%25d%20%25f%20%25d%20%25d%0A
rname 0:35:34 a loc 1
rname 0:35:37 b loc 2
rname 0:35:40 d loc 4
rname 0:35:43 c loc 3
rname 0:35:46 x loc 5
rname 0:35:49 k loc 6
rname 0:35:52 k2 loc 7
call 0:35:1 8
cstmt 0:35:1
prog 15
#end
