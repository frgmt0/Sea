// sea/tests/rt/arm64_macos/rt_json_layout.s -- the JSON emitter's layout (LANGUAGE.md 11.4, DESIGN.md 2.11.6, L-bz): f64 as %.17g (0.1, -0, 100, 1e300, 5e-324) and null for NaN and +-inf; i64 -2^63 and 2^63 - 1; true, false; a string with every escape class (quote, backslash, LF, TAB, 0x01, 0x1F, CR as u000d) and 0x7F, 0x80, 0xFF verbatim; an escaped key; empty object and array; nesting; vectors of f64, i64 (empty), bool, str; matrices 2x3 (column-major data), 1x1 of str, 0x3 and 3x0 as []; a path written twice (the second replaces the first); a top-level scalar, vector and empty object; each file read back
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
    // ---- a.json: every scalar, container and array kind -------------
    JP _sea_json_open, La
    J0 _sea_json_obj
    JP _sea_json_key, Lk_f
    J0 _sea_json_arr
    JF 0x3FB999999999999A           // 0.1
    JF 0x8000000000000000           // -0
    JF 0x4059000000000000           // 100
    JF 0x7E37E43C8800759C           // 1e300
    JF 0x0000000000000001           // 5e-324
    JF 0x7FF8000000000000           // NaN
    JF 0x7FF0000000000000           // inf
    JF 0xFFF0000000000000           // -inf
    J0 _sea_json_end
    JP _sea_json_key, Lk_i
    J0 _sea_json_arr
    JI 0
    JI 0x8000000000000000           // -2^63
    JI 0x7FFFFFFFFFFFFFFF           // 2^63 - 1
    J0 _sea_json_end
    JP _sea_json_key, Lk_b
    JB 1
    JP _sea_json_key, Lk_c
    JB 0
    JP _sea_json_key, Lk_s
    JP _sea_json_str, Lsesc
    JP _sea_json_key, Lk_eo
    J0 _sea_json_obj
    J0 _sea_json_end
    JP _sea_json_key, Lk_ea
    J0 _sea_json_arr
    J0 _sea_json_end
    JP _sea_json_key, Lk_nest
    J0 _sea_json_obj
    JP _sea_json_key, Lk_k
    J0 _sea_json_obj
    JP _sea_json_key, Lk_deep
    JI 1
    J0 _sea_json_end
    JP _sea_json_key, Lk_arr
    J0 _sea_json_arr
    J0 _sea_json_obj
    J0 _sea_json_end
    J0 _sea_json_arr
    J0 _sea_json_arr
    J0 _sea_json_end
    JP _sea_json_str, Lx
    J0 _sea_json_end
    J0 _sea_json_end
    J0 _sea_json_end
    JP _sea_json_key, Lk_vf
    JP _sea_json_vec, Lvf
    JP _sea_json_key, Lk_vi
    JP _sea_json_vec, Lvi
    JP _sea_json_key, Lk_vb
    JP _sea_json_vec, Lvb
    JP _sea_json_key, Lk_vs
    JP _sea_json_vec, Lvs
    JP _sea_json_key, Lk_m23
    JP _sea_json_mat, Lm23
    JP _sea_json_key, Lk_m11
    JP _sea_json_mat, Lm11
    JP _sea_json_key, Lk_m03
    JP _sea_json_mat, Lm03
    JP _sea_json_key, Lk_m30
    JP _sea_json_mat, Lm30
    JP _sea_json_key, Lk_q
    JI 5
    J0 _sea_json_end
    J0 _sea_json_close
    // ---- b.json written twice: the second replaces the first --------
    JP _sea_json_open, Lb
    JP _sea_json_vec, Lvf
    J0 _sea_json_close
    JP _sea_json_open, Lb
    JI 42                           // a top-level scalar
    J0 _sea_json_close
    // ---- c.json: a top-level vector and d.json: an empty top object --
    JP _sea_json_open, Lc
    JP _sea_json_vec, Lvs
    J0 _sea_json_close
    JP _sea_json_open, Ld
    J0 _sea_json_obj
    J0 _sea_json_end
    J0 _sea_json_close
    CAT Lc_a, a.json
    CAT Lc_b, b.json
    CAT Lc_c, c.json
    CAT Lc_d, d.json
    EPILOGUE

    .section __TEXT,__cstring,cstring_literals
Lc_a:   .asciz "a.json"
Lc_b:   .asciz "b.json"
Lc_c:   .asciz "c.json"
Lc_d:   .asciz "d.json"
    .section __DATA,__const
    SSTR La, 6, "a.json"
    SSTR Lb, 6, "b.json"
    SSTR Lc, 6, "c.json"
    SSTR Ld, 6, "d.json"
    SSTR Lk_f, 1, "f"
    SSTR Lk_i, 1, "i"
    SSTR Lk_b, 1, "b"
    SSTR Lk_c, 1, "c"
    SSTR Lk_s, 1, "s"
    SSTR Lk_eo, 2, "eo"
    SSTR Lk_ea, 2, "ea"
    SSTR Lk_nest, 4, "nest"
    SSTR Lk_k, 1, "k"
    SSTR Lk_deep, 4, "deep"
    SSTR Lk_arr, 3, "arr"
    SSTR Lk_vf, 2, "vf"
    SSTR Lk_vi, 2, "vi"
    SSTR Lk_vb, 2, "vb"
    SSTR Lk_vs, 2, "vs"
    SSTR Lk_m23, 3, "m23"
    SSTR Lk_m11, 3, "m11"
    SSTR Lk_m03, 3, "m03"
    SSTR Lk_m30, 3, "m30"
    .p2align 3
Lk_q:                               // the key k"ey
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .byte 0x6B, 0x22, 0x65, 0x79
    SSTR Lx, 1, "x"
    SSTR Lsa, 1, "a"
    SSTR Lsempty, 0, ""
    SSTR Lsz, 1, "z"
    .p2align 3
Lscd:                               // c"d
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 3
    .byte 0x63, 0x22, 0x64
    .p2align 3
Lsesc:                              // every escape class and the verbatim high bytes
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 15
    .byte 0x71, 0x22, 0x62, 0x5C, 0x6E, 0x0A, 0x74, 0x09, 0x63, 0x01, 0x1F, 0x0D, 0x7F, 0x80, 0xFF
    .p2align 3
Ld_vf:  .quad 0x3FF8000000000000, 0x4000000000000000         // 1.5, 2
Ld_vb:  .byte 0, 1
    .p2align 3
Ld_vs:  .quad Lsa, Lsempty, Lscd
Ld_m23: .quad 0x3FF0000000000000, 0x4010000000000000         // column-major: 1 4
        .quad 0x4000000000000000, 0x4014000000000000         //               2 5
        .quad 0x4008000000000000, 0x4018000000000000         //               3 6
Ld_m11: .quad Lsz
Ld_none: .quad 0
    SARR Lvf, SEA_EK_F64, 1, 2, 1, SEA_ESIZE_F64, Ld_vf
    SARR Lvi, SEA_EK_I64, 1, 0, 1, SEA_ESIZE_I64, Ld_none
    SARR Lvb, SEA_EK_BOOL, 1, 2, 1, SEA_ESIZE_BOOL, Ld_vb
    SARR Lvs, SEA_EK_STR, 1, 3, 1, SEA_ESIZE_PTR, Ld_vs
    SARR Lm23, SEA_EK_F64, 2, 2, 3, SEA_ESIZE_F64, Ld_m23
    SARR Lm11, SEA_EK_STR, 2, 1, 1, SEA_ESIZE_PTR, Ld_m11
    SARR Lm03, SEA_EK_I64, 2, 0, 3, SEA_ESIZE_I64, Ld_none
    SARR Lm30, SEA_EK_BOOL, 2, 3, 0, SEA_ESIZE_BOOL, Ld_none
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad La, 1
