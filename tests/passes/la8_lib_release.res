#sea 1
#target arm64-macos
#file la8_lib_release.sea
rtst 10 S 1 2
rtfd f 8
rtfd k 3
rtmat 11 4
rtype 0:1:15 Lu s 0 8
field 0:1:12 f
rtype 0:1:22 i64 s 0 3
field 0:1:19 k
rst 0:1:1 S 2 1
rtype 0:2:9 f64 m 0 11
param 0:2:6 A 0 0
rtype 0:2:20 i64 s 0 3
param 0:2:17 n 0 0
rtype 0:2:28 f64 s 0 4
rpname 0:3:9 F 3
rname 0:3:13 lu pd 0
rname 0:3:16 A loc 1
call 0:3:13 1
let 0:3:5 0
rname 0:4:8 n loc 2
rint 0:4:12 9 #4022000000000000
bin 0:4:8 gt
rname 0:4:23 rcond pd 0
rname 0:4:29 F loc 3
call 0:4:23 1
return 0:4:16 1
block 0:4:14 1
if 0:4:5 0
rpname 0:5:9 t 4
float 0:5:13 #0000000000000000
var 0:5:5 0
rint 0:6:14 0 #0000000000000000
rname 0:6:17 n loc 2
range 0:6:14 0 0
rpname 0:7:13 G 6
rname 0:7:17 lu pd 0
rname 0:7:20 A loc 1
call 0:7:17 1
let 0:7:9 0
rname 0:8:12 i loc 5
rint 0:8:17 0 #0000000000000000
bin 0:8:12 eq
continue 0:8:21
block 0:8:19 1
if 0:8:9 0
rname 0:9:12 i loc 5
rint 0:9:17 3 #4008000000000000
bin 0:9:12 eq
break 0:9:21
block 0:9:19 1
if 0:9:9 0
rname 0:10:9 t loc 4
rname 0:10:13 t loc 4
rname 0:10:17 rcond pd 0
rname 0:10:23 G loc 6
call 0:10:17 1
bin 0:10:13 add
asg 0:10:9 set
block 0:6:19 4
rfor 0:6:5 i 0:6:9 5
rpname 0:12:9 H 7
rname 0:12:13 F loc 3
let 0:12:5 0
rpname 0:13:9 s 8
rname 0:13:20 F loc 3
init 0:13:17 f
rint 0:13:26 1 #3FF0000000000000
init 0:13:23 k
rslit 0:13:13 S 2 1
let 0:13:5 0
rname 0:14:12 t loc 4
rname 0:14:16 rcond pd 0
rname 0:14:22 H loc 7
call 0:14:16 1
bin 0:14:12 add
rname 0:14:27 rcond pd 0
rname 0:14:33 s loc 8
dot 0:14:33 f
call 0:14:27 1
bin 0:14:12 add
return 0:14:5 1
block 0:2:32 7
rfn 0:2:1 g 0 2 1 2 4 11 3
rpname 0:16:5 A 1
rtype 0:16:8 f64 m 0 11
float 0:16:18 #4000000000000000
float 0:16:23 #0000000000000000
row 0:16:18 2
float 0:16:28 #0000000000000000
float 0:16:33 #4010000000000000
row 0:16:28 2
array 0:16:17 2
let 0:16:1 1
rname 0:17:1 printf pd 0
str 0:17:8 %25g%20%25g%0A
rname 0:17:19 g fn 2
rname 0:17:21 A loc 1
rint 0:17:24 5 #4014000000000000
call 0:17:19 2
rname 0:17:28 g fn 2
rname 0:17:30 A loc 1
rint 0:17:33 10 #4024000000000000
call 0:17:28 2
call 0:17:1 3
cstmt 0:17:1
prog 4
#end
