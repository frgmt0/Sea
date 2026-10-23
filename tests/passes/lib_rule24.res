#sea 1
#target arm64-macos
#file lib_rule24.sea
rtvec 10 4
rtype 0:1:11 f64 v 0 10
param 0:1:8 c 0 0
rtype 0:1:21 i64 s 0 3
rpname 0:8:9 r 2
rname 0:8:13 argsort pd 0
rname 0:8:21 c loc 1
true 0:8:30
narg 0:8:24 desc
call 0:8:13 2
let 0:8:5 0
rname 0:9:12 r loc 2
rint 0:9:14 0 #0000000000000000
index 0:9:12 1
return 0:9:5 1
block 0:1:25 2
rfn 0:1:1 top 0 1 1 2 3 10
rname 0:11:1 printf pd 0
str 0:11:8 %25d%0A
rname 0:11:16 top fn 2
rname 0:11:20 ones pd 0
rint 0:11:25 3 #4008000000000000
call 0:11:20 1
call 0:11:16 1
call 0:11:1 2
cstmt 0:11:1
rname 0:12:1 printf pd 0
str 0:12:8 %25d%0A
rname 0:12:16 top fn 2
rname 0:12:20 zeros pd 0
rint 0:12:26 2 #4000000000000000
call 0:12:20 1
call 0:12:16 1
call 0:12:1 2
cstmt 0:12:1
prog 3
#end
