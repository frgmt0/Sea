#sea 1
#target arm64-macos
#file struct_cow2.sea
rtst 10 T 1 1
rtfd v 12
rtst 11 S 2 1
rtfd w 13
rtvec 12 4
rtvec 13 10
rtype 0:2:8 f64 v 0 12
field 0:2:5 v
rst 0:1:1 T 1 1
rtype 0:5:8 T v 0 13
field 0:5:5 w
rst 0:4:1 S 1 2
rpname 0:7:5 a 1
float 0:7:26 #3FF0000000000000
row 0:7:26 1
array 0:7:25 1
init 0:7:22 v
rslit 0:7:18 T 1 1
row 0:7:18 1
array 0:7:17 1
init 0:7:14 w
rslit 0:7:10 S 1 2
row 0:7:10 1
array 0:7:9 1
var 0:7:1 0
rpname 0:8:5 b 2
rname 0:8:9 a loc 1
let 0:8:1 0
rname 0:9:1 a loc 1
rint 0:9:3 0 #0000000000000000
index 0:9:1 1
dot 0:9:1 w
rint 0:9:8 0 #0000000000000000
index 0:9:1 1
dot 0:9:1 v
rint 0:9:13 0 #0000000000000000
index 0:9:1 1
float 0:9:18 #4022000000000000
asg 0:9:1 set
rname 0:10:1 printf pd 0
str 0:10:8 %25g%20%25g%0A
rname 0:10:19 b loc 2
rint 0:10:21 0 #0000000000000000
index 0:10:19 1
dot 0:10:19 w
rint 0:10:26 0 #0000000000000000
index 0:10:19 1
dot 0:10:19 v
rint 0:10:31 0 #0000000000000000
index 0:10:19 1
rname 0:10:35 a loc 1
rint 0:10:37 0 #0000000000000000
index 0:10:35 1
dot 0:10:35 w
rint 0:10:42 0 #0000000000000000
index 0:10:35 1
dot 0:10:35 v
rint 0:10:47 0 #0000000000000000
index 0:10:35 1
call 0:10:1 3
cstmt 0:10:1
prog 6
#end
