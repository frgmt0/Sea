#sea 1
#target arm64-macos
#file libL_hirl.sea
rtvec 10 3
rpname 0:1:5 v 1
rtype 0:1:8 i64 v 0 10
rint 0:1:17 4660 #40B2340000000000
rint 0:1:26 1 #3FF0000000000000
neg 0:1:25
rint 0:1:29 255 #406FE00000000000
rint 0:1:34 4096 #40B0000000000000
row 0:1:17 4
array 0:1:16 1
let 0:1:1 1
rpname 0:2:5 w 2
rname 0:2:9 bitand pd 0
rname 0:2:16 shr pd 0
rname 0:2:20 v loc 1
rint 0:2:23 4 #4010000000000000
call 0:2:16 2
rint 0:2:27 15 #402E000000000000
call 0:2:9 2
let 0:2:1 0
rpname 0:3:5 z 3
rname 0:3:9 bitxor pd 0
rname 0:3:16 sar pd 0
rname 0:3:20 v loc 1
rint 0:3:23 3 #4008000000000000
call 0:3:16 2
rname 0:3:27 bitnot pd 0
rname 0:3:34 v loc 1
call 0:3:27 1
call 0:3:9 2
let 0:3:1 0
rpname 0:4:5 f 4
rname 0:4:9 split pd 0
str 0:4:15 a,b
str 0:4:22 ,
call 0:4:9 2
let 0:4:1 0
rpname 0:5:5 n 5
rname 0:5:9 parse_i64 pd 0
rname 0:5:19 f loc 4
rint 0:5:21 0 #0000000000000000
index 0:5:19 1
rint 0:5:31 16 #4030000000000000
narg 0:5:25 base
call 0:5:9 2
rname 0:5:37 len pd 0
rname 0:5:41 substr pd 0
rname 0:5:48 f loc 4
rint 0:5:50 1 #3FF0000000000000
index 0:5:48 1
rint 0:5:54 0 #0000000000000000
rint 0:5:57 1 #3FF0000000000000
call 0:5:41 3
call 0:5:37 1
bin 0:5:9 add
let 0:5:1 0
rpname 0:6:5 lines 6
rname 0:6:13 read_lines pd 0
str 0:6:24 in.txt
call 0:6:13 1
let 0:6:1 0
rpname 0:7:5 y 7
rname 0:7:9 parse_f64 pd 0
str 0:7:19 2.5
call 0:7:9 1
let 0:7:1 0
rname 0:8:1 printf pd 0
str 0:8:8 %25d%20%25d%20%25d%20%25d%20%25g%0A
rname 0:8:28 w loc 2
rint 0:8:30 0 #0000000000000000
index 0:8:28 1
rname 0:8:34 z loc 3
rint 0:8:36 1 #3FF0000000000000
index 0:8:34 1
rname 0:8:40 n loc 5
rname 0:8:43 len pd 0
rname 0:8:47 lines loc 6
call 0:8:43 1
rname 0:8:55 y loc 7
call 0:8:1 6
cstmt 0:8:1
prog 8
#end
