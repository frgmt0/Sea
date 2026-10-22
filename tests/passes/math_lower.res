#sea 1
#target arm64-macos
#file math_lower.sea
rpname 0:3:5 x 1
float 0:3:9 #3FE0000000000000
let 0:3:1 0
rpname 0:4:5 y 2
float 0:4:9 #4000000000000000
let 0:4:1 0
rpname 0:5:5 n 3
rint 0:5:9 3 #4008000000000000
let 0:5:1 0
rpname 0:6:5 a 4
rname 0:6:9 log pd 0
rname 0:6:13 x loc 1
call 0:6:9 1
let 0:6:1 0
rpname 0:7:5 b 5
rname 0:7:9 exp pd 0
rname 0:7:13 x loc 1
call 0:7:9 1
let 0:7:1 0
rpname 0:8:5 c 6
rname 0:8:9 sin pd 0
rname 0:8:13 n loc 3
call 0:8:9 1
let 0:8:1 0
rpname 0:9:5 d 7
rname 0:9:9 cos pd 0
rname 0:9:13 x loc 1
call 0:9:9 1
let 0:9:1 0
rpname 0:10:5 e 8
rname 0:10:9 pow pd 0
rname 0:10:13 x loc 1
rname 0:10:16 y loc 2
call 0:10:9 2
let 0:10:1 0
rpname 0:11:5 h 9
rname 0:11:9 hypot pd 0
rname 0:11:15 x loc 1
float 0:11:18 #4010000000000000
call 0:11:9 2
let 0:11:1 0
rpname 0:12:5 p 10
rname 0:12:9 x loc 1
float 0:12:13 #3FE0000000000000
bin 0:12:9 pow
let 0:12:1 0
rpname 0:13:5 q 11
rname 0:13:9 x loc 1
rname 0:13:13 y loc 2
bin 0:13:9 pow
let 0:13:1 0
rpname 0:14:5 r 12
rname 0:14:9 log pd 0
float 0:14:13 #4000000000000000
call 0:14:9 1
rname 0:14:20 exp pd 0
rname 0:14:24 y loc 2
call 0:14:20 1
bin 0:14:9 add
let 0:14:1 0
rpname 0:15:5 s 13
rname 0:15:9 n loc 3
rint 0:15:17 3 #4008000000000000
conv 0:15:13 f64
bin 0:15:9 pow
let 0:15:1 0
prog 13
#end
