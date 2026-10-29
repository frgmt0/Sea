#sea 1
#target arm64-macos
#file res6_default.sea
rint 0:3:11 4 #4010000000000000
rcni 0:3:1 N 0 1 4
rtype 0:4:9 i64 s 0 3
param 0:4:6 a 0 0
rtype 0:4:17 i64 s 0 3
rname 0:4:23 N cst 1
param 0:4:14 b 0 1
rtype 0:4:29 f64 s 0 4
rname 0:4:35 pi pd 0
param 0:4:26 c 0 1
rtype 0:4:42 f64 s 0 4
float 0:4:48 #4000000000000000
rname 0:4:54 pi pd 0
rint 0:4:59 2 #4000000000000000
rpowk 0:4:54 2
bin 0:4:48 mul
param 0:4:39 d 0 1
rtype 0:4:65 f64 s 0 4
rname 0:5:12 a loc 1
rname 0:5:16 b loc 2
bin 0:5:12 add
rname 0:5:20 c loc 3
bin 0:5:12 add
rname 0:5:24 d loc 4
bin 0:5:12 add
return 0:5:5 1
block 0:4:69 1
rfn 0:4:1 f 2 4 1 2 4 3 3 4 4
rname 0:7:1 printf pd 0
str 0:7:8 %25g%0A
rname 0:7:16 f fn 2
rint 0:7:18 1 #3FF0000000000000
call 0:7:16 1
call 0:7:1 2
cstmt 0:7:1
rname 0:8:1 printf pd 0
str 0:8:8 %25g%0A
rname 0:8:16 f fn 2
rint 0:8:18 1 #3FF0000000000000
float 0:8:24 #3FE0000000000000
narg 0:8:21 d
call 0:8:16 2
call 0:8:1 2
cstmt 0:8:1
prog 4
#end
