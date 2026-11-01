#sea 1
#target arm64-macos
#file la8_l21_vm.sea
rtfvec 10 4 3
rtfmat 11 4 3 2
rpname 0:1:5 x 1
rint 0:1:12 3 #4008000000000000
rtype 0:1:8 f64 fv 1 10
float 0:1:18 #3FF0000000000000
float 0:1:23 #4000000000000000
float 0:1:28 #4008000000000000
row 0:1:18 3
array 0:1:17 1
let 0:1:1 1
rpname 0:2:5 A 2
rint 0:2:12 3 #4008000000000000
rint 0:2:14 2 #4000000000000000
rtype 0:2:8 f64 fm 2 11
float 0:2:20 #3FF0000000000000
float 0:2:25 #4000000000000000
row 0:2:20 2
float 0:2:30 #4008000000000000
float 0:2:35 #4010000000000000
row 0:2:30 2
float 0:2:40 #4014000000000000
float 0:2:45 #4018000000000000
row 0:2:40 2
array 0:2:19 3
let 0:2:1 1
rpname 0:3:5 y 3
rname 0:3:9 x loc 1
rname 0:3:13 A loc 2
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
