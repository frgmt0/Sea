// =====================================================================
// sea/runtime/arm64_macos/rt_clock.s -- the monotonic clock behind
// `now()` (LANGUAGE.md 13; DESIGN.md 4.5 "clock", 4.8 entry NOW).
//
// Defines: _sea_now   (rt.inc SEA_ENT_NOW, symbol sea_now)
//
// The value is clock_gettime(CLOCK_MONOTONIC) converted as
// `sec + nsec / 1e9` in f64 arithmetic (LANGUAGE.md 13), the same
// operations in the same order as the x86_64-linux runtime, so both
// targets round identically.
// =====================================================================
.include "errors.inc"
.include "rt.inc"

.equ RT_CLOCK_MONOTONIC, 6          /* <time.h> CLOCK_MONOTONIC on Darwin */
.equ RT_TS_SEC,          0          /* struct timespec: i64 tv_sec */
.equ RT_TS_NSEC,         8          /* struct timespec: i64 tv_nsec */
.equ RT_TS_SIZE,         16

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// _sea_now -- seconds on the monotonic clock as an f64.
//   Purpose : clock_gettime(CLOCK_MONOTONIC, &ts); result =
//             (f64)ts.tv_sec + (f64)ts.tv_nsec / 1e9. The call cannot
//             fail for CLOCK_MONOTONIC on a running system; should it
//             ever return non-zero the zeroed timespec yields 0.0.
//   Inputs  : none
//   Outputs : d0 = seconds from an unspecified fixed origin
//   Clobbers: x0-x17, d0-d7, d16-d31 (calls libc)
//   Callee-saved used: none
//   Frame   : 16 + RT_TS_SIZE bytes (frame record, timespec)
// ---------------------------------------------------------------------
    .globl _sea_now
    .p2align 2
_sea_now:
    stp x29, x30, [sp, #-32]!       // frame record, timespec at sp+16
    mov x29, sp
    stp xzr, xzr, [sp, #16]         // ts = {0, 0} (defined result on failure)
    mov w0, #RT_CLOCK_MONOTONIC
    add x1, sp, #16                 // &ts
    bl _clock_gettime
    ldr x9, [sp, #16 + RT_TS_SEC]   // seconds
    ldr x10, [sp, #16 + RT_TS_NSEC] // nanoseconds, 0 .. 999999999
    scvtf d0, x9                    // (f64) sec  (exact below 2^53)
    scvtf d1, x10                   // (f64) nsec (exact)
    movz x11, #0xCA00               // 1000000000 = 0x3B9ACA00
    movk x11, #0x3B9A, lsl #16
    scvtf d2, x11                   // 1e9, exact
    fdiv d1, d1, d2                 // nsec / 1e9
    fadd d0, d0, d1                 // sec + nsec / 1e9
    ldp x29, x30, [sp], #32
    ret
