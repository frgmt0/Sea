// sea/tests/rt/arm64_macos/rt_clock_monotonic.s -- _sea_now (LANGUAGE 13): positive, equals sec + nsec/1e9 of CLOCK_MONOTONIC (between two direct readings), advances across a sleep, nanosecond resolution
.include "errors.inc"
.include "rt.inc"

// A static string object (rt.inc SEA_STR_*): count SEA_RC_STATIC, tag, length, bytes.
.macro SSTR label, len, text
    .p2align 3
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad \len
    .ascii "\text"
.endm
// Append static bytes to the standard-output buffer (x0, x1 clobbered).
.macro PUT label, len
    adrp x0, \label@PAGE
    add x0, x0, \label@PAGEOFF
    mov x1, #\len
    bl _sea_out_write
.endm
// _sea_err(code, site, slots label); noreturn.
.macro RAISE code, site, slots
    mov w0, #\code
    mov x1, #\site
    adrp x2, \slots@PAGE
    add x2, x2, \slots@PAGEOFF
    bl _sea_err
.endm
// Load a 32-bit constant into a register.
.macro LI reg, val
    movz \reg, #((\val) & 0xffff)
    movk \reg, #(((\val) >> 16) & 0xffff), lsl #16
.endm
// Function prologue / epilogue of _sea_main-like routines (frame record only).
.macro PROLOGUE
    stp x29, x30, [sp, #-16]!
    mov x29, sp
.endm
.macro EPILOGUE
    ldp x29, x30, [sp], #16
    ret
.endm

    .section __TEXT,__text,regular,pure_instructions
    .globl _sea_main
    .p2align 2
_sea_main:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp d8, d9, [sp, #16]
    str d10, [sp, #32]
    str x19, [sp, #40]
    // ts0 at sp+48, ts2 at sp+64
    add x0, sp, #48
    bl Lread                    // d0 = CLOCK_MONOTONIC now, converted
    fmov d8, d0                 // before
    bl _sea_now
    fmov d9, d0                 // the value under test
    add x0, sp, #64
    bl Lread
    fmov d10, d0                // after

    // check 1: the value is positive
    fmov d1, xzr
    fcmp d9, d1
    b.gt 1f
    PUT Lf1, 14
    b 2f
1:  PUT Lp1, 9
2:
    // check 2: before <= value <= after
    fcmp d8, d9
    b.gt 3f
    fcmp d9, d10
    b.gt 3f
    PUT Lp2, 7
    b 4f
3:  PUT Lf2, 12
4:
    // check 3: after usleep(20 ms), now() advanced by at least 19 ms and less than 5 s
    mov w0, #20000
    bl _usleep
    bl _sea_now
    fsub d0, d0, d9
    adrp x9, Lmin@PAGE
    ldr d1, [x9, Lmin@PAGEOFF]
    fcmp d0, d1
    b.lt 5f
    adrp x9, Lmax@PAGE
    ldr d1, [x9, Lmax@PAGEOFF]
    fcmp d0, d1
    b.gt 5f
    PUT Lp3, 6
    b 6f
5:  PUT Lf3, 11
6:
    // check 4: consecutive distinct readings differ by far less than a millisecond
    // (resolution): spin until the value changes, at most 10,000,000 calls
    bl _sea_now
    fmov d8, d0
    LI x19, 10000000
7:  bl _sea_now
    fcmp d0, d8
    b.ne 8f
    subs x19, x19, #1
    b.ne 7b
    PUT Lf4, 16
    b 9f
8:  fsub d0, d0, d8
    adrp x9, Lms@PAGE
    ldr d1, [x9, Lms@PAGEOFF]
    fcmp d0, d1
    b.gt 10f
    PUT Lp4, 11
    b 9f
10: PUT Lf4, 16
9:
    ldr d10, [sp, #32]
    ldr x19, [sp, #40]
    ldp d8, d9, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// Lread -- x0 = &timespec: clock_gettime(CLOCK_MONOTONIC) -> d0 = sec + nsec / 1e9
Lread:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x0, [sp, #16]
    mov w0, #6
    ldr x1, [sp, #16]
    bl _clock_gettime
    ldr x0, [sp, #16]
    ldp x9, x10, [x0]
    scvtf d0, x9
    scvtf d1, x10
    LI x11, 1000000000
    scvtf d2, x11
    fdiv d1, d1, d2
    fadd d0, d0, d1
    ldp x29, x30, [sp], #32
    ret

    .section __TEXT,__const
Lp1: .ascii "positive\n"
Lf1: .ascii "FAIL positive\n"
Lp2: .ascii "bounds\n"
Lf2: .ascii "FAIL bounds\n"
Lp3: .ascii "sleep\n"
Lf3: .ascii "FAIL sleep\n"
Lp4: .ascii "resolution\n"
Lf4: .ascii "FAIL resolution\n"
    .p2align 3
Lmin: .double 0.019
Lmax: .double 5.0
Lms:  .double 0.001
    .section __DATA,__const
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
