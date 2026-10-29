#sea 1
#target arm64-macos
#file inl6_agg.sea
rtst 10 P 1 2
rtfd x 4
rtfd y 4
rtype 0:5:10 f64 s 0 4
param 0:5:7 x 0 0
rtype 0:5:18 P s 0 10
rname 0:6:19 x loc 1
init 0:6:16 x
rname 0:6:25 x loc 1
float 0:6:29 #4000000000000000
bin 0:6:25 mul
init 0:6:22 y
rslit 0:6:12 P 2 1
return 0:6:5 1
block 0:5:20 1
rfn 0:5:1 mk 2 1 1 2 10 4
rname 0:8:1 printf pd 0
str 0:8:8 %25g%20%25g%0A
rname 0:8:19 mk fn 2
float 0:8:22 #3FF8000000000000
call 0:8:19 1
dot 0:8:19 x
rname 0:8:30 mk fn 2
float 0:8:33 #4000000000000000
call 0:8:30 1
dot 0:8:30 y
call 0:8:1 3
cstmt 0:8:1
rtype 0:10:8 f64 s 0 4
field 0:10:5 x
rtype 0:11:8 f64 s 0 4
field 0:11:5 y
rst 0:9:1 P 2 1
prog 3
#end
