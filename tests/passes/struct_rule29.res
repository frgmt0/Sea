#sea 1
#target arm64-macos
#file struct_rule29.sea
rtst 10 Dim 1 6
rtfd name 5
rtfd nom 4
rtfd tol 4
rtfd dist 5
rtfd sign 3
rtfd alpha 4
rtvec 11 10
rtype 0:1:15 Dim v 0 11
param 0:1:9 dims 0 0
false 0:1:30
block 0:1:36 0
while 0:1:24
rpname 0:2:9 nom 2
rname 0:2:15 dims loc 1
dot 0:2:15 nom
let 0:2:5 0
rpname 0:3:9 names 3
rname 0:3:17 dims loc 1
dot 0:3:17 name
let 0:3:5 0
rname 0:4:5 printf pd 0
str 0:4:12 %25s%20%25g%20%25s%20%25g%0A
rname 0:4:29 names loc 3
rint 0:4:35 0 #0000000000000000
index 0:4:29 1
rname 0:4:39 nom loc 2
rint 0:4:43 0 #0000000000000000
index 0:4:39 1
rname 0:4:47 names loc 3
rint 0:4:53 1 #3FF0000000000000
index 0:4:47 1
rname 0:4:57 nom loc 2
rint 0:4:61 1 #3FF0000000000000
index 0:4:57 1
call 0:4:5 5
cstmt 0:4:5
block 0:1:22 4
rfn 0:1:1 show 0 1 0 2 1 11
rpname 0:6:5 d 1
str 0:6:21 a
init 0:6:15 name
float 0:6:31 #3FF8000000000000
init 0:6:26 nom
float 0:6:41 #3FE0000000000000
init 0:6:36 tol
str 0:6:52 n
init 0:6:46 dist
rint 0:6:63 1 #3FF0000000000000
init 0:6:57 sign
float 0:6:73 #0000000000000000
init 0:6:66 alpha
rslit 0:6:9 Dim 6 1
let 0:6:1 0
rpname 0:7:5 dims 2
rname 0:7:12 filled pd 0
rname 0:7:19 d loc 1
rint 0:7:22 2 #4000000000000000
call 0:7:12 2
let 0:7:1 0
rname 0:8:1 show fn 2
rname 0:8:6 dims loc 2
call 0:8:1 1
cstmt 0:8:1
rname 0:9:1 show fn 2
rname 0:9:6 dims loc 2
call 0:9:1 1
cstmt 0:9:1
rtype 0:11:11 str s 0 5
field 0:11:5 name
rtype 0:12:10 f64 s 0 4
field 0:12:5 nom
rtype 0:13:10 f64 s 0 4
field 0:13:5 tol
rtype 0:14:11 str s 0 5
field 0:14:5 dist
rtype 0:15:11 i64 s 0 3
field 0:15:5 sign
rtype 0:16:12 f64 s 0 4
field 0:16:5 alpha
rst 0:10:1 Dim 6 1
prog 6
#end
