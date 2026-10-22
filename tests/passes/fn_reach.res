#sea 1
#target arm64-macos
#file fn_reach.sea
rtup 10 2 3 3
rtype 0:4:14 i64 s 0 3
param 0:4:11 n 0 0
rtype 0:4:23 i64 s 0 3
rtype 0:4:28 i64 s 0 3
rname 0:5:13 n loc 1
rname 0:5:16 n loc 1
return 0:5:5 2
block 0:4:33 1
rfn 0:4:1 unused 0 1 2 2 10 3
rtype 0:7:14 i64 s 0 3
rint 0:8:12 7 #401C000000000000
return 0:8:5 1
block 0:7:18 1
rfn 0:7:1 leaf 0 0 1 3 3
rtype 0:10:13 i64 s 0 3
rname 0:11:12 leaf fn 3
call 0:11:12 0
rint 0:11:21 1 #3FF0000000000000
bin 0:11:12 add
return 0:11:5 1
block 0:10:17 1
rfn 0:10:1 mid 0 0 1 4 3
rtype 0:13:14 i64 s 0 3
rname 0:14:12 mid fn 4
call 0:14:12 0
return 0:14:5 1
block 0:13:18 1
rfn 0:13:1 dead 0 0 1 5 3
rpname 0:16:5 v 1
rname 0:16:9 mid fn 4
call 0:16:9 0
let 0:16:1 0
prog 5
#end
