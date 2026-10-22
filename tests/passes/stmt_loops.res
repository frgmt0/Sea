#sea 1
#target arm64-macos
#file stmt_loops.sea
rtype 0:4:12 i64 s 0 3
param 0:4:9 n 0 0
rtype 0:4:20 i64 s 0 3
rpname 0:5:9 k 2
rint 0:5:13 0 #0000000000000000
var 0:5:5 0
rname 0:6:11 k loc 2
rname 0:6:15 n loc 1
bin 0:6:11 lt
rname 0:7:9 k loc 2
rint 0:7:14 3 #4008000000000000
asg 0:7:9 add
block 0:6:17 1
while 0:6:5
rname 0:9:14 n loc 1
rint 0:9:18 0 #0000000000000000
rint 0:9:26 2 #4000000000000000
neg 0:9:25
range 0:9:14 1 1
rname 0:10:12 i loc 3
rint 0:10:17 4 #4010000000000000
bin 0:10:12 eq
continue 0:11:13
block 0:10:19 1
if 0:10:9 0
rname 0:13:12 i loc 3
rint 0:13:16 2 #4000000000000000
bin 0:13:12 lt
break 0:14:13
block 0:13:18 1
if 0:13:9 0
rname 0:16:9 k loc 2
rname 0:16:14 i loc 3
asg 0:16:9 sub
block 0:9:28 3
rfor 0:9:5 i 0:9:9 3
rname 0:18:12 k loc 2
return 0:18:5 1
block 0:4:24 4
rfn 0:4:1 walk 0 1 1 2 3 3
rpname 0:20:5 a 1
rname 0:20:9 walk fn 2
rint 0:20:14 10 #4024000000000000
call 0:20:9 1
let 0:20:1 0
rpname 0:21:5 b 2
rname 0:21:9 walk fn 2
rint 0:21:14 7 #401C000000000000
call 0:21:9 1
let 0:21:1 0
prog 3
#end
