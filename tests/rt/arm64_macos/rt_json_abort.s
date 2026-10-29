// sea/tests/rt/arm64_macos/rt_json_abort.s -- a run-time error while a JSON file is open (LANGUAGE.md 9.2 step 3, DESIGN.md 2.11.6, L-ca): _sea_err reports the original error, then flushes the emitter's buffer to the file and closes it; a forked child does the writes and the error, the parent prints the child's status and the file (as written: no closing bracket, no final LF)
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

// ---- test helpers (the same block in every 4c runtime test) ----------
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
// The address of a label.
.macro LA reg, label
    adrp \reg, \label@PAGE
    add \reg, \reg, \label@PAGEOFF
.endm
// Load a 64-bit constant into a register.
.macro LI reg, val
    movz \reg, #((\val) & 0xffff)
    movk \reg, #(((\val) >> 16) & 0xffff), lsl #16
    movk \reg, #(((\val) >> 32) & 0xffff), lsl #32
    movk \reg, #(((\val) >> 48) & 0xffff), lsl #48
.endm
// Print a literal text (x0-x17 clobbered).
.macro TXT text
    .pushsection __TEXT,__cstring,cstring_literals
Ltxt\@: .asciz "\text"
    .popsection
    LA x0, Ltxt\@
    bl Lput_cstr
.endm
// Print a literal text, then a register in signed decimal (x0-x17 clobbered;
// reg must not be x0-x17 unless it is x1).
.macro KV text, reg
    mov x1, \reg
    .pushsection __TEXT,__cstring,cstring_literals
Lkv\@: .asciz "\text"
    .popsection
    LA x0, Lkv\@
    bl Lput_kv
.endm
// The live-object counter of rt_mem.s into a register.
.macro LIVE reg
    adrp \reg, _sea_live@PAGE
    ldr \reg, [\reg, _sea_live@PAGEOFF]
.endm
// The release sequence of pass 4 (DESIGN.md 4.9) on the object in reg:
// the count drops by one unless static, _sea_free at 0 (x0-x17 clobbered).
.macro REL reg
    mov x0, \reg
    ldr x10, [x0]
    cbz x10, Lrel\@
    subs x10, x10, #1
    str x10, [x0]
    b.ne Lrel\@
    bl _sea_free
Lrel\@:
.endm
// _sea_main's frame: the frame record and x19-x28 (all callee-saved).
.macro PROLOGUE
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
.endm
.macro EPILOGUE
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret
.endm

    .section __TEXT,__text,regular,pure_instructions

// Lput_cstr -- print a NUL-terminated text. x0 = text. Clobbers x0-x17.
// Callee-saved used: x19 (the text). Frame 32 bytes.
    .p2align 2
Lput_cstr:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    bl _strlen                  // its length
    mov x1, x0
    mov x0, x19
    bl _sea_out_write           // into the standard-output buffer
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lput_dec -- print x0 as a signed decimal. Clobbers x0-x17. Frame 48
// bytes (frame record, 32 bytes of digits).
    .p2align 2
Lput_dec:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    add x9, sp, #48             // digits right to left from the end
    cmp x0, #0
    cset w11, lt                // negative?
    cneg x10, x0, lt            // magnitude (2^63 exact as unsigned)
    mov x12, #10
1:  udiv x13, x10, x12
    msub x14, x13, x12, x10     // the next digit
    add w14, w14, #'0'
    strb w14, [x9, #-1]!
    mov x10, x13
    cbnz x10, 1b
    cbz w11, 2f
    mov w14, #'-'
    strb w14, [x9, #-1]!
2:  mov x0, x9
    add x1, sp, #48
    sub x1, x1, x9              // the number of bytes
    bl _sea_out_write
    ldp x29, x30, [sp], #48
    ret

// Lput_kv -- print a text, then x1 in signed decimal. x0 = text. Clobbers
// x0-x17. Callee-saved used: x19 (the value). Frame 32 bytes.
    .p2align 2
Lput_kv:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x1
    bl Lput_cstr
    mov x0, x19
    bl Lput_dec
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lput_str -- print a string object's bytes between [ and ]. x0 = the
// object. Clobbers x0-x17. Callee-saved used: x19. Frame 32 bytes.
    .p2align 2
Lput_str:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    LA x0, Lput_s_lb
    mov x1, #1
    bl _sea_out_write
    add x0, x19, #SEA_STR_BYTES
    ldr x1, [x19, #SEA_STR_LEN]
    bl _sea_out_write
    LA x0, Lput_s_rb
    mov x1, #1
    bl _sea_out_write
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .section __TEXT,__const
Lput_s_lb: .ascii "["
Lput_s_rb: .ascii "]"
    .section __TEXT,__text,regular,pure_instructions
// ---- end of the test helpers ------------------------------------------
// ---- phase-6 helpers (the same block in every 6b runtime test) --------
// Lput_hex -- print x0 as 16 upper-case hexadecimal digits (the bits of an
// f64). Clobbers x0-x17. Frame 32 bytes (frame record, 16 bytes of digits).
    .p2align 2
Lput_hex:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    add x9, sp, #16             // the digits at [sp + 16, sp + 32)
    mov x10, #16
1:  and x11, x0, #0xf           // the lowest digit, written right to left
    add x12, x11, #'0'
    add x13, x11, #('A' - 10)
    cmp x11, #10
    csel x12, x13, x12, hs
    sub x10, x10, #1
    strb w12, [x9, x10]
    lsr x0, x0, #4
    cbnz x10, 1b
    mov x0, x9
    mov x1, #16
    bl _sea_out_write
    ldp x29, x30, [sp], #32
    ret

// Lcat -- print the bytes of a file (x0 = NUL-terminated path) to the
// standard-output buffer; a file that cannot be opened prints
// "<no file>". Clobbers x0-x17. Callee-saved used: x19 (fd). Frame 32
// bytes + a 4096-byte read buffer at [sp].
    .p2align 2
Lcat:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    sub sp, sp, #4096
    mov w1, #0                  // O_RDONLY
    bl _open
    mov w19, w0
    tbz w0, #31, 1f
    TXT "<no file>"
    b 3f
1:  mov w0, w19                 // read up to 4096 bytes
    mov x1, sp
    mov x2, #4096
    bl _read
    cmp x0, #0
    b.le 2f                     // end of file (or an error)
    mov x1, x0
    mov x0, sp
    bl _sea_out_write
    b 1b
2:  mov w0, w19
    bl _close
3:  add sp, sp, #4096
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
// ---- end of the phase-6 helpers ---------------------------------------

// JSON emitter calls, every one at site 0.
.macro J0 entry                     // an entry whose only argument is the site
    mov x0, #0
    bl \entry
.endm
.macro JP entry, label              // an entry taking a pointer, then the site
    LA x0, \label
    mov x1, #0
    bl \entry
.endm
.macro JF bits                      // _sea_json_f64(d0 = bits, site)
    LI x9, \bits
    fmov d0, x9
    mov x0, #0
    bl _sea_json_f64
.endm
.macro JI val                       // _sea_json_i64(val, site)
    LI x0, \val
    mov x1, #0
    bl _sea_json_i64
.endm
.macro JB val                       // _sea_json_bool(val, site)
    mov x0, #\val
    mov x1, #0
    bl _sea_json_bool
.endm
// A static dynamic-array header (rt.inc SEA_ARR_*, count SEA_RC_STATIC).
.macro SARR label, ek, rank, rows, cols, esize, data
    .p2align 3
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, \ek, \rank
    .space 5, 0
    .quad \rows, \cols, (\rows) * (\cols), \data, \esize, 0
.endm
// CAT cpath: print "--- <cpath>" LF, the file's bytes, then "|" LF.
.macro CAT cpath, name
    TXT "--- \name\n"
    LA x0, \cpath
    bl Lcat
    TXT "|\n"
.endm

    .section __TEXT,__text,regular,pure_instructions
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    sub sp, sp, #16                 // waitpid's status word at [sp]
    bl _fork
    cbnz w0, Lparent
    // The child: a JSON file half written, then a run-time error.
    JP _sea_json_open, La
    J0 _sea_json_obj
    JP _sea_json_key, Lk
    JI 1
    JP _sea_json_key, Ls
    J0 _sea_json_arr
    JB 1
    mov w0, #SEA_E_INT_OVERFLOW
    mov x1, #0                      // site 0: j.sea:9
    mov x2, #0
    bl _sea_err                     // flushes and closes a.json, exits 1
    brk #1
Lparent:
    mov x1, sp
    mov w2, #0
    bl _waitpid                     // w0 = the child's pid
    ldr w9, [sp]
    ubfx x19, x9, #8, #8            // WEXITSTATUS
    KV "child status=", x19
    TXT "\n"
    CAT Lc_a, a.json
    add sp, sp, #16
    EPILOGUE

    .section __TEXT,__cstring,cstring_literals
Lc_a:   .asciz "a.json"
    .section __DATA,__const
    SSTR La, 6, "a.json"
    SSTR Lk, 1, "k"
    SSTR Ls, 1, "s"
    SSTR Lfile, 5, "j.sea"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lfile, 9
