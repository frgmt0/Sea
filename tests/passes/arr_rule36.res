#sea 1
#target arm64-macos
#file arr_rule36.sea
rname 0:1:1 printf pd 0
str 0:1:8 %25g%0A
rname 0:1:16 dist fn 2
float 0:1:21 #3FE0000000000000
float 0:1:26 #4000000000000000
call 0:1:16 2
call 0:1:1 2
cstmt 0:1:1
rname 0:2:1 printf pd 0
str 0:2:8 %25g%0A
rname 0:2:16 dist fn 2
float 0:2:21 #4010000000000000
float 0:2:26 #3FF8000000000000
call 0:2:16 2
call 0:2:1 2
cstmt 0:2:1
rtype 0:5:13 f64 s 0 4
param 0:5:9 tn 0 0
rtype 0:5:21 f64 s 0 4
param 0:5:18 t 0 0
rtype 0:5:29 f64 s 0 4
rpname 0:6:9 d 3
rname 0:6:13 abs pd 0
rname 0:6:17 tn loc 1
rname 0:6:22 t loc 2
bin 0:6:17 sub
call 0:6:13 1
let 0:6:5 0
rpname 0:7:9 r 4
rname 0:7:13 d loc 3
var 0:7:5 0
rname 0:8:11 r loc 4
float 0:8:15 #3FF0000000000000
bin 0:8:11 gt
rname 0:9:9 r loc 4
rname 0:9:13 r loc 4
float 0:9:17 #4000000000000000
bin 0:9:13 div
asg 0:9:9 set
block 0:8:19 1
while 0:8:5
rname 0:11:12 r loc 4
return 0:11:5 1
block 0:5:33 4
rfn 0:5:1 dist 0 2 1 2 4 4 4
prog 3
#end
