#sea 1
#target arm64-macos
#file res_noprelude_pnames.sea
rpname 0:4:5 a 1
rname 0:4:9 linspace none 0
rint 0:4:18 0 #0000000000000000
rint 0:4:21 1 #3FF0000000000000
rint 0:4:24 3 #4008000000000000
call 0:4:9 3
let 0:4:1 0
rpname 0:5:5 b 2
rname 0:5:9 meshgrid none 0
let 0:5:1 0
rname 0:6:1 setdiff none 0
rname 0:6:9 bincount none 0
call 0:6:1 1
cstmt 0:6:1
rname 0:7:1 printf pd 0
str 0:7:8 %25d%0A
rname 0:7:16 len pd 0
rname 0:7:20 zeros pd 0
rint 0:7:26 2 #4000000000000000
call 0:7:20 1
call 0:7:16 1
call 0:7:1 2
cstmt 0:7:1
prog 4
#end
