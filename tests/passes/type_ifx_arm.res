#sea 1
#target arm64-macos
#file type_ifx_arm.sea
rpname 0:4:5 c 1
true 0:4:9
let 0:4:1 0
rpname 0:5:5 v 2
rname 0:5:12 c loc 1
float 0:5:16 #3FE0000000000000
rint 0:5:29 2 #4000000000000000
ifx 0:5:9
let 0:5:1 0
rpname 0:6:5 w 3
rname 0:6:9 c loc 1
rname 0:6:14 v loc 2
float 0:6:18 #3FF0000000000000
bin 0:6:14 gt
bin 0:6:9 and
let 0:6:1 0
prog 3
#end
