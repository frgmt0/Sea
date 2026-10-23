#sea 1
#target arm64-macos
#file res_noval_calltype.sea
rerr 0:2:11 229 0
rtype 0:1:10 f64 s 0 4
rname 0:1:16 f fn 2
call 0:1:16 0
rcn 0:1:1 A 1 1
rtype 0:2:11 Q s 0 0
rint 0:2:22 1 #3FF0000000000000
return 0:2:15 1
block 0:2:13 1
rfn 0:2:1 f 0 0 1 2 0
prog 2
#end
