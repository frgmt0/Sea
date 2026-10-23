#sea 1
#target arm64-macos
#file sel_compound.sea
rpname 0:1:5 v 1
rname 0:1:9 ones pd 0
rint 0:1:14 4 #4010000000000000
call 0:1:9 1
var 0:1:1 0
rname 0:2:1 v loc 1
rint 0:2:3 1 #3FF0000000000000
rint 0:2:6 3 #4008000000000000
range 0:2:3 0 0
index 0:2:1 1
float 0:2:12 #4000000000000000
asg 0:2:1 add
rname 0:3:1 printf pd 0
str 0:3:8 %25g%20%25g%20%25g%20%25g%0A
rname 0:3:25 v loc 1
rint 0:3:27 0 #0000000000000000
index 0:3:25 1
rname 0:3:31 v loc 1
rint 0:3:33 1 #3FF0000000000000
index 0:3:31 1
rname 0:3:37 v loc 1
rint 0:3:39 2 #4000000000000000
index 0:3:37 1
rname 0:3:43 v loc 1
rint 0:3:45 3 #4008000000000000
index 0:3:43 1
call 0:3:1 5
cstmt 0:3:1
prog 3
#end
