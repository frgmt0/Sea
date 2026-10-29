// =====================================================================
// sea/runtime/arm64_macos/rt_out.s -- buffered standard output and the
// raw write loop (DESIGN.md 4.5 "I/O", 4.6; LANGUAGE.md 9.2, 11.3).
//
// Defines:
//   _sea_print        (global, SEA_ENT_PRINT) a string's bytes into the
//                     buffer (LANGUAGE.md 11.2)
// and (all .private_extern: internal to libsea, not a contract entry
// of rt.inc; used by rt_main.s, rt_err.s, rt_fmt.s and rt_file.s):
//   _sea_write_all    write(2) loop for any descriptor
//   _sea_out_write    append bytes to the standard-output buffer
//   _sea_out_repeat   append one byte value n times (padding)
//   _sea_out_flush    write the buffer to fd 1
//   _sea_out_bytes    _sea_out_write whose failure is _sea_out_fail
//   _sea_out_fail     noreturn: report a failed stdout write as the
//                     run-time error `cannot write '<stdout>': <reason>`
//   _sea_stdout_name  the static string object "<stdout>" (SEA_STR_*)
//
// THE BUFFER API (what _sea_printf in rt_fmt.s calls). AAPCS64: x0-x17
// and d0-d7, d16-d31 are clobbered by every routine, x19-x28 and d8-d15
// are preserved, x18 is never touched. Every routine that can fail
// returns x0 = 0 on success, or the host errno value (nonzero) of the
// failed write; the failure is sticky:
//
//   _sea_out_write (x0 = pointer, x1 = byte count) -> x0
//       Appends the bytes. The buffer (SEA_STDOUT_BUF_BYTES = 64 KiB,
//       LANGUAGE.md 11.3) is written to fd 1 as soon as it is full.
//   _sea_out_repeat (w0 = byte value, x1 = count) -> x0
//       Same as _sea_out_write of `count` copies of the byte.
//   _sea_out_flush () -> x0
//       Writes whatever is buffered.
//   _sea_out_bytes (x0 = pointer, x1 = byte count, x2 = site index or
//                   SEA_SITE_NONE)
//       _sea_out_write; on failure it does not return but runs
//       _sea_out_fail(errno, site). Returns nothing on success.
//   _sea_out_fail (x0 = errno, x1 = site index or SEA_SITE_NONE)
//       Never returns: _sea_err(SEA_E_CANNOT_WRITE, site, slots) with
//       the slots { &_sea_stdout_name, errno } built on the stack.
//       A caller does:   bl _sea_out_write ; cbnz x0, fail ... fail:
//       mov x1, <site> ; b _sea_out_fail   (x0 still holds the errno).
//
// Failure model (the Baysick rule, LANGUAGE.md 9.4: status 0 means every
// byte arrived). A write(2) that fails with anything but EINTR, or that
// writes 0 bytes (reported as EIO), empties the buffer, marks stdout
// broken and remembers the errno. From then on _sea_out_write,
// _sea_out_repeat and _sea_out_flush write nothing and return the
// remembered errno, so _sea_err's own flush cannot loop and the
// process cannot exit 0 after losing output.
//
// Standard error is not buffered here; _sea_err owns its tiny line
// buffer. SIGPIPE is ignored by main (rt_main.s), so a closed pipe is
// EPIPE here, never a signal.
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

.equ RT_OUT_EINTR,      4           /* <errno.h> EINTR on Darwin */
.equ RT_OUT_EIO,        5           /* <errno.h> EIO on Darwin: a write that made no progress */
.equ RT_OUT_EAGAIN,      35          /* <errno.h> EAGAIN (= EWOULDBLOCK) on Darwin: a non-blocking stdout that is full */
.equ RT_OUT_POLLOUT,     0x0004      /* <poll.h> POLLOUT */
.equ RT_OUT_PAD_CHUNK,  64          /* bytes of the stack block _sea_out_repeat copies from */

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// _sea_write_all -- write a whole byte range to a file descriptor.
//   Purpose : call write(2) until every byte is written; retry on
//             EINTR; on EAGAIN (a full non-blocking descriptor) wait
//             with poll(POLLOUT) and retry; give up on any other error
//             or on a write that makes no progress.
//   Inputs  : w0 = fd, x1 = pointer, x2 = byte count
//   Outputs : x0 = 0 if every byte was written, else the errno (EIO for
//             a write that returned 0)
//   Clobbers: x0-x17, d0-d7, d16-d31 (calls libc)
//   Callee-saved used: x19 = fd, x20 = cursor, x21 = bytes remaining
//   Frame   : 48 bytes (frame record + x19..x21; the 8 bytes at sp+40
//             hold the pollfd)
// ---------------------------------------------------------------------
    .private_extern _sea_write_all
    .p2align 2
_sea_write_all:
    stp x29, x30, [sp, #-48]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov w19, w0                     // fd
    mov x20, x1                     // next byte to write
    mov x21, x2                     // bytes left
Lrt_out_wa_loop:
    cbz x21, Lrt_out_wa_ok          // everything written
    mov w0, w19
    mov x1, x20
    mov x2, x21
    bl _write                       // x0 = bytes written, or -1
    cmp x0, #0
    b.lt Lrt_out_wa_err             // -1: inspect errno
    b.eq Lrt_out_wa_noprog          // 0 bytes: no progress, give up
    add x20, x20, x0                // advance past the bytes written
    sub x21, x21, x0
    b Lrt_out_wa_loop
Lrt_out_wa_err:
    bl ___error                     // x0 = &errno
    ldr w0, [x0]                    // the errno of the failed write
    cmp w0, #RT_OUT_EINTR
    b.eq Lrt_out_wa_loop            // interrupted: try again
    cmp w0, #RT_OUT_EAGAIN
    b.ne Lrt_out_wa_done            // real error: x0 = errno
    // A non-blocking descriptor that is full: wait until it is writable
    // (poll on {fd, POLLOUT, 0}, no timeout), then write again. A poll
    // that fails is ignored: the next write reports the real error.
    str w19, [sp, #40]              // pollfd.fd
    mov w9, #RT_OUT_POLLOUT
    strh w9, [sp, #44]              // pollfd.events
    strh wzr, [sp, #46]             // pollfd.revents
    add x0, sp, #40
    mov w1, #1
    mov w2, #-1
    bl _poll
    b Lrt_out_wa_loop
Lrt_out_wa_noprog:
    mov w0, #RT_OUT_EIO             // a write that writes nothing is EIO
    b Lrt_out_wa_done
Lrt_out_wa_ok:
    mov x0, #0                      // all bytes written
Lrt_out_wa_done:
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// _sea_out_flush -- write the buffered bytes to standard output.
//   Purpose : if stdout is already broken return the remembered errno
//             without writing; otherwise write the buffer with
//             _sea_write_all and empty it. A failed write marks stdout
//             broken (the buffer is dropped) and remembers the errno.
//   Inputs  : none
//   Outputs : x0 = 0, or the errno of the (current or earlier) failure
//   Clobbers: x0-x17, d0-d7, d16-d31
//   Callee-saved used: none
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .private_extern _sea_out_flush
    .p2align 2
_sea_out_flush:
    stp x29, x30, [sp, #-16]!       // frame record
    mov x29, sp
    adrp x9, Lrt_out_err@PAGE
    ldr x10, [x9, Lrt_out_err@PAGEOFF]
    cbnz x10, Lrt_out_flush_ret     // already broken: x10 = errno
    adrp x11, Lrt_out_fill@PAGE
    add x11, x11, Lrt_out_fill@PAGEOFF
    ldr x2, [x11]                   // bytes buffered
    mov x10, #0                     // result so far: success
    cbz x2, Lrt_out_flush_ret       // nothing to write
    str xzr, [x11]                  // the buffer is emptied either way
    mov w0, #1                      // fd 1
    adrp x1, Lrt_out_buf@PAGE
    add x1, x1, Lrt_out_buf@PAGEOFF
    bl _sea_write_all               // x0 = 0 or errno
    mov x10, x0
    cbz x10, Lrt_out_flush_ret
    adrp x9, Lrt_out_err@PAGE       // failed: remember it (sticky)
    str x10, [x9, Lrt_out_err@PAGEOFF]
Lrt_out_flush_ret:
    mov x0, x10
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// _sea_out_write -- append bytes to the standard-output buffer.
//   Purpose : copy the bytes into the buffer; whenever the buffer
//             becomes full write it out (_sea_out_flush). A broken
//             stdout discards the bytes and returns the errno.
//   Inputs  : x0 = pointer to the bytes, x1 = byte count (may be 0)
//   Outputs : x0 = 0, or the errno of the failed write
//   Clobbers: x0-x17, d0-d7, d16-d31
//   Callee-saved used: x19 = source cursor, x20 = bytes left
//   Frame   : 32 bytes (frame record + x19, x20)
// ---------------------------------------------------------------------
    .private_extern _sea_out_write
    .p2align 2
_sea_out_write:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0                     // next source byte
    mov x20, x1                     // bytes left
Lrt_out_w_loop:
    adrp x9, Lrt_out_err@PAGE
    ldr x0, [x9, Lrt_out_err@PAGEOFF]
    cbnz x0, Lrt_out_w_done         // broken: discard, report the errno
    cbz x20, Lrt_out_w_done         // nothing (more) to append: x0 = 0
    adrp x11, Lrt_out_fill@PAGE
    add x11, x11, Lrt_out_fill@PAGEOFF
    ldr x12, [x11]                  // fill
    mov x13, #SEA_STDOUT_BUF_BYTES
    sub x13, x13, x12               // free space (>= 1: a full buffer is flushed at once)
    cmp x20, x13
    csel x2, x20, x13, lo           // n = min(left, free)
    adrp x0, Lrt_out_buf@PAGE
    add x0, x0, Lrt_out_buf@PAGEOFF
    add x0, x0, x12                 // destination = buffer + fill
    add x12, x12, x2
    str x12, [x11]                  // fill += n
    mov x1, x19                     // source
    add x19, x19, x2                // advance the cursor ...
    sub x20, x20, x2                // ... and the count
    bl _memcpy                      // copy n bytes (x2)
    adrp x11, Lrt_out_fill@PAGE
    ldr x12, [x11, Lrt_out_fill@PAGEOFF]
    mov x13, #SEA_STDOUT_BUF_BYTES
    cmp x12, x13
    b.lo Lrt_out_w_loop             // room left: continue with the rest
    bl _sea_out_flush               // buffer full: write it out
    cbz x0, Lrt_out_w_loop
Lrt_out_w_done:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// _sea_out_repeat -- append one byte value `count` times.
//   Purpose : padding for width fields. Builds a RT_OUT_PAD_CHUNK-byte
//             block on the stack and appends it with _sea_out_write.
//   Inputs  : w0 = byte value, x1 = count (may be 0)
//   Outputs : x0 = 0, or the errno of the failed write
//   Clobbers: x0-x17, d0-d7, d16-d31
//   Callee-saved used: x19 = bytes left
//   Frame   : 32 + RT_OUT_PAD_CHUNK bytes (frame record, x19, block)
// ---------------------------------------------------------------------
    .private_extern _sea_out_repeat
    .p2align 2
_sea_out_repeat:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str x19, [sp, #16]
    sub sp, sp, #RT_OUT_PAD_CHUNK   // the block at [sp]
    mov x19, x1                     // bytes left
    dup v0.16b, w0                  // 16 copies of the byte
    stp q0, q0, [sp]                // fill the 64-byte block
    stp q0, q0, [sp, #32]
Lrt_out_rep_loop:
    mov x0, #0
    cbz x19, Lrt_out_rep_done       // all appended
    mov x1, #RT_OUT_PAD_CHUNK
    cmp x19, x1
    csel x1, x19, x1, lo            // n = min(left, chunk)
    sub x19, x19, x1
    mov x0, sp
    bl _sea_out_write
    cbz x0, Lrt_out_rep_loop        // ok: next chunk
Lrt_out_rep_done:
    add sp, sp, #RT_OUT_PAD_CHUNK
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// _sea_out_bytes -- append bytes; a failed write is the run-time error.
//   Purpose : _sea_out_write whose failure does not return: it is
//             _sea_out_fail(errno, site). This is the entry rt_fmt.s
//             uses.
//   Inputs  : x0 = pointer, x1 = byte count (may be 0), x2 = site index
//             or SEA_SITE_NONE
//   Outputs : returns only on success (nothing is returned)
//   Clobbers: x0-x17, d0-d7, d16-d31
//   Callee-saved used: x19 = site (saved and restored)
//   Frame   : 32 bytes (frame record + x19)
// ---------------------------------------------------------------------
    .private_extern _sea_out_bytes
    .p2align 2
_sea_out_bytes:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x2                     // keep the site across the call
    bl _sea_out_write               // x0 = 0 or errno
    cbnz x0, Lrt_out_bytes_fail
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
Lrt_out_bytes_fail:
    mov x1, x19                     // x0 = errno, x1 = site
    bl _sea_out_fail                // noreturn

// ---------------------------------------------------------------------
// _sea_out_fail -- a stdout write failed: report it and terminate.
//   Purpose : _sea_err(SEA_E_CANNOT_WRITE, site, slots) with the slot
//             vector { &_sea_stdout_name, errno } (args letters "se").
//   Inputs  : x0 = host errno value, x1 = site index or SEA_SITE_NONE
//   Outputs : never returns
//   Clobbers: everything
//   Callee-saved used: none
//   Frame   : 32 bytes (frame record + 16-byte slot vector)
// ---------------------------------------------------------------------
    .private_extern _sea_out_fail
    .p2align 2
_sea_out_fail:
    stp x29, x30, [sp, #-32]!       // frame record (+ slots at sp+16)
    mov x29, sp
    adrp x9, _sea_stdout_name@PAGE
    add x9, x9, _sea_stdout_name@PAGEOFF
    stp x9, x0, [sp, #16]           // slot 0 = path string, slot 1 = errno
    mov w0, #SEA_E_CANNOT_WRITE
    add x2, sp, #16                 // the slot vector
    bl _sea_err                     // noreturn (x1 = site already)
    brk #1                          // not reached

// ---------------------------------------------------------------------
// _sea_print -- the entry PRINT (DESIGN.md 4.8, 2.11.6, L-cd;
//   LANGUAGE.md 11.2).
//   Purpose : s's bytes into the standard-output buffer, nothing added,
//             so print and printf interleave in program order. A failed
//             write is the run-time error `cannot write '<stdout>':
//             <reason>` at the site, as _sea_printf reports it. An empty
//             s writes nothing (as an empty piece of _sea_printf).
//   Inputs  : x0 = s (a string object, borrowed), x1 = site index
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: none
//   Frame   : none (tail call of _sea_out_bytes)
// ---------------------------------------------------------------------
    .globl _sea_print
    .p2align 2
_sea_print:
    mov x2, x1                      // the site
    ldr x1, [x0, #SEA_STR_LEN]      // the byte count
    add x0, x0, #SEA_STR_BYTES      // the bytes
    cbz x1, 1f                      // nothing to write
    b _sea_out_bytes                // tail call: returns to our caller
1:  ret

// ---------------------------------------------------------------------
// Data. The string object is static (count SEA_RC_STATIC, SEA_STR_*),
// so it is shown by `%s` like any Sea string.
// ---------------------------------------------------------------------
    .section __DATA,__const
    .p2align 3
    .private_extern _sea_stdout_name
_sea_stdout_name:
    .quad SEA_RC_STATIC             // SEA_STR_RC
Lrt_out_nm_tag:
    .byte SEA_TAG_STR               // SEA_STR_TAG
    .space SEA_STR_LEN - SEA_STR_TAG - 1, 0 // the rest of the header
Lrt_out_nm_len:
    .quad 8                         // SEA_STR_LEN: the length of "<stdout>"
Lrt_out_nm_bytes:
    .ascii "<stdout>"               // SEA_STR_BYTES
.if (SEA_STR_RC != 0) || ((Lrt_out_nm_tag - _sea_stdout_name) != SEA_STR_TAG) || ((Lrt_out_nm_len - _sea_stdout_name) != SEA_STR_LEN) || ((Lrt_out_nm_bytes - _sea_stdout_name) != SEA_STR_BYTES)
    .error "rt_out: _sea_stdout_name does not match the SEA_STR_* layout of rt.inc"
.endif

    .section __DATA,__bss
.zerofill __DATA,__bss,Lrt_out_buf,SEA_STDOUT_BUF_BYTES,4
.zerofill __DATA,__bss,Lrt_out_fill,8,3     /* bytes buffered, 0 .. SEA_STDOUT_BUF_BYTES-1 between calls */
.zerofill __DATA,__bss,Lrt_out_err,8,3      /* 0, or the errno that broke stdout (sticky) */
