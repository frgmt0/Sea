#sea 1
#target arm64-macos
#file json6_matstruct.sea
rtst 10 Q 1 2
rtfd a 4
rtfd b 5
rtmat 11 10
rtype 0:6:8 f64 s 0 4
field 0:6:5 a
rtype 0:7:8 str s 0 5
field 0:7:5 b
rst 0:5:1 Q 2 1
rpname 0:9:5 qm 1
rtype 0:9:9 Q m 0 11
array 0:9:16 0
let 0:9:1 1
rname 0:10:1 write_json pd 0
str 0:10:12 qm.json
rname 0:10:23 qm loc 1
call 0:10:1 2
cstmt 0:10:1
rname 0:11:1 printf pd 0
str 0:11:8 done%0A
call 0:11:1 1
cstmt 0:11:1
prog 4
#end
