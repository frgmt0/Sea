# sea/tests/rt/x86_64_linux/rt_json_abort.s -- a run-time error while a JSON file is open (LANGUAGE.md 9.2 step 3, DESIGN.md 2.11.6, L-ca): _sea_err reports the original error, then flushes the emitter's buffer to the file and closes it; a forked child does the writes and the error, the parent prints the child's status and the file (as written: no closing bracket, no final LF)
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
    call fork@PLT
    testl %eax, %eax
    jnz .Lparent
    # The child: a JSON file half written, then a run-time error.
    JSONP sea_json_open, .La
    JSON0 sea_json_obj
    JSONP sea_json_key, .Lk
    JSONI 1
    JSONP sea_json_key, .Ls
    JSON0 sea_json_arr
    JSONB 1
    movl $SEA_E_INT_OVERFLOW, %edi
    xorl %esi, %esi                 # site 0: j.sea:9
    xorl %edx, %edx
    call sea_err                    # flushes and closes a.json, exits 1
    ud2
.Lparent:
    movl %eax, %edi                 # the child's pid
    movq %rsp, %rsi                 # waitpid's status word at 0(%rsp)
    xorl %edx, %edx
    call waitpid@PLT
    movl 0(%rsp), %eax
    shrl $8, %eax
    movzbl %al, %ebx                # WEXITSTATUS
    KV "child status=", %rbx
    TXT "\n"
    CAT .Lc_a, a.json
    EPILOGUE

    .section .rodata
.Lc_a:   .asciz "a.json"
    .section .data.rel.ro,"aw",@progbits
    SSTR .La, 6, "a.json"
    SSTR .Lk, 1, "k"
    SSTR .Ls, 1, "s"
    SSTR .Lfile, 5, "j.sea"
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lfile, 9
