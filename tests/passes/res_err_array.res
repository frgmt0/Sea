#sea 1
#target arm64-macos
#file res_err_array.sea
rtfvec 10 4 3
rint 0:3:13 3 #4008000000000000
rtype 0:3:9 f64 fv 1 10
param 0:3:6 v 0 0
rtype 0:3:20 i64 s 0 3
param 0:3:17 k 0 0
rtype 0:3:28 i64 s 0 3
rname 0:4:12 k loc 2
return 0:4:5 1
block 0:3:32 1
rfn 0:3:1 f 2 2 1 2 3 10 3
prog 1
#end
