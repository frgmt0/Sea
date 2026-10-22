#sea 1
#target arm64-macos
#file res_err_redef_item.sea
rerr 0:4:1 235 1 A
rint 0:3:11 1 #3FF0000000000000
rcni 0:3:1 A 0 1 1
name 0:4:11 A
rint 0:4:15 1 #3FF0000000000000
bin 0:4:11 add
const 0:4:1 A 0
rpname 0:5:5 b 1
rname 0:5:9 A cst 1
let 0:5:1 0
prog 3
#end
