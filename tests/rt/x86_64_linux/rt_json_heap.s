# sea/tests/rt/x86_64_linux/rt_json_heap.s -- a write_json on dynamic objects (a str_cat path, key and value, an f64 2x2 matrix, a str vector) leaves the live count unchanged (DESIGN.md 2.11.6): the state is not a counted object; JSON_OPEN retains the path and JSON_CLOSE releases it and frees the state; 40 nested arrays grow the container stack past its first size (L-co); live count back to 0 (heap check); the file read back
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

.equ NEST, 40                       # nesting depth: above the stack's first size

    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    # Dynamic objects: the path "h" + ".json", a key, a str value, an
    # f64 2 x 2 matrix and a str vector of two dynamic strings.
    leaq .Lh(%rip), %rdi
    leaq .Ldotjson(%rip), %rsi
    xorl %edx, %edx
    call sea_str_cat
    movq %rax, %rbx                 # the path
    leaq .Lk(%rip), %rdi
    leaq .Lk(%rip), %rsi
    xorl %edx, %edx
    call sea_str_cat
    movq %rax, %r12                 # the key "kk"
    leaq .Lv(%rip), %rdi
    leaq .Lk(%rip), %rsi
    xorl %edx, %edx
    call sea_str_cat
    movq %rax, %r13                 # the value "vk"
    movl $SEA_EK_F64, %edi
    movl $2, %esi
    movl $2, %edx
    movl $2, %ecx
    xorl %r8d, %r8d
    call sea_arr_new
    movq %rax, %r14                 # [[0, 2], [1, 3]] column-major 0 1 2 3
    movq SEA_ARR_DATA(%r14), %rcx
    movabsq $0x3FF0000000000000, %rax   # 1.0
    movq %rax, 8(%rcx)
    movabsq $0x4000000000000000, %rax   # 2.0
    movq %rax, 16(%rcx)
    movabsq $0x4008000000000000, %rax   # 3.0
    movq %rax, 24(%rcx)
    movl $SEA_EK_STR, %edi
    movl $1, %esi
    movl $2, %edx
    movl $1, %ecx
    xorl %r8d, %r8d
    call sea_arr_new
    movq %rax, %r15                 # the str vector
    movq %r13, %rdi
    call sea_retain                 # element 0: the value (shared)
    movq SEA_ARR_DATA(%r15), %rcx
    movq %r13, (%rcx)
    leaq .Lv(%rip), %rdi
    leaq .Lv(%rip), %rsi
    xorl %edx, %edx
    call sea_str_cat                # element 1: "vv"
    movq SEA_ARR_DATA(%r15), %rcx
    movq %rax, 8(%rcx)
    KV "live before=", sea_live(%rip)
    KV " path rc=", SEA_STR_RC(%rbx)
    TXT "\n"

    movq %rbx, %rdi
    xorl %esi, %esi
    call sea_json_open
    KV "live open=", sea_live(%rip) # the state is not a counted object
    KV " path rc=", SEA_STR_RC(%rbx) # retained by the state
    TXT "\n"
    JSON0 sea_json_obj
    movq %r12, %rdi
    xorl %esi, %esi
    call sea_json_key
    movq %r13, %rdi
    xorl %esi, %esi
    call sea_json_str
    JSONP sea_json_key, .Lk_m
    movq %r14, %rdi
    xorl %esi, %esi
    call sea_json_mat
    JSONP sea_json_key, .Lk_s
    movq %r15, %rdi
    xorl %esi, %esi
    call sea_json_vec
    JSONP sea_json_key, .Lk_n
    movq $NEST, 0(%rsp)             # NEST nested arrays: the stack grows
1:  JSON0 sea_json_arr
    decq 0(%rsp)
    jnz 1b
    movq $NEST, 0(%rsp)
2:  JSON0 sea_json_end
    decq 0(%rsp)
    jnz 2b
    JSON0 sea_json_end
    JSON0 sea_json_close
    KV "live closed=", sea_live(%rip)
    KV " path rc=", SEA_STR_RC(%rbx) # released by JSON_CLOSE
    KV " value rc=", SEA_STR_RC(%r13) # the value and the vector's element 0
    xorl %eax, %eax
    cmpq $0, sea_json_st(%rip)
    sete %al
    KV " state freed=", %rax
    TXT "\n"
    REL %rbx
    REL %r12
    REL %r13
    REL %r14
    REL %r15
    KV "live end=", sea_live(%rip)
    TXT "\n"
    CAT .Lc_h, h.json
    EPILOGUE

    .section .rodata
.Lc_h:   .asciz "h.json"
    .section .data.rel.ro,"aw",@progbits
    SSTR .Lh, 1, "h"
    SSTR .Ldotjson, 5, ".json"
    SSTR .Lk, 1, "k"
    SSTR .Lv, 1, "v"
    SSTR .Lk_m, 1, "m"
    SSTR .Lk_s, 1, "s"
    SSTR .Lk_n, 1, "n"
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lh, 1
