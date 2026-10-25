50000 REM ====================================================================================
50005 REM x64data.bas -- the tables of seagen_x64 (pass 4, x86_64-linux), read before the
50010 REM generated DATA blocks (DESIGN 2.6.3, 2.7: templates are DATA, not string constants).
50015 REM 1. the rt.inc / limits.inc constants the pass needs (their values come from the consts
50020 REM    block; the order is the index into K(), see x64.bas); sentinel "-".
50025 REM 2. the LIR records handled by their own code: name, code; sentinel "-".
50030 REM 3. cc word, then: the condition after cmpq (icmp), the ucomisd operand order of fcmp
50035 REM    (ba: ucomisd b, a; ab: ucomisd a, b), its set conditions (the second and the combining
50040 REM    instruction only for eq / ne), the inverse icmp condition, the fcmp branch condition
50045 REM    and its inverse (DESIGN 4.9.2, L-as: the inverses hold for unordered operands); "-".
50050 REM 4. machine register numbers (1-16 %rax %rcx %rdx %rbx %rsp %rbp %rsi %rdi %r8-%r15,
50055 REM    17-32 %xmm0-%xmm15): the integer argument registers, -1, the integer result
50060 REM    registers, -1 (DESIGN 4.8); then the names: 32 of 64 bits, 16 of 32, 16 of 8, "-".
50065 REM 5. the register table of DESIGN 4.9.2 for ralloc's ra_tab: register, class (1 general,
50070 REM    2 xmm), rank crossing no call, rank crossing a call, callee-saved; sentinel -1.
50075 REM 6. instruction templates: key, error of @C, error of @D (errors.inc names or "-"), the
50080 REM    form (0 staged, else the direct form of x64.bas), its flags, the number of code
50082 REM    lines and of cold lines, then the lines. A direct form's one line is its mnemonic.
50084 REM    Flags: c commuting, s the first operand may be the immediate, i the second may be
50086 REM    a 32-bit immediate, l leaq for an immediate, m imulq $v, a, d, o jo to the cold
50088 REM    block, n / a the .L<f>_neg / .L<f>_abs constant, z the narrow register (movzbl to
50089 REM    32 bits, movb from 8), b an immediate byte. A staged template runs on its operands
50090 REM    in %rax %rcx %rdx (i, p) and %xmm14 %xmm15 (f), in operand order; results in %rax
50091 REM    or %xmm14 (rcount's flag in %rcx); %r11 is free in it. @C @D cold labels, @0..@9
50092 REM    argument slot k. Numeric labels 1-4 are template-local; a line ending in ":" is
50093 REM    written unindented. The cold lines precede movl code %edi, movq site %rsi,
50094 REM    movq %rsp %rdx, call sea_err. Sentinel "-".
50098 REM ====================================================================================
50100 DATA "SLOT_SIZE","STACK_LEAF_MAX","RC_STATIC","TAG_STR","STR_RC","STR_TAG","STR_LEN"
50105 DATA "STR_BYTES","FMT_NPIECE","FMT_NCONV","FMT_PIECES","FP_KIND","FP_CONV","FP_FLAGS"
50110 DATA "FP_CLS","FP_WIDTH","FP_PREC","FP_TEXT","FP_TLEN","FP_SIZE","FPK_TEXT","FPK_CONV"
50115 DATA "FF_LEFT","FF_PLUS","FF_SPACE","FF_ZERO","FF_ALT","CLS_I","CLS_F","CLS_P"
50120 DATA "SITE_FILE","SITE_LINE","SITE_SIZE","DATA_ALIGN","ESIZE_I64","ESIZE_F64","ESIZE_BOOL"
50125 DATA "LIM_LIR_INSTRS","LIM_LIR_OPERANDS","LIM_LIR_REGS","LIM_LIR_BLOCKS","LIM_LIR_SLOTS"
50130 DATA "LIM_LIR_IMMS","LIM_LIR_LABELS","LIM_LIR_SITES","FILE_VERSION","SL_SIZE","SL_NREF"
50135 DATA "SL_REFS","ESIZE_PTR","-"
50200 DATA "func",1,"slot",2,"endfunc",3,"li",4,"lf",5,"sa",7,"loop",8,"endloop",9,"do",10
50205 DATA "enddo",11,"if",12,"ifz",13,"else",14,"endif",15,"exit",16,"next",17,"ret",18
50210 DATA "call",19,"rcall",20,"chk",21,"str",30,"fmt",31,"ftext",32,"fconv",33,"dat",34
50215 DATA "dvi",35,"dvf",36,"slay",37,"soff",38,"-"
50300 DATA "eq","e","ba","e","np","andb","ne","-","-"
50305 DATA "ne","ne","ba","ne","p","orb","e","-","-"
50310 DATA "lt","l","ab","a","-","-","ge","a","be"
50315 DATA "le","le","ab","ae","-","-","g","ae","b"
50320 DATA "gt","g","ba","a","-","-","le","a","be"
50325 DATA "ge","ge","ba","ae","-","-","l","ae","b","-"
50400 DATA 8,7,3,2,9,10,-1
50405 DATA 1,3,2,7,8,9,10,-1
50410 DATA "%rax","%rcx","%rdx","%rbx","%rsp","%rbp","%rsi","%rdi","%r8","%r9","%r10","%r11"
50412 DATA "%r12","%r13","%r14","%r15","%xmm0","%xmm1","%xmm2","%xmm3","%xmm4","%xmm5","%xmm6"
50414 DATA "%xmm7","%xmm8","%xmm9","%xmm10","%xmm11","%xmm12","%xmm13","%xmm14","%xmm15"
50416 DATA "%eax","%ecx","%edx","%ebx","%esp","%ebp","%esi","%edi","%r8d","%r9d","%r10d","%r11d"
50418 DATA "%r12d","%r13d","%r14d","%r15d"
50420 DATA "%al","%cl","%dl","%bl","%spl","%bpl","%sil","%dil","%r8b","%r9b","%r10b","%r11b"
50422 DATA "%r12b","%r13b","%r14b","%r15b","-"
50440 REM %rsi %rdi %r8 %r9 %r10, then %rbx %r12-%r15 (callee-saved) crossing no call; the
50441 REM callee-saved first crossing a call; %xmm0-%xmm13 in both rows (none is callee-saved)
50442 DATA 7,1,1,6,0,8,1,2,7,0,9,1,3,8,0,10,1,4,9,0,11,1,5,10,0
50444 DATA 4,1,6,1,1,13,1,7,2,1,14,1,8,3,1,15,1,9,4,1,16,1,10,5,1
50446 DATA 17,2,1,1,0,18,2,2,2,0,19,2,3,3,0,20,2,4,4,0,21,2,5,5,0,22,2,6,6,0,23,2,7,7,0
50448 DATA 24,2,8,8,0,25,2,9,9,0,26,2,10,10,0,27,2,11,11,0,28,2,12,12,0,29,2,13,13,0
50449 DATA 30,2,14,14,0,-1
50500 REM ---- direct: copies, wrapping integer arithmetic, bit operations (DESIGN 4.9.2, L-ah) ---
50505 DATA "mov","-","-",21,"-",0,0
50510 DATA "iadd","-","-",1,"csil",1,0,"addq"
50515 DATA "isub","-","-",1,"i",1,0,"subq"
50520 DATA "imul","-","-",1,"csim",1,0,"imulq"
50525 DATA "ineg","-","-",4,"-",1,0,"negq"
50535 DATA "imulh","-","-",8,"-",0,0
50540 DATA "iand","-","-",1,"csi",1,0,"andq"
50545 DATA "ior","-","-",1,"csi",1,0,"orq"
50550 DATA "ixor","-","-",1,"csi",1,0,"xorq"
50555 REM shifts: the count in %cl, masked to 6 bits as arm64's lsl / lsr / asr do
50560 DATA "ishl","-","-",3,"-",1,0,"shlq"
50565 DATA "ishr","-","-",3,"-",1,0,"shrq"
50570 DATA "isar","-","-",3,"-",1,0,"sarq"
50575 DATA "padd","-","-",1,"il",1,0,"addq"
50580 DATA "bnot","-","-",11,"-",0,0
50585 DATA "icmp","-","-",9,"-",0,0
50590 DATA "isel","-","-",13,"-",0,0
50595 DATA "psel","-","-",13,"-",0,0
50597 DATA "fsel","-","-",14,"-",0,0
50600 REM ---- checked integer arithmetic (LANGUAGE 6.5, 6.6): OF after the operation ---------
50605 DATA "iaddc","INT_OVERFLOW","-",1,"sio",1,0,"addq"
50610 DATA "isubc","INT_OVERFLOW","-",1,"io",1,0,"subq"
50615 DATA "inegc","INT_OVERFLOW","-",4,"o",1,0,"negq"
50620 DATA "imulc","INT_OVERFLOW","-",1,"simo",1,0,"imulq"
50635 REM ---- staged: idivf: the checks before idivq (which faults on them): zero divisor,
50640 REM -2^63 / -1; the truncated quotient minus 1 when the remainder is not 0 and its sign
50642 REM differs from the divisor's (floored, LANGUAGE 6.6)
50645 DATA "idivf","INT_DIV_ZERO","INT_OVERFLOW",0,"-",16,0,"testq %rcx, %rcx","je @C"
50650 DATA "cmpq $-1, %rcx","jne 1f","movabsq $0x8000000000000000, %rdx","cmpq %rdx, %rax"
50655 DATA "je @D","1:","cqto","idivq %rcx","testq %rdx, %rdx","je 2f","xorq %rcx, %rdx"
50660 DATA "jns 2f","subq $1, %rax","2:"
50665 REM imodf: divisor -1 gives 0 without idivq (-2^63 % -1 would fault); else the truncated
50670 REM remainder, plus the divisor when it is not 0 and the signs differ
50675 DATA "imodf","INT_DIV_ZERO","-",0,"-",16,0,"testq %rcx, %rcx","je @C","cmpq $-1, %rcx"
50680 DATA "jne 1f","xorl %eax, %eax","jmp 2f","1:","cqto","idivq %rcx","movq %rdx, %rax"
50685 DATA "testq %rax, %rax","je 2f","xorq %rcx, %rdx","jns 2f","addq %rcx, %rax","2:"
50690 REM rcount: last = (n - 1) mod 2^64 in %rax (to d), the non-empty flag in %rcx (to e)
50695 REM for lo..hi step st (0) and lo..=hi step st (1), LANGUAGE 5.1, DESIGN 3.6.4:
50697 REM last = the distance (hi - lo - 1 or hi - lo, unsigned) divided by |st| with divq
50700 DATA "rcount0","RANGE_STEP_ZERO","-",0,"-",27,0,"testq %rdx, %rdx","je @C"
50702 DATA "movq %rdx, %r11"
50705 DATA "js 1f","cmpq %rcx, %rax","jge 3f","subq %rax, %rcx","subq $1, %rcx","movq %rcx, %rax"
50710 DATA "xorl %edx, %edx","divq %r11","movl $1, %ecx","jmp 4f","1:","cmpq %rcx, %rax","jle 3f"
50715 DATA "subq %rcx, %rax","subq $1, %rax","negq %r11","xorl %edx, %edx","divq %r11"
50720 DATA "movl $1, %ecx","jmp 4f","3:","xorl %eax, %eax","xorl %ecx, %ecx","4:"
50725 DATA "rcount1","RANGE_STEP_ZERO","-",0,"-",25,0,"testq %rdx, %rdx","je @C"
50727 DATA "movq %rdx, %r11"
50730 DATA "js 1f","cmpq %rcx, %rax","jg 3f","subq %rax, %rcx","movq %rcx, %rax","xorl %edx, %edx"
50735 DATA "divq %r11","movl $1, %ecx","jmp 4f","1:","cmpq %rcx, %rax","jl 3f","subq %rcx, %rax"
50740 DATA "negq %r11","xorl %edx, %edx","divq %r11","movl $1, %ecx","jmp 4f","3:"
50745 DATA "xorl %eax, %eax","xorl %ecx, %ecx","4:"
50800 REM ---- f64: one IEEE instruction each (DESIGN 3.6.4: no FMA, no contraction) ------------
50805 DATA "fadd","-","-",2,"c",1,0,"addsd"
50810 DATA "fsub","-","-",2,"-",1,0,"subsd"
50815 DATA "fmul","-","-",2,"c",1,0,"mulsd"
50820 DATA "fdiv","-","-",2,"-",1,0,"divsd"
50822 REM fneg / fabs: bit 63 flipped / cleared with the function's 16-byte constants (L-ah)
50825 DATA "fneg","-","-",5,"n",1,0,"xorpd"
50830 DATA "fabs","-","-",5,"a",1,0,"andpd"
50835 DATA "fsqrt","-","-",6,"-",1,0,"sqrtsd"
50837 REM staged ffloor fceil ftrunc fround (SSE2, DESIGN 4.9.1, 4.9.2): NaN or |x| >= 2^52 is
50838 REM x; else t = cvttsd2si, kept as an integer in %rax and adjusted there (decq, incq, or
50839 REM leaq 1(%rax,%rcx,2) with %rcx = 0 or -1 for fround), converted again; the result takes
50840 REM x's sign bit (so a zero result is -0.0 for a negative x, as frintm/p/z/a give)
50841 DATA "ffloor","-","-",0,"-",21,0,"movq %xmm14, %rax","btrq $63, %rax"
50842 DATA "movabsq $0x4330000000000000, %rcx","cmpq %rcx, %rax","jae 1f"
50843 DATA "cvttsd2si %xmm14, %rax","xorpd %xmm15, %xmm15","cvtsi2sdq %rax, %xmm15"
50844 DATA "ucomisd %xmm14, %xmm15","jbe 2f","decq %rax","xorpd %xmm15, %xmm15"
50845 DATA "cvtsi2sdq %rax, %xmm15","2:","movq %xmm14, %rcx","shrq $63, %rcx","shlq $63, %rcx"
50846 DATA "movq %xmm15, %rax","orq %rcx, %rax","movq %rax, %xmm14","1:"
50850 DATA "fceil","-","-",0,"-",21,0,"movq %xmm14, %rax","btrq $63, %rax"
50851 DATA "movabsq $0x4330000000000000, %rcx","cmpq %rcx, %rax","jae 1f"
50852 DATA "cvttsd2si %xmm14, %rax","xorpd %xmm15, %xmm15","cvtsi2sdq %rax, %xmm15"
50853 DATA "ucomisd %xmm15, %xmm14","jbe 2f","incq %rax","xorpd %xmm15, %xmm15"
50854 DATA "cvtsi2sdq %rax, %xmm15","2:","movq %xmm14, %rcx","shrq $63, %rcx","shlq $63, %rcx"
50855 DATA "movq %xmm15, %rax","orq %rcx, %rax","movq %rax, %xmm14","1:"
50860 DATA "ftrunc","-","-",0,"-",15,0,"movq %xmm14, %rax","btrq $63, %rax"
50861 DATA "movabsq $0x4330000000000000, %rcx","cmpq %rcx, %rax","jae 1f"
50862 DATA "cvttsd2si %xmm14, %rax","xorpd %xmm15, %xmm15","cvtsi2sdq %rax, %xmm15"
50863 DATA "movq %xmm14, %rcx","shrq $63, %rcx","shlq $63, %rcx"
50864 DATA "movq %xmm15, %rax","orq %rcx, %rax","movq %rax, %xmm14","1:"
50865 REM fround: |t - x| >= 0.5 (exact; the bits of two non-negative doubles compare as
50866 REM integers) moves t one away from zero towards x's sign: half away from zero (frinta)
50870 DATA "fround","-","-",0,"-",27,0,"movq %xmm14, %rax","btrq $63, %rax"
50871 DATA "movabsq $0x4330000000000000, %rcx","cmpq %rcx, %rax","jae 1f"
50872 DATA "cvttsd2si %xmm14, %rax","xorpd %xmm15, %xmm15","cvtsi2sdq %rax, %xmm15"
50873 DATA "subsd %xmm14, %xmm15","movq %xmm15, %rcx","btrq $63, %rcx"
50874 DATA "movabsq $0x3FE0000000000000, %rdx","cmpq %rdx, %rcx","jb 2f","movq %xmm14, %rcx"
50875 DATA "sarq $63, %rcx","leaq 1(%rax,%rcx,2), %rax","2:","xorpd %xmm15, %xmm15"
50876 DATA "cvtsi2sdq %rax, %xmm15","movq %xmm14, %rcx","shrq $63, %rcx","shlq $63, %rcx"
50877 DATA "movq %xmm15, %rax","orq %rcx, %rax","movq %rax, %xmm14","1:"
50880 REM fmin / fmax (LANGUAGE 10.4, DESIGN 4.9.1): a NaN first operand gives the second; else
50882 REM the second if it is strictly smaller / larger (an ordered comparison), else the first
50885 DATA "fmin","-","-",0,"-",7,0,"ucomisd %xmm14, %xmm14","jp 1f","ucomisd %xmm15, %xmm14"
50887 DATA "jbe 2f","1:","movapd %xmm15, %xmm14","2:"
50890 DATA "fmax","-","-",0,"-",7,0,"ucomisd %xmm14, %xmm14","jp 1f","ucomisd %xmm14, %xmm15"
50892 DATA "jbe 2f","1:","movapd %xmm15, %xmm14","2:"
50895 DATA "fcmp","-","-",10,"-",0,0
50900 DATA "fnan","-","-",12,"-",0,0
50905 DATA "itof","-","-",7,"-",0,0
50910 REM ftoi (LANGUAGE 4.2; DESIGN 4.9.1): the checks come first: NaN; |x| >= 2^63 except
50912 REM -2^63 itself; for |x| < 2^52 the truncation equals x; then cvttsd2si. The cold block
50914 REM passes x's bits as the f argument
50915 DATA "ftoi","CONV_I64","-",0,"-",22,1,"ucomisd %xmm14, %xmm14","jp @C"
50918 DATA "movq %xmm14, %rax"
50920 DATA "btrq $63, %rax","movabsq $0x43E0000000000000, %rcx","cmpq %rcx, %rax","jb 1f"
50922 DATA "movq %xmm14, %rax","movabsq $0xC3E0000000000000, %rcx","cmpq %rcx, %rax","jne @C"
50924 DATA "jmp 2f","1:","movabsq $0x4330000000000000, %rcx","cmpq %rcx, %rax","jae 2f"
50926 DATA "cvttsd2si %xmm14, %rax","cvtsi2sdq %rax, %xmm15","ucomisd %xmm14, %xmm15"
50927 DATA "jne @C","2:"
50928 DATA "cvttsd2si %xmm14, %rax","movsd %xmm14, @0(%rsp)"
50930 REM ---- direct memory: off(base, idx, scale), or (%r11) after base + idx * scale + off ----
50935 DATA "ldi","-","-",15,"-",1,0,"movq"
50940 DATA "ldb","-","-",15,"z",1,0,"movzbl"
50945 DATA "ldf","-","-",15,"-",1,0,"movsd"
50950 DATA "ldp","-","-",15,"-",1,0,"movq"
50955 DATA "sti","-","-",16,"i",1,0,"movq"
50960 DATA "stb","-","-",16,"zb",1,0,"movb"
50965 DATA "stf","-","-",16,"-",1,0,"movsd"
50970 DATA "stp","-","-",16,"-",1,0,"movq"
50975 DATA "la","-","-",20,"-",0,0
50980 REM chkb (LANGUAGE 5.4): unsigned idx >= ext catches idx < 0; arguments idx, dim, ext
50985 DATA "chkb","INDEX_OOB","-",17,"-",0,0
50991 REM ---- phase 4 (DESIGN 4.9, 4.9.1, 4.9.2): counts at offset 0, a count of 0 is a static
50992 REM object; release calls sea_free (entry FREE) with %rsp = 0 mod 16
50993 DATA "retain","-","-",18,"-",0,0
50995 DATA "release","-","-",19,"-",0,0
50997 REM staged mcopy d s n (n >= 0, no overlap): 8 bytes at a time, then single bytes
50998 DATA "mcopy","-","-",0,"-",21,0,"cmpq $8, %rdx","jb 2f","1:","movq (%rcx), %r11"
50999 DATA "movq %r11, (%rax)"
51000 DATA "addq $8, %rcx","addq $8, %rax","subq $8, %rdx","cmpq $8, %rdx","jae 1b","2:"
51001 DATA "testq %rdx, %rdx","je 4f","3:","movzbl (%rcx), %r11d","movb %r11b, (%rax)","incq %rcx"
51002 DATA "incq %rax","decq %rdx","jne 3b","4:"
51005 DATA "-"
