#sea 1
#target arm64-macos
#file la8_lib_rcall.sea
rtmat 10 4
rtvec 11 4
rtype 0:1:9 f64 m 0 10
param 0:1:6 A 0 0
rtype 0:1:20 f64 v 0 11
param 0:1:17 b 0 0
rtype 0:1:30 i64 s 0 3
param 0:1:27 n 0 0
rtype 0:1:38 f64 s 0 4
rname 0:2:8 n loc 3
rint 0:2:12 0 #0000000000000000
bin 0:2:8 gt
rname 0:2:23 g fn 2
rname 0:2:25 A loc 1
rname 0:2:28 b loc 2
rname 0:2:31 n loc 3
rint 0:2:35 1 #3FF0000000000000
bin 0:2:31 sub
call 0:2:23 3
return 0:2:16 1
block 0:2:14 1
if 0:2:5 0
rpname 0:3:9 F 4
rname 0:3:13 lu pd 0
rname 0:3:16 A loc 1
call 0:3:13 1
let 0:3:5 0
rpname 0:4:9 C 5
rname 0:4:13 chol pd 0
rname 0:4:18 A loc 1
call 0:4:13 1
let 0:4:5 0
rpname 0:5:9 x 6
rname 0:5:13 solve pd 0
rname 0:5:19 F loc 4
rname 0:5:22 b loc 2
call 0:5:13 2
let 0:5:5 0
rpname 0:6:9 Y 7
rname 0:6:13 solve pd 0
rname 0:6:19 C loc 5
rname 0:6:22 A loc 1
call 0:6:13 2
let 0:6:5 0
rpname 0:7:9 z 8
rname 0:7:13 solve pd 0
rname 0:7:19 A loc 1
rname 0:7:22 b loc 2
call 0:7:13 2
let 0:7:5 0
rpname 0:8:9 r 9
rname 0:8:13 rcond pd 0
rname 0:8:19 lu pd 0
rname 0:8:22 A loc 1
call 0:8:19 1
call 0:8:13 1
let 0:8:5 0
rpname 0:9:9 e 10
rname 0:9:13 eig_sym pd 0
rname 0:9:21 A loc 1
call 0:9:13 1
let 0:9:5 0
rpname 0:10:9 w 11
rname 0:10:13 eig_sym pd 0
rname 0:10:21 A loc 1
rname 0:10:24 Y loc 7
call 0:10:13 2
let 0:10:5 0
rname 0:11:12 x loc 6
rint 0:11:14 1 #3FF0000000000000
index 0:11:12 1
rname 0:11:19 Y loc 7
rint 0:11:21 1 #3FF0000000000000
rint 0:11:24 0 #0000000000000000
index 0:11:19 2
bin 0:11:12 add
rname 0:11:29 z loc 8
rint 0:11:31 0 #0000000000000000
index 0:11:29 1
bin 0:11:12 add
rname 0:11:36 r loc 9
bin 0:11:12 add
rname 0:11:40 e loc 10
rint 0:11:42 0 #0000000000000000
index 0:11:40 1
bin 0:11:12 add
rname 0:11:47 w loc 11
rint 0:11:49 1 #3FF0000000000000
index 0:11:47 1
bin 0:11:12 add
rname 0:11:54 rcond pd 0
rname 0:11:60 F loc 4
call 0:11:54 1
bin 0:11:12 add
return 0:11:5 1
block 0:1:42 10
rfn 0:1:1 g 0 3 1 2 4 10 11 3
rpname 0:13:5 A 1
rtype 0:13:8 f64 m 0 10
float 0:13:18 #4010000000000000
float 0:13:23 #0000000000000000
row 0:13:18 2
float 0:13:28 #0000000000000000
float 0:13:33 #3FF0000000000000
row 0:13:28 2
array 0:13:17 2
let 0:13:1 1
rpname 0:14:5 b 2
rtype 0:14:8 f64 v 0 11
float 0:14:17 #4020000000000000
float 0:14:22 #4022000000000000
row 0:14:17 2
array 0:14:16 1
let 0:14:1 1
rname 0:15:1 printf pd 0
str 0:15:8 %25g%0A
rname 0:15:16 g fn 2
rname 0:15:18 A loc 1
rname 0:15:21 b loc 2
rint 0:15:24 1 #3FF0000000000000
call 0:15:16 3
call 0:15:1 2
cstmt 0:15:1
prog 4
#end
