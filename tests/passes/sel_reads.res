#sea 1
#target arm64-macos
#file sel_reads.sea
rpname 0:1:5 A 1
rname 0:1:9 zeros pd 0
rint 0:1:15 2 #4000000000000000
rint 0:1:18 3 #4008000000000000
call 0:1:9 2
var 0:1:1 0
rname 0:2:1 A loc 1
rint 0:2:3 0 #0000000000000000
rint 0:2:6 2 #4000000000000000
index 0:2:1 2
float 0:2:11 #4014000000000000
asg 0:2:1 set
rname 0:3:1 A loc 1
rint 0:3:3 1 #3FF0000000000000
rint 0:3:6 2 #4000000000000000
index 0:3:1 2
float 0:3:11 #4018000000000000
asg 0:3:1 set
rpname 0:4:5 c 2
rname 0:4:9 A loc 1
all 0:4:11
rint 0:4:14 2 #4000000000000000
index 0:4:9 2
let 0:4:1 0
rpname 0:5:5 w 3
rname 0:5:9 filled pd 0
rint 0:5:16 1 #3FF0000000000000
rint 0:5:19 2 #4000000000000000
call 0:5:9 2
let 0:5:1 0
rpname 0:6:5 r 4
rname 0:6:9 c loc 2
rname 0:6:11 w loc 3
index 0:6:9 1
let 0:6:1 0
rpname 0:7:5 M 5
rname 0:7:9 A loc 1
float 0:7:13 #4016000000000000
bin 0:7:9 gt
let 0:7:1 0
rpname 0:8:5 s 6
rname 0:8:9 A loc 1
rname 0:8:11 M loc 5
index 0:8:9 1
let 0:8:1 0
rname 0:9:1 printf pd 0
str 0:9:8 %25g%20%25g%20%25g%20%25d%20%25g%0A
rname 0:9:28 c loc 2
rint 0:9:30 0 #0000000000000000
index 0:9:28 1
rname 0:9:34 c loc 2
rint 0:9:36 1 #3FF0000000000000
index 0:9:34 1
rname 0:9:40 r loc 4
rint 0:9:42 0 #0000000000000000
index 0:9:40 1
rname 0:9:46 len pd 0
rname 0:9:50 r loc 4
call 0:9:46 1
rname 0:9:54 s loc 6
rint 0:9:56 0 #0000000000000000
index 0:9:54 1
call 0:9:1 6
cstmt 0:9:1
prog 9
#end
