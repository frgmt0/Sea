#sea 1
#target arm64-macos
#file struct_l17.sea
rtst 10 Lim 1 2
rtfd lo 4
rtfd hi 4
rtst 11 S 2 4
rtfd n 3
rtfd name 5
rtfd v 12
rtfd lim 10
rtvec 12 4
rtype 0:1:12 i64 s 0 3
param 0:1:9 k 0 0
rtype 0:1:20 i64 s 0 3
rpname 0:2:9 l0 2
float 0:2:24 #0000000000000000
init 0:2:20 lo
float 0:2:33 #3FF0000000000000
init 0:2:29 hi
rslit 0:2:14 Lim 2 1
let 0:2:5 0
rpname 0:3:9 s 3
rname 0:3:20 k loc 1
init 0:3:17 n
str 0:3:29 a
init 0:3:23 name
rname 0:3:37 zeros pd 0
rint 0:3:43 2 #4000000000000000
call 0:3:37 1
init 0:3:34 v
rname 0:3:52 l0 loc 2
init 0:3:47 lim
rslit 0:3:13 S 4 2
var 0:3:5 0
rname 0:4:5 s loc 3
dot 0:4:5 n
rname 0:4:11 s loc 3
dot 0:4:11 n
rint 0:4:17 1 #3FF0000000000000
bin 0:4:11 add
asg 0:4:5 set
rname 0:5:5 s loc 3
dot 0:5:5 n
rint 0:5:12 2 #4000000000000000
asg 0:5:5 add
rname 0:6:5 s loc 3
dot 0:6:5 name
str 0:6:14 b
asg 0:6:5 set
rname 0:7:5 s loc 3
dot 0:7:5 lim
dot 0:7:5 hi
float 0:7:16 #4008000000000000
asg 0:7:5 set
rname 0:8:5 s loc 3
dot 0:8:5 v
rname 0:8:9 k loc 1
index 0:8:5 1
float 0:8:14 #4022000000000000
asg 0:8:5 set
rpname 0:9:9 l1 4
rname 0:9:14 s loc 3
dot 0:9:14 lim
let 0:9:5 0
rname 0:10:5 s loc 3
dot 0:10:5 lim
float 0:10:23 #3FE0000000000000
init 0:10:19 lo
float 0:10:32 #3FE8000000000000
init 0:10:28 hi
rslit 0:10:13 Lim 2 1
asg 0:10:5 set
rpname 0:11:9 l2 5
rname 0:11:14 s loc 3
dot 0:11:14 lim
let 0:11:5 0
rname 0:12:5 printf pd 0
str 0:12:12 %25d%20%25s%20%25g%20%25g%20%25g%20%25g%0A
rname 0:12:35 s loc 3
dot 0:12:35 n
rname 0:12:40 s loc 3
dot 0:12:40 name
rname 0:12:48 s loc 3
dot 0:12:48 v
rint 0:12:52 0 #0000000000000000
index 0:12:48 1
rname 0:12:56 s loc 3
dot 0:12:56 v
rint 0:12:60 1 #3FF0000000000000
index 0:12:56 1
rname 0:12:64 l1 loc 4
dot 0:12:64 hi
rname 0:12:71 l2 loc 5
dot 0:12:71 lo
call 0:12:5 7
cstmt 0:12:5
rname 0:13:12 s loc 3
dot 0:13:12 n
return 0:13:5 1
block 0:1:24 12
rfn 0:1:1 edit 0 1 1 2 3 3
rname 0:15:1 printf pd 0
str 0:15:8 %25d%0A
rname 0:15:16 edit fn 2
rint 0:15:21 0 #0000000000000000
call 0:15:16 1
call 0:15:1 2
cstmt 0:15:1
rname 0:16:1 printf pd 0
str 0:16:8 %25d%0A
rname 0:16:16 edit fn 2
rint 0:16:21 1 #3FF0000000000000
call 0:16:16 1
call 0:16:1 2
cstmt 0:16:1
rtype 0:18:9 f64 s 0 4
field 0:18:5 lo
rtype 0:19:9 f64 s 0 4
field 0:19:5 hi
rst 0:17:1 Lim 2 1
rtype 0:22:8 i64 s 0 3
field 0:22:5 n
rtype 0:23:11 str s 0 5
field 0:23:5 name
rtype 0:24:8 f64 v 0 12
field 0:24:5 v
rtype 0:25:10 Lim s 0 10
field 0:25:5 lim
rst 0:21:1 S 4 2
prog 5
#end
