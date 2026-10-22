# =====================================================================
# sea/runtime/x86_64_linux/rt_main.s -- process entry, program stack,
# stack-overflow signal handling and kernel selection
# (DESIGN.md 4.4, 4.5, 4.6, 4.7.1, 4.8; LANGUAGE.md 9.2, 9.4).
# The x86_64-linux twin of runtime/arm64_macos/rt_main.s.
#
# Defines: main, sea_stack_limit, sea_variant   (global, rt.inc)
#          sea_argc, sea_argv   (.globl + .hidden: internal, DESIGN.md
#                               4.5; read by sea_args, rt_args.s)
# Uses   : sea_main and sea_sites (the program), sea_err (rt_err.s),
#          sea_out_flush and sea_out_fail (rt_out.s), sea_write_all
#          (rt_out.s), sea_live (rt_mem.s), Baysick's
#          bsk_kern_init, bsk_kern_use, bsk_kern_variants, bsk_kern_name
#          (libbaysickrt.a), and glibc through the PLT.
#
# Start-up (Baysick's program-stack technique, Baysick DESIGN.md 6.9):
#   0. argc (sign-extended) and argv are saved in sea_argc and sea_argv
#      before anything else (DESIGN.md 4.5, sea_args), and the heap
#      check is armed when the environment variable SEA_HEAP_CHECK is
#      exactly "1" (DESIGN.md 4.5).
#   1. SIGPIPE is ignored, so a write to a closed pipe is EPIPE, which
#      the output layer reports as `cannot write '<stdout>': Broken pipe`.
#   2. The program stack: G = sysconf(_SC_PAGESIZE); mmap of
#      SEA_STACK_BYTES (64 MiB) + G, private anonymous read/write; the
#      lowest G bytes are mprotect()ed PROT_NONE: the guard page.
#      sea_stack_limit = base + G + SEA_STACK_MARGIN (the lowest
#      address %rsp may reach in checked code, DESIGN.md 4.6).
#      A failure of sysconf, mmap, mprotect, sigaltstack or sigaction is
#      the run-time error `out of memory` (SEA_E_OUT_OF_MEMORY, no
#      location).
#   3. An alternate signal stack (RT_ALTSTACK_BYTES, static) and
#      SA_ONSTACK|SA_SIGINFO handlers for SIGSEGV and SIGBUS. A fault
#      whose address (si_addr) lies in the guard page is the run-time
#      error `stack overflow` with no location (SEA_SITE_NONE), reported
#      by sea_err, which flushes standard output first and ends with
#      _exit (status 1), never exit (DESIGN.md 4.6). A fault anywhere
#      else, and a signal that was sent rather than raised by a fault
#      (si_code <= 0: kill, tkill, raise, sigqueue), gets the default
#      action: the handler resets the signal to SIG_DFL, unblocks it and
#      raises it again, so the process dies by that signal as it would
#      without a handler. Every other signal keeps its default action.
#   4. Kernels: bsk_kern_init selects a Baysick variant from
#      BAYSICK_KERNELS; Sea must not depend on that variable, so the
#      runtime re-selects: SEA_KERNELS, if it names a usable variant or
#      `baseline`, else the first name of bsk_kern_variants() (the best
#      usable variant) (DESIGN.md 4.4). sea_variant is then set from the
#      selected variant's name (bsk_kern_name, DESIGN.md 4.7.1): "avx2"
#      -> SEA_VAR_AVX2; any other name ("sse2", which `baseline` also
#      selects: Baysick's x86_64 baseline is SSE2 code) -> SEA_VAR_SSE2.
#   5. %rsp := the top of the new stack (page-aligned), %rbp := 0, call
#      sea_main with %rsp = 0 (mod 16).
# When sea_main returns: the final flush of standard output
# (sea_out_flush). If it fails: sea_err(SEA_E_CANNOT_WRITE,
# SEA_SITE_NONE, {"<stdout>", errno}), i.e. `error: cannot write
# '<stdout>': <reason>`, status 1 (LANGUAGE.md 9.2, 9.4). Otherwise,
# when the heap check is armed, the line `heap: N live objects` + LF
# goes to standard error (N = sea_live in decimal, no sign or padding;
# a failed write of it is ignored), and then _exit(SEA_EXIT_RUN_OK) (all
# output is already written). A run-time error, `error` and a failed
# final flush end in sea_err without the heap line. The stack is never
# unmapped.
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"
.include "runtime.inc"              # Baysick's (found through -I <baysick>/include): the kernel entry points called below

# Linux x86_64 / glibc values (DESIGN.md 4.7.1; private to the runtime).
.equ RT_ALTSTACK_BYTES, 65536       # alternate signal stack for the handlers
.equ RT_SC_PAGESIZE,    30          # sysconf(_SC_PAGESIZE)
.equ RT_PROT_NONE,      0
.equ RT_PROT_RW,        3           # PROT_READ | PROT_WRITE
.equ RT_MAP_PRIVANON,   0x22        # MAP_PRIVATE | MAP_ANONYMOUS
.equ RT_SIGPIPE,        13
.equ RT_SIGSEGV,        11
.equ RT_SIGBUS,         7
.equ RT_SIG_DFL,        0
.equ RT_SIG_IGN,        1
.equ RT_SA_FLAGS_VAL,   0x08000004  # SA_ONSTACK | SA_SIGINFO
.equ RT_SI_CODE,        8           # siginfo_t.si_code (i32): > 0 a fault, <= 0 sent by kill/tkill/raise/sigqueue
.equ RT_SI_ADDR,        16          # siginfo_t.si_addr
.equ RT_SIG_UNBLOCK,    1           # sigprocmask how: SIG_UNBLOCK
.equ RT_SIGSET_BYTES,   128         # glibc sigset_t
# stack_t: ss_sp ptr, ss_flags i32, ss_size u64; 24 bytes
.equ RT_SS_SP,          0
.equ RT_SS_FLAGS,       8
.equ RT_SS_SIZE,        16
# glibc's struct sigaction: sa_sigaction ptr, sa_mask 128 bytes,
# sa_flags i32, sa_restorer ptr; 152 bytes
.equ RT_SA_HANDLER,     0
.equ RT_SA_MASK,        8
.equ RT_SA_FLAGS,       136
.equ RT_SA_RESTORER,    144
.equ RT_SA_SIZE,        152
.equ RT_MAIN_SA,        32          # the sigaction in main's scratch (stack_t at 0)
.equ RT_MAIN_SCRATCH,   (RT_MAIN_SA + RT_SA_SIZE + 8) # 192: a multiple of 16
# The heap line (DESIGN.md 4.5): "heap: " (6 bytes), at most 20 digits,
# " live objects\n" (14 bytes), built in RT_MAIN_HEAPLINE bytes.
.equ RT_MAIN_S_HEAP_LEN, 6
.equ RT_MAIN_S_LIVE_LEN, 14
.equ RT_MAIN_HEAPLINE,  48          # >= 6 + 20 + 14, a multiple of 16

    .text

# ---------------------------------------------------------------------
# main -- process entry point of every compiled Sea program (called by
#   glibc's start code).
#   Purpose : the start-up sequence of the file header, the call of
#             sea_main on the new stack, the final flush and exit.
#   Inputs  : %edi = argc, %rsi = argv (saved in sea_argc, sea_argv)
#   Outputs : never returns
#   Clobbers: everything (control never comes back)
#   Callee-saved used (not restored: the function never returns):
#             %rbp = frame pointer (then 0 on the program stack),
#             %rbx = mapping base, %r12 = G (page size)
#   Frame   : 24 bytes (%rbp %rbx %r12) + RT_MAIN_SCRATCH (stack_t,
#             sigaction) on the process stack; entered at %rsp = 8
#             (mod 16), so %rsp = 0 (mod 16) at every call; the program
#             runs on the new stack
# ---------------------------------------------------------------------
    .globl main
    .type main, @function
    .p2align 4
main:
    pushq %rbp                      # entered with %rsp = 8 (mod 16): now 0
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    subq $RT_MAIN_SCRATCH, %rsp     # scratch at 0(%rsp)

    # 0. The arguments for sea_args, and the heap check (DESIGN.md 4.5).
    movslq %edi, %rax
    movq %rax, sea_argc(%rip)
    movq %rsi, sea_argv(%rip)
    leaq .Lrt_main_s_heapenv(%rip), %rdi
    call getenv@PLT                 # SEA_HEAP_CHECK or NULL
    testq %rax, %rax
    jz 1f                           # unset: no check
    cmpb $49, (%rax)                # '1' ...
    jne 1f
    cmpb $0, 1(%rax)                # ... and nothing after it
    jne 1f
    movq $1, .Lrt_main_heapchk(%rip)
1:
    # 1. Ignore SIGPIPE: signal(SIGPIPE, SIG_IGN).
    movl $RT_SIGPIPE, %edi
    movl $RT_SIG_IGN, %esi
    call signal@PLT

    # 2. The program stack. G = the host page size.
    movl $RT_SC_PAGESIZE, %edi
    call sysconf@PLT
    testq %rax, %rax
    jle .Lrt_main_oom               # -1 (or 0): no page size
    movq %rax, %r12
    xorl %edi, %edi                 # addr: anywhere
    leaq SEA_STACK_BYTES(%r12), %rsi # size + G
    movl $RT_PROT_RW, %edx
    movl $RT_MAP_PRIVANON, %ecx
    movl $-1, %r8d                  # fd: none
    xorl %r9d, %r9d                 # offset
    call mmap@PLT
    cmpq $-1, %rax
    je .Lrt_main_oom                # MAP_FAILED
    movq %rax, %rbx
    movq %rbx, %rdi                 # the lowest G bytes ...
    movq %r12, %rsi
    movl $RT_PROT_NONE, %edx
    call mprotect@PLT               # ... become the guard page
    testl %eax, %eax
    jnz .Lrt_main_oom
    # Record the guard page [base, base+G) for the handler and the
    # limit for the prologue checks.
    leaq (%rbx,%r12), %rax          # base + G: the top of the guard page
    movq %rbx, .Lrt_main_guard(%rip)        # guard lo
    movq %rax, .Lrt_main_guard+8(%rip)      # guard hi
    addq $SEA_STACK_MARGIN, %rax
    movq %rax, sea_stack_limit(%rip)

    # 3. Alternate signal stack and the SIGSEGV / SIGBUS handlers.
    leaq .Lrt_main_altstack(%rip), %rax
    movq %rax, RT_SS_SP(%rsp)
    movl $0, RT_SS_FLAGS(%rsp)
    movl $0, RT_SS_FLAGS+4(%rsp)    # padding
    movq $RT_ALTSTACK_BYTES, RT_SS_SIZE(%rsp)
    movq %rsp, %rdi                 # &stack_t
    xorl %esi, %esi                 # old: not wanted
    call sigaltstack@PLT
    testl %eax, %eax
    jnz .Lrt_main_oom               # a start-up failure, like mmap
    leaq RT_MAIN_SA(%rsp), %rdi     # the sigaction: all zero (empty mask,
    xorl %eax, %eax                 # no restorer: glibc supplies it) ...
    movl $(RT_SA_SIZE / 8), %ecx
    rep stosq                       # (the direction flag is clear)
    leaq .Lrt_main_segv(%rip), %rax # ... then the handler and the flags
    movq %rax, RT_MAIN_SA+RT_SA_HANDLER(%rsp)
    movl $RT_SA_FLAGS_VAL, RT_MAIN_SA+RT_SA_FLAGS(%rsp)
    movl $RT_SIGSEGV, %edi
    leaq RT_MAIN_SA(%rsp), %rsi
    xorl %edx, %edx                 # old: not wanted
    call sigaction@PLT
    testl %eax, %eax
    jnz .Lrt_main_oom
    movl $RT_SIGBUS, %edi
    leaq RT_MAIN_SA(%rsp), %rsi
    xorl %edx, %edx
    call sigaction@PLT
    testl %eax, %eax
    jnz .Lrt_main_oom

    # 4. Kernel selection (DESIGN.md 4.4).
    call bsk_kern_init
    leaq .Lrt_main_s_env(%rip), %rdi
    call getenv@PLT                 # SEA_KERNELS or NULL
    testq %rax, %rax
    jz .Lrt_main_auto
    cmpb $0, (%rax)
    je .Lrt_main_auto               # empty: auto
    movq %rax, %rdi
    call bsk_kern_use               # 0 ok, -1 unknown / unusable
    testq %rax, %rax
    jz .Lrt_main_kern_done          # the named variant (or baseline)
.Lrt_main_auto:
    call bsk_kern_variants          # NULL-terminated array of usable names, best first
    movq (%rax), %rdi
    call bsk_kern_use               # always succeeds for a name it lists
.Lrt_main_kern_done:
    call bsk_kern_name              # the selected variant's name
    movq %rax, %rdi
    leaq .Lrt_main_s_avx2(%rip), %rsi
    call strcmp@PLT
    movl $SEA_VAR_SSE2, %ecx        # sse2 (and baseline, which is sse2)
    movl $SEA_VAR_AVX2, %edx
    testl %eax, %eax
    cmovzl %edx, %ecx               # avx2
    movq %rcx, sea_variant(%rip)

    # 5. Switch to the new stack (page-aligned, hence 16-byte aligned)
    #    and run the program there. The old frame is not used again.
    movq .Lrt_main_guard+8(%rip), %rax  # guard hi = base + G
    addq $SEA_STACK_BYTES, %rax
    andq $-16, %rax
    movq %rax, %rsp
    xorl %ebp, %ebp                 # end of the frame-pointer chain
    call sea_main

    # The final flush; a failure is `cannot write '<stdout>'` with no site.
    call sea_out_flush              # %rax = 0 or errno
    testq %rax, %rax
    jz .Lrt_main_exit
    movq %rax, %rdi
    movq $SEA_SITE_NONE, %rsi
    call sea_out_fail               # noreturn
.Lrt_main_exit:
    cmpq $0, .Lrt_main_heapchk(%rip)
    je .Lrt_main_exit0
    # The heap line, built right to left in RT_MAIN_HEAPLINE bytes at
    # 0(%rsp) (%rsp = 0 (mod 16) here, the top of the program stack):
    # "heap: " N " live objects" LF. main never returns, so %rbx and
    # %r12 (no longer needed) hold the line's start and end.
    subq $RT_MAIN_HEAPLINE, %rsp
    leaq RT_MAIN_HEAPLINE(%rsp), %r12 # the end of the line
    leaq -RT_MAIN_S_LIVE_LEN(%r12), %rbx
    movq %rbx, %rdi
    leaq .Lrt_main_s_live(%rip), %rsi
    movl $RT_MAIN_S_LIVE_LEN, %edx
    call memcpy@PLT                 # " live objects\n" at the end
    movq sea_live(%rip), %rax       # N, unsigned, digits right to left
    movl $10, %ecx
2:  xorl %edx, %edx
    divq %rcx                       # %rdx = the next digit
    addb $48, %dl                   # '0'
    decq %rbx
    movb %dl, (%rbx)
    testq %rax, %rax
    jnz 2b
    subq $RT_MAIN_S_HEAP_LEN, %rbx
    movq %rbx, %rdi
    leaq .Lrt_main_s_heap(%rip), %rsi
    movl $RT_MAIN_S_HEAP_LEN, %edx
    call memcpy@PLT                 # "heap: " in front
    movl $2, %edi                   # fd 2
    movq %rbx, %rsi
    movq %r12, %rdx
    subq %rbx, %rdx                 # the line's length
    call sea_write_all              # a failure is ignored
.Lrt_main_exit0:
    movl $SEA_EXIT_RUN_OK, %edi
    call _exit@PLT                  # does not return
    ud2                             # not reached

.Lrt_main_oom:
    movl $SEA_E_OUT_OF_MEMORY, %edi # before any user code ran
    movq $SEA_SITE_NONE, %rsi
    xorl %edx, %edx
    call sea_err                    # noreturn
    ud2
    .size main, . - main

# ---------------------------------------------------------------------
# .Lrt_main_segv -- SIGSEGV / SIGBUS handler (runs on the alternate
#   stack).
#   Purpose : a fault (si_code > 0) whose address lies in the guard page
#             is the run-time error `stack overflow` without location.
#             Anything else -- a fault elsewhere, or a signal sent with
#             kill/tkill/raise/sigqueue (si_code <= 0) -- gets the
#             default action: the signal is reset to SIG_DFL, unblocked
#             (it is blocked while its handler runs) and raised again,
#             so the process dies by it at once (status 128 + signal
#             through a shell). Should the process survive the raise,
#             the handler returns.
#   Inputs  : %edi = signal number, %rsi = siginfo_t *, %rdx = ucontext
#             (unused)
#   Outputs : does not return in practice (see Purpose)
#   Clobbers: all caller-saved registers (the kernel restores the
#             interrupted context on return)
#   Callee-saved used: %rbx = signal number (saved and restored),
#             %rbp = frame pointer
#   Frame   : 16 bytes (%rbp %rbx) + RT_SIGSET_BYTES (the sigset_t at
#             0(%rsp)) + 8 pad; entered at %rsp = 8 (mod 16), so %rsp =
#             0 (mod 16) at the calls
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_main_segv:
    pushq %rbp                      # %rsp = 0 (mod 16)
    movq %rsp, %rbp
    pushq %rbx
    subq $(RT_SIGSET_BYTES + 8), %rsp # %rsp = 0 (mod 16)
    movl %edi, %ebx                 # the signal number
    cmpl $0, RT_SI_CODE(%rsi)
    jle .Lrt_main_segv_other        # sent, not a fault (SI_USER 0, SI_TKILL -6, ...)
    movq RT_SI_ADDR(%rsi), %rax     # the faulting address
    cmpq .Lrt_main_guard(%rip), %rax
    jb .Lrt_main_segv_other         # below the guard page
    cmpq .Lrt_main_guard+8(%rip), %rax
    jae .Lrt_main_segv_other        # above it
    movl $SEA_E_STACK_OVERFLOW, %edi
    movq $SEA_SITE_NONE, %rsi
    xorl %edx, %edx
    call sea_err                    # noreturn
.Lrt_main_segv_other:
    movl %ebx, %edi
    movl $RT_SIG_DFL, %esi
    call signal@PLT                 # the default action back
    movq %rsp, %rdi                 # an empty sigset_t ...
    xorl %eax, %eax
    movl $(RT_SIGSET_BYTES / 8), %ecx
    rep stosq                       # (the direction flag is clear in a handler)
    leal -1(%rbx), %ecx
    movl $1, %eax
    shlq %cl, %rax
    movq %rax, (%rsp)               # ... holding just this signal (bit sig-1)
    movl $RT_SIG_UNBLOCK, %edi
    movq %rsp, %rsi
    xorl %edx, %edx                 # old mask: not wanted
    call sigprocmask@PLT
    movl %ebx, %edi
    call raise@PLT                  # dies here by the signal's default action
    addq $(RT_SIGSET_BYTES + 8), %rsp
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# Data shared with compiled code and the runtime.
# ---------------------------------------------------------------------
    .section .rodata
.Lrt_main_s_env:    .asciz "SEA_KERNELS"
.Lrt_main_s_avx2:   .asciz "avx2"
.Lrt_main_s_heapenv: .asciz "SEA_HEAP_CHECK"
.Lrt_main_s_heap:   .ascii "heap: "
.Lrt_main_s_heap_end:
.Lrt_main_s_live:   .ascii " live objects\n"
.Lrt_main_s_live_end:
.if ((.Lrt_main_s_heap_end - .Lrt_main_s_heap) != RT_MAIN_S_HEAP_LEN) || ((.Lrt_main_s_live_end - .Lrt_main_s_live) != RT_MAIN_S_LIVE_LEN)
    .error "rt_main: the heap-line texts do not match their lengths"
.endif

    .bss
    .p2align 3
    .globl sea_stack_limit
    .type sea_stack_limit, @object
    .size sea_stack_limit, 8
sea_stack_limit:
    .zero 8                         # lowest %rsp the prologue check accepts
    .globl sea_variant
    .type sea_variant, @object
    .size sea_variant, 8
sea_variant:
    .zero 8                         # SEA_VAR_* of the selected variant
    .globl sea_argc
    .hidden sea_argc
    .type sea_argc, @object
    .size sea_argc, 8
sea_argc:
    .zero 8                         # main's argc, sign-extended (for sea_args)
    .globl sea_argv
    .hidden sea_argv
    .type sea_argv, @object
    .size sea_argv, 8
sea_argv:
    .zero 8                         # main's argv (for sea_args)
.Lrt_main_heapchk:
    .zero 8                         # 1: SEA_HEAP_CHECK is "1", write the heap line
.Lrt_main_guard:
    .zero 16                        # guard page [lo, hi)
    .p2align 4
.Lrt_main_altstack:
    .zero RT_ALTSTACK_BYTES

    .section .note.GNU-stack,"",@progbits
