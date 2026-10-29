#sea 1
#target arm64-macos
#file json6_struct.sea
rtst 10 P 1 6
rtfd x 4
rtfd n 3
rtfd ok 2
rtfd name 5
rtfd w 11
rtfd m 12
rtfvec 11 4 3
rtmat 12 4
rtype 0:5:8 f64 s 0 4
field 0:5:5 x
rtype 0:6:8 i64 s 0 3
field 0:6:5 n
rtype 0:7:9 bool s 0 2
field 0:7:5 ok
rtype 0:8:11 str s 0 5
field 0:8:5 name
rint 0:9:12 3 #4008000000000000
rtype 0:9:8 f64 fv 1 11
field 0:9:5 w
rtype 0:10:8 f64 m 0 12
field 0:10:5 m
rst 0:4:1 P 6 1
rpname 0:12:5 p 1
float 0:12:16 #3FF8000000000000
init 0:12:13 x
rint 0:12:24 7 #401C000000000000
init 0:12:21 n
true 0:12:31
init 0:12:27 ok
str 0:12:43 a
init 0:12:37 name
float 0:12:52 #3FF0000000000000
float 0:12:57 #4000000000000000
float 0:12:62 #4008000000000000
row 0:12:52 3
array 0:12:51 1
init 0:12:48 w
rname 0:12:71 zeros pd 0
rint 0:12:77 2 #4000000000000000
rint 0:12:80 2 #4000000000000000
call 0:12:71 2
init 0:12:68 m
rslit 0:12:9 P 6 1
let 0:12:1 0
rname 0:13:1 write_json pd 0
str 0:13:12 p.json
rname 0:13:22 p loc 1
call 0:13:1 2
cstmt 0:13:1
rname 0:14:1 printf pd 0
str 0:14:8 done%0A
call 0:14:1 1
cstmt 0:14:1
prog 4
#end
