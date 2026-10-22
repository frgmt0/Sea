#sea 1
#target arm64-macos
#file arr_rule30.sea
rtvec 10 4
rtype 0:2:12 f64 v 0 10
param 0:2:9 v 0 0
rname 0:3:14 v loc 1
block 0:3:16 0
rfor 0:3:5 x 0:3:9 2
rname 0:5:5 printf pd 0
str 0:5:12 walked%20%25d%0A
rname 0:5:27 len pd 0
rname 0:5:31 v loc 1
call 0:5:27 1
call 0:5:5 2
cstmt 0:5:5
block 0:2:19 2
rfn 0:2:1 walk 0 1 0 2 1 10
rname 0:7:1 walk fn 2
rname 0:7:6 ones pd 0
rint 0:7:11 3 #4008000000000000
call 0:7:6 1
call 0:7:1 1
cstmt 0:7:1
rname 0:8:1 walk fn 2
rname 0:8:6 zeros pd 0
rint 0:8:12 0 #0000000000000000
call 0:8:6 1
call 0:8:1 1
cstmt 0:8:1
prog 3
#end
