#sea 1
#target arm64-macos
#file sel_ref_store.sea
rtvec 10 4
rtype 0:1:17 f64 v 0 10
param 0:1:10 v 1 0
rtype 0:1:27 i64 s 0 3
param 0:1:24 k 0 0
rint 0:2:14 0 #0000000000000000
rname 0:2:17 k loc 2
range 0:2:14 0 0
rname 0:3:9 v loc 1
rname 0:3:11 i loc 3
rint 0:3:14 3 #4008000000000000
range 0:3:11 0 0
index 0:3:9 1
float 0:3:19 #401C000000000000
asg 0:3:9 set
block 0:2:19 1
rfor 0:2:5 i 0:2:9 3
block 0:1:32 1
rfn 0:1:1 setto 0 2 0 2 1 10 3
rpname 0:6:5 a 1
rname 0:6:9 zeros pd 0
rint 0:6:15 4 #4010000000000000
call 0:6:9 1
var 0:6:1 0
rname 0:7:1 setto fn 2
rname 0:7:11 a loc 1
ref 0:7:7
rint 0:7:14 2 #4000000000000000
call 0:7:1 2
cstmt 0:7:1
rname 0:8:1 setto fn 2
rname 0:8:11 a loc 1
ref 0:8:7
rint 0:8:14 0 #0000000000000000
call 0:8:1 2
cstmt 0:8:1
rname 0:9:1 printf pd 0
str 0:9:8 %25g%20%25g%20%25g%20%25g%0A
rname 0:9:25 a loc 1
rint 0:9:27 0 #0000000000000000
index 0:9:25 1
rname 0:9:31 a loc 1
rint 0:9:33 1 #3FF0000000000000
index 0:9:31 1
rname 0:9:37 a loc 1
rint 0:9:39 2 #4000000000000000
index 0:9:37 1
rname 0:9:43 a loc 1
rint 0:9:45 3 #4008000000000000
index 0:9:43 1
call 0:9:1 5
cstmt 0:9:1
prog 5
#end
