#sea 1
#target arm64-macos
#file res_powk_mod.sea
rpname 0:3:5 x 1
float 0:3:9 #3FF8000000000000
let 0:3:1 0
rpname 0:4:5 a 2
rname 0:4:9 x loc 1
rint 0:4:14 6 #4018000000000000
rint 0:4:18 4 #4010000000000000
bin 0:4:14 mod
rpowk 0:4:9 2
let 0:4:1 0
rpname 0:5:5 b 3
rname 0:5:9 x loc 1
float 0:5:14 #4014000000000000
float 0:5:20 #4008000000000000
bin 0:5:14 mod
rpowk 0:5:9 2
let 0:5:1 0
prog 3
#end
