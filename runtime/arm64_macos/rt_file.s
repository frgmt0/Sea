// =====================================================================
// sea/runtime/arm64_macos/rt_file.s -- make_dir and the JSON emitter
// (LANGUAGE.md 10.10, 11.3, 11.4, 9.2; DESIGN.md 4.8 entries 25, 27-38,
// 2.11.6; lead decisions L-bz, L-ca, L-cb, L-co).
//
// Defines (global, rt.inc SEA_ENTRY_LIST):
//   _sea_make_dir   (path, site)    create one directory level
//   _sea_json_open  (path, site)    begin a JSON file
//   _sea_json_close (site)          end it: LF, flush, close, free
//   _sea_json_obj   (site)          begin an object as the next value
//   _sea_json_arr   (site)          begin an array as the next value
//   _sea_json_end   (site)          end the innermost object or array
//   _sea_json_key   (key, site)     the next member's key
//   _sea_json_f64   (d0 = x, x0 = site)  %.17g, or null for NaN, +-Inf
//   _sea_json_i64   (v, site)       decimal
//   _sea_json_bool  (v, site)       true / false
//   _sea_json_str   (s, site)       an escaped string
//   _sea_json_vec   (a, site)       a dynamic vector as a flat array
//   _sea_json_mat   (a, site)       a dynamic matrix as an array of rows
// and (.private_extern, used by rt_err.s):
//   _sea_json_abort ()              flush and close an open JSON file,
//                                   ignoring failures (L-ca)
//   _sea_json_st                    ptr: the emitter's state, 0 if none
// Uses: _sea_alloc, _sea_free_block, _sea_retain, _sea_release (rt_mem.s),
//       _sea_write_all (rt_out.s), _sea_err (rt_err.s); open, close,
//       mkdir, memcpy, memchr, snprintf, __error (libSystem).
//
// Every argument is borrowed. A failing entry calls _sea_err and never
// returns; the error slots of CANNOT_OPEN, CANNOT_WRITE and CANNOT_MKDIR
// are { path string, host errno } (errors.inc args "se").
//
// THE EMITTER STATE (private to this file; one block from _sea_alloc,
// not a counted object, so a completed write_json leaves the live count
// unchanged): the retained path, the descriptor (-1 when none is open),
// the site of the entry running, the SEA_JSON_BUF_BYTES output buffer
// and the container stack, a separate block of RJ_STK0 bytes doubled as
// needed (L-co: no depth limit; no memory is OUT_OF_MEMORY), one byte per
// open container: RJ_K_ARR set for an array (clear for an object),
// RJ_K_HAS set once it has a member or element. At most one file is open
// (pass 2b's blocks do not nest); the emitter trusts the nesting it is
// given, as _sea_printf trusts its format.
//
// LAYOUT (DESIGN.md 2.11.6, L-bz). With D the number of open containers:
//   * an element of an array, or a key of an object, is preceded by `,`
//     if the container already has one, then LF and 2D spaces; a key is
//     written as a string and followed by `: `; the value of a key
//     follows it on the same line;
//   * `}` / `]` closing a non-empty container comes after LF and 2D
//     spaces (D counted after the close); an empty one is `{}` / `[]`;
//   * after the top value JSON_CLOSE writes one LF.
// Scalars: f64 finite as C's %.17g (snprintf, the C locale: `-0`,
// `100`, `0.10000000000000001`), NaN and +-Inf as null; i64 in decimal;
// bool true / false; a string between `"` with `"` as \", `\` as \\, LF
// as \n, TAB as \t, every other byte below 0x20 as \u00 and two
// lower-case hex digits, every other byte (0x7F and 0x80-0xFF included)
// as it is.
//
// WRITE FAILURES (2.11.6). A failed flush (or a failed final write or
// close in JSON_CLOSE) closes the descriptor if it is still open
// (ignoring that close's result), sets it to -1, keeps the state and its
// retained path, and calls _sea_err(CANNOT_WRITE, site, {path, errno});
// _sea_err then finds no open file.
//
// Host constants (Darwin <fcntl.h>, <errno.h>): see the RT_FILE_*
// equates below. The errno value of EINVAL is taken from the darwin
// column of errors.inc's SEA_ERRNO_LIST.
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

.equ RT_FILE_O_RDONLY,    0x0000    /* <fcntl.h> O_RDONLY */
.equ RT_FILE_O_WRONLY,    0x0001    /* <fcntl.h> O_WRONLY */
.equ RT_FILE_O_CREAT,     0x0200    /* <fcntl.h> O_CREAT on Darwin */
.equ RT_FILE_O_TRUNC,     0x0400    /* <fcntl.h> O_TRUNC on Darwin */
.equ RT_FILE_O_DIRECTORY, 0x100000  /* <fcntl.h> O_DIRECTORY on Darwin */
.equ RT_FILE_MODE_FILE,   0666      /* open mode of a JSON file, before the umask */
.equ RT_FILE_MODE_DIR,    0777      /* mkdir mode, before the umask */

// EINVAL's host value on this target, from the errno table.
.macro RT_FILE_ERRNO_PICK id, name, darwin, linux, text
.ifc \name, EINVAL
.equ RT_FILE_EINVAL, \darwin
.endif
.endm
SEA_ERRNO_LIST RT_FILE_ERRNO_PICK

// The emitter state block.
.equ RJ_PATH,       0               /* ptr  the path string, retained */
.equ RJ_FD,         8               /* i64  the descriptor, -1 when none is open */
.equ RJ_FILL,       16              /* u64  bytes in the buffer */
.equ RJ_DEPTH,      24              /* u64  open containers */
.equ RJ_STK,        32              /* ptr  container stack, one byte per container */
.equ RJ_STKCAP,     40              /* u64  its size in bytes */
.equ RJ_SITE,       48              /* i64  site index of the entry running */
.equ RJ_BUF,        64              /* u8[SEA_JSON_BUF_BYTES] the output buffer */
.equ RJ_SIZE,       (RJ_BUF + SEA_JSON_BUF_BYTES)
.equ RJ_STK0,       16              /* first size of the container stack */
.equ RJ_K_ARR,      1               /* stack byte: an array (else an object) */
.equ RJ_K_HAS,      2               /* stack byte: has a member or element */
.equ RJ_NUMBUF,     32              /* %.17g text (at most 24 bytes + NUL), i64 digits */
.equ RJ_SPACES,     64              /* bytes of the static block of spaces */

// reg := the emitter state (0 when none).
.macro RJ_STATE reg
    adrp \reg, _sea_json_st@PAGE
    ldr \reg, [\reg, _sea_json_st@PAGEOFF]
.endm
// Store the site (a register) into the state.
.macro RJ_SITE_SET reg
    adrp x9, _sea_json_st@PAGE
    ldr x9, [x9, _sea_json_st@PAGEOFF]
    str \reg, [x9, #RJ_SITE]
.endm

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// Lrt_file_cpath -- a NUL-terminated copy of a path string.
//   Purpose : allocates length + 1 bytes, copies the bytes, appends NUL,
//             and reports whether the path holds a NUL byte (such a path
//             cannot be passed to the host: EINVAL for the caller).
//   Inputs  : x0 = path (string object), x1 = site
//   Outputs : x0 = the buffer (free with _sea_free_block(x0, length + 1)),
//             x1 = 1 if the path holds a NUL byte, else 0
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = path, x20 = length, x21 = the buffer
//   Frame   : 48 bytes (frame record + x19..x21, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_file_cpath:
    stp x29, x30, [sp, #-48]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    ldr x20, [x19, #SEA_STR_LEN]
    add x0, x20, #1                 // the bytes and a NUL
    bl _sea_alloc                   // x1 = site; noreturn on failure
    mov x21, x0
    add x1, x19, #SEA_STR_BYTES     // copy the bytes
    mov x2, x20
    bl _memcpy
    strb wzr, [x21, x20]            // the terminating NUL
    mov x0, x21                     // a NUL among the path's own bytes?
    mov w1, #0
    mov x2, x20
    bl _memchr                      // x0 = its address, or 0
    cmp x0, #0
    cset x1, ne
    mov x0, x21
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrt_file_errno -- the calling thread's errno.
//   Outputs : x0 = errno (zero-extended)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_file_errno:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl ___error                     // x0 = &errno
    ldr w0, [x0]
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// Lrt_file_fail -- report a file error and terminate.
//   Purpose : _sea_err(code, site, {path, errno}) with the slots built on
//             the stack (errors.inc args "se").
//   Inputs  : w0 = code (SEA_E_CANNOT_*), x1 = site, x2 = path string,
//             x3 = host errno
//   Outputs : never returns
//   Frame   : 32 bytes (frame record + the two slots)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_file_fail:
    stp x29, x30, [sp, #-32]!       // frame record (+ slots at sp+16)
    mov x29, sp
    stp x2, x3, [sp, #16]           // slot 0 = path, slot 1 = errno
    add x2, sp, #16
    bl _sea_err                     // noreturn
    brk #1                          // not reached

// ---------------------------------------------------------------------
// _sea_make_dir -- the entry MAKE_DIR (DESIGN.md 4.8; LANGUAGE.md 10.10;
//   Decision 89, L-cb).
//   Purpose : the path copied into a new NUL-terminated buffer (a NUL
//             byte in the path: CANNOT_MKDIR with EINVAL; the buffer is
//             freed on every exit); mkdir(buf, 0777) under the umask;
//             success returns; on a failure the errno is saved first,
//             then open(buf, O_RDONLY | O_DIRECTORY) tests for a
//             directory (closed at once when it succeeds; no stat): a
//             directory returns (`/` gives EISDIR from mkdir on macOS),
//             otherwise CANNOT_MKDIR with the path and the saved errno.
//             No parent is created.
//   Inputs  : x0 = path (string object), x1 = site
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = path, x20 = site, x21 = the buffer,
//             x22 = the saved errno
//   Frame   : 48 bytes (frame record + x19..x22)
// ---------------------------------------------------------------------
    .globl _sea_make_dir
    .p2align 2
_sea_make_dir:
    stp x29, x30, [sp, #-48]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    bl Lrt_file_cpath               // x0 = buffer, x1 = holds a NUL
    mov x21, x0
    mov x22, #RT_FILE_EINVAL
    cbnz x1, Lrt_file_mkdir_fail    // a NUL byte: EINVAL
    mov x0, x21
    mov w1, #RT_FILE_MODE_DIR
    bl _mkdir                       // 0, or -1 and errno
    cbz w0, Lrt_file_mkdir_done     // created
    bl Lrt_file_errno
    mov x22, x0                     // the errno of mkdir, kept
    // Is the path a directory already? (open does not create here.)
    mov x0, x21
    mov w1, #(RT_FILE_O_RDONLY | RT_FILE_O_DIRECTORY)
    bl _open                        // fd, or -1
    tbnz w0, #31, Lrt_file_mkdir_fail   // not a directory: the saved errno
    bl _close                       // w0 = fd; the result does not matter
Lrt_file_mkdir_done:
    mov x0, x21
    ldr x1, [x19, #SEA_STR_LEN]
    add x1, x1, #1
    bl _sea_free_block              // the buffer
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
Lrt_file_mkdir_fail:
    mov x0, x21
    ldr x1, [x19, #SEA_STR_LEN]
    add x1, x1, #1
    bl _sea_free_block              // the buffer, before the report
    mov w0, #SEA_E_CANNOT_MKDIR
    mov x1, x20
    mov x2, x19
    mov x3, x22
    bl Lrt_file_fail                // noreturn

// ---------------------------------------------------------------------
// Lrt_json_wfail -- a write of the JSON file failed: report it.
//   Purpose : closes the descriptor if it is still open (the result is
//             ignored), sets it to -1, keeps the state and the path, and
//             calls _sea_err(CANNOT_WRITE, the state's site, {path,
//             errno}).
//   Inputs  : x0 = host errno
//   Outputs : never returns
//   Callee-saved used: x19 = state, x20 = errno
//   Frame   : 32 bytes (frame record + x19, x20)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_wfail:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    RJ_STATE x19
    mov x20, x0
    ldr x0, [x19, #RJ_FD]
    cmn x0, #1
    b.eq 1f                         // already closed
    mov x9, #-1
    str x9, [x19, #RJ_FD]           // no file is open any more
    bl _close                       // w0 = fd; result ignored
1:  mov w0, #SEA_E_CANNOT_WRITE
    ldr x1, [x19, #RJ_SITE]
    ldr x2, [x19, #RJ_PATH]
    mov x3, x20
    bl Lrt_file_fail                // noreturn

// ---------------------------------------------------------------------
// Lrt_json_flush -- write the buffered bytes to the file and empty it.
//   Outputs : returns only on success
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = state
//   Frame   : 32 bytes (frame record + x19, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_flush:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str x19, [sp, #16]
    RJ_STATE x19
    ldr x2, [x19, #RJ_FILL]
    cbz x2, 1f                      // nothing buffered
    str xzr, [x19, #RJ_FILL]        // emptied either way
    ldr x0, [x19, #RJ_FD]
    add x1, x19, #RJ_BUF
    bl _sea_write_all               // x0 = 0 or errno
    cbnz x0, 2f
1:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
2:  bl Lrt_json_wfail               // noreturn (x0 = errno)

// ---------------------------------------------------------------------
// Lrt_json_put -- append bytes to the buffer, writing it whenever it
//   becomes full.
//   Inputs  : x0 = bytes, x1 = count (may be 0)
//   Outputs : none (a failed write does not return)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = state, x20 = source cursor, x21 = bytes left
//   Frame   : 48 bytes (frame record + x19..x21, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_put:
    stp x29, x30, [sp, #-48]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    RJ_STATE x19
    mov x20, x0
    mov x21, x1
Lrt_json_put_loop:
    cbz x21, Lrt_json_put_done      // everything appended
    ldr x12, [x19, #RJ_FILL]
    mov x13, #SEA_JSON_BUF_BYTES
    sub x13, x13, x12               // free space (>= 1: a full buffer is written at once)
    cmp x21, x13
    csel x2, x21, x13, lo           // n = min(left, free)
    add x0, x19, #RJ_BUF
    add x0, x0, x12                 // destination = buffer + fill
    add x12, x12, x2
    str x12, [x19, #RJ_FILL]        // fill += n
    mov x1, x20
    add x20, x20, x2                // advance the cursor ...
    sub x21, x21, x2                // ... and the count
    bl _memcpy
    ldr x12, [x19, #RJ_FILL]
    mov x13, #SEA_JSON_BUF_BYTES
    cmp x12, x13
    b.lo Lrt_json_put_loop          // room left
    bl Lrt_json_flush               // full: write it out
    b Lrt_json_put_loop
Lrt_json_put_done:
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrt_json_indent -- LF, then two spaces per open container.
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = spaces left
//   Frame   : 32 bytes (frame record + x19, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_indent:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str x19, [sp, #16]
    adrp x0, Lrt_json_s_commalf@PAGE
    add x0, x0, Lrt_json_s_commalf@PAGEOFF
    add x0, x0, #1                  // just the LF
    mov x1, #1
    bl Lrt_json_put
    RJ_STATE x9
    ldr x19, [x9, #RJ_DEPTH]
    lsl x19, x19, #1                // 2 spaces per level
1:  cbz x19, 2f
    mov x1, #RJ_SPACES
    cmp x19, x1
    csel x1, x19, x1, lo            // n = min(left, block)
    sub x19, x19, x1
    adrp x0, Lrt_json_s_spaces@PAGE
    add x0, x0, Lrt_json_s_spaces@PAGEOFF
    bl Lrt_json_put
    b 1b
2:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// Lrt_json_sep -- start a new member or element of the innermost open
//   container: `,` if it has one already, then LF and the indentation;
//   marks it as having one.
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_sep:
    stp x29, x30, [sp, #-16]!       // frame record
    mov x29, sp
    RJ_STATE x9
    ldr x10, [x9, #RJ_STK]
    ldr x11, [x9, #RJ_DEPTH]
    sub x11, x11, #1                // the innermost container
    ldrb w12, [x10, x11]
    orr w13, w12, #RJ_K_HAS         // it has one from now on
    strb w13, [x10, x11]
    tbz w12, #1, 1f                 // RJ_K_HAS was clear: no comma
    adrp x0, Lrt_json_s_commalf@PAGE
    add x0, x0, Lrt_json_s_commalf@PAGEOFF
    mov x1, #1                      // `,`
    bl Lrt_json_put
1:  bl Lrt_json_indent              // LF and 2D spaces
    ldp x29, x30, [sp], #16
    ret
.if (RJ_K_HAS != 2)
    .error "rt_file: Lrt_json_sep tests bit 1 for RJ_K_HAS"
.endif

// ---------------------------------------------------------------------
// Lrt_json_pre -- what comes before a value: nothing for the top value
//   or the value of a key; in an array Lrt_json_sep.
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Frame   : none (return or tail call)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_pre:
    RJ_STATE x9
    ldr x11, [x9, #RJ_DEPTH]
    cbz x11, 1f                     // the top value
    ldr x10, [x9, #RJ_STK]
    sub x11, x11, #1
    ldrb w12, [x10, x11]
    tbnz w12, #0, Lrt_json_sep      // an array: separator (tail call)
1:  ret                             // an object: the value follows its key
.if (RJ_K_ARR != 1)
    .error "rt_file: Lrt_json_pre tests bit 0 for RJ_K_ARR"
.endif

// ---------------------------------------------------------------------
// Lrt_json_push -- open a container (after Lrt_json_pre).
//   Purpose : grows the stack by doubling when it is full (no memory:
//             OUT_OF_MEMORY at the state's site), pushes the kind,
//             writes `{` or `[`.
//   Inputs  : w0 = 0 for an object, RJ_K_ARR for an array
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = state, x20 = kind, x21 = new stack,
//             x22 = new size
//   Frame   : 48 bytes (frame record + x19..x22)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_push:
    stp x29, x30, [sp, #-48]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    RJ_STATE x19
    mov w20, w0
    ldr x9, [x19, #RJ_DEPTH]
    ldr x22, [x19, #RJ_STKCAP]
    cmp x9, x22
    b.lo 1f                         // room for one more
    lsl x22, x22, #1                // double it
    mov x0, x22
    ldr x1, [x19, #RJ_SITE]
    bl _sea_alloc                   // noreturn on failure
    mov x21, x0
    ldr x1, [x19, #RJ_STK]          // move the old entries over
    ldr x2, [x19, #RJ_DEPTH]
    bl _memcpy
    ldr x0, [x19, #RJ_STK]
    ldr x1, [x19, #RJ_STKCAP]       // still the old size
    bl _sea_free_block
    str x21, [x19, #RJ_STK]
    str x22, [x19, #RJ_STKCAP]
1:  ldr x10, [x19, #RJ_STK]
    ldr x9, [x19, #RJ_DEPTH]
    strb w20, [x10, x9]             // the new container, no element yet
    add x9, x9, #1
    str x9, [x19, #RJ_DEPTH]
    adrp x0, Lrt_json_s_open@PAGE   // "{[": the kind picks the byte
    add x0, x0, Lrt_json_s_open@PAGEOFF
    add x0, x0, x20
    mov x1, #1
    bl Lrt_json_put
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrt_json_pop -- close the innermost container: LF and the indentation
//   of the enclosing level if it has an element, then `}` or `]`.
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = the popped stack byte
//   Frame   : 32 bytes (frame record + x19, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_pop:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str x19, [sp, #16]
    RJ_STATE x9
    ldr x10, [x9, #RJ_STK]
    ldr x11, [x9, #RJ_DEPTH]
    sub x11, x11, #1                // one level fewer
    str x11, [x9, #RJ_DEPTH]
    ldrb w19, [x10, x11]
    tbz w19, #1, 1f                 // empty: `{}` / `[]`
    bl Lrt_json_indent              // LF and 2D spaces (D after the pop)
1:  adrp x0, Lrt_json_s_close@PAGE  // "}]": the kind picks the byte
    add x0, x0, Lrt_json_s_close@PAGEOFF
    and x9, x19, #RJ_K_ARR
    add x0, x0, x9
    mov x1, #1
    bl Lrt_json_put
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// Lrt_json_wf64 -- an f64 token: %.17g if finite, else `null`.
//   Inputs  : d0 = x
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: none
//   Frame   : 16 (frame record) + 16 (variadic slot at [sp]) + RJ_NUMBUF
//             (text at [sp, #16]) = 64 bytes
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_wf64:
    stp x29, x30, [sp, #-16]!       // frame record
    mov x29, sp
    sub sp, sp, #(16 + RJ_NUMBUF)
    fmov x9, d0
    lsl x9, x9, #1                  // |bits| << 1
    movz x10, #0xFFE0, lsl #48      // Inf's bits << 1
    cmp x9, x10
    b.hs 1f                         // NaN or +-Inf: null
    // snprintf(text, size, "%.17g", x): the double is variadic, so on
    // Apple arm64 it goes in the stack slot at [sp].
    str d0, [sp]
    add x0, sp, #16
    mov x1, #RJ_NUMBUF
    adrp x2, Lrt_json_s_g17@PAGE
    add x2, x2, Lrt_json_s_g17@PAGEOFF
    bl _snprintf
    sxtw x1, w0                     // the text's length
    add x0, sp, #16
    bl Lrt_json_put
    b 2f
1:  adrp x0, Lrt_json_s_null@PAGE
    add x0, x0, Lrt_json_s_null@PAGEOFF
    mov x1, #4
    bl Lrt_json_put
2:  add sp, sp, #(16 + RJ_NUMBUF)
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// Lrt_json_wi64 -- an i64 token in decimal ('-' before a negative value,
//   -9223372036854775808 for -2^63).
//   Inputs  : x0 = v
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Frame   : 16 (frame record) + RJ_NUMBUF (digits) = 48 bytes
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_wi64:
    stp x29, x30, [sp, #-16]!       // frame record
    mov x29, sp
    sub sp, sp, #RJ_NUMBUF
    cmp x0, #0
    cset w11, lt                    // negative?
    cneg x10, x0, lt                // magnitude (2^63 exact as unsigned)
    add x9, sp, #RJ_NUMBUF          // digits right to left from the end
    mov x12, #10
1:  udiv x13, x10, x12
    msub x14, x13, x12, x10         // the next digit
    add w14, w14, #'0'
    strb w14, [x9, #-1]!
    mov x10, x13
    cbnz x10, 1b
    cbz w11, 2f
    mov w14, #'-'
    strb w14, [x9, #-1]!
2:  mov x0, x9
    add x1, sp, #RJ_NUMBUF
    sub x1, x1, x9                  // the number of bytes
    bl Lrt_json_put
    add sp, sp, #RJ_NUMBUF
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// Lrt_json_wbool -- `true` for a nonzero v, else `false`.
//   Inputs  : x0 = v (0 or 1)
//   Frame   : none (tail call of Lrt_json_put)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_wbool:
    cbz x0, 1f
    adrp x0, Lrt_json_s_true@PAGE
    add x0, x0, Lrt_json_s_true@PAGEOFF
    mov x1, #4
    b Lrt_json_put
1:  adrp x0, Lrt_json_s_false@PAGE
    add x0, x0, Lrt_json_s_false@PAGEOFF
    mov x1, #5
    b Lrt_json_put

// ---------------------------------------------------------------------
// Lrt_json_wstr -- a string token, escaped (L-bz).
//   Purpose : `"`, then runs of bytes that need no escape copied as they
//             are and each other byte as its escape, then `"`. A null
//             pointer (a str element not yet stored, DESIGN.md 4.1) is
//             written as the empty string.
//   Inputs  : x0 = s (string object or 0)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = cursor, x20 = end, x21 = start of the run
//   Frame   : 48 bytes (frame record + x19..x21; the escape is built in
//             the 8 bytes at sp+40)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_wstr:
    stp x29, x30, [sp, #-48]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, #0                     // null: no bytes
    mov x20, #0
    cbz x0, 1f
    add x19, x0, #SEA_STR_BYTES
    ldr x9, [x0, #SEA_STR_LEN]
    add x20, x19, x9                // one past the last byte
1:  adrp x0, Lrt_json_s_quote@PAGE
    add x0, x0, Lrt_json_s_quote@PAGEOFF
    mov x1, #1
    bl Lrt_json_put                 // the opening quote
    mov x21, x19                    // a run starts
Lrt_json_wstr_scan:
    cmp x19, x20
    b.hs Lrt_json_wstr_end
    ldrb w9, [x19]
    cmp w9, #0x20
    b.lo Lrt_json_wstr_esc          // a control byte
    cmp w9, #'"'
    b.eq Lrt_json_wstr_esc
    cmp w9, #'\\'
    b.eq Lrt_json_wstr_esc
    add x19, x19, #1                // as it is: the run goes on
    b Lrt_json_wstr_scan
Lrt_json_wstr_esc:
    // The run so far, then this byte's escape.
    mov x0, x21
    sub x1, x19, x21
    bl Lrt_json_put
    ldrb w9, [x19], #1
    mov x21, x19                    // the next run starts after it
    mov w10, #'\\'
    strb w10, [sp, #40]             // every escape starts with a backslash
    mov x1, #2                      // \" \\ \n \t: two bytes
    cmp w9, #'"'
    b.eq 2f
    cmp w9, #'\\'
    b.eq 2f
    mov w10, #'n'
    cmp w9, #0x0A                   // LF
    b.eq 3f
    mov w10, #'t'
    cmp w9, #0x09                   // TAB
    b.eq 3f
    // \u00XX with lower-case hex digits.
    mov w10, #'u'
    strb w10, [sp, #41]
    mov w10, #'0'
    strb w10, [sp, #42]
    strb w10, [sp, #43]
    adrp x11, Lrt_json_s_hex@PAGE
    add x11, x11, Lrt_json_s_hex@PAGEOFF
    lsr w12, w9, #4
    ldrb w12, [x11, x12]            // high digit
    strb w12, [sp, #44]
    and w12, w9, #0xF
    ldrb w12, [x11, x12]            // low digit
    strb w12, [sp, #45]
    mov x1, #6
    b 4f
2:  strb w9, [sp, #41]              // \" or \\: the byte itself
    b 4f
3:  strb w10, [sp, #41]             // \n or \t
4:  add x0, sp, #40
    bl Lrt_json_put
    b Lrt_json_wstr_scan
Lrt_json_wstr_end:
    mov x0, x21                     // the last run
    sub x1, x19, x21
    bl Lrt_json_put
    adrp x0, Lrt_json_s_quote@PAGE
    add x0, x0, Lrt_json_s_quote@PAGEOFF
    mov x1, #1
    bl Lrt_json_put                 // the closing quote
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrt_json_welem -- one array element as the scalar entries write it,
//   after Lrt_json_pre.
//   Inputs  : w0 = ek (SEA_EK_F64, SEA_EK_I64, SEA_EK_BOOL, SEA_EK_STR),
//             x1 = the element's address
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = ek, x20 = address
//   Frame   : 32 bytes (frame record + x19, x20)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_welem:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov w19, w0
    mov x20, x1
    bl Lrt_json_pre
    cmp w19, #SEA_EK_F64
    b.eq 1f
    cmp w19, #SEA_EK_I64
    b.eq 2f
    cmp w19, #SEA_EK_BOOL
    b.eq 3f
    ldr x0, [x20]                   // SEA_EK_STR: the string object
    bl Lrt_json_wstr
    b 4f
1:  ldr d0, [x20]
    bl Lrt_json_wf64
    b 4f
2:  ldr x0, [x20]
    bl Lrt_json_wi64
    b 4f
3:  ldrb w0, [x20]
    bl Lrt_json_wbool
4:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// _sea_json_open -- the entry JSON_OPEN (DESIGN.md 4.8, 2.11.6, L-ca).
//   Purpose : first allocates the emitter's state (the retained path, an
//             empty buffer, the container stack, depth 0, descriptor -1)
//             and makes it current, then copies the path into a
//             NUL-terminated buffer and opens it (O_WRONLY | O_CREAT |
//             O_TRUNC, mode 0666 before the umask) and stores the
//             descriptor. A failure (a NUL byte in the path: EINVAL)
//             frees the state, then CANNOT_OPEN with the path and errno.
//   Inputs  : x0 = path (string object), x1 = site
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = path, x20 = site, x21 = state, x22 = the
//             path buffer, then the errno
//   Frame   : 48 bytes (frame record + x19..x22) + 16 (open's variadic
//             mode slot at [sp]) = 64 bytes
// ---------------------------------------------------------------------
    .globl _sea_json_open
    .p2align 2
_sea_json_open:
    stp x29, x30, [sp, #-48]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    sub sp, sp, #16
    mov x19, x0
    mov x20, x1
    // The state: header and buffer in one block.
    movz x0, #(RJ_SIZE & 0xFFFF)
    movk x0, #(RJ_SIZE >> 16), lsl #16
    bl _sea_alloc                   // x1 = site; noreturn on failure
    mov x21, x0
    mov x9, #-1
    str x9, [x21, #RJ_FD]           // no descriptor yet
    str xzr, [x21, #RJ_FILL]
    str xzr, [x21, #RJ_DEPTH]
    str x20, [x21, #RJ_SITE]
    str xzr, [x21, #RJ_STK]
    str xzr, [x21, #RJ_STKCAP]
    str x19, [x21, #RJ_PATH]
    mov x0, x19
    bl _sea_retain                  // the state keeps the path
    adrp x9, _sea_json_st@PAGE
    str x21, [x9, _sea_json_st@PAGEOFF]    // current (descriptor -1)
    mov x0, #RJ_STK0
    mov x1, x20
    bl _sea_alloc                   // the container stack
    str x0, [x21, #RJ_STK]
    mov x9, #RJ_STK0
    str x9, [x21, #RJ_STKCAP]
    // The NUL-terminated path, and the open.
    mov x0, x19
    mov x1, x20
    bl Lrt_file_cpath               // x0 = buffer, x1 = holds a NUL
    mov x22, x0
    cbz x1, 1f
    mov x0, x22                     // a NUL byte: EINVAL
    ldr x1, [x19, #SEA_STR_LEN]
    add x1, x1, #1
    bl _sea_free_block
    mov x22, #RT_FILE_EINVAL
    b Lrt_json_open_fail
1:  mov x9, #RT_FILE_MODE_FILE
    str x9, [sp]                    // open's mode is variadic: the stack slot
    mov x0, x22
    mov w1, #(RT_FILE_O_WRONLY | RT_FILE_O_CREAT | RT_FILE_O_TRUNC)
    bl _open                        // fd, or -1 and errno
    sxtw x9, w0
    str x9, [x21, #RJ_FD]           // the descriptor (or -1)
    tbz x9, #63, 2f                 // opened
    bl Lrt_file_errno
    mov x9, x22
    mov x22, x0                     // the errno of open
    mov x0, x9                      // the path buffer
    ldr x1, [x19, #SEA_STR_LEN]
    add x1, x1, #1
    bl _sea_free_block
    b Lrt_json_open_fail
2:  mov x0, x22                     // the path buffer is not kept
    ldr x1, [x19, #SEA_STR_LEN]
    add x1, x1, #1
    bl _sea_free_block
    add sp, sp, #16
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
Lrt_json_open_fail:
    // x22 = errno. Free the state (it holds no open descriptor), then
    // report with the borrowed path, which the caller keeps alive.
    bl Lrt_json_free
    mov w0, #SEA_E_CANNOT_OPEN
    mov x1, x20
    mov x2, x19
    mov x3, x22
    bl Lrt_file_fail                // noreturn

// ---------------------------------------------------------------------
// Lrt_json_free -- release the path, free the stack and the state, and
//   make no state current.
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = state
//   Frame   : 32 bytes (frame record + x19, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_json_free:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str x19, [sp, #16]
    RJ_STATE x19
    adrp x9, _sea_json_st@PAGE
    str xzr, [x9, _sea_json_st@PAGEOFF]    // none current
    ldr x0, [x19, #RJ_PATH]
    bl _sea_release
    ldr x0, [x19, #RJ_STK]
    cbz x0, 1f                      // not allocated yet
    ldr x1, [x19, #RJ_STKCAP]
    bl _sea_free_block
1:  mov x0, x19
    movz x1, #(RJ_SIZE & 0xFFFF)
    movk x1, #(RJ_SIZE >> 16), lsl #16
    bl _sea_free_block
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// _sea_json_close -- the entry JSON_CLOSE (DESIGN.md 4.8, 2.11.6).
//   Purpose : LF after the top value, flush, close, then release the path
//             and free the state. A failed write or close: CANNOT_WRITE
//             with the path and the errno (descriptor -1, state kept).
//   Inputs  : x0 = site
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = state
//   Frame   : 32 bytes (frame record + x19, pad)
// ---------------------------------------------------------------------
    .globl _sea_json_close
    .p2align 2
_sea_json_close:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str x19, [sp, #16]
    RJ_SITE_SET x0
    adrp x0, Lrt_json_s_commalf@PAGE
    add x0, x0, Lrt_json_s_commalf@PAGEOFF
    add x0, x0, #1                  // the final LF
    mov x1, #1
    bl Lrt_json_put
    bl Lrt_json_flush
    RJ_STATE x19
    ldr x0, [x19, #RJ_FD]
    mov x9, #-1
    str x9, [x19, #RJ_FD]           // closed from here on, whatever close says
    bl _close                       // 0, or -1 and errno
    cbz w0, 1f
    bl Lrt_file_errno
    bl Lrt_json_wfail               // noreturn (descriptor already -1)
1:  bl Lrt_json_free
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// _sea_json_obj / _sea_json_arr -- the entries JSON_OBJ, JSON_ARR: begin
//   an object / an array as the next value.
//   Inputs  : x0 = site
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: none
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .globl _sea_json_obj
    .p2align 2
_sea_json_obj:
    stp x29, x30, [sp, #-16]!       // frame record
    mov x29, sp
    RJ_SITE_SET x0
    bl Lrt_json_pre
    mov w0, #0                      // an object
    bl Lrt_json_push
    ldp x29, x30, [sp], #16
    ret

    .globl _sea_json_arr
    .p2align 2
_sea_json_arr:
    stp x29, x30, [sp, #-16]!       // frame record
    mov x29, sp
    RJ_SITE_SET x0
    bl Lrt_json_pre
    mov w0, #RJ_K_ARR               // an array
    bl Lrt_json_push
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// _sea_json_end -- the entry JSON_END: end the innermost container.
//   Inputs  : x0 = site
//   Frame   : none (tail call of Lrt_json_pop)
// ---------------------------------------------------------------------
    .globl _sea_json_end
    .p2align 2
_sea_json_end:
    RJ_SITE_SET x0
    b Lrt_json_pop

// ---------------------------------------------------------------------
// _sea_json_key -- the entry JSON_KEY: the next member's key in the
//   innermost open object: separator, the key as a string, `: `.
//   Inputs  : x0 = key (string object), x1 = site
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = key
//   Frame   : 32 bytes (frame record + x19, pad)
// ---------------------------------------------------------------------
    .globl _sea_json_key
    .p2align 2
_sea_json_key:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    RJ_SITE_SET x1
    bl Lrt_json_sep
    mov x0, x19
    bl Lrt_json_wstr
    adrp x0, Lrt_json_s_colon@PAGE
    add x0, x0, Lrt_json_s_colon@PAGEOFF
    mov x1, #2                      // ": "
    bl Lrt_json_put
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// _sea_json_f64 -- the entry JSON_F64.
//   Inputs  : d0 = x, x0 = site
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: d8 = x
//   Frame   : 32 bytes (frame record + d8, pad)
// ---------------------------------------------------------------------
    .globl _sea_json_f64
    .p2align 2
_sea_json_f64:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str d8, [sp, #16]
    fmov d8, d0
    RJ_SITE_SET x0
    bl Lrt_json_pre
    fmov d0, d8
    bl Lrt_json_wf64
    ldr d8, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// _sea_json_i64 / _sea_json_bool / _sea_json_str -- the entries
//   JSON_I64, JSON_BOOL, JSON_STR: one scalar as the next value.
//   Inputs  : x0 = v (i64, bool 0/1, or a string object), x1 = site
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = v
//   Frame   : 32 bytes (frame record + x19, pad)
// ---------------------------------------------------------------------
.macro RJ_SCALAR_ENTRY name, writer
    .globl \name
    .p2align 2
\name:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    RJ_SITE_SET x1
    bl Lrt_json_pre                 // separator in an array
    mov x0, x19
    bl \writer                      // the token
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
.endm
    RJ_SCALAR_ENTRY _sea_json_i64, Lrt_json_wi64
    RJ_SCALAR_ENTRY _sea_json_bool, Lrt_json_wbool
    RJ_SCALAR_ENTRY _sea_json_str, Lrt_json_wstr

// ---------------------------------------------------------------------
// _sea_json_vec -- the entry JSON_VEC: a dynamic vector as a flat array
//   (its rows * cols elements in buffer order; cols is 1 for a vector),
//   `[]` when empty.
//   Inputs  : x0 = a (array of ek F64, I64, BOOL or STR), x1 = site
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = a, x20 = element cursor, x21 = elements
//             left, x22 = element size
//   Frame   : 48 bytes (frame record + x19..x22)
// ---------------------------------------------------------------------
    .globl _sea_json_vec
    .p2align 2
_sea_json_vec:
    stp x29, x30, [sp, #-48]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    RJ_SITE_SET x1
    bl Lrt_json_pre
    mov w0, #RJ_K_ARR
    bl Lrt_json_push                // `[`
    ldr x9, [x19, #SEA_ARR_ROWS]
    ldr x10, [x19, #SEA_ARR_COLS]
    mul x21, x9, x10                // the number of elements
    ldr x20, [x19, #SEA_ARR_DATA]
    ldr x22, [x19, #SEA_ARR_ESIZE]
1:  cbz x21, 2f
    ldrb w0, [x19, #SEA_ARR_EK]
    mov x1, x20
    bl Lrt_json_welem
    add x20, x20, x22               // the next element
    sub x21, x21, #1
    b 1b
2:  bl Lrt_json_pop                 // `]`
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// _sea_json_mat -- the entry JSON_MAT: a dynamic matrix of r rows and c
//   columns as an array of r arrays of c elements, element (i, j) at
//   position j of row i (column-major buffer: DATA + esize * (i + j*r));
//   a matrix with no element is `[]`.
//   Inputs  : x0 = a (array of ek F64, I64, BOOL or STR), x1 = site
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = a, x20 = row i, x21 = column j, x22 = rows,
//             x23 = cols, x24 = element size
//   Frame   : 64 bytes (frame record + x19..x24)
// ---------------------------------------------------------------------
    .globl _sea_json_mat
    .p2align 2
_sea_json_mat:
    stp x29, x30, [sp, #-64]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    RJ_SITE_SET x1
    bl Lrt_json_pre
    mov w0, #RJ_K_ARR
    bl Lrt_json_push                // the outer `[`
    ldr x22, [x19, #SEA_ARR_ROWS]
    ldr x23, [x19, #SEA_ARR_COLS]
    ldr x24, [x19, #SEA_ARR_ESIZE]
    cbz x23, 4f                     // no element: `[]`
    mov x20, #0                     // row i
1:  cmp x20, x22
    b.hs 4f                         // every row written (none if r = 0)
    bl Lrt_json_pre                 // the row is an element of the outer array
    mov w0, #RJ_K_ARR
    bl Lrt_json_push                // the row's `[`
    mov x21, #0                     // column j
2:  cmp x21, x23
    b.hs 3f
    madd x9, x21, x22, x20          // i + j*r
    ldr x1, [x19, #SEA_ARR_DATA]
    madd x1, x9, x24, x1            // its address
    ldrb w0, [x19, #SEA_ARR_EK]
    bl Lrt_json_welem
    add x21, x21, #1
    b 2b
3:  bl Lrt_json_pop                 // the row's `]`
    add x20, x20, #1
    b 1b
4:  bl Lrt_json_pop                 // the outer `]`
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
// _sea_json_abort -- for _sea_err (LANGUAGE.md 9.2 step 3, L-ca): if a
//   JSON file is open (a state exists and its descriptor is not -1),
//   write its buffer and close it, ignoring both results, and set the
//   descriptor to -1. Nothing else is freed (the process ends).
//   Inputs  : none
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = state
//   Frame   : 32 bytes (frame record + x19, pad)
// ---------------------------------------------------------------------
    .private_extern _sea_json_abort
    .p2align 2
_sea_json_abort:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str x19, [sp, #16]
    RJ_STATE x19
    cbz x19, 2f                     // no emitter state
    ldr x0, [x19, #RJ_FD]
    cmn x0, #1
    b.eq 2f                         // no open file
    ldr x2, [x19, #RJ_FILL]
    cbz x2, 1f
    str xzr, [x19, #RJ_FILL]
    add x1, x19, #RJ_BUF
    bl _sea_write_all               // result ignored
1:  ldr x0, [x19, #RJ_FD]
    mov x9, #-1
    str x9, [x19, #RJ_FD]
    bl _close                       // result ignored
2:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// Constant texts.
// ---------------------------------------------------------------------
    .section __TEXT,__cstring,cstring_literals
Lrt_json_s_g17:     .asciz "%.17g"
    .section __TEXT,__const
Lrt_json_s_commalf: .ascii ",\n"
Lrt_json_s_colon:   .ascii ": "
Lrt_json_s_quote:   .ascii "\""
Lrt_json_s_open:    .ascii "{["         /* indexed by RJ_K_ARR */
Lrt_json_s_close:   .ascii "}]"         /* indexed by RJ_K_ARR */
Lrt_json_s_null:    .ascii "null"
Lrt_json_s_true:    .ascii "true"
Lrt_json_s_false:   .ascii "false"
Lrt_json_s_hex:     .ascii "0123456789abcdef"
Lrt_json_s_spaces:  .space RJ_SPACES, 0x20

// ---------------------------------------------------------------------
// State: the current emitter state (0 when no write_json is running).
// ---------------------------------------------------------------------
    .private_extern _sea_json_st
.zerofill __DATA,__bss,_sea_json_st,8,3
