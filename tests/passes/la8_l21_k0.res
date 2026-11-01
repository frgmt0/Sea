#sea 1
#target arm64-macos
#file la8_l21_k0.sea
rtfmat 10 4 2 0
rtfmat 11 4 0 3
rpname 0:1:5 Z 1
rint 0:1:12 2 #4000000000000000
rint 0:1:14 0 #0000000000000000
rtype 0:1:8 f64 fm 2 10
array 0:1:19 0
let 0:1:1 1
rpname 0:2:5 W 2
rint 0:2:12 0 #0000000000000000
rint 0:2:14 3 #4008000000000000
rtype 0:2:8 f64 fm 2 11
array 0:2:19 0
let 0:2:1 1
rpname 0:3:5 C 3
rname 0:3:9 Z loc 1
rname 0:3:13 W loc 2
bin 0:3:9 matmul
let 0:3:1 0
rname 0:4:1 printf pd 0
str 0:4:8 %25g%20%25g%0A
rname 0:4:19 C loc 3
rint 0:4:21 0 #0000000000000000
rint 0:4:24 0 #0000000000000000
index 0:4:19 2
rname 0:4:28 C loc 3
rint 0:4:30 1 #3FF0000000000000
rint 0:4:33 2 #4000000000000000
index 0:4:28 2
call 0:4:1 3
cstmt 0:4:1
prog 4
#end
