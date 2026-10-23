#sea 1
#target arm64-macos
#file arr_views.sea
rpname 0:1:5 A 1
rname 0:1:9 zeros pd 0
rint 0:1:15 2 #4000000000000000
rint 0:1:18 3 #4008000000000000
call 0:1:9 2
var 0:1:1 0
rname 0:2:1 A loc 1
rint 0:2:3 1 #3FF0000000000000
rint 0:2:6 0 #0000000000000000
index 0:2:1 2
float 0:2:11 #4010000000000000
asg 0:2:1 set
rpname 0:3:5 B 2
rname 0:3:9 A loc 1
dot 0:3:9 T
let 0:3:1 0
rpname 0:4:5 f 3
rname 0:4:9 A loc 1
dot 0:4:9 flat
let 0:4:1 0
rname 0:5:1 printf pd 0
str 0:5:8 %25g%20%25d%20%25g%20%25d%0A
rname 0:5:25 B loc 2
rint 0:5:27 0 #0000000000000000
rint 0:5:30 1 #3FF0000000000000
index 0:5:25 2
rname 0:5:34 rows pd 0
rname 0:5:39 B loc 2
call 0:5:34 1
rname 0:5:43 f loc 3
rint 0:5:45 1 #3FF0000000000000
index 0:5:43 1
rname 0:5:49 len pd 0
rname 0:5:53 f loc 3
call 0:5:49 1
call 0:5:1 5
cstmt 0:5:1
prog 5
#end
