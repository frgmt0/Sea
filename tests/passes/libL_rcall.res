#sea 1
#target arm64-macos
#file libL_rcall.sea
rpname 0:1:5 path 1
str 0:1:12 can.log
let 0:1:1 0
rpname 0:2:5 lines 2
rname 0:2:13 read_lines pd 0
rname 0:2:24 path loc 1
call 0:2:13 1
let 0:2:1 0
rpname 0:3:5 f 3
rname 0:3:9 split pd 0
rname 0:3:15 lines loc 2
rint 0:3:21 0 #0000000000000000
index 0:3:15 1
str 0:3:25 %20
call 0:3:9 2
let 0:3:1 0
rpname 0:4:5 t 4
rname 0:4:9 substr pd 0
rname 0:4:16 f loc 3
rint 0:4:18 0 #0000000000000000
index 0:4:16 1
rint 0:4:22 1 #3FF0000000000000
rint 0:4:25 18 #4032000000000000
call 0:4:9 3
let 0:4:1 0
rpname 0:5:5 id 5
rname 0:5:10 parse_i64 pd 0
rname 0:5:20 f loc 3
rint 0:5:22 2 #4000000000000000
index 0:5:20 1
rint 0:5:32 16 #4030000000000000
narg 0:5:26 base
call 0:5:10 2
let 0:5:1 0
rpname 0:6:5 k 6
rname 0:6:9 parse_i64 pd 0
str 0:6:19 42
call 0:6:9 1
let 0:6:1 0
rpname 0:7:5 x 7
rname 0:7:9 parse_f64 pd 0
rname 0:7:19 substr pd 0
rname 0:7:26 t loc 4
rint 0:7:29 0 #0000000000000000
rint 0:7:32 4 #4010000000000000
call 0:7:19 3
call 0:7:9 1
let 0:7:1 0
rname 0:8:1 printf pd 0
str 0:8:8 %25d%20%25d%20%25d%20%25g%0A
rname 0:8:25 len pd 0
rname 0:8:29 f loc 3
call 0:8:25 1
rname 0:8:33 id loc 5
rname 0:8:37 k loc 6
rname 0:8:40 x loc 7
call 0:8:1 5
cstmt 0:8:1
prog 8
#end
