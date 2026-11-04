# sea/tests/rt/x86_64_linux/rt_lib_err_read_oom.s -- sea_read_lines with no memory left (DESIGN.md 2.15.5, 2.15.6 step 3): after a first read_lines of a short file (released), RLIMIT_AS is set to the address space in use, so the next mapping fails; read_lines of a 70000-byte file (its buffer must grow past RTT_CHUNK) is OUT_OF_MEMORY at its site (m.sea:50, site 1), status 1, standard output flushed first. Fixtures: rt_lib_err_read_oom.files/.
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# Linux values (private to this test): RLIMIT_AS 9, struct rlimit {cur u64, max u64},
# _SC_PAGESIZE 30, O_RDONLY 0.
.equ RLIMIT_AS, 9
.equ SC_PAGESIZE, 30

    .text
# limit_as -- set RLIMIT_AS's soft limit to the process's present address-space size
# (the first field of /proc/self/statm, in pages, times the page size), so that the
# next mapping the allocator asks for fails. Frame: 8 (%rbp) + 16 (rlimit) + 64 (text)
# + 8 (%rbx) + 8 pad. Callee-saved used: %rbx = the descriptor, then the size.
    .p2align 4
limit_as:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $88, %rsp                  # 0(%rsp) rlimit, 16(%rsp) text; %rsp = 0 (mod 16)
    leaq .Lstatm(%rip), %rdi
    xorl %esi, %esi
    xorl %eax, %eax
    call open@PLT
    movl %eax, %ebx
    movl %ebx, %edi
    leaq 16(%rsp), %rsi
    movl $63, %edx
    call read@PLT
    movl %ebx, %edi
    call close@PLT
    xorl %ebx, %ebx                 # the leading decimal number: pages
    leaq 16(%rsp), %rcx
1:  movzbl (%rcx), %eax
    subl $48, %eax
    cmpl $9, %eax
    ja 2f
    imulq $10, %rbx
    addq %rax, %rbx
    incq %rcx
    jmp 1b
2:  movl $SC_PAGESIZE, %edi
    call sysconf@PLT
    imulq %rax, %rbx                # bytes mapped now
    movl $RLIMIT_AS, %edi
    movq %rsp, %rsi
    call getrlimit@PLT              # keep the hard limit
    movq %rbx, 0(%rsp)              # the soft limit: what is mapped now
    movl $RLIMIT_AS, %edi
    movq %rsp, %rsi
    call setrlimit@PLT
    addq $88, %rsp
    popq %rbx
    popq %rbp
    ret
    .section .rodata
.Lstatm: .asciz "/proc/self/statm"
    .text


# sea_main -- the warm-up read, the limit, the failing read. Frame: 8 (%rbp) + 8.
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    leaq .Lsmall(%rip), %rdi
    xorl %esi, %esi                 # site 0
    call sea_read_lines
    movq %rax, %rbx
    movq SEA_ARR_ROWS(%rbx), %rax
    cmpq $2, %rax
    jne 9f                          # (2 lines expected)
    movq %rbx, %rdi                 # count 1: released (sea_free)
    movq $0, SEA_OBJ_RC(%rdi)
    call sea_free
    leaq .Lbefore(%rip), %rdi
    movl $7, %esi
    call sea_out_write              # "before\n", buffered
    call limit_as
    leaq .Lbig(%rip), %rdi
    movl $1, %esi                   # site 1
    call sea_read_lines
9:  leaq .Lafter(%rip), %rdi        # not reached
    movl $12, %esi
    call sea_out_write
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

    .section .rodata
.Lbefore: .ascii "before\n"
.Lafter:  .ascii "not reached\n"
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
.Lsmall:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 9
    .ascii "small.txt"
    .p2align 3
.Lbig:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 7
    .ascii "big.txt"
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
    .quad .Lfile, 50                # site 1

    .section .note.GNU-stack,"",@progbits
