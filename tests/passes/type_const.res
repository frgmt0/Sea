#sea 1
#target arm64-macos
#file type_const.sea
rint 0:4:11 4 #4010000000000000
rcni 0:4:1 N 0 1 4
rname 0:5:11 N cst 1
rint 0:5:15 2 #4000000000000000
bin 0:5:11 mul
rint 0:5:19 1 #3FF0000000000000
bin 0:5:11 add
rcni 0:5:1 M 0 2 9
type 0:6:13 f64 s 0
float 0:6:19 #3FE0000000000000
rcnf 0:6:1 HALF 1 3 #3FE0000000000000
type 0:7:10 f64 s 0
rint 0:7:16 3 #4008000000000000
rcnf 0:7:1 K 1 4 #4008000000000000
float 0:8:13 #4000000000000000
rname 0:8:19 pi pd 0
bin 0:8:13 mul
rcnf 0:8:1 TAU 0 5 #401921FB54442D18
rpname 0:9:5 a 1
rname 0:9:9 M cst 2
let 0:9:1 0
rpname 0:10:5 b 2
rname 0:10:9 N cst 1
rname 0:10:13 HALF cst 3
bin 0:10:9 mul
let 0:10:1 0
rpname 0:11:5 c 3
rname 0:11:9 K cst 4
rname 0:11:13 TAU cst 5
bin 0:11:9 add
let 0:11:1 0
rpname 0:12:5 d 4
rname 0:12:10 N cst 1
neg 0:12:9
let 0:12:1 0
prog 9
#end
