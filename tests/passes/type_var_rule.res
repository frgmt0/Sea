#sea 1
#target arm64-macos
#file type_var_rule.sea
rtype 0:4:16 f64 s 0 4
param 0:4:9 v 1 0
rname 0:5:5 v loc 1
rname 0:5:9 v loc 1
rint 0:5:13 2 #4000000000000000
bin 0:5:9 div
asg 0:5:5 set
block 0:4:21 1
rfn 0:4:1 half 0 1 0 2 1 4
rpname 0:7:5 d 1
float 0:7:9 #4004000000000000
let 0:7:1 0
rpname 0:8:5 dMax 2
rint 0:8:12 0 #0000000000000000
var 0:8:1 0
rname 0:9:4 d loc 1
rname 0:9:8 dMax loc 2
bin 0:9:4 gt
rname 0:10:5 dMax loc 2
rname 0:10:12 d loc 1
asg 0:10:5 set
block 0:9:13 1
if 0:9:1 0
rpname 0:12:5 count 3
rint 0:12:13 0 #0000000000000000
var 0:12:1 0
rname 0:13:1 count loc 3
rint 0:13:10 1 #3FF0000000000000
asg 0:13:1 add
rpname 0:14:5 late 4
rint 0:14:12 1 #3FF0000000000000
var 0:14:1 0
rname 0:15:1 late loc 4
rname 0:15:8 late loc 4
rint 0:15:15 1 #3FF0000000000000
bin 0:15:8 add
asg 0:15:1 set
rname 0:16:1 late loc 4
float 0:16:8 #3FE0000000000000
asg 0:16:1 set
rpname 0:17:5 r 5
rint 0:17:9 4 #4010000000000000
var 0:17:1 0
rname 0:18:1 half fn 2
rname 0:18:10 r loc 5
ref 0:18:6
call 0:18:1 1
cstmt 0:18:1
rpname 0:19:5 n 6
rtype 0:19:8 i64 s 0 3
rint 0:19:14 0 #0000000000000000
var 0:19:1 1
rpname 0:20:5 k 7
rint 0:20:9 0 #0000000000000000
let 0:20:1 0
prog 13
#end
