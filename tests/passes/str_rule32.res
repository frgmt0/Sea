#sea 1
#target arm64-macos
#file str_rule32.sea
rtype 0:1:12 str s 0 5
param 0:1:9 a 0 0
rtype 0:1:20 str s 0 5
param 0:1:17 b 0 0
false 0:1:33
block 0:1:39 0
while 0:1:27
rname 0:2:8 a loc 1
rname 0:2:12 b loc 2
bin 0:2:8 lt
rname 0:3:9 printf pd 0
str 0:3:16 lt%0A
call 0:3:9 1
cstmt 0:3:9
block 0:2:14 1
rname 0:5:9 printf pd 0
str 0:5:16 ge%0A
call 0:5:9 1
cstmt 0:5:9
block 0:4:12 1
if 0:2:5 1
rname 0:7:5 printf pd 0
str 0:7:12 %25s%20%25d%20%25s%0A
rname 0:7:26 lower pd 0
rname 0:7:32 a loc 1
call 0:7:26 1
rname 0:7:36 len pd 0
rname 0:7:40 a loc 1
call 0:7:36 1
rname 0:7:48 a loc 1
rname 0:7:52 b loc 2
bin 0:7:48 lt
conv 0:7:44 str
call 0:7:5 4
cstmt 0:7:5
block 0:1:25 3
rfn 0:1:1 less 0 2 0 2 1 5 5
rname 0:9:1 less fn 2
str 0:9:6 ab
str 0:9:12 b
call 0:9:1 2
cstmt 0:9:1
rname 0:10:1 less fn 2
str 0:10:6 b
str 0:10:11 ab
call 0:10:1 2
cstmt 0:10:1
rname 0:11:1 less fn 2
str 0:11:6 Ab
str 0:11:12 a
call 0:11:1 2
cstmt 0:11:1
prog 4
#end
