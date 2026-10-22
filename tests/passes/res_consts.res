#sea 1
#target arm64-macos
#file res_consts.sea
rint 0:3:11 7 #401C000000000000
rint 0:3:15 3 #4008000000000000
bin 0:3:11 mod
rint 0:3:19 10 #4024000000000000
bin 0:3:11 sub
rcni 0:3:1 I 0 1 -9
type 0:4:10 f64 s 0
rname 0:4:16 I cst 1
rint 0:4:20 2 #4000000000000000
bin 0:4:16 mul
rcnf 0:4:1 F 1 2 #C032000000000000
rname 0:5:11 F cst 2
float 0:5:15 #0000000000000000
bin 0:5:11 lt
false 0:5:23
not 0:5:22
bin 0:5:11 and
rcnb 0:5:1 B 0 3 1
rint 0:6:11 1 #3FF0000000000000
rint 0:6:15 #7FFFFFFFFFFFFFFF -
rint 0:6:37 2 #4000000000000000
bin 0:6:15 mul
bin 0:6:11 add
rcne 0:6:1 O 0 4 ovf 0:6:15
rint 0:7:11 5 #4014000000000000
rname 0:7:16 I cst 1
rint 0:7:20 9 #4022000000000000
bin 0:7:16 add
bin 0:7:11 mod
rcne 0:7:1 D 0 5 div0 0:7:11
rname 0:8:11 now pd 0
call 0:8:11 0
rcn 0:8:1 N 0 6
rname 0:9:11 N cst 6
rint 0:9:15 1 #3FF0000000000000
bin 0:9:11 add
rcn 0:9:1 M 0 7
rname 0:10:11 Q cst 9
rint 0:10:15 2 #4000000000000000
bin 0:10:11 mul
rcn 0:10:1 P 0 8
rname 0:11:11 P cst 8
rint 0:11:15 1 #3FF0000000000000
bin 0:11:11 add
rcn 0:11:1 Q 0 9
rpname 0:12:5 x 1
rname 0:12:9 I cst 1
rname 0:12:13 M cst 7
bin 0:12:9 add
let 0:12:1 0
prog 10
#end
