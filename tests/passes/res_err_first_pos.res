#sea 1
#target arm64-macos
#file res_err_first_pos.sea
rerr 0:3:6 259 1 strings
type 0:3:9 str s 0
param 0:3:6 s 0 0
rname 0:4:5 printf pd 0
str 0:4:12 x%0A
call 0:4:5 1
cstmt 0:4:5
block 0:3:14 1
rfn 0:3:1 f 0 1 0 2 1 0
name 0:7:5 printf
str 0:7:12 y%0A
call 0:7:5 1
cstmt 0:7:5
block 0:6:8 1
fn 0:6:1 f 0 0 0
prog 2
#end
