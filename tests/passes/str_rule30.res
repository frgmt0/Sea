#sea 1
#target arm64-macos
#file str_rule30.sea
rname 0:3:10 args pd 0
call 0:3:10 0
block 0:3:17 0
rfor 0:3:1 a 0:3:5 1
rpname 0:4:5 k 2
rname 0:4:9 len pd 0
rname 0:4:13 args pd 0
call 0:4:13 0
call 0:4:9 1
let 0:4:1 0
rname 0:5:1 printf pd 0
str 0:5:8 %25d%0A
rname 0:5:16 k loc 2
call 0:5:1 2
cstmt 0:5:1
prog 3
#end
