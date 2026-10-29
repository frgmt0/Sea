#sea 1
#target arm64-macos
#file str_ew.sea
rtvec 10 5
rtype 0:1:10 str v 0 10
param 0:1:7 v 0 0
rpname 0:2:9 c 2
rname 0:2:13 v loc 1
str 0:2:17 !
bin 0:2:13 add
let 0:2:5 0
rpname 0:3:9 e 3
rname 0:3:13 v loc 1
str 0:3:18 b
bin 0:3:13 eq
let 0:3:5 0
rname 0:4:5 printf pd 0
str 0:4:12 %25s%20%25s%20%25s%0A
rname 0:4:26 c loc 2
rint 0:4:28 0 #0000000000000000
index 0:4:26 1
rname 0:4:32 c loc 2
rint 0:4:34 1 #3FF0000000000000
index 0:4:32 1
rname 0:4:42 e loc 3
rint 0:4:44 1 #3FF0000000000000
index 0:4:42 1
conv 0:4:38 str
call 0:4:5 4
cstmt 0:4:5
block 0:1:17 3
rfn 0:1:1 ew 2 1 0 2 1 10
rname 0:6:1 ew fn 2
str 0:6:5 a
str 0:6:10 b
row 0:6:5 2
array 0:6:4 1
call 0:6:1 1
cstmt 0:6:1
rname 0:7:1 ew fn 2
str 0:7:5 b
str 0:7:10 c
str 0:7:15 d
row 0:7:5 3
array 0:7:4 1
call 0:7:1 1
cstmt 0:7:1
prog 3
#end
