// sea/tests/rt/arm64_macos/rt_la_gemm_sweep.s -- GEMV and VECMAT bit for bit against the pinned orders of DESIGN.md 2.13.2 (LANGUAGE.md 10.5, 10.8) for every pair of extents 0 .. 33 (r, k for GEMV, k, c for VECMAT: every panel, pair and tail of every variant, empty operands included), on LCG data with about 0.1-0.2% each of +-0, +-Inf, NaN with payloads and subnormals among normal numbers of exponents -15 .. 16; and MATMUL on exact integer data (70x40 @ 40x65, 33x17 @ 17x9, 1x64 @ 64x1, 64x1 @ 1x64). Each sweep prints a 64-bit FNV-1a-style hash of the extents and result bits (a NaN folded as #7FF8000000000000, its bits not being observable); the hashes are those of a binary64 transcription of the pinned orders. Pass 1 runs under the first variant of the target (x86_64: sse2), pass 2 under the selected one (x86_64: avx2 on an AVX2 host), so equal lines show the forms bit-identical; the arm64 NEON form prints the same bytes. Heap check: 0 live objects.
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

// ---- the sweep --------------------------------------------------------
// The data: the 64-bit LCG s = s * 6364136223846793005 + 1442695040888963407
// from SEED; one value per step from u = s: cat = u >> 54; sign = bit 53;
// m = u's low 52 bits; cat 0: +0, 1: -0, 2: +Inf, 3: -Inf, 4: the quiet
// NaN #7FF8000000000000 | (u & #FFFF), 5: a subnormal (sign, m), else a
// normal number with the exponent 1008 + bits 47..51 (sign, m). The
// exact GEMM data: (u >> 59) - 16 as an f64 (-16 .. 15).
// The hash: h = #CBF29CE484222325; fold(b): h = (h XOR b) * #100000001B3
// (mod 2^64); each case folds its outer extent, then every result
// element's bits, a NaN as #7FF8000000000000 (NaN bits are not
// observable, LANGUAGE.md 6.5).
.equ SEED, 0x5EA0000000000853
.equ LCG_A, 6364136223846793005
.equ LCG_C, 1442695040888963407
.equ FNV0, 0xCBF29CE484222325
.equ FNVP, 0x100000001B3
.equ MAXN, 34                       /* extents 0 .. 33 */

    .section __DATA,__data
    .p2align 3
Lstate: .quad 0
    .section __TEXT,__text,regular,pure_instructions

// Lstep -- one LCG step. Outputs: x0 = u. Clobbers x9-x12. Leaf.
    .p2align 2
Lstep:
    LA x9, Lstate
    ldr x10, [x9]
    LI x11, LCG_A
    LI x12, LCG_C
    madd x10, x10, x11, x12
    str x10, [x9]
    mov x0, x10
    ret

// Lval -- the next value's bits (see above). Outputs: x0. Clobbers
// x0-x15. Frame 16 bytes.
    .p2align 2
Lval:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl Lstep
    lsr x11, x0, #54                // cat
    ubfx x12, x0, #53, #1           // sign
    lsl x12, x12, #63
    and x13, x0, #0x000FFFFFFFFFFFFF   // m
    cmp x11, #5
    b.hi 6f
    adr x14, 1f
    add x14, x14, x11, lsl #3       // two instructions per case
    br x14
1:  mov x0, #0                      // 0: +0
    b 9f
    mov x0, #0x8000000000000000     // 1: -0
    b 9f
    mov x0, #0x7FF0000000000000     // 2: +Inf
    b 9f
    mov x0, #0xFFF0000000000000     // 3: -Inf
    b 9f
    and x0, x0, #0xFFFF             // 4: a quiet NaN with a payload
    b 5f
    orr x0, x12, x13                // 5: a subnormal
    b 9f
5:  mov x9, #0x7FF8000000000000
    orr x0, x0, x9
    b 9f
6:  ubfx x14, x0, #47, #5           // a normal number
    add x14, x14, #1008
    orr x0, x12, x13
    orr x0, x0, x14, lsl #52
9:  ldp x29, x30, [sp], #16
    ret

// Lival -- the next exact GEMM value (an f64 -16 .. 15) in x0's bits.
// Clobbers x0-x12, d0. Frame 16 bytes.
    .p2align 2
Lival:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl Lstep
    lsr x0, x0, #59
    sub x0, x0, #16
    scvtf d0, x0
    fmov x0, d0
    ldp x29, x30, [sp], #16
    ret

// Lfold -- h = (h XOR b) * FNVP. Inputs: x0 = h, x1 = b. Outputs: x0.
// Clobbers x9. Leaf.
    .p2align 2
Lfold:
    eor x0, x0, x1
    LI x9, FNVP
    mul x0, x0, x9
    ret

// Lfill -- a new dynamic f64 array (count 1) filled from a value routine.
//   Inputs  : x0 = rank, x1 = rows, x2 = cols, x3 = Lval or Lival
//   Outputs : x0 = the array
//   Clobbers: x0-x17, d0
//   Callee-saved used: x19 = the routine, x20 = the array, x21 = cursor,
//             x22 = elements left. Frame 48 bytes.
    .p2align 2
Lfill:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x3
    mov x3, x2
    mov x2, x1
    mov x1, x0
    mov x0, #SEA_EK_F64
    mov x4, #0
    bl _sea_arr_new_u
    mov x20, x0
    ldr x21, [x20, #SEA_ARR_DATA]
    ldr x9, [x20, #SEA_ARR_ROWS]
    ldr x10, [x20, #SEA_ARR_COLS]
    mul x22, x9, x10
1:  cbz x22, 2f
    blr x19
    str x0, [x21], #8               // column-major, in generation order
    sub x22, x22, #1
    b 1b
2:  mov x0, x20
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Lfoldres -- fold the outer extent, then every element (NaN canonical).
//   Inputs  : x0 = h, x1 = the extent, x2 = the result array
//   Outputs : x0 = h
//   Clobbers: x0-x15. Callee-saved used: x19 = h, x20 = cursor,
//             x21 = elements left. Frame 32 bytes + 16.
    .p2align 2
Lfoldres:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x20, x2
    bl Lfold                        // the extent
    mov x19, x0
    ldr x9, [x20, #SEA_ARR_ROWS]
    ldr x10, [x20, #SEA_ARR_COLS]
    mul x21, x9, x10
    ldr x20, [x20, #SEA_ARR_DATA]
1:  cbz x21, 3f
    ldr x1, [x20], #8
    lsl x9, x1, #1                  // a NaN: above +Inf without the sign
    mov x10, #0xFFE0000000000000
    cmp x9, x10
    b.ls 2f
    mov x1, #0x7FF8000000000000     // canonical
2:  mov x0, x19
    bl Lfold
    mov x19, x0
    sub x21, x21, #1
    b 1b
3:  mov x0, x19
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Lsweep_mv -- GEMV for every r, k in 0 .. 33 (A then x from the LCG).
//   Outputs : x0 = the hash
//   Callee-saved used: x19 = r, x20 = k, x21 = A, x22 = x, x23 = y,
//             x24 = h. Frame 96 bytes.
    .p2align 2
Lsweep_mv:
    PROLOGUE
    LA x9, Lstate
    LI x10, SEED
    str x10, [x9]
    LI x24, FNV0
    mov x19, #0
1:  mov x20, #0
2:  mov x0, #2                      // A: r x k
    mov x1, x19
    mov x2, x20
    adr x3, Lval
    bl Lfill
    mov x21, x0
    mov x0, #1                      // x: k
    mov x1, x20
    mov x2, #1
    adr x3, Lval
    bl Lfill
    mov x22, x0
    mov x0, x21
    mov x1, x22
    mov x2, #0
    bl _sea_gemv
    mov x23, x0
    mov x0, x24
    mov x1, x19
    mov x2, x23
    bl Lfoldres
    mov x24, x0
    REL x23
    REL x21
    REL x22
    add x20, x20, #1
    cmp x20, #MAXN
    b.lo 2b
    add x19, x19, #1
    cmp x19, #MAXN
    b.lo 1b
    mov x0, x24
    EPILOGUE

// Lsweep_vm -- VECMAT for every k, c in 0 .. 33 (x then A).
//   Outputs : x0 = the hash
//   Callee-saved used: x19 = k, x20 = c, x21 = x, x22 = A, x23 = y,
//             x24 = h. Frame 96 bytes.
    .p2align 2
Lsweep_vm:
    PROLOGUE
    LA x9, Lstate
    LI x10, SEED
    str x10, [x9]
    LI x24, FNV0
    mov x19, #0
1:  mov x20, #0
2:  mov x0, #1                      // x: k
    mov x1, x19
    mov x2, #1
    adr x3, Lval
    bl Lfill
    mov x21, x0
    mov x0, #2                      // A: k x c
    mov x1, x19
    mov x2, x20
    adr x3, Lval
    bl Lfill
    mov x22, x0
    mov x0, x21
    mov x1, x22
    mov x2, #0
    bl _sea_vecmat
    mov x23, x0
    mov x0, x24
    mov x1, x20
    mov x2, x23
    bl Lfoldres
    mov x24, x0
    REL x23
    REL x21
    REL x22
    add x20, x20, #1
    cmp x20, #MAXN
    b.lo 2b
    add x19, x19, #1
    cmp x19, #MAXN
    b.lo 1b
    mov x0, x24
    EPILOGUE

// Lsweep_mm -- MATMUL on exact integer data, the shapes of Lmm_shapes.
//   Outputs : x0 = the hash
//   Callee-saved used: x19 = the shape record, x21 = A, x22 = B,
//             x23 = C, x24 = h. Frame 96 bytes.
    .p2align 2
Lsweep_mm:
    PROLOGUE
    LA x9, Lstate
    LI x10, SEED
    str x10, [x9]
    LI x24, FNV0
    LA x19, Lmm_shapes
1:  ldr x9, [x19]
    cbz x9, 2f
    mov x0, #2                      // A: r x k
    ldr x1, [x19]
    ldr x2, [x19, #8]
    adr x3, Lival
    bl Lfill
    mov x21, x0
    mov x0, #2                      // B: k x c
    ldr x1, [x19, #8]
    ldr x2, [x19, #16]
    adr x3, Lival
    bl Lfill
    mov x22, x0
    mov x0, x21
    mov x1, x22
    mov x2, #0
    bl _sea_matmul
    mov x23, x0
    ldr x9, [x19]
    ldr x10, [x19, #16]
    mul x1, x9, x10                 // the extent: r * c
    mov x0, x24
    mov x2, x23
    bl Lfoldres
    mov x24, x0
    REL x23
    REL x21
    REL x22
    add x19, x19, #24
    b 1b
2:  mov x0, x24
    EPILOGUE

    .section __DATA,__const
    .p2align 3
Lmm_shapes:                         // r, k, c
    .quad 70, 40, 65
    .quad 33, 17, 9
    .quad 1, 64, 1
    .quad 64, 1, 64
    .quad 0
    .section __TEXT,__text,regular,pure_instructions

// Lpass -- the three sweeps; prints `pass <n> gemv|vecmat|matmul <hash>`.
//   Inputs  : x0 = n. Callee-saved used: x19 = n. Frame 32 bytes.
    .p2align 2
Lpass:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    TXT "pass "
    mov x0, x19
    bl Lput_dec
    TXT " gemv "
    bl Lsweep_mv
    bl Lput_hex
    TXT "\npass "
    mov x0, x19
    bl Lput_dec
    TXT " vecmat "
    bl Lsweep_vm
    bl Lput_hex
    TXT "\npass "
    mov x0, x19
    bl Lput_dec
    TXT " matmul "
    bl Lsweep_mm
    bl Lput_hex
    TXT "\n"
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---- the test ---------------------------------------------------------
// _sea_main -- pass 1 under FIRST_VARIANT, pass 2 under the variant main
// selected; both must give the hashes of the pinned orders.
// Callee-saved used: x19 (the selected variant). Frame 96 bytes.
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x9, _sea_variant
    ldr x19, [x9]
    mov x10, #FIRST_VARIANT
    str x10, [x9]
    mov x0, #1
    bl Lpass
    LA x9, _sea_variant
    str x19, [x9]
    mov x0, #2
    bl Lpass
    EPILOGUE

    .section __DATA,__const
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
