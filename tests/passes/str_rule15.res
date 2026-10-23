#sea 1
#target arm64-macos
#file str_rule15.sea
rtype 0:3:12 str s 0 5
param 0:3:9 a 0 0
rtype 0:3:20 str s 0 5
param 0:3:17 b 0 0
rpname 0:4:9 s 3
rname 0:4:13 a loc 1
rname 0:4:17 b loc 2
bin 0:4:13 add
let 0:4:5 0
rpname 0:5:9 t 4
rname 0:5:13 s loc 3
let 0:5:5 0
rname 0:6:5 printf pd 0
str 0:6:12 %25s%0A
rname 0:6:20 a loc 1
rname 0:6:24 b loc 2
bin 0:6:20 add
call 0:6:5 2
cstmt 0:6:5
rname 0:7:5 printf pd 0
str 0:7:12 %25s%20%25s%0A
rname 0:7:23 s loc 3
rname 0:7:26 t loc 4
call 0:7:5 3
cstmt 0:7:5
block 0:3:25 4
rfn 0:3:1 show 0 2 0 2 1 5 5
rpname 0:9:5 x 1
rint 0:9:13 12 #4028000000000000
conv 0:9:9 str
let 0:9:1 0
rpname 0:10:5 y 2
rint 0:10:13 7 #401C000000000000
conv 0:10:9 str
let 0:10:1 0
rname 0:11:1 show fn 2
rname 0:11:6 x loc 1
rname 0:11:9 y loc 2
call 0:11:1 2
cstmt 0:11:1
rname 0:12:1 show fn 2
rname 0:12:6 y loc 2
rname 0:12:9 x loc 1
call 0:12:1 2
cstmt 0:12:1
prog 5
#end
