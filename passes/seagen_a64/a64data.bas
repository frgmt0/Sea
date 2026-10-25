50000 REM ====================================================================================
50005 REM a64data.bas -- the tables of seagen_a64 (pass 4, arm64-macos), read before the generated
50010 REM DATA blocks (DESIGN 2.6.3, 2.7: templates are DATA, not string constants). In order:
50015 REM 1. the rt.inc / limits.inc constants the pass needs (their values come from the consts
50020 REM    block; the order is the index into K(), see a64.bas); sentinel "-".
50025 REM 2. the LIR records handled by their own code: name, code; sentinel "-".
50030 REM 3. cc word, condition after cmp (icmp), condition after fcmp (fcmp, NaN false except
50035 REM    ne: lt -> mi, le -> ls); sentinel "-".
50040 REM 4. branch inversions: the far form (b.<inverse> 9f; b <label>; 9:) and the inverse of a
50042 REM    fused condition (DESIGN 4.9.2, L-as: it holds for unordered operands); sentinel "-".
50045 REM 5. instruction templates: key, error of $C, error of $D (errors.inc names or "-"),
50050 REM    then the number of code lines and of cold lines, then the lines (DESIGN 4.9.2, L-an).
50055 REM    Direct templates use the allocated registers: $d the destination, $a $b $c the operands
50056 REM    (a register, the scratch register of the position or an immediate), $w $x the 32-bit
50057 REM    names of the destination and of the first operand. Staged templates run on the scratch
50058 REM    registers: operands in x15 x16 x17 (i, p) and d29 d30 d31 (f) in operand order by class,
50059 REM    results in x15 (rcount's e in x16) or d29. x17 holds imulc's high half.
50060 REM    $C $D cold labels, $K $F the cc conditions, $M the memory operand, $L the data label,
50065 REM    $U the first u field, $S the site index, $0..$9 argument slot k (k * SLOT_SIZE).
50070 REM    Numeric labels 1-4 are template-local; 9 is the far form's. A line ending in ":"
50075 REM    is written unindented. The cold lines precede mov x0 code, x1 site, x2 sp,
50080 REM    bl _sea_err. Sentinel "-".
50082 REM    mov, isel psel fsel, chkb's code and release are emitted by their own code (a64.bas); a
50083 REM    fused icmp fcmp bnot is its template's first line (DESIGN 4.9.2 compare and branch).
50085 REM ====================================================================================
50100 DATA "SLOT_SIZE","STACK_LEAF_MAX","RC_STATIC","TAG_STR","STR_RC","STR_TAG","STR_LEN"
50105 DATA "STR_BYTES","FMT_NPIECE","FMT_NCONV","FMT_PIECES","FP_KIND","FP_CONV","FP_FLAGS"
50110 DATA "FP_CLS","FP_WIDTH","FP_PREC","FP_TEXT","FP_TLEN","FP_SIZE","FPK_TEXT","FPK_CONV"
50115 DATA "FF_LEFT","FF_PLUS","FF_SPACE","FF_ZERO","FF_ALT","CLS_I","CLS_F","CLS_P"
50120 DATA "SITE_FILE","SITE_LINE","SITE_SIZE","DATA_ALIGN","ESIZE_I64","ESIZE_F64","ESIZE_BOOL"
50125 DATA "LIM_LIR_INSTRS","LIM_LIR_OPERANDS","LIM_LIR_REGS","LIM_LIR_BLOCKS","LIM_LIR_SLOTS"
50130 DATA "LIM_LIR_IMMS","LIM_LIR_LABELS","LIM_LIR_SITES","FILE_VERSION","SL_SIZE","SL_NREF"
50135 DATA "SL_REFS","-"
50200 DATA "func",1,"slot",2,"endfunc",3,"li",4,"lf",5,"sa",7,"loop",8,"endloop",9,"do",10
50205 DATA "enddo",11,"if",12,"ifz",13,"else",14,"endif",15,"exit",16,"next",17,"ret",18
50210 DATA "call",19,"rcall",20,"chk",21,"str",30,"fmt",31,"ftext",32,"fconv",33,"dat",34
50215 DATA "dvi",35,"dvf",36,"retain",22,"release",23,"mcopy",24,"slay",37,"soff",38,"-"
50300 DATA "eq","eq","eq","ne","ne","ne","lt","lt","mi","le","le","ls","gt","gt","gt"
50305 DATA "ge","ge","ge","-"
50400 DATA "b.eq","b.ne","b.ne","b.eq","b.vs","b.vc","b.vc","b.vs","b.lt","b.ge","b.ge","b.lt"
50405 DATA "b.gt","b.le","b.le","b.gt","b.lo","b.hs","b.hs","b.lo","b.mi","b.pl","b.pl","b.mi"
50410 DATA "b.ls","b.hi","b.hi","b.ls","cbz","cbnz","cbnz","cbz","-"
50500 REM ---- copies, wrapping integer arithmetic, bit operations (direct) ------------------------
50505 DATA "mov","-","-",0,0
50510 DATA "iadd","-","-",1,0,"add $d, $a, $b"
50515 DATA "isub","-","-",1,0,"sub $d, $a, $b"
50520 DATA "imul","-","-",1,0,"mul $d, $a, $b"
50525 DATA "ineg","-","-",1,0,"neg $d, $a"
50530 DATA "imulh","-","-",1,0,"smulh $d, $a, $b"
50535 DATA "iand","-","-",1,0,"and $d, $a, $b"
50540 DATA "ior","-","-",1,0,"orr $d, $a, $b"
50545 DATA "ixor","-","-",1,0,"eor $d, $a, $b"
50550 DATA "ishl","-","-",1,0,"lsl $d, $a, $b"
50555 DATA "ishr","-","-",1,0,"lsr $d, $a, $b"
50560 DATA "isar","-","-",1,0,"asr $d, $a, $b"
50565 DATA "padd","-","-",1,0,"add $d, $a, $b"
50570 DATA "bnot","-","-",2,0,"cmp $a, #0","cset $d, eq"
50575 DATA "icmp","-","-",2,0,"cmp $a, $b","cset $d, $K"
50580 DATA "isel","-","-",0,0
50585 DATA "psel","-","-",0,0
50590 DATA "fsel","-","-",0,0
50600 REM ---- checked integer arithmetic (LANGUAGE 6.5, 6.6; DESIGN 5.2: flag tests) -----------
50605 DATA "iaddc","INT_OVERFLOW","-",2,0,"adds $d, $a, $b","b.vs $C"
50610 DATA "isubc","INT_OVERFLOW","-",2,0,"subs $d, $a, $b","b.vs $C"
50615 DATA "inegc","INT_OVERFLOW","-",2,0,"negs $d, $a","b.vs $C"
50620 REM imulc: the 128-bit product fits in i64 iff its high half is the sign of the low half (the
50622 REM high half first, so the destination may share a register with an operand)
50625 DATA "imulc","INT_OVERFLOW","-",4,0,"smulh x17, $a, $b","mul $d, $a, $b"
50630 DATA "cmp x17, $d, asr #63","b.ne $C"
50635 REM idivf (staged): zero divisor, -2^63 / -1; truncated quotient, minus 1 when the remainder is
50640 REM not 0 and its sign differs from the divisor's (floored, LANGUAGE 6.6)
50645 DATA "idivf","INT_DIV_ZERO","INT_OVERFLOW",15,0,"cbz x16, $C","cmn x16, #1","b.ne 1f"
50650 DATA "movz x17, #0x8000, lsl #48","cmp x15, x17","b.eq $D","1:","sdiv x17, x15, x16"
50655 DATA "msub x15, x17, x16, x15","cbz x15, 2f","eor x15, x15, x16","asr x15, x15, #63"
50660 DATA "add x17, x17, x15","2:","mov x15, x17"
50665 REM imodf (staged): the truncated remainder, plus the divisor when it is not 0 and the signs
50670 REM differ (-2^63 % -1: sdiv gives -2^63, the remainder wraps to 0, the floored result)
50675 DATA "imodf","INT_DIV_ZERO","-",8,0,"cbz x16, $C","sdiv x17, x15, x16"
50680 DATA "msub x15, x17, x16, x15","cbz x15, 1f","eor x17, x15, x16","tbz x17, #63, 1f"
50685 DATA "add x15, x15, x16","1:"
50690 REM rcount (staged): last = (n - 1) mod 2^64 in x15 (to d) and the non-empty flag in x16 (to
50695 REM e) for lo..hi step st (0) and lo..=hi step st (1), LANGUAGE 5.1, DESIGN 3.6.4:
50697 REM last = the distance (hi - lo - 1 or hi - lo, unsigned) divided by |st|, unsigned
50700 DATA "rcount0","RANGE_STEP_ZERO","-",22,0,"cbz x17, $C","tbnz x17, #63, 1f","cmp x15, x16"
50705 DATA "b.ge 3f","sub x16, x16, x15","sub x16, x16, #1","udiv x15, x16, x17","mov x16, #1"
50710 DATA "b 4f","1:","cmp x15, x16","b.le 3f","sub x16, x15, x16","sub x16, x16, #1"
50715 DATA "neg x17, x17","udiv x15, x16, x17","mov x16, #1","b 4f","3:","mov x15, #0"
50720 DATA "mov x16, #0","4:"
50725 DATA "rcount1","RANGE_STEP_ZERO","-",20,0,"cbz x17, $C","tbnz x17, #63, 1f","cmp x15, x16"
50730 DATA "b.gt 3f","sub x16, x16, x15","udiv x15, x16, x17","mov x16, #1","b 4f","1:"
50735 DATA "cmp x15, x16","b.lt 3f","sub x16, x15, x16","neg x17, x17","udiv x15, x16, x17"
50740 DATA "mov x16, #1","b 4f","3:","mov x15, #0","mov x16, #0","4:"
50800 REM ---- f64: one IEEE instruction each (DESIGN 3.6.4: no FMA, no contraction) ------------
50805 DATA "fadd","-","-",1,0,"fadd $d, $a, $b"
50810 DATA "fsub","-","-",1,0,"fsub $d, $a, $b"
50815 DATA "fmul","-","-",1,0,"fmul $d, $a, $b"
50820 DATA "fdiv","-","-",1,0,"fdiv $d, $a, $b"
50825 DATA "fneg","-","-",1,0,"fneg $d, $a"
50830 DATA "fabs","-","-",1,0,"fabs $d, $a"
50835 DATA "fsqrt","-","-",1,0,"fsqrt $d, $a"
50837 REM the roundings are staged (DESIGN 4.9.2: staged on both targets)
50840 DATA "ffloor","-","-",1,0,"frintm d29, d29"
50845 DATA "fceil","-","-",1,0,"frintp d29, d29"
50850 DATA "ftrunc","-","-",1,0,"frintz d29, d29"
50855 DATA "fround","-","-",1,0,"frinta d29, d29"
50860 REM fmin / fmax (staged, LANGUAGE 10.4): the second if it is strictly smaller / larger, else
50865 REM the first; a NaN first operand gives the second
50870 DATA "fmin","-","-",4,0,"fcmp d30, d29","fcsel d31, d30, d29, mi","fcmp d29, d29"
50875 DATA "fcsel d29, d30, d31, vs"
50880 DATA "fmax","-","-",4,0,"fcmp d30, d29","fcsel d31, d30, d29, gt","fcmp d29, d29"
50885 DATA "fcsel d29, d30, d31, vs"
50890 DATA "fcmp","-","-",2,0,"fcmp $a, $b","cset $d, $F"
50895 DATA "fnan","-","-",2,0,"fcmp $a, $a","cset $d, vs"
50900 DATA "itof","-","-",1,0,"scvtf $d, $a"
50905 REM ftoi (staged, LANGUAGE 4.2): integral (NaN fails the compare), then -2^63 <= x < 2^63
50910 REM with -2^63 made exactly by scvtf; the cold block passes x's bits as the f argument
50915 DATA "ftoi","CONV_I64","-",11,1,"frintz d30, d29","fcmp d30, d29","b.ne $C"
50920 DATA "movz x16, #0x8000, lsl #48","scvtf d30, x16","fcmp d29, d30","b.lt $C"
50925 DATA "fneg d30, d30","fcmp d29, d30","b.ge $C","fcvtzs x15, d29","str d29, [sp, #$0]"
50930 REM ---- memory: $M is [base], [base, #off], [base, idx(, lsl #3)] or [x16] -------------------
50935 DATA "ldi","-","-",1,0,"ldr $d, $M"
50940 DATA "ldb","-","-",1,0,"ldrb $w, $M"
50945 DATA "ldf","-","-",1,0,"ldr $d, $M"
50950 DATA "ldp","-","-",1,0,"ldr $d, $M"
50955 DATA "sti","-","-",1,0,"str $a, $M"
50960 DATA "stb","-","-",1,0,"strb $x, $M"
50965 DATA "stf","-","-",1,0,"str $a, $M"
50970 DATA "stp","-","-",1,0,"str $a, $M"
50975 DATA "la","-","-",2,0,"adrp $d, $L@PAGE","add $d, $d, $L@PAGEOFF"
50980 REM chkb (LANGUAGE 5.4): the compare and branch are a64.bas's (an immediate index 0-4095:
50982 REM cmp ext, #idx / b.ls); the cold lines store the arguments idx, dim, ext
50985 DATA "chkb","INDEX_OOB","-",0,4,"str $a, [sp, #$0]","mov x17, #$U","str x17, [sp, #$1]"
50990 DATA "str $b, [sp, #$2]"
50991 DATA "retain","-","-",5,0,"ldr x16, [$a]","cbz x16, 1f","add x16, x16, #1","str x16, [$a]","1:"
50992 DATA "release","-","-",0,0
50993 REM mcopy (staged): d s n in x15 x16 x17, the data through d29 (DESIGN 4.9.2)
50994 DATA "mcopy","-","-",16,0,"cmp x17, #8","b.lo 2f","1:","ldr d29, [x16], #8","str d29, [x15], #8"
50995 DATA "sub x17, x17, #8","cmp x17, #8","b.hs 1b","2:","cbz x17, 4f","3:","ldr b29, [x16], #1"
50996 DATA "str b29, [x15], #1","subs x17, x17, #1","b.ne 3b","4:"
50999 DATA "-"
