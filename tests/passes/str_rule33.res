#sea 1
#target arm64-macos
#file str_rule33.sea
rtype 0:1:12 str s 0 5
param 0:1:9 a 0 0
rpname 0:2:9 n 2
rint 0:2:13 0 #0000000000000000
var 0:2:5 0
rname 0:3:11 a loc 1
str 0:4:9 x
str 0:4:15 y
rname 0:4:24 n loc 2
rint 0:4:28 1 #3FF0000000000000
asg 0:4:24 set
block 0:4:22 1
arm 0:4:9 2
rname 0:5:16 n loc 2
rint 0:5:20 2 #4000000000000000
asg 0:5:16 set
block 0:5:14 1
arm 0:5:9 0
match 0:3:5 2
rname 0:7:5 printf pd 0
str 0:7:12 %25d%0A
rname 0:7:20 n loc 2
call 0:7:5 2
cstmt 0:7:5
block 0:1:17 3
rfn 0:1:1 pick 0 1 0 2 1 5
rname 0:10:5 pick fn 2
str 0:10:10 x
call 0:10:5 1
cstmt 0:10:5
rname 0:11:5 pick fn 2
str 0:11:10 y
call 0:11:5 1
cstmt 0:11:5
rname 0:12:5 pick fn 2
str 0:12:10 z
call 0:12:5 1
cstmt 0:12:5
block 0:9:12 3
rfn 0:9:1 drive 0 0 0 3 1
rname 0:14:1 drive fn 3
call 0:14:1 0
cstmt 0:14:1
rname 0:15:1 drive fn 3
call 0:15:1 0
cstmt 0:15:1
prog 4
#end
