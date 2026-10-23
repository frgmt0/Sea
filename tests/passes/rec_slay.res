#sea 1
#target arm64-macos
#file rec_slay.sea
rpname 0:1:5 rs 1
rint 0:1:16 1 #3FF0000000000000
init 0:1:13 a
str 0:1:22 x
init 0:1:19 b
rlit 0:1:11 2
rint 0:1:34 2 #4000000000000000
init 0:1:31 a
str 0:1:40 y
init 0:1:37 b
rlit 0:1:29 2
row 0:1:11 2
array 0:1:10 1
let 0:1:1 0
rpname 0:2:5 t 2
rint 0:2:9 0 #0000000000000000
var 0:2:1 0
rname 0:3:10 rs loc 1
rname 0:4:5 t loc 2
rname 0:4:10 r loc 3
dot 0:4:10 a
asg 0:4:5 add
rname 0:5:5 printf pd 0
str 0:5:12 %25s%0A
rname 0:5:20 r loc 3
dot 0:5:20 b
call 0:5:5 2
cstmt 0:5:5
block 0:3:13 2
rfor 0:3:1 r 0:3:5 3
rname 0:7:1 printf pd 0
str 0:7:8 %25d%0A
rname 0:7:16 t loc 2
call 0:7:1 2
cstmt 0:7:1
prog 4
#end
