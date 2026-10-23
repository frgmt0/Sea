#sea 1
#target arm64-macos
#file lib_find.sea
rpname 0:1:5 m 1
false 0:1:10
true 0:1:17
true 0:1:23
false 0:1:29
true 0:1:36
row 0:1:10 5
array 0:1:9 1
let 0:1:1 0
rpname 0:2:5 f 2
rname 0:2:9 find pd 0
rname 0:2:14 m loc 1
call 0:2:9 1
let 0:2:1 0
rname 0:3:1 printf pd 0
str 0:3:8 %25d%20%25d%0A
rname 0:3:19 len pd 0
rname 0:3:23 f loc 2
call 0:3:19 1
rname 0:3:27 f loc 2
rint 0:3:29 2 #4000000000000000
index 0:3:27 1
call 0:3:1 3
cstmt 0:3:1
prog 3
#end
