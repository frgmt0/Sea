#sea 1
#target arm64-macos
#file arr_rule17.sea
rpname 0:1:5 n 1
rint 0:1:9 3 #4008000000000000
let 0:1:1 0
rpname 0:1:16 u 2
rname 0:1:20 ones pd 0
rname 0:1:25 n loc 1
call 0:1:20 1
let 0:1:12 0
rname 0:2:1 printf pd 0
str 0:2:8 %25g%20%25d%0A
rname 0:2:19 u loc 2
rint 0:2:21 2 #4000000000000000
index 0:2:19 1
rname 0:2:25 len pd 0
rname 0:2:29 u loc 2
call 0:2:25 1
call 0:2:1 3
cstmt 0:2:1
prog 3
#end
