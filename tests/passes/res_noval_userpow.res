#sea 1
#target arm64-macos
#file res_noval_userpow.sea
rerr 0:2:1 212 0
rname 0:1:11 pow fn 2
float 0:1:15 #4000000000000000
float 0:1:20 #4008000000000000
call 0:1:11 2
rcn 0:1:1 C 0 1
type 0:2:11 f64 s 0
param 0:2:8 x 0 0
type 0:2:19 f64 s 0
param 0:2:16 y 0 0
type 0:2:27 f64 s 0
rname 0:2:40 x loc 1
return 0:2:33 1
block 0:2:31 1
rfn 0:2:1 pow 0 2 1 2 4 4 4
prog 2
#end
