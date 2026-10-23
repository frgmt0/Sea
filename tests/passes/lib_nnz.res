#sea 1
#target arm64-macos
#file lib_nnz.sea
rpname 0:1:5 m 1
true 0:1:10
false 0:1:16
true 0:1:23
true 0:1:29
row 0:1:10 4
array 0:1:9 1
let 0:1:1 0
rpname 0:2:5 n 2
rname 0:2:9 nnz pd 0
rname 0:2:13 m loc 1
call 0:2:9 1
let 0:2:1 0
rpname 0:3:5 y 3
rname 0:3:9 any pd 0
rname 0:3:13 m loc 1
call 0:3:9 1
let 0:3:1 0
rpname 0:4:5 z 4
rname 0:4:9 all pd 0
rname 0:4:13 m loc 1
call 0:4:9 1
let 0:4:1 0
rname 0:5:1 printf pd 0
str 0:5:8 %25d%20%25d%20%25d%0A
rname 0:5:22 n loc 2
rname 0:5:25 y loc 3
rname 0:5:28 z loc 4
call 0:5:1 4
cstmt 0:5:1
prog 5
#end
