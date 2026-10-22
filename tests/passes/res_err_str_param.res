#sea 1
#target arm64-macos
#file res_err_str_param.sea
rerr 0:3:6 259 1 strings
rtype 0:3:9 str s 0 0
param 0:3:6 s 0 0
rtype 0:3:17 i64 s 0 3
param 0:3:14 n 0 0
rname 0:4:5 printf pd 0
str 0:4:12 x%0A
call 0:4:5 1
cstmt 0:4:5
block 0:3:22 1
rfn 0:3:1 f 0 2 0 2 1 0 3
prog 1
#end
