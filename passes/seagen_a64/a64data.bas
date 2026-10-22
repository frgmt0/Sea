50000 REM ====================================================================================
50005 REM a64data.bas -- the tables of seagen_a64 (pass 4, arm64-macos), read before the generated
50010 REM DATA blocks (DESIGN 2.6.3, 2.7: templates are DATA, not string constants). In order:
50015 REM 1. the rt.inc / limits.inc constants the pass needs (their values come from the consts
50020 REM    block; the order is the index into K(), see a64.bas); sentinel "-".
50025 REM 2. the LIR records handled by their own code: name, code; sentinel "-".
50030 REM 3. cc word, condition after cmp (icmp), condition after fcmp (fcmp, NaN false except
50035 REM    ne: lt -> mi, le -> ls); sentinel "-".
50040 REM 4. branch inversions for the far form (b.<inverse> 9f; b <label>; 9:); sentinel "-".
50045 REM 5. instruction templates: key, error of $C, error of $D (errors.inc names or "-"),
50050 REM    then the number of code lines and of cold lines, then the lines. Operands are in
50055 REM    x9 x10 x11 (i, p) and d16 d17 d18 (f) in operand order, the result in x9 or d16.
50060 REM    $C $D cold labels, $K $F the cc conditions, $M the memory operand, $L the data label,
50065 REM    $U the first u field, $S the site index, $0..$9 argument slot k (k * SLOT_SIZE).
50070 REM    Numeric labels 1-4 are template-local; 9 is the far form's. A line ending in ":"
50075 REM    is written unindented. The cold lines precede mov x0 code, x1 site, x2 sp,
50080 REM    bl _sea_err. Sentinel "-".
50082 REM    retain, release (a in x9; $M = _<symbol of the FREE entry>) and mcopy (d s n in x9 x10
50083 REM    x11) are the sequences of DESIGN 4.9, emitted by their own code (a64.bas 6500).
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
50500 REM ---- copies, wrapping integer arithmetic, bit operations ------------------------------
50505 DATA "mov","-","-",0,0
50510 DATA "iadd","-","-",1,0,"add x9, x9, x10"
50515 DATA "isub","-","-",1,0,"sub x9, x9, x10"
50520 DATA "imul","-","-",1,0,"mul x9, x9, x10"
50525 DATA "ineg","-","-",1,0,"neg x9, x9"
50530 DATA "imulh","-","-",1,0,"smulh x9, x9, x10"
50535 DATA "iand","-","-",1,0,"and x9, x9, x10"
50540 DATA "ior","-","-",1,0,"orr x9, x9, x10"
50545 DATA "ixor","-","-",1,0,"eor x9, x9, x10"
50550 DATA "ishl","-","-",1,0,"lsl x9, x9, x10"
50555 DATA "ishr","-","-",1,0,"lsr x9, x9, x10"
50560 DATA "isar","-","-",1,0,"asr x9, x9, x10"
50565 DATA "padd","-","-",1,0,"add x9, x9, x10"
50570 DATA "bnot","-","-",2,0,"cmp x9, #0","cset x9, eq"
50575 DATA "icmp","-","-",2,0,"cmp x9, x10","cset x9, $K"
50580 DATA "isel","-","-",2,0,"cmp x9, #0","csel x9, x10, x11, ne"
50585 DATA "psel","-","-",2,0,"cmp x9, #0","csel x9, x10, x11, ne"
50590 DATA "fsel","-","-",2,0,"cmp x9, #0","fcsel d16, d16, d17, ne"
50600 REM ---- checked integer arithmetic (LANGUAGE 6.5, 6.6; DESIGN 5.2: flag tests) -----------
50605 DATA "iaddc","INT_OVERFLOW","-",2,0,"adds x9, x9, x10","b.vs $C"
50610 DATA "isubc","INT_OVERFLOW","-",2,0,"subs x9, x9, x10","b.vs $C"
50615 DATA "inegc","INT_OVERFLOW","-",2,0,"negs x9, x9","b.vs $C"
50620 REM imulc: the 128-bit product fits in i64 iff its high half is the sign of the low half
50625 DATA "imulc","INT_OVERFLOW","-",4,0,"smulh x11, x9, x10","mul x9, x9, x10"
50630 DATA "cmp x11, x9, asr #63","b.ne $C"
50635 REM idivf: zero divisor, -2^63 / -1; truncated quotient, minus 1 when the remainder is not
50640 REM 0 and its sign differs from the divisor's (floored, LANGUAGE 6.6)
50645 DATA "idivf","INT_DIV_ZERO","INT_OVERFLOW",15,0,"cbz x10, $C","cmn x10, #1","b.ne 1f"
50650 DATA "movz x11, #0x8000, lsl #48","cmp x9, x11","b.eq $D","1:","sdiv x11, x9, x10"
50655 DATA "msub x9, x11, x10, x9","cbz x9, 2f","eor x9, x9, x10","asr x9, x9, #63"
50660 DATA "add x11, x11, x9","2:","mov x9, x11"
50665 REM imodf: the truncated remainder, plus the divisor when it is not 0 and the signs differ
50670 REM (-2^63 % -1: sdiv gives -2^63, the remainder wraps to 0, the floored result)
50675 DATA "imodf","INT_DIV_ZERO","-",8,0,"cbz x10, $C","sdiv x11, x9, x10"
50680 DATA "msub x9, x11, x10, x9","cbz x9, 1f","eor x11, x9, x10","tbz x11, #63, 1f"
50685 DATA "add x9, x9, x10","1:"
50690 REM rcount: last = (n - 1) mod 2^64 in x9 (stored to d) and the non-empty flag in x10
50695 REM (stored to e) for lo..hi step st (0) and lo..=hi step st (1), LANGUAGE 5.1, DESIGN 3.6.4:
50697 REM last = the distance (hi - lo - 1 or hi - lo, unsigned) divided by |st|, unsigned
50700 DATA "rcount0","RANGE_STEP_ZERO","-",22,0,"cbz x11, $C","tbnz x11, #63, 1f","cmp x9, x10"
50705 DATA "b.ge 3f","sub x10, x10, x9","sub x10, x10, #1","udiv x9, x10, x11","mov x10, #1"
50710 DATA "b 4f","1:","cmp x9, x10","b.le 3f","sub x10, x9, x10","sub x10, x10, #1"
50715 DATA "neg x11, x11","udiv x9, x10, x11","mov x10, #1","b 4f","3:","mov x9, #0"
50720 DATA "mov x10, #0","4:"
50725 DATA "rcount1","RANGE_STEP_ZERO","-",20,0,"cbz x11, $C","tbnz x11, #63, 1f","cmp x9, x10"
50730 DATA "b.gt 3f","sub x10, x10, x9","udiv x9, x10, x11","mov x10, #1","b 4f","1:"
50735 DATA "cmp x9, x10","b.lt 3f","sub x10, x9, x10","neg x11, x11","udiv x9, x10, x11"
50740 DATA "mov x10, #1","b 4f","3:","mov x9, #0","mov x10, #0","4:"
50800 REM ---- f64: one IEEE instruction each (DESIGN 3.6.4: no FMA, no contraction) ------------
50805 DATA "fadd","-","-",1,0,"fadd d16, d16, d17"
50810 DATA "fsub","-","-",1,0,"fsub d16, d16, d17"
50815 DATA "fmul","-","-",1,0,"fmul d16, d16, d17"
50820 DATA "fdiv","-","-",1,0,"fdiv d16, d16, d17"
50825 DATA "fneg","-","-",1,0,"fneg d16, d16"
50830 DATA "fabs","-","-",1,0,"fabs d16, d16"
50835 DATA "fsqrt","-","-",1,0,"fsqrt d16, d16"
50840 DATA "ffloor","-","-",1,0,"frintm d16, d16"
50845 DATA "fceil","-","-",1,0,"frintp d16, d16"
50850 DATA "ftrunc","-","-",1,0,"frintz d16, d16"
50855 DATA "fround","-","-",1,0,"frinta d16, d16"
50860 REM fmin / fmax (LANGUAGE 10.4): the second if it is strictly smaller / larger, else the
50865 REM first; a NaN first operand gives the second
50870 DATA "fmin","-","-",4,0,"fcmp d17, d16","fcsel d18, d17, d16, mi","fcmp d16, d16"
50875 DATA "fcsel d16, d17, d18, vs"
50880 DATA "fmax","-","-",4,0,"fcmp d17, d16","fcsel d18, d17, d16, gt","fcmp d16, d16"
50885 DATA "fcsel d16, d17, d18, vs"
50890 DATA "fcmp","-","-",2,0,"fcmp d16, d17","cset x9, $F"
50895 DATA "fnan","-","-",2,0,"fcmp d16, d16","cset x9, vs"
50900 DATA "itof","-","-",1,0,"scvtf d16, x9"
50905 REM ftoi (LANGUAGE 4.2): integral (NaN fails the compare), then -2^63 <= x < 2^63 with
50910 REM -2^63 made exactly by scvtf; the cold block passes x's bits as the f argument
50915 DATA "ftoi","CONV_I64","-",11,1,"frintz d17, d16","fcmp d17, d16","b.ne $C"
50920 DATA "movz x10, #0x8000, lsl #48","scvtf d17, x10","fcmp d16, d17","b.lt $C"
50925 DATA "fneg d17, d17","fcmp d16, d17","b.ge $C","fcvtzs x9, d16","str d16, [sp, #$0]"
50930 REM ---- memory: $M is [base], or [x16] after base + idx * scale + off ----------------------
50935 DATA "ldi","-","-",1,0,"ldr x9, $M"
50940 DATA "ldb","-","-",1,0,"ldrb w9, $M"
50945 DATA "ldf","-","-",1,0,"ldr d16, $M"
50950 DATA "ldp","-","-",1,0,"ldr x9, $M"
50955 DATA "sti","-","-",1,0,"str x9, $M"
50960 DATA "stb","-","-",1,0,"strb w9, $M"
50965 DATA "stf","-","-",1,0,"str d16, $M"
50970 DATA "stp","-","-",1,0,"str x9, $M"
50975 DATA "la","-","-",2,0,"adrp x9, $L@PAGE","add x9, x9, $L@PAGEOFF"
50980 REM chkb (LANGUAGE 5.4): unsigned idx >= ext catches idx < 0; arguments idx, dim, ext
50985 DATA "chkb","INDEX_OOB","-",2,4,"cmp x9, x10","b.hs $C","str x9, [sp, #$0]"
50990 DATA "mov x9, #$U","str x9, [sp, #$1]","str x10, [sp, #$2]"
50991 DATA "retain","-","-",5,0,"ldr x10, [x9]","cbz x10, 1f","add x10, x10, #1","str x10, [x9]","1:"
50992 DATA "release","-","-",8,0,"ldr x10, [x9]","cbz x10, 1f","subs x10, x10, #1","str x10, [x9]"
50993 DATA "b.ne 1f","mov x0, x9","bl $M","1:","mcopy","-","-",16,0,"cmp x11, #8","b.lo 2f","1:"
50994 DATA "ldr x16, [x10], #8","str x16, [x9], #8","sub x11, x11, #8","cmp x11, #8","b.hs 1b","2:","cbz x11, 4f","3:","ldrb w16, [x10], #1","strb w16, [x9], #1","subs x11, x11, #1","b.ne 3b","4:"
50995 DATA "-"
