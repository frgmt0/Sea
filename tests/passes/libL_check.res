#sea 1
#target arm64-macos
#file libL_check.sea
rtvec 10 3
rtype 0:1:12 str s 0 5
param 0:1:6 path 0 0
rtype 0:1:20 str s 0 5
param 0:1:17 s 0 0
rtype 0:1:28 i64 v 0 10
param 0:1:25 v 0 0
rtype 0:1:38 i64 s 0 3
param 0:1:35 k 0 0
rtype 0:1:46 i64 s 0 3
rpname 0:2:9 L 5
rname 0:2:13 read_lines pd 0
rname 0:2:24 path loc 1
call 0:2:13 1
let 0:2:5 0
rpname 0:3:9 F 6
rname 0:3:13 split pd 0
rname 0:3:19 s loc 2
str 0:3:22 ,
call 0:3:13 2
let 0:3:5 0
rpname 0:4:9 t 7
rname 0:4:13 substr pd 0
rname 0:4:20 s loc 2
rint 0:4:23 1 #3FF0000000000000
rname 0:4:26 k loc 4
call 0:4:13 3
let 0:4:5 0
rpname 0:5:9 a 8
rname 0:5:13 parse_i64 pd 0
rname 0:5:23 t loc 7
call 0:5:13 1
let 0:5:5 0
rpname 0:6:9 b 9
rname 0:6:13 parse_i64 pd 0
rname 0:6:23 t loc 7
rint 0:6:32 16 #4030000000000000
narg 0:6:26 base
call 0:6:13 2
let 0:6:5 0
rpname 0:7:9 x 10
rname 0:7:13 parse_f64 pd 0
rname 0:7:23 F loc 6
rint 0:7:25 0 #0000000000000000
index 0:7:23 1
call 0:7:13 1
let 0:7:5 0
rpname 0:8:9 c 11
rname 0:8:13 bitand pd 0
rname 0:8:20 a loc 8
rint 0:8:23 255 #406FE00000000000
call 0:8:13 2
rname 0:8:31 bitor pd 0
rname 0:8:37 b loc 9
rname 0:8:40 k loc 4
call 0:8:31 2
bin 0:8:13 add
rname 0:8:45 bitxor pd 0
rname 0:8:52 a loc 8
rint 0:8:56 1 #3FF0000000000000
neg 0:8:55
call 0:8:45 2
bin 0:8:13 add
let 0:8:5 0
rpname 0:9:9 d 12
rname 0:9:13 bitnot pd 0
rname 0:9:20 c loc 11
call 0:9:13 1
rname 0:9:25 shl pd 0
rname 0:9:29 c loc 11
rint 0:9:32 2 #4000000000000000
call 0:9:25 2
bin 0:9:13 add
rname 0:9:37 shr pd 0
rname 0:9:41 c loc 11
rname 0:9:44 k loc 4
call 0:9:37 2
bin 0:9:13 add
rname 0:9:49 sar pd 0
rname 0:9:53 c loc 11
rint 0:9:56 63 #404F800000000000
call 0:9:49 2
bin 0:9:13 add
let 0:9:5 0
rpname 0:10:9 w 13
rname 0:10:13 bitand pd 0
rname 0:10:20 shr pd 0
rname 0:10:24 v loc 3
rint 0:10:27 4 #4010000000000000
call 0:10:20 2
rint 0:10:31 15 #402E000000000000
call 0:10:13 2
let 0:10:5 0
rpname 0:11:9 e 14
rname 0:11:13 bitnot pd 0
rname 0:11:20 v loc 3
call 0:11:13 1
let 0:11:5 0
rname 0:12:12 c loc 11
rname 0:12:16 d loc 12
bin 0:12:12 add
rname 0:12:20 len pd 0
rname 0:12:24 L loc 5
call 0:12:20 1
bin 0:12:12 add
rname 0:12:29 w loc 13
rint 0:12:31 0 #0000000000000000
index 0:12:29 1
bin 0:12:12 add
rname 0:12:36 e loc 14
rint 0:12:38 0 #0000000000000000
index 0:12:36 1
bin 0:12:12 add
rname 0:12:47 x loc 10
conv 0:12:43 i64
bin 0:12:12 add
return 0:12:5 1
block 0:1:50 11
rfn 0:1:1 g 2 4 1 2 3 5 5 10 3
prog 1
#end
