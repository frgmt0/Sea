#sea 1
#target arm64-macos
#file res_err_str_result.sea
rerr 0:3:17 259 1 strings
type 0:3:12 i64 s 0
type 0:3:17 str s 0
rint 0:4:13 1 #3FF0000000000000
rint 0:4:16 2 #4000000000000000
return 0:4:5 2
block 0:3:22 1
rfn 0:3:1 f 0 0 2 2 0
prog 1
#end
