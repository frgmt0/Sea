#sea 1
#target arm64-macos
#file struct_l12.sea
rtst 10 P 1 2
rtfd name 5
rtfd x 4
rtup 11 2 5 3
rtup 12 2 10 3
rtype 0:1:11 i64 s 0 3
param 0:1:8 k 0 0
rtype 0:1:20 str s 0 5
rtype 0:1:25 i64 s 0 3
rname 0:2:17 k loc 1
conv 0:2:13 str
rname 0:2:21 k loc 1
rint 0:2:25 1 #3FF0000000000000
bin 0:2:21 add
return 0:2:5 2
block 0:1:30 1
rfn 0:1:1 two 0 1 2 2 11 3
rtype 0:4:10 i64 s 0 3
param 0:4:7 k 0 0
rtype 0:4:19 P s 0 10
rtype 0:4:22 i64 s 0 3
rname 0:5:27 k loc 1
conv 0:5:23 str
init 0:5:17 name
float 0:5:34 #3FF8000000000000
init 0:5:31 x
rslit 0:5:13 P 2 1
rname 0:5:41 k loc 1
return 0:5:5 2
block 0:4:27 1
rfn 0:4:1 mk 0 1 2 3 12 3
rpname 0:7:5 s 1
str 0:7:19 a
init 0:7:13 name
float 0:7:27 #3FE0000000000000
init 0:7:24 x
rslit 0:7:9 P 2 1
var 0:7:1 0
rpname 0:8:5 ps 2
str 0:8:21 b
init 0:8:15 name
float 0:8:29 #4004000000000000
init 0:8:26 x
rslit 0:8:11 P 2 1
row 0:8:11 1
array 0:8:10 1
var 0:8:1 0
rpname 0:9:5 k 3
rint 0:9:9 0 #0000000000000000
var 0:9:1 0
rname 0:10:2 s loc 1
dot 0:10:2 name
rname 0:10:10 k loc 3
rname 0:10:15 two fn 2
rint 0:10:19 7 #401C000000000000
call 0:10:15 1
tasg 0:10:1 2
rname 0:11:2 ps loc 2
rint 0:11:5 0 #0000000000000000
index 0:11:2 1
rname 0:11:9 k loc 3
rname 0:11:14 mk fn 3
rname 0:11:17 k loc 3
call 0:11:14 1
tasg 0:11:1 2
rname 0:12:1 printf pd 0
str 0:12:8 %25s%20%25d%20%25s%20%25g%0A
rname 0:12:25 s loc 1
dot 0:12:25 name
rname 0:12:33 k loc 3
rname 0:12:36 ps loc 2
rint 0:12:39 0 #0000000000000000
index 0:12:36 1
dot 0:12:36 name
rname 0:12:48 ps loc 2
rint 0:12:51 0 #0000000000000000
index 0:12:48 1
dot 0:12:48 x
call 0:12:1 5
cstmt 0:12:1
rname 0:13:1 ps loc 2
rint 0:13:4 0 #0000000000000000
index 0:13:1 1
str 0:13:19 c
init 0:13:13 name
float 0:13:27 #400C000000000000
init 0:13:24 x
rslit 0:13:9 P 2 1
asg 0:13:1 set
rpname 0:14:6 t 4
rpname 0:14:9 j 5
ptuple 0:14:5 2
rname 0:14:14 two fn 2
rint 0:14:18 3 #4008000000000000
call 0:14:14 1
let 0:14:1 0
rpname 0:15:6 q 6
rpname 0:15:9 m 7
ptuple 0:15:5 2
rname 0:15:14 mk fn 3
rint 0:15:17 4 #4010000000000000
call 0:15:14 1
let 0:15:1 0
rname 0:16:1 printf pd 0
str 0:16:8 %25s%20%25d%20%25s%20%25d%20%25s%0A
rname 0:16:28 t loc 4
rname 0:16:31 j loc 5
rname 0:16:34 q loc 6
dot 0:16:34 name
rname 0:16:42 m loc 7
rname 0:16:45 ps loc 2
rint 0:16:48 0 #0000000000000000
index 0:16:45 1
dot 0:16:45 name
call 0:16:1 6
cstmt 0:16:1
rtype 0:18:11 str s 0 5
field 0:18:5 name
rtype 0:19:8 f64 s 0 4
field 0:19:5 x
rst 0:17:1 P 2 1
prog 13
#end
