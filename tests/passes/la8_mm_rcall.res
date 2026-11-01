#sea 1
#target arm64-macos
#file la8_mm_rcall.sea
rpname 0:1:5 A 1
rname 0:1:9 ones pd 0
rint 0:1:14 2 #4000000000000000
rint 0:1:17 3 #4008000000000000
call 0:1:9 2
let 0:1:1 0
rpname 0:2:5 B 2
rname 0:2:9 ones pd 0
rint 0:2:14 3 #4008000000000000
rint 0:2:17 2 #4000000000000000
call 0:2:9 2
let 0:2:1 0
rpname 0:3:5 C 3
rname 0:3:9 A loc 1
rname 0:3:13 B loc 2
bin 0:3:9 matmul
let 0:3:1 0
rpname 0:4:5 y 4
rname 0:4:9 C loc 3
rname 0:4:13 ones pd 0
rint 0:4:18 2 #4000000000000000
call 0:4:13 1
bin 0:4:9 matmul
let 0:4:1 0
rpname 0:5:5 z 5
rname 0:5:9 ones pd 0
rint 0:5:14 2 #4000000000000000
call 0:5:9 1
rname 0:5:19 C loc 3
bin 0:5:9 matmul
let 0:5:1 0
rname 0:6:1 printf pd 0
str 0:6:8 %25g%20%25g%20%25g%0A
rname 0:6:22 C loc 3
rint 0:6:24 1 #3FF0000000000000
rint 0:6:27 1 #3FF0000000000000
index 0:6:22 2
rname 0:6:31 y loc 4
rint 0:6:33 0 #0000000000000000
index 0:6:31 1
rname 0:6:37 z loc 5
rint 0:6:39 1 #3FF0000000000000
index 0:6:37 1
call 0:6:1 4
cstmt 0:6:1
prog 6
#end
