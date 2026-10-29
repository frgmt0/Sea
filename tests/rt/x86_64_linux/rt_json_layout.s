# sea/tests/rt/x86_64_linux/rt_json_layout.s -- the JSON emitter's layout (LANGUAGE.md 11.4, DESIGN.md 2.11.6, L-bz): f64 as %.17g (0.1, -0, 100, 1e300, 5e-324) and null for NaN and +-inf; i64 -2^63 and 2^63 - 1; true, false; a string with every escape class (quote, backslash, LF, TAB, 0x01, 0x1F, CR as u000d) and 0x7F, 0x80, 0xFF verbatim; an escaped key; empty object and array; nesting; vectors of f64, i64 (empty), bool, str; matrices 2x3 (column-major data), 1x1 of str, 0x3 and 3x0 as []; a path written twice (the second replaces the first); a top-level scalar, vector and empty object; each file read back
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# ---- test helpers (the x86_64 twins of the helpers of tests/rt/arm64_macos's 6b tests) ----
# A static string object (rt.inc SEA_STR_*): count SEA_RC_STATIC, tag, length, bytes.
.macro SSTR label, len, text
    .p2align 3
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad \len
    .ascii "\text"
.endm
# Print a literal text (caller-saved registers clobbered).
.macro TXT text
    .pushsection .rodata
.Ltxt\@: .asciz "\text"
    .popsection
    leaq .Ltxt\@(%rip), %rdi
    call put_cstr
.endm
# Print a literal text, then a register or memory operand in signed decimal
# (caller-saved registers clobbered; the operand must not be %rdi).
.macro KV text, val
    movq \val, %rsi
    .pushsection .rodata
.Lkv\@: .asciz "\text"
    .popsection
    leaq .Lkv\@(%rip), %rdi
    call put_kv
.endm
# The live-object counter of rt_mem.s into a register.
.macro LIVE reg
    movq sea_live(%rip), \reg
.endm
# The release sequence of pass 4 (DESIGN.md 4.9) on the object in a register or memory
# operand: the count drops by one unless static, sea_free at 0 (caller-saved clobbered).
.macro REL val
    movq \val, %rdi
    movq SEA_OBJ_RC(%rdi), %rax
    testq %rax, %rax
    jz .Lrel\@
    decq %rax
    movq %rax, SEA_OBJ_RC(%rdi)
    jnz .Lrel\@
    call sea_free
.Lrel\@:
.endm
# sea_main's frame: %rbp, %rbx, %r12-%r15 saved, 56 bytes of locals at 0(%rsp)
# (entered at %rsp = 8 (mod 16), so %rsp = 0 (mod 16) after it).
.macro PROLOGUE
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $56, %rsp
.endm
.macro EPILOGUE
    addq $56, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.endm

    .text
# put_cstr -- print a NUL-terminated text (%rdi). Callee-saved used: %rbx.
    .p2align 4
put_cstr:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rdi, %rbx
    call strlen@PLT
    movq %rax, %rsi
    movq %rbx, %rdi
    call sea_out_write
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# put_dec -- print %rdi as a signed decimal. Frame: 8 (%rbp) + 32 bytes of digits.
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

# put_kv -- print a text (%rdi), then %rsi in signed decimal. Callee-saved used: %rbx.
    .p2align 4
put_kv:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rsi, %rbx
    call put_cstr
    movq %rbx, %rdi
    call put_dec
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# put_str -- print a string object's (%rdi) bytes between [ and ]. Callee-saved: %rbx.
    .p2align 4
put_str:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rdi, %rbx
    leaq .Lput_s_lb(%rip), %rdi
    movl $1, %esi
    call sea_out_write
    leaq SEA_STR_BYTES(%rbx), %rdi
    movq SEA_STR_LEN(%rbx), %rsi
    call sea_out_write
    leaq .Lput_s_rb(%rip), %rdi
    movl $1, %esi
    call sea_out_write
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret
    .pushsection .rodata
.Lput_s_lb: .ascii "["
.Lput_s_rb: .ascii "]"
    .popsection
# ---- end of the test helpers ----
# ---- phase-6 helpers ----
# put_hex -- print %rdi as 16 upper-case hexadecimal digits (the bits of an f64).
#   Frame: 8 (%rbp) + 16 bytes of digits.
    .p2align 4
put_hex:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp
    movl $16, %ecx
1:  movl %edi, %eax
    andl $15, %eax
    leaq .Lput_hexd(%rip), %rdx
    movb (%rdx,%rax), %al
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
    .pushsection .rodata
.Lput_hexd: .ascii "0123456789ABCDEF"
    .popsection

# cat -- print the bytes of the file named by the C string at %rdi; a file that cannot
#   be opened prints "<no file>". Callee-saved used: %rbx (fd). Frame 24 + 4096 + 8.
    .p2align 4
cat:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $4104, %rsp
    xorl %esi, %esi                 # O_RDONLY
    xorl %eax, %eax
    call open@PLT
    movl %eax, %ebx
    testl %eax, %eax
    jns 1f
    TXT "<no file>"
    jmp 3f
1:  movl %ebx, %edi
    movq %rsp, %rsi
    movl $4096, %edx
    call read@PLT
    testq %rax, %rax
    jle 2f
    movq %rsp, %rdi
    movq %rax, %rsi
    call sea_out_write
    jmp 1b
2:  movl %ebx, %edi
    call close@PLT
3:  addq $4104, %rsp
    popq %rbx
    popq %rbp
    ret
# ---- end of the phase-6 helpers ----

# JSON emitter calls, every one at site 0. (GNU as macro names ignore case, so
# they must not spell an instruction such as jb or jp.)
.macro JSON0 entry                     # an entry whose only argument is the site
    xorl %edi, %edi
    call \entry
.endm
.macro JSONP entry, label              # an entry taking a pointer, then the site
    leaq \label(%rip), %rdi
    xorl %esi, %esi
    call \entry
.endm
.macro JSONF bits                      # sea_json_f64(%xmm0 = bits, site)
    movabsq $\bits, %rax
    movq %rax, %xmm0
    xorl %edi, %edi
    call sea_json_f64
.endm
.macro JSONI val                       # sea_json_i64(val, site)
    movabsq $\val, %rdi
    xorl %esi, %esi
    call sea_json_i64
.endm
.macro JSONB val                       # sea_json_bool(val, site)
    movl $\val, %edi
    xorl %esi, %esi
    call sea_json_bool
.endm
# A static dynamic-array header (rt.inc SEA_ARR_*, count SEA_RC_STATIC).
.macro SARR label, ek, rank, rows, cols, esize, data
    .p2align 3
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, \ek, \rank
    .space 5, 0
    .quad \rows, \cols, (\rows) * (\cols), \data, \esize, 0
.endm
# CAT cpath, name: print "--- <name>" LF, the file's bytes, then "|" LF.
.macro CAT cpath, name
    TXT "--- \name"
    call putnl6
    leaq \cpath(%rip), %rdi
    call cat
    TXT "|"
    call putnl6
.endm
    .p2align 4
putnl6:
    pushq %rbp
    movq %rsp, %rbp
    leaq .Lnl6(%rip), %rdi
    movl $1, %esi
    call sea_out_write
    popq %rbp
    ret
    .pushsection .rodata
.Lnl6: .byte 10
    .popsection

    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    # ---- a.json: every scalar, container and array kind -------------
    JSONP sea_json_open, .La
    JSON0 sea_json_obj
    JSONP sea_json_key, .Lk_f
    JSON0 sea_json_arr
    JSONF 0x3FB999999999999A           # 0.1
    JSONF 0x8000000000000000           # -0
    JSONF 0x4059000000000000           # 100
    JSONF 0x7E37E43C8800759C           # 1e300
    JSONF 0x0000000000000001           # 5e-324
    JSONF 0x7FF8000000000000           # NaN
    JSONF 0x7FF0000000000000           # inf
    JSONF 0xFFF0000000000000           # -inf
    JSON0 sea_json_end
    JSONP sea_json_key, .Lk_i
    JSON0 sea_json_arr
    JSONI 0
    JSONI 0x8000000000000000           # -2^63
    JSONI 0x7FFFFFFFFFFFFFFF           # 2^63 - 1
    JSON0 sea_json_end
    JSONP sea_json_key, .Lk_b
    JSONB 1
    JSONP sea_json_key, .Lk_c
    JSONB 0
    JSONP sea_json_key, .Lk_s
    JSONP sea_json_str, .Lsesc
    JSONP sea_json_key, .Lk_eo
    JSON0 sea_json_obj
    JSON0 sea_json_end
    JSONP sea_json_key, .Lk_ea
    JSON0 sea_json_arr
    JSON0 sea_json_end
    JSONP sea_json_key, .Lk_nest
    JSON0 sea_json_obj
    JSONP sea_json_key, .Lk_k
    JSON0 sea_json_obj
    JSONP sea_json_key, .Lk_deep
    JSONI 1
    JSON0 sea_json_end
    JSONP sea_json_key, .Lk_arr
    JSON0 sea_json_arr
    JSON0 sea_json_obj
    JSON0 sea_json_end
    JSON0 sea_json_arr
    JSON0 sea_json_arr
    JSON0 sea_json_end
    JSONP sea_json_str, .Lx
    JSON0 sea_json_end
    JSON0 sea_json_end
    JSON0 sea_json_end
    JSONP sea_json_key, .Lk_vf
    JSONP sea_json_vec, .Lvf
    JSONP sea_json_key, .Lk_vi
    JSONP sea_json_vec, .Lvi
    JSONP sea_json_key, .Lk_vb
    JSONP sea_json_vec, .Lvb
    JSONP sea_json_key, .Lk_vs
    JSONP sea_json_vec, .Lvs
    JSONP sea_json_key, .Lk_m23
    JSONP sea_json_mat, .Lm23
    JSONP sea_json_key, .Lk_m11
    JSONP sea_json_mat, .Lm11
    JSONP sea_json_key, .Lk_m03
    JSONP sea_json_mat, .Lm03
    JSONP sea_json_key, .Lk_m30
    JSONP sea_json_mat, .Lm30
    JSONP sea_json_key, .Lk_q
    JSONI 5
    JSON0 sea_json_end
    JSON0 sea_json_close
    # ---- b.json written twice: the second replaces the first --------
    JSONP sea_json_open, .Lb
    JSONP sea_json_vec, .Lvf
    JSON0 sea_json_close
    JSONP sea_json_open, .Lb
    JSONI 42                           # a top-level scalar
    JSON0 sea_json_close
    # ---- c.json: a top-level vector and d.json: an empty top object --
    JSONP sea_json_open, .Lc
    JSONP sea_json_vec, .Lvs
    JSON0 sea_json_close
    JSONP sea_json_open, .Ld
    JSON0 sea_json_obj
    JSON0 sea_json_end
    JSON0 sea_json_close
    CAT .Lc_a, a.json
    CAT .Lc_b, b.json
    CAT .Lc_c, c.json
    CAT .Lc_d, d.json
    EPILOGUE

    .section .rodata
.Lc_a:   .asciz "a.json"
.Lc_b:   .asciz "b.json"
.Lc_c:   .asciz "c.json"
.Lc_d:   .asciz "d.json"
    .section .data.rel.ro,"aw",@progbits
    SSTR .La, 6, "a.json"
    SSTR .Lb, 6, "b.json"
    SSTR .Lc, 6, "c.json"
    SSTR .Ld, 6, "d.json"
    SSTR .Lk_f, 1, "f"
    SSTR .Lk_i, 1, "i"
    SSTR .Lk_b, 1, "b"
    SSTR .Lk_c, 1, "c"
    SSTR .Lk_s, 1, "s"
    SSTR .Lk_eo, 2, "eo"
    SSTR .Lk_ea, 2, "ea"
    SSTR .Lk_nest, 4, "nest"
    SSTR .Lk_k, 1, "k"
    SSTR .Lk_deep, 4, "deep"
    SSTR .Lk_arr, 3, "arr"
    SSTR .Lk_vf, 2, "vf"
    SSTR .Lk_vi, 2, "vi"
    SSTR .Lk_vb, 2, "vb"
    SSTR .Lk_vs, 2, "vs"
    SSTR .Lk_m23, 3, "m23"
    SSTR .Lk_m11, 3, "m11"
    SSTR .Lk_m03, 3, "m03"
    SSTR .Lk_m30, 3, "m30"
    .p2align 3
.Lk_q:                               # the key k"ey
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .byte 0x6B, 0x22, 0x65, 0x79
    SSTR .Lx, 1, "x"
    SSTR .Lsa, 1, "a"
    SSTR .Lsempty, 0, ""
    SSTR .Lsz, 1, "z"
    .p2align 3
.Lscd:                               # c"d
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .byte 0x63, 0x22, 0x64
    .p2align 3
.Lsesc:                              # every escape class and the verbatim high bytes
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 15
    .byte 0x71, 0x22, 0x62, 0x5C, 0x6E, 0x0A, 0x74, 0x09, 0x63, 0x01, 0x1F, 0x0D, 0x7F, 0x80, 0xFF
    .p2align 3
.Ld_vf:  .quad 0x3FF8000000000000, 0x4000000000000000         # 1.5, 2
.Ld_vb:  .byte 0, 1
    .p2align 3
.Ld_vs:  .quad .Lsa, .Lsempty, .Lscd
.Ld_m23: .quad 0x3FF0000000000000, 0x4010000000000000         # column-major: 1 4
        .quad 0x4000000000000000, 0x4014000000000000         #               2 5
        .quad 0x4008000000000000, 0x4018000000000000         #               3 6
.Ld_m11: .quad .Lsz
.Ld_none: .quad 0
    SARR .Lvf, SEA_EK_F64, 1, 2, 1, SEA_ESIZE_F64, .Ld_vf
    SARR .Lvi, SEA_EK_I64, 1, 0, 1, SEA_ESIZE_I64, .Ld_none
    SARR .Lvb, SEA_EK_BOOL, 1, 2, 1, SEA_ESIZE_BOOL, .Ld_vb
    SARR .Lvs, SEA_EK_STR, 1, 3, 1, SEA_ESIZE_PTR, .Ld_vs
    SARR .Lm23, SEA_EK_F64, 2, 2, 3, SEA_ESIZE_F64, .Ld_m23
    SARR .Lm11, SEA_EK_STR, 2, 1, 1, SEA_ESIZE_PTR, .Ld_m11
    SARR .Lm03, SEA_EK_I64, 2, 0, 3, SEA_ESIZE_I64, .Ld_none
    SARR .Lm30, SEA_EK_BOOL, 2, 3, 0, SEA_ESIZE_BOOL, .Ld_none
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .La, 1
