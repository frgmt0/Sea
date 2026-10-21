# =====================================================================
# sea/runtime/x86_64_linux/rt_clock.s -- the monotonic clock behind
# `now()` (LANGUAGE.md 13; DESIGN.md 4.5 "clock", 4.7.1, 4.8 entry NOW).
# The x86_64-linux twin of runtime/arm64_macos/rt_clock.s.
#
# Defines: sea_now   (rt.inc SEA_ENT_NOW)
#
# The value is clock_gettime(CLOCK_MONOTONIC) converted as
# `sec + nsec / 1e9` in f64 arithmetic (LANGUAGE.md 13), the same
# operations in the same order as the arm64-macos runtime, so both
# targets round identically.
# =====================================================================
.include "errors.inc"
.include "rt.inc"

# Linux x86_64 values (DESIGN.md 4.7.1; private to the runtime).
.equ RT_CLOCK_MONOTONIC, 1          # <time.h> CLOCK_MONOTONIC
.equ RT_TS_SEC,          0          # struct timespec: i64 tv_sec
.equ RT_TS_NSEC,         8          # struct timespec: i64 tv_nsec
.equ RT_TS_SIZE,         16
.equ RT_NSEC_PER_SEC,    1000000000

    .text

# ---------------------------------------------------------------------
# sea_now -- seconds on the monotonic clock as an f64.
#   Purpose : clock_gettime(CLOCK_MONOTONIC, &ts); result =
#             (f64)ts.tv_sec + (f64)ts.tv_nsec / 1e9. The call cannot
#             fail for CLOCK_MONOTONIC on a running system; should it
#             ever return non-zero the zeroed timespec yields 0.0.
#   Inputs  : none
#   Outputs : %xmm0 = seconds from an unspecified fixed origin
#   Clobbers: all caller-saved registers (calls libc)
#   Callee-saved used: %rbp = frame pointer
#   Frame   : 8 bytes (%rbp) + RT_TS_SIZE (timespec at 0(%rsp))
# ---------------------------------------------------------------------
    .globl sea_now
    .type sea_now, @function
    .p2align 4
sea_now:
    pushq %rbp                      # %rsp = 0 (mod 16)
    movq %rsp, %rbp
    subq $RT_TS_SIZE, %rsp          # the timespec at 0(%rsp)
    movq $0, RT_TS_SEC(%rsp)        # ts = {0, 0} (defined result on failure)
    movq $0, RT_TS_NSEC(%rsp)
    movl $RT_CLOCK_MONOTONIC, %edi
    movq %rsp, %rsi                 # &ts
    call clock_gettime@PLT
    cvtsi2sdq RT_TS_SEC(%rsp), %xmm0   # (f64) sec  (exact below 2^53)
    cvtsi2sdq RT_TS_NSEC(%rsp), %xmm1  # (f64) nsec (exact)
    movl $RT_NSEC_PER_SEC, %eax
    cvtsi2sdq %rax, %xmm2           # 1e9, exact
    divsd %xmm2, %xmm1              # nsec / 1e9
    addsd %xmm1, %xmm0              # sec + nsec / 1e9
    movq %rbp, %rsp
    popq %rbp
    ret
    .size sea_now, . - sea_now

    .section .note.GNU-stack,"",@progbits
