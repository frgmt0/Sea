#sea 1
#target arm64-macos
#file struct_l6_field.sea
rtst 10 G 1 1
rtfd v 11
rtvec 11 4
rtype 0:1:11 i64 s 0 3
false 0:1:23
block 0:1:29 0
while 0:1:17
rint 0:2:12 0 #0000000000000000
return 0:2:5 1
block 0:1:15 2
rfn 0:1:1 p 0 0 1 2 3
rtype 0:4:11 i64 s 0 3
false 0:4:23
block 0:4:29 0
while 0:4:17
rint 0:5:12 1 #3FF0000000000000
return 0:5:5 1
block 0:4:15 2
rfn 0:4:1 q 0 0 1 3 3
rpname 0:7:5 dims 1
rname 0:7:20 ones pd 0
rint 0:7:25 4 #4010000000000000
call 0:7:20 1
init 0:7:17 v
rslit 0:7:13 G 1 1
row 0:7:13 1
array 0:7:12 1
var 0:7:1 0
rname 0:8:1 dims loc 1
rname 0:8:6 p fn 2
call 0:8:6 0
index 0:8:1 1
dot 0:8:1 v
rname 0:8:13 q fn 3
call 0:8:13 0
rint 0:8:18 3 #4008000000000000
range 0:8:13 0 0
index 0:8:1 1
float 0:8:23 #0000000000000000
asg 0:8:1 set
rname 0:9:1 printf pd 0
str 0:9:8 %25g%20%25g%20%25d%20%25d%0A
rname 0:9:25 dims loc 1
rint 0:9:30 0 #0000000000000000
index 0:9:25 1
dot 0:9:25 v
rint 0:9:35 1 #3FF0000000000000
index 0:9:25 1
rname 0:9:39 dims loc 1
rint 0:9:44 0 #0000000000000000
index 0:9:39 1
dot 0:9:39 v
rint 0:9:49 3 #4008000000000000
index 0:9:39 1
rname 0:9:53 p fn 2
call 0:9:53 0
rname 0:9:58 q fn 3
call 0:9:58 0
call 0:9:1 5
cstmt 0:9:1
rtype 0:11:8 f64 v 0 11
field 0:11:5 v
rst 0:10:1 G 1 1
prog 6
#end
