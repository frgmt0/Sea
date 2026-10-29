#sea 1
#target arm64-macos
#file elem6_vec.sea
rtype 0:4:19 f64 s 0 4
param 0:4:16 x 0 0
rtype 0:4:27 f64 s 0 4
param 0:4:24 k 0 0
rtype 0:4:35 f64 s 0 4
rname 0:5:12 x loc 1
rname 0:5:16 k loc 2
bin 0:5:12 mul
float 0:5:20 #3FF0000000000000
bin 0:5:12 add
return 0:5:5 1
block 0:4:39 1
rfn 0:4:1 f 1 2 1 2 4 4 4
rpname 0:7:5 v 1
rname 0:7:9 zeros pd 0
rint 0:7:15 3 #4008000000000000
call 0:7:9 1
let 0:7:1 0
rpname 0:8:5 w 2
rname 0:8:9 f fn 2
rname 0:8:11 v loc 1
float 0:8:14 #4000000000000000
call 0:8:9 2
let 0:8:1 0
rpname 0:9:5 s 3
rname 0:9:9 f fn 2
float 0:9:11 #3FE0000000000000
float 0:9:16 #4010000000000000
call 0:9:9 2
let 0:9:1 0
rname 0:10:1 printf pd 0
str 0:10:8 %25g%20%25g%0A
rname 0:10:19 w loc 2
rint 0:10:21 2 #4000000000000000
index 0:10:19 1
rname 0:10:25 s loc 3
call 0:10:1 3
cstmt 0:10:1
prog 5
#end
