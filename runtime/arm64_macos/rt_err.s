// =====================================================================
// sea/runtime/arm64_macos/rt_err.s -- run-time error reporting
// (LANGUAGE.md 9.2, 9.4; DESIGN.md 4.5, 4.6, 4.8, 2.6.2).
//
// Defines: _sea_err   (global, rt.inc)
//
//   _sea_err(x0 = code SEA_E_* 1 .. SEA_E_RT_END-1,
//            x1 = site index into _sea_sites, or SEA_SITE_NONE,
//            x2 = address of the argument slots)           noreturn
//
// The sequence of LANGUAGE.md 9.2:
//   1. standard output is flushed (_sea_out_flush; a broken stdout
//      stays broken and the failure is ignored: the status is 1 anyway);
//   2. one line goes to standard error, written with one write(2) (or
//      several if it exceeds RT_ERR_BUF_BYTES):
//        `<file>:<line>: error: <message>` + LF         site given
//        `error: <message>` + LF                        SEA_SITE_NONE
//      <file> is the string object at SEA_SITE_FILE of the record
//      `_sea_sites + SEA_SITE_SIZE*site`, <line> its SEA_SITE_LINE;
//   3. open output files are flushed and closed: the one file that can
//      be open is a write_json file between JSON_OPEN and JSON_CLOSE
//      (rt_file.s); _sea_json_abort writes its buffer and closes it,
//      ignoring a failure of either (the error reported stays the
//      original one; DESIGN.md 2.11.6, L-ca). It does nothing when no
//      emitter state exists or its descriptor is -1 (an error inside
//      JSON_OPEN before the descriptor is stored, or the emitter's own
//      failed write, which closed the file before calling here). This
//      step also runs for a code outside the run-time range;
//   4. the process ends with _exit(SEA_EXIT_RUN_ERROR) (1), never exit:
//      no atexit handler or library flush runs, which also makes this
//      path safe from the SIGSEGV / SIGBUS handler of rt_main.s
//      (DESIGN.md 4.6).
// A code outside 1 .. SEA_E_RT_END-1 (a caller bug) prints nothing after
// the flush and exits 1, like Baysick's _bsk_err.
//
// The message text and the args letters come from the table that
// SEA_EMIT_ERRMSG_TABLE (errors.inc) emits, the same macro as the
// x86_64-linux runtime's, so the texts cannot diverge. Each `%x` of the
// text takes the next letter of the args string and the next slot(s):
//   i  one slot, i64, decimal (a leading '-' if negative)
//   f  one slot, the bits of an f64, text from `_sea_fmt_g`
//   s  one slot, a string object (SEA_STR_LEN at +16, bytes at +24)
//   h  two slots: rows, then cols or SEA_SHAPE_VEC: `RxC` or `R`
//   e  one slot, the host errno value; the reason is the text of the
//      errno-table record with that value, or of record 0 if none has
// (an `%` is always followed by one conversion character, which is
// skipped; the character itself is not looked at).
//
// EXTERNAL INTERNAL SYMBOLS used (defined elsewhere in the runtime):
//   _sea_json_abort() (rt_file.s): step 3 above; clobbers like any
//              function, returns normally.
//   _sea_fmt_g(x0 = destination buffer of at least 16 bytes (this file
//              passes RT_ERR_FMTG_BYTES = 32), d0 = the f64)
//              -> x0 = number of bytes written
//   writes the text of printf("%g") in Sea's rules (LANGUAGE.md 11.1):
//   default precision, so at most 13 bytes for a finite value, and
//   `NaN`, `Inf`, `-Inf` for the non-finite ones; no NUL, no padding.
//   It preserves x19-x28 and d8-d15 like any function.
//
// Standard error is unbuffered for the program but this routine collects
// the line in a static buffer of RT_ERR_BUF_BYTES bytes (written when
// full and at the end), so a normal message is one write(2).
// =====================================================================
.include "errors.inc"
.include "rt.inc"

.equ RT_ERR_BUF_BYTES,  4096        /* the line buffer; longer lines are written in pieces */
.equ RT_ERR_FMTG_BYTES,     32          /* bytes _sea_fmt_g may write */
.equ RT_ERR_SCRATCH,    48          /* stack scratch of _sea_err: _sea_fmt_g output, errno scan */

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// Lrt_err_put -- append bytes to the line buffer, writing it to fd 2
//   whenever it becomes full.
//   Inputs  : x0 = pointer, x1 = byte count (may be 0)
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31
//   Callee-saved used: x25 = source cursor, x26 = bytes left
//   Frame   : 32 bytes (frame record + x25, x26)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_err_put:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x25, x26, [sp, #16]
    mov x25, x0
    mov x26, x1
Lrt_err_put_loop:
    cbz x26, Lrt_err_put_done
    adrp x11, Lrt_err_fill@PAGE
    add x11, x11, Lrt_err_fill@PAGEOFF
    ldr x12, [x11]                  // bytes in the buffer
    mov x13, #RT_ERR_BUF_BYTES
    sub x13, x13, x12               // free space (>= 1)
    cmp x26, x13
    csel x2, x26, x13, lo           // n = min(left, free)
    adrp x0, Lrt_err_buf@PAGE
    add x0, x0, Lrt_err_buf@PAGEOFF
    add x0, x0, x12                 // destination
    add x12, x12, x2
    str x12, [x11]                  // fill += n
    mov x1, x25
    add x25, x25, x2
    sub x26, x26, x2
    bl _memcpy
    adrp x11, Lrt_err_fill@PAGE
    ldr x12, [x11, Lrt_err_fill@PAGEOFF]
    cmp x12, #RT_ERR_BUF_BYTES
    b.lo Lrt_err_put_loop           // not full yet
    bl Lrt_err_flush                // full: write it out
    b Lrt_err_put_loop
Lrt_err_put_done:
    ldp x25, x26, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// Lrt_err_flush -- write the line buffer to fd 2 and empty it.
//   Purpose : a failed write to standard error is ignored (there is no
//             better channel to report it on).
//   Clobbers: x0-x17, d0-d7, d16-d31
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_err_flush:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adrp x9, Lrt_err_fill@PAGE
    add x9, x9, Lrt_err_fill@PAGEOFF
    ldr x2, [x9]
    str xzr, [x9]                   // emptied either way
    cbz x2, Lrt_err_flush_ret
    mov w0, #2
    adrp x1, Lrt_err_buf@PAGE
    add x1, x1, Lrt_err_buf@PAGEOFF
    bl _sea_write_all               // result ignored
Lrt_err_flush_ret:
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// Lrt_err_put_dec -- append the decimal text of a 64-bit integer.
//   Inputs  : x0 = value, w1 = 1 if x0 is a signed i64, 0 if unsigned
//   Clobbers: x0-x17, d0-d7, d16-d31
//   Callee-saved used: none
//   Frame   : 16 + 32 bytes (frame record, digit scratch; at most 20
//             digits and a sign)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_err_put_dec:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    add x9, sp, #48                 // end of the scratch: digits are written backwards
    mov x10, #10
    mov w11, #0                     // sign needed?
    cbz w1, 1f
    tbz x0, #63, 1f
    neg x0, x0                      // magnitude (INT64_MIN stays 2^63 as unsigned)
    mov w11, #1
1:
Lrt_err_dec_loop:
    udiv x12, x0, x10               // x12 = x0 / 10
    msub x13, x12, x10, x0          // x13 = x0 % 10
    add w13, w13, #'0'
    strb w13, [x9, #-1]!
    mov x0, x12
    cbnz x0, Lrt_err_dec_loop
    cbz w11, 2f
    mov w13, #'-'
    strb w13, [x9, #-1]!
2:
    add x1, sp, #48
    sub x1, x1, x9                  // byte count
    mov x0, x9
    bl Lrt_err_put
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// _sea_err -- see the file header.
//   Inputs  : x0 = code, x1 = site index or SEA_SITE_NONE, x2 = slots
//   Outputs : never returns
//   Clobbers: everything
//   Callee-saved used: x19 = code, x20 = site, x21 = slot cursor,
//             x22 = message cursor, x23 = args-letter cursor,
//             x24 = start of the literal run being scanned
//   Frame   : 80 (frame record + x19..x24) + RT_ERR_SCRATCH bytes
// ---------------------------------------------------------------------
    .globl _sea_err
    .p2align 2
_sea_err:
    stp x29, x30, [sp, #-80]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    sub sp, sp, #RT_ERR_SCRATCH     // scratch at [sp]
    mov x19, x0                     // code
    mov x20, x1                     // site
    mov x21, x2                     // argument slots

    // 1. Standard output first, so the message follows all output.
    //    A failure (stdout broken) is ignored here.
    bl _sea_out_flush

    // A code that is not a run-time code prints nothing.
    sub x9, x19, #1
    cmp x9, #(SEA_E_RT_END - 2)
    b.hi Lrt_err_exit

    adrp x9, Lrt_err_fill@PAGE      // an empty line buffer
    str xzr, [x9, Lrt_err_fill@PAGEOFF]

    // 2a. `<file>:<line>: ` when the error has a location.
    cmn x20, #-(SEA_SITE_NONE)       // SEA_SITE_NONE?
    b.eq Lrt_err_nosite
    adrp x9, _sea_sites@PAGE
    add x9, x9, _sea_sites@PAGEOFF
    mov x11, #SEA_SITE_SIZE
    madd x9, x20, x11, x9           // record = sites + site * SEA_SITE_SIZE
    ldr x10, [x9, #SEA_SITE_FILE]   // the static string object of the path
    ldr x1, [x10, #SEA_STR_LEN]
    add x0, x10, #SEA_STR_BYTES
    bl Lrt_err_put
    adrp x0, Lrt_err_s_colon@PAGE
    add x0, x0, Lrt_err_s_colon@PAGEOFF
    mov x1, #1
    bl Lrt_err_put
    adrp x9, _sea_sites@PAGE        // reload the record (x9 was clobbered)
    add x9, x9, _sea_sites@PAGEOFF
    mov x11, #SEA_SITE_SIZE
    madd x9, x20, x11, x9
    ldr x0, [x9, #SEA_SITE_LINE]
    mov w1, #0                      // unsigned
    bl Lrt_err_put_dec
    adrp x0, Lrt_err_s_colonsp@PAGE
    add x0, x0, Lrt_err_s_colonsp@PAGEOFF
    mov x1, #2
    bl Lrt_err_put
Lrt_err_nosite:
    // 2b. `error: `
    adrp x0, Lrt_err_s_error@PAGE
    add x0, x0, Lrt_err_s_error@PAGEOFF
    mov x1, #7
    bl Lrt_err_put

    // 2c. The message with its substitutions.
    adrp x9, Lrt_err_tab@PAGE
    add x9, x9, Lrt_err_tab@PAGEOFF
    mov x10, #SEA_ERRTAB_SIZE
    madd x9, x19, x10, x9           // record = table + SEA_ERRTAB_SIZE * code
    ldr x22, [x9, #SEA_ERRTAB_MSG]
    ldr x23, [x9, #SEA_ERRTAB_ARGS]
Lrt_err_scan:
    mov x24, x22                    // start of a literal run
1:  ldrb w9, [x22]
    cbz w9, Lrt_err_lit_end         // end of the text
    cmp w9, #'%'
    b.eq Lrt_err_lit_end            // a substitution follows
    add x22, x22, #1
    b 1b
Lrt_err_lit_end:
    mov x0, x24
    sub x1, x22, x24
    bl Lrt_err_put                  // the literal run
    ldrb w9, [x22]
    cbz w9, Lrt_err_msg_done
    add x22, x22, #2                // skip `%` and its conversion character
    ldrb w9, [x23], #1              // the args letter of this substitution
    cbz w9, Lrt_err_scan            // no letter left (cannot happen with a valid table)
    cmp w9, #'i'
    b.eq Lrt_err_a_i
    cmp w9, #'f'
    b.eq Lrt_err_a_f
    cmp w9, #'s'
    b.eq Lrt_err_a_s
    cmp w9, #'h'
    b.eq Lrt_err_a_h
    cmp w9, #'e'
    b.eq Lrt_err_a_e
    b Lrt_err_scan                  // unknown letter (cannot happen with a valid table)

Lrt_err_a_i:                        // i64, decimal
    ldr x0, [x21], #SEA_SLOT_SIZE
    mov w1, #1
    bl Lrt_err_put_dec
    b Lrt_err_scan

Lrt_err_a_f:                        // f64, Sea's %g
    ldr x9, [x21], #SEA_SLOT_SIZE
    fmov d0, x9
    mov x0, sp                      // the scratch holds RT_ERR_FMTG_BYTES bytes of text
    bl _sea_fmt_g                   // x0 = byte count
    mov x1, x0
    mov x0, sp
    bl Lrt_err_put
    b Lrt_err_scan

Lrt_err_a_s:                        // string object
    ldr x10, [x21], #SEA_SLOT_SIZE
    ldr x1, [x10, #SEA_STR_LEN]
    add x0, x10, #SEA_STR_BYTES
    bl Lrt_err_put
    b Lrt_err_scan

Lrt_err_a_h:                        // shape: rows [x cols]
    ldp x0, x10, [x21], #(2*SEA_SLOT_SIZE)         // rows, cols (SEA_SHAPE_VEC for a vector)
    mov w1, #0
    str x10, [sp, #(RT_ERR_SCRATCH - 8)]  // keep cols across the call
    bl Lrt_err_put_dec
    ldr x0, [sp, #(RT_ERR_SCRATCH - 8)]
    cmn x0, #-(SEA_SHAPE_VEC)       // SEA_SHAPE_VEC: a vector has no `x cols`
    b.eq Lrt_err_scan
    mov w1, #0
    str x0, [sp, #(RT_ERR_SCRATCH - 8)]
    adrp x0, Lrt_err_s_x@PAGE
    add x0, x0, Lrt_err_s_x@PAGEOFF
    mov x1, #1
    bl Lrt_err_put
    ldr x0, [sp, #(RT_ERR_SCRATCH - 8)]
    mov w1, #0
    bl Lrt_err_put_dec
    b Lrt_err_scan

Lrt_err_a_e:                        // errno reason from the table
    ldr x9, [x21], #SEA_SLOT_SIZE               // host errno value
    adrp x10, Lrt_err_errno@PAGE
    add x10, x10, Lrt_err_errno@PAGEOFF
    add x11, x10, #SEA_ERRNO_SIZE   // record 1 .. SEA_ERRNO_COUNT-1 are searched
    mov x12, #(SEA_ERRNO_COUNT - 1)
    ldr x13, [x10, #SEA_ERRNO_TEXT] // default: the text of record 0
2:  ldr x14, [x11, #SEA_ERRNO_HOST]
    cmp x14, x9
    b.ne 3f
    ldr x13, [x11, #SEA_ERRNO_TEXT]
    b 4f
3:  add x11, x11, #SEA_ERRNO_SIZE
    subs x12, x12, #1
    b.ne 2b
4:  mov x0, x13
    str x13, [sp, #(RT_ERR_SCRATCH - 8)]
    bl _strlen
    mov x1, x0
    ldr x0, [sp, #(RT_ERR_SCRATCH - 8)]
    bl Lrt_err_put
    b Lrt_err_scan

Lrt_err_msg_done:
    adrp x0, Lrt_err_s_lf@PAGE
    add x0, x0, Lrt_err_s_lf@PAGEOFF
    mov x1, #1
    bl Lrt_err_put
    bl Lrt_err_flush                // the whole line, one write(2)

Lrt_err_exit:
    // 3. An open write_json file: flushed and closed, failures ignored.
    bl _sea_json_abort
    mov w0, #SEA_EXIT_RUN_ERROR
    bl _exit                        // does not return
    brk #1                          // not reached

// ---------------------------------------------------------------------
// Constant data: the message and errno tables (errors.inc macros) and
// the few literals of the line.
// ---------------------------------------------------------------------
    .section __DATA,__const
    SEA_EMIT_ERRMSG_TABLE Lrt_err_tab
    SEA_EMIT_ERRNO_TABLE Lrt_err_errno, darwin

    .section __TEXT,__const
Lrt_err_s_colon:    .ascii ":"
Lrt_err_s_colonsp:  .ascii ": "
Lrt_err_s_error:    .ascii "error: "
Lrt_err_s_x:        .ascii "x"
Lrt_err_s_lf:       .ascii "\n"

.zerofill __DATA,__bss,Lrt_err_buf,RT_ERR_BUF_BYTES,4
.zerofill __DATA,__bss,Lrt_err_fill,8,3     /* bytes in the line buffer */
