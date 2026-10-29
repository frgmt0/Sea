#sea 1
#target arm64-macos
#file res_rt.sea
rtst 10 P 1 1
rtfd v 11
rtfvec 11 4 2
rtvec 12 10
rint 0:1:11 2 #4000000000000000
rcni 0:1:1 N 0 1 2
rname 0:3:12 N cst 1
rtype 0:3:8 f64 fv 1 11
field 0:3:5 v
rst 0:2:1 P 1 1
rtype 0:5:14 P v 0 12
param 0:5:10 ps 0 0
rtype 0:5:22 f64 s 0 4
rname 0:6:12 ps loc 1
rint 0:6:15 0 #0000000000000000
index 0:6:12 1
dot 0:6:12 v
rint 0:6:20 0 #0000000000000000
index 0:6:12 1
return 0:6:5 1
block 0:5:26 1
rfn 0:5:1 first 2 1 1 2 4 12
rpname 0:8:5 a 1
float 0:8:18 #3FF8000000000000
float 0:8:23 #4004000000000000
row 0:8:18 2
array 0:8:17 1
init 0:8:14 v
rslit 0:8:10 P 1 1
row 0:8:10 1
array 0:8:9 1
let 0:8:1 0
rname 0:9:1 printf pd 0
str 0:9:8 %25g%0A
rname 0:9:16 first fn 2
rname 0:9:22 a loc 1
call 0:9:16 1
call 0:9:1 2
cstmt 0:9:1
prog 5
#end
