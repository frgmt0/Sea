#sea 1
#target arm64-macos
#file arr_lit_fixed.sea
rtvec 10 4
rtfvec 11 4 0
rpname 0:1:5 f 1
float 0:1:10 #3FF8000000000000
float 0:1:15 #4004000000000000
float 0:1:20 #4010000000000000
row 0:1:10 3
array 0:1:9 1
let 0:1:1 0
rpname 0:2:5 e 2
rtype 0:2:8 f64 v 0 10
array 0:2:16 0
let 0:2:1 1
rpname 0:3:5 z 3
rint 0:3:12 0 #0000000000000000
rtype 0:3:8 f64 fv 1 11
array 0:3:17 0
let 0:3:1 1
rpname 0:4:5 m 4
rint 0:4:10 1 #3FF0000000000000
rint 0:4:13 2 #4000000000000000
row 0:4:10 2
rint 0:4:16 3 #4008000000000000
rint 0:4:19 4 #4010000000000000
row 0:4:16 2
array 0:4:9 2
let 0:4:1 0
rname 0:5:1 printf pd 0
str 0:5:8 %25g%20%25d%20%25d%20%25d%0A
rname 0:5:25 f loc 1
rint 0:5:27 1 #3FF0000000000000
index 0:5:25 1
rname 0:5:31 len pd 0
rname 0:5:35 e loc 2
call 0:5:31 1
rname 0:5:39 len pd 0
rname 0:5:43 z loc 3
call 0:5:39 1
rname 0:5:47 m loc 4
rint 0:5:49 1 #3FF0000000000000
rint 0:5:52 0 #0000000000000000
index 0:5:47 2
call 0:5:1 5
cstmt 0:5:1
prog 5
#end
