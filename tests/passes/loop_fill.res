#sea 1
#target arm64-macos
#file loop_fill.sea
rtype 0:1:16 i64 s 0 3
param 0:1:9 k 1 0
rtype 0:1:24 i64 s 0 3
rint 0:2:14 0 #0000000000000000
rint 0:2:17 2 #4000000000000000
range 0:2:14 0 0
rname 0:3:9 k loc 1
rint 0:3:14 1 #3FF0000000000000
asg 0:3:9 add
block 0:2:19 1
rfor 0:2:5 i 0:2:9 2
rname 0:5:12 k loc 1
return 0:5:5 1
block 0:1:28 2
rfn 0:1:1 grow 0 1 1 2 3 3
rtype 0:7:17 i64 s 0 3
param 0:7:10 n 1 0
rtype 0:7:25 f64 s 0 4
rpname 0:8:9 v 2
rname 0:8:13 filled pd 0
float 0:8:20 #3FE0000000000000
rname 0:8:25 n loc 1
call 0:8:13 2
let 0:8:5 0
rpname 0:9:9 s 3
float 0:9:13 #0000000000000000
var 0:9:5 0
rname 0:10:14 v loc 2
rname 0:11:9 s loc 3
rname 0:11:14 x loc 4
asg 0:11:9 add
block 0:10:16 1
rfor 0:10:5 x 0:10:9 4
rname 0:13:12 s loc 3
return 0:13:5 1
block 0:7:29 4
rfn 0:7:1 count 0 1 1 3 4 3
rpname 0:15:5 vf 1
rname 0:15:10 filled pd 0
float 0:15:17 #4004000000000000
rint 0:15:22 3 #4008000000000000
call 0:15:10 2
let 0:15:1 0
rpname 0:16:5 vi 2
rname 0:16:10 filled pd 0
rint 0:16:17 4 #4010000000000000
rint 0:16:20 2 #4000000000000000
call 0:16:10 2
let 0:16:1 0
rpname 0:17:5 vb 3
rname 0:17:10 filled pd 0
true 0:17:17
rint 0:17:23 2 #4000000000000000
call 0:17:10 2
let 0:17:1 0
rname 0:18:1 printf pd 0
str 0:18:8 %25g%20%25d%20%25d%20%25d%0A
rname 0:18:25 vf loc 1
rint 0:18:28 2 #4000000000000000
index 0:18:25 1
rname 0:18:32 vi loc 2
rint 0:18:35 1 #3FF0000000000000
index 0:18:32 1
rname 0:18:39 vb loc 3
rint 0:18:42 0 #0000000000000000
index 0:18:39 1
rname 0:18:46 len pd 0
rname 0:18:50 vb loc 3
call 0:18:46 1
call 0:18:1 5
cstmt 0:18:1
rpname 0:19:5 mf 4
rname 0:19:10 filled pd 0
float 0:19:17 #3FD0000000000000
rint 0:19:23 2 #4000000000000000
rint 0:19:26 3 #4008000000000000
call 0:19:10 3
let 0:19:1 0
rpname 0:20:5 mi 5
rname 0:20:10 filled pd 0
rint 0:20:18 7 #401C000000000000
neg 0:20:17
rint 0:20:21 3 #4008000000000000
rint 0:20:24 1 #3FF0000000000000
call 0:20:10 3
let 0:20:1 0
rpname 0:21:5 mb 6
rname 0:21:10 filled pd 0
false 0:21:17
rint 0:21:24 1 #3FF0000000000000
rint 0:21:27 2 #4000000000000000
call 0:21:10 3
let 0:21:1 0
rname 0:22:1 printf pd 0
str 0:22:8 %25g%20%25d%20%25d%0A
rname 0:22:22 mf loc 4
rint 0:22:25 1 #3FF0000000000000
rint 0:22:28 2 #4000000000000000
index 0:22:22 2
rname 0:22:32 mi loc 5
rint 0:22:35 2 #4000000000000000
rint 0:22:38 0 #0000000000000000
index 0:22:32 2
rname 0:22:42 mb loc 6
rint 0:22:45 0 #0000000000000000
rint 0:22:48 1 #3FF0000000000000
index 0:22:42 2
call 0:22:1 4
cstmt 0:22:1
rpname 0:23:5 mo 7
rname 0:23:10 ones pd 0
rint 0:23:15 2 #4000000000000000
rint 0:23:18 2 #4000000000000000
call 0:23:10 2
let 0:23:1 0
rpname 0:24:5 mz 8
rname 0:24:10 zeros pd 0
rint 0:24:16 3 #4008000000000000
rint 0:24:19 2 #4000000000000000
call 0:24:10 2
let 0:24:1 0
rname 0:25:1 printf pd 0
str 0:25:8 %25g%20%25g%20%25d%0A
rname 0:25:22 mo loc 7
rint 0:25:25 1 #3FF0000000000000
rint 0:25:28 1 #3FF0000000000000
index 0:25:22 2
rname 0:25:32 mz loc 8
rint 0:25:35 2 #4000000000000000
rint 0:25:38 1 #3FF0000000000000
index 0:25:32 2
rname 0:25:42 rows pd 0
rname 0:25:47 mz loc 8
call 0:25:42 1
call 0:25:1 4
cstmt 0:25:1
rpname 0:26:5 m 9
rint 0:26:9 4 #4010000000000000
var 0:26:1 0
rname 0:27:1 printf pd 0
str 0:27:8 %25g%20%25g%0A
rname 0:27:19 count fn 3
rname 0:27:29 m loc 9
ref 0:27:25
call 0:27:19 1
rname 0:27:33 count fn 3
rname 0:27:43 m loc 9
ref 0:27:39
call 0:27:33 1
call 0:27:1 3
cstmt 0:27:1
rpname 0:28:5 k 10
rint 0:28:9 1 #3FF0000000000000
var 0:28:1 0
rpname 0:29:5 vk 11
rname 0:29:10 filled pd 0
rname 0:29:17 k loc 10
rname 0:29:20 grow fn 2
rname 0:29:29 k loc 10
ref 0:29:25
call 0:29:20 1
call 0:29:10 2
let 0:29:1 0
rname 0:30:1 printf pd 0
str 0:30:8 %25d%20%25d%20%25d%0A
rname 0:30:22 vk loc 11
rint 0:30:25 0 #0000000000000000
index 0:30:22 1
rname 0:30:29 len pd 0
rname 0:30:33 vk loc 11
call 0:30:29 1
rname 0:30:38 k loc 10
call 0:30:1 4
cstmt 0:30:1
rpname 0:31:5 c 12
rname 0:31:9 k loc 10
rint 0:31:13 2 #4000000000000000
bin 0:31:9 gt
let 0:31:1 0
rpname 0:32:5 vc 13
rname 0:32:10 ones pd 0
rname 0:32:18 c loc 12
rint 0:32:22 2 #4000000000000000
rint 0:32:33 3 #4008000000000000
ifx 0:32:15
call 0:32:10 1
let 0:32:1 0
rpname 0:33:5 p 14
true 0:33:9
let 0:33:1 0
rpname 0:34:5 q 15
rname 0:34:9 k loc 10
rint 0:34:14 3 #4008000000000000
bin 0:34:9 eq
let 0:34:1 0
rpname 0:35:5 vq 16
rname 0:35:10 filled pd 0
rname 0:35:17 p loc 14
rname 0:35:22 q loc 15
bin 0:35:17 and
rname 0:35:25 m loc 9
call 0:35:10 2
let 0:35:1 0
rname 0:36:1 printf pd 0
str 0:36:8 %25g%20%25d%20%25d%20%25d%0A
rname 0:36:25 vc loc 13
rint 0:36:28 1 #3FF0000000000000
index 0:36:25 1
rname 0:36:32 len pd 0
rname 0:36:36 vc loc 13
call 0:36:32 1
rname 0:36:41 vq loc 16
rint 0:36:44 3 #4008000000000000
index 0:36:41 1
rname 0:36:48 grow fn 2
rname 0:36:57 m loc 9
ref 0:36:53
call 0:36:48 1
call 0:36:1 5
cstmt 0:36:1
prog 24
#end
