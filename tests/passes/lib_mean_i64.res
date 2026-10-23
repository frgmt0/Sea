#sea 1
#target arm64-macos
#file lib_mean_i64.sea
rpname 0:1:5 w 1
rint 0:1:10 3 #4008000000000000
rint 0:1:13 5 #4014000000000000
rint 0:1:16 9 #4022000000000000
row 0:1:10 3
array 0:1:9 1
let 0:1:1 0
rpname 0:2:5 t 2
rname 0:2:9 sum pd 0
rname 0:2:13 w loc 1
call 0:2:9 1
let 0:2:1 0
rpname 0:3:5 m 3
rname 0:3:9 mean pd 0
rname 0:3:14 w loc 1
call 0:3:9 1
let 0:3:1 0
rname 0:4:1 printf pd 0
str 0:4:8 %25d%20%25g%0A
rname 0:4:19 t loc 2
rname 0:4:22 m loc 3
call 0:4:1 3
cstmt 0:4:1
prog 4
#end
