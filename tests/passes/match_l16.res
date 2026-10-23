#sea 1
#target arm64-macos
#file match_l16.sea
rtype 0:1:11 i64 s 0 3
param 0:1:8 k 0 0
rtype 0:1:19 str s 0 5
rname 0:2:16 k loc 1
conv 0:2:12 str
return 0:2:5 1
block 0:1:23 1
rfn 0:1:1 tag 0 1 1 2 5 3
rtype 0:4:12 i64 s 0 3
param 0:4:9 n 0 0
rpname 0:5:9 i 2
rint 0:5:13 0 #0000000000000000
var 0:5:5 0
rname 0:6:11 i loc 2
rname 0:6:15 n loc 1
bin 0:6:11 lt
rname 0:7:15 tag fn 2
rname 0:7:19 i loc 2
call 0:7:15 1
str 0:8:13 2
str 0:8:19 9
break 0:8:28
block 0:8:26 1
arm 0:8:13 2
str 0:9:13 0
rname 0:9:22 printf pd 0
str 0:9:29 zero%0A
call 0:9:22 1
cstmt 0:9:22
block 0:9:20 1
arm 0:9:13 1
rname 0:10:20 printf pd 0
str 0:10:27 %25d%0A
rname 0:10:35 i loc 2
call 0:10:20 2
cstmt 0:10:20
block 0:10:18 1
arm 0:10:13 0
match 0:7:9 3
rname 0:12:9 i loc 2
rint 0:12:14 1 #3FF0000000000000
asg 0:12:9 add
block 0:6:17 2
while 0:6:5
rname 0:14:11 tag fn 2
rname 0:14:15 n loc 1
call 0:14:11 1
rname 0:15:16 printf pd 0
str 0:15:23 end%0A
call 0:15:16 1
cstmt 0:15:16
block 0:15:14 1
arm 0:15:9 0
match 0:14:5 1
block 0:4:17 3
rfn 0:4:1 scan 0 1 0 3 1 3
rname 0:18:1 scan fn 3
rint 0:18:6 5 #4014000000000000
call 0:18:1 1
cstmt 0:18:1
rname 0:19:1 scan fn 3
rint 0:19:6 1 #3FF0000000000000
call 0:19:1 1
cstmt 0:19:1
prog 4
#end
