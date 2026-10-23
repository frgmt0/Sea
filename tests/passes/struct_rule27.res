#sea 1
#target arm64-macos
#file struct_rule27.sea
rtst 10 P 1 2
rtfd x 4
rtfd n 3
rpname 0:1:5 p 1
float 0:1:16 #3FF8000000000000
init 0:1:13 x
rint 0:1:24 3 #4008000000000000
init 0:1:21 n
rslit 0:1:9 P 2 1
let 0:1:1 0
rpname 0:2:5 y 2
rname 0:2:9 p loc 1
dot 0:2:9 x
let 0:2:1 0
rname 0:3:1 printf pd 0
str 0:3:8 %25g%20%25d%0A
rname 0:3:19 y loc 2
rname 0:3:22 p loc 1
dot 0:3:22 n
call 0:3:1 3
cstmt 0:3:1
rtype 0:5:8 f64 s 0 4
field 0:5:5 x
rtype 0:6:8 i64 s 0 3
field 0:6:5 n
rst 0:4:1 P 2 1
prog 4
#end
