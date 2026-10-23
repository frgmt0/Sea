#sea 1
#target arm64-macos
#file res_rtst.sea
rtst 10 B 1 3
rtfd a 11
rtfd w 12
rtfd t 13
rtst 11 A 2 2
rtfd x 3
rtfd s 5
rtvec 12 4
rtfvec 13 11 2
rtmat 14 3
rtvec 15 11
rtvec 16 10
rtype 0:4:8 A s 0 11
field 0:4:5 a
rtype 0:5:8 f64 v 0 12
field 0:5:5 w
rint 0:6:10 2 #4000000000000000
rtype 0:6:8 A fv 1 13
field 0:6:5 t
rst 0:3:1 B 3 1
rtype 0:9:8 i64 s 0 3
field 0:9:5 x
rtype 0:10:8 str s 0 5
field 0:10:5 s
rst 0:8:1 A 2 2
rtype 0:12:10 B s 0 10
param 0:12:7 b 0 0
rtype 0:12:16 i64 m 0 14
param 0:12:13 k 0 0
rtype 0:12:27 A v 0 15
rname 0:13:13 b loc 1
dot 0:13:13 a
row 0:13:13 1
array 0:13:12 1
return 0:13:5 1
block 0:12:31 1
rfn 0:12:1 mk 0 2 1 2 15 10 14
rpname 0:15:5 v 1
rtype 0:15:8 B v 0 16
array 0:15:14 0
let 0:15:1 1
rpname 0:16:5 A 2
rint 0:16:9 2 #4000000000000000
let 0:16:1 0
rpname 0:17:5 q 3
rint 0:17:16 1 #3FF0000000000000
init 0:17:13 x
str 0:17:22 %
init 0:17:19 s
rslit 0:17:9 A 2 0
let 0:17:1 0
rpname 0:18:5 r 4
rint 0:18:16 1 #3FF0000000000000
init 0:18:13 x
rslit 0:18:9 Q 1 0
let 0:18:1 0
prog 7
#end
