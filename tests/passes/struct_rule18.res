#sea 1
#target arm64-macos
#file struct_rule18.sea
rtst 10 Dim 1 6
rtfd name 5
rtfd nom 4
rtfd tol 4
rtfd dist 5
rtfd sign 3
rtfd alpha 4
rtvec 11 10
rtype 0:1:16 Dim v 0 11
param 0:1:10 dims 0 0
rtype 0:1:26 i64 s 0 3
param 0:1:23 d 0 0
rtype 0:1:34 f64 s 0 4
rname 0:9:12 dims loc 1
rname 0:9:17 d loc 2
index 0:9:12 1
dot 0:9:12 nom
return 0:9:5 1
block 0:1:38 1
rfn 0:1:1 nomOf 0 2 1 2 4 11 3
rpname 0:11:5 dims 1
str 0:11:25 a
init 0:11:19 name
float 0:11:35 #3FF8000000000000
init 0:11:30 nom
float 0:11:45 #3FE0000000000000
init 0:11:40 tol
str 0:11:56 n
init 0:11:50 dist
rint 0:11:67 1 #3FF0000000000000
init 0:11:61 sign
float 0:11:77 #0000000000000000
init 0:11:70 alpha
rslit 0:11:13 Dim 6 1
str 0:11:96 b
init 0:11:90 name
float 0:11:106 #4004000000000000
init 0:11:101 nom
float 0:11:116 #3FD0000000000000
init 0:11:111 tol
str 0:11:128 u
init 0:11:122 dist
rint 0:11:139 2 #4000000000000000
init 0:11:133 sign
float 0:11:149 #0000000000000000
init 0:11:142 alpha
rslit 0:11:84 Dim 6 1
row 0:11:13 2
array 0:11:12 1
let 0:11:1 0
rname 0:12:1 printf pd 0
str 0:12:8 %25g%20%25g%0A
rname 0:12:19 nomOf fn 2
rname 0:12:25 dims loc 1
rint 0:12:31 0 #0000000000000000
call 0:12:19 2
rname 0:12:35 nomOf fn 2
rname 0:12:41 dims loc 1
rint 0:12:47 1 #3FF0000000000000
call 0:12:35 2
call 0:12:1 3
cstmt 0:12:1
rtype 0:14:11 str s 0 5
field 0:14:5 name
rtype 0:15:10 f64 s 0 4
field 0:15:5 nom
rtype 0:16:10 f64 s 0 4
field 0:16:5 tol
rtype 0:17:11 str s 0 5
field 0:17:5 dist
rtype 0:18:11 i64 s 0 3
field 0:18:5 sign
rtype 0:19:12 f64 s 0 4
field 0:19:5 alpha
rst 0:13:1 Dim 6 1
prog 4
#end
