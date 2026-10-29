#sea 1
#target arm64-macos
#file inl6_seq_named.sea
rtvec 10 2
rtype 0:5:12 bool v 0 10
param 0:5:9 a 0 0
rtype 0:5:23 bool v 0 10
param 0:5:20 b 0 0
rtype 0:5:34 bool v 0 10
false 0:5:49
block 0:5:55 0
while 0:5:43
rname 0:6:5 printf pd 0
str 0:6:12 pick%20%25d%20%25d%0A
rname 0:6:28 len pd 0
rname 0:6:32 a loc 1
call 0:6:28 1
rname 0:6:36 len pd 0
rname 0:6:40 b loc 2
call 0:6:36 1
call 0:6:5 3
cstmt 0:6:5
rname 0:7:12 a loc 1
return 0:7:5 1
block 0:5:41 3
rfn 0:5:1 pick 0 2 1 2 10 10 10
rpname 0:9:5 v 1
rname 0:9:9 filled pd 0
float 0:9:16 #3FF0000000000000
rint 0:9:21 3 #4008000000000000
call 0:9:9 2
var 0:9:1 0
rpname 0:10:5 m1 2
rname 0:10:10 filled pd 0
true 0:10:17
rint 0:10:23 3 #4008000000000000
call 0:10:10 2
let 0:10:1 0
rpname 0:11:5 m2 3
rname 0:11:10 filled pd 0
false 0:11:17
rint 0:11:24 2 #4000000000000000
call 0:11:10 2
let 0:11:1 0
rname 0:12:1 v loc 1
rname 0:12:3 pick fn 2
rname 0:12:11 m2 loc 3
narg 0:12:8 b
rname 0:12:18 m1 loc 2
narg 0:12:15 a
call 0:12:3 2
index 0:12:1 1
float 0:12:25 #0000000000000000
asg 0:12:1 set
rpname 0:13:5 w 4
rname 0:13:9 pick fn 2
rname 0:13:14 m2 loc 3
rname 0:13:18 m1 loc 2
call 0:13:9 2
let 0:13:1 0
rname 0:14:1 printf pd 0
str 0:14:8 %25g%20%25g%20%25g%20%25d%0A
rname 0:14:25 v loc 1
rint 0:14:27 0 #0000000000000000
index 0:14:25 1
rname 0:14:31 v loc 1
rint 0:14:33 1 #3FF0000000000000
index 0:14:31 1
rname 0:14:37 v loc 1
rint 0:14:39 2 #4000000000000000
index 0:14:37 1
rname 0:14:43 len pd 0
rname 0:14:47 w loc 4
call 0:14:43 1
call 0:14:1 5
cstmt 0:14:1
prog 7
#end
