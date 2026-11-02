#sea 1
#target arm64-macos
#file la8_lib_hirl.sea
rtmat 10 3
rtvec 11 4
rtype 0:1:10 i64 m 0 10
param 0:1:6 Ai 0 0
rtype 0:1:21 f64 v 0 11
param 0:1:18 b 0 0
rtype 0:1:31 i64 s 0 3
param 0:1:28 n 0 0
rtype 0:1:39 f64 s 0 4
rname 0:2:8 n loc 3
rint 0:2:12 0 #0000000000000000
bin 0:2:8 gt
rname 0:2:23 g fn 2
rname 0:2:25 Ai loc 1
rname 0:2:29 b loc 2
rname 0:2:32 n loc 3
rint 0:2:36 1 #3FF0000000000000
bin 0:2:32 sub
call 0:2:23 3
return 0:2:16 1
block 0:2:14 1
if 0:2:5 0
rpname 0:3:9 M 4
float 0:3:14 #4010000000000000
float 0:3:19 #0000000000000000
row 0:3:14 2
float 0:3:24 #0000000000000000
float 0:3:29 #3FF0000000000000
row 0:3:24 2
array 0:3:13 2
let 0:3:5 0
rpname 0:4:9 F 5
rname 0:4:13 lu pd 0
rname 0:4:16 Ai loc 1
call 0:4:13 1
let 0:4:5 0
rpname 0:5:9 e 6
rname 0:5:13 eig_sym pd 0
rname 0:5:21 M loc 4
call 0:5:13 1
let 0:5:5 0
rpname 0:6:9 x 7
rname 0:6:13 solve pd 0
rname 0:6:19 F loc 5
rname 0:6:22 b loc 2
rname 0:6:26 b loc 2
bin 0:6:22 add
call 0:6:13 2
let 0:6:5 0
rname 0:7:12 e loc 6
rint 0:7:14 0 #0000000000000000
index 0:7:12 1
rname 0:7:19 x loc 7
rint 0:7:21 1 #3FF0000000000000
index 0:7:19 1
bin 0:7:12 add
return 0:7:5 1
block 0:1:43 6
rfn 0:1:1 g 0 3 1 2 4 10 11 3
rpname 0:9:5 Ai 1
rtype 0:9:9 i64 m 0 10
rint 0:9:19 4 #4010000000000000
rint 0:9:22 0 #0000000000000000
row 0:9:19 2
rint 0:9:25 0 #0000000000000000
rint 0:9:28 1 #3FF0000000000000
row 0:9:25 2
array 0:9:18 2
let 0:9:1 1
rpname 0:10:5 b 2
rtype 0:10:8 f64 v 0 11
float 0:10:17 #4020000000000000
float 0:10:22 #4022000000000000
row 0:10:17 2
array 0:10:16 1
let 0:10:1 1
rname 0:11:1 printf pd 0
str 0:11:8 %25g%0A
rname 0:11:16 g fn 2
rname 0:11:18 Ai loc 1
rname 0:11:22 b loc 2
rint 0:11:25 1 #3FF0000000000000
call 0:11:16 3
call 0:11:1 2
cstmt 0:11:1
prog 4
#end
