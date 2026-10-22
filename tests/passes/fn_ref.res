#sea 1
#target arm64-macos
#file fn_ref.sea
rtype 0:5:16 i64 s 0 3
param 0:5:9 s 1 0
rtype 0:5:24 i64 s 0 3
param 0:5:21 n 0 0
rint 0:6:14 0 #0000000000000000
rname 0:6:17 n loc 2
range 0:6:14 0 0
rname 0:7:9 s loc 1
rname 0:7:14 i loc 3
asg 0:7:9 add
block 0:6:19 1
rfor 0:6:5 i 0:6:9 3
block 0:5:29 1
rfn 0:5:1 bump 0 2 0 2 1 3 3
rtype 0:10:17 i64 s 0 3
param 0:10:10 s 1 0
rtype 0:10:25 i64 s 0 3
param 0:10:22 n 0 0
rint 0:11:14 0 #0000000000000000
rname 0:11:17 n loc 2
range 0:11:14 0 0
rname 0:12:9 bump fn 2
rname 0:12:18 s loc 1
ref 0:12:14
rname 0:12:21 i loc 3
call 0:12:9 2
cstmt 0:12:9
block 0:11:19 1
rfor 0:11:5 i 0:11:9 3
block 0:10:30 1
rfn 0:10:1 bump2 0 2 0 3 1 3 3
rpname 0:15:5 t 1
rint 0:15:9 0 #0000000000000000
var 0:15:1 0
rname 0:16:1 bump fn 2
rname 0:16:10 t loc 1
ref 0:16:6
rint 0:16:13 3 #4008000000000000
call 0:16:1 2
cstmt 0:16:1
rname 0:17:1 bump2 fn 3
rname 0:17:11 t loc 1
ref 0:17:7
rint 0:17:14 2 #4000000000000000
call 0:17:1 2
cstmt 0:17:1
rname 0:18:1 bump2 fn 3
rname 0:18:11 t loc 1
ref 0:18:7
rint 0:18:14 1 #3FF0000000000000
call 0:18:1 2
cstmt 0:18:1
prog 6
#end
