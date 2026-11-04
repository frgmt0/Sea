# =====================================================================
# sea/tests/rt/x86_64_linux/rt_lib_kat.s -- the text entries on the known answers of
# rt_lib_kat.out (written by T1's tests/vectors/libL_cases.py from Python's int() and
# float(), independent of the runtime; DESIGN.md 2.15.8): 114 parse_i64, 206 parse_f64,
# 37 split and 34 substr cases. The program embeds only the inputs (the data section
# below was generated from rt_lib_kat.out's inputs), calls sea_parse_i64, sea_parse_f64,
# sea_split and sea_substr directly (site 0) and prints each result in the file's
# format: `parse_i64 B "T" V`, `parse_f64 "T" H` (the 64 bits, 16 lowercase hex digits;
# every NaN as 7ff8000000000000), `split "S" "P" C "F1" ...`, `substr "S" L H "R"`. Every
# result object is released: heap check, 0 live objects.
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# The bits of +Inf shifted left by one: |bits| << 1 above it is a NaN.
.equ INF2, 0xFFE0000000000000
.equ QNAN, 0x7FF8000000000000

# Append a literal text (caller-saved registers clobbered).
.macro TXT text
    leaq .Ltxt_s\@(%rip), %rdi
    movq $(.Ltxt_e\@ - .Ltxt_s\@), %rsi
    call sea_out_write
    .pushsection .rodata
.Ltxt_s\@: .ascii "\text"
.Ltxt_e\@:
    .popsection
.endm
# The release sequence of pass 4 (DESIGN.md 4.9) on the object in a register.
.macro REL reg
    movq \reg, %rdi
    movq SEA_OBJ_RC(%rdi), %rax
    testq %rax, %rax
    jz .Lrel\@
    decq %rax
    movq %rax, SEA_OBJ_RC(%rdi)
    jnz .Lrel\@
    call sea_free
.Lrel\@:
.endm

    .text
# put_dec -- append %rdi in signed decimal. Frame: 8 (%rbp) + 32 bytes of digits.
    .p2align 4
put_dec:
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp
    leaq 32(%rsp), %r8
    movq %rdi, %rax
    xorl %r9d, %r9d
    testq %rax, %rax
    jns 1f
    negq %rax                       # magnitude (2^63 exact as unsigned)
    movl $1, %r9d
1:  movl $10, %ecx
2:  xorl %edx, %edx
    divq %rcx
    addb $48, %dl
    decq %r8
    movb %dl, (%r8)
    testq %rax, %rax
    jnz 2b
    testl %r9d, %r9d
    jz 3f
    decq %r8
    movb $45, (%r8)
3:  movq %r8, %rdi
    leaq 32(%rsp), %rsi
    subq %r8, %rsi
    call sea_out_write
    movq %rbp, %rsp
    popq %rbp
    ret

# put_hex16 -- append %rdi as 16 lowercase hexadecimal digits. Frame: 8 + 16 bytes.
    .p2align 4
put_hex16:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp
    leaq .Lhexdig(%rip), %r8
    movl $16, %ecx
1:  movl %edi, %eax
    andl $15, %eax                  # the lowest digit, written right to left
    movb (%r8,%rax), %al
    decl %ecx
    movb %al, (%rsp,%rcx)
    shrq $4, %rdi
    testl %ecx, %ecx
    jnz 1b
    movq %rsp, %rdi
    movl $16, %esi
    call sea_out_write
    movq %rbp, %rsp
    popq %rbp
    ret

# put_q -- append ` "<bytes>"` for the string object %rdi. Callee-saved: %rbx.
    .p2align 4
put_q:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rdi, %rbx
    TXT " \""
    leaq SEA_STR_BYTES(%rbx), %rdi
    movq SEA_STR_LEN(%rbx), %rsi
    call sea_out_write
    TXT "\""
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# put_sp_dec -- append ` <%rdi in decimal>`. Callee-saved: %rbx.
    .p2align 4
put_sp_dec:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rdi, %rbx
    TXT " "
    movq %rbx, %rdi
    call put_dec
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# sea_main -- the four sections in order.
#   Callee-saved used: %rbx = the record, %r12 = a result object, %r13 = the
#   element index. Frame: %rbp %rbx %r12 %r13 + 8 pad.
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    # parse_i64: records {base, s}.
    leaq tab_pi(%rip), %rbx
1:  cmpq $0, 8(%rbx)
    je 2f
    TXT "parse_i64"
    movq 0(%rbx), %rdi
    call put_sp_dec
    movq 8(%rbx), %rdi
    call put_q
    movq 8(%rbx), %rdi
    movq 0(%rbx), %rsi
    xorl %edx, %edx
    call sea_parse_i64
    movq %rax, %rdi
    call put_sp_dec
    TXT "\n"
    addq $16, %rbx
    jmp 1b
    # parse_f64: records {s}.
2:  leaq tab_pf(%rip), %rbx
3:  cmpq $0, 0(%rbx)
    je 5f
    TXT "parse_f64"
    movq 0(%rbx), %rdi
    call put_q
    TXT " "
    movq 0(%rbx), %rdi
    xorl %esi, %esi
    call sea_parse_f64
    movq %xmm0, %rdi
    movq %rdi, %rax
    shlq $1, %rax
    movabsq $INF2, %rcx
    cmpq %rcx, %rax
    jbe 4f
    movabsq $QNAN, %rdi             # every NaN prints as Sea's nan
4:  call put_hex16
    TXT "\n"
    addq $8, %rbx
    jmp 3b
    # split: records {s, sep}.
5:  leaq tab_sp(%rip), %rbx
6:  cmpq $0, 0(%rbx)
    je 8f
    TXT "split"
    movq 0(%rbx), %rdi
    call put_q
    movq 8(%rbx), %rdi
    call put_q
    movq 0(%rbx), %rdi
    movq 8(%rbx), %rsi
    xorl %edx, %edx
    call sea_split
    movq %rax, %r12
    movq SEA_ARR_ROWS(%r12), %rdi
    call put_sp_dec
    xorl %r13d, %r13d
7:  cmpq SEA_ARR_ROWS(%r12), %r13
    jae 71f
    movq SEA_ARR_DATA(%r12), %rax
    movq (%rax,%r13,8), %rdi
    call put_q
    incq %r13
    jmp 7b
71: TXT "\n"
    REL %r12
    addq $16, %rbx
    jmp 6b
    # substr: records {s, lo, hi}.
8:  leaq tab_ss(%rip), %rbx
9:  cmpq $0, 0(%rbx)
    je 10f
    TXT "substr"
    movq 0(%rbx), %rdi
    call put_q
    movq 8(%rbx), %rdi
    call put_sp_dec
    movq 16(%rbx), %rdi
    call put_sp_dec
    movq 0(%rbx), %rdi
    movq 8(%rbx), %rsi
    movq 16(%rbx), %rdx
    xorl %ecx, %ecx
    call sea_substr
    movq %rax, %r12
    movq %r12, %rdi
    call put_q
    TXT "\n"
    REL %r12
    addq $24, %rbx
    jmp 9b
10: addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

    .section .rodata
.Lhexdig: .ascii "0123456789abcdef"

    .section .data.rel.ro,"aw",@progbits
    .p2align 3
tab_pi:                             # {base, s}
    .quad 2, .Ls0
    .quad 3, .Ls1
    .quad 4, .Ls2
    .quad 5, .Ls3
    .quad 6, .Ls4
    .quad 7, .Ls5
    .quad 8, .Ls6
    .quad 9, .Ls7
    .quad 10, .Ls8
    .quad 11, .Ls9
    .quad 12, .Ls10
    .quad 13, .Ls11
    .quad 14, .Ls12
    .quad 15, .Ls13
    .quad 16, .Ls14
    .quad 17, .Ls15
    .quad 18, .Ls16
    .quad 19, .Ls17
    .quad 20, .Ls18
    .quad 21, .Ls19
    .quad 22, .Ls20
    .quad 23, .Ls21
    .quad 24, .Ls22
    .quad 25, .Ls23
    .quad 26, .Ls24
    .quad 27, .Ls25
    .quad 28, .Ls26
    .quad 29, .Ls27
    .quad 30, .Ls28
    .quad 31, .Ls29
    .quad 32, .Ls30
    .quad 33, .Ls31
    .quad 34, .Ls32
    .quad 35, .Ls33
    .quad 36, .Ls34
    .quad 2, .Ls35
    .quad 2, .Ls36
    .quad 3, .Ls37
    .quad 3, .Ls38
    .quad 7, .Ls39
    .quad 7, .Ls40
    .quad 8, .Ls41
    .quad 8, .Ls42
    .quad 10, .Ls43
    .quad 10, .Ls44
    .quad 16, .Ls45
    .quad 16, .Ls46
    .quad 32, .Ls47
    .quad 32, .Ls48
    .quad 36, .Ls49
    .quad 36, .Ls50
    .quad 10, .Ls18
    .quad 10, .Ls51
    .quad 10, .Ls52
    .quad 10, .Ls53
    .quad 10, .Ls54
    .quad 10, .Ls55
    .quad 10, .Ls56
    .quad 10, .Ls57
    .quad 2, .Ls58
    .quad 10, .Ls59
    .quad 16, .Ls60
    .quad 16, .Ls61
    .quad 16, .Ls62
    .quad 16, .Ls63
    .quad 16, .Ls64
    .quad 16, .Ls65
    .quad 16, .Ls66
    .quad 16, .Ls67
    .quad 16, .Ls68
    .quad 16, .Ls69
    .quad 16, .Ls46
    .quad 16, .Ls70
    .quad 36, .Ls71
    .quad 36, .Ls72
    .quad 36, .Ls73
    .quad 36, .Ls74
    .quad 36, .Ls75
    .quad 36, .Ls76
    .quad 36, .Ls77
    .quad 36, .Ls78
    .quad 36, .Ls79
    .quad 36, .Ls49
    .quad 36, .Ls80
    .quad 10, .Ls43
    .quad 10, .Ls44
    .quad 10, .Ls81
    .quad 10, .Ls82
    .quad 10, .Ls83
    .quad 10, .Ls84
    .quad 10, .Ls85
    .quad 10, .Ls86
    .quad 2, .Ls87
    .quad 2, .Ls88
    .quad 2, .Ls35
    .quad 2, .Ls36
    .quad 8, .Ls89
    .quad 8, .Ls90
    .quad 8, .Ls41
    .quad 3, .Ls91
    .quad 3, .Ls92
    .quad 5, .Ls93
    .quad 35, .Ls94
    .quad 35, .Ls95
    .quad 9, .Ls96
    .quad 11, .Ls97
    .quad 11, .Ls98
    .quad 11, .Ls99
    .quad 12, .Ls100
    .quad 13, .Ls101
    .quad 17, .Ls102
    .quad 18, .Ls103
    .quad 20, .Ls104
    .quad 25, .Ls105
    .quad 0, 0
tab_pf:                             # {s}
    .quad .Ls106
    .quad .Ls107
    .quad .Ls108
    .quad .Ls109
    .quad .Ls110
    .quad .Ls111
    .quad .Ls112
    .quad .Ls113
    .quad .Ls18
    .quad .Ls51
    .quad .Ls52
    .quad .Ls114
    .quad .Ls115
    .quad .Ls116
    .quad .Ls117
    .quad .Ls118
    .quad .Ls119
    .quad .Ls120
    .quad .Ls121
    .quad .Ls122
    .quad .Ls123
    .quad .Ls124
    .quad .Ls85
    .quad .Ls84
    .quad .Ls125
    .quad .Ls126
    .quad .Ls127
    .quad .Ls128
    .quad .Ls129
    .quad .Ls130
    .quad .Ls131
    .quad .Ls132
    .quad .Ls133
    .quad .Ls134
    .quad .Ls135
    .quad .Ls136
    .quad .Ls137
    .quad .Ls138
    .quad .Ls139
    .quad .Ls140
    .quad .Ls141
    .quad .Ls142
    .quad .Ls143
    .quad .Ls144
    .quad .Ls145
    .quad .Ls146
    .quad .Ls147
    .quad .Ls148
    .quad .Ls149
    .quad .Ls150
    .quad .Ls151
    .quad .Ls152
    .quad .Ls153
    .quad .Ls154
    .quad .Ls155
    .quad .Ls156
    .quad .Ls157
    .quad .Ls158
    .quad .Ls159
    .quad .Ls160
    .quad .Ls161
    .quad .Ls162
    .quad .Ls163
    .quad .Ls164
    .quad .Ls165
    .quad .Ls166
    .quad .Ls167
    .quad .Ls168
    .quad .Ls169
    .quad .Ls170
    .quad .Ls171
    .quad .Ls172
    .quad .Ls173
    .quad .Ls174
    .quad .Ls175
    .quad .Ls176
    .quad .Ls177
    .quad .Ls178
    .quad .Ls179
    .quad .Ls180
    .quad .Ls181
    .quad .Ls182
    .quad .Ls183
    .quad .Ls184
    .quad .Ls185
    .quad .Ls186
    .quad .Ls187
    .quad .Ls188
    .quad .Ls189
    .quad .Ls190
    .quad .Ls191
    .quad .Ls192
    .quad .Ls193
    .quad .Ls194
    .quad .Ls195
    .quad .Ls196
    .quad .Ls197
    .quad .Ls198
    .quad .Ls199
    .quad .Ls200
    .quad .Ls201
    .quad .Ls202
    .quad .Ls203
    .quad .Ls204
    .quad .Ls205
    .quad .Ls206
    .quad .Ls207
    .quad .Ls208
    .quad .Ls209
    .quad .Ls210
    .quad .Ls211
    .quad .Ls212
    .quad .Ls213
    .quad .Ls214
    .quad .Ls215
    .quad .Ls216
    .quad .Ls217
    .quad .Ls218
    .quad .Ls219
    .quad .Ls220
    .quad .Ls221
    .quad .Ls222
    .quad .Ls223
    .quad .Ls224
    .quad .Ls225
    .quad .Ls226
    .quad .Ls227
    .quad .Ls228
    .quad .Ls229
    .quad .Ls230
    .quad .Ls231
    .quad .Ls232
    .quad .Ls233
    .quad .Ls234
    .quad .Ls235
    .quad .Ls236
    .quad .Ls237
    .quad .Ls238
    .quad .Ls239
    .quad .Ls240
    .quad .Ls241
    .quad .Ls242
    .quad .Ls243
    .quad .Ls244
    .quad .Ls245
    .quad .Ls246
    .quad .Ls247
    .quad .Ls248
    .quad .Ls249
    .quad .Ls250
    .quad .Ls251
    .quad .Ls252
    .quad .Ls253
    .quad .Ls254
    .quad .Ls255
    .quad .Ls256
    .quad .Ls257
    .quad .Ls258
    .quad .Ls259
    .quad .Ls260
    .quad .Ls261
    .quad .Ls262
    .quad .Ls263
    .quad .Ls264
    .quad .Ls265
    .quad .Ls266
    .quad .Ls267
    .quad .Ls268
    .quad .Ls269
    .quad .Ls270
    .quad .Ls271
    .quad .Ls272
    .quad .Ls273
    .quad .Ls274
    .quad .Ls275
    .quad .Ls276
    .quad .Ls277
    .quad .Ls278
    .quad .Ls279
    .quad .Ls280
    .quad .Ls281
    .quad .Ls282
    .quad .Ls283
    .quad .Ls284
    .quad .Ls285
    .quad .Ls286
    .quad .Ls287
    .quad .Ls288
    .quad .Ls289
    .quad .Ls290
    .quad .Ls291
    .quad .Ls292
    .quad .Ls293
    .quad .Ls294
    .quad .Ls295
    .quad .Ls296
    .quad .Ls297
    .quad .Ls298
    .quad .Ls299
    .quad .Ls300
    .quad .Ls301
    .quad .Ls302
    .quad .Ls303
    .quad .Ls304
    .quad .Ls305
    .quad .Ls306
    .quad 0
tab_sp:                             # {s, sep}
    .quad .Ls307, .Ls308
    .quad .Ls309, .Ls308
    .quad .Ls310, .Ls308
    .quad .Ls311, .Ls308
    .quad .Ls312, .Ls313
    .quad .Ls314, .Ls315
    .quad .Ls316, .Ls317
    .quad .Ls318, .Ls317
    .quad .Ls319, .Ls317
    .quad .Ls317, .Ls317
    .quad .Ls320, .Ls320
    .quad .Ls311, .Ls311
    .quad .Ls311, .Ls321
    .quad .Ls322, .Ls311
    .quad .Ls310, .Ls311
    .quad .Ls323, .Ls322
    .quad .Ls324, .Ls325
    .quad .Ls326, .Ls327
    .quad .Ls328, .Ls327
    .quad .Ls329, .Ls327
    .quad .Ls330, .Ls331
    .quad .Ls332, .Ls331
    .quad .Ls333, .Ls334
    .quad .Ls335, .Ls336
    .quad .Ls337, .Ls313
    .quad .Ls338, .Ls313
    .quad .Ls339, .Ls317
    .quad .Ls340, .Ls341
    .quad .Ls342, .Ls343
    .quad .Ls344, .Ls315
    .quad .Ls345, .Ls315
    .quad .Ls315, .Ls315
    .quad .Ls346, .Ls315
    .quad .Ls347, .Ls348
    .quad .Ls349, .Ls348
    .quad .Ls350, .Ls348
    .quad .Ls351, .Ls352
    .quad 0, 0
tab_ss:                             # {s, lo, hi}
    .quad .Ls353, 0, 5
    .quad .Ls353, 0, 1
    .quad .Ls353, 4, 5
    .quad .Ls353, 1, 4
    .quad .Ls353, 2, 2
    .quad .Ls353, 3, 3
    .quad .Ls353, 0, 0
    .quad .Ls353, 5, 5
    .quad .Ls353, 4, 2
    .quad .Ls353, 9, 2
    .quad .Ls353, -3, -5
    .quad .Ls353, 100, -100
    .quad .Ls353, 2, 1
    .quad .Ls310, 0, 0
    .quad .Ls310, 3, 1
    .quad .Ls310, 5, 5
    .quad .Ls354, 1, 4
    .quad .Ls354, 0, 1
    .quad .Ls354, 4, 5
    .quad .Ls97, 0, 1
    .quad .Ls97, 0, 0
    .quad .Ls322, 0, 2
    .quad .Ls322, 1, 2
    .quad .Ls322, 0, 1
    .quad .Ls322, 2, 0
    .quad .Ls151, 0, 10
    .quad .Ls151, 11, 17
    .quad .Ls340, 9, 17
    .quad .Ls355, 2, 4
    .quad .Ls355, 6, 8
    .quad .Ls356, 1, 2
    .quad .Ls357, 2, 3
    .quad .Ls311, 1, 1
    .quad .Ls311, 7, 7
    .quad 0, 0, 0
# The texts: static string objects (count SEA_RC_STATIC).
    .p2align 3
.Ls0:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 42
    .ascii "111100010100001010100100001110101100011011"
    .p2align 3
.Ls1:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 36
    .ascii "101121222222012010201100021211000002"
    .p2align 3
.Ls2:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 14
    .ascii "32103203210301"
    .p2align 3
.Ls3:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 15
    .ascii "222234313224244"
    .p2align 3
.Ls4:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "41334"
    .p2align 3
.Ls5:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "10004120601041065356132"
    .p2align 3
.Ls6:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 15
    .ascii "317764057136675"
    .p2align 3
.Ls7:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 7
    .ascii "1351545"
    .p2align 3
.Ls8:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 9
    .ascii "106367170"
    .p2align 3
.Ls9:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 9
    .ascii "5a4156448"
    .p2align 3
.Ls10:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 17
    .ascii "1009108781439b14a"
    .p2align 3
.Ls11:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 15
    .ascii "228a05029899266"
    .p2align 3
.Ls12:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "5"
    .p2align 3
.Ls13:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "e0621e"
    .p2align 3
.Ls14:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "14b957"
    .p2align 3
.Ls15:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "56cga1"
    .p2align 3
.Ls16:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 10
    .ascii "2c40bd5hh0"
    .p2align 3
.Ls17:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 9
    .ascii "3hd256d93"
    .p2align 3
.Ls18:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "0"
    .p2align 3
.Ls19:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "6k7gc"
    .p2align 3
.Ls20:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 7
    .ascii "gh3k839"
    .p2align 3
.Ls21:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 14
    .ascii "6i17j7i7a793ih"
    .p2align 3
.Ls22:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 13
    .ascii "5e6aal18de5k3"
    .p2align 3
.Ls23:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 11
    .ascii "2hdhlhm7d75"
    .p2align 3
.Ls24:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "45075"
    .p2align 3
.Ls25:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 11
    .ascii "kdmaioj6ep9"
    .p2align 3
.Ls26:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 9
    .ascii "8e0on8if5"
    .p2align 3
.Ls27:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 8
    .ascii "133amrhq"
    .p2align 3
.Ls28:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 13
    .ascii "6betmo7bd7201"
    .p2align 3
.Ls29:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "lnfer"
    .p2align 3
.Ls30:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 7
    .ascii "6j34gb0"
    .p2align 3
.Ls31:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "3um"
    .p2align 3
.Ls32:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 10
    .ascii "3jxcnh5n2o"
    .p2align 3
.Ls33:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 11
    .ascii "lc0bf6l4sh6"
    .p2align 3
.Ls34:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 12
    .ascii "44ea1fnpj3vh"
    .p2align 3
.Ls35:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 63
    .ascii "111111111111111111111111111111111111111111111111111111111111111"
    .p2align 3
.Ls36:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 65
    .ascii "-100000000000000000000000000000000000000000000000000000000000000"
    .ascii "0"
    .p2align 3
.Ls37:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 40
    .ascii "2021110011022210012102010021220101220221"
    .p2align 3
.Ls38:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 41
    .ascii "-2021110011022210012102010021220101220222"
    .p2align 3
.Ls39:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "22341010611245052052300"
    .p2align 3
.Ls40:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 24
    .ascii "-22341010611245052052301"
    .p2align 3
.Ls41:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 21
    .ascii "777777777777777777777"
    .p2align 3
.Ls42:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "-1000000000000000000000"
    .p2align 3
.Ls43:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 19
    .ascii "9223372036854775807"
    .p2align 3
.Ls44:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 20
    .ascii "-9223372036854775808"
    .p2align 3
.Ls45:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 16
    .ascii "7fffffffffffffff"
    .p2align 3
.Ls46:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 17
    .ascii "-8000000000000000"
    .p2align 3
.Ls47:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 13
    .ascii "7vvvvvvvvvvvv"
    .p2align 3
.Ls48:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 14
    .ascii "-8000000000000"
    .p2align 3
.Ls49:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 13
    .ascii "1y2p0ij32e8e7"
    .p2align 3
.Ls50:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 14
    .ascii "-1y2p0ij32e8e8"
    .p2align 3
.Ls51:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "-0"
    .p2align 3
.Ls52:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "+0"
    .p2align 3
.Ls53:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "+5"
    .p2align 3
.Ls54:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "-5"
    .p2align 3
.Ls55:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "007"
    .p2align 3
.Ls56:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "-007"
    .p2align 3
.Ls57:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "+007"
    .p2align 3
.Ls58:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 71
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000001"
    .p2align 3
.Ls59:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 43
    .ascii "0000000000000000000000000000000000000000123"
    .p2align 3
.Ls60:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 32
    .ascii "000000000000000000000000000000ff"
    .p2align 3
.Ls61:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 32
    .ascii "-0000000000000000000000000000001"
    .p2align 3
.Ls62:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "ff"
    .p2align 3
.Ls63:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "FF"
    .p2align 3
.Ls64:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "Ff"
    .p2align 3
.Ls65:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "fF"
    .p2align 3
.Ls66:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 8
    .ascii "deadBEEF"
    .p2align 3
.Ls67:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 8
    .ascii "18FF50E5"
    .p2align 3
.Ls68:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 9
    .ascii "-DEADbeef"
    .p2align 3
.Ls69:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 17
    .ascii "+7fffffffffffffff"
    .p2align 3
.Ls70:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 16
    .ascii "7FFFFFFFFFFFFFFF"
    .p2align 3
.Ls71:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "zz"
    .p2align 3
.Ls72:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "ZZ"
    .p2align 3
.Ls73:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "Zz"
    .p2align 3
.Ls74:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "zZ"
    .p2align 3
.Ls75:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "z"
    .p2align 3
.Ls76:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "Z"
    .p2align 3
.Ls77:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "0z"
    .p2align 3
.Ls78:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "-a"
    .p2align 3
.Ls79:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "+A"
    .p2align 3
.Ls80:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 14
    .ascii "-1Y2P0IJ32E8E8"
    .p2align 3
.Ls81:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 20
    .ascii "+9223372036854775807"
    .p2align 3
.Ls82:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 19
    .ascii "1000000000000000000"
    .p2align 3
.Ls83:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 18
    .ascii "999999999999999999"
    .p2align 3
.Ls84:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "-1"
    .p2align 3
.Ls85:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "1"
    .p2align 3
.Ls86:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "-123"
    .p2align 3
.Ls87:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "101"
    .p2align 3
.Ls88:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "-101"
    .p2align 3
.Ls89:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "777"
    .p2align 3
.Ls90:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 8
    .ascii "-1000000"
    .p2align 3
.Ls91:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "2"
    .p2align 3
.Ls92:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "-2222"
    .p2align 3
.Ls93:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "4"
    .p2align 3
.Ls94:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "y"
    .p2align 3
.Ls95:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "Y"
    .p2align 3
.Ls96:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "88888"
    .p2align 3
.Ls97:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "a"
    .p2align 3
.Ls98:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "A"
    .p2align 3
.Ls99:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "-aaaa"
    .p2align 3
.Ls100:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "b9"
    .p2align 3
.Ls101:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "C"
    .p2align 3
.Ls102:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "g"
    .p2align 3
.Ls103:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "H"
    .p2align 3
.Ls104:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "j"
    .p2align 3
.Ls105:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "o"
    .p2align 3
.Ls106:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "inf"
    .p2align 3
.Ls107:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "Inf"
    .p2align 3
.Ls108:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "+inf"
    .p2align 3
.Ls109:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "+Inf"
    .p2align 3
.Ls110:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "-inf"
    .p2align 3
.Ls111:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "-Inf"
    .p2align 3
.Ls112:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "nan"
    .p2align 3
.Ls113:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "NaN"
    .p2align 3
.Ls114:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "0.0"
    .p2align 3
.Ls115:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "-0.0"
    .p2align 3
.Ls116:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "00"
    .p2align 3
.Ls117:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 7
    .ascii "000.000"
    .p2align 3
.Ls118:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "0e0"
    .p2align 3
.Ls119:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "-0e-5"
    .p2align 3
.Ls120:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "0e+400"
    .p2align 3
.Ls121:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii ".0"
    .p2align 3
.Ls122:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "0."
    .p2align 3
.Ls123:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "-.0"
    .p2align 3
.Ls124:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "+.0e9"
    .p2align 3
.Ls125:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "+1"
    .p2align 3
.Ls126:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "1.5"
    .p2align 3
.Ls127:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "-1.5"
    .p2align 3
.Ls128:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii ".5"
    .p2align 3
.Ls129:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "-.5"
    .p2align 3
.Ls130:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "5."
    .p2align 3
.Ls131:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "-5."
    .p2align 3
.Ls132:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "+5."
    .p2align 3
.Ls133:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "1e3"
    .p2align 3
.Ls134:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "1E3"
    .p2align 3
.Ls135:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "1e+3"
    .p2align 3
.Ls136:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "1e-3"
    .p2align 3
.Ls137:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "1E-3"
    .p2align 3
.Ls138:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "+2.5"
    .p2align 3
.Ls139:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 7
    .ascii "-2.5e+2"
    .p2align 3
.Ls140:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "5e-1"
    .p2align 3
.Ls141:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii ".5e1"
    .p2align 3
.Ls142:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "5.e2"
    .p2align 3
.Ls143:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "0.1"
    .p2align 3
.Ls144:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "0.2"
    .p2align 3
.Ls145:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "0.3"
    .p2align 3
.Ls146:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "000123"
    .p2align 3
.Ls147:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 8
    .ascii "0.000001"
    .p2align 3
.Ls148:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 9
    .ascii "123456789"
    .p2align 3
.Ls149:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "3.14159265358979323846"
    .p2align 3
.Ls150:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 17
    .ascii "2.718281828459045"
    .p2align 3
.Ls151:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 17
    .ascii "1700000000.123456"
    .p2align 3
.Ls152:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "1e22"
    .p2align 3
.Ls153:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "1e23"
    .p2align 3
.Ls154:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "8.5e-5"
    .p2align 3
.Ls155:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "4.35"
    .p2align 3
.Ls156:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "5e-324"
    .p2align 3
.Ls157:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "1e-323"
    .p2align 3
.Ls158:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 16
    .ascii "9007199254740992"
    .p2align 3
.Ls159:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 16
    .ascii "9007199254740993"
    .p2align 3
.Ls160:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 16
    .ascii "9007199254740994"
    .p2align 3
.Ls161:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 16
    .ascii "9007199254740995"
    .p2align 3
.Ls162:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 16
    .ascii "9007199254740996"
    .p2align 3
.Ls163:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 24
    .ascii "9007199254740993.0000001"
    .p2align 3
.Ls164:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 24
    .ascii "9007199254740992.9999999"
    .p2align 3
.Ls165:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 18
    .ascii "9007199254740993.5"
    .p2align 3
.Ls166:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 18
    .ascii "9007199254740992.5"
    .p2align 3
.Ls167:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 17
    .ascii "18014398509481985"
    .p2align 3
.Ls168:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 17
    .ascii "18014398509481986"
    .p2align 3
.Ls169:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 17
    .ascii "18014398509481987"
    .p2align 3
.Ls170:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 17
    .ascii "18014398509481984"
    .p2align 3
.Ls171:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 55
    .ascii "1.00000000000000011102230246251565404236316680908203125"
    .p2align 3
.Ls172:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 56
    .ascii "1.000000000000000111022302462515654042363166809082031251"
    .p2align 3
.Ls173:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 56
    .ascii "-1.00000000000000011102230246251565404236316680908203125"
    .p2align 3
.Ls174:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 55
    .ascii "1.50000000000000011102230246251565404236316680908203125"
    .p2align 3
.Ls175:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 56
    .ascii "1.500000000000000111022302462515654042363166809082031251"
    .p2align 3
.Ls176:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 56
    .ascii "-1.50000000000000011102230246251565404236316680908203125"
    .p2align 3
.Ls177:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 54
    .ascii "3.1415926535897933380425683935754932463169097900390625"
    .p2align 3
.Ls178:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 55
    .ascii "3.14159265358979333804256839357549324631690979003906251"
    .p2align 3
.Ls179:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 55
    .ascii "-3.1415926535897933380425683935754932463169097900390625"
    .p2align 3
.Ls180:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 37
    .ascii "123456789.000000007450580596923828125"
    .p2align 3
.Ls181:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 38
    .ascii "123456789.0000000074505805969238281251"
    .p2align 3
.Ls182:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 38
    .ascii "-123456789.000000007450580596923828125"
    .p2align 3
.Ls183:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 59
    .ascii "0.100000000000000012490009027033011079765856266021728515625"
    .p2align 3
.Ls184:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 60
    .ascii "0.1000000000000000124900090270330110797658562660217285156251"
    .p2align 3
.Ls185:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 60
    .ascii "-0.100000000000000012490009027033011079765856266021728515625"
    .p2align 3
.Ls186:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 31
    .ascii "1267650600228229542234191560704"
    .p2align 3
.Ls187:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 32
    .ascii "12676506002282295422341915607041"
    .p2align 3
.Ls188:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 32
    .ascii "-1267650600228229542234191560704"
    .p2align 3
.Ls189:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "10000000000000001048576"
    .p2align 3
.Ls190:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 24
    .ascii "100000000000000010485761"
    .p2align 3
.Ls191:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 24
    .ascii "-10000000000000001048576"
    .p2align 3
.Ls192:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 89
    .ascii "0.00000000010000000000000001010556826712030286784943511335654875"
    .ascii "4381947219371795654296875"
    .p2align 3
.Ls193:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 90
    .ascii "0.00000000010000000000000001010556826712030286784943511335654875"
    .ascii "43819472193717956542968751"
    .p2align 3
.Ls194:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 90
    .ascii "-0.0000000001000000000000000101055682671203028678494351133565487"
    .ascii "54381947219371795654296875"
    .p2align 3
.Ls195:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 301
    .ascii "1000000000000000126855605679093573388607593488603187161478864198"
    .ascii "4815254107775011615834042331006665413021201686407014076668787127"
    .ascii "4500908309837405446203199237238991625604630709288637225616778178"
    .ascii "7193689444949857643457040908156539501183462088086674146902434205"
    .ascii "806252960993440370942179392028053726841274368"
    .p2align 3
.Ls196:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 302
    .ascii "1000000000000000126855605679093573388607593488603187161478864198"
    .ascii "4815254107775011615834042331006665413021201686407014076668787127"
    .ascii "4500908309837405446203199237238991625604630709288637225616778178"
    .ascii "7193689444949857643457040908156539501183462088086674146902434205"
    .ascii "8062529609934403709421793920280537268412743681"
    .p2align 3
.Ls197:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 302
    .ascii "-100000000000000012685560567909357338860759348860318716147886419"
    .ascii "8481525410777501161583404233100666541302120168640701407666878712"
    .ascii "7450090830983740544620319923723899162560463070928863722561677817"
    .ascii "8719368944494985764345704090815653950118346208808667414690243420"
    .ascii "5806252960993440370942179392028053726841274368"
    .p2align 3
.Ls198:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1077
    .ascii "0.00000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000074109846876186981626485318930233205854758970392148714663837"
    .ascii "8523751013260905313127797949754542453988569694847043168576596389"
    .ascii "9850655339096945981621940161728171894510697854671067917687257517"
    .ascii "7347315553307795408549809608457500958111373034747658096871009590"
    .ascii "9754422710047573078097111189357848386756539987835030152280559340"
    .ascii "4659373979179073872386829939581848166016912201945649993128979841"
    .ascii "1362062484498678713572180352209017023903285791732520220528974020"
    .ascii "8029068540216066123755499834026713000358124864790413857434018755"
    .ascii "2090159017259254714629617513415977493871857473787096164563890871"
    .ascii "8119841271673056017045493004705269590165763776884908267986972573"
    .ascii "3665217655679410725087643375608460039849049721491174630855395563"
    .ascii "54188641513168478436313080237596295773983001708984375"
    .p2align 3
.Ls199:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1078
    .ascii "0.00000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000074109846876186981626485318930233205854758970392148714663837"
    .ascii "8523751013260905313127797949754542453988569694847043168576596389"
    .ascii "9850655339096945981621940161728171894510697854671067917687257517"
    .ascii "7347315553307795408549809608457500958111373034747658096871009590"
    .ascii "9754422710047573078097111189357848386756539987835030152280559340"
    .ascii "4659373979179073872386829939581848166016912201945649993128979841"
    .ascii "1362062484498678713572180352209017023903285791732520220528974020"
    .ascii "8029068540216066123755499834026713000358124864790413857434018755"
    .ascii "2090159017259254714629617513415977493871857473787096164563890871"
    .ascii "8119841271673056017045493004705269590165763776884908267986972573"
    .ascii "3665217655679410725087643375608460039849049721491174630855395563"
    .ascii "541886415131684784363130802375962957739830017089843751"
    .p2align 3
.Ls200:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1078
    .ascii "-0.0000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000007410984687618698162648531893023320585475897039214871466383"
    .ascii "7852375101326090531312779794975454245398856969484704316857659638"
    .ascii "9985065533909694598162194016172817189451069785467106791768725751"
    .ascii "7734731555330779540854980960845750095811137303474765809687100959"
    .ascii "0975442271004757307809711118935784838675653998783503015228055934"
    .ascii "0465937397917907387238682993958184816601691220194564999312897984"
    .ascii "1136206248449867871357218035220901702390328579173252022052897402"
    .ascii "0802906854021606612375549983402671300035812486479041385743401875"
    .ascii "5209015901725925471462961751341597749387185747378709616456389087"
    .ascii "1811984127167305601704549300470526959016576377688490826798697257"
    .ascii "3366521765567941072508764337560846003984904972149117463085539556"
    .ascii "354188641513168478436313080237596295773983001708984375"
    .p2align 3
.Ls201:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1077
    .ascii "0.00000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0250021920077962813680552637630963425485338513112979047037567634"
    .ascii "6294668404540891388814349821908058939437960515641303054577354346"
    .ascii "2827562333396759998552125616942581447590995708626131637577778997"
    .ascii "7393571676065776644207682399455732348402161560349199477162690087"
    .ascii "4837416130495707806954115830261174120980405626113390410513694951"
    .ascii "9174681090468887475701939502628429419056131963974526819468324046"
    .ascii "5144801870375753354679114902487099641718499374945717324582021515"
    .ascii "4067565175601746176471273394787425541527252181259550363234607156"
    .ascii "8166471226972322255452951094369405159023164066400093850379837869"
    .ascii "6971170200999982839144900207344507355898395284052193432049805014"
    .ascii "1889297710438649537346201511074687770744077070726146295819499535"
    .ascii "81080251592723417974895028237369842827320098876953125"
    .p2align 3
.Ls202:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1078
    .ascii "0.00000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0250021920077962813680552637630963425485338513112979047037567634"
    .ascii "6294668404540891388814349821908058939437960515641303054577354346"
    .ascii "2827562333396759998552125616942581447590995708626131637577778997"
    .ascii "7393571676065776644207682399455732348402161560349199477162690087"
    .ascii "4837416130495707806954115830261174120980405626113390410513694951"
    .ascii "9174681090468887475701939502628429419056131963974526819468324046"
    .ascii "5144801870375753354679114902487099641718499374945717324582021515"
    .ascii "4067565175601746176471273394787425541527252181259550363234607156"
    .ascii "8166471226972322255452951094369405159023164066400093850379837869"
    .ascii "6971170200999982839144900207344507355898395284052193432049805014"
    .ascii "1889297710438649537346201511074687770744077070726146295819499535"
    .ascii "810802515927234179748950282373698428273200988769531251"
    .p2align 3
.Ls203:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1078
    .ascii "-0.0000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0025002192007796281368055263763096342548533851311297904703756763"
    .ascii "4629466840454089138881434982190805893943796051564130305457735434"
    .ascii "6282756233339675999855212561694258144759099570862613163757777899"
    .ascii "7739357167606577664420768239945573234840216156034919947716269008"
    .ascii "7483741613049570780695411583026117412098040562611339041051369495"
    .ascii "1917468109046888747570193950262842941905613196397452681946832404"
    .ascii "6514480187037575335467911490248709964171849937494571732458202151"
    .ascii "5406756517560174617647127339478742554152725218125955036323460715"
    .ascii "6816647122697232225545295109436940515902316406640009385037983786"
    .ascii "9697117020099998283914490020734450735589839528405219343204980501"
    .ascii "4188929771043864953734620151107468777074407707072614629581949953"
    .ascii "581080251592723417974895028237369842827320098876953125"
    .p2align 3
.Ls204:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "2.2250738585072011e-308"
    .p2align 3
.Ls205:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "2.2250738585072012e-308"
    .p2align 3
.Ls206:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "2.2250738585072014e-308"
    .p2align 3
.Ls207:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "2.2250738585072013e-308"
    .p2align 3
.Ls208:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "2.225073858507201e-308"
    .p2align 3
.Ls209:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "2.2250738585072009e-308"
    .p2align 3
.Ls210:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1077
    .ascii "0.00000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000022250738585"
    .ascii "0720113605740979670913197593481954635164564802342610972482222202"
    .ascii "1076945516529523908135087914149158913039621106870086438694594645"
    .ascii "5276572074078206217433799881410632673292535522868813721490129811"
    .ascii "2245145188984905722230728525513315575501591439747639798341180199"
    .ascii "9323962548289017107081850690630666655994938275772572015763062690"
    .ascii "6633326475653000092458883164330377797918696120494973903778297049"
    .ascii "0505108060994073026293712895895000358379996720725430436028407889"
    .ascii "5771796150945516748243471030702609144621572289880258182545180325"
    .ascii "7070188608721131280795122334262883686223215037756666225039825343"
    .ascii "3597456888442390026549819838548794829220689472168983109969836584"
    .ascii "6814022854243330660339850886445804001034933970427567186443383770"
    .ascii "48603786162277173854562306587467901408672332763671875"
    .p2align 3
.Ls211:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "4.9406564584124654e-324"
    .p2align 3
.Ls212:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "4.9406564584124653e-324"
    .p2align 3
.Ls213:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "2.4703282292062328e-324"
    .p2align 3
.Ls214:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "2.4703282292062327e-324"
    .p2align 3
.Ls215:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "2.4703282292062326e-324"
    .p2align 3
.Ls216:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 24
    .ascii "-2.4703282292062327e-324"
    .p2align 3
.Ls217:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "2.4703282292062329e-324"
    .p2align 3
.Ls218:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "7.4109846876186982e-324"
    .p2align 3
.Ls219:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "7.4109846876186981e-324"
    .p2align 3
.Ls220:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "1e-324"
    .p2align 3
.Ls221:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "3e-324"
    .p2align 3
.Ls222:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "1e-400"
    .p2align 3
.Ls223:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 14
    .ascii "123456789e-410"
    .p2align 3
.Ls224:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 7
    .ascii "-1e-400"
    .p2align 3
.Ls225:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1077
    .ascii "0.00000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000024703282292062327208828439643411068618252990130716238221279"
    .ascii "2841250337753635104375932649918180817996189898282347722858865463"
    .ascii "3283551779698981993873980053909390631503565951557022639229085839"
    .ascii "2449105184435931802849936536152500319370457678249219365623669863"
    .ascii "6584807570015857692699037063119282795585513329278343384093519780"
    .ascii "1553124659726357957462276646527282722005637400648549997709659947"
    .ascii "0454020828166226237857393450736339007967761930577506740176324673"
    .ascii "6009689513405355374585166611342237666786041621596804619144672918"
    .ascii "4030053005753084904876539171138659164623952491262365388187963623"
    .ascii "9373280423891018672348497668235089863388587925628302755995657524"
    .ascii "4555072551893136908362547791869486679949683240497058210285131854"
    .ascii "51396213837722826145437693412532098591327667236328125"
    .p2align 3
.Ls226:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1078
    .ascii "0.00000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000024703282292062327208828439643411068618252990130716238221279"
    .ascii "2841250337753635104375932649918180817996189898282347722858865463"
    .ascii "3283551779698981993873980053909390631503565951557022639229085839"
    .ascii "2449105184435931802849936536152500319370457678249219365623669863"
    .ascii "6584807570015857692699037063119282795585513329278343384093519780"
    .ascii "1553124659726357957462276646527282722005637400648549997709659947"
    .ascii "0454020828166226237857393450736339007967761930577506740176324673"
    .ascii "6009689513405355374585166611342237666786041621596804619144672918"
    .ascii "4030053005753084904876539171138659164623952491262365388187963623"
    .ascii "9373280423891018672348497668235089863388587925628302755995657524"
    .ascii "4555072551893136908362547791869486679949683240497058210285131854"
    .ascii "513962138377228261454376934125320985913276672363281251"
    .p2align 3
.Ls227:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "1.7976931348623158e308"
    .p2align 3
.Ls228:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "1.7976931348623159e308"
    .p2align 3
.Ls229:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "1.7976931348623157e308"
    .p2align 3
.Ls230:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "1.7976931348623160e308"
    .p2align 3
.Ls231:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "-1.7976931348623159e308"
    .p2align 3
.Ls232:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 7
    .ascii "1.8e308"
    .p2align 3
.Ls233:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "1e309"
    .p2align 3
.Ls234:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "1e308"
    .p2align 3
.Ls235:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 309
    .ascii "1797693134862315807937289714053034150799341327100378269361737789"
    .ascii "8044496829276475094664901797758720709633028641669288791094655554"
    .ascii "7851940402630657488671505820681908902000708383676273854845817711"
    .ascii "5317644757302700698555713669596228429148198608349364752927190741"
    .ascii "68444365510704342711559699508093042880177904174497792"
    .p2align 3
.Ls236:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 309
    .ascii "1797693134862315807937289714053034150799341327100378269361737789"
    .ascii "8044496829276475094664901797758720709633028641669288791094655554"
    .ascii "7851940402630657488671505820681908902000708383676273854845817711"
    .ascii "5317644757302700698555713669596228429148198608349364752927190741"
    .ascii "68444365510704342711559699508093042880177904174497791"
    .p2align 3
.Ls237:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 311
    .ascii "1797693134862315807937289714053034150799341327100378269361737789"
    .ascii "8044496829276475094664901797758720709633028641669288791094655554"
    .ascii "7851940402630657488671505820681908902000708383676273854845817711"
    .ascii "5317644757302700698555713669596228429148198608349364752927190741"
    .ascii "68444365510704342711559699508093042880177904174497792.5"
    .p2align 3
.Ls238:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 309
    .ascii "1797693134862315807937289714053034150799341327100378269361737789"
    .ascii "8044496829276475094664901797758720709633028641669288791094655554"
    .ascii "7851940402630657488671505820681908902000708383676273854845817711"
    .ascii "5317644757302700698555713669596228429148198608349364752927190741"
    .ascii "68444365510704342711559699508093042880177904174497793"
    .p2align 3
.Ls239:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 17
    .ascii "65039888825534541"
    .p2align 3
.Ls240:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 19
    .ascii "0.65039888825534541"
    .p2align 3
.Ls241:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "6.5039888825534541e-17"
    .p2align 3
.Ls242:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 21
    .ascii "-650.39888825534541e5"
    .p2align 3
.Ls243:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 21
    .ascii "65039888825534541e-17"
    .p2align 3
.Ls244:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 40
    .ascii "6348275778525287356828742891065220566287"
    .p2align 3
.Ls245:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 42
    .ascii "0.6348275778525287356828742891065220566287"
    .p2align 3
.Ls246:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 45
    .ascii "6.348275778525287356828742891065220566287e-40"
    .p2align 3
.Ls247:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 44
    .ascii "-634.8275778525287356828742891065220566287e5"
    .p2align 3
.Ls248:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 44
    .ascii "6348275778525287356828742891065220566287e-40"
    .p2align 3
.Ls249:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 800
    .ascii "3656212160639867443512605848962042212391515278149571912581113911"
    .ascii "9219554946743438644997713294579497991306954968552254832345184558"
    .ascii "4700183071008038592721561569364263929979858728252572087298857326"
    .ascii "7150250409787708858567571415098618572586323189496750550317707312"
    .ascii "5211376698495319639948644863661057340234994822867893498128706127"
    .ascii "2122523433290696582673468696955239717305711396168747429335722472"
    .ascii "5269284441146659670859213813093818490265833964395964607076988343"
    .ascii "5189423449345616898698705271835393859602707442234142918412168935"
    .ascii "7610105169864884878839629193037835935874872889362164000012590326"
    .ascii "7719040133683552239635694047518454902354392185700144996152424592"
    .ascii "6918632369987781075487937172025376239116747456749629671172296551"
    .ascii "1001349064670571624634276894508020460158599473605871302481482817"
    .ascii "94767448400485524976755940174188"
    .p2align 3
.Ls250:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 802
    .ascii "0.36562121606398674435126058489620422123915152781495719125811139"
    .ascii "1192195549467434386449977132945794979913069549685522548323451845"
    .ascii "5847001830710080385927215615693642639299798587282525720872988573"
    .ascii "2671502504097877088585675714150986185725863231894967505503177073"
    .ascii "1252113766984953196399486448636610573402349948228678934981287061"
    .ascii "2721225234332906965826734686969552397173057113961687474293357224"
    .ascii "7252692844411466596708592138130938184902658339643959646070769883"
    .ascii "4351894234493456168986987052718353938596027074422341429184121689"
    .ascii "3576101051698648848788396291930378359358748728893621640000125903"
    .ascii "2677190401336835522396356940475184549023543921857001449961524245"
    .ascii "9269186323699877810754879371720253762391167474567496296711722965"
    .ascii "5110013490646705716246342768945080204601585994736058713024814828"
    .ascii "1794767448400485524976755940174188"
    .p2align 3
.Ls251:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 806
    .ascii "3.65621216063986744351260584896204221239151527814957191258111391"
    .ascii "1921955494674343864499771329457949799130695496855225483234518455"
    .ascii "8470018307100803859272156156936426392997985872825257208729885732"
    .ascii "6715025040978770885856757141509861857258632318949675055031770731"
    .ascii "2521137669849531963994864486366105734023499482286789349812870612"
    .ascii "7212252343329069658267346869695523971730571139616874742933572247"
    .ascii "2526928444114665967085921381309381849026583396439596460707698834"
    .ascii "3518942344934561689869870527183539385960270744223414291841216893"
    .ascii "5761010516986488487883962919303783593587487288936216400001259032"
    .ascii "6771904013368355223963569404751845490235439218570014499615242459"
    .ascii "2691863236998778107548793717202537623911674745674962967117229655"
    .ascii "1100134906467057162463427689450802046015859947360587130248148281"
    .ascii "794767448400485524976755940174188e-800"
    .p2align 3
.Ls252:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 804
    .ascii "-365.62121606398674435126058489620422123915152781495719125811139"
    .ascii "1192195549467434386449977132945794979913069549685522548323451845"
    .ascii "5847001830710080385927215615693642639299798587282525720872988573"
    .ascii "2671502504097877088585675714150986185725863231894967505503177073"
    .ascii "1252113766984953196399486448636610573402349948228678934981287061"
    .ascii "2721225234332906965826734686969552397173057113961687474293357224"
    .ascii "7252692844411466596708592138130938184902658339643959646070769883"
    .ascii "4351894234493456168986987052718353938596027074422341429184121689"
    .ascii "3576101051698648848788396291930378359358748728893621640000125903"
    .ascii "2677190401336835522396356940475184549023543921857001449961524245"
    .ascii "9269186323699877810754879371720253762391167474567496296711722965"
    .ascii "5110013490646705716246342768945080204601585994736058713024814828"
    .ascii "1794767448400485524976755940174188e5"
    .p2align 3
.Ls253:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 805
    .ascii "3656212160639867443512605848962042212391515278149571912581113911"
    .ascii "9219554946743438644997713294579497991306954968552254832345184558"
    .ascii "4700183071008038592721561569364263929979858728252572087298857326"
    .ascii "7150250409787708858567571415098618572586323189496750550317707312"
    .ascii "5211376698495319639948644863661057340234994822867893498128706127"
    .ascii "2122523433290696582673468696955239717305711396168747429335722472"
    .ascii "5269284441146659670859213813093818490265833964395964607076988343"
    .ascii "5189423449345616898698705271835393859602707442234142918412168935"
    .ascii "7610105169864884878839629193037835935874872889362164000012590326"
    .ascii "7719040133683552239635694047518454902354392185700144996152424592"
    .ascii "6918632369987781075487937172025376239116747456749629671172296551"
    .ascii "1001349064670571624634276894508020460158599473605871302481482817"
    .ascii "94767448400485524976755940174188e-800"
    .p2align 3
.Ls254:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 33
    .ascii "0000000000000000000000000000001.5"
    .p2align 3
.Ls255:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 408
    .ascii "0.00000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "00000000000000000015e400"
    .p2align 3
.Ls256:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 406
    .ascii "1000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "00000000000000000e-400"
    .p2align 3
.Ls257:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 331
    .ascii "1000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "00000000000"
    .p2align 3
.Ls258:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 802
    .ascii "0.99999999999999999999999999999999999999999999999999999999999999"
    .ascii "9999999999999999999999999999999999999999999999999999999999999999"
    .ascii "9999999999999999999999999999999999999999999999999999999999999999"
    .ascii "9999999999999999999999999999999999999999999999999999999999999999"
    .ascii "9999999999999999999999999999999999999999999999999999999999999999"
    .ascii "9999999999999999999999999999999999999999999999999999999999999999"
    .ascii "9999999999999999999999999999999999999999999999999999999999999999"
    .ascii "9999999999999999999999999999999999999999999999999999999999999999"
    .ascii "9999999999999999999999999999999999999999999999999999999999999999"
    .ascii "9999999999999999999999999999999999999999999999999999999999999999"
    .ascii "9999999999999999999999999999999999999999999999999999999999999999"
    .ascii "9999999999999999999999999999999999999999999999999999999999999999"
    .ascii "9999999999999999999999999999999999"
    .p2align 3
.Ls259:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 793
    .ascii "1.00000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000000000000000000000000000000000000000000000"
    .ascii "0000000000000000000000001"
    .p2align 3
.Ls260:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "1e400"
    .p2align 3
.Ls261:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "1e+400"
    .p2align 3
.Ls262:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "-1e400"
    .p2align 3
.Ls263:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "1e-401"
    .p2align 3
.Ls264:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "0e400"
    .p2align 3
.Ls265:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 7
    .ascii "-0e-400"
    .p2align 3
.Ls266:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 7
    .ascii "0.0e400"
    .p2align 3
.Ls267:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "9e399"
    .p2align 3
.Ls268:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "9e-399"
    .p2align 3
.Ls269:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 27
    .ascii "1e0000000000000000000000005"
    .p2align 3
.Ls270:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 28
    .ascii "1e-0000000000000000000000001"
    .p2align 3
.Ls271:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 27
    .ascii "1e9999999999999999999999999"
    .p2align 3
.Ls272:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 28
    .ascii "1e-9999999999999999999999999"
    .p2align 3
.Ls273:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 27
    .ascii "0e9999999999999999999999999"
    .p2align 3
.Ls274:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 29
    .ascii "-0e-9999999999999999999999999"
    .p2align 3
.Ls275:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 36
    .ascii "12345.678e+0000000000000000000000002"
    .p2align 3
.Ls276:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 27
    .ascii "1E0000000000000000000000000"
    .p2align 3
.Ls277:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 28
    .ascii "5e-0000000000000000000000324"
    .p2align 3
.Ls278:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "-4.13402988119073e+227"
    .p2align 3
.Ls279:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "1.4597008022476304e+138"
    .p2align 3
.Ls280:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 24
    .ascii "-5.7729897338491692e-270"
    .p2align 3
.Ls281:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "-5.772989733849169e-270"
    .p2align 3
.Ls282:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "-6.225038912834262e-44"
    .p2align 3
.Ls283:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "1.5944640009720988e+262"
    .p2align 3
.Ls284:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "1.594464000972099e+262"
    .p2align 3
.Ls285:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 24
    .ascii "-3.4923399814236393e+275"
    .p2align 3
.Ls286:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "-3.492339981423639e+275"
    .p2align 3
.Ls287:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 19
    .ascii "-41668443969498.906"
    .p2align 3
.Ls288:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 18
    .ascii "-41668443969498.91"
    .p2align 3
.Ls289:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "8.7800249709412179e-124"
    .p2align 3
.Ls290:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "8.780024970941218e-124"
    .p2align 3
.Ls291:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "2.0551167627947782e-126"
    .p2align 3
.Ls292:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 21
    .ascii "2.583044784376434e+23"
    .p2align 3
.Ls293:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 24
    .ascii "-2.5799012761554617e+261"
    .p2align 3
.Ls294:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "-5.4916210691183977e+62"
    .p2align 3
.Ls295:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "-5.491621069118398e+62"
    .p2align 3
.Ls296:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 24
    .ascii "-6.1593947862888659e-150"
    .p2align 3
.Ls297:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "-6.159394786288866e-150"
    .p2align 3
.Ls298:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "1.5221201384378854e+203"
    .p2align 3
.Ls299:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "7.1775929624530171e-09"
    .p2align 3
.Ls300:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 21
    .ascii "7.177592962453017e-09"
    .p2align 3
.Ls301:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "-2.966241676371694e+305"
    .p2align 3
.Ls302:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "-1.9964234401775535e-38"
    .p2align 3
.Ls303:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 23
    .ascii "7.6934887664645327e+214"
    .p2align 3
.Ls304:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "7.693488766464533e+214"
    .p2align 3
.Ls305:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 24
    .ascii "-1.5669246586415468e+173"
    .p2align 3
.Ls306:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 22
    .ascii "1.065539104777903e-262"
    .p2align 3
.Ls307:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "a,,b"
    .p2align 3
.Ls308:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii ","
    .p2align 3
.Ls309:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii ",a,"
    .p2align 3
.Ls310:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 0
    .p2align 3
.Ls311:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "abc"
    .p2align 3
.Ls312:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "aaa"
    .p2align 3
.Ls313:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "aa"
    .p2align 3
.Ls314:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "a::b"
    .p2align 3
.Ls315:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "::"
    .p2align 3
.Ls316:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "a b c"
    .p2align 3
.Ls317:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii " "
    .p2align 3
.Ls318:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "a  b"
    .p2align 3
.Ls319:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "  "
    .p2align 3
.Ls320:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "x"
    .p2align 3
.Ls321:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "abcd"
    .p2align 3
.Ls322:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "ab"
    .p2align 3
.Ls323:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "abab"
    .p2align 3
.Ls324:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "ababab"
    .p2align 3
.Ls325:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "bab"
    .p2align 3
.Ls326:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "aXbX"
    .p2align 3
.Ls327:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "X"
    .p2align 3
.Ls328:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "XaXbX"
    .p2align 3
.Ls329:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 2
    .ascii "XX"
    .p2align 3
.Ls330:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "abcab"
    .p2align 3
.Ls331:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "cab"
    .p2align 3
.Ls332:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "abca"
    .p2align 3
.Ls333:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "abcabc"
    .p2align 3
.Ls334:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "cabc"
    .p2align 3
.Ls335:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "aabaab"
    .p2align 3
.Ls336:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "aab"
    .p2align 3
.Ls337:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "aaaa"
    .p2align 3
.Ls338:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "aaaaa"
    .p2align 3
.Ls339:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 35
    .ascii "1700000000.123456 can0 123#DEADBEEF"
    .p2align 3
.Ls340:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 17
    .ascii "can0 123#DEADBEEF"
    .p2align 3
.Ls341:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "#"
    .p2align 3
.Ls342:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 7
    .ascii "a,b;c,d"
    .p2align 3
.Ls343:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii ";"
    .p2align 3
.Ls344:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 17
    .ascii "one::two::::three"
    .p2align 3
.Ls345:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "end::"
    .p2align 3
.Ls346:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii ":::"
    .p2align 3
.Ls347:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 8
    .ascii "a-->b-->"
    .p2align 3
.Ls348:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "-->"
    .p2align 3
.Ls349:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "ab-"
    .p2align 3
.Ls350:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .ascii "ab--"
    .p2align 3
.Ls351:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "a=b=c"
    .p2align 3
.Ls352:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 1
    .ascii "="
    .p2align 3
.Ls353:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "hello"
    .p2align 3
.Ls354:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "(1.5)"
    .p2align 3
.Ls355:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 8
    .ascii "DEADBEEF"
    .p2align 3
.Ls356:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .ascii "a b"
    .p2align 3
.Ls357:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "x y z"
    .p2align 3
.Lfile:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "m.sea"
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lfile, 1                 # site 0

    .section .note.GNU-stack,"",@progbits
