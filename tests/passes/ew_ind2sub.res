#sea 1
#target arm64-macos
#file ew_ind2sub.sea
rpname 0:1:5 k 1
rname 0:1:9 filled pd 0
rint 0:1:16 7 #401C000000000000
rint 0:1:19 2 #4000000000000000
call 0:1:9 2
var 0:1:1 0
rname 0:2:1 k loc 1
rint 0:2:3 1 #3FF0000000000000
index 0:2:1 1
rint 0:2:8 2 #4000000000000000
asg 0:2:1 set
rpname 0:3:6 i 2
rpname 0:3:9 j 3
ptuple 0:3:5 2
rname 0:3:14 ind2sub pd 0
rint 0:3:22 3 #4008000000000000
rname 0:3:25 k loc 1
call 0:3:14 2
let 0:3:1 0
rname 0:4:1 printf pd 0
str 0:4:8 %25d%20%25d%20%25d%20%25d%0A
rname 0:4:25 i loc 2
rint 0:4:27 0 #0000000000000000
index 0:4:25 1
rname 0:4:31 i loc 2
rint 0:4:33 1 #3FF0000000000000
index 0:4:31 1
rname 0:4:37 j loc 3
rint 0:4:39 0 #0000000000000000
index 0:4:37 1
rname 0:4:43 j loc 3
rint 0:4:45 1 #3FF0000000000000
index 0:4:43 1
call 0:4:1 5
cstmt 0:4:1
prog 4
#end
