#sea 1
#target arm64-macos
#file plot9_check.sea
rtvec 10 4
rtvec 11 3
rtvec 12 5
rtype 0:1:10 Axes s 0 7
param 0:1:6 ax 0 0
rtype 0:1:19 f64 v 0 10
param 0:1:16 x 0 0
rtype 0:1:29 i64 v 0 11
param 0:1:26 k 0 0
rtype 0:1:39 str v 0 12
param 0:1:36 s 0 0
rtype 0:1:49 Figure s 0 6
rpname 0:2:9 fig 5
rname 0:2:15 figure pd 0
rint 0:2:22 2 #4000000000000000
rint 0:2:25 3 #4008000000000000
rint 0:2:36 600 #4082C00000000000
narg 0:2:28 height
str 0:2:47 h
narg 0:2:41 name
call 0:2:15 4
let 0:2:5 0
rpname 0:3:9 p 6
rtype 0:3:12 Axes s 0 7
rname 0:3:19 panel pd 0
rname 0:3:25 fig loc 5
rint 0:3:30 1 #3FF0000000000000
rint 0:3:33 0 #0000000000000000
rint 0:3:45 2 #4000000000000000
narg 0:3:36 colspan
call 0:3:19 4
let 0:3:5 1
rpname 0:4:9 tw 7
rname 0:4:14 twin_y pd 0
rname 0:4:21 p loc 6
call 0:4:14 1
let 0:4:5 0
rname 0:5:5 plot pd 0
rname 0:5:10 ax loc 1
rname 0:5:14 x loc 2
rname 0:5:17 x loc 2
rname 0:5:27 s loc 4
rint 0:5:29 0 #0000000000000000
index 0:5:27 1
narg 0:5:20 label
str 0:5:40 o
narg 0:5:33 style
call 0:5:5 5
cstmt 0:5:5
rname 0:6:5 plot pd 0
rname 0:6:10 p loc 6
rname 0:6:13 k loc 3
float 0:6:17 #3FF0000000000000
float 0:6:22 #4000000000000000
row 0:6:17 2
array 0:6:16 1
call 0:6:5 3
cstmt 0:6:5
rname 0:7:5 xline pd 0
rname 0:7:11 tw loc 7
rint 0:7:15 1 #3FF0000000000000
str 0:7:25 #00ff00
narg 0:7:18 color
call 0:7:5 3
cstmt 0:7:5
rname 0:8:5 xlim pd 0
rname 0:8:10 ax loc 1
rint 0:8:14 0 #0000000000000000
float 0:8:17 #4004000000000000
call 0:8:5 3
cstmt 0:8:5
rname 0:9:5 grid pd 0
rname 0:9:10 ax loc 1
call 0:9:5 1
cstmt 0:9:5
rname 0:10:5 legend pd 0
rname 0:10:12 p loc 6
str 0:10:20 best
narg 0:10:15 loc
call 0:10:5 2
cstmt 0:10:5
rname 0:11:5 x_ticks pd 0
rname 0:11:13 ax loc 1
rname 0:11:17 s loc 4
call 0:11:5 2
cstmt 0:11:5
rname 0:12:5 y_reverse pd 0
rname 0:12:15 tw loc 7
call 0:12:5 1
cstmt 0:12:5
rname 0:13:5 save_svg pd 0
rname 0:13:14 fig loc 5
str 0:13:19 g.svg
call 0:13:5 2
cstmt 0:13:5
rname 0:14:12 fig loc 5
return 0:14:5 1
block 0:1:56 13
rfn 0:1:1 g 2 4 1 2 6 7 10 11 12
prog 1
#end
