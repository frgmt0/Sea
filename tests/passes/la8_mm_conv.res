#sea 1
#target arm64-macos
#file la8_mm_conv.sea
rtmat 10 3
rpname 0:1:5 Ai 1
rtype 0:1:9 i64 m 0 10
rint 0:1:19 1 #3FF0000000000000
rint 0:1:22 2 #4000000000000000
row 0:1:19 2
rint 0:1:25 3 #4008000000000000
rint 0:1:28 4 #4010000000000000
row 0:1:25 2
array 0:1:18 2
let 0:1:1 1
rpname 0:2:5 x 2
rname 0:2:9 ones pd 0
rint 0:2:14 2 #4000000000000000
call 0:2:9 1
let 0:2:1 0
rpname 0:3:5 y 3
rname 0:3:9 Ai loc 1
rname 0:3:14 x loc 2
bin 0:3:9 matmul
let 0:3:1 0
rpname 0:4:5 F 4
float 0:4:10 #3FF0000000000000
float 0:4:15 #4000000000000000
row 0:4:10 2
float 0:4:20 #4008000000000000
float 0:4:25 #4010000000000000
row 0:4:20 2
array 0:4:9 2
let 0:4:1 0
rpname 0:5:5 z 5
rname 0:5:9 F loc 4
rname 0:5:13 x loc 2
bin 0:5:9 matmul
let 0:5:1 0
rname 0:6:1 printf pd 0
str 0:6:8 %25g%20%25g%0A
rname 0:6:19 y loc 3
rint 0:6:21 1 #3FF0000000000000
index 0:6:19 1
rname 0:6:25 z loc 5
rint 0:6:27 0 #0000000000000000
index 0:6:25 1
call 0:6:1 3
cstmt 0:6:1
prog 6
#end
