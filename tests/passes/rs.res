#sea 1
#target arm64-macos
#file rs.sea
rtup 10 2 4 3
rint 0:1:11 2 #4000000000000000
rint 0:1:15 3 #4008000000000000
bin 0:1:11 mul
rcni 0:1:1 N 0 1 6
type 0:2:13 f64 s 0
param 0:2:10 x 0 0
type 0:2:22 f64 s 0
type 0:2:27 i64 s 0
rpname 0:3:9 k 2
rname 0:3:17 x loc 1
conv 0:3:13 i64
let 0:3:5 0
rname 0:4:13 x loc 1
rint 0:4:17 2 #4000000000000000
rpowk 0:4:13 2
rname 0:4:20 k loc 2
rname 0:4:24 N cst 1
bin 0:4:20 add
return 0:4:5 2
block 0:2:32 2
rfn 0:2:1 split 0 1 2 2 10 4
rpname 0:6:6 a 1
rpname 0:6:9 b 2
ptuple 0:6:5 2
rname 0:6:14 split fn 2
rname 0:6:20 pi pd 0
call 0:6:14 1
let 0:6:1 0
rint 0:7:10 0 #0000000000000000
rname 0:7:13 b loc 2
range 0:7:10 0 0
rname 0:8:5 printf pd 0
str 0:8:12 %25g%0A
rname 0:8:20 a loc 1
call 0:8:5 2
cstmt 0:8:5
block 0:7:15 1
rfor 0:7:1 i 0:7:5 3
prog 4
#end
