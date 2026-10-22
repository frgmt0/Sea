#sea 1
#target arm64-macos
#file fn_printf.sea
rpname 0:5:5 n 1
rint 0:5:9 42 #4045000000000000
let 0:5:1 0
rpname 0:6:5 x 2
rname 0:6:13 n loc 1
conv 0:6:9 f64
float 0:6:18 #4020000000000000
bin 0:6:9 div
let 0:6:1 0
rname 0:7:1 printf pd 0
str 0:7:8 n=%255d%20x=%25-8.3f%20%25s|%25%25%0A
rname 0:7:34 n loc 1
rname 0:7:37 x loc 2
str 0:7:40 ok
call 0:7:1 4
cstmt 0:7:1
rpname 0:8:5 t 3
rname 0:8:9 now pd 0
call 0:8:9 0
let 0:8:1 0
rname 0:9:1 printf pd 0
str 0:9:8 %25+e%20%25d%0A
rname 0:9:20 x loc 2
rname 0:9:27 x loc 2
float 0:9:31 #4020000000000000
bin 0:9:27 mul
conv 0:9:23 i64
call 0:9:1 3
cstmt 0:9:1
rname 0:10:1 printf pd 0
str 0:10:8 done%0A
call 0:10:1 1
cstmt 0:10:1
prog 6
#end
