#sea 1
#target arm64-macos
#file la8_l21_mv.sea
rtfmat 10 4 2 2
rtfvec 11 4 2
rpname 0:1:5 A 1
rint 0:1:12 2 #4000000000000000
rint 0:1:14 2 #4000000000000000
rtype 0:1:8 f64 fm 2 10
float 0:1:20 #3FF0000000000000
float 0:1:25 #4000000000000000
row 0:1:20 2
float 0:1:30 #4008000000000000
float 0:1:35 #4010000000000000
row 0:1:30 2
array 0:1:19 2
let 0:1:1 1
rpname 0:2:5 x 2
rint 0:2:12 2 #4000000000000000
rtype 0:2:8 f64 fv 1 11
float 0:2:18 #4014000000000000
float 0:2:23 #4018000000000000
row 0:2:18 2
array 0:2:17 1
let 0:2:1 1
rpname 0:3:5 y 3
rname 0:3:9 A loc 1
rname 0:3:13 x loc 2
bin 0:3:9 matmul
let 0:3:1 0
rname 0:4:1 printf pd 0
str 0:4:8 %25g%20%25g%0A
rname 0:4:19 y loc 3
rint 0:4:21 0 #0000000000000000
index 0:4:19 1
rname 0:4:25 y loc 3
rint 0:4:27 1 #3FF0000000000000
index 0:4:25 1
call 0:4:1 3
cstmt 0:4:1
prog 4
#end
