#sea 1
#target arm64-macos
#file res_str_consts.sea
str 0:3:11 ab
str 0:3:18 c
bin 0:3:11 add
rcns 0:3:1 A 0 1 abc
rname 0:4:11 A cst 1
str 0:4:15 %25
bin 0:4:11 add
rcns 0:4:1 B 0 2 abc%25
rtype 0:5:10 str s 0 5
str 0:5:16 x
rcns 0:5:1 T 1 3 x
rname 0:6:11 A cst 1
rname 0:6:15 B cst 2
bin 0:6:11 lt
rcnb 0:6:1 L 0 4 1
str 0:7:11 %C3%A9
str 0:7:24 z
bin 0:7:11 gt
rcnb 0:7:1 U 0 5 1
rname 0:8:1 printf pd 0
str 0:8:8 %25s%20%25s%20%25s%0A
rname 0:8:22 A cst 1
rname 0:8:25 B cst 2
rname 0:8:28 T cst 3
call 0:8:1 4
cstmt 0:8:1
rname 0:9:4 L cst 4
rname 0:9:9 U cst 5
bin 0:9:4 and
rname 0:10:5 printf pd 0
str 0:10:12 lt%0A
call 0:10:5 1
cstmt 0:10:5
block 0:9:11 1
if 0:9:1 0
prog 7
#end
