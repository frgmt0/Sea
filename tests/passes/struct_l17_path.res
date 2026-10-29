#sea 1
#target arm64-macos
#file struct_l17_path.sea
rtst 10 T 1 2
rtfd lo 4
rtfd hi 4
rtst 11 D 2 3
rtfd name 5
rtfd w 12
rtfd lim 10
rtvec 12 4
rtvec 13 11
rtype 0:1:16 D v 0 13
param 0:1:8 ds 1 0
rtype 0:1:24 i64 s 0 3
param 0:1:21 i 0 0
rtype 0:1:32 f64 s 0 4
param 0:1:29 x 0 0
false 0:1:45
block 0:1:51 0
while 0:1:39
rname 0:2:5 ds loc 1
rname 0:2:8 i loc 2
index 0:2:5 1
dot 0:2:5 w
rint 0:2:13 0 #0000000000000000
index 0:2:5 1
rname 0:2:18 x loc 3
asg 0:2:5 set
rname 0:3:5 ds loc 1
rname 0:3:8 i loc 2
index 0:3:5 1
dot 0:3:5 lim
rname 0:3:25 x loc 3
init 0:3:21 lo
float 0:3:32 #4000000000000000
init 0:3:28 hi
rslit 0:3:17 T 2 1
asg 0:3:5 set
rname 0:4:5 ds loc 1
rname 0:4:8 i loc 2
index 0:4:5 1
dot 0:4:5 lim
dot 0:4:5 hi
rname 0:4:20 x loc 3
float 0:4:24 #3FF0000000000000
bin 0:4:20 add
asg 0:4:5 set
rname 0:5:5 ds loc 1
rname 0:5:8 i loc 2
index 0:5:5 1
dot 0:5:5 name
str 0:5:18 z
asg 0:5:5 set
block 0:1:37 5
rfn 0:1:1 upd 0 3 0 2 1 13 3 4
rpname 0:7:5 t0 1
float 0:7:18 #0000000000000000
init 0:7:14 lo
float 0:7:27 #3FF0000000000000
init 0:7:23 hi
rslit 0:7:10 T 2 1
let 0:7:1 0
rpname 0:8:5 ds 2
str 0:8:21 a
init 0:8:15 name
rname 0:8:29 zeros pd 0
rint 0:8:35 1 #3FF0000000000000
call 0:8:29 1
init 0:8:26 w
rname 0:8:44 t0 loc 1
init 0:8:39 lim
rslit 0:8:11 D 3 2
str 0:8:60 b
init 0:8:54 name
rname 0:8:68 zeros pd 0
rint 0:8:74 1 #3FF0000000000000
call 0:8:68 1
init 0:8:65 w
rname 0:8:83 t0 loc 1
init 0:8:78 lim
rslit 0:8:50 D 3 2
row 0:8:11 2
array 0:8:10 1
var 0:8:1 0
rpname 0:9:5 keep 3
rname 0:9:12 ds loc 2
let 0:9:1 0
rname 0:10:1 upd fn 2
rname 0:10:9 ds loc 2
ref 0:10:5
rint 0:10:13 1 #3FF0000000000000
float 0:10:16 #401C000000000000
call 0:10:1 3
cstmt 0:10:1
rname 0:11:1 upd fn 2
rname 0:11:9 ds loc 2
ref 0:11:5
rint 0:11:13 0 #0000000000000000
float 0:11:16 #4020000000000000
call 0:11:1 3
cstmt 0:11:1
rname 0:12:1 printf pd 0
str 0:12:8 %25s%20%25g%20%25g%20%25g%0A
rname 0:12:25 ds loc 2
rint 0:12:28 1 #3FF0000000000000
index 0:12:25 1
dot 0:12:25 name
rname 0:12:37 ds loc 2
rint 0:12:40 1 #3FF0000000000000
index 0:12:37 1
dot 0:12:37 w
rint 0:12:45 0 #0000000000000000
index 0:12:37 1
rname 0:12:49 ds loc 2
rint 0:12:52 1 #3FF0000000000000
index 0:12:49 1
dot 0:12:49 lim
dot 0:12:49 lo
rname 0:12:63 ds loc 2
rint 0:12:66 1 #3FF0000000000000
index 0:12:63 1
dot 0:12:63 lim
dot 0:12:63 hi
call 0:12:1 5
cstmt 0:12:1
rname 0:13:1 printf pd 0
str 0:13:8 %25s%20%25g%20%25s%0A
rname 0:13:22 keep loc 3
rint 0:13:27 1 #3FF0000000000000
index 0:13:22 1
dot 0:13:22 name
rname 0:13:36 keep loc 3
rint 0:13:41 1 #3FF0000000000000
index 0:13:36 1
dot 0:13:36 w
rint 0:13:46 0 #0000000000000000
index 0:13:36 1
rname 0:13:50 ds loc 2
rint 0:13:53 0 #0000000000000000
index 0:13:50 1
dot 0:13:50 name
call 0:13:1 4
cstmt 0:13:1
rtype 0:15:9 f64 s 0 4
field 0:15:5 lo
rtype 0:16:9 f64 s 0 4
field 0:16:5 hi
rst 0:14:1 T 2 1
rtype 0:19:11 str s 0 5
field 0:19:5 name
rtype 0:20:8 f64 v 0 12
field 0:20:5 w
rtype 0:21:10 T s 0 10
field 0:21:5 lim
rst 0:18:1 D 3 2
prog 10
#end
