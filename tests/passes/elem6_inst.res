#sea 1
#target arm64-macos
#file elem6_inst.sea
rtype 0:7:19 f64 s 0 4
param 0:7:16 x 0 0
rtype 0:7:27 f64 s 0 4
param 0:7:24 y 0 0
rtype 0:7:35 str s 0 5
param 0:7:32 s 0 0
rtype 0:7:43 f64 s 0 4
rname 0:8:12 x loc 1
rname 0:8:16 y loc 2
bin 0:8:12 mul
return 0:8:5 1
block 0:7:47 1
rfn 0:7:1 h 1 3 1 2 4 4 4 5
rtype 0:10:24 f64 s 0 4
param 0:10:21 x 0 0
rtype 0:10:32 f64 s 0 4
rname 0:11:12 x loc 1
return 0:11:5 1
block 0:10:36 1
rfn 0:10:1 unused 1 1 1 3 4 4
rpname 0:13:5 a 1
rname 0:13:9 filled pd 0
float 0:13:16 #4000000000000000
rint 0:13:21 2 #4000000000000000
call 0:13:9 2
let 0:13:1 0
rpname 0:14:5 k 2
rname 0:14:9 filled pd 0
rint 0:14:16 3 #4008000000000000
rint 0:14:19 2 #4000000000000000
call 0:14:9 2
let 0:14:1 0
rpname 0:15:5 m 3
rname 0:15:9 zeros pd 0
rint 0:15:15 2 #4000000000000000
rint 0:15:18 3 #4008000000000000
call 0:15:9 2
let 0:15:1 0
rpname 0:16:5 f 4
float 0:16:10 #3FF8000000000000
float 0:16:15 #4004000000000000
row 0:16:10 2
array 0:16:9 1
let 0:16:1 0
rpname 0:17:5 r1 5
rname 0:17:10 h fn 2
rname 0:17:12 a loc 1
float 0:17:15 #4000000000000000
str 0:17:20 u
call 0:17:10 3
let 0:17:1 0
rpname 0:18:5 r2 6
rname 0:18:10 h fn 2
rname 0:18:12 k loc 2
float 0:18:15 #4000000000000000
str 0:18:20 u
call 0:18:10 3
let 0:18:1 0
rpname 0:19:5 r3 7
rname 0:19:10 h fn 2
rname 0:19:12 m loc 3
rname 0:19:15 a loc 1
dot 0:19:15 col
str 0:19:22 u
call 0:19:10 3
let 0:19:1 0
rpname 0:20:5 r4 8
rname 0:20:10 h fn 2
rname 0:20:12 f loc 4
float 0:20:15 #4000000000000000
str 0:20:20 u
call 0:20:10 3
let 0:20:1 0
rpname 0:21:5 r5 9
rname 0:21:10 h fn 2
rname 0:21:12 f loc 4
rname 0:21:15 a loc 1
str 0:21:18 u
call 0:21:10 3
let 0:21:1 0
rpname 0:22:5 r6 10
rname 0:22:10 h fn 2
float 0:22:12 #3FF0000000000000
float 0:22:17 #4000000000000000
str 0:22:22 u
call 0:22:10 3
let 0:22:1 0
rname 0:23:1 printf pd 0
str 0:23:8 %25g%20%25g%20%25g%20%25g%20%25g%20%25g%0A
rname 0:23:31 r1 loc 5
rint 0:23:34 1 #3FF0000000000000
index 0:23:31 1
rname 0:23:38 r2 loc 6
rint 0:23:41 1 #3FF0000000000000
index 0:23:38 1
rname 0:23:45 r3 loc 7
rint 0:23:48 1 #3FF0000000000000
rint 0:23:51 2 #4000000000000000
index 0:23:45 2
rname 0:23:55 r4 loc 8
rint 0:23:58 1 #3FF0000000000000
index 0:23:55 1
rname 0:23:62 r5 loc 9
rint 0:23:65 0 #0000000000000000
index 0:23:62 1
rname 0:23:69 r6 loc 10
call 0:23:1 7
cstmt 0:23:1
prog 13
#end
