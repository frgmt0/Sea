#sea 1
#target arm64-macos
#file res6_class.sea
rtype 0:5:20 f64 s 0 4
param 0:5:17 x 0 0
rtype 0:5:28 f64 s 0 4
rname 0:6:12 x loc 1
rname 0:6:16 x loc 1
bin 0:6:12 mul
return 0:6:5 1
block 0:5:32 1
rfn 0:5:1 sq 1 1 1 2 4 4
rtype 0:8:12 i64 s 0 3
param 0:8:9 k 0 0
rtype 0:8:20 i64 s 0 3
rpname 0:9:9 s 2
rint 0:9:13 0 #0000000000000000
var 0:9:5 0
rint 0:10:14 0 #0000000000000000
rname 0:10:17 k loc 1
range 0:10:14 0 0
rname 0:11:9 s loc 2
rname 0:11:14 i loc 3
asg 0:11:9 add
block 0:10:19 1
rfor 0:10:5 i 0:10:9 3
rname 0:13:12 s loc 2
return 0:13:5 1
block 0:8:24 3
rfn 0:8:1 once 2 1 1 3 3 3
rtype 0:15:13 i64 s 0 3
param 0:15:10 k 0 0
rtype 0:15:21 i64 s 0 3
rpname 0:16:9 s 2
rint 0:16:13 0 #0000000000000000
var 0:16:5 0
rname 0:17:11 s loc 2
rname 0:17:15 k loc 1
bin 0:17:11 lt
rname 0:18:9 s loc 2
rint 0:18:14 1 #3FF0000000000000
asg 0:18:9 add
block 0:17:17 1
while 0:17:5
rname 0:20:12 s loc 2
return 0:20:5 1
block 0:15:25 3
rfn 0:15:1 twice 0 1 1 4 3 3
rtype 0:22:19 i64 s 0 3
rname 0:23:12 twice fn 4
rint 0:23:18 1 #3FF0000000000000
call 0:23:12 1
return 0:23:5 1
block 0:22:23 1
rfn 0:22:1 unreached 2 0 1 5 3
rtype 0:25:12 i64 s 0 3
param 0:25:9 n 0 0
rtype 0:25:20 bool s 0 2
rname 0:26:8 n loc 1
rint 0:26:13 0 #0000000000000000
bin 0:26:8 eq
true 0:27:16
return 0:27:9 1
block 0:26:15 1
if 0:26:5 0
rname 0:29:12 odd fn 7
rname 0:29:16 n loc 1
rint 0:29:20 1 #3FF0000000000000
bin 0:29:16 sub
call 0:29:12 1
return 0:29:5 1
block 0:25:25 2
rfn 0:25:1 even 0 1 1 6 2 3
rtype 0:31:11 i64 s 0 3
param 0:31:8 n 0 0
rtype 0:31:19 bool s 0 2
rname 0:32:8 n loc 1
rint 0:32:13 0 #0000000000000000
bin 0:32:8 eq
false 0:33:16
return 0:33:9 1
block 0:32:15 1
if 0:32:5 0
rname 0:35:12 even fn 6
rname 0:35:17 n loc 1
rint 0:35:21 1 #3FF0000000000000
bin 0:35:17 sub
call 0:35:12 1
return 0:35:5 1
block 0:31:24 2
rfn 0:31:1 odd 0 1 1 7 2 3
rtype 0:37:11 i64 s 0 3
param 0:37:8 k 0 0
rtype 0:37:19 i64 s 0 3
rpname 0:38:9 s 2
rname 0:38:13 k loc 1
var 0:38:5 0
rname 0:39:8 s loc 2
rint 0:39:12 0 #0000000000000000
bin 0:39:8 gt
rname 0:40:9 s loc 2
rint 0:40:14 1 #3FF0000000000000
asg 0:40:9 add
block 0:39:14 1
rname 0:41:15 s loc 2
rint 0:41:19 0 #0000000000000000
bin 0:41:15 lt
rname 0:42:9 s loc 2
rint 0:42:14 1 #3FF0000000000000
asg 0:42:9 sub
block 0:41:21 1
rname 0:44:9 s loc 2
rint 0:44:13 1 #3FF0000000000000
asg 0:44:9 set
block 0:43:12 1
if 0:41:12 1
if 0:39:5 1
rname 0:47:9 s loc 2
rint 0:47:14 2 #4000000000000000
asg 0:47:9 add
block 0:46:5 1
rname 0:49:5 s loc 2
rint 0:49:10 1 #3FF0000000000000
asg 0:49:5 add
rname 0:50:5 s loc 2
rint 0:50:10 1 #3FF0000000000000
asg 0:50:5 add
rname 0:51:5 s loc 2
rint 0:51:10 1 #3FF0000000000000
asg 0:51:5 add
rname 0:52:5 s loc 2
rint 0:52:10 1 #3FF0000000000000
asg 0:52:5 add
rname 0:53:5 s loc 2
rint 0:53:10 1 #3FF0000000000000
asg 0:53:5 add
rname 0:54:5 s loc 2
rint 0:54:10 1 #3FF0000000000000
asg 0:54:5 add
rname 0:55:5 s loc 2
rint 0:55:10 1 #3FF0000000000000
asg 0:55:5 add
rname 0:56:5 s loc 2
rint 0:56:10 1 #3FF0000000000000
asg 0:56:5 add
rname 0:57:5 s loc 2
rint 0:57:10 1 #3FF0000000000000
asg 0:57:5 add
rname 0:58:5 s loc 2
rint 0:58:10 1 #3FF0000000000000
asg 0:58:5 add
rname 0:59:5 s loc 2
rint 0:59:10 1 #3FF0000000000000
asg 0:59:5 add
rname 0:60:5 s loc 2
rint 0:60:10 1 #3FF0000000000000
asg 0:60:5 add
rname 0:61:5 s loc 2
rint 0:61:10 1 #3FF0000000000000
asg 0:61:5 add
rname 0:62:5 s loc 2
rint 0:62:10 1 #3FF0000000000000
asg 0:62:5 add
rname 0:63:5 s loc 2
rint 0:63:10 1 #3FF0000000000000
asg 0:63:5 add
rname 0:64:5 s loc 2
rint 0:64:10 1 #3FF0000000000000
asg 0:64:5 add
rname 0:65:5 s loc 2
rint 0:65:10 1 #3FF0000000000000
asg 0:65:5 add
rname 0:66:5 s loc 2
rint 0:66:10 1 #3FF0000000000000
asg 0:66:5 add
rname 0:67:5 s loc 2
rint 0:67:10 1 #3FF0000000000000
asg 0:67:5 add
rname 0:68:5 s loc 2
rint 0:68:10 1 #3FF0000000000000
asg 0:68:5 add
rname 0:69:5 s loc 2
rint 0:69:10 1 #3FF0000000000000
asg 0:69:5 add
rname 0:70:5 s loc 2
rint 0:70:10 1 #3FF0000000000000
asg 0:70:5 add
rname 0:71:5 s loc 2
rint 0:71:10 1 #3FF0000000000000
asg 0:71:5 add
rname 0:72:5 s loc 2
rint 0:72:10 1 #3FF0000000000000
asg 0:72:5 add
rname 0:73:5 s loc 2
rint 0:73:10 1 #3FF0000000000000
asg 0:73:5 add
rname 0:74:5 s loc 2
rint 0:74:10 1 #3FF0000000000000
asg 0:74:5 add
rname 0:75:5 s loc 2
rint 0:75:10 1 #3FF0000000000000
asg 0:75:5 add
rname 0:76:5 s loc 2
rint 0:76:10 1 #3FF0000000000000
asg 0:76:5 add
rname 0:77:5 s loc 2
rint 0:77:10 1 #3FF0000000000000
asg 0:77:5 add
rname 0:78:5 s loc 2
rint 0:78:10 1 #3FF0000000000000
asg 0:78:5 add
rname 0:79:5 s loc 2
rint 0:79:10 1 #3FF0000000000000
asg 0:79:5 add
rname 0:80:5 s loc 2
rint 0:80:10 1 #3FF0000000000000
asg 0:80:5 add
rname 0:81:5 s loc 2
rint 0:81:10 1 #3FF0000000000000
asg 0:81:5 add
rname 0:82:5 s loc 2
rint 0:82:10 1 #3FF0000000000000
asg 0:82:5 add
rname 0:83:5 s loc 2
rint 0:83:10 1 #3FF0000000000000
asg 0:83:5 add
rname 0:84:5 s loc 2
rint 0:84:10 1 #3FF0000000000000
asg 0:84:5 add
rname 0:85:5 s loc 2
rint 0:85:10 1 #3FF0000000000000
asg 0:85:5 add
rname 0:86:5 s loc 2
rint 0:86:10 1 #3FF0000000000000
asg 0:86:5 add
rname 0:87:5 s loc 2
rint 0:87:10 1 #3FF0000000000000
asg 0:87:5 add
rname 0:88:5 s loc 2
rint 0:88:10 1 #3FF0000000000000
asg 0:88:5 add
rname 0:89:5 s loc 2
rint 0:89:10 1 #3FF0000000000000
asg 0:89:5 add
rname 0:90:5 s loc 2
rint 0:90:10 1 #3FF0000000000000
asg 0:90:5 add
rname 0:91:12 s loc 2
return 0:91:5 1
block 0:37:23 46
rfn 0:37:1 s50 2 1 1 8 3 3
rtype 0:93:11 i64 s 0 3
param 0:93:8 k 0 0
rtype 0:93:19 i64 s 0 3
rpname 0:94:9 s 2
rname 0:94:13 k loc 1
var 0:94:5 0
rname 0:95:8 s loc 2
rint 0:95:12 0 #0000000000000000
bin 0:95:8 gt
rname 0:96:9 s loc 2
rint 0:96:14 1 #3FF0000000000000
asg 0:96:9 add
block 0:95:14 1
rname 0:97:15 s loc 2
rint 0:97:19 0 #0000000000000000
bin 0:97:15 lt
rname 0:98:9 s loc 2
rint 0:98:14 1 #3FF0000000000000
asg 0:98:9 sub
block 0:97:21 1
rname 0:100:9 s loc 2
rint 0:100:13 1 #3FF0000000000000
asg 0:100:9 set
block 0:99:12 1
if 0:97:12 1
if 0:95:5 1
rname 0:103:9 s loc 2
rint 0:103:14 2 #4000000000000000
asg 0:103:9 add
block 0:102:5 1
rname 0:105:5 s loc 2
rint 0:105:10 1 #3FF0000000000000
asg 0:105:5 add
rname 0:106:5 s loc 2
rint 0:106:10 1 #3FF0000000000000
asg 0:106:5 add
rname 0:107:5 s loc 2
rint 0:107:10 1 #3FF0000000000000
asg 0:107:5 add
rname 0:108:5 s loc 2
rint 0:108:10 1 #3FF0000000000000
asg 0:108:5 add
rname 0:109:5 s loc 2
rint 0:109:10 1 #3FF0000000000000
asg 0:109:5 add
rname 0:110:5 s loc 2
rint 0:110:10 1 #3FF0000000000000
asg 0:110:5 add
rname 0:111:5 s loc 2
rint 0:111:10 1 #3FF0000000000000
asg 0:111:5 add
rname 0:112:5 s loc 2
rint 0:112:10 1 #3FF0000000000000
asg 0:112:5 add
rname 0:113:5 s loc 2
rint 0:113:10 1 #3FF0000000000000
asg 0:113:5 add
rname 0:114:5 s loc 2
rint 0:114:10 1 #3FF0000000000000
asg 0:114:5 add
rname 0:115:5 s loc 2
rint 0:115:10 1 #3FF0000000000000
asg 0:115:5 add
rname 0:116:5 s loc 2
rint 0:116:10 1 #3FF0000000000000
asg 0:116:5 add
rname 0:117:5 s loc 2
rint 0:117:10 1 #3FF0000000000000
asg 0:117:5 add
rname 0:118:5 s loc 2
rint 0:118:10 1 #3FF0000000000000
asg 0:118:5 add
rname 0:119:5 s loc 2
rint 0:119:10 1 #3FF0000000000000
asg 0:119:5 add
rname 0:120:5 s loc 2
rint 0:120:10 1 #3FF0000000000000
asg 0:120:5 add
rname 0:121:5 s loc 2
rint 0:121:10 1 #3FF0000000000000
asg 0:121:5 add
rname 0:122:5 s loc 2
rint 0:122:10 1 #3FF0000000000000
asg 0:122:5 add
rname 0:123:5 s loc 2
rint 0:123:10 1 #3FF0000000000000
asg 0:123:5 add
rname 0:124:5 s loc 2
rint 0:124:10 1 #3FF0000000000000
asg 0:124:5 add
rname 0:125:5 s loc 2
rint 0:125:10 1 #3FF0000000000000
asg 0:125:5 add
rname 0:126:5 s loc 2
rint 0:126:10 1 #3FF0000000000000
asg 0:126:5 add
rname 0:127:5 s loc 2
rint 0:127:10 1 #3FF0000000000000
asg 0:127:5 add
rname 0:128:5 s loc 2
rint 0:128:10 1 #3FF0000000000000
asg 0:128:5 add
rname 0:129:5 s loc 2
rint 0:129:10 1 #3FF0000000000000
asg 0:129:5 add
rname 0:130:5 s loc 2
rint 0:130:10 1 #3FF0000000000000
asg 0:130:5 add
rname 0:131:5 s loc 2
rint 0:131:10 1 #3FF0000000000000
asg 0:131:5 add
rname 0:132:5 s loc 2
rint 0:132:10 1 #3FF0000000000000
asg 0:132:5 add
rname 0:133:5 s loc 2
rint 0:133:10 1 #3FF0000000000000
asg 0:133:5 add
rname 0:134:5 s loc 2
rint 0:134:10 1 #3FF0000000000000
asg 0:134:5 add
rname 0:135:5 s loc 2
rint 0:135:10 1 #3FF0000000000000
asg 0:135:5 add
rname 0:136:5 s loc 2
rint 0:136:10 1 #3FF0000000000000
asg 0:136:5 add
rname 0:137:5 s loc 2
rint 0:137:10 1 #3FF0000000000000
asg 0:137:5 add
rname 0:138:5 s loc 2
rint 0:138:10 1 #3FF0000000000000
asg 0:138:5 add
rname 0:139:5 s loc 2
rint 0:139:10 1 #3FF0000000000000
asg 0:139:5 add
rname 0:140:5 s loc 2
rint 0:140:10 1 #3FF0000000000000
asg 0:140:5 add
rname 0:141:5 s loc 2
rint 0:141:10 1 #3FF0000000000000
asg 0:141:5 add
rname 0:142:5 s loc 2
rint 0:142:10 1 #3FF0000000000000
asg 0:142:5 add
rname 0:143:5 s loc 2
rint 0:143:10 1 #3FF0000000000000
asg 0:143:5 add
rname 0:144:5 s loc 2
rint 0:144:10 1 #3FF0000000000000
asg 0:144:5 add
rname 0:145:5 s loc 2
rint 0:145:10 1 #3FF0000000000000
asg 0:145:5 add
rname 0:146:5 s loc 2
rint 0:146:10 1 #3FF0000000000000
asg 0:146:5 add
rname 0:147:5 s loc 2
rint 0:147:10 1 #3FF0000000000000
asg 0:147:5 add
rname 0:148:12 s loc 2
return 0:148:5 1
block 0:93:23 47
rfn 0:93:1 s51 0 1 1 9 3 3
rpname 0:150:5 a 1
rname 0:150:9 once fn 3
rint 0:150:14 3 #4008000000000000
call 0:150:9 1
rname 0:150:19 twice fn 4
rint 0:150:25 2 #4000000000000000
call 0:150:19 1
bin 0:150:9 add
let 0:150:1 0
rpname 0:151:5 b 2
rname 0:151:9 s50 fn 8
rint 0:151:13 0 #0000000000000000
call 0:151:9 1
rname 0:151:18 s51 fn 9
rint 0:151:22 0 #0000000000000000
call 0:151:18 1
bin 0:151:9 add
rname 0:151:27 s50 fn 8
rint 0:151:31 1 #3FF0000000000000
call 0:151:27 1
bin 0:151:9 add
rname 0:151:36 s51 fn 9
rint 0:151:40 1 #3FF0000000000000
call 0:151:36 1
bin 0:151:9 add
let 0:151:1 0
rpname 0:152:5 c 3
rname 0:152:9 even fn 6
rint 0:152:14 4 #4010000000000000
call 0:152:9 1
rname 0:152:20 odd fn 7
rint 0:152:24 3 #4008000000000000
call 0:152:20 1
bin 0:152:9 and
let 0:152:1 0
rpname 0:153:5 d 4
rname 0:153:9 sq fn 2
float 0:153:12 #4000000000000000
call 0:153:9 1
let 0:153:1 0
prog 12
#end
