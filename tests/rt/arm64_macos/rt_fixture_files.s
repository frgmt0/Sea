// =====================================================================
// sea/tests/rt/arm64_macos/rt_fixture_files.s -- proves the rt NAME.files/ sidecar
// (L-mp, DESIGN.md 2.15.8): the program opens "fixture.txt", which exists only
// in rt_fixture_files.files/, reads it and writes it to standard output
// (libSystem open, read, write). Expected stdout = the fixture's bytes
// (rt_fixture_files.out); an absent fixture makes open fail and the program exit 1.
// Run by tests/rt/run_rt.sh, linked with the arm64-macos runtime.
// =====================================================================
.include "limits.inc"
.include "rt.inc"

    .section __TEXT,__text,regular,pure_instructions

// _sea_main -- open the fixture, copy up to 256 bytes of it to stdout.
//   Frame: 288 bytes (frame record + 256-byte buffer + x19, pad); callee-saved used:
//   x19 = the file descriptor
    .globl _sea_main
    .p2align 2
_sea_main:
    stp x29, x30, [sp, #-304]!
    mov x29, sp
    str x19, [sp, #16]
    adrp x0, Lfx_path@PAGE
    add x0, x0, Lfx_path@PAGEOFF
    mov x1, #0                      // O_RDONLY
    bl _open
    tbnz x0, #63, Lfx_fail          // -1: the fixture is missing
    mov x19, x0
    add x1, sp, #32                 // buffer
    mov x2, #256
    bl _read                        // x0 = bytes read
    cmp x0, #0
    b.le Lfx_fail
    mov x2, x0
    add x1, sp, #32
    mov x0, #1                      // standard output
    bl _write
    mov x0, x19
    bl _close
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #304
    ret
Lfx_fail:
    mov w0, #1
    bl _exit

    .section __TEXT,__cstring,cstring_literals
Lfx_path:
    .asciz "fixture.txt"

    .section __DATA,__const
    .p2align 3
// The error-site table (no site is used).
    .globl _sea_sites
_sea_sites:
    .quad 0, 0
