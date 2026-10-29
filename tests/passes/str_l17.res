#sea 1
#target arm64-macos
#file str_l17.sea
rtype 0:1:11 i64 s 0 3
param 0:1:8 i 0 0
rtype 0:1:19 str s 0 5
param 0:1:16 s 0 0
rpname 0:2:9 names 3
str 0:2:18 p
str 0:2:23 q
str 0:2:28 r
row 0:2:18 3
array 0:2:17 1
var 0:2:5 0
rname 0:3:5 names loc 3
rname 0:3:11 i loc 1
index 0:3:5 1
rname 0:3:16 s loc 2
asg 0:3:5 set
rname 0:4:5 names loc 3
rname 0:4:11 i loc 1
index 0:4:5 1
str 0:4:17 !
asg 0:4:5 add
rname 0:5:5 printf pd 0
str 0:5:12 %25s%20%25s%20%25s%0A
rname 0:5:26 names loc 3
rint 0:5:32 0 #0000000000000000
index 0:5:26 1
rname 0:5:36 names loc 3
rint 0:5:42 1 #3FF0000000000000
index 0:5:36 1
rname 0:5:46 names loc 3
rint 0:5:52 2 #4000000000000000
index 0:5:46 1
call 0:5:5 4
cstmt 0:5:5
block 0:1:24 4
rfn 0:1:1 put 2 2 0 2 1 3 5
rname 0:7:1 put fn 2
rint 0:7:5 0 #0000000000000000
str 0:7:8 a
call 0:7:1 2
cstmt 0:7:1
rname 0:8:1 put fn 2
rint 0:8:5 2 #4000000000000000
str 0:8:8 b
call 0:8:1 2
cstmt 0:8:1
prog 3
#end
