#sea 1
#target arm64-macos
#file lib_sort_fixed.sea
rpname 0:1:5 f 1
float 0:1:10 #4008000000000000
float 0:1:15 #3FE0000000000000
float 0:1:20 #4000000000000000
row 0:1:10 3
array 0:1:9 1
let 0:1:1 0
rpname 0:2:5 s 2
rname 0:2:9 sort pd 0
rname 0:2:14 f loc 1
call 0:2:9 1
let 0:2:1 0
rpname 0:3:5 d 3
rname 0:3:9 s loc 2
rint 0:3:11 0 #0000000000000000
index 0:3:9 1
float 0:3:16 #3FF0000000000000
bin 0:3:9 lt
let 0:3:1 0
rpname 0:4:5 r 4
rname 0:4:9 argsort pd 0
rname 0:4:17 f loc 1
rname 0:4:26 d loc 3
narg 0:4:20 desc
call 0:4:9 2
let 0:4:1 0
rname 0:5:1 printf pd 0
str 0:5:8 %25g%20%25d%0A
rname 0:5:19 s loc 2
rint 0:5:21 2 #4000000000000000
index 0:5:19 1
rname 0:5:25 r loc 4
rint 0:5:27 0 #0000000000000000
index 0:5:25 1
call 0:5:1 3
cstmt 0:5:1
prog 5
#end
