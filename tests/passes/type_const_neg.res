#sea 1
#target arm64-macos
#file type_const_neg.sea
rint 0:3:12 #000000003B9ACA00 #41CDCD6500000000
neg 0:3:11
rcni 0:3:1 N 0 1 #FFFFFFFFC4653600
rint 0:4:12 999999999 #41CDCD64FF800000
neg 0:4:11
rcni 0:4:1 P 0 2 -999999999
rint 0:5:12 #8000000000000000 #C3E0000000000000
neg 0:5:11
rcni 0:5:1 M 0 3 #8000000000000000
rpname 0:6:5 a 1
rname 0:6:9 N cst 1
let 0:6:1 0
rpname 0:7:5 b 2
rname 0:7:9 P cst 2
let 0:7:1 0
rpname 0:8:5 c 3
rname 0:8:9 M cst 3
rint 0:8:13 1 #3FF0000000000000
bin 0:8:9 add
let 0:8:1 0
rname 0:9:1 printf pd 0
str 0:9:8 %25d%20%25d%20%25d%0A
rname 0:9:22 a loc 1
rname 0:9:25 b loc 2
rname 0:9:28 c loc 3
call 0:9:1 4
cstmt 0:9:1
prog 7
#end
