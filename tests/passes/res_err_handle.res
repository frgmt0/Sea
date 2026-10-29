#sea 1
#target arm64-macos
#file res_err_handle.sea
rerr 0:3:9 259 1 handle%20types
rtype 0:3:9 Figure s 0 0
param 0:3:6 a 0 0
rname 0:4:5 printf pd 0
str 0:4:12 x%0A
call 0:4:5 1
cstmt 0:4:5
block 0:3:17 1
rfn 0:3:1 f 2 1 0 2 1 0
prog 1
#end
