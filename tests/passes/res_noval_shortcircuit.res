#sea 1
#target arm64-macos
#file res_noval_shortcircuit.sea
rerr 0:3:11 259 1 strings
rname 0:1:11 B cst 2
rint 0:1:16 #7FFFFFFFFFFFFFFF -
rint 0:1:38 1 #3FF0000000000000
bin 0:1:16 add
rint 0:1:42 0 #0000000000000000
bin 0:1:16 gt
bin 0:1:11 or
rcn 0:1:1 D 0 1
rtype 0:2:10 bool s 0 2
false 0:2:17
rname 0:2:26 f fn 2
call 0:2:26 0
float 0:2:33 #3FF0000000000000
bin 0:2:26 eq
bin 0:2:17 and
rcn 0:2:1 B 1 2
rtype 0:3:11 str s 0 0
rint 0:3:24 1 #3FF0000000000000
return 0:3:17 1
block 0:3:15 1
rfn 0:3:1 f 0 0 1 2 0
prog 3
#end
