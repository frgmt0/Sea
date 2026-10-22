#sea 1
#target arm64-macos
#file res_err_default.sea
rerr 0:3:6 259 1 default%20arguments
rtype 0:3:9 i64 s 0 3
name 0:3:15 K
param 0:3:6 a 0 1
rtype 0:3:21 i64 s 0 3
rname 0:4:12 a loc 1
return 0:4:5 1
block 0:3:25 1
rfn 0:3:1 f 0 1 1 2 3 3
rint 0:6:11 1 #3FF0000000000000
rcni 0:6:1 K 0 1 1
prog 2
#end
