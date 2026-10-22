#sea 1
#target arm64-macos
#file res_err_param_redef.sea
rerr 0:3:14 235 1 a
type 0:3:9 i64 s 0
param 0:3:6 a 0 0
type 0:3:17 i64 s 0
param 0:3:14 a 0 0
rname 0:4:5 printf pd 0
str 0:4:12 x%0A
call 0:4:5 1
cstmt 0:4:5
block 0:3:22 1
rfn 0:3:1 g 0 2 0 2 1 3 3
prog 1
#end
