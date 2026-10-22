50000 REM ====================================================================================
50005 REM x64data.bas -- the tables of seagen_x64 (pass 4, x86_64-linux), read before the
50010 REM generated DATA blocks (DESIGN 2.6.3, 2.7: templates are DATA, not string constants).
50015 REM 1. the rt.inc / limits.inc constants the pass needs (their values come from the consts
50020 REM    block; the order is the index into K(), see x64.bas); sentinel "-".
50025 REM 2. the LIR records handled by their own code: name, code; sentinel "-".
50030 REM 3. cc word, then: the condition after cmpq (icmp), the ucomisd operands of fcmp, its
50035 REM    two set conditions and the instruction that combines them (DESIGN 4.9.1: an
50040 REM    unordered pair sets ZF PF CF, so only ne is true with a NaN); sentinel "-".
50045 REM 4. the integer argument registers, sentinel "-", then the integer result registers,
50050 REM    sentinel "-" (DESIGN 4.8).
50055 REM 5. instruction templates: key, error of @C, error of @D (errors.inc names or "-"),
50060 REM    then the number of code lines and of cold lines, then the lines (AT&T syntax).
50065 REM    Operands are in %rax %rcx %rdx (i, p) and %xmm8 %xmm9 %xmm10 (f) in operand order,
50070 REM    the result in %rax or %xmm8 (rcount: its flag in %rcx). @C @D cold labels, @K the
50075 REM    icmp condition, @F @G @H @I the fcmp parts, @M the memory operand, @L the data
50080 REM    label, @U the first u field, @S the site index, @E the entry symbol in G(J), @0..@9 slot k.
50085 REM    Numeric labels 1-4 are template-local. A line ending in ":" is written unindented.
50090 REM    The cold lines precede movl code %edi, movq site %rsi, movq %rsp %rdx, call
50095 REM    sea_err. %r10 %r11 are free inside a template. Sentinel "-".
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
50300 DATA "eq","e","%xmm9, %xmm8","e","np","andb"
50305 DATA "ne","ne","%xmm9, %xmm8","ne","p","orb"
50310 DATA "lt","l","%xmm8, %xmm9","a","a","andb"
50315 DATA "le","le","%xmm8, %xmm9","ae","ae","andb"
50320 DATA "gt","g","%xmm9, %xmm8","a","a","andb"
50325 DATA "ge","ge","%xmm9, %xmm8","ae","ae","andb","-"
50400 DATA "%rdi","%rsi","%rdx","%rcx","%r8","%r9","-"
50405 DATA "%rax","%rdx","%rcx","%rsi","%rdi","%r8","%r9","-"
50500 REM ---- copies, wrapping integer arithmetic, bit operations ------------------------------
50505 DATA "mov","-","-",0,0
50510 DATA "iadd","-","-",1,0,"addq %rcx, %rax"
50515 DATA "isub","-","-",1,0,"subq %rcx, %rax"
50520 DATA "imul","-","-",1,0,"imulq %rcx, %rax"
50525 DATA "ineg","-","-",1,0,"negq %rax"
50530 REM imulh: the one-operand form, %rdx:%rax = %rax * %rcx
50535 DATA "imulh","-","-",2,0,"imulq %rcx","movq %rdx, %rax"
50540 DATA "iand","-","-",1,0,"andq %rcx, %rax"
50545 DATA "ior","-","-",1,0,"orq %rcx, %rax"
50550 DATA "ixor","-","-",1,0,"xorq %rcx, %rax"
50555 REM shifts: the count in %cl, masked to 6 bits as arm64's lsl / lsr / asr do
50560 DATA "ishl","-","-",1,0,"shlq %cl, %rax"
50565 DATA "ishr","-","-",1,0,"shrq %cl, %rax"
50570 DATA "isar","-","-",1,0,"sarq %cl, %rax"
50575 DATA "padd","-","-",1,0,"addq %rcx, %rax"
50580 DATA "bnot","-","-",3,0,"testq %rax, %rax","sete %al","movzbl %al, %eax"
50585 DATA "icmp","-","-",3,0,"cmpq %rcx, %rax","set@K %al","movzbl %al, %eax"
50590 DATA "isel","-","-",3,0,"testq %rax, %rax","movq %rdx, %rax","cmovneq %rcx, %rax"
50595 DATA "psel","-","-",3,0,"testq %rax, %rax","movq %rdx, %rax","cmovneq %rcx, %rax"
50597 DATA "fsel","-","-",4,0,"testq %rax, %rax","jne 1f","movapd %xmm9, %xmm8","1:"
50600 REM ---- checked integer arithmetic (LANGUAGE 6.5, 6.6): OF after the operation ---------
50605 DATA "iaddc","INT_OVERFLOW","-",2,0,"addq %rcx, %rax","jo @C"
50610 DATA "isubc","INT_OVERFLOW","-",2,0,"subq %rcx, %rax","jo @C"
50615 DATA "inegc","INT_OVERFLOW","-",2,0,"negq %rax","jo @C"
50620 DATA "imulc","INT_OVERFLOW","-",2,0,"imulq %rcx, %rax","jo @C"
50635 REM idivf: the checks before idivq (which faults on them): zero divisor, -2^63 / -1;
50640 REM the truncated quotient minus 1 when the remainder is not 0 and its sign differs from
50642 REM the divisor's (floored, LANGUAGE 6.6)
50645 DATA "idivf","INT_DIV_ZERO","INT_OVERFLOW",16,0,"testq %rcx, %rcx","je @C","cmpq $-1, %rcx"
50650 DATA "jne 1f","movabsq $0x8000000000000000, %rdx","cmpq %rdx, %rax","je @D","1:","cqto"
50655 DATA "idivq %rcx","testq %rdx, %rdx","je 2f","xorq %rcx, %rdx","jns 2f","subq $1, %rax"
50660 DATA "2:"
50665 REM imodf: divisor -1 gives 0 without idivq (-2^63 % -1 would fault); else the truncated
50670 REM remainder, plus the divisor when it is not 0 and the signs differ
50675 DATA "imodf","INT_DIV_ZERO","-",16,0,"testq %rcx, %rcx","je @C","cmpq $-1, %rcx","jne 1f"
50680 DATA "xorl %eax, %eax","jmp 2f","1:","cqto","idivq %rcx","movq %rdx, %rax"
50685 DATA "testq %rax, %rax","je 2f","xorq %rcx, %rdx","jns 2f","addq %rcx, %rax","2:"
50690 REM rcount: last = (n - 1) mod 2^64 in %rax (stored to d), the non-empty flag in %rcx
50695 REM (stored to e) for lo..hi step st (0) and lo..=hi step st (1), LANGUAGE 5.1, DESIGN 3.6.4:
50697 REM last = the distance (hi - lo - 1 or hi - lo, unsigned) divided by |st| with divq
50700 DATA "rcount0","RANGE_STEP_ZERO","-",27,0,"testq %rdx, %rdx","je @C","movq %rdx, %r10"
50705 DATA "js 1f","cmpq %rcx, %rax","jge 3f","subq %rax, %rcx","subq $1, %rcx","movq %rcx, %rax"
50710 DATA "xorl %edx, %edx","divq %r10","movl $1, %ecx","jmp 4f","1:","cmpq %rcx, %rax","jle 3f"
50715 DATA "subq %rcx, %rax","subq $1, %rax","negq %r10","xorl %edx, %edx","divq %r10"
50720 DATA "movl $1, %ecx","jmp 4f","3:","xorl %eax, %eax","xorl %ecx, %ecx","4:"
50725 DATA "rcount1","RANGE_STEP_ZERO","-",25,0,"testq %rdx, %rdx","je @C","movq %rdx, %r10"
50730 DATA "js 1f","cmpq %rcx, %rax","jg 3f","subq %rax, %rcx","movq %rcx, %rax","xorl %edx, %edx"
50735 DATA "divq %r10","movl $1, %ecx","jmp 4f","1:","cmpq %rcx, %rax","jl 3f","subq %rcx, %rax"
50740 DATA "negq %r10","xorl %edx, %edx","divq %r10","movl $1, %ecx","jmp 4f","3:"
50745 DATA "xorl %eax, %eax","xorl %ecx, %ecx","4:"
50800 REM ---- f64: one IEEE instruction each (DESIGN 3.6.4: no FMA, no contraction) ------------
50805 DATA "fadd","-","-",1,0,"addsd %xmm9, %xmm8"
50810 DATA "fsub","-","-",1,0,"subsd %xmm9, %xmm8"
50815 DATA "fmul","-","-",1,0,"mulsd %xmm9, %xmm8"
50820 DATA "fdiv","-","-",1,0,"divsd %xmm9, %xmm8"
50822 REM fneg / fabs: bit 63 flipped / cleared, never 0 - x (DESIGN 4.9.1)
50825 DATA "fneg","-","-",3,0,"movq %xmm8, %rax","btcq $63, %rax","movq %rax, %xmm8"
50830 DATA "fabs","-","-",3,0,"movq %xmm8, %rax","btrq $63, %rax","movq %rax, %xmm8"
50835 DATA "fsqrt","-","-",1,0,"sqrtsd %xmm8, %xmm8"
50837 REM ffloor fceil ftrunc fround (SSE2, DESIGN 4.9.1): NaN or |x| >= 2^52 is x; else
50838 REM t = the truncation through cvttsd2si / cvtsi2sdq, adjusted by 1.0; the result takes
50839 REM x's sign bit (so a zero result is -0.0 for a negative x, as frintm/p/z/a give)
50840 DATA "ffloor","-","-",20,0,"movq %xmm8, %rax","btrq $63, %rax"
50841 DATA "movabsq $0x4330000000000000, %rcx","cmpq %rcx, %rax","jae 1f","cvttsd2si %xmm8, %rax"
50842 DATA "cvtsi2sdq %rax, %xmm9","movabsq $0x3FF0000000000000, %rax","movq %rax, %xmm10"
50843 DATA "ucomisd %xmm8, %xmm9","jbe 2f","subsd %xmm10, %xmm9","2:","movq %xmm8, %rcx"
50844 DATA "shrq $63, %rcx","shlq $63, %rcx","movq %xmm9, %rax","orq %rcx, %rax"
50845 DATA "movq %rax, %xmm8","1:"
50850 DATA "fceil","-","-",20,0,"movq %xmm8, %rax","btrq $63, %rax"
50851 DATA "movabsq $0x4330000000000000, %rcx","cmpq %rcx, %rax","jae 1f","cvttsd2si %xmm8, %rax"
50852 DATA "cvtsi2sdq %rax, %xmm9","movabsq $0x3FF0000000000000, %rax","movq %rax, %xmm10"
50853 DATA "ucomisd %xmm9, %xmm8","jbe 2f","addsd %xmm10, %xmm9","2:","movq %xmm8, %rcx"
50854 DATA "shrq $63, %rcx","shlq $63, %rcx","movq %xmm9, %rax","orq %rcx, %rax"
50855 DATA "movq %rax, %xmm8","1:"
50860 DATA "ftrunc","-","-",14,0,"movq %xmm8, %rax","btrq $63, %rax"
50861 DATA "movabsq $0x4330000000000000, %rcx","cmpq %rcx, %rax","jae 1f","cvttsd2si %xmm8, %rax"
50862 DATA "cvtsi2sdq %rax, %xmm9","movq %xmm8, %rcx","shrq $63, %rcx","shlq $63, %rcx"
50863 DATA "movq %xmm9, %rax","orq %rcx, %rax","movq %rax, %xmm8","1:"
50865 REM fround: |x - t| >= 0.5 (x - t exact) adds sign(x) * 1.0: half away from zero (frinta)
50870 DATA "fround","-","-",29,0,"movq %xmm8, %rax","btrq $63, %rax"
50871 DATA "movabsq $0x4330000000000000, %rcx","cmpq %rcx, %rax","jae 1f","cvttsd2si %xmm8, %rax"
50872 DATA "cvtsi2sdq %rax, %xmm9","movapd %xmm8, %xmm10","subsd %xmm9, %xmm10"
50873 DATA "movq %xmm10, %rax","btrq $63, %rax","movabsq $0x3FE0000000000000, %rcx"
50874 DATA "cmpq %rcx, %rax","jb 2f","movabsq $0x3FF0000000000000, %rax","movq %xmm8, %rcx"
50875 DATA "shrq $63, %rcx","shlq $63, %rcx","orq %rcx, %rax","movq %rax, %xmm10"
50876 DATA "addsd %xmm10, %xmm9","2:","movq %xmm8, %rcx","shrq $63, %rcx","shlq $63, %rcx"
50877 DATA "movq %xmm9, %rax","orq %rcx, %rax","movq %rax, %xmm8","1:"
50880 REM fmin / fmax (LANGUAGE 10.4, DESIGN 4.9.1): a NaN first operand gives the second; else
50882 REM the second if it is strictly smaller / larger (an ordered comparison), else the first
50885 DATA "fmin","-","-",7,0,"ucomisd %xmm8, %xmm8","jp 1f","ucomisd %xmm9, %xmm8","jbe 2f","1:"
50887 DATA "movapd %xmm9, %xmm8","2:"
50890 DATA "fmax","-","-",7,0,"ucomisd %xmm8, %xmm8","jp 1f","ucomisd %xmm8, %xmm9","jbe 2f","1:"
50892 DATA "movapd %xmm9, %xmm8","2:"
50895 DATA "fcmp","-","-",5,0,"ucomisd @F","set@G %al","set@H %cl","@I %cl, %al"
50897 DATA "movzbl %al, %eax"
50900 DATA "fnan","-","-",3,0,"ucomisd %xmm8, %xmm8","setp %al","movzbl %al, %eax"
50905 DATA "itof","-","-",1,0,"cvtsi2sdq %rax, %xmm8"
50910 REM ftoi (LANGUAGE 4.2; DESIGN 4.9.1): the checks come first: NaN; |x| >= 2^63 except
50912 REM -2^63 itself; for |x| < 2^52 the truncation equals x; then cvttsd2si. The cold block
50914 REM passes x's bits as the f argument
50915 DATA "ftoi","CONV_I64","-",22,1,"ucomisd %xmm8, %xmm8","jp @C","movq %xmm8, %rax"
50920 DATA "btrq $63, %rax","movabsq $0x43E0000000000000, %rcx","cmpq %rcx, %rax","jb 1f"
50922 DATA "movq %xmm8, %rax","movabsq $0xC3E0000000000000, %rcx","cmpq %rcx, %rax","jne @C"
50924 DATA "jmp 2f","1:","movabsq $0x4330000000000000, %rcx","cmpq %rcx, %rax","jae 2f"
50926 DATA "cvttsd2si %xmm8, %rax","cvtsi2sdq %rax, %xmm9","ucomisd %xmm8, %xmm9","jne @C","2:"
50928 DATA "cvttsd2si %xmm8, %rax","movsd %xmm8, @0(%rsp)"
50930 REM ---- memory: @M is off(base, idx, scale), or (%r10) after base + idx * scale + off ----
50935 DATA "ldi","-","-",1,0,"movq @M, %rax"
50940 DATA "ldb","-","-",1,0,"movzbl @M, %eax"
50945 DATA "ldf","-","-",1,0,"movsd @M, %xmm8"
50950 DATA "ldp","-","-",1,0,"movq @M, %rax"
50955 DATA "sti","-","-",1,0,"movq %rax, @M"
50960 DATA "stb","-","-",1,0,"movb %al, @M"
50965 DATA "stf","-","-",1,0,"movsd %xmm8, @M"
50970 DATA "stp","-","-",1,0,"movq %rax, @M"
50975 DATA "la","-","-",1,0,"leaq @L(%rip), %rax"
50980 REM chkb (LANGUAGE 5.4): unsigned idx >= ext catches idx < 0; arguments idx, dim, ext
50985 DATA "chkb","INDEX_OOB","-",2,4,"cmpq %rcx, %rax","jae @C","movq %rax, @0(%rsp)"
50990 DATA "movq $@U, %rax","movq %rax, @1(%rsp)","movq %rcx, @2(%rsp)"
50991 REM ---- phase 4 (DESIGN 4.9, 4.9.1): counts at offset 0, a count of 0 is a static object;
50992 REM release calls @E, the symbol of entry FREE (sea_free), with %rsp = 0 mod 16
50993 DATA "retain","-","-",6,0,"movq (%rax), %rcx","testq %rcx, %rcx","je 1f","incq %rcx"
50994 DATA "movq %rcx, (%rax)","1:"
50995 DATA "release","-","-",9,0,"movq (%rax), %rcx","testq %rcx, %rcx","je 1f","decq %rcx"
50996 DATA "movq %rcx, (%rax)","jne 1f","movq %rax, %rdi","call @E","1:"
50997 REM mcopy d s n (n >= 0, no overlap): 8 bytes at a time, then single bytes, ascending
50998 DATA "mcopy","-","-",21,0,"cmpq $8, %rdx","jb 2f","1:","movq (%rcx), %r10","movq %r10, (%rax)"
50999 DATA "addq $8, %rcx","addq $8, %rax","subq $8, %rdx","cmpq $8, %rdx","jae 1b","2:"
51000 DATA "testq %rdx, %rdx","je 4f","3:","movzbl (%rcx), %r10d","movb %r10b, (%rax)","incq %rcx"
51001 DATA "incq %rax","decq %rdx","jne 3b","4:"
51005 DATA "-"
