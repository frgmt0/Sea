#sea 1
#target arm64-macos
#file fn_multi.sea
rtup 10 2 3 4
type 0:4:12 i64 s 0
param 0:4:9 n 0 0
type 0:4:21 i64 s 0
type 0:4:26 f64 s 0
rpname 0:5:9 a 2
rint 0:5:13 0 #0000000000000000
var 0:5:5 0
rpname 0:6:9 b 3
float 0:6:13 #0000000000000000
var 0:6:5 0
rint 0:7:14 0 #0000000000000000
rname 0:7:17 n loc 1
range 0:7:14 0 0
rname 0:8:9 a loc 2
rname 0:8:14 i loc 4
asg 0:8:9 add
rname 0:9:9 b loc 3
float 0:9:14 #3FE0000000000000
asg 0:9:9 add
block 0:7:19 2
rfor 0:7:5 i 0:7:9 4
rname 0:11:13 a loc 2
rname 0:11:16 b loc 3
return 0:11:5 2
block 0:4:31 4
rfn 0:4:1 sums 0 1 2 2 10 3
type 0:13:13 i64 s 0
param 0:13:10 n 0 0
type 0:13:22 i64 s 0
type 0:13:27 f64 s 0
rname 0:14:8 n loc 1
rint 0:14:12 0 #0000000000000000
bin 0:14:8 gt
rname 0:15:16 again fn 3
rname 0:15:22 n loc 1
rint 0:15:26 1 #3FF0000000000000
bin 0:15:22 sub
call 0:15:16 1
return 0:15:9 1
block 0:14:14 1
if 0:14:5 0
rname 0:17:12 sums fn 2
rint 0:17:17 4 #4010000000000000
call 0:17:12 1
return 0:17:5 1
block 0:13:32 2
rfn 0:13:1 again 0 1 2 3 10 3
rpname 0:19:6 p 1
rpname 0:19:9 q 2
ptuple 0:19:5 2
rname 0:19:14 sums fn 2
rint 0:19:19 3 #4008000000000000
call 0:19:14 1
let 0:19:1 0
rpname 0:20:6 r 3
pskip 0:20:9
ptuple 0:20:5 2
rname 0:20:14 again fn 3
rint 0:20:20 2 #4000000000000000
call 0:20:14 1
let 0:20:1 0
pskip 0:21:6
rpname 0:21:9 w 4
ptuple 0:21:5 2
rname 0:21:14 sums fn 2
rint 0:21:19 2 #4000000000000000
call 0:21:14 1
let 0:21:1 0
prog 5
#end
