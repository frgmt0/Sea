#sea 1
#target arm64-macos
#file libL_bits.sea
rpname 0:1:5 id 1
rint 0:1:10 419385573 #41B8FF50E5000000
let 0:1:1 0
rpname 0:4:5 p 2
rname 0:4:9 bitand pd 0
rname 0:4:16 shr pd 0
rname 0:4:20 id loc 1
rint 0:4:24 8 #4020000000000000
call 0:4:16 2
rint 0:4:28 262143 #410FFFF800000000
call 0:4:9 2
let 0:4:1 0
rpname 0:5:5 a 3
rint 0:5:10 6 #4018000000000000
neg 0:5:9
let 0:5:1 0
rpname 0:6:5 n 4
rint 0:6:9 3 #4008000000000000
let 0:6:1 0
rpname 0:7:5 q 5
rname 0:7:9 bitor pd 0
rname 0:7:15 a loc 3
rint 0:7:18 1 #3FF0000000000000
call 0:7:9 2
rname 0:7:23 bitxor pd 0
rname 0:7:30 a loc 3
rname 0:7:33 n loc 4
call 0:7:23 2
bin 0:7:9 add
rname 0:7:38 bitnot pd 0
rname 0:7:45 a loc 3
call 0:7:38 1
bin 0:7:9 add
let 0:7:1 0
rpname 0:8:5 r 6
rname 0:8:9 shl pd 0
rname 0:8:13 a loc 3
rname 0:8:16 n loc 4
call 0:8:9 2
rname 0:8:21 sar pd 0
rname 0:8:25 a loc 3
rname 0:8:28 n loc 4
call 0:8:21 2
bin 0:8:9 add
rname 0:8:33 shr pd 0
rname 0:8:37 a loc 3
rint 0:8:40 60 #404E000000000000
call 0:8:33 2
bin 0:8:9 add
let 0:8:1 0
rname 0:9:1 printf pd 0
str 0:9:8 %25d%20%25d%20%25d%0A
rname 0:9:22 p loc 2
rname 0:9:25 q loc 5
rname 0:9:28 r loc 6
call 0:9:1 4
cstmt 0:9:1
prog 7
#end
