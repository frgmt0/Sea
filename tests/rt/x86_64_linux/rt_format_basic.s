# sea/tests/rt/x86_64_linux/rt_format_basic.s -- sea_format (DESIGN.md 4.8 FORMAT, LANGUAGE.md 11.1): a new string (count 1, tag, length) of exactly the bytes sea_printf writes for the same format and slots: text, %05d, %-4s, %.3f, %8d of NaN, %e, %%; the empty format gives an empty string; %d of -0.0, %+d, %f of an i64; nothing goes to stdout; live count back to 0 (heap check)
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

# Pre-parsed format pieces (rt.inc SEA_FP_*): a text piece and a conversion piece.
.macro FTEXT label, len
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad \label, \len
.endm
.macro FCONV letter, flags, cls, width, prec
    .byte SEA_FPK_CONV, \letter, \flags, \cls
    .long \width, \prec, 0
    .quad 0, 0
.endm
# FMT fmt, slots: %rbx := sea_format(fmt, slots, site 0); print it as [bytes], then its
# count, tag and length, LF; release it.
.macro FMT fmt, slots
    leaq \fmt(%rip), %rdi
    leaq \slots(%rip), %rsi
    xorl %edx, %edx
    call sea_format
    movq %rax, %rbx
    movq %rbx, %rdi
    call put_str
    KV " rc=", SEA_STR_RC(%rbx)
    xorl %eax, %eax
    cmpb $SEA_TAG_STR, SEA_STR_TAG(%rbx)
    sete %al
    KV " tag_ok=", %rax
    KV " len=", SEA_STR_LEN(%rbx)
    TXT "\n"
    REL %rbx
.endm

    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    LIVE %r12
    KV "live before=", %r12
    TXT "\n"
    FMT .Lf1, .Ls1
    FMT .Lf2, .Ls2
    FMT .Lf3, .Ls3
    # The same format through sea_printf: the same bytes on stdout.
    TXT "["
    leaq .Lf1(%rip), %rdi
    leaq .Ls1(%rip), %rsi
    xorl %edx, %edx
    call sea_printf
    TXT "]\n"
    LIVE %r12
    KV "live after=", %r12
    TXT "\n"
    EPILOGUE

    .section .rodata
.Lt_n:   .ascii "n="
.Lt_s:   .ascii " s="
.Lt_bar: .ascii "|"
.Lt_sp:  .ascii " "
.Lt_pc:  .ascii "%"
    .section .data.rel.ro,"aw",@progbits
    SSTR .Lab, 2, "ab"
    .p2align 3
# "n=%05d s=%-4s|%.3f %8d %e%%"
.Lf1:
    .quad 11, 5
    FTEXT .Lt_n, 2
    FCONV 100, SEA_FF_ZERO, SEA_CLS_I, 5, -1        # %05d
    FTEXT .Lt_s, 3
    FCONV 115, SEA_FF_LEFT, SEA_CLS_P, 4, -1        # %-4s
    FTEXT .Lt_bar, 1
    FCONV 102, 0, SEA_CLS_F, -1, 3                  # %.3f
    FTEXT .Lt_sp, 1
    FCONV 100, 0, SEA_CLS_F, 8, -1                  # %8d of an f64
    FTEXT .Lt_sp, 1
    FCONV 101, 0, SEA_CLS_F, -1, -1                 # %e
    FTEXT .Lt_pc, 1                                 # %%
.Ls1:
    .quad 42, .Lab, 0x400921F9F01B866E, 0x7FF8000000000000, 0x3FF8000000000000
# the empty format: no piece
.Lf2:
    .quad 0, 0
.Ls2:
    .quad 0
# "%d|%+d|%f": -0.0 under %d, an i64 with +, an i64 under %f
.Lf3:
    .quad 5, 3
    FCONV 100, 0, SEA_CLS_F, -1, -1                 # %d of -0.0
    FTEXT .Lt_bar, 1
    FCONV 100, SEA_FF_PLUS, SEA_CLS_I, -1, -1       # %+d
    FTEXT .Lt_bar, 1
    FCONV 102, 0, SEA_CLS_I, -1, -1                 # %f of an i64
.Ls3:
    .quad 0x8000000000000000, 7, 7
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lab, 1
