#sea 1
#target arm64-macos
#file ew_colrow.sea
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
rpname 0:3:5 b 2
rname 0:3:9 ones pd 0
rint 0:3:14 3 #4008000000000000
call 0:3:9 1
var 0:3:1 0
rname 0:4:1 b loc 2
rint 0:4:3 2 #4000000000000000
index 0:4:1 1
float 0:4:8 #4014000000000000
asg 0:4:1 set
rpname 0:5:5 P 3
rname 0:5:9 a loc 1
dot 0:5:9 col
rname 0:5:17 b loc 2
dot 0:5:17 row
bin 0:5:9 mul
let 0:5:1 0
rname 0:6:1 printf pd 0
str 0:6:8 %25g%20%25g%20%25d%20%25d%0A
rname 0:6:25 P loc 3
rint 0:6:27 1 #3FF0000000000000
rint 0:6:30 0 #0000000000000000
index 0:6:25 2
rname 0:6:34 P loc 3
rint 0:6:36 1 #3FF0000000000000
rint 0:6:39 2 #4000000000000000
index 0:6:34 2
rname 0:6:43 rows pd 0
rname 0:6:48 P loc 3
call 0:6:43 1
rname 0:6:52 cols pd 0
rname 0:6:57 P loc 3
call 0:6:52 1
call 0:6:1 5
cstmt 0:6:1
prog 6
#end
