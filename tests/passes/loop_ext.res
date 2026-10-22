#sea 1
#target arm64-macos
#file loop_ext.sea
rtmat 10 4
rtvec 11 4
rtype 0:1:17 f64 m 0 10
param 0:1:10 A 1 0
rtype 0:1:28 f64 v 0 11
param 0:1:25 v 0 0
rtype 0:1:38 i64 s 0 3
rpname 0:2:9 t 3
rint 0:2:13 0 #0000000000000000
var 0:2:5 0
rint 0:3:14 0 #0000000000000000
rint 0:3:17 2 #4000000000000000
range 0:3:14 0 0
rname 0:4:9 t loc 3
rname 0:4:14 rows pd 0
rname 0:4:19 A loc 1
call 0:4:14 1
rname 0:4:24 cols pd 0
rname 0:4:29 A loc 1
call 0:4:24 1
bin 0:4:14 mul
rname 0:4:34 len pd 0
rname 0:4:38 v loc 2
call 0:4:34 1
bin 0:4:14 add
rname 0:4:43 numel pd 0
rname 0:4:49 v loc 2
call 0:4:43 1
bin 0:4:14 add
rname 0:4:54 numel pd 0
rname 0:4:60 A loc 1
call 0:4:54 1
bin 0:4:14 add
asg 0:4:9 add
block 0:3:19 1
rfor 0:3:5 i 0:3:9 4
rname 0:6:12 t loc 3
return 0:6:5 1
block 0:1:42 3
rfn 0:1:1 shape 0 2 1 2 3 10 11
rpname 0:8:5 v 1
rname 0:8:9 zeros pd 0
rint 0:8:15 5 #4014000000000000
call 0:8:9 1
let 0:8:1 0
rpname 0:9:5 m1 2
rname 0:9:10 zeros pd 0
rint 0:9:16 2 #4000000000000000
rint 0:9:19 3 #4008000000000000
call 0:9:10 2
let 0:9:1 0
rpname 0:10:5 m2 3
rname 0:10:10 ones pd 0
rint 0:10:15 4 #4010000000000000
rint 0:10:18 1 #3FF0000000000000
call 0:10:10 2
let 0:10:1 0
rname 0:11:1 printf pd 0
str 0:11:8 %25d%20%25d%20%25d%20%25d%20%25d%0A
rname 0:11:28 len pd 0
rname 0:11:32 v loc 1
call 0:11:28 1
rname 0:11:36 numel pd 0
rname 0:11:42 v loc 1
call 0:11:36 1
rname 0:11:46 rows pd 0
rname 0:11:51 m1 loc 2
call 0:11:46 1
rname 0:11:56 cols pd 0
rname 0:11:61 m1 loc 2
call 0:11:56 1
rname 0:11:66 numel pd 0
rname 0:11:72 m1 loc 2
call 0:11:66 1
call 0:11:1 6
cstmt 0:11:1
rpname 0:12:5 m 4
rname 0:12:9 m2 loc 3
var 0:12:1 0
rname 0:13:1 printf pd 0
str 0:13:8 %25d%20%25d%0A
rname 0:13:19 shape fn 2
rname 0:13:29 m loc 4
ref 0:13:25
rname 0:13:32 v loc 1
call 0:13:19 2
rname 0:13:36 shape fn 2
rname 0:13:46 m loc 4
ref 0:13:42
rname 0:13:49 zeros pd 0
rint 0:13:55 0 #0000000000000000
call 0:13:49 1
call 0:13:36 2
call 0:13:1 3
cstmt 0:13:1
rname 0:14:1 printf pd 0
str 0:14:8 %25d%20%25d%0A
rname 0:14:19 len pd 0
rname 0:14:23 ones pd 0
rint 0:14:28 4 #4010000000000000
call 0:14:23 1
call 0:14:19 1
rname 0:14:33 numel pd 0
rname 0:14:39 zeros pd 0
rint 0:14:45 2 #4000000000000000
rint 0:14:48 3 #4008000000000000
call 0:14:39 2
call 0:14:33 1
call 0:14:1 3
cstmt 0:14:1
rname 0:15:1 printf pd 0
str 0:15:8 %25d%20%25d%0A
rname 0:15:19 rows pd 0
rname 0:15:24 zeros pd 0
rint 0:15:30 2 #4000000000000000
rint 0:15:33 3 #4008000000000000
call 0:15:24 2
call 0:15:19 1
rname 0:15:38 cols pd 0
rname 0:15:43 ones pd 0
rint 0:15:48 1 #3FF0000000000000
rint 0:15:51 7 #401C000000000000
call 0:15:43 2
call 0:15:38 1
call 0:15:1 3
cstmt 0:15:1
rpname 0:16:5 c 5
rname 0:16:9 rows pd 0
rname 0:16:14 m1 loc 2
call 0:16:9 1
rint 0:16:20 2 #4000000000000000
bin 0:16:9 gt
let 0:16:1 0
rname 0:17:1 printf pd 0
str 0:17:8 %25d%0A
rname 0:17:16 numel pd 0
rname 0:17:25 c loc 5
rname 0:17:29 m1 loc 2
rname 0:17:41 m2 loc 3
ifx 0:17:22
call 0:17:16 1
call 0:17:1 2
cstmt 0:17:1
prog 11
#end
