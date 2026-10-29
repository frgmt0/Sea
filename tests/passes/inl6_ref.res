#sea 1
#target arm64-macos
#file inl6_ref.sea
rtype 0:5:15 i64 s 0 3
param 0:5:8 c 1 0
rtype 0:5:23 i64 s 0 3
param 0:5:20 d 0 0
rtype 0:5:31 i64 s 0 3
rname 0:6:5 c loc 1
rname 0:6:10 d loc 2
asg 0:6:5 add
rname 0:7:12 c loc 1
return 0:7:5 1
block 0:5:35 2
rfn 0:5:1 inc 2 2 1 2 3 3 3
rpname 0:9:5 n 1
rint 0:9:9 1 #3FF0000000000000
var 0:9:1 0
rpname 0:10:5 m 2
rname 0:10:9 n loc 1
rname 0:10:13 inc fn 2
rname 0:10:21 n loc 1
ref 0:10:17
rint 0:10:24 10 #4024000000000000
call 0:10:13 2
bin 0:10:9 add
let 0:10:1 0
rname 0:11:1 inc fn 2
rname 0:11:9 n loc 1
ref 0:11:5
rint 0:11:12 100 #4059000000000000
call 0:11:1 2
cstmt 0:11:1
rname 0:12:1 printf pd 0
str 0:12:8 %25d%20%25d%0A
rname 0:12:19 n loc 1
rname 0:12:22 m loc 2
call 0:12:1 3
cstmt 0:12:1
prog 5
#end
