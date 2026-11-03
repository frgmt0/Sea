#sea 1
#target arm64-macos
#file plot9_rcall.sea
rtvec 10 4
rpname 0:1:5 fig 1
rname 0:1:11 figure pd 0
rint 0:1:18 1 #3FF0000000000000
rint 0:1:21 2 #4000000000000000
str 0:1:30 r
narg 0:1:24 name
rint 0:1:42 400 #4079000000000000
narg 0:1:35 width
call 0:1:11 4
let 0:1:1 0
rpname 0:2:5 ax 2
rname 0:2:10 panel pd 0
rname 0:2:16 fig loc 1
rint 0:2:21 0 #0000000000000000
rint 0:2:24 1 #3FF0000000000000
call 0:2:10 3
let 0:2:1 0
rpname 0:3:5 t 3
rname 0:3:9 twin_y pd 0
rname 0:3:16 ax loc 2
call 0:3:9 1
let 0:3:1 0
rpname 0:4:5 x 4
rtype 0:4:8 f64 v 0 10
float 0:4:17 #0000000000000000
float 0:4:22 #3FF0000000000000
row 0:4:17 2
array 0:4:16 1
let 0:4:1 1
rname 0:5:1 plot pd 0
rname 0:5:6 t loc 3
rname 0:5:9 x loc 4
rname 0:5:12 x loc 4
str 0:5:22 r--
narg 0:5:15 style
str 0:5:36 a
narg 0:5:29 label
float 0:5:48 #4000000000000000
narg 0:5:41 width
str 0:5:60 #102030
narg 0:5:53 color
call 0:5:1 7
cstmt 0:5:1
rname 0:6:1 xline pd 0
rname 0:6:7 ax loc 2
float 0:6:11 #3FE0000000000000
str 0:6:23 :
narg 0:6:16 style
str 0:6:35 #00ff00
narg 0:6:28 color
call 0:6:1 4
cstmt 0:6:1
rname 0:7:1 xlabel pd 0
rname 0:7:8 ax loc 2
str 0:7:12 x
call 0:7:1 2
cstmt 0:7:1
rname 0:8:1 ylabel pd 0
rname 0:8:8 t loc 3
str 0:8:11 y
call 0:8:1 2
cstmt 0:8:1
rname 0:9:1 title pd 0
rname 0:9:7 ax loc 2
str 0:9:11 t
call 0:9:1 2
cstmt 0:9:1
rname 0:10:1 legend pd 0
rname 0:10:8 ax loc 2
str 0:10:17 south
narg 0:10:12 loc
call 0:10:1 2
cstmt 0:10:1
rname 0:11:1 grid pd 0
rname 0:11:6 ax loc 2
false 0:11:14
narg 0:11:10 on
call 0:11:1 2
cstmt 0:11:1
rname 0:12:1 xlim pd 0
rname 0:12:6 ax loc 2
float 0:12:11 #3FF0000000000000
neg 0:12:10
float 0:12:16 #4000000000000000
call 0:12:1 3
cstmt 0:12:1
rname 0:13:1 ylim pd 0
rname 0:13:6 t loc 3
float 0:13:9 #0000000000000000
float 0:13:14 #4008000000000000
call 0:13:1 3
cstmt 0:13:1
rname 0:14:1 x_ticks pd 0
rname 0:14:9 ax loc 2
str 0:14:14 p
str 0:14:19 q
row 0:14:14 2
array 0:14:13 1
call 0:14:1 2
cstmt 0:14:1
rname 0:15:1 y_ticks pd 0
rname 0:15:9 t loc 3
str 0:15:13 u
row 0:15:13 1
array 0:15:12 1
call 0:15:1 2
cstmt 0:15:1
rname 0:16:1 y_reverse pd 0
rname 0:16:11 t loc 3
call 0:16:1 1
cstmt 0:16:1
rname 0:17:1 axis_equal pd 0
rname 0:17:12 ax loc 2
call 0:17:1 1
cstmt 0:17:1
rname 0:18:1 save_svg pd 0
rname 0:18:10 fig loc 1
str 0:18:15 r.svg
call 0:18:1 2
cstmt 0:18:1
rname 0:19:1 printf pd 0
str 0:19:8 %25d%0A
rname 0:19:16 len pd 0
rname 0:19:20 x loc 4
call 0:19:16 1
call 0:19:1 2
cstmt 0:19:1
prog 19
#end
