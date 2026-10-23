#sea 1
#target arm64-macos
#file str_rule26.sea
rpname 0:1:5 names 1
str 0:1:14 a
str 0:1:19 bc
row 0:1:14 2
array 0:1:13 1
let 0:1:1 0
rname 0:2:10 names loc 1
rname 0:3:5 printf pd 0
str 0:3:12 %25s%0A
rname 0:3:20 n loc 2
call 0:3:5 2
cstmt 0:3:5
block 0:2:16 1
rfor 0:2:1 n 0:2:5 2
prog 2
#end
