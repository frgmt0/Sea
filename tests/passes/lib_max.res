#sea 1
#target arm64-macos
#file lib_max.sea
rpname 0:1:5 v 1
float 0:1:10 #4004000000000000
rname 0:1:15 nan pd 0
float 0:1:20 #401C000000000000
float 0:1:25 #3FE0000000000000
float 0:1:30 #401C000000000000
row 0:1:10 5
array 0:1:9 1
let 0:1:1 0
rpname 0:2:5 w 2
rint 0:2:10 4 #4010000000000000
rint 0:2:13 1 #3FF0000000000000
rint 0:2:16 9 #4022000000000000
rint 0:2:19 1 #3FF0000000000000
row 0:2:10 4
array 0:2:9 1
let 0:2:1 0
rpname 0:3:5 a 3
rname 0:3:9 max pd 0
rname 0:3:13 v loc 1
call 0:3:9 1
let 0:3:1 0
rpname 0:4:5 b 4
rname 0:4:9 argmin pd 0
rname 0:4:16 w loc 2
call 0:4:9 1
let 0:4:1 0
rname 0:5:1 printf pd 0
str 0:5:8 %25g%20%25d%0A
rname 0:5:19 a loc 3
rname 0:5:22 b loc 4
call 0:5:1 3
cstmt 0:5:1
prog 5
#end
