#sea 1
#target arm64-macos
#file arr_dynfix.sea
rtvec 10 4
rtfvec 11 4 2
rpname 0:1:5 f 1
float 0:1:10 #3FF8000000000000
float 0:1:15 #4004000000000000
row 0:1:10 2
array 0:1:9 1
let 0:1:1 0
rpname 0:2:5 d 2
rtype 0:2:8 f64 v 0 10
rname 0:2:16 f loc 1
let 0:2:1 1
rpname 0:3:5 g 3
rint 0:3:12 2 #4000000000000000
rtype 0:3:8 f64 fv 1 11
rname 0:3:17 d loc 2
let 0:3:1 1
rname 0:4:1 printf pd 0
str 0:4:8 %25g%20%25g%20%25d%0A
rname 0:4:22 d loc 2
rint 0:4:24 1 #3FF0000000000000
index 0:4:22 1
rname 0:4:28 g loc 3
rint 0:4:30 0 #0000000000000000
index 0:4:28 1
rname 0:4:34 len pd 0
rname 0:4:38 d loc 2
call 0:4:34 1
call 0:4:1 4
cstmt 0:4:1
prog 4
#end
