#sea 1
#target arm64-macos
#file str_fixed_self.sea
rtfvec 10 5 3
rint 0:1:16 3 #4008000000000000
rtype 0:1:12 str fv 1 10
param 0:1:9 a 0 0
rname 0:2:5 printf pd 0
str 0:2:12 %25s%20%25s%20%25s%0A
rname 0:2:26 a loc 1
rint 0:2:28 0 #0000000000000000
index 0:2:26 1
rname 0:2:32 a loc 1
rint 0:2:34 1 #3FF0000000000000
index 0:2:32 1
rname 0:2:38 a loc 1
rint 0:2:40 2 #4000000000000000
index 0:2:38 1
call 0:2:5 4
cstmt 0:2:5
block 0:1:20 1
rfn 0:1:1 show 0 1 0 2 1 10
rpname 0:4:5 a 1
rint 0:4:12 3 #4008000000000000
rtype 0:4:8 str fv 1 10
str 0:4:18 x
str 0:4:23 y
str 0:4:28 z
row 0:4:18 3
array 0:4:17 1
var 0:4:1 1
rname 0:5:1 a loc 1
all 0:5:3
index 0:5:1 1
rname 0:5:8 a loc 1
asg 0:5:1 set
rname 0:6:1 show fn 2
rname 0:6:6 a loc 1
call 0:6:1 1
cstmt 0:6:1
rname 0:7:1 a loc 1
rint 0:7:3 0 #0000000000000000
index 0:7:1 1
str 0:7:8 w
asg 0:7:1 set
rname 0:8:1 show fn 2
rname 0:8:6 a loc 1
call 0:8:1 1
cstmt 0:8:1
prog 6
#end
