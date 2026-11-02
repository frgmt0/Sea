#sea 1
#target arm64-macos
#file la8_lib_check.sea
rtmat 10 4
rtmat 11 3
rtvec 12 4
rtype 0:1:9 f64 m 0 10
param 0:1:6 A 0 0
rtype 0:1:21 i64 m 0 11
param 0:1:17 Ai 0 0
rtype 0:1:32 f64 v 0 12
param 0:1:29 b 0 0
rtype 0:1:42 Lu s 0 8
param 0:1:39 F 0 0
rtype 0:1:49 Chol s 0 9
rpname 0:2:9 M 5
float 0:2:14 #4010000000000000
float 0:2:19 #0000000000000000
row 0:2:14 2
float 0:2:24 #0000000000000000
float 0:2:29 #4010000000000000
row 0:2:24 2
array 0:2:13 2
let 0:2:5 0
rpname 0:3:9 Mi 6
rint 0:3:15 4 #4010000000000000
rint 0:3:18 0 #0000000000000000
row 0:3:15 2
rint 0:3:21 0 #0000000000000000
rint 0:3:24 4 #4010000000000000
row 0:3:21 2
array 0:3:14 2
let 0:3:5 0
rpname 0:4:9 G 7
rtype 0:4:12 Lu s 0 8
rname 0:4:17 lu pd 0
rname 0:4:20 Ai loc 2
call 0:4:17 1
let 0:4:5 1
rpname 0:5:9 C 8
rname 0:5:13 chol pd 0
rname 0:5:18 A loc 1
call 0:5:13 1
let 0:5:5 0
rpname 0:6:9 x 9
rname 0:6:13 solve pd 0
rname 0:6:19 F loc 4
rname 0:6:22 b loc 3
call 0:6:13 2
let 0:6:5 0
rpname 0:7:9 y 10
rname 0:7:13 solve pd 0
rname 0:7:19 C loc 8
rname 0:7:22 A loc 1
call 0:7:13 2
let 0:7:5 0
rpname 0:8:9 z 11
rname 0:8:13 solve pd 0
rname 0:8:19 Ai loc 2
rname 0:8:23 b loc 3
call 0:8:13 2
let 0:8:5 0
rpname 0:9:9 r 12
rname 0:9:13 rcond pd 0
rname 0:9:19 G loc 7
call 0:9:13 1
let 0:9:5 0
rpname 0:10:9 e 13
rname 0:10:13 eig_sym pd 0
rname 0:10:21 M loc 5
call 0:10:13 1
let 0:10:5 0
rpname 0:11:9 e2 14
rname 0:11:14 eig_sym pd 0
rname 0:11:22 Mi loc 6
rname 0:11:26 A loc 1
call 0:11:14 2
let 0:11:5 0
rname 0:12:5 printf pd 0
str 0:12:12 %25g%20%25g%20%25g%20%25g%20%25g%20%25g%0A
rname 0:12:35 x loc 9
rint 0:12:37 0 #0000000000000000
index 0:12:35 1
rname 0:12:41 y loc 10
rint 0:12:43 0 #0000000000000000
rint 0:12:46 0 #0000000000000000
index 0:12:41 2
rname 0:12:50 z loc 11
rint 0:12:52 0 #0000000000000000
index 0:12:50 1
rname 0:12:56 r loc 12
rname 0:12:59 e loc 13
rint 0:12:61 0 #0000000000000000
index 0:12:59 1
rname 0:12:65 e2 loc 14
rint 0:12:68 0 #0000000000000000
index 0:12:65 1
call 0:12:5 7
cstmt 0:12:5
rname 0:13:12 C loc 8
return 0:13:5 1
block 0:1:54 12
rfn 0:1:1 g 2 4 1 2 9 10 11 12 8
prog 1
#end
