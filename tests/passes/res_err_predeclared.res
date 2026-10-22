#sea 1
#target arm64-macos
#file res_err_predeclared.sea
rerr 0:3:1 212 0
rtype 0:3:12 f64 s 0 4
param 0:3:9 x 0 0
rtype 0:3:20 f64 s 0 4
rname 0:4:12 x loc 1
return 0:4:5 1
block 0:3:24 1
rfn 0:3:1 sqrt 0 1 1 2 4 4
rpname 0:6:5 y 1
rname 0:6:9 sqrt fn 2
float 0:6:14 #4000000000000000
call 0:6:9 1
let 0:6:1 0
prog 2
#end
