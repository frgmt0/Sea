// =====================================================================
// sea/runtime/arm64_macos/rt_arr.s -- array constructors and copy on
// write (DESIGN.md 4.1, 4.2, 4.8 entries ARR_NEW, ARR_NEW_S, ARR_UNIQUE,
// ARR_NEW_U).
//
// Defines (global, rt.inc SEA_ENTRY_LIST):
//   _sea_arr_new    (ek, rank, rows, cols, site) -> a new zeroed array
//   _sea_arr_new_u  (ek, rank, rows, cols, site) -> the same, not cleared
//   _sea_arr_new_s  (slay, rank, rows, cols, site) -> a zeroed struct array
//   _sea_arr_unique (a, site) -> a with count 1, or a copy
// Uses: _sea_alloc (rt_mem.s), _sea_live (rt_mem.s), _sea_err (rt_err.s),
//       memset, memcpy (libSystem).
//
// Every array is one block (DESIGN.md 4.1): its SEA_ARR_SIZE-byte header
// and, right after it, the buffer of rows * cols elements, so
// SEA_ARR_DATA = header + SEA_ARR_SIZE and SEA_ARR_CAP = rows * cols.
// The block of an array is at least SEA_ARR_SIZE (64) bytes, so its class
// is at least 64 and the buffer is SEA_DATA_ALIGN-aligned. Header bytes
// that no field uses (11 .. 15) are 0. A new array has count 1 and adds
// one to the live counter.
//
// Failures (the site is the last integer argument):
//   * the first of rows, cols (in this order) above SEA_LIM_EXTENT as an
//     unsigned value (so every negative extent too) is
//     _sea_err(SEA_E_ARRAY_SIZE, site, {that value});
//   * rows * cols * esize + SEA_ARR_SIZE above 2^62, or no memory, is
//     _sea_err(SEA_E_OUT_OF_MEMORY, site).
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// Lrt_arr_make -- the common constructor.
//   Inputs  : x0 = ek, x1 = rank, x2 = rows, x3 = cols, x4 = site,
//             x5 = element size, x6 = descriptor or 0, w7 = 1 to clear
//             the buffer to zero bytes, 0 to leave it as the block holds
//             it
//   Outputs : x0 = the new array (count 1, header complete)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = ek, x20 = rank, x21 = rows, x22 = cols,
//             x23 = site, x24 = element size, x25 = descriptor,
//             x26 = clear flag, x27 = buffer bytes, x28 = the array
//   Frame   : 96 bytes (frame record + x19..x28) + 16 (the argument slot
//             of ARRAY_SIZE at [sp]) = 112 bytes
// ---------------------------------------------------------------------
    .p2align 2
Lrt_arr_make:
    stp x29, x30, [sp, #-96]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    sub sp, sp, #16                 // the error slot
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x5
    mov x25, x6
    mov w26, w7

    // Extents: rows first, then cols, each 0 .. SEA_LIM_EXTENT.
    mov x9, #SEA_LIM_EXTENT
    mov x10, x21
    cmp x21, x9
    b.hi Lrt_arr_make_badsize       // unsigned: a negative extent too
    mov x10, x22
    cmp x22, x9
    b.hi Lrt_arr_make_badsize

    // Buffer bytes = rows * cols * esize; rows * cols < 2^62 here, the
    // product with esize may overflow 64 bits (umulh catches it).
    mul x9, x21, x22                // elements
    umulh x10, x9, x24
    cbnz x10, Lrt_arr_make_oom
    mul x27, x9, x24
    movz x11, #0x4000, lsl #48      // 2^62 ...
    sub x11, x11, #SEA_ARR_SIZE     // ... less the header
    cmp x27, x11
    b.hi Lrt_arr_make_oom           // the block would exceed 2^62
    add x0, x27, #SEA_ARR_SIZE
    mov x1, x23
    bl _sea_alloc                   // noreturn on failure
    mov x28, x0

    // The header: count 1, tag/ek/rank with bytes 11..15 zero, extents,
    // capacity, data pointer, element size, descriptor.
    mov x9, #1
    str x9, [x28, #SEA_ARR_RC]
    str xzr, [x28, #SEA_ARR_TAG]    // bytes 8..15 zero first
    mov w9, #SEA_TAG_ARRAY
    strb w9, [x28, #SEA_ARR_TAG]
    strb w19, [x28, #SEA_ARR_EK]
    strb w20, [x28, #SEA_ARR_RANK]
    str x21, [x28, #SEA_ARR_ROWS]
    str x22, [x28, #SEA_ARR_COLS]
    mul x9, x21, x22
    str x9, [x28, #SEA_ARR_CAP]     // cap = rows * cols
    add x0, x28, #SEA_ARR_SIZE
    str x0, [x28, #SEA_ARR_DATA]    // the buffer follows the header
    str x24, [x28, #SEA_ARR_ESIZE]
    str x25, [x28, #SEA_ARR_SLAY]

    // Clear the buffer (a recycled block is not clean, DESIGN.md 4.1).
    cbz w26, 1f
    mov w1, #0
    mov x2, x27
    bl _memset                      // x0 = the buffer
1:
    adrp x9, _sea_live@PAGE
    ldr x10, [x9, _sea_live@PAGEOFF]
    add x10, x10, #1                // one more live object
    str x10, [x9, _sea_live@PAGEOFF]
    mov x0, x28
    add sp, sp, #16
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

Lrt_arr_make_badsize:
    str x10, [sp]                   // the offending extent, as an i64
    mov w0, #SEA_E_ARRAY_SIZE
    mov x1, x23
    mov x2, sp
    bl _sea_err                     // noreturn
Lrt_arr_make_oom:
    mov w0, #SEA_E_OUT_OF_MEMORY
    mov x1, x23
    mov x2, #0
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// Lrt_arr_esize -- the element size of a scalar or str element kind.
//   Inputs  : x0 = ek (SEA_EK_F64, SEA_EK_I64, SEA_EK_BOOL, SEA_EK_STR)
//   Outputs : x5 = SEA_ESIZE_F64, SEA_ESIZE_I64, SEA_ESIZE_BOOL or
//             SEA_ESIZE_PTR by ek
//   Clobbers: x9, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_arr_esize:
    mov x5, #SEA_ESIZE_F64
    mov x9, #SEA_ESIZE_I64
    cmp x0, #SEA_EK_I64
    csel x5, x9, x5, eq
    mov x9, #SEA_ESIZE_BOOL
    cmp x0, #SEA_EK_BOOL
    csel x5, x9, x5, eq
    mov x9, #SEA_ESIZE_PTR
    cmp x0, #SEA_EK_STR
    csel x5, x9, x5, eq
    ret

// ---------------------------------------------------------------------
// _sea_arr_new -- the entry ARR_NEW: a new array, buffer zeroed.
//   Inputs  : x0 = ek, x1 = rank (1 or 2), x2 = rows, x3 = cols (1 for
//             a vector), x4 = site
//   Outputs : x0 = the array (count 1)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: none (Lrt_arr_make saves what it uses)
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .globl _sea_arr_new
    .p2align 2
_sea_arr_new:
    stp x29, x30, [sp, #-16]!       // frame record
    mov x29, sp
    bl Lrt_arr_esize                // x5 = element size
    mov x6, #0                      // no descriptor
    mov w7, #1                      // clear
    bl Lrt_arr_make
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// _sea_arr_new_u -- the entry ARR_NEW_U: as ARR_NEW for a numeric ek
//   (SEA_EK_F64, SEA_EK_I64, SEA_EK_BOOL), the buffer left as the block
//   holds it (its contents are unspecified until written).
//   Inputs  : x0 = ek, x1 = rank, x2 = rows, x3 = cols, x4 = site
//   Outputs : x0 = the array (count 1)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: none
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .globl _sea_arr_new_u
    .p2align 2
_sea_arr_new_u:
    stp x29, x30, [sp, #-16]!       // frame record
    mov x29, sp
    bl Lrt_arr_esize                // x5 = element size
    mov x6, #0                      // no descriptor
    mov w7, #0                      // not cleared
    bl Lrt_arr_make
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// _sea_arr_new_s -- the entry ARR_NEW_S: a new struct array, zeroed.
//   Inputs  : x0 = descriptor (SEA_SL_*), x1 = rank, x2 = rows,
//             x3 = cols, x4 = site
//   Outputs : x0 = the array: ek SEA_EK_STRUCT, esize = the descriptor's
//             SEA_SL_SIZE, SEA_ARR_SLAY = the descriptor
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: none
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .globl _sea_arr_new_s
    .p2align 2
_sea_arr_new_s:
    stp x29, x30, [sp, #-16]!       // frame record
    mov x29, sp
    ldr x5, [x0, #SEA_SL_SIZE]      // element size = struct size
    mov x6, x0                      // the descriptor
    mov x0, #SEA_EK_STRUCT
    mov w7, #1                      // clear: null references, zero fields
    bl Lrt_arr_make
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// _sea_arr_unique -- the entry ARR_UNIQUE: copy on write.
//   Purpose : if a's count is 1, a itself. Otherwise a new array with
//             a's ek, rank, rows, cols, esize and descriptor (cap rows *
//             cols) holding a copy of the rows * cols * esize data bytes;
//             every non-null str element, or every non-null reference
//             field of every struct element, gains a count (static
//             objects are unchanged); then a's count drops by one if it
//             is above 1 (a static a, count 0, stays). Returns the copy,
//             count 1.
//   Inputs  : x0 = a, x1 = site
//   Outputs : x0 = an array with count 1 and a's contents
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = a, x20 = site, x21 = the copy, x22 = element
//             cursor, x23 = elements left, x24 = descriptor, x25 = element
//             size, x26 = reference fields, x27 = field index
//   Frame   : none on the count-1 path; else 96 bytes (frame record +
//             x19..x27, pad)
// ---------------------------------------------------------------------
    .globl _sea_arr_unique
    .p2align 2
_sea_arr_unique:
    ldr x9, [x0, #SEA_ARR_RC]
    cmp x9, #1
    b.ne Lrt_arr_unique_copy
    ret                             // sole owner: write in place
Lrt_arr_unique_copy:
    stp x29, x30, [sp, #-96]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    str x27, [sp, #80]
    mov x19, x0
    mov x20, x1
    // The copy: the same header fields, not cleared (it is overwritten).
    ldrb w0, [x19, #SEA_ARR_EK]
    ldrb w1, [x19, #SEA_ARR_RANK]
    ldr x2, [x19, #SEA_ARR_ROWS]
    ldr x3, [x19, #SEA_ARR_COLS]
    mov x4, x20
    ldr x5, [x19, #SEA_ARR_ESIZE]
    ldr x6, [x19, #SEA_ARR_SLAY]
    mov w7, #0
    bl Lrt_arr_make
    mov x21, x0
    // The data bytes.
    ldr x9, [x19, #SEA_ARR_ROWS]
    ldr x10, [x19, #SEA_ARR_COLS]
    mul x23, x9, x10                // elements
    ldr x25, [x19, #SEA_ARR_ESIZE]
    ldr x0, [x21, #SEA_ARR_DATA]
    ldr x1, [x19, #SEA_ARR_DATA]
    mul x2, x23, x25
    bl _memcpy
    // The copy holds one more count of every reference it contains.
    ldr x22, [x21, #SEA_ARR_DATA]
    ldrb w9, [x21, #SEA_ARR_EK]
    cmp w9, #SEA_EK_STR
    b.eq Lrt_arr_unique_strs
    cmp w9, #SEA_EK_STRUCT
    b.eq Lrt_arr_unique_structs
    b Lrt_arr_unique_drop
Lrt_arr_unique_strs:
    cbz x23, Lrt_arr_unique_drop
    ldr x0, [x22], #SEA_ESIZE_PTR
    bl _sea_retain                  // null and static skipped
    sub x23, x23, #1
    b Lrt_arr_unique_strs
Lrt_arr_unique_structs:
    ldr x24, [x21, #SEA_ARR_SLAY]
    ldr x26, [x24, #SEA_SL_NREF]
Lrt_arr_unique_elem:
    cbz x23, Lrt_arr_unique_drop
    mov x27, #0                     // field index
1:  cmp x27, x26
    b.hs 2f
    add x9, x24, #SEA_SL_REFS
    ldr x9, [x9, x27, lsl #3]       // byte offset of reference field j
    ldr x0, [x22, x9]
    bl _sea_retain
    add x27, x27, #1
    b 1b
2:  add x22, x22, x25               // the next element
    sub x23, x23, #1
    b Lrt_arr_unique_elem
Lrt_arr_unique_drop:
    // The variable gives up its count on a (count >= 2 here, or static).
    ldr x9, [x19, #SEA_ARR_RC]
    cmp x9, #1
    b.ls 3f                         // static (0): unchanged
    sub x9, x9, #1
    str x9, [x19, #SEA_ARR_RC]
3:  mov x0, x21
    ldr x27, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret
