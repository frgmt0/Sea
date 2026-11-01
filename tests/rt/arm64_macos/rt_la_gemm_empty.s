// sea/tests/rt/arm64_macos/rt_la_gemm_empty.s -- the empty shortcuts of sea_matmul, sea_gemv and sea_vecmat (DESIGN.md 2.13.2 "Empty operands", 2.13.5; LANGUAGE.md 10.8): r x 0 @ 0 x c is the r x c matrix of +0, 0 x k @ k x c the empty 0 x c matrix and r x k @ k x 0 the r x 0 one, 0 x 0 @ 0 x 0 the 0 x 0 one; r x 0 @ (empty) is r times +0, 0 x k @ x the empty vector; (empty) @ 0 x c is c times +0, x @ k x 0 the empty vector. Before each call a freed block of the result's class is filled with 42.0, so a zero result that is not written shows it; the ownership check and the heap check as in rt_la_gemm_values.
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

// ---- test helpers (the same block in every rt_la_gemm test) -----------
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
// The entries, by their index in the case tables.
.equ ENT_GEMV, 0
.equ ENT_VECMAT, 1
.equ ENT_MATMUL, 2
// The variant of the first pass: the one form of arm64-macos.
.equ FIRST_VARIANT, SEA_VAR_NEON

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

// Lput_hex -- print x0 as 16 upper-case hexadecimal digits. Clobbers
// x0-x17. Frame 32 bytes (frame record, 16 bytes of digits).
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

// Lput_f -- print the f64 bits in x0: `NaN` for every NaN (its bits are
// not observable, LANGUAGE.md 6.5), else the 16 hexadecimal digits.
// Clobbers x0-x17. Frame 16 bytes.
    .p2align 2
Lput_f:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    lsl x9, x0, #1              // drop the sign
    LI x10, 0xFFE0000000000000  // the exponent all ones, shifted
    cmp x9, x10
    b.ls 1f                     // not above +inf: a number
    TXT "NaN"
    b 2f
1:  bl Lput_hex
2:  ldp x29, x30, [sp], #16
    ret

// Lmk -- a new dynamic f64 array (count 1) holding a copy of n doubles.
//   Inputs  : x0 = rank, x1 = rows, x2 = cols (1 for a vector), x3 = the
//             source doubles (rows * cols of them, column-major)
//   Outputs : x0 = the array
//   Clobbers: x0-x17, v0-v7, v16-v31
//   Callee-saved used: x19 = the source, x20 = the array. Frame 32 bytes.
    .p2align 2
Lmk:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x3
    mov x4, x2
    mov x3, x4                  // cols
    mov x2, x1                  // rows
    mov x1, x0                  // rank
    mov x0, #SEA_EK_F64
    mov x4, #0                  // site 0
    bl _sea_arr_new_u
    mov x20, x0
    ldr x9, [x20, #SEA_ARR_ROWS]
    ldr x10, [x20, #SEA_ARR_COLS]
    mul x2, x9, x10
    lsl x2, x2, #3              // the bytes
    ldr x0, [x20, #SEA_ARR_DATA]
    mov x1, x19
    bl _memcpy
    mov x0, x20
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Ldirty -- leave a freed block of the class a result of this shape takes
// with every element 42.0 (#4045000000000000): the allocator hands the
// most recently freed block of a class out first, so a result that is not
// fully written shows it.
//   Inputs  : x0 = rank, x1 = rows, x2 = cols
//   Clobbers: x0-x17
//   Callee-saved used: x19 = the array. Frame 32 bytes.
    .p2align 2
Ldirty:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x3, x2
    mov x2, x1
    mov x1, x0
    mov x0, #SEA_EK_F64
    mov x4, #0
    bl _sea_arr_new_u
    mov x19, x0
    ldr x9, [x19, #SEA_ARR_ROWS]
    ldr x10, [x19, #SEA_ARR_COLS]
    mul x9, x9, x10             // elements
    ldr x10, [x19, #SEA_ARR_DATA]
    LI x11, 0x4045000000000000
    cbz x9, 2f
1:  str x11, [x10], #8
    subs x9, x9, #1
    b.ne 1b
2:  REL x19                     // count 1 -> freed
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lcall -- call an entry by its table index.
//   Inputs  : x0 = ENT_*, x1 = the left operand, x2 = the right operand
//   Outputs : x0 = the entry's result
//   Clobbers: as the entries. Frame 16 bytes.
    .p2align 2
Lcall:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    LA x9, Lentries
    ldr x9, [x9, x0, lsl #3]
    mov x0, x1
    mov x1, x2
    mov x2, #0                  // site 0
    blr x9
    ldp x29, x30, [sp], #16
    ret
    .section __DATA,__const
    .p2align 3
Lentries:
    .quad _sea_gemv, _sea_vecmat, _sea_matmul
    .section __TEXT,__text,regular,pure_instructions
// ---- end of the test helpers ------------------------------------------

// ---- the case table driver (rt_la_gemm_values, rt_la_gemm_empty) ------
// A case record (8-byte words): label, ENT_*, the left operand's rank,
// rows, cols, data, the right operand's rank, rows, cols, data, the
// expected result's rank, rows, cols. The table ends with a 0 label.
.equ CR_LABEL, 0
.equ CR_ENT, 8
.equ CR_L, 16
.equ CR_R, 48
.equ CR_RES, 80
.equ CR_SIZE, 104

// Lcase -- one case: the operands as fresh dynamic arrays (count 1), a
// dirty freed block of the result's class, the call, then the line
// `<label>: <rank> <rows>x<cols> own ok|own BAD <elements>`. "own ok"
// means: the live count rose by exactly one, the result has count 1, tag
// SEA_TAG_ARRAY and ek SEA_EK_F64, and both operands still have count 1
// and their original bytes. Everything is released afterwards.
//   Inputs  : x0 = the record
//   Clobbers: x0-x17, v0-v7, v16-v31
//   Callee-saved used: x19 = record, x20 = left, x21 = right, x22 = the
//             live count before the call, x23 = result, x24 = faults,
//             x25 = element cursor, x26 = elements left
//   Frame   : 96 bytes
    .p2align 2
Lcase:
    PROLOGUE
    mov x19, x0
    ldp x0, x1, [x19, #CR_L]
    ldp x2, x3, [x19, #(CR_L + 16)]
    bl Lmk
    mov x20, x0
    ldp x0, x1, [x19, #CR_R]
    ldp x2, x3, [x19, #(CR_R + 16)]
    bl Lmk
    mov x21, x0
    ldp x0, x1, [x19, #CR_RES]
    ldr x2, [x19, #(CR_RES + 16)]
    bl Ldirty
    LIVE x22
    ldr x0, [x19, #CR_ENT]
    mov x1, x20
    mov x2, x21
    bl Lcall
    mov x23, x0
    // ownership
    mov x24, #0
    LIVE x9
    add x10, x22, #1
    cmp x9, x10
    cinc x24, x24, ne           // exactly one new object
    ldr x9, [x23, #SEA_ARR_RC]
    cmp x9, #1
    cinc x24, x24, ne           // owned: count 1
    ldrb w9, [x23, #SEA_ARR_TAG]
    cmp w9, #SEA_TAG_ARRAY
    cinc x24, x24, ne
    ldrb w9, [x23, #SEA_ARR_EK]
    cmp w9, #SEA_EK_F64
    cinc x24, x24, ne
    ldr x9, [x20, #SEA_ARR_RC]
    cmp x9, #1
    cinc x24, x24, ne           // the operands borrowed: counts unchanged
    ldr x9, [x21, #SEA_ARR_RC]
    cmp x9, #1
    cinc x24, x24, ne
    ldr x0, [x20, #SEA_ARR_DATA] // and their bytes unchanged
    ldr x1, [x19, #(CR_L + 24)]
    ldr x9, [x20, #SEA_ARR_ROWS]
    ldr x10, [x20, #SEA_ARR_COLS]
    mul x2, x9, x10
    lsl x2, x2, #3
    bl _memcmp
    cmp w0, #0
    cinc x24, x24, ne
    ldr x0, [x21, #SEA_ARR_DATA]
    ldr x1, [x19, #(CR_R + 24)]
    ldr x9, [x21, #SEA_ARR_ROWS]
    ldr x10, [x21, #SEA_ARR_COLS]
    mul x2, x9, x10
    lsl x2, x2, #3
    bl _memcmp
    cmp w0, #0
    cinc x24, x24, ne
    // the line
    ldr x0, [x19, #CR_LABEL]
    bl Lput_cstr
    TXT ": "
    ldrb w0, [x23, #SEA_ARR_RANK]
    bl Lput_dec
    TXT " "
    ldr x0, [x23, #SEA_ARR_ROWS]
    bl Lput_dec
    TXT "x"
    ldr x0, [x23, #SEA_ARR_COLS]
    bl Lput_dec
    cbnz x24, 1f
    TXT " own ok"
    b 2f
1:  TXT " own BAD"
2:  ldr x25, [x23, #SEA_ARR_DATA]
    ldr x9, [x23, #SEA_ARR_ROWS]
    ldr x10, [x23, #SEA_ARR_COLS]
    mul x26, x9, x10
3:  cbz x26, 4f
    TXT " "
    ldr x0, [x25], #8
    bl Lput_f
    sub x26, x26, #1
    b 3b
4:  TXT "\n"
    REL x23
    REL x20
    REL x21
    EPILOGUE

// Lrun -- every record of a table. x0 = the table. Clobbers x0-x17.
// Callee-saved used: x19 (the record). Frame 32 bytes.
    .p2align 2
Lrun:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
1:  ldr x9, [x19, #CR_LABEL]
    cbz x9, 2f
    mov x0, x19
    bl Lcase
    add x19, x19, #CR_SIZE
    b 1b
2:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---- the test ---------------------------------------------------------
// _sea_main -- the table once, under the variant main selected. Frame 96
// bytes.
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    TXT "pass 1\n"
    LA x0, Lcases
    bl Lrun
    EPILOGUE

    .section __DATA,__const
    .p2align 3
Lce0_l:
Lce0_r:
    .quad 0                 /* (an operand with no element points here) */
Lce1_l:
Lce1_r:
    .quad 0                 /* (an operand with no element points here) */
Lce2_l:
Lce2_r:
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
Lce3_l:
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
Lce3_r:
    .quad 0                 /* (an operand with no element points here) */
Lce4_l:
Lce4_r:
    .quad 0                 /* (an operand with no element points here) */
Lce5_l:
Lce5_r:
    .quad 0                 /* (an operand with no element points here) */
Lce6_l:
Lce6_r:
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
Lce7_l:
Lce7_r:
    .quad 0                 /* (an operand with no element points here) */
Lce8_l:
Lce8_r:
    .quad 0                 /* (an operand with no element points here) */
Lce9_l:
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
Lce9_r:
    .quad 0                 /* (an operand with no element points here) */
Lce10_l:
Lce10_r:
    .quad 0                 /* (an operand with no element points here) */
    .p2align 3
Lcases:
    .quad Lcne0, ENT_MATMUL, 2, 3, 0, Lce0_l, 2, 0, 2, Lce0_r, 2, 3, 2
    .quad Lcne1, ENT_MATMUL, 2, 1, 0, Lce1_l, 2, 0, 1, Lce1_r, 2, 1, 1
    .quad Lcne2, ENT_MATMUL, 2, 0, 4, Lce2_l, 2, 4, 2, Lce2_r, 2, 0, 2
    .quad Lcne3, ENT_MATMUL, 2, 3, 4, Lce3_l, 2, 4, 0, Lce3_r, 2, 3, 0
    .quad Lcne4, ENT_MATMUL, 2, 0, 0, Lce4_l, 2, 0, 0, Lce4_r, 2, 0, 0
    .quad Lcne5, ENT_GEMV, 2, 3, 0, Lce5_l, 1, 0, 1, Lce5_r, 1, 3, 1
    .quad Lcne6, ENT_GEMV, 2, 0, 4, Lce6_l, 1, 4, 1, Lce6_r, 1, 0, 1
    .quad Lcne7, ENT_GEMV, 2, 0, 0, Lce7_l, 1, 0, 1, Lce7_r, 1, 0, 1
    .quad Lcne8, ENT_VECMAT, 1, 0, 1, Lce8_l, 2, 0, 3, Lce8_r, 1, 3, 1
    .quad Lcne9, ENT_VECMAT, 1, 4, 1, Lce9_l, 2, 4, 0, Lce9_r, 1, 0, 1
    .quad Lcne10, ENT_VECMAT, 1, 0, 1, Lce10_l, 2, 0, 0, Lce10_r, 1, 0, 1
    .quad 0                     /* end of the table */
Lcne0: .asciz "mm 3x0 @ 0x2"
Lcne1: .asciz "mm 1x0 @ 0x1"
Lcne2: .asciz "mm 0x4 @ 4x2"
Lcne3: .asciz "mm 3x4 @ 4x0"
Lcne4: .asciz "mm 0x0 @ 0x0"
Lcne5: .asciz "mv 3x0 @ 0"
Lcne6: .asciz "mv 0x4 @ 4"
Lcne7: .asciz "mv 0x0 @ 0"
Lcne8: .asciz "vm 0 @ 0x3"
Lcne9: .asciz "vm 4 @ 4x0"
Lcne10: .asciz "vm 0 @ 0x0"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lsite_file
    .quad 1
Lsite_file:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "la.sea"
