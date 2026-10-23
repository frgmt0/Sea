#sea 1
#target arm64-macos
#file arr_lit_cat.sea
rpname 0:1:5 a 1
rname 0:1:9 ones pd 0
rint 0:1:14 2 #4000000000000000
call 0:1:9 1
var 0:1:1 0
rname 0:2:1 a loc 1
rint 0:2:3 1 #3FF0000000000000
index 0:2:1 1
float 0:2:8 #4008000000000000
asg 0:2:1 set
rpname 0:3:5 v 2
rname 0:3:10 a loc 1
float 0:3:13 #4014000000000000
rname 0:3:18 a loc 1
row 0:3:10 3
array 0:3:9 1
let 0:3:1 0
rpname 0:4:5 M 3
rname 0:4:9 ones pd 0
rint 0:4:14 2 #4000000000000000
rint 0:4:17 1 #3FF0000000000000
call 0:4:9 2
var 0:4:1 0
rname 0:5:1 M loc 3
rint 0:5:3 1 #3FF0000000000000
rint 0:5:6 0 #0000000000000000
index 0:5:1 2
float 0:5:11 #4000000000000000
asg 0:5:1 set
rpname 0:6:5 W 4
rname 0:6:10 M loc 3
rname 0:6:13 M loc 3
row 0:6:10 2
array 0:6:9 1
let 0:6:1 0
rname 0:7:1 printf pd 0
str 0:7:8 %25g%20%25g%20%25d%20%25g%20%25d%0A
rname 0:7:28 v loc 2
rint 0:7:30 2 #4000000000000000
index 0:7:28 1
rname 0:7:34 v loc 2
rint 0:7:36 4 #4010000000000000
index 0:7:34 1
rname 0:7:40 len pd 0
rname 0:7:44 v loc 2
call 0:7:40 1
rname 0:7:48 W loc 4
rint 0:7:50 1 #3FF0000000000000
rint 0:7:53 1 #3FF0000000000000
index 0:7:48 2
rname 0:7:57 cols pd 0
rname 0:7:62 W loc 4
call 0:7:57 1
call 0:7:1 6
cstmt 0:7:1
prog 7
#end
