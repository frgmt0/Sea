// =====================================================================
// sea/runtime/arm64_macos/rt_main.s -- process entry, program stack,
// stack-overflow signal handling and kernel selection
// (DESIGN.md 4.4, 4.5, 4.6, 4.8; LANGUAGE.md 9.2, 9.4).
//
// Defines: _main, _sea_stack_limit, _sea_variant   (global, rt.inc)
// Uses   : _sea_main and _sea_sites (the program), _sea_err (rt_err.s),
//          _sea_out_flush and _sea_out_fail (rt_out.s), and Baysick's
//          _bsk_kern_init, _bsk_kern_use, _bsk_kern_variants.
//
// Start-up (Baysick's program-stack technique, Baysick DESIGN.md 6.9):
//   1. SIGPIPE is ignored, so a write to a closed pipe is EPIPE, which
//      the output layer reports as `cannot write '<stdout>': Broken pipe`.
//   2. The program stack: G = sysconf(_SC_PAGESIZE); mmap of
//      SEA_STACK_BYTES (64 MiB) + G, private anonymous read/write; the
//      lowest G bytes are mprotect()ed PROT_NONE: the guard page.
//      _sea_stack_limit = base + G + SEA_STACK_MARGIN (the lowest
//      address sp may reach in checked code, DESIGN.md 4.6).
//      A failure of sysconf, mmap, mprotect, sigaltstack or sigaction is the run-time error
//      `out of memory` (SEA_E_OUT_OF_MEMORY, no location).
//   3. An alternate signal stack (RT_ALTSTACK_BYTES, static) and
//      SA_ONSTACK|SA_SIGINFO handlers for SIGSEGV and SIGBUS. A fault
//      whose address lies in the guard page is the run-time error
//      `stack overflow` with no location (SEA_SITE_NONE), reported by
//      _sea_err, which flushes standard output first and ends with
//      _exit (status 1), never exit (DESIGN.md 4.6); a fault
//      anywhere else gets the default action back (the handler resets
//      the signal to SIG_DFL and returns, so the instruction faults
//      again and the process dies as it would without a handler).
//      Every other signal keeps its default action.
//   4. Kernels: _bsk_kern_init selects a Baysick variant from
//      BAYSICK_KERNELS; Sea must not depend on that variable, so the
//      runtime re-selects: SEA_KERNELS, if it names a usable variant or
//      `baseline`, else the first name of _bsk_kern_variants() (the best
//      usable variant) (DESIGN.md 4.4). _sea_variant = SEA_VAR_NEON: the
//      only variant id of arm64-macos (`baseline` is also NEON code).
//   5. sp := the top of the new stack, x29 := 0, call _sea_main.
// When _sea_main returns: the final flush of standard output
// (_sea_out_flush). If it fails: _sea_err(SEA_E_CANNOT_WRITE,
// SEA_SITE_NONE, {"<stdout>", errno}), i.e. `error: cannot write
// '<stdout>': <reason>`, status 1 (LANGUAGE.md 9.2, 9.4). Otherwise
// _exit(SEA_EXIT_RUN_OK) (all output is already written). The stack is
// never unmapped.
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"
.include "runtime.inc"        // Baysick's (found through -I $BAYSICK/include): the kernel entry points called below

.equ RT_ALTSTACK_BYTES, 65536       /* alternate signal stack for the handlers */
.equ RT_SC_PAGESIZE,    29          /* sysconf(_SC_PAGESIZE) on Darwin */
.equ RT_PROT_NONE,      0
.equ RT_PROT_RW,        3           /* PROT_READ | PROT_WRITE */
.equ RT_MAP_PRIVANON,   0x1002      /* MAP_PRIVATE | MAP_ANON */
.equ RT_SIGPIPE,        13
.equ RT_SIGSEGV,        11
.equ RT_SIGBUS,         10
.equ RT_SIG_DFL,        0
.equ RT_SIG_IGN,        1
.equ RT_SA_ONSTACK,     0x0001
.equ RT_SA_SIGINFO,     0x0040
.equ RT_SI_ADDR,        24          /* siginfo_t.si_addr on Darwin arm64 */
// stack_t (Darwin): ss_sp, ss_size, ss_flags
.equ RT_SS_SP,          0
.equ RT_SS_SIZE,        8
.equ RT_SS_FLAGS,       16
// struct sigaction (Darwin): handler, sa_mask (u32), sa_flags (int)
.equ RT_SA_HANDLER,     0
.equ RT_SA_MASK,        8
.equ RT_SA_FLAGS,       12
.equ RT_MAIN_SCRATCH,   48          /* stack_t at +0 (24 bytes), sigaction at +32 (16 bytes) */

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// _main -- process entry point of every compiled Sea program.
//   Purpose : the start-up sequence of the file header, the call of
//             _sea_main on the new stack, the final flush and exit.
//   Inputs  : w0 = argc, x1 = argv (ignored)
//   Outputs : never returns
//   Clobbers: everything (control never comes back)
//   Callee-saved used: x19 = G (page size), x20 = mapping base
//   Frame   : 32 + RT_MAIN_SCRATCH bytes on the process stack (frame
//             record, x19, x20, scratch for stack_t / sigaction); the
//             program runs on the new stack, with x29 = 0
// ---------------------------------------------------------------------
    .globl _main
    .p2align 2
_main:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    sub sp, sp, #RT_MAIN_SCRATCH    // scratch at [sp]

    // 1. Ignore SIGPIPE: signal(SIGPIPE, SIG_IGN).
    mov w0, #RT_SIGPIPE
    mov x1, #RT_SIG_IGN
    bl _signal

    // 2. The program stack. G = the host page size (16 KiB on arm64).
    mov w0, #RT_SC_PAGESIZE
    bl _sysconf
    cmp x0, #0
    b.le Lrt_main_oom               // -1: no page size (never on macOS)
    mov x19, x0
    mov x0, #0                      // addr: anywhere
    mov x1, #SEA_STACK_BYTES
    add x1, x1, x19                 // size + G
    mov w2, #RT_PROT_RW
    mov w3, #RT_MAP_PRIVANON
    mov w4, #-1                     // fd: none
    mov x5, #0                      // offset
    bl _mmap
    cmn x0, #1
    b.eq Lrt_main_oom               // MAP_FAILED
    mov x20, x0
    mov x1, x19                     // the lowest G bytes ...
    mov w2, #RT_PROT_NONE
    bl _mprotect                    // ... become the guard page (x0 = base)
    cbnz w0, Lrt_main_oom
    // Record the guard page [base, base+G) for the handler and the
    // limit for the prologue checks.
    add x9, x20, x19                // base + G: the top of the guard page
    adrp x10, Lrt_main_guard@PAGE
    add x10, x10, Lrt_main_guard@PAGEOFF
    stp x20, x9, [x10]              // guard lo, hi
    mov x11, #SEA_STACK_MARGIN
    add x11, x9, x11                // _sea_stack_limit
    adrp x10, _sea_stack_limit@PAGE
    str x11, [x10, _sea_stack_limit@PAGEOFF]

    // 3. Alternate signal stack and the SIGSEGV / SIGBUS handlers.
    adrp x9, Lrt_main_altstack@PAGE
    add x9, x9, Lrt_main_altstack@PAGEOFF
    mov x10, #RT_ALTSTACK_BYTES
    str x9, [sp, #RT_SS_SP]
    str x10, [sp, #RT_SS_SIZE]
    str wzr, [sp, #RT_SS_FLAGS]
    mov x0, sp                      // &stack_t
    mov x1, #0                      // old: not wanted
    bl _sigaltstack
    cbnz w0, Lrt_main_oom           // a start-up failure, like mmap
    adrp x9, Lrt_main_segv@PAGE
    add x9, x9, Lrt_main_segv@PAGEOFF
    add x12, sp, #32                // &sigaction
    str x9, [x12, #RT_SA_HANDLER]
    str wzr, [x12, #RT_SA_MASK]
    mov w9, #(RT_SA_ONSTACK | RT_SA_SIGINFO)
    str w9, [x12, #RT_SA_FLAGS]
    mov w0, #RT_SIGSEGV
    mov x1, x12
    mov x2, #0
    bl _sigaction
    cbnz w0, Lrt_main_oom
    mov w0, #RT_SIGBUS
    add x1, sp, #32
    mov x2, #0
    bl _sigaction
    cbnz w0, Lrt_main_oom

    // 4. Kernel selection (DESIGN.md 4.4).
    bl _bsk_kern_init
    adrp x0, Lrt_main_s_env@PAGE
    add x0, x0, Lrt_main_s_env@PAGEOFF
    bl _getenv                      // SEA_KERNELS or NULL
    cbz x0, Lrt_main_auto
    ldrb w9, [x0]
    cbz w9, Lrt_main_auto           // empty: auto
    bl _bsk_kern_use                // 0 ok, -1 unknown / unusable
    cmp w0, #0
    b.eq Lrt_main_kern_done         // the named variant (or baseline)
Lrt_main_auto:
    bl _bsk_kern_variants           // NULL-terminated array of usable names, best first
    ldr x0, [x0]
    bl _bsk_kern_use                // always succeeds for a name it lists
Lrt_main_kern_done:
    mov x9, #SEA_VAR_NEON
    adrp x10, _sea_variant@PAGE
    str x9, [x10, _sea_variant@PAGEOFF]

    // 5. Switch to the new stack (page-aligned, hence 16-byte aligned)
    //    and run the program there. The old frame is not used again.
    adrp x10, Lrt_main_guard@PAGE
    ldr x9, [x10, Lrt_main_guard@PAGEOFF + 8]   // guard hi = base + G
    mov x10, #SEA_STACK_BYTES
    add x9, x9, x10
    and x9, x9, #~15
    mov sp, x9
    mov x29, #0                     // end of the frame-record chain
    bl _sea_main

    // The final flush; a failure is `cannot write '<stdout>'` with no site.
    bl _sea_out_flush               // x0 = 0 or errno
    cbz x0, Lrt_main_exit
    mov x1, #SEA_SITE_NONE
    bl _sea_out_fail                // noreturn
Lrt_main_exit:
    mov w0, #SEA_EXIT_RUN_OK
    bl _exit                        // does not return
    brk #1                          // not reached

Lrt_main_oom:
    mov w0, #SEA_E_OUT_OF_MEMORY    // before any user code ran
    mov x1, #SEA_SITE_NONE
    mov x2, #0
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// Lrt_main_segv -- SIGSEGV / SIGBUS handler (runs on the alternate stack).
//   Purpose : a fault in the guard page is the run-time error `stack
//             overflow` without location. Any other fault: the signal
//             gets its default action and the handler returns, so the
//             faulting instruction runs again and kills the process the
//             default way.
//   Inputs  : w0 = signal number, x1 = siginfo_t *, x2 = ucontext (unused)
//   Outputs : returns only in the "any other fault" case
//   Clobbers: x0-x17 (a signal handler: everything but sp)
//   Callee-saved used: none
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_main_segv:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    ldr x9, [x1, #RT_SI_ADDR]       // the faulting address
    adrp x10, Lrt_main_guard@PAGE
    add x10, x10, Lrt_main_guard@PAGEOFF
    ldp x11, x12, [x10]             // guard [lo, hi)
    cmp x9, x11
    b.lo Lrt_main_segv_other
    cmp x9, x12
    b.hs Lrt_main_segv_other
    mov w0, #SEA_E_STACK_OVERFLOW
    mov x1, #SEA_SITE_NONE
    mov x2, #0
    bl _sea_err                     // noreturn
Lrt_main_segv_other:
    mov x1, #RT_SIG_DFL             // w0 still the signal number
    bl _signal
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// Data shared with compiled code and the runtime.
// ---------------------------------------------------------------------
    .section __TEXT,__cstring,cstring_literals
Lrt_main_s_env:     .asciz "SEA_KERNELS"

    .section __DATA,__bss
    .globl _sea_stack_limit
    .globl _sea_variant
.zerofill __DATA,__bss,_sea_stack_limit,8,3 /* lowest sp the prologue check accepts */
.zerofill __DATA,__bss,_sea_variant,8,3     /* SEA_VAR_* of the selected variant */
.zerofill __DATA,__bss,Lrt_main_guard,16,3  /* guard page [lo, hi) */
.zerofill __DATA,__bss,Lrt_main_altstack,RT_ALTSTACK_BYTES,4
