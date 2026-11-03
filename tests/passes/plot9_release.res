#sea 1
#target arm64-macos
#file plot9_release.sea
rtst 10 S 1 2
rtfd a 7
rtfd k 3
rtype 0:1:15 Axes s 0 7
field 0:1:12 a
rtype 0:1:24 i64 s 0 3
field 0:1:21 k
rst 0:1:1 S 2 1
rtype 0:2:11 Figure s 0 6
param 0:2:6 fig 0 0
rtype 0:2:22 i64 s 0 3
param 0:2:19 n 0 0
rtype 0:2:30 i64 s 0 3
rpname 0:3:9 ax 3
rname 0:3:14 panel pd 0
rname 0:3:20 fig loc 1
rint 0:3:25 0 #0000000000000000
rname 0:3:28 n loc 2
call 0:3:14 3
let 0:3:5 0
rname 0:4:8 n loc 2
rint 0:4:12 0 #0000000000000000
bin 0:4:8 gt
rname 0:4:23 n loc 2
return 0:4:16 1
block 0:4:14 1
if 0:4:5 0
rpname 0:5:9 c 4
rint 0:5:13 0 #0000000000000000
var 0:5:5 0
rint 0:6:14 0 #0000000000000000
rint 0:6:17 3 #4008000000000000
range 0:6:14 0 0
rpname 0:7:13 F 6
rname 0:7:17 figure pd 0
rint 0:7:24 1 #3FF0000000000000
rint 0:7:27 1 #3FF0000000000000
call 0:7:17 2
let 0:7:9 0
rname 0:8:12 i loc 5
rint 0:8:17 0 #0000000000000000
bin 0:8:12 eq
continue 0:8:21
block 0:8:19 1
if 0:8:9 0
rname 0:9:12 i loc 5
rint 0:9:17 2 #4000000000000000
bin 0:9:12 eq
break 0:9:21
block 0:9:19 1
if 0:9:9 0
rname 0:10:9 c loc 4
rname 0:10:13 c loc 4
rname 0:10:17 i loc 5
bin 0:10:13 add
asg 0:10:9 set
block 0:6:19 4
rfor 0:6:5 i 0:6:9 5
rpname 0:12:9 b 7
rname 0:12:13 ax loc 3
let 0:12:5 0
rpname 0:13:9 s 8
rname 0:13:20 ax loc 3
init 0:13:17 a
rint 0:13:27 1 #3FF0000000000000
init 0:13:24 k
rslit 0:13:13 S 2 1
let 0:13:5 0
rname 0:14:5 title pd 0
rname 0:14:11 b loc 7
str 0:14:14 b
call 0:14:5 2
cstmt 0:14:5
rname 0:15:5 xlabel pd 0
rname 0:15:12 s loc 8
dot 0:15:12 a
str 0:15:17 s
call 0:15:5 2
cstmt 0:15:5
rname 0:16:12 c loc 4
rname 0:16:16 s loc 8
dot 0:16:16 k
bin 0:16:12 add
return 0:16:5 1
block 0:2:34 9
rfn 0:2:1 g 0 2 1 2 3 6 3
rpname 0:18:5 fig 1
rname 0:18:11 figure pd 0
rint 0:18:18 1 #3FF0000000000000
rint 0:18:21 2 #4000000000000000
call 0:18:11 2
let 0:18:1 0
rname 0:19:1 printf pd 0
str 0:19:8 %25d%20%25d%0A
rname 0:19:19 g fn 2
rname 0:19:21 fig loc 1
rint 0:19:26 0 #0000000000000000
call 0:19:19 2
rname 0:19:30 g fn 2
rname 0:19:32 fig loc 1
rint 0:19:37 1 #3FF0000000000000
call 0:19:30 2
call 0:19:1 3
cstmt 0:19:1
prog 4
#end
