#sea 1
#target arm64-macos
#file fuse7c2_mm_sum.sea
rtmat 10 4
rtmat 11 2
rtvec 12 4
rpname 0:5:5 A 1
rtype 0:5:8 f64 m 0 10
float 0:5:18 #3FF0000000000000
float 0:5:23 #4000000000000000
row 0:5:18 2
float 0:5:28 #4008000000000000
float 0:5:33 #4010000000000000
row 0:5:28 2
array 0:5:17 2
let 0:5:1 1
rpname 0:6:5 B 2
rtype 0:6:8 f64 m 0 10
float 0:6:18 #3FE0000000000000
float 0:6:23 #3FE0000000000000
row 0:6:18 2
float 0:6:28 #3FE0000000000000
float 0:6:33 #3FE0000000000000
row 0:6:28 2
array 0:6:17 2
let 0:6:1 1
rpname 0:7:5 m 3
rtype 0:7:8 bool m 0 11
true 0:7:19
false 0:7:25
row 0:7:19 2
true 0:7:32
true 0:7:38
row 0:7:32 2
array 0:7:18 2
let 0:7:1 1
rpname 0:8:5 v 4
rtype 0:8:8 f64 v 0 12
float 0:8:17 #3FF0000000000000
float 0:8:22 #4000000000000000
float 0:8:27 #4008000000000000
row 0:8:17 3
array 0:8:16 1
let 0:8:1 1
rpname 0:9:5 s0 5
rname 0:9:10 sum pd 0
rname 0:9:14 v loc 4
float 0:9:18 #4000000000000000
bin 0:9:14 mul
call 0:9:10 1
let 0:9:1 0
rname 0:10:1 printf pd 0
str 0:10:8 %25g%0A
rname 0:10:16 s0 loc 5
call 0:10:1 2
cstmt 0:10:1
rpname 0:11:5 s 6
rname 0:11:9 sum pd 0
rname 0:11:13 A loc 1
rname 0:11:15 m loc 3
index 0:11:13 1
rname 0:11:20 B loc 2
rname 0:11:22 m loc 3
index 0:11:20 1
bin 0:11:13 sub
call 0:11:9 1
let 0:11:1 0
rname 0:12:1 printf pd 0
str 0:12:8 %25g%0A
rname 0:12:16 s loc 6
call 0:12:1 2
cstmt 0:12:1
prog 8
#end
