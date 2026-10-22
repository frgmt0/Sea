# =====================================================================
# sea/runtime/x86_64_linux/rt_args.s -- the command-line arguments
# (DESIGN.md 4.5, 4.7.1, 4.8 entry ARGS; LANGUAGE.md 10.10).
# The x86_64-linux twin of runtime/arm64_macos/rt_args.s.
#
# Defines (global, rt.inc SEA_ENTRY_LIST):
#   sea_args (site) -> a new str[] of the arguments after the program name
# Uses: sea_argc, sea_argv (rt_main.s: main's argc and argv, saved
#   before the stack switch), sea_arr_new (rt_arr.s), sea_alloc and
#   sea_live (rt_mem.s), sea_err (rt_err.s), glibc strlen and memcpy
#   through the PLT.
#
# The vector has argc - 1 elements (none when argc < 1); element i is a
# new string (count 1, counted in sea_live) of the bytes of argv[i + 1]
# up to its NUL, an empty argument giving the empty string. No memory,
# or an argument longer than SEA_LIM_STR_BYTES (impossible on Linux), is
# sea_err(SEA_E_OUT_OF_MEMORY, site).
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

    .text

# ---------------------------------------------------------------------
# sea_args -- entry ARGS (DESIGN.md 4.8).
#   Purpose : see the file header.
#   Inputs  : %rdi = site
#   Outputs : %rax = the str[] (rank 1, count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = site, %r12 = the
#             vector, %r13 = element index, %r14 = the current argument,
#             %r15 = its length, %rbp = frame pointer
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + 8 pad = 56 bytes
# ---------------------------------------------------------------------
    .globl sea_args
    .type sea_args, @function
    .p2align 4
sea_args:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    # The vector: argc - 1 null elements, filled below.
    movq sea_argc(%rip), %rdx
    decq %rdx                       # without the program name
    xorl %eax, %eax
    testq %rdx, %rdx
    cmovsq %rax, %rdx               # argc < 1: no arguments
    movl $SEA_EK_STR, %edi
    movl $1, %esi                   # rank 1
    movl $1, %ecx                   # cols 1: a vector
    movq %rbx, %r8
    call sea_arr_new
    movq %rax, %r12
    xorl %r13d, %r13d
.Lrt_args_loop:
    cmpq SEA_ARR_ROWS(%r12), %r13
    jae .Lrt_args_done
    movq sea_argv(%rip), %rax
    movq 8(%rax,%r13,8), %r14       # argv[i + 1]
    movq %r14, %rdi
    call strlen@PLT
    movq %rax, %r15
    cmpq $SEA_LIM_STR_BYTES, %r15
    ja .Lrt_args_oom
    leaq SEA_STR_BYTES(%r15), %rdi  # a string block
    movq %rbx, %rsi
    call sea_alloc
    movq $1, SEA_STR_RC(%rax)       # count 1
    movq $0, SEA_STR_TAG(%rax)      # the tag and the 7 bytes after it
    movb $SEA_TAG_STR, SEA_STR_TAG(%rax)
    movq %r15, SEA_STR_LEN(%rax)
    incq sea_live(%rip)             # one more live object
    movq SEA_ARR_DATA(%r12), %rcx
    movq %rax, (%rcx,%r13,8)        # element i (the vector owns its count)
    leaq SEA_STR_BYTES(%rax), %rdi
    movq %r14, %rsi
    movq %r15, %rdx
    call memcpy@PLT                 # the argument's bytes
    incq %r13
    jmp .Lrt_args_loop
.Lrt_args_done:
    movq %r12, %rax
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_args_oom:
    movl $SEA_E_OUT_OF_MEMORY, %edi
    movq %rbx, %rsi
    xorl %edx, %edx
    call sea_err                    # noreturn
    ud2
    .size sea_args, . - sea_args

    .section .note.GNU-stack,"",@progbits
