#sea 1
#target arm64-macos
#file str_l12.sea
rtup 10 2 5 3
rtype 0:1:11 i64 s 0 3
param 0:1:8 n 0 0
rtype 0:1:20 str s 0 5
rtype 0:1:25 i64 s 0 3
false 0:1:38
block 0:1:44 0
while 0:1:32
rname 0:2:17 n loc 1
conv 0:2:13 str
rname 0:2:21 n loc 1
rint 0:2:25 1 #3FF0000000000000
bin 0:2:21 add
return 0:2:5 2
block 0:1:30 2
rfn 0:1:1 two 0 1 2 2 10 3
rtype 0:4:11 i64 s 0 3
param 0:4:8 i 0 0
false 0:4:24
block 0:4:30 0
while 0:4:18
rpname 0:5:9 names 2
str 0:5:18 x
str 0:5:23 y
row 0:5:18 2
array 0:5:17 1
var 0:5:5 0
rpname 0:6:9 k 3
rint 0:6:13 0 #0000000000000000
var 0:6:5 0
rname 0:7:6 names loc 2
rname 0:7:12 i loc 1
index 0:7:6 1
rname 0:7:16 k loc 3
rname 0:7:21 two fn 2
rname 0:7:25 i loc 1
rint 0:7:29 5 #4014000000000000
bin 0:7:25 add
call 0:7:21 1
tasg 0:7:5 2
rname 0:8:5 printf pd 0
str 0:8:12 %25s%20%25s%20%25d%0A
rname 0:8:26 names loc 2
rint 0:8:32 0 #0000000000000000
index 0:8:26 1
rname 0:8:36 names loc 2
rint 0:8:42 1 #3FF0000000000000
index 0:8:36 1
rname 0:8:46 k loc 3
call 0:8:5 4
cstmt 0:8:5
block 0:4:16 5
rfn 0:4:1 upd 0 1 0 3 1 3
rpname 0:10:6 a 1
rpname 0:10:9 b 2
ptuple 0:10:5 2
rname 0:10:14 two fn 2
rint 0:10:18 1 #3FF0000000000000
call 0:10:14 1
let 0:10:1 0
rname 0:11:1 printf pd 0
str 0:11:8 %25s%20%25d%0A
rname 0:11:19 a loc 1
rname 0:11:22 b loc 2
call 0:11:1 3
cstmt 0:11:1
rname 0:12:1 upd fn 3
rint 0:12:5 0 #0000000000000000
call 0:12:1 1
cstmt 0:12:1
rname 0:13:1 upd fn 3
rint 0:13:5 1 #3FF0000000000000
call 0:13:1 1
cstmt 0:13:1
prog 6
#end
