#sea 1
#target arm64-macos
#file res_err_param_shadow.sea
rerr 0:3:6 213 0
type 0:3:11 i64 s 0
rint 0:3:17 1 #3FF0000000000000
param 0:3:6 len 0 1
type 0:3:23 i64 s 0
rname 0:4:12 len loc 1
return 0:4:5 1
block 0:3:27 1
rfn 0:3:1 f 0 1 1 2 3 3
prog 1
#end
