// sea/tests/rt/arm64_macos/rt_la_gemm_values.s -- sea_gemv, sea_vecmat and sea_matmul on given data (DESIGN.md 2.13.2, 2.13.5, 2.13.6; LANGUAGE.md 10.5, 10.8): GEMV's pinned order (A[0,:] = [1e16, 1, -1e16] with x = [1, 1, 1] is 0), a row of -0 products gives -0, Inf, NaN and 0*Inf, row counts 1, 7, 19, 35 against every panel and tail; VECMAT's pinned 8-lane order with k = 19 on data where it differs from the sequential sum, -0 lanes, non-finite values, k = 1, 7, 8, 13, 16, 23 (tails and none); MATMUL on exact data (1x1, 3x5 @ 5x2, 2x3 @ 3x4 dyadic). Each case: fresh operands of count 1, a dirty freed block of the result's class, then the result's rank, shape and elements (f64 bits, NaN as NaN) and the ownership check (one new object of count 1, the operands' counts and bytes unchanged). The table runs twice, under the first variant of the target (x86_64: sse2) and under the selected one, with the same expected bytes; the heap check ends at 0 live objects. Expected values: DESIGN.md 2.13.2's orders transcribed into binary64 operations.
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
// _sea_main -- the table twice: pass 1 under FIRST_VARIANT, pass 2 under
// the variant main selected. Callee-saved used: x19 (the selected
// variant). Frame 96 bytes.
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x9, _sea_variant
    ldr x19, [x9]               // the selected variant
    mov x10, #FIRST_VARIANT
    str x10, [x9]
    TXT "pass 1\n"
    LA x0, Lcases
    bl Lrun
    LA x9, _sea_variant
    str x19, [x9]               // back to the selected variant
    TXT "pass 2\n"
    LA x0, Lcases
    bl Lrun
    EPILOGUE

    .section __DATA,__const
    .p2align 3
Lcv0_l:
    .quad 0x4341C37937E08000
    .quad 0x3FF0000000000000
    .quad 0xC341C37937E08000
Lcv0_r:
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
Lcv1_l:
    .quad 0x8000000000000000
    .quad 0x0000000000000000
    .quad 0x8000000000000000
    .quad 0x8000000000000000
    .quad 0x8000000000000000
    .quad 0x0000000000000000
Lcv1_r:
    .quad 0x3FF0000000000000
    .quad 0x4000000000000000
    .quad 0x4008000000000000
    .quad 0                 /* (an operand with no element points here) */
Lcv2_l:
    .quad 0x7FF0000000000000
    .quad 0x7FF0000000000000
    .quad 0x7FE1CCF385EBC8A0
    .quad 0x3FF0000000000000
    .quad 0xFFF0000000000000
    .quad 0x7FE1CCF385EBC8A0
Lcv2_r:
    .quad 0x4000000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
Lcv3_l:
    .quad 0x0000000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
Lcv3_r:
    .quad 0x7FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
Lcv4_l:
    .quad 0xBFEBF15F2E283A7F
Lcv4_r:
    .quad 0x400BF1CB64658734
    .quad 0                 /* (an operand with no element points here) */
Lcv5_l:
    .quad 0x4026FB9DB3D1CD2E
    .quad 0xBFAFD082B532EED2
    .quad 0x3FE3E56D36B1060D
    .quad 0x4025CA9BB28B9030
    .quad 0x3F8A6A6862CDCD1E
    .quad 0xC04AC613EEF42956
    .quad 0xBFD8DD4514F9E90C
    .quad 0xBF9BD0F6809BF2A8
    .quad 0xBFF882F1512E77C9
    .quad 0x3F9F017284C5F714
    .quad 0xBF7F739657EFCF1C
    .quad 0x3F5D2ED414E4FA17
    .quad 0xBFABD02EA3A4E75C
    .quad 0xBFA77EC2B7AC855F
    .quad 0xBFBC2564DECF1D3E
    .quad 0xBFDA60DB126A2712
    .quad 0x3FBE5DF4C431DFCC
    .quad 0x3FA49B8AAE4F11B1
    .quad 0x3F54269212C9E77A
    .quad 0xC00D90717DDBB699
    .quad 0xC01BE6F18232DB56
    .quad 0xC0307A8BD6F69C2C
    .quad 0x3F70CD6C5FDAD160
    .quad 0x3F7C0CC842879892
    .quad 0x400A10937386DEFD
    .quad 0x404F28A5EEF2C21C
    .quad 0x40245653B664F689
    .quad 0xBFAC14ACA24CCE4B
    .quad 0xBF77D0985EB7970E
    .quad 0x40211E6DA7774072
    .quad 0x3FF60F295E615B16
    .quad 0x3F73204C59E7B0FB
    .quad 0xBF82DC5C7BDB3B9F
    .quad 0xBFD3201B1C2C9E4A
    .quad 0x4031EE5DCFE2642F
Lcv5_r:
    .quad 0xC046FC09EA0F19E4
    .quad 0xBF987B769E4672D0
    .quad 0x401D9C938583D68D
    .quad 0x403B0FFBCF322A78
    .quad 0xC0103EF38C053CAA
    .quad 0                 /* (an operand with no element points here) */
Lcv6_l:
    .quad 0xBF6205DC397B5FDE
    .quad 0x403CDC75C97320C8
    .quad 0x3F8545FA658F4AB2
    .quad 0x3FD534430EFDDE88
    .quad 0xC017980D9E189879
    .quad 0xBF78D7B444F65545
    .quad 0x3FF80F094D8DE7FE
    .quad 0xC03284B1CC82FAD0
    .quad 0x3FE3EEEF234297CD
    .quad 0x3F7710B44C97FAF2
    .quad 0x3F930CE282F1C751
    .quad 0xC012A4179CEB46C8
    .quad 0xBFB355A8C123B4A0
    .quad 0xC00E86E5705E4C33
    .quad 0x4036B935C04987D7
    .quad 0x3FBC0CA0CDFB526A
    .quad 0x3FAB876CB8580522
    .quad 0xC027B9C5B1CAC0B4
    .quad 0xBFC1431CE11C4661
    .quad 0xC036EEF3C2441C35
    .quad 0x3FD1BCE911688569
    .quad 0xBF87DAAE6D1951E9
    .quad 0xBF668C80238427EB
    .quad 0xBFB9E1ECC082E9B2
    .quad 0x3F96F1BA9F8BA5F4
    .quad 0xBF79E14A4C4B0790
    .quad 0xC0418FBDE33C8C16
    .quad 0x3FFFEDA744ADA7F2
    .quad 0xC014439F8E31C228
    .quad 0x403A461FD0204C2D
    .quad 0x3F55C9420C0E67AD
    .quad 0xC015E94F8A64540D
    .quad 0x3FB80182CC4BFED5
    .quad 0xBFBEE898D46F898C
    .quad 0xBF8DA0DE6B2D4723
    .quad 0xBF8038667307EBA3
    .quad 0x3FB2A0D0DA2410B1
    .quad 0xBFFB030D530C8D42
    .quad 0x3FE473633B3F7912
    .quad 0x3FCE8DE8ECBF655E
    .quad 0xBFCEB5AAFF036ADA
    .quad 0xC0383BFDD2BD352B
    .quad 0x3F8A210E6D73E0BD
    .quad 0x3FE52FD3233B316C
    .quad 0x402CE897A2D05557
    .quad 0x3F6112242E7FE3EB
    .quad 0xBF8DC072732FF08D
    .quad 0x3F58F8E00F0FC208
    .quad 0x403F9C03DD2F6B96
    .quad 0x4043B6C7FCB03D71
    .quad 0x3FFBF14F4F884C97
    .quad 0xBFCB2450F5079BF2
    .quad 0xBF6614A827A002EE
    .quad 0x401E39439D5EAB6E
    .quad 0x402923D9A5DE9514
    .quad 0x3F5508201BD56EF1
    .quad 0xC0484B03EA71F91E
Lcv6_r:
    .quad 0x3F8206486FB8AC94
    .quad 0x40258769B286A4C6
    .quad 0x3FAEFD20B4621B32
    .quad 0                 /* (an operand with no element points here) */
Lcv7_l:
    .quad 0xBFAD101ABF24F28E
    .quad 0xBFB9E868DDB352BD
    .quad 0x4016A687946D8F57
    .quad 0x3F849DEA6B702CDF
    .quad 0x3FB4C5B2D96363D4
    .quad 0xBF96E9549AF88135
    .quad 0xC01740CD8621E6F0
    .quad 0x3FD9386D186A02F7
    .quad 0x3FCF5AECF556B7D0
    .quad 0xBF5F1FF61469FED0
    .quad 0x3FA6A62EADF3BF87
    .quad 0xBFE8195B24F1937A
    .quad 0x3FBADB22DEA281E4
    .quad 0x3F658F0829101306
    .quad 0xBFA14D06A1C3F270
    .quad 0xBF9DB866898C7DC2
    .quad 0x3FA8B0E4AC7E2A78
    .quad 0x3FAAD800B5466FB6
    .quad 0xC02E5FA7AF6EA549
    .quad 0xBF504D7606AC81D1
    .quad 0x3FA792E0A09E2F7D
    .quad 0xBFDF3AD1033C07A6
    .quad 0x404C4B93E72D7E75
    .quad 0x3FE7B7113E7E3AD3
    .quad 0x4033D2E1CB906CEB
    .quad 0x3FA499EEA9A34D04
    .quad 0xBF5EC928101421A2
    .quad 0x4043C6A1E70E8199
    .quad 0xBFA0B6A6BDABED42
    .quad 0xC0436DD1F8C957E7
    .quad 0x3FA5835AB9BB7444
    .quad 0x3FA8B252BAE0F71E
    .quad 0xBFDD26A91CBCC20B
    .quad 0x3F9AB1168CB274CE
    .quad 0xBFD9535F06782A17
    .quad 0x4030E8F3DABA3706
    .quad 0x40160BF3881C6457
    .quad 0x3FAF7092A7C29B1E
    .quad 0xBF64C674264119A0
    .quad 0xBFB44910DA883219
    .quad 0x40335603CEEF1D3E
    .quad 0x3FDB384704E04BA7
    .quad 0x3F53022613B1D8AB
    .quad 0x3FFCA9915CFB30CB
    .quad 0x402F1983A6C6F660
    .quad 0x40330F2DC1E8571E
    .quad 0x3FBA66CCC25E20CC
    .quad 0x3FDAE4EF1589FDB6
    .quad 0x403E3551D3F4B266
    .quad 0xBFFE343D43B10CA3
    .quad 0x40310C53D7F27BE1
    .quad 0x3FC4A2E2EF43B81C
    .quad 0x401B8F5198574D81
    .quad 0x400F66436BC3503C
    .quad 0xBF584F520866B88E
    .quad 0x3FDADAB117F9CE69
    .quad 0xBFF6B39F498285E9
    .quad 0x3F90CA148D581958
    .quad 0xBF96A86C88CEA6BF
    .quad 0x4001F38D72F4A0AF
    .quad 0xBFAA4F00AB9CEC5F
    .quad 0x3FE6E4052B10D94C
    .quad 0xC01B1B1D8C1D9C29
    .quad 0x3FA9A906A48D4B27
    .quad 0xBF6A7198235DFCAA
    .quad 0xBFD10DE1114949D8
    .quad 0xC02D6F9DA97940C8
    .quad 0xBFE3183728AF18B6
    .quad 0x4013E285871CBE1C
    .quad 0x403E2D8FC1C923A1
    .quad 0xBFE864552C802361
    .quad 0x404D6F2DE16B1D64
    .quad 0x3FFECA4954E76C0D
    .quad 0xC03C00A5C5043CB7
    .quad 0x4041BD95ED309601
    .quad 0x3FCFD808E87078E5
    .quad 0xBFC0A3A2E224A65E
    .quad 0xBFE1C6CB3AFF8F10
    .quad 0xBFED933F2EE4527B
    .quad 0xBFFBD22F5663C114
    .quad 0xC038469BC046A9F6
    .quad 0x3FFA99475A59A70A
    .quad 0xBF82C57E741D66EC
    .quad 0x3FBD1044CDB81472
    .quad 0xBF96408E99A11147
    .quad 0x3F731FD256DCF9ED
    .quad 0x4041C071F7A8EA39
    .quad 0xBF51FF1A0BD454AA
    .quad 0x3FE6B4FB39799CC9
    .quad 0xC03A31A5D26AA465
    .quad 0xC034D9BFDAE3F88E
    .quad 0xBFEF04D13AF7090E
    .quad 0x403A9CE9D2F4837D
    .quad 0x3F8DD0106AF4110B
    .quad 0x3FB39430DCB777E0
    .quad 0xBF85ED366173691A
    .quad 0xBFC167CAF384CB6B
    .quad 0x3F968B4296A206DC
    .quad 0xC03C4073DD27246C
    .quad 0x402166D9BF8A0EF0
    .quad 0x3F8C624667112A23
    .quad 0xC02C6A77B42F9FBF
    .quad 0xBF7E061256186535
    .quad 0xBFFC8B435C47D1DA
    .quad 0xBFA4C940B605ED3E
    .quad 0xBF878D6A68E7A702
    .quad 0x401B888B933D6889
    .quad 0xBFD1C047137D48CA
    .quad 0xBF77A4DC58146ADD
    .quad 0x404F6909FF9ADFDC
    .quad 0x4014541798D9087B
    .quad 0xBF73291C530974DC
    .quad 0x3FF1C02141687A28
    .quad 0xBFC2AD60E44DB3EC
    .quad 0x3F9CD6EA9B57F768
    .quad 0x3F56D76C045A13D1
    .quad 0xC015AFF39BA473CF
    .quad 0x3F85760A7743C9B7
    .quad 0xBF8E148A7083B476
    .quad 0xBF55B23C082C1A94
    .quad 0xBF7CF0C24FFC3A8C
    .quad 0x3FADFF26AF78032D
    .quad 0xBFB93E20C65BC80F
    .quad 0x3FBA127ED63ED7B8
    .quad 0xBFD4DE010C4FCB9E
    .quad 0x3FFFF03148776424
    .quad 0xC04BCB63F369C86A
    .quad 0xBF8CA01668D43DF7
    .quad 0x40223EC9AA2DD74E
    .quad 0xC044AEC3E9FD60DA
    .quad 0xBF639A2628ACA601
    .quad 0xBFF642ED4480D6B4
    .quad 0xBFB6FAA8DC2EE16C
    .quad 0xBFB45AC0C0981476
    .quad 0xC0078FCD75FFC01B
    .quad 0xBFF0D3D34FF5DC79
    .quad 0xBFB1007CCC2169D2
    .quad 0xC0311E25C602DF86
    .quad 0x3FA252A8B72A4143
    .quad 0x3FC69DECF517FD79
Lcv7_r:
    .quad 0x3FCD1086F5623F44
    .quad 0xBFB2935CC6C6D6BB
    .quad 0xC0405DADE3405FD7
    .quad 0x3F99E34A8816C727
    .quad 0                 /* (an operand with no element points here) */
Lcv8_l:
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
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
Lcv8_r:
    .quad 0x4341C37937E08000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0xC341C37937E08000
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
    .quad 0x0000000000000000
    .quad 0x3FB999999999999A
    .quad 0x3FC999999999999A
    .quad 0x3FD3333333333333
    .quad 0x3FD999999999999A
    .quad 0x3FE0000000000000
    .quad 0x3FE3333333333333
    .quad 0x3FE6666666666666
    .quad 0x3FE999999999999A
    .quad 0x3FECCCCCCCCCCCCD
    .quad 0x3FF0000000000000
    .quad 0x3FF199999999999A
    .quad 0x3FF3333333333333
    .quad 0x3FF4CCCCCCCCCCCD
    .quad 0x3FF6666666666666
    .quad 0x3FF8000000000000
    .quad 0x3FF999999999999A
    .quad 0x3FFB333333333333
    .quad 0x3FFCCCCCCCCCCCCD
    .quad 0                 /* (an operand with no element points here) */
Lcv9_l:
    .quad 0x3FF0000000000000
Lcv9_r:
    .quad 0x8000000000000000
    .quad 0x0000000000000000
    .quad 0                 /* (an operand with no element points here) */
Lcv10_l:
    .quad 0xBFF0000000000000
    .quad 0x4000000000000000
Lcv10_r:
    .quad 0x0000000000000000
    .quad 0x8000000000000000
    .quad 0                 /* (an operand with no element points here) */
Lcv11_l:
    .quad 0x7FF0000000000000
    .quad 0x3FF0000000000000
Lcv11_r:
    .quad 0x0000000000000000
    .quad 0x4014000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
Lcv12_l:
    .quad 0x3F8A57D066C7F55E
Lcv12_r:
    .quad 0xBF9A583C9D054213
    .quad 0                 /* (an operand with no element points here) */
Lcv13_l:
    .quad 0xBFC5620EEC71880D
    .quad 0x400248017FB4E26B
    .quad 0xBFD1AAF10B5FB480
    .quad 0xBFFFEB254F029F9D
    .quad 0x3FAE32DCB3B9BEAC
    .quad 0x3FF776574B09E0AF
    .quad 0xBFF0CEEF4AC1DE7E
Lcv13_r:
    .quad 0x3FE5627B22AED4C3
    .quad 0xC00AF2F568C86669
    .quad 0xBFFB62175A328500
    .quad 0x400530856BA939E5
    .quad 0xC0340767DCF12E38
    .quad 0x3FC658F8E3E30A2A
    .quad 0x40003F95649174F0
    .quad 0xBFDD0B711DE173B1
    .quad 0x4010EA0195D43963
    .quad 0x3F858FB66103A079
    .quad 0x3FBB5250D2C875EA
    .quad 0x3F9591D88799EE6C
    .quad 0xBFF72AA750211A9D
    .quad 0xBF5CFDAE140FF464
    .quad 0x4037A925C168EAFB
    .quad 0xC0222FD1AACAC6CA
    .quad 0xC0262F7FAC95EAC6
    .quad 0xBF6B98E62D7444E1
    .quad 0x3FA66A36BA2EAEF6
    .quad 0x3FC42C6AE2B75FA5
    .quad 0xBFDDD7510B41EFC8
    .quad 0                 /* (an operand with no element points here) */
Lcv14_l:
    .quad 0x40006C4D721B1ABD
    .quad 0x3F9F53F493F51461
    .quad 0xBF630B7E3A3DF925
    .quad 0xBFAF54CCAB74EDF5
    .quad 0xC04B6081EF048A07
    .quad 0x402587F7A10C0C9E
    .quad 0x401000B38355DD70
    .quad 0xBFB58A02C3894C5C
Lcv14_r:
    .quad 0xC0206CB9A8586773
    .quad 0x3F87FEE87D08985F
    .quad 0xBF9CC2A48910C9A5
    .quad 0x3FB49A2CC81B883D
    .quad 0x3FD1350D183BF993
    .quad 0x3FE46A9939E53619
    .quad 0x401F71599D2573E2
    .quad 0xBF83BF2C69C87BD8
    .quad 0x400C55FF67E85966
    .quad 0xBF6D9EF828D5A457
    .quad 0x3FCEEB9CFDCA6E1F
    .quad 0x3F5B071C0FA03B1E
    .quad 0x400EB0216D9FE7E1
    .quad 0x3FB405D0CCC1BB37
    .quad 0xBFA23CF6A2E35594
    .quad 0x4003DB97665BF222
    .quad 0                 /* (an operand with no element points here) */
Lcv15_l:
    .quad 0x404B768BF7C4AD6D
    .quad 0xC02C5FE7A8354657
    .quad 0xC0046C0B691C3DCB
    .quad 0xBF5EBE7407E73C4D
    .quad 0x3FE88E272A4F5562
    .quad 0x40439997F70E388E
    .quad 0x402F3277BBE9DC62
    .quad 0x3F5C3DBE0F705484
    .quad 0x3FE192D72A1FF7F6
    .quad 0x404FB887E29E257C
    .quad 0x3F7AA3285C077199
    .quad 0x3F8EADFE7530926A
    .quad 0xBF5611E80596868D
Lcv15_r:
    .quad 0xBF6B76F82E01FA23
    .quad 0xC0150ADB9148CA55
    .quad 0xC02E2331B7EF0E4A
    .quad 0x3F6403D4248DD695
    .quad 0x3F7E62B25386C4EE
    .quad 0x40127C398FE76209
    .quad 0xC03EA31DD5B972D4
    .quad 0x402A72E7B5AF8400
    .quad 0xBFE7C1FD39FC796A
    .quad 0xC045AE39F0A7A835
    .quad 0xBFE284E928CC6655
    .quad 0xC0107C5F97A687CF
    .quad 0x4016359B8B1EB525
    .quad 0x401B0DF38573820B
    .quad 0xC01CD0C7845DC02D
    .quad 0xBFE5875D21ED1D7A
    .quad 0xC010826F94E23572
    .quad 0x3F61D55C346BA2E7
    .quad 0x3F70A34C56D36CC5
    .quad 0xC006E96F6B882ADE
    .quad 0x3F69834029AD43EF
    .quad 0x401A89AD86261ECA
    .quad 0x40446611F9F0AE0D
    .quad 0xC0094CBF607B16C1
    .quad 0x3FAC91B6B59DEB00
    .quad 0xBFBFF08EC59124E0
    .quad 0x3FFD74C754B663FF
    .quad 0x402B0253ACAC0753
    .quad 0x3FEA23BD242A7251
    .quad 0x40027C5F716C61FA
    .quad 0x3FF779F55A16DD1A
    .quad 0xC01B11B1906F08AA
    .quad 0xC0231D1FAD30A356
    .quad 0xC02AD71BB9738B14
    .quad 0x403006A1C0A5AEE7
    .quad 0x3F8CC5B669569B45
    .quad 0xBF7E14DA48D055CD
    .quad 0xBFD67FDD0DFC8FCF
    .quad 0xBFE877B920F41677
    .quad 0                 /* (an operand with no element points here) */
Lcv16_l:
    .quad 0xBF8680CA7D6E401D
    .quad 0x3FA96BDABC75784D
    .quad 0xBF95CC9897FA8270
    .quad 0xC00E281B64598AA5
    .quad 0xBF85BBCC659A20BD
    .quad 0x3F71AB384D10647D
    .quad 0xC04E643BF47DDB53
    .quad 0x3FF2F1795B575CAB
    .quad 0x3FCCFED4FC3417F9
    .quad 0x4027C7C9AA70295A
    .quad 0x3F9E3C74870969CE
    .quad 0xC0442341FD36DF1C
    .quad 0x3F6D9762231553D1
    .quad 0xBF52E88618B39E21
    .quad 0x3F75A70052068703
    .quad 0x401019E598C95A87
Lcv16_r:
    .quad 0x3FA68136B3AB8CD3
    .quad 0x3FA216CEA588FC4A
    .quad 0xBFCF83BEE6CD52F0
    .quad 0x40136D7B810024ED
    .quad 0xC01B90578ED19049
    .quad 0x40408DD9E5E98DF8
    .quad 0x3F5DD4E20E4D71C6
    .quad 0x3FD126A301968C27
    .quad 0x3FD32DFB0C10996E
    .quad 0x402DBD7BB879AC13
    .quad 0xBFF61E3553CE5E8A
    .quad 0xBFD5F1A31FACD481
    .quad 0xC02DBB15A89D8269
    .quad 0xBF6216163E2548DF
    .quad 0x3F87649865D82AC6
    .quad 0x3FB73322DD7E48D2
    .quad 0x401DABE789085AC8
    .quad 0xBFE4F39737E751EA
    .quad 0x3FEDBFD72525CBAC
    .quad 0xC02047F1AFF0907A
    .quad 0x402F5937B8E2EE03
    .quad 0xBF51E9D01C48D487
    .quad 0xC02A2525BD9A0498
    .quad 0x403721E3DE7667E2
    .quad 0x404972DDE1A2B1F7
    .quad 0x3FEAA93322E96A54
    .quad 0xC01AAE31818DF98B
    .quad 0xBF7EDB4E4F0CE0FA
    .quad 0x3F7696C453A49D6A
    .quad 0x401BA4119A156DB5
    .quad 0x3F57340E07C3E9B1
    .quad 0x3FBDDAB4C0EBABBC
    .quad 0                 /* (an operand with no element points here) */
Lcv17_l:
    .quad 0x3FD18B090317D2CD
    .quad 0xC03677CDD0B5AA42
    .quad 0xC0372D25C6D8C715
    .quad 0xBFBD91C2C0CBD8FC
    .quad 0x4022E971A0E4EC18
    .quad 0xBFAFBCD8A312906C
    .quad 0x3F6D96002D11DA45
    .quad 0xBFA9A534A73E64D3
    .quad 0xBFB86AD2CE4837FD
    .quad 0xC00FD70B72422D38
    .quad 0xBFA1D5C0B20B6203
    .quad 0xC0199885853D2BCE
    .quad 0x3F751CDC40942115
    .quad 0xBFB9F0A8D16564F4
    .quad 0xBFE03AD13380F19C
    .quad 0xBFF1C5AB545A85DF
    .quad 0x3F56A2841E47EA81
    .quad 0xBFB042C4DF12A3D8
    .quad 0xBFFBB6295B4B1823
    .quad 0x3FE0BB913B914522
    .quad 0x3FFD9A7B57222869
    .quad 0xBF57BC700CDC8C80
    .quad 0xBFD14081131D8CF6
Lcv17_r:
    .quad 0xBFE18B7539551F83
    .quad 0x402F22C1B9C92E40
    .quad 0x3F50E44C15AB9795
    .quad 0x3FB2D722DD727344
    .quad 0x3FB8BDFCCA1C5BA4
    .quad 0xBF6E9F7A3BEBB9E7
    .quad 0xBF7D06A646E170B8
    .quad 0xBF77DA5E4D7D944F
    .quad 0x3FBE99F8DE24B971
    .quad 0x4015CCBD804BAFF1
    .quad 0xC009B7817ED056BF
    .quad 0xBFAB66E6A7B32133
    .quad 0xC035408FC61C4FAD
    .quad 0xBFC91E38F6D70FB3
    .quad 0xBFF1F8694752955F
    .quad 0xBF98DEE8990F7429
    .quad 0x400AD55F7D2E801E
    .quad 0x3F6811D23B6300ED
    .quad 0xC04ADC61F3782A94
    .quad 0x4049A673F458F616
    .quad 0xBFF52F2F48189816
    .quad 0xBFA949F2B26B8A44
    .quad 0x401FE43981435B23
    .quad 0xBF74F7085C71B902
    .quad 0x3FD654050DA778ED
    .quad 0xC01561D78041AFC8
    .quad 0x4027E79BAE658F18
    .quad 0xBFC2B448F16DBAA1
    .quad 0x401309CB831EC884
    .quad 0xC034CBC3C2BE796F
    .quad 0x3FA6EE26B570F648
    .quad 0x4040A3B7F1684ECE
    .quad 0xBF7D676C4E1229C3
    .quad 0xBFE2681729F96197
    .quad 0xBFC76BA2F73B74CF
    .quad 0x3FEE26D138BB3209
    .quad 0x4024EB1FA4C0FD1A
    .quad 0xC02F5AE7B768AB88
    .quad 0xBFC91DDAF6F75792
    .quad 0xBFC62A88E261C400
    .quad 0x3FB97CDEC60D2902
    .quad 0xBFC9984CF43A21EE
    .quad 0x3FB57C7ECECE50BE
    .quad 0xBFA1ECCAA0FAEA02
    .quad 0x400480C562AD6A7C
    .quad 0x3F61C35E3F9ABD62
    .quad 0xC0032E4F66933C46
    .quad 0x40422B81EB04198C
    .quad 0xC031476DCA43AD8F
    .quad 0xBF75178C540BB2E1
    .quad 0xC01CDE4F86672C67
    .quad 0x3F8C02C069900AC0
    .quad 0xBFC13972E887EDCE
    .quad 0xC023162DB7CB6A51
    .quad 0xBFEB53FD23F63E26
    .quad 0xC006FA1F67E392E8
    .quad 0x3FC47798E0C01ECF
    .quad 0xBFBDC712DFC0DD03
    .quad 0x3F721A3A4A38B5D0
    .quad 0xBFCC2104F40B26F6
    .quad 0x3FCA6860E8459CB4
    .quad 0x3F7B887C463FDC2B
    .quad 0xC01C0C85816CE378
    .quad 0x3FD3BBEB1CA38605
    .quad 0x3FC6061EEBE0A4A4
    .quad 0x40441A73FF64BF68
    .quad 0x3FC603FCEF464F7C
    .quad 0xBFCECA0EE6B80BD9
    .quad 0xBF55C618174A5552
    .quad 0x3FFFF1B553ADFB42
    .quad 0x3FF558594E16AEFF
    .quad 0x3FF730175FC12B5A
    .quad 0xC01687C98A2DB774
    .quad 0xBF5C818606E21FA6
    .quad 0x3F9DED369CFD206F
    .quad 0xBF6B51383B75911C
    .quad 0xC04AADBFEA884E4C
    .quad 0xBFDECED31538BE6A
    .quad 0xBFB611B4D2F02FFF
    .quad 0x40490FEDE3486DD9
    .quad 0xBFEA25752152B022
    .quad 0xBFF97CA94324B9CF
    .quad 0xBF640D8C32BF242D
    .quad 0x3F866A34661768F4
    .quad 0xC04BE29BEBE1A6C7
    .quad 0x3FB31F4AC5067AF9
    .quad 0xBFCB9174E6EF123C
    .quad 0xC00B965379B2BAF7
    .quad 0x3F56185412785812
    .quad 0x3FC37706EB749077
    .quad 0xBF94BF5A91A03ABA
    .quad 0xBF8722C66591F015
    .quad 0x401D57D18B0BF665
    .quad 0x3F5A18A60EB134C1
    .quad 0xBFF6E2F946702DFA
    .quad 0x3F7D47C05E2FD2A7
    .quad 0xBF993C909E417928
    .quad 0xBF76D9E0504B3CB3
    .quad 0x3FE8D2C53A95389A
    .quad 0xBF6996F03B2FFDB2
    .quad 0xC03B54F5D435DD4C
    .quad 0xBFD5A6251CD0EE16
    .quad 0xBFE59999223797FE
    .quad 0xC0295A77AF98975E
    .quad 0x3FDB1E1F06A96DC9
    .quad 0x3F50A59608E33E17
    .quad 0xBFCC23BCF954F6D2
    .quad 0x3FC0B4A2EB12B380
    .quad 0x3FCBF860FEAE941F
    .quad 0xBF97DB7A9CDFF7CD
    .quad 0x3FA85D40A242B18A
    .quad 0xBFC0E320F54BDE10
    .quad 0x3F956AE88504B0D7
    .quad 0xBFFD7C5348C14AB7
    .quad 0x3F9E16389C2B62E4
    .quad 0                 /* (an operand with no element points here) */
Lcv18_l:
    .quad 0x4008000000000000
Lcv18_r:
    .quad 0x4010000000000000
    .quad 0                 /* (an operand with no element points here) */
Lcv19_l:
    .quad 0xC000000000000000
    .quad 0x4014000000000000
    .quad 0x3FF0000000000000
    .quad 0xC008000000000000
    .quad 0x4010000000000000
    .quad 0x0000000000000000
    .quad 0xC010000000000000
    .quad 0x4008000000000000
    .quad 0xBFF0000000000000
    .quad 0xC014000000000000
    .quad 0x4000000000000000
    .quad 0xC000000000000000
    .quad 0x4014000000000000
    .quad 0x3FF0000000000000
    .quad 0xC008000000000000
Lcv19_r:
    .quad 0xC008000000000000
    .quad 0x4000000000000000
    .quad 0xC000000000000000
    .quad 0x4008000000000000
    .quad 0xBFF0000000000000
    .quad 0x4010000000000000
    .quad 0x0000000000000000
    .quad 0xC010000000000000
    .quad 0x3FF0000000000000
    .quad 0xC008000000000000
    .quad 0                 /* (an operand with no element points here) */
Lcv20_l:
    .quad 0x3FE0000000000000
    .quad 0xBFD0000000000000
    .quad 0x4000000000000000
    .quad 0x3FF8000000000000
    .quad 0xC008000000000000
    .quad 0x3FC0000000000000
Lcv20_r:
    .quad 0x3FF0000000000000
    .quad 0x4000000000000000
    .quad 0xBFE0000000000000
    .quad 0x4010000000000000
    .quad 0x3FD0000000000000
    .quad 0xBFF0000000000000
    .quad 0x4020000000000000
    .quad 0xC000000000000000
    .quad 0x3FE0000000000000
    .quad 0x4008000000000000
    .quad 0xC010000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
    .p2align 3
Lcases:
    .quad Lcnv0, ENT_GEMV, 2, 1, 3, Lcv0_l, 1, 3, 1, Lcv0_r, 1, 1, 1
    .quad Lcnv1, ENT_GEMV, 2, 2, 3, Lcv1_l, 1, 3, 1, Lcv1_r, 1, 2, 1
    .quad Lcnv2, ENT_GEMV, 2, 3, 2, Lcv2_l, 1, 2, 1, Lcv2_r, 1, 3, 1
    .quad Lcnv3, ENT_GEMV, 2, 2, 2, Lcv3_l, 1, 2, 1, Lcv3_r, 1, 2, 1
    .quad Lcnv4, ENT_GEMV, 2, 1, 1, Lcv4_l, 1, 1, 1, Lcv4_r, 1, 1, 1
    .quad Lcnv5, ENT_GEMV, 2, 7, 5, Lcv5_l, 1, 5, 1, Lcv5_r, 1, 7, 1
    .quad Lcnv6, ENT_GEMV, 2, 19, 3, Lcv6_l, 1, 3, 1, Lcv6_r, 1, 19, 1
    .quad Lcnv7, ENT_GEMV, 2, 35, 4, Lcv7_l, 1, 4, 1, Lcv7_r, 1, 35, 1
    .quad Lcnv8, ENT_VECMAT, 1, 19, 1, Lcv8_l, 2, 19, 2, Lcv8_r, 1, 2, 1
    .quad Lcnv9, ENT_VECMAT, 1, 1, 1, Lcv9_l, 2, 1, 2, Lcv9_r, 1, 2, 1
    .quad Lcnv10, ENT_VECMAT, 1, 2, 1, Lcv10_l, 2, 2, 1, Lcv10_r, 1, 1, 1
    .quad Lcnv11, ENT_VECMAT, 1, 2, 1, Lcv11_l, 2, 2, 2, Lcv11_r, 1, 2, 1
    .quad Lcnv12, ENT_VECMAT, 1, 1, 1, Lcv12_l, 2, 1, 1, Lcv12_r, 1, 1, 1
    .quad Lcnv13, ENT_VECMAT, 1, 7, 1, Lcv13_l, 2, 7, 3, Lcv13_r, 1, 3, 1
    .quad Lcnv14, ENT_VECMAT, 1, 8, 1, Lcv14_l, 2, 8, 2, Lcv14_r, 1, 2, 1
    .quad Lcnv15, ENT_VECMAT, 1, 13, 1, Lcv15_l, 2, 13, 3, Lcv15_r, 1, 3, 1
    .quad Lcnv16, ENT_VECMAT, 1, 16, 1, Lcv16_l, 2, 16, 2, Lcv16_r, 1, 2, 1
    .quad Lcnv17, ENT_VECMAT, 1, 23, 1, Lcv17_l, 2, 23, 5, Lcv17_r, 1, 5, 1
    .quad Lcnv18, ENT_MATMUL, 2, 1, 1, Lcv18_l, 2, 1, 1, Lcv18_r, 2, 1, 1
    .quad Lcnv19, ENT_MATMUL, 2, 3, 5, Lcv19_l, 2, 5, 2, Lcv19_r, 2, 3, 2
    .quad Lcnv20, ENT_MATMUL, 2, 2, 3, Lcv20_l, 2, 3, 4, Lcv20_r, 2, 2, 4
    .quad 0                     /* end of the table */
Lcnv0: .asciz "mv order"
Lcnv1: .asciz "mv negzero"
Lcnv2: .asciz "mv nonfinite"
Lcnv3: .asciz "mv zero inf"
Lcnv4: .asciz "mv 1x1"
Lcnv5: .asciz "mv 7x5"
Lcnv6: .asciz "mv 19x3"
Lcnv7: .asciz "mv 35x4"
Lcnv8: .asciz "vm order"
Lcnv9: .asciz "vm negzero"
Lcnv10: .asciz "vm negzero2"
Lcnv11: .asciz "vm nonfinite"
Lcnv12: .asciz "vm 1x1"
Lcnv13: .asciz "vm 7x3"
Lcnv14: .asciz "vm 8x2"
Lcnv15: .asciz "vm 13x3"
Lcnv16: .asciz "vm 16x2"
Lcnv17: .asciz "vm 23x5"
Lcnv18: .asciz "mm 1x1"
Lcnv19: .asciz "mm 3x5x2"
Lcnv20: .asciz "mm 2x3x4"
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
