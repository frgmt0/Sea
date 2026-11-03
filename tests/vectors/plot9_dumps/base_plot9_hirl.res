#sea 1
#target arm64-macos
#file plot9_hirl.sea
rtvec 10 4
rpname 0:1:5 fig 1
rname 0:1:11 figure pd 0
rint 0:1:18 1 #3FF0000000000000
rint 0:1:21 1 #3FF0000000000000
call 0:1:11 2
let 0:1:1 0
rpname 0:2:5 ax 2
rname 0:2:10 panel pd 0
rname 0:2:16 fig loc 1
rint 0:2:21 0 #0000000000000000
rint 0:2:24 0 #0000000000000000
call 0:2:10 3
let 0:2:1 0
rpname 0:3:5 x 3
rtype 0:3:8 f64 v 0 10
float 0:3:17 #3FF0000000000000
float 0:3:22 #4000000000000000
float 0:3:27 #4008000000000000
row 0:3:17 3
array 0:3:16 1
let 0:3:1 1
rname 0:4:1 plot pd 0
rname 0:4:6 ax loc 2
float 0:4:10 #4000000000000000
rname 0:4:16 x loc 3
bin 0:4:10 mul
float 0:4:20 #3FF0000000000000
bin 0:4:10 add
rname 0:4:25 x loc 3
str 0:4:35 fit
narg 0:4:28 label
call 0:4:1 4
cstmt 0:4:1
rname 0:5:1 plot pd 0
rname 0:5:6 ax loc 2
rname 0:5:10 x loc 3
rint 0:5:12 0 #0000000000000000
rint 0:5:15 2 #4000000000000000
range 0:5:12 0 0
index 0:5:10 1
float 0:5:20 #4010000000000000
float 0:5:25 #4014000000000000
row 0:5:20 2
array 0:5:19 1
str 0:5:38 o
narg 0:5:31 style
call 0:5:1 4
cstmt 0:5:1
rname 0:6:1 x_ticks pd 0
rname 0:6:9 ax loc 2
str 0:6:14 a
str 0:6:19 b
row 0:6:14 2
array 0:6:13 1
call 0:6:1 2
cstmt 0:6:1
rname 0:7:1 save_svg pd 0
rname 0:7:10 fig loc 1
str 0:7:15 h.svg
call 0:7:1 2
cstmt 0:7:1
rname 0:8:1 printf pd 0
str 0:8:8 %25g%0A
rname 0:8:16 x loc 3
rint 0:8:18 2 #4000000000000000
index 0:8:16 1
call 0:8:1 2
cstmt 0:8:1
prog 8
#end
