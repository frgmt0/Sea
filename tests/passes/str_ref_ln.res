#sea 1
#target arm64-macos
#file str_ref_ln.sea
rtvec 10 5
rtype 0:1:13 str v 0 10
param 0:1:6 v 1 0
rtype 0:1:23 i64 s 0 3
param 0:1:20 i 0 0
false 0:1:36
block 0:1:42 0
while 0:1:30
rname 0:2:5 v loc 1
rname 0:2:7 i loc 2
index 0:2:5 1
str 0:2:12 x
asg 0:2:5 set
block 0:1:28 2
rfn 0:1:1 f 0 2 0 2 1 10 3
rpname 0:4:5 names 1
str 0:4:14 a
str 0:4:19 b
row 0:4:14 2
array 0:4:13 1
var 0:4:1 0
rname 0:5:1 f fn 2
rname 0:5:7 names loc 1
ref 0:5:3
rint 0:5:14 0 #0000000000000000
call 0:5:1 2
cstmt 0:5:1
rname 0:6:1 f fn 2
rname 0:6:7 names loc 1
ref 0:6:3
rint 0:6:14 1 #3FF0000000000000
call 0:6:1 2
cstmt 0:6:1
rname 0:7:1 printf pd 0
str 0:7:8 %25s%20%25s%0A
rname 0:7:19 names loc 1
rint 0:7:25 0 #0000000000000000
index 0:7:19 1
rname 0:7:29 names loc 1
rint 0:7:35 1 #3FF0000000000000
index 0:7:29 1
call 0:7:1 3
cstmt 0:7:1
prog 5
#end
