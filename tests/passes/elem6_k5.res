#sea 1
#target arm64-macos
#file elem6_k5.sea
rtup 10 5 4 4 4 4 4
rtype 0:4:19 f64 s 0 4
param 0:4:16 x 0 0
rtype 0:4:28 f64 s 0 4
rtype 0:4:33 f64 s 0 4
rtype 0:4:38 f64 s 0 4
rtype 0:4:43 f64 s 0 4
rtype 0:4:48 f64 s 0 4
rname 0:5:13 x loc 1
rname 0:5:16 x loc 1
float 0:5:20 #3FF0000000000000
bin 0:5:16 add
rname 0:5:25 x loc 1
float 0:5:29 #4000000000000000
bin 0:5:25 add
rname 0:5:34 x loc 1
float 0:5:38 #4008000000000000
bin 0:5:34 add
rname 0:5:43 x loc 1
float 0:5:47 #4010000000000000
bin 0:5:43 add
return 0:5:5 5
block 0:4:53 1
rfn 0:4:1 g 1 1 5 2 10 4
rpname 0:7:5 v 1
rname 0:7:9 zeros pd 0
rint 0:7:15 2 #4000000000000000
call 0:7:9 1
let 0:7:1 0
rpname 0:8:6 a 2
pskip 0:8:9
rpname 0:8:12 c 3
pskip 0:8:15
rpname 0:8:18 e 4
ptuple 0:8:5 5
rname 0:8:23 g fn 2
rname 0:8:25 v loc 1
call 0:8:23 1
let 0:8:1 0
rpname 0:9:5 p 5
rname 0:9:9 zeros pd 0
rint 0:9:15 1 #3FF0000000000000
call 0:9:9 1
var 0:9:1 0
rpname 0:10:5 q 6
rname 0:10:9 zeros pd 0
rint 0:10:15 1 #3FF0000000000000
call 0:10:9 1
var 0:10:1 0
rname 0:11:2 p loc 5
pskip 0:11:5
pskip 0:11:8
rname 0:11:11 q loc 6
pskip 0:11:14
rname 0:11:19 g fn 2
rname 0:11:21 v loc 1
call 0:11:19 1
tasg 0:11:1 5
rname 0:12:1 g fn 2
rname 0:12:3 v loc 1
call 0:12:1 1
cstmt 0:12:1
rname 0:13:1 printf pd 0
str 0:13:8 %25g%20%25g%20%25g%20%25g%20%25g%20%25d%20%25d%0A
rname 0:13:34 a loc 2
rint 0:13:36 1 #3FF0000000000000
index 0:13:34 1
rname 0:13:40 c loc 3
rint 0:13:42 1 #3FF0000000000000
index 0:13:40 1
rname 0:13:46 e loc 4
rint 0:13:48 1 #3FF0000000000000
index 0:13:46 1
rname 0:13:52 p loc 5
rint 0:13:54 1 #3FF0000000000000
index 0:13:52 1
rname 0:13:58 q loc 6
rint 0:13:60 1 #3FF0000000000000
index 0:13:58 1
rname 0:13:64 len pd 0
rname 0:13:68 a loc 2
call 0:13:64 1
rname 0:13:72 len pd 0
rname 0:13:76 p loc 5
call 0:13:72 1
call 0:13:1 8
cstmt 0:13:1
prog 8
#end
