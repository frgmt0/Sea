#sea 1
#target arm64-macos
#file res_rint.sea
rpname 0:3:5 a 1
rint 0:3:9 #0020000000000001 -
let 0:3:1 0
rpname 0:4:5 b 2
rint 0:4:10 #8000000000000000 #C3E0000000000000
neg 0:4:9
let 0:4:1 0
rpname 0:5:5 c 3
rint 0:5:9 #0020000000000000 #4340000000000000
rint 0:5:28 4 #4010000000000000
bin 0:5:9 mul
let 0:5:1 0
prog 3
#end
