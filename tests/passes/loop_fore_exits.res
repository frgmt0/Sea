#sea 1
#target arm64-macos
#file loop_fore_exits.sea
rtvec 10 4
rtype 0:1:16 f64 v 0 10
param 0:1:13 v 0 0
rtype 0:1:26 f64 s 0 4
param 0:1:23 t 0 0
rtype 0:1:34 i64 s 0 3
rpname 0:2:9 i 3
rint 0:2:13 0 #0000000000000000
var 0:2:5 0
rname 0:3:14 v loc 1
rname 0:4:12 x loc 4
rname 0:4:17 t loc 2
bin 0:4:12 eq
rname 0:4:28 i loc 3
return 0:4:21 1
block 0:4:19 1
if 0:4:9 0
rname 0:5:9 i loc 3
rint 0:5:14 1 #3FF0000000000000
asg 0:5:9 add
block 0:3:16 2
rfor 0:3:5 x 0:3:9 4
rint 0:7:13 1 #3FF0000000000000
neg 0:7:12
return 0:7:5 1
block 0:1:38 3
rfn 0:1:1 where_is 0 2 1 2 3 10 4
rtype 0:9:17 f64 v 0 10
param 0:9:10 v 1 0
rtype 0:9:29 f64 s 0 4
param 0:9:24 cap 0 0
rtype 0:9:37 f64 s 0 4
rpname 0:10:9 s 3
float 0:10:13 #0000000000000000
var 0:10:5 0
rname 0:11:14 v loc 1
rname 0:12:12 x loc 4
float 0:12:16 #0000000000000000
bin 0:12:12 lt
continue 0:12:22
block 0:12:20 1
if 0:12:9 0
rname 0:13:12 x loc 4
rname 0:13:16 cap loc 2
bin 0:13:12 gt
break 0:13:22
block 0:13:20 1
if 0:13:9 0
rname 0:14:9 s loc 3
rname 0:14:14 x loc 4
asg 0:14:9 add
block 0:11:16 3
rfor 0:11:5 x 0:11:9 4
rname 0:16:12 s loc 3
return 0:16:5 1
block 0:9:41 3
rfn 0:9:1 sumto 0 2 1 3 4 10 4
rtype 0:18:13 f64 v 0 10
param 0:18:10 a 0 0
rtype 0:18:23 f64 v 0 10
param 0:18:20 b 0 0
rtype 0:18:33 i64 s 0 3
rpname 0:19:9 c 3
rint 0:19:13 0 #0000000000000000
var 0:19:5 0
rname 0:20:14 a loc 1
rname 0:21:18 b loc 2
rname 0:22:16 x loc 4
rname 0:22:20 y loc 5
bin 0:22:16 lt
rname 0:22:24 c loc 3
rint 0:22:29 1 #3FF0000000000000
asg 0:22:24 add
block 0:22:22 1
if 0:22:13 0
block 0:21:20 1
rfor 0:21:9 y 0:21:13 5
block 0:20:16 1
rfor 0:20:5 x 0:20:9 4
rname 0:25:12 c loc 3
return 0:25:5 1
block 0:18:37 3
rfn 0:18:1 pairs 0 2 1 4 3 10 10
rpname 0:27:5 a 1
rname 0:27:9 filled pd 0
float 0:27:16 #4000000000000000
rint 0:27:21 4 #4010000000000000
call 0:27:9 2
var 0:27:1 0
rname 0:28:1 a loc 1
rint 0:28:3 1 #3FF0000000000000
index 0:28:1 1
float 0:28:9 #3FF0000000000000
neg 0:28:8
asg 0:28:1 set
rname 0:29:1 a loc 1
rint 0:29:3 2 #4000000000000000
index 0:29:1 1
float 0:29:8 #4022000000000000
asg 0:29:1 set
rpname 0:30:5 b 2
rname 0:30:9 zeros pd 0
rint 0:30:15 2 #4000000000000000
call 0:30:9 1
let 0:30:1 0
rname 0:31:1 printf pd 0
str 0:31:8 %25d%20%25d%0A
rname 0:31:19 where_is fn 2
rname 0:31:28 a loc 1
float 0:31:31 #4022000000000000
call 0:31:19 2
rname 0:31:37 where_is fn 2
rname 0:31:46 b loc 2
float 0:31:49 #3FF0000000000000
call 0:31:37 2
call 0:31:1 3
cstmt 0:31:1
rname 0:32:1 printf pd 0
str 0:32:8 %25g%20%25g%0A
rname 0:32:19 sumto fn 3
rname 0:32:29 a loc 1
ref 0:32:25
float 0:32:32 #4014000000000000
call 0:32:19 2
rname 0:32:38 sumto fn 3
rname 0:32:48 a loc 1
ref 0:32:44
float 0:32:51 #4024000000000000
call 0:32:38 2
call 0:32:1 3
cstmt 0:32:1
rname 0:33:1 printf pd 0
str 0:33:8 %25d%20%25d%0A
rname 0:33:19 pairs fn 4
rname 0:33:25 a loc 1
rname 0:33:28 a loc 1
call 0:33:19 2
rname 0:33:32 pairs fn 4
rname 0:33:38 b loc 2
rname 0:33:41 a loc 1
call 0:33:32 2
call 0:33:1 3
cstmt 0:33:1
rpname 0:34:5 n 3
float 0:34:9 #0000000000000000
var 0:34:1 0
rname 0:35:10 ones pd 0
rint 0:35:15 3 #4008000000000000
call 0:35:10 1
rname 0:36:5 n loc 3
rname 0:36:10 x loc 4
asg 0:36:5 add
block 0:35:18 1
rfor 0:35:1 x 0:35:5 4
rpname 0:38:5 c 5
rname 0:38:9 len pd 0
rname 0:38:13 a loc 1
call 0:38:9 1
rint 0:38:18 3 #4008000000000000
bin 0:38:9 gt
let 0:38:1 0
rname 0:39:13 c loc 5
rname 0:39:17 b loc 2
rname 0:39:28 a loc 1
ifx 0:39:10
rname 0:40:5 n loc 3
rname 0:40:10 x loc 6
float 0:40:14 #3FF0000000000000
bin 0:40:10 add
asg 0:40:5 add
block 0:39:32 1
rfor 0:39:1 x 0:39:5 6
rname 0:42:1 printf pd 0
str 0:42:8 %25g%0A
rname 0:42:16 n loc 3
call 0:42:1 2
cstmt 0:42:1
prog 15
#end
