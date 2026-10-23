// =====================================================================
// sea/runtime/arm64_macos/rt_sort.s -- sorting (DESIGN.md 4.5, 4.8
// entries SORT and ARGSORT, "The sort entries in detail"; LANGUAGE.md
// 10.6).
//
// Defines (global, rt.inc SEA_ENTRY_LIST):
//   _sea_sort    (v, desc, site) -> a new vector of v's elements in the
//                stable order of LANGUAGE.md 10.6
//   _sea_argsort (v, desc, site) -> a new i64 vector p (0-based) such
//                that v[p[0]], v[p[1]], ... is that order
// Uses: _sea_arr_new (rt_arr.s), _sea_alloc, _sea_free_block,
//       _sea_retain (rt_mem.s), _sea_str_cmp (rt_str.s).
//
// v is a vector of ek SEA_EK_F64, SEA_EK_I64 or SEA_EK_STR, borrowed and
// never written; desc is 0 (ascending) or 1 (descending). The result is
// a new vector with count 1 (sea_arr_new of v's ek, or SEA_EK_I64 for
// argsort; rank 1, rows n, cols 1), also for n = 0 and n = 1.
//
// Keys (f64, i64). For an f64 element with bits b: every NaN (exponent
// all ones, mantissa not 0, either sign) becomes #7FF8000000000000 and
// -0 (#8000000000000000) becomes 0; then key = b XOR #FFFFFFFFFFFFFFFF if
// b's sign bit is set, else b XOR #8000000000000000. For an i64 element
// key = b XOR #8000000000000000. With desc 1, key = NOT key. Unsigned
// key order is the order of LANGUAGE.md 10.6 (NaN above +inf ascending,
// below -inf descending, +-0 one key), and a stable sort on the keys
// keeps equal elements in input order in both directions.
//
// Algorithm. n <= RT_SORT_SMALL (32): a stable insertion sort of (key,
// index) pairs, held as a key array of 8n bytes followed by a 32-bit
// index array of 4n bytes (12n bytes rounded up to 8). Otherwise an LSD
// radix sort with 8 passes of 8 bits from the least significant byte, on
// a key array and a 32-bit index array (extents are below 2^31), ping-
// ponged between two buffers of each; the 8 histograms of 256 u64 counts
// are counted in one pass over the keys, and a pass whose byte is the
// same for every key is skipped. sort then gathers v[index[k]] (the
// original bits: -0, the NaN payloads and signs are kept); argsort
// writes the indices as i64. str (both entries): a stable bottom-up
// merge sort of 32-bit indices in STR_CMP's order (reversed for desc,
// ties keeping input order), ping-ponged between two index buffers; sort
// stores the gathered string pointers and retains each.
//
// Scratch. One block from _sea_alloc for n >= 2 (none for n <= 1):
//   f64/i64, n <= 32 : keys 8n, indices 4n           = 12n rounded to 8
//   f64/i64, n > 32  : histograms RT_SORT_HIST_BYTES (16384), keys A, B
//                      (8n each), indices A, B (4n each) = 24n + 16384
//   str              : indices A, B (4n each)        = 8n
// The result is allocated first, then the scratch; the scratch is freed
// with _sea_free_block before the entry returns, so the live-object
// count changes only by the result. A failed allocation of either is
// _sea_err(SEA_E_OUT_OF_MEMORY, site) through _sea_alloc's own path
// (rt_arr.s for the result); nothing else fails.
//
// Stack. The entries jump to Lrt_sort_common (96 bytes); below it only
// Lrt_sort_merge (112 bytes) has a frame of its own, so at most 208
// bytes below the incoming sp belong to this file (DESIGN.md 4.8: at
// most 256); the other helpers are leaves without a frame.
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

.equ RT_SORT_SMALL,      32         /* n <= this: insertion sort */
.equ RT_SORT_HIST_BYTES, 16384      /* 8 histograms * 256 counts * 8 bytes */
.equ RT_SORT_HIST_ONE,   2048       /* one histogram: 256 counts * 8 bytes */

.if SEA_LIM_EXTENT > 0x7FFFFFFF
    .error "rt_sort: 32-bit indices need extents below 2^31"
.endif

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// _sea_sort -- the entry SORT.
//   Inputs  : x0 = v, x1 = desc (0 or 1), x2 = site
//   Outputs : x0 = the sorted vector (count 1)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: none here (Lrt_sort_common saves what it uses)
//   Frame   : none (a jump to Lrt_sort_common with x3 = 0)
// ---------------------------------------------------------------------
    .globl _sea_sort
    .p2align 2
_sea_sort:
    mov x3, #0                      // mode 0: the sorted values
    b Lrt_sort_common

// ---------------------------------------------------------------------
// _sea_argsort -- the entry ARGSORT.
//   Inputs  : x0 = v, x1 = desc (0 or 1), x2 = site
//   Outputs : x0 = the i64 permutation vector (count 1)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: none here
//   Frame   : none (a jump to Lrt_sort_common with x3 = 1)
// ---------------------------------------------------------------------
    .globl _sea_argsort
    .p2align 2
_sea_argsort:
    mov x3, #1                      // mode 1: the permutation
    b Lrt_sort_common

// ---------------------------------------------------------------------
// Lrt_sort_common -- both entries (see the file header).
//   Inputs  : x0 = v, x1 = desc (0 or 1), x2 = site, x3 = mode (0 sort,
//             1 argsort)
//   Outputs : x0 = the result vector (count 1)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = v, then the final index buffer of the str
//             gather; x20 = desc mask (0 or all ones), then the str
//             gather's cursor; x21 = site, x22 = mode, x23 = n,
//             x24 = the result, x25 = the scratch block, x26 = its byte
//             count, x27 = v's elements, x28 = the result's elements
//   Frame   : 96 bytes (frame record + x19..x28)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_sort_common:
    stp x29, x30, [sp, #-96]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    mov x19, x0
    neg x20, x1                     // desc 0 -> 0, desc 1 -> all ones
    mov x21, x2
    mov x22, x3
    ldr x9, [x19, #SEA_ARR_ROWS]
    ldr x10, [x19, #SEA_ARR_COLS]
    mul x23, x9, x10                // n (cols is 1 for a vector)

    // The result first: v's ek for sort, i64 for argsort; rank 1, n x 1.
    ldrb w0, [x19, #SEA_ARR_EK]
    mov x9, #SEA_EK_I64
    cmp x22, #0
    csel x0, x9, x0, ne
    mov x1, #1
    mov x2, x23
    mov x3, #1
    mov x4, x21
    bl _sea_arr_new                 // noreturn on failure
    mov x24, x0
    ldr x27, [x19, #SEA_ARR_DATA]   // v's elements (8 bytes each)
    ldr x28, [x24, #SEA_ARR_DATA]   // the result's elements
    cmp x23, #1
    b.hi Lrt_sort_common_many
    cbz x23, Lrt_sort_common_done   // n = 0: the empty vector

    // n = 1: no scratch. argsort: [0]; sort: v[0], retained if a str.
    cbz x22, 1f
    str xzr, [x28]
    b Lrt_sort_common_done
1:  ldr x0, [x27]
    str x0, [x28]                   // the element's bits unchanged
    ldrb w9, [x19, #SEA_ARR_EK]
    cmp w9, #SEA_EK_STR
    b.ne Lrt_sort_common_done
    bl _sea_retain                  // the result holds one more count
    b Lrt_sort_common_done

Lrt_sort_common_many:
    ldrb w9, [x19, #SEA_ARR_EK]
    cmp w9, #SEA_EK_STR
    b.eq Lrt_sort_common_str
    cmp x23, #RT_SORT_SMALL
    b.hi Lrt_sort_common_radix

    // f64/i64, 2 <= n <= 32: keys (8n) and indices (4n), 12n rounded to 8.
    add x26, x23, x23, lsl #1       // 3n
    lsl x26, x26, #2                // 12n
    add x26, x26, #7
    and x26, x26, #0xfffffffffffffff8
    mov x0, x26
    mov x1, x21
    bl _sea_alloc                   // noreturn on failure
    mov x25, x0
    mov x0, x25                     // keys at the start of the block
    add x1, x25, x23, lsl #3        // indices after the 8n key bytes
    mov x2, x27
    mov x3, x23
    ldrb w4, [x19, #SEA_ARR_EK]
    mov x5, x20
    bl Lrt_sort_keys
    mov x0, x25
    add x1, x25, x23, lsl #3
    mov x2, x23
    bl Lrt_sort_insert
    add x0, x25, x23, lsl #3        // the sorted indices
    b Lrt_sort_common_gather

Lrt_sort_common_radix:
    // f64/i64, n > 32: histograms, keys A and B, indices A and B.
    add x26, x23, x23, lsl #1       // 3n
    lsl x26, x26, #3                // 24n
    add x26, x26, #RT_SORT_HIST_BYTES
    mov x0, x26
    mov x1, x21
    bl _sea_alloc                   // noreturn on failure
    mov x25, x0
    add x0, x25, #RT_SORT_HIST_BYTES // keys A after the histograms
    add x1, x0, x23, lsl #4         // indices A after keys A and B
    mov x2, x27
    mov x3, x23
    ldrb w4, [x19, #SEA_ARR_EK]
    mov x5, x20
    bl Lrt_sort_keys
    mov x0, x25
    mov x1, x23
    bl Lrt_sort_radix               // x0 = the buffer of the sorted indices

Lrt_sort_common_gather:
    // x0 = the 32-bit indices in sorted order.
    cbnz x22, Lrt_sort_common_perm
    mov x9, #0                      // k
2:  ldr w10, [x0, x9, lsl #2]       // index[k]
    ldr x11, [x27, x10, lsl #3]     // v[index[k]], its original bits
    str x11, [x28, x9, lsl #3]
    add x9, x9, #1
    cmp x9, x23
    b.lo 2b
    b Lrt_sort_common_free

Lrt_sort_common_perm:
    // argsort: the indices as i64 (32-bit zero-extended).
    mov x9, #0
3:  ldr w10, [x0, x9, lsl #2]
    str x10, [x28, x9, lsl #3]
    add x9, x9, #1
    cmp x9, x23
    b.lo 3b

Lrt_sort_common_free:
    mov x0, x25
    mov x1, x26                     // the request it was allocated with
    bl _sea_free_block
Lrt_sort_common_done:
    mov x0, x24
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

Lrt_sort_common_str:
    // str, n >= 2: indices A and B, 4n bytes each.
    lsl x26, x23, #3                // 8n
    mov x0, x26
    mov x1, x21
    bl _sea_alloc                   // noreturn on failure
    mov x25, x0
    mov x0, x27                     // the string pointers
    mov x1, x25                     // indices A
    add x2, x25, x23, lsl #2        // indices B
    mov x3, x23
    mov x4, x20
    bl Lrt_sort_merge               // x0 = the buffer of the sorted indices
    cbnz x22, Lrt_sort_common_perm
    // sort: gather the pointers; each gains the result's count.
    mov x19, x0                     // v is no longer needed (x27 holds its elements)
    mov x20, #0                     // k
4:  ldr w10, [x19, x20, lsl #2]
    ldr x0, [x27, x10, lsl #3]      // v[index[k]]
    str x0, [x28, x20, lsl #3]
    bl _sea_retain                  // clobbers x9 only; static strings unchanged
    add x20, x20, #1
    cmp x20, x23
    b.lo 4b
    b Lrt_sort_common_free

// ---------------------------------------------------------------------
// Lrt_sort_keys -- the keys and the identity indices (file header).
//   Inputs  : x0 = key array (8n bytes), x1 = index array (4n bytes),
//             x2 = v's elements, x3 = n (>= 1), w4 = ek (SEA_EK_F64 or
//             SEA_EK_I64), x5 = desc mask (0 or all ones)
//   Outputs : key[k] = the key of element k, index[k] = k
//   Clobbers: x9-x14, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_sort_keys:
    movz x12, #0x7FF0, lsl #48      // +inf: an f64 above it (sign cleared) is a NaN
    movz x13, #0x7FF8, lsl #48      // the canonical NaN
    movz x14, #0x8000, lsl #48      // the sign bit (-0's bits)
    mov x9, #0                      // k
    cmp w4, #SEA_EK_F64
    b.ne Lrt_sort_keys_i64
Lrt_sort_keys_f64:
    ldr x10, [x2, x9, lsl #3]       // the element's bits b
    and x11, x10, #0x7fffffffffffffff
    cmp x11, x12
    csel x10, x13, x10, hi          // every NaN -> #7FF8000000000000
    cmp x10, x14
    csel x10, xzr, x10, eq          // -0 -> +0
    asr x11, x10, #63               // all ones if negative, else 0
    orr x11, x11, x14               // negative: invert all; else flip the sign
    eor x10, x10, x11
    eor x10, x10, x5                // desc: NOT key
    str x10, [x0, x9, lsl #3]
    str w9, [x1, x9, lsl #2]        // index k
    add x9, x9, #1
    cmp x9, x3
    b.lo Lrt_sort_keys_f64
    ret
Lrt_sort_keys_i64:
    ldr x10, [x2, x9, lsl #3]
    eor x10, x10, x14               // the sign flip: signed order as unsigned
    eor x10, x10, x5                // desc: NOT key
    str x10, [x0, x9, lsl #3]
    str w9, [x1, x9, lsl #2]
    add x9, x9, #1
    cmp x9, x3
    b.lo Lrt_sort_keys_i64
    ret

// ---------------------------------------------------------------------
// Lrt_sort_insert -- stable insertion sort of (key, index) pairs by
//   unsigned key: an element moves left only past strictly greater keys.
//   Inputs  : x0 = key array, x1 = index array, x2 = n (>= 2)
//   Outputs : both arrays permuted together into ascending key order
//   Clobbers: x9-x15, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_sort_insert:
    mov x9, #1                      // i: the element to insert
1:  ldr x10, [x0, x9, lsl #3]       // its key
    ldr w11, [x1, x9, lsl #2]       // its index
    mov x12, x9                     // j: the hole
2:  cbz x12, 3f
    sub x13, x12, #1
    ldr x14, [x0, x13, lsl #3]
    cmp x14, x10
    b.ls 3f                         // key[j-1] <= key: the place (stable)
    str x14, [x0, x12, lsl #3]      // shift the greater pair right
    ldr w15, [x1, x13, lsl #2]
    str w15, [x1, x12, lsl #2]
    mov x12, x13
    b 2b
3:  str x10, [x0, x12, lsl #3]      // the pair into the hole
    str w11, [x1, x12, lsl #2]
    add x9, x9, #1
    cmp x9, x2
    b.lo 1b
    ret

// ---------------------------------------------------------------------
// Lrt_sort_radix -- LSD radix sort, 8 passes of 8 bits (file header).
//   Inputs  : x0 = the scratch block: the histograms (RT_SORT_HIST_BYTES),
//             then keys A (8n, filled), keys B (8n), indices A (4n,
//             filled), indices B (4n); x1 = n (> 32)
//   Outputs : x0 = the index buffer (A or B) holding the indices in
//             ascending key order (stable)
//   Clobbers: x0-x16, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_sort_radix:
    mov x7, x1                      // n
    mov x2, x0                      // the histograms
    add x3, x0, #RT_SORT_HIST_BYTES // source keys (A)
    add x4, x3, x7, lsl #3          // destination keys (B)
    add x5, x4, x7, lsl #3          // source indices (A)
    add x6, x5, x7, lsl #2          // destination indices (B)

    // Clear the 8 * 256 counts (16 bytes per step).
    mov x9, x2
    mov x10, #(RT_SORT_HIST_BYTES / 16)
1:  stp xzr, xzr, [x9], #16
    subs x10, x10, #1
    b.ne 1b

    // Count all 8 histograms in one pass over the keys.
    mov x9, #0                      // k
2:  ldr x10, [x3, x9, lsl #3]       // key[k]
    mov x11, x2                     // the histogram of byte 0
    mov x12, #8                     // bytes left
3:  and x13, x10, #0xff
    ldr x14, [x11, x13, lsl #3]
    add x14, x14, #1                // one more key with this byte
    str x14, [x11, x13, lsl #3]
    lsr x10, x10, #8                // the next byte
    add x11, x11, #RT_SORT_HIST_ONE // and its histogram
    subs x12, x12, #1
    b.ne 3b
    add x9, x9, #1
    cmp x9, x7
    b.lo 2b

    // The passes, byte 0 (least significant) to byte 7.
    mov x8, #0                      // the shift of this pass's byte
    mov x11, x2                     // this pass's histogram
4:  ldr x10, [x3]                   // any key's byte at this position:
    lsr x10, x10, x8
    and x10, x10, #0xff
    ldr x12, [x11, x10, lsl #3]
    cmp x12, x7
    b.eq 7f                         // ... held by all n keys: skip the pass
    // Exclusive prefix sums in place: count -> first destination.
    mov x9, #0
    mov x12, #0                     // the running total
5:  ldr x13, [x11, x9, lsl #3]
    str x12, [x11, x9, lsl #3]
    add x12, x12, x13
    add x9, x9, #1
    cmp x9, #256
    b.lo 5b
    // Scatter in input order (stable) from the source to the destination.
    mov x9, #0
6:  ldr x10, [x3, x9, lsl #3]       // key
    ldr w13, [x5, x9, lsl #2]       // its index
    lsr x14, x10, x8
    and x14, x14, #0xff             // its byte in this pass
    ldr x15, [x11, x14, lsl #3]     // its destination
    add x16, x15, #1
    str x16, [x11, x14, lsl #3]
    str x10, [x4, x15, lsl #3]
    str w13, [x6, x15, lsl #2]
    add x9, x9, #1
    cmp x9, x7
    b.lo 6b
    // The destination becomes the source of the next pass.
    mov x10, x3
    mov x3, x4
    mov x4, x10
    mov x10, x5
    mov x5, x6
    mov x6, x10
7:  add x8, x8, #8
    add x11, x11, #RT_SORT_HIST_ONE
    cmp x8, #64
    b.lo 4b
    mov x0, x5                      // the indices after the last pass
    ret

// ---------------------------------------------------------------------
// Lrt_sort_merge -- stable bottom-up merge sort of string indices.
//   Purpose : sorts the indices 0 .. n-1 of the string pointers by
//             STR_CMP's order (desc: the reverse order); a right element
//             goes before a left one only when it is strictly before it,
//             so equal strings keep their input order in both directions.
//             Runs of width 1, 2, 4, ... are merged from one buffer into
//             the other, which then swap roles.
//   Inputs  : x0 = the string pointers, x1 = index buffer A (4n bytes),
//             x2 = index buffer B (4n bytes), x3 = n (>= 2), x4 = desc
//             mask (0 or all ones)
//   Outputs : x0 = the buffer (A or B) holding the sorted indices
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = string pointers, x20 = source buffer,
//             x21 = destination buffer, x22 = n, x23 = run width,
//             x24 = run start, x25 = left cursor, x26 = right cursor,
//             x27 = output cursor, x28 = desc mask; [sp + 96] = the left
//             run's end (mid), [sp + 104] = the right run's end (hi)
//   Frame   : 112 bytes (frame record + x19..x28 + two words)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_sort_merge:
    stp x29, x30, [sp, #-112]!      // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x28, x4
    // The source starts as the identity 0 .. n-1.
    mov x9, #0
1:  str w9, [x20, x9, lsl #2]
    add x9, x9, #1
    cmp x9, x22
    b.lo 1b
    mov x23, #1                     // run width
Lrt_sort_merge_width:
    cmp x23, x22
    b.hs Lrt_sort_merge_done        // one run covers everything
    mov x24, #0                     // the first pair of runs
Lrt_sort_merge_pair:
    cmp x24, x22
    b.hs Lrt_sort_merge_next
    add x9, x24, x23
    cmp x9, x22
    csel x9, x22, x9, hi            // mid = min(lo + width, n)
    add x10, x9, x23
    cmp x10, x22
    csel x10, x22, x10, hi          // hi = min(mid + width, n)
    str x9, [sp, #96]
    str x10, [sp, #104]
    mov x25, x24                    // left cursor
    mov x26, x9                     // right cursor
    mov x27, x24                    // output cursor
Lrt_sort_merge_step:
    ldr x9, [sp, #96]
    cmp x25, x9
    b.hs Lrt_sort_merge_restr       // left run used up
    ldr x10, [sp, #104]
    cmp x26, x10
    b.hs Lrt_sort_merge_restl       // right run used up
    ldr w9, [x20, x26, lsl #2]
    ldr x0, [x19, x9, lsl #3]       // the right string
    ldr w10, [x20, x25, lsl #2]
    ldr x1, [x19, x10, lsl #3]      // the left string
    bl _sea_str_cmp                 // -1, 0, 1: right vs left
    cmp x28, #0
    cneg x0, x0, ne                 // desc: the reverse order
    tbnz x0, #63, Lrt_sort_merge_right // strictly before: right first
    ldr w9, [x20, x25, lsl #2]      // else the left one (ties: input order)
    str w9, [x21, x27, lsl #2]
    add x25, x25, #1
    add x27, x27, #1
    b Lrt_sort_merge_step
Lrt_sort_merge_right:
    ldr w9, [x20, x26, lsl #2]
    str w9, [x21, x27, lsl #2]
    add x26, x26, #1
    add x27, x27, #1
    b Lrt_sort_merge_step
Lrt_sort_merge_restl:
    // Copy the rest of the left run.
    ldr x9, [sp, #96]
2:  cmp x25, x9
    b.hs Lrt_sort_merge_pairend
    ldr w10, [x20, x25, lsl #2]
    str w10, [x21, x27, lsl #2]
    add x25, x25, #1
    add x27, x27, #1
    b 2b
Lrt_sort_merge_restr:
    // Copy the rest of the right run.
    ldr x10, [sp, #104]
3:  cmp x26, x10
    b.hs Lrt_sort_merge_pairend
    ldr w11, [x20, x26, lsl #2]
    str w11, [x21, x27, lsl #2]
    add x26, x26, #1
    add x27, x27, #1
    b 3b
Lrt_sort_merge_pairend:
    add x24, x24, x23, lsl #1       // the next pair of runs
    b Lrt_sort_merge_pair
Lrt_sort_merge_next:
    mov x9, x20                     // the merged runs become the source
    mov x20, x21
    mov x21, x9
    lsl x23, x23, #1                // of runs twice as wide
    b Lrt_sort_merge_width
Lrt_sort_merge_done:
    mov x0, x20
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #112
    ret
