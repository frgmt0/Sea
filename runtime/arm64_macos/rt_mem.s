// =====================================================================
// sea/runtime/arm64_macos/rt_mem.s -- the allocator, sea_free, the
// count helpers and the live-object counter (DESIGN.md 4.1, 4.2, 4.5,
// 4.8 entry FREE).
//
// Defines:
//   _sea_free         (global, SEA_ENT_FREE) free an object whose count
//                     has just reached 0, after releasing what it refers to
//   _sea_alloc        (private to the runtime) allocate a block
//   _sea_free_block   (private) give a block back
//   _sea_retain       (private) the count increment for runtime code
//   _sea_release      (private) the count decrement, freeing at 0
//   _sea_live         (private) u64: arrays and strings allocated and not
//                     yet freed; read by main's heap check (rt_main.s)
//
// THE INTERNAL API (AAPCS64: x0-x17, d0-d7, d16-d31 clobbered unless a
// routine says less; x19-x28, d8-d15 preserved; x18 never touched):
//   _sea_alloc (x0 = request b in bytes, x1 = site index or
//               SEA_SITE_NONE) -> x0 = block of the class of b
//       Never returns on failure: a request above 2^62 (RT_MEM_MAX_REQ)
//       or a failed mmap is _sea_err(SEA_E_OUT_OF_MEMORY, site). The
//       contents of the block are unspecified (a recycled block is not
//       clean). The live counter is not touched: the object
//       constructors (rt_arr.s, rt_str.s, rt_args.s, rt_fmt.s) count
//       the objects they make, and _sea_free uncounts them.
//   _sea_free_block (x0 = block, x1 = the request b it was allocated
//               with, or any b of the same class) -> nothing
//   _sea_retain (x0 = object or 0)    clobbers x9 only
//       Count + 1 unless the pointer is null or the object is static.
//   _sea_release (x0 = object or 0)   clobbers as _sea_free
//       Nothing for null or a static object; else count - 1, and at 0
//       _sea_free (the same path as the release sequence of pass 4).
//
// The allocator (DESIGN.md 4.1). A request of b bytes takes the class
// 2^k, the least power of two >= max(b, RT_MEM_MIN_BYTES = 32). One
// table of list heads is indexed by k (5 .. 62):
//   * small classes (2^k <= SEA_SMALL_MAX_BYTES): a LIFO free list per
//     class, linked through the first 8 bytes of each free block. When
//     the list is empty, the next block is carved from the class's
//     current chunk (a cursor and an end per class, ascending addresses,
//     so no page is touched before its block is handed out); a used-up or
//     absent chunk is replaced by one fresh mmap of SEA_CHUNK_BYTES
//     (page-aligned). Chunks are never unmapped. Every block is at a
//     multiple of its class size inside its chunk, so it is aligned to
//     its class size (at most 4096, below the 16 KiB page);
//   * large classes: a block is one mmap of its class size (page-
//     aligned). A freed large block goes into its class's LIFO cache
//     while that class holds fewer than SEA_LCACHE_PER_CLASS blocks and
//     the cache holds at most SEA_LCACHE_MAX_BYTES with it; otherwise it
//     is unmapped. An allocation takes the most recently freed cached
//     block of its class first.
// Programs are single-threaded: nothing here is atomic.
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

.equ RT_MEM_MIN_BYTES,  32          /* the smallest class, 2^5 */
.equ RT_MEM_CLASSES,    64          /* table slots, indexed by log2 of the class */
.equ RT_PROT_RW,        3           /* PROT_READ | PROT_WRITE */
.equ RT_MAP_PRIVANON,   0x1002      /* MAP_PRIVATE | MAP_ANON on Darwin */

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// Lrt_mem_class -- the class of a request.
//   Inputs  : x0 = request b (<= 2^62)
//   Outputs : x0 = k, x1 = 2^k: the least power of two >= max(b, 32)
//   Clobbers: x9
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_mem_class:
    cmp x0, #RT_MEM_MIN_BYTES
    mov x9, #RT_MEM_MIN_BYTES
    csel x0, x9, x0, lo             // b = max(b, 32)
    sub x9, x0, #1
    clz x9, x9                      // leading zeros of b - 1
    mov x0, #64
    sub x0, x0, x9                  // k = 64 - clz(b - 1)
    mov x1, #1
    lsl x1, x1, x0                  // 2^k
    ret

// ---------------------------------------------------------------------
// _sea_alloc -- allocate a block (see the file header).
//   Inputs  : x0 = request in bytes, x1 = site index or SEA_SITE_NONE
//   Outputs : x0 = the block (aligned to min(class, 4096) or better)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = k, x20 = class size, x21 = site,
//             x22 = &heads[k]
//   Frame   : 48 bytes (frame record + x19..x22)
// ---------------------------------------------------------------------
    .private_extern _sea_alloc
    .p2align 2
_sea_alloc:
    stp x29, x30, [sp, #-48]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x21, x1                     // site, for the failure report
    movz x9, #0x4000, lsl #48       // 2^62: the largest request that fits
    cmp x0, x9
    b.hi Lrt_mem_alloc_oom
    bl Lrt_mem_class                // x0 = k, x1 = class size
    mov x19, x0
    mov x20, x1
    adrp x9, Lrt_mem_heads@PAGE
    add x9, x9, Lrt_mem_heads@PAGEOFF
    add x22, x9, x19, lsl #3        // &heads[k]
    ldr x0, [x22]                   // first free block of the class, or 0
    cmp x20, #SEA_SMALL_MAX_BYTES
    b.hi Lrt_mem_alloc_large

    // Small class: pop the free list; if it is empty, carve the next
    // block of the class's current chunk (cursor, end), mapping a fresh
    // chunk when there is none or it is used up.
    cbz x0, Lrt_mem_alloc_carve
    ldr x9, [x0]                    // the block's successor
    str x9, [x22]                   // becomes the head
    b Lrt_mem_alloc_done
Lrt_mem_alloc_carve:
    adrp x9, Lrt_mem_cur@PAGE
    add x9, x9, Lrt_mem_cur@PAGEOFF
    ldr x0, [x9, x19, lsl #3]       // the cursor
    adrp x10, Lrt_mem_end@PAGE
    add x10, x10, Lrt_mem_end@PAGEOFF
    ldr x11, [x10, x19, lsl #3]     // the chunk's end
    cmp x0, x11
    b.ne 1f                         // room left in the chunk
    mov x0, #0                      // addr: anywhere
    mov x1, #SEA_CHUNK_BYTES
    mov w2, #RT_PROT_RW
    mov w3, #RT_MAP_PRIVANON
    mov w4, #-1                     // fd: none
    mov x5, #0                      // offset
    bl _mmap
    cmn x0, #1
    b.eq Lrt_mem_alloc_oom          // MAP_FAILED
    adrp x10, Lrt_mem_end@PAGE
    add x10, x10, Lrt_mem_end@PAGEOFF
    add x11, x0, #SEA_CHUNK_BYTES
    str x11, [x10, x19, lsl #3]     // the new chunk's end
    adrp x9, Lrt_mem_cur@PAGE
    add x9, x9, Lrt_mem_cur@PAGEOFF
1:  add x11, x0, x20
    str x11, [x9, x19, lsl #3]      // cursor += class size
    b Lrt_mem_alloc_done

    // Large class: the most recently freed cached block, else a new map.
Lrt_mem_alloc_large:
    cbz x0, Lrt_mem_alloc_map
    ldr x9, [x0]                    // the next cached block
    str x9, [x22]
    adrp x10, Lrt_mem_counts@PAGE
    add x10, x10, Lrt_mem_counts@PAGEOFF
    ldr x11, [x10, x19, lsl #3]
    sub x11, x11, #1                // one block fewer in this class
    str x11, [x10, x19, lsl #3]
    adrp x10, Lrt_mem_cached@PAGE
    ldr x11, [x10, Lrt_mem_cached@PAGEOFF]
    sub x11, x11, x20               // and fewer bytes in the cache
    str x11, [x10, Lrt_mem_cached@PAGEOFF]
    b Lrt_mem_alloc_done
Lrt_mem_alloc_map:
    mov x0, #0
    mov x1, x20                     // exactly the class size
    mov w2, #RT_PROT_RW
    mov w3, #RT_MAP_PRIVANON
    mov w4, #-1
    mov x5, #0
    bl _mmap
    cmn x0, #1
    b.eq Lrt_mem_alloc_oom
Lrt_mem_alloc_done:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
Lrt_mem_alloc_oom:
    mov w0, #SEA_E_OUT_OF_MEMORY
    mov x1, x21                     // the site of the allocating entry
    mov x2, #0                      // no argument slots
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_free_block -- give a block back to its class (see the header).
//   Inputs  : x0 = block, x1 = a request size of its class
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = block, x20 = k, x21 = class size
//   Frame   : 32 bytes (frame record + x19, x20) + 16 (x21, pad) = 48
// ---------------------------------------------------------------------
    .private_extern _sea_free_block
    .p2align 2
_sea_free_block:
    stp x29, x30, [sp, #-48]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0                     // the block
    mov x0, x1
    bl Lrt_mem_class                // x0 = k, x1 = class size
    mov x20, x0
    mov x21, x1
    adrp x9, Lrt_mem_heads@PAGE
    add x9, x9, Lrt_mem_heads@PAGEOFF
    add x9, x9, x20, lsl #3         // &heads[k]
    cmp x21, #SEA_SMALL_MAX_BYTES
    b.hi Lrt_mem_fb_large
Lrt_mem_fb_push:
    ldr x10, [x9]                   // push on the class's list (LIFO)
    str x10, [x19]
    str x19, [x9]
    b Lrt_mem_fb_done
Lrt_mem_fb_large:
    // Cache it while the class holds fewer than SEA_LCACHE_PER_CLASS
    // blocks and the cache stays within SEA_LCACHE_MAX_BYTES with it.
    adrp x10, Lrt_mem_counts@PAGE
    add x10, x10, Lrt_mem_counts@PAGEOFF
    ldr x11, [x10, x20, lsl #3]
    cmp x11, #SEA_LCACHE_PER_CLASS
    b.hs Lrt_mem_fb_unmap
    adrp x12, Lrt_mem_cached@PAGE
    ldr x13, [x12, Lrt_mem_cached@PAGEOFF]
    add x13, x13, x21               // bytes cached with this block
    mov x14, #SEA_LCACHE_MAX_BYTES
    cmp x13, x14
    b.hi Lrt_mem_fb_unmap
    str x13, [x12, Lrt_mem_cached@PAGEOFF]
    add x11, x11, #1
    str x11, [x10, x20, lsl #3]     // one more block in the class
    b Lrt_mem_fb_push
Lrt_mem_fb_unmap:
    mov x0, x19
    mov x1, x21                     // the whole mapping
    bl _munmap                      // cannot fail for a mapping of ours
Lrt_mem_fb_done:
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// _sea_retain -- count + 1 (see the file header).
//   Inputs  : x0 = object or 0
//   Outputs : none (x0 preserved)
//   Clobbers: x9
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .private_extern _sea_retain
    .p2align 2
_sea_retain:
    cbz x0, 1f                      // null: nothing
    ldr x9, [x0, #SEA_OBJ_RC]
    cbz x9, 1f                      // static: unchanged
    add x9, x9, #1
    str x9, [x0, #SEA_OBJ_RC]
1:  ret

// ---------------------------------------------------------------------
// _sea_release -- count - 1, freeing at 0 (see the file header).
//   Inputs  : x0 = object or 0
//   Outputs : none
//   Clobbers: as _sea_free (x0-x17, d0-d7, d16-d31, flags)
//   Callee-saved used: none
//   Frame   : none (leaf, or a tail call of _sea_free)
// ---------------------------------------------------------------------
    .private_extern _sea_release
    .p2align 2
_sea_release:
    cbz x0, 1f                      // null: nothing
    ldr x9, [x0, #SEA_OBJ_RC]
    cbz x9, 1f                      // static: unchanged
    subs x9, x9, #1
    str x9, [x0, #SEA_OBJ_RC]
    b.eq _sea_free                  // reached 0: free it (tail call)
1:  ret

// ---------------------------------------------------------------------
// _sea_free -- the entry FREE (DESIGN.md 4.8): free an object whose
//   count has just reached 0.
//   Purpose : an array first releases each str element (ek SEA_EK_STR)
//             or each reference field of each struct element (ek
//             SEA_EK_STRUCT, offsets from its SEA_SL_* descriptor),
//             skipping null and static references; then its block
//             (SEA_ARR_SIZE + cap * esize bytes) is freed. A string's
//             block (SEA_STR_BYTES + length) is freed. The live counter
//             drops by one. Phase 4 creates no handle object (tags
//             SEA_TAG_FIGURE .. SEA_TAG_CHOL), so any tag other than
//             SEA_TAG_ARRAY and SEA_TAG_STR is a corrupted object and
//             traps (brk) rather than freeing memory of unknown size.
//   Inputs  : x0 = the object (count 0 just reached; never static)
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = object, x20 = element cursor, x21 = elements
//             left, x22 = descriptor, x23 = element size, x24 = number of
//             reference fields, x25 = field index
//   Frame   : 80 bytes (frame record + x19..x25, pad)
// ---------------------------------------------------------------------
    .globl _sea_free
    .p2align 2
_sea_free:
    stp x29, x30, [sp, #-80]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    str x25, [sp, #64]
    mov x19, x0
    ldrb w9, [x19, #SEA_OBJ_TAG]
    cmp w9, #SEA_TAG_STR
    b.eq Lrt_mem_free_str
    cmp w9, #SEA_TAG_ARRAY
    b.ne Lrt_mem_free_badtag

    // An array: release what its elements refer to.
    ldrb w9, [x19, #SEA_ARR_EK]
    ldr x10, [x19, #SEA_ARR_ROWS]
    ldr x11, [x19, #SEA_ARR_COLS]
    mul x21, x10, x11               // elements
    ldr x20, [x19, #SEA_ARR_DATA]   // first element
    cmp w9, #SEA_EK_STR
    b.eq Lrt_mem_free_strs
    cmp w9, #SEA_EK_STRUCT
    b.eq Lrt_mem_free_structs
    b Lrt_mem_free_arr              // numeric elements hold no reference
Lrt_mem_free_strs:
    cbz x21, Lrt_mem_free_arr
    ldr x0, [x20], #SEA_ESIZE_PTR   // the element (null and static skipped)
    bl _sea_release
    sub x21, x21, #1
    b Lrt_mem_free_strs
Lrt_mem_free_structs:
    ldr x22, [x19, #SEA_ARR_SLAY]   // the descriptor
    ldr x23, [x19, #SEA_ARR_ESIZE]
    ldr x24, [x22, #SEA_SL_NREF]
Lrt_mem_free_elem:
    cbz x21, Lrt_mem_free_arr
    mov x25, #0                     // field index
1:  cmp x25, x24
    b.hs 2f
    add x9, x22, #SEA_SL_REFS
    ldr x9, [x9, x25, lsl #3]       // byte offset of reference field j
    ldr x0, [x20, x9]
    bl _sea_release
    add x25, x25, #1
    b 1b
2:  add x20, x20, x23               // the next element
    sub x21, x21, #1
    b Lrt_mem_free_elem
Lrt_mem_free_arr:
    ldr x9, [x19, #SEA_ARR_CAP]
    ldr x10, [x19, #SEA_ARR_ESIZE]
    mul x1, x9, x10
    add x1, x1, #SEA_ARR_SIZE       // header and buffer: one block
    mov x0, x19
    bl _sea_free_block
    b Lrt_mem_free_count
Lrt_mem_free_str:
    ldr x1, [x19, #SEA_STR_LEN]
    add x1, x1, #SEA_STR_BYTES      // header and bytes: one block
    mov x0, x19
    bl _sea_free_block
Lrt_mem_free_count:
    adrp x9, _sea_live@PAGE
    ldr x10, [x9, _sea_live@PAGEOFF]
    sub x10, x10, #1                // one live object fewer
    str x10, [x9, _sea_live@PAGEOFF]
    ldr x25, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret
Lrt_mem_free_badtag:
    brk #1                          // not an object phase 4 creates

// ---------------------------------------------------------------------
// State: list heads (small: free lists; large: caches) and the large
// cache's per-class counts, indexed by k; the bytes cached in all; the
// live-object counter.
// ---------------------------------------------------------------------
    .private_extern _sea_live
.zerofill __DATA,__bss,_sea_live,8,3                    /* live arrays and strings */
.zerofill __DATA,__bss,Lrt_mem_heads,(8*RT_MEM_CLASSES),3   /* first free block per class */
.zerofill __DATA,__bss,Lrt_mem_counts,(8*RT_MEM_CLASSES),3  /* cached blocks per large class */
.zerofill __DATA,__bss,Lrt_mem_cur,(8*RT_MEM_CLASSES),3     /* next block to carve per small class */
.zerofill __DATA,__bss,Lrt_mem_end,(8*RT_MEM_CLASSES),3     /* end of that class's current chunk */
.zerofill __DATA,__bss,Lrt_mem_cached,8,3               /* bytes in the large cache */
