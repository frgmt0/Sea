#sea 1
#target arm64-macos
#file op_shortcircuit.sea
rtype 0:3:12 i64 s 0 3
param 0:3:9 a 0 0
rtype 0:3:20 i64 s 0 3
param 0:3:17 b 0 0
rtype 0:3:28 i64 s 0 3
rpname 0:4:9 r 3
rint 0:4:13 0 #0000000000000000
var 0:4:5 0
rint 0:5:14 0 #0000000000000000
rname 0:5:17 a loc 1
range 0:5:14 0 0
rname 0:6:12 i loc 4
rint 0:6:16 1 #3FF0000000000000
bin 0:6:12 gt
rname 0:6:21 i loc 4
rname 0:6:25 b loc 2
bin 0:6:21 lt
bin 0:6:12 and
rname 0:7:13 r loc 3
rint 0:7:18 1 #3FF0000000000000
asg 0:7:13 add
block 0:6:27 1
if 0:6:9 0
rname 0:9:12 i loc 4
rint 0:9:17 0 #0000000000000000
bin 0:9:12 eq
rname 0:9:22 r loc 3
rint 0:9:26 3 #4008000000000000
bin 0:9:22 gt
bin 0:9:12 or
rname 0:10:13 r loc 3
rname 0:10:17 r loc 3
rint 0:10:21 2 #4000000000000000
bin 0:10:17 mul
rname 0:10:28 r loc 3
rint 0:10:32 4 #4010000000000000
bin 0:10:28 gt
rint 0:10:36 1 #3FF0000000000000
rint 0:10:47 0 #0000000000000000
ifx 0:10:25
bin 0:10:17 add
asg 0:10:13 set
block 0:9:28 1
if 0:9:9 0
block 0:5:19 2
rfor 0:5:5 i 0:5:9 4
rname 0:13:12 r loc 3
return 0:13:5 1
block 0:3:32 3
rfn 0:3:1 pick 0 2 1 2 3 3 3
rpname 0:15:5 x 1
rname 0:15:9 pick fn 2
rint 0:15:14 5 #4014000000000000
rint 0:15:17 3 #4008000000000000
call 0:15:9 2
let 0:15:1 0
rpname 0:16:5 y 2
rname 0:16:9 pick fn 2
rint 0:16:14 2 #4000000000000000
rint 0:16:17 2 #4000000000000000
call 0:16:9 2
let 0:16:1 0
prog 3
#end
