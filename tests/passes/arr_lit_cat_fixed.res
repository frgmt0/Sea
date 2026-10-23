#sea 1
#target arm64-macos
#file arr_lit_cat_fixed.sea
rpname 0:1:5 a 1
float 0:1:10 #3FF8000000000000
float 0:1:15 #4004000000000000
row 0:1:10 2
array 0:1:9 1
let 0:1:1 0
rpname 0:2:5 v 2
rname 0:2:10 a loc 1
float 0:2:13 #4010000000000000
rname 0:2:18 a loc 1
row 0:2:10 3
array 0:2:9 1
let 0:2:1 0
rpname 0:3:5 m 3
float 0:3:10 #3FF0000000000000
float 0:3:15 #4000000000000000
row 0:3:10 2
float 0:3:20 #4008000000000000
float 0:3:25 #4010000000000000
row 0:3:20 2
array 0:3:9 2
let 0:3:1 0
rpname 0:4:5 W 4
rname 0:4:10 m loc 3
rname 0:4:13 m loc 3
row 0:4:10 2
array 0:4:9 1
let 0:4:1 0
rname 0:5:1 printf pd 0
str 0:5:8 %25g%20%25g%20%25d%20%25g%20%25d%0A
rname 0:5:28 v loc 2
rint 0:5:30 2 #4000000000000000
index 0:5:28 1
rname 0:5:34 v loc 2
rint 0:5:36 4 #4010000000000000
index 0:5:34 1
rname 0:5:40 len pd 0
rname 0:5:44 v loc 2
call 0:5:40 1
rname 0:5:48 W loc 4
rint 0:5:50 1 #3FF0000000000000
rint 0:5:53 3 #4008000000000000
index 0:5:48 2
rname 0:5:57 cols pd 0
rname 0:5:62 W loc 4
call 0:5:57 1
call 0:5:1 6
cstmt 0:5:1
prog 5
#end
