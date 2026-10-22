# sea/tests/rt/x86_64_linux/rt_mem_cache_bytes.s -- the large-block cache in all: eight freed 32 MiB blocks fill the SEA_LCACHE_MAX_BYTES (256 MiB) cache and stay mapped; a freed 64 MiB block would exceed it and is unmapped although its class is empty; a 32 MiB allocation then takes the last cached block
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

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
# Append static bytes to the standard-output buffer (caller-saved registers clobbered).
.macro PUT label, len
    leaq \label(%rip), %rdi
    movq $\len, %rsi
    call sea_out_write
.endm
# Append a text and a LF (caller-saved registers clobbered).
.macro SAY text
    leaq .Lsay_s\@(%rip), %rdi
    movq $(.Lsay_e\@ - .Lsay_s\@), %rsi
    call sea_out_write
    .pushsection .rodata
.Lsay_s\@: .ascii "\text"
    .byte 10
.Lsay_e\@:
    .popsection
.endm
# After a compare: `<text>` + LF if condition cc holds, else `<text> BAD` + LF.
.macro CHECK cc, text
    j\cc .Lck_ok\@
    leaq .Lck_bs\@(%rip), %rdi
    movq $(.Lck_be\@ - .Lck_bs\@), %rsi
    jmp .Lck_out\@
.Lck_ok\@:
    leaq .Lck_s\@(%rip), %rdi
    movq $(.Lck_e\@ - .Lck_s\@), %rsi
.Lck_out\@:
    call sea_out_write
    .pushsection .rodata
.Lck_s\@: .ascii "\text"
    .byte 10
.Lck_e\@:
.Lck_bs\@: .ascii "\text BAD"
    .byte 10
.Lck_be\@:
    .popsection
.endm
# Append the bytes of the string object in a register (not %rdi/%rsi).
.macro PUTSTR reg
    leaq SEA_STR_BYTES(\reg), %rdi
    movq SEA_STR_LEN(\reg), %rsi
    call sea_out_write
.endm
# sea_err(code, site, slots label); noreturn.
.macro RAISE code, site, slots
    movl $\code, %edi
    movq $\site, %rsi
    leaq \slots(%rip), %rdx
    call sea_err
.endm
# sea_main's frame: %rbp, %rbx, %r12-%r15 saved, 8 bytes of locals at
# 0(%rsp); entered at %rsp = 8 (mod 16), so %rsp = 0 (mod 16) after it.
.macro PROLOGUE
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp
.endm
.macro EPILOGUE
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.endm
# The error-site table: site 0 is m.sea:\line.
.macro SITES line
    .pushsection .data.rel.ro,"aw",@progbits
    .p2align 3
    SSTR .Lsite_file, 5, "m.sea"
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lsite_file
    .quad \line
    .popsection
.endm

    .text
# putdec -- append the decimal text of %rdi (signed) to standard output.
#   Clobbers: all caller-saved registers. Frame: 8 (%rbp) + 32 bytes.
    .p2align 4
putdec:
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp
    leaq 32(%rsp), %r8
    movq %rdi, %rax
    xorl %r9d, %r9d
    testq %rax, %rax
    jns 1f
    negq %rax
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
# putnl -- append a LF.
    .p2align 4
putnl:
    pushq %rbp
    movq %rsp, %rbp
    leaq .Lnl(%rip), %rdi
    movl $1, %esi
    call sea_out_write
    popq %rbp
    ret
    .pushsection .rodata
.Lnl: .byte 10
    .popsection

.equ NBLK, 8
.equ BLK, 33554432
.equ BIG, 67108864
.equ ENOMEM, 12

.if NBLK * BLK != SEA_LCACHE_MAX_BYTES
    .error "rt_mem_cache_bytes: the eight blocks must fill the cache exactly"
.endif

    .text
# mapped -- %rdi = a page address; %eax = 1 if it is mapped, 0 if mincore fails with
#   ENOMEM, 2 otherwise.
    .p2align 4
mapped:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp
    movl $4096, %esi
    movq %rsp, %rdx
    call mincore@PLT
    testl %eax, %eax
    jnz 1f
    movl $1, %eax
    jmp 3f
1:  call __errno_location@PLT
    cmpl $ENOMEM, (%rax)
    jne 2f
    xorl %eax, %eax
    jmp 3f
2:  movl $2, %eax
3:  movq %rbp, %rsp
    popq %rbp
    ret

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    xorl %r12d, %r12d
1:  movl $BLK, %edi
    xorl %esi, %esi
    call sea_alloc
    leaq .Lblk(%rip), %rcx
    movq %rax, (%rcx,%r12,8)
    incq %r12
    cmpq $NBLK, %r12
    jb 1b
    movl $BIG, %edi
    xorl %esi, %esi
    call sea_alloc
    movq %rax, %rbx                 # the 64 MiB block
    xorl %r12d, %r12d
2:  leaq .Lblk(%rip), %rcx
    movq (%rcx,%r12,8), %rdi
    movl $BLK, %esi
    call sea_free_block
    incq %r12
    cmpq $NBLK, %r12
    jb 2b
    # All eight cached.
    xorl %r12d, %r12d
    movl $1, %r13d
3:  leaq .Lblk(%rip), %rcx
    movq (%rcx,%r12,8), %rdi
    call mapped
    cmpl $1, %eax
    je 4f
    xorl %r13d, %r13d
4:  incq %r12
    cmpq $NBLK, %r12
    jb 3b
    cmpl $1, %r13d
    CHECK e, "eight 32 MiB blocks cached"
    # The 64 MiB block does not fit in the cache: unmapped.
    movq %rbx, %rdi
    movl $BIG, %esi
    call sea_free_block
    movq %rbx, %rdi
    call mapped
    cmpl $0, %eax
    CHECK e, "64 MiB block unmapped"
    # A 32 MiB allocation: the most recently freed block.
    movl $BLK, %edi
    xorl %esi, %esi
    call sea_alloc
    cmpq .Lblk+8*(NBLK-1)(%rip), %rax
    CHECK e, "32 MiB block from the cache"
    EPILOGUE

    .bss
    .p2align 3
.Lblk: .zero 8*NBLK
    SITES 1
