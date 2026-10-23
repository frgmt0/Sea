#sea 1
#target arm64-macos
#file str_fill_flat.sea
rtype 0:1:12 str s 0 5
param 0:1:9 s 0 0
rtype 0:1:20 i64 s 0 3
param 0:1:17 r 0 0
rpname 0:2:9 m 3
rname 0:2:13 filled pd 0
rname 0:2:20 s loc 1
rname 0:2:23 r loc 2
rint 0:2:26 2 #4000000000000000
call 0:2:13 3
let 0:2:5 0
rpname 0:3:9 f 4
rname 0:3:13 m loc 3
dot 0:3:13 flat
let 0:3:5 0
rname 0:4:5 printf pd 0
str 0:4:12 %25d%20%25s%0A
rname 0:4:23 len pd 0
rname 0:4:27 f loc 4
call 0:4:23 1
rname 0:4:31 f loc 4
rint 0:4:33 1 #3FF0000000000000
index 0:4:31 1
call 0:4:5 3
cstmt 0:4:5
block 0:1:25 3
rfn 0:1:1 tile 0 2 0 2 1 5 3
rname 0:6:1 tile fn 2
str 0:6:6 ab
rint 0:6:12 2 #4000000000000000
call 0:6:1 2
cstmt 0:6:1
rname 0:7:1 tile fn 2
str 0:7:6 c
rint 0:7:11 1 #3FF0000000000000
call 0:7:1 2
cstmt 0:7:1
prog 3
#end
