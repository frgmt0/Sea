#sea 1
#target arm64-macos
#file lib_find_first.sea
rpname 0:1:5 m 1
false 0:1:10
true 0:1:17
true 0:1:23
false 0:1:29
row 0:1:10 4
array 0:1:9 1
let 0:1:1 0
rpname 0:2:5 a 2
rname 0:2:9 find_first pd 0
rname 0:2:20 m loc 1
call 0:2:9 1
let 0:2:1 0
rpname 0:3:5 b 3
rname 0:3:9 find_last pd 0
rname 0:3:19 m loc 1
call 0:3:9 1
let 0:3:1 0
rname 0:4:1 printf pd 0
str 0:4:8 %25d%20%25d%0A
rname 0:4:19 a loc 2
rname 0:4:22 b loc 3
call 0:4:1 3
cstmt 0:4:1
prog 4
#end
