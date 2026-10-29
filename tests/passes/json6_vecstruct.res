#sea 1
#target arm64-macos
#file json6_vecstruct.sea
rtst 10 P 1 6
rtfd x 4
rtfd n 3
rtfd ok 2
rtfd s 5
rtfd v 11
rtfd m 12
rtvec 11 4
rtmat 12 4
rtvec 13 10
rtype 0:6:8 f64 s 0 4
field 0:6:5 x
rtype 0:7:8 i64 s 0 3
field 0:7:5 n
rtype 0:8:9 bool s 0 2
field 0:8:5 ok
rtype 0:9:8 str s 0 5
field 0:9:5 s
rtype 0:10:8 f64 v 0 11
field 0:10:5 v
rtype 0:11:8 f64 m 0 12
field 0:11:5 m
rst 0:5:1 P 6 1
rpname 0:13:5 ps 1
rtype 0:13:9 P v 0 13
array 0:13:15 0
let 0:13:1 1
rname 0:14:1 write_json pd 0
str 0:14:12 ps.json
rname 0:14:23 ps loc 1
call 0:14:1 2
cstmt 0:14:1
rname 0:15:1 printf pd 0
str 0:15:8 done%0A
call 0:15:1 1
cstmt 0:15:1
prog 4
#end
