# =====================================================================
# sea/runtime/x86_64_linux/rt_mem.s -- the allocator, sea_free, the
# count helpers and the live-object counter (DESIGN.md 4.1, 4.2, 4.5,
# 4.7.1, 4.8 entry FREE). The x86_64-linux twin of
# runtime/arm64_macos/rt_mem.s: the same classes, lists, cache and
# counter, so every program behaves the same on both targets.
#
# Defines:
#   sea_free         (global, entry FREE, rt.inc) free an object whose
#                    count has just reached 0
#   sea_alloc        (.globl + .hidden: internal, DESIGN.md 4.5) a block
#   sea_free_block   (.globl + .hidden) give a block back
#   sea_retain       (.globl + .hidden) count + 1 (runtime code)
#   sea_release      (.globl + .hidden) count - 1, sea_free at 0
#   sea_live         (.globl + .hidden) u64: arrays, strings and handles
#                    allocated and not yet freed
#   sea_freed        (.globl + .hidden) u64: arrays, strings and handles
#                    freed so far. sea_live + sea_freed is the number
#                    of objects ever created (the `count` mode of SEA_HEAP_CHECK):
#                    every constructor counts its object in sea_live and
#                    nothing but sea_free uncounts one, so the sum misses
#                    no creation path
# Uses: sea_err (rt_err.s); glibc mmap, munmap through the PLT.
#
# Blocks and classes (DESIGN.md 4.1). A request of b bytes takes the
# class 2^k, the least power of two >= max(b, 32) (k >= RT_MEM_K_MIN).
# The classes up to SEA_SMALL_MAX_BYTES (k <= RT_MEM_K_SMALL) are small:
# each has a LIFO free list (the link is the first word of a free block)
# and is refilled, when the list is empty, from one fresh
# SEA_CHUNK_BYTES chunk (mmap, page-aligned) carved into blocks of the
# class in ascending address order (carved lazily: a cursor and an end
# per class, so a block is handed out only when it is needed); chunks
# are never unmapped. Every small block is aligned to its class size.
# The larger classes are large: a block is one mmap of exactly its class
# size (page-aligned). A freed large block goes into the cache of its
# class (a LIFO list, the link again in its first word) while that class
# holds fewer than SEA_LCACHE_PER_CLASS blocks and the cache holds at most
# SEA_LCACHE_MAX_BYTES with it; otherwise it is unmapped. An allocation
# of a large class takes the most recently freed cached block of that
# class first. A request above RT_MEM_MAX_REQ (2^62) bytes, or an mmap
# that fails, is sea_err(SEA_E_OUT_OF_MEMORY, site).
#
# The blocks know nothing about their size: whoever frees a block passes
# the same byte count it was allocated with (an array: SEA_ARR_SIZE +
# SEA_ARR_CAP * SEA_ARR_ESIZE; a string: SEA_STR_BYTES + SEA_STR_LEN),
# which gives the same class.
#
# The live-object counter (DESIGN.md 4.1, 4.5 SEA_HEAP_CHECK) counts
# objects, not blocks: the constructors of rt_arr.s, rt_str.s, rt_args.s,
# rt_fmt.s, rt_lu.s and rt_plot.s add 1 per array, string or handle they create,
# sea_free subtracts 1 per object it frees. Static objects (count
# SEA_RC_STATIC) are never counted or freed.
#
# Linux values (DESIGN.md 4.7.1; private to the runtime): mmap(NULL, n,
# PROT_READ|PROT_WRITE = 3, MAP_PRIVATE|MAP_ANONYMOUS = 0x22, -1, 0),
# failure (void *) -1; munmap(addr, n).
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

.equ RT_MEM_PROT_RW,    3           # PROT_READ | PROT_WRITE
.equ RT_MEM_MAP_PRIVANON, 0x22      # MAP_PRIVATE | MAP_ANONYMOUS
.equ RT_MEM_K_MIN,      5           # the smallest class: 2^5 = 32 bytes
.equ RT_MEM_MIN_BYTES,  32          # = 1 << RT_MEM_K_MIN
.equ RT_MEM_K_SMALL,    12          # the largest small class: 2^12 = SEA_SMALL_MAX_BYTES
.equ RT_MEM_MAX_REQ,    0x4000000000000000 # 2^62: the largest request that is attempted
.equ RT_MEM_NCLASS,     64          # per-class tables are indexed by k = 0 .. 63
# A handle's private layout (rt_lu.s, DESIGN.md 2.13.6 "Handles", L-is):
# n at offset 16, the factor (n x n doubles, then an Lu's n u32 pivots)
# at offset 64.
.equ RT_MEM_H_N,        SEA_OBJ_HDR
.equ RT_MEM_H_F,        (SEA_OBJ_HDR + 48)
# The plotting objects' private layouts (rt_plot.s, DESIGN.md 2.14.6
# "Objects", L-kw; the same offsets as rt_plot.s's RTP_*). Figure: the
# name, the axes table (count, capacity, block of RT_MEM_AX_SIZE-byte
# records), the series table (count, capacity, block of
# RT_MEM_SR_SIZE-byte records); RT_MEM_FG_SIZE bytes in all. Axes: the
# figure (a counted reference); RT_MEM_AH_SIZE bytes.
.equ RT_MEM_FG_NAME,    48
.equ RT_MEM_FG_NAX,     56
.equ RT_MEM_FG_AXCAP,   64
.equ RT_MEM_FG_AXT,     72
.equ RT_MEM_FG_NSR,     80
.equ RT_MEM_FG_SRCAP,   88
.equ RT_MEM_FG_SRT,     96
.equ RT_MEM_FG_SIZE,    704
.equ RT_MEM_AH_FIG,     16
.equ RT_MEM_AH_SIZE,    32
# Axes record: the three strings, the two category label blocks and
# their counts.
.equ RT_MEM_AX_TITLE,   56
.equ RT_MEM_AX_XLAB,    64
.equ RT_MEM_AX_YLAB,    72
.equ RT_MEM_AX_XCAT,    128
.equ RT_MEM_AX_NXCAT,   136
.equ RT_MEM_AX_YCAT,    144
.equ RT_MEM_AX_NYCAT,   152
.equ RT_MEM_AX_SIZE,    256
# Series record: kind, label, n, m, the data block.
.equ RT_MEM_SR_KIND,    0
.equ RT_MEM_SR_LABEL,   48
.equ RT_MEM_SR_N,       56
.equ RT_MEM_SR_M,       64
.equ RT_MEM_SR_DATA,    72
.equ RT_MEM_SR_SIZE,    128
# Series kinds whose data block size differs (DESIGN.md 2.14.6 "Block
# sizes"): line and bar 16n, barh 8n, contour and image 8(n + m + nm).
.equ RT_MEM_SK_BARH,    4

.if (1 << RT_MEM_K_SMALL) != SEA_SMALL_MAX_BYTES
    .error "rt_mem: RT_MEM_K_SMALL does not match SEA_SMALL_MAX_BYTES"
.endif
.if (1 << RT_MEM_K_MIN) != RT_MEM_MIN_BYTES
    .error "rt_mem: RT_MEM_K_MIN does not match RT_MEM_MIN_BYTES"
.endif
.if (SEA_CHUNK_BYTES % SEA_SMALL_MAX_BYTES) != 0
    .error "rt_mem: SEA_CHUNK_BYTES is not a multiple of every small class"
.endif

    .text

# RT_MEM_CLASS -- the class exponent of a request (inline).
#   Inputs : \bytes = the request (a register, not %rcx), 1 .. 2^62
#   Outputs: %ecx = k, the least k >= RT_MEM_K_MIN with 2^k >= bytes
#   Clobbers: %rcx, flags
.macro RT_MEM_CLASS bytes
    movl $RT_MEM_K_MIN, %ecx
    cmpq $RT_MEM_MIN_BYTES, \bytes
    jbe 1f                          # up to 32 bytes: the smallest class
    leaq -1(\bytes), %rcx
    bsrq %rcx, %rcx                 # index of the highest set bit of bytes - 1
    incl %ecx                       # k = that index + 1
1:
.endm

# ---------------------------------------------------------------------
# sea_alloc -- allocate a block (internal, DESIGN.md 4.1, 4.5).
#   Purpose : a block of at least `bytes` bytes from the class of the
#             request (file header); its contents are whatever the block
#             holds (a recycled block is not clean, a fresh one is zero).
#   Inputs  : %rdi = bytes (>= 0), %rsi = site index (or SEA_SITE_NONE)
#             reported by `out of memory`
#   Outputs : %rax = the block, aligned to min(class size, 4096) (every
#             class is >= 32 bytes; a large block is page-aligned)
#   Clobbers: all caller-saved registers (mmap may be called)
#   Callee-saved used: %rbx = k, %r12 = site, %rbp = frame pointer
#   Frame   : 24 bytes (%rbp %rbx %r12); %rsp = 0 (mod 16) at the calls
# ---------------------------------------------------------------------
    .globl sea_alloc
    .hidden sea_alloc
    .type sea_alloc, @function
    .p2align 4
sea_alloc:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rsi, %r12                 # site, for `out of memory`
    movabsq $RT_MEM_MAX_REQ, %rax
    cmpq %rax, %rdi
    ja .Lrt_mem_alloc_oom           # does not fit: out of memory
    RT_MEM_CLASS %rdi               # %ecx = k
    movl %ecx, %ebx
    leaq .Lrt_mem_free(%rip), %rdx
    cmpl $RT_MEM_K_SMALL, %ebx
    ja .Lrt_mem_alloc_large

    # Small: pop the free list of the class ...
    movq (%rdx,%rbx,8), %rax
    testq %rax, %rax
    jz 1f
    movq (%rax), %rcx               # the next free block
    movq %rcx, (%rdx,%rbx,8)
    jmp .Lrt_mem_alloc_ret
    # ... else carve the next block of the current chunk; a used-up (or
    # absent) chunk is replaced by a fresh one.
1:  leaq .Lrt_mem_cur(%rip), %rdx
    leaq .Lrt_mem_end(%rip), %rsi
    movq (%rdx,%rbx,8), %rax        # cursor
    cmpq (%rsi,%rbx,8), %rax
    jne 2f                          # room left in the chunk
    xorl %edi, %edi                 # mmap(NULL, SEA_CHUNK_BYTES, RW, PRIVATE|ANON, -1, 0)
    movl $SEA_CHUNK_BYTES, %esi
    movl $RT_MEM_PROT_RW, %edx
    movl $RT_MEM_MAP_PRIVANON, %ecx
    movl $-1, %r8d
    xorl %r9d, %r9d
    call mmap@PLT
    cmpq $-1, %rax
    je .Lrt_mem_alloc_oom           # MAP_FAILED
    leaq .Lrt_mem_end(%rip), %rsi
    leaq SEA_CHUNK_BYTES(%rax), %rcx
    movq %rcx, (%rsi,%rbx,8)        # the chunk's end
    leaq .Lrt_mem_cur(%rip), %rdx
2:  movl %ebx, %ecx
    movl $1, %esi
    shlq %cl, %rsi                  # the class size
    addq %rax, %rsi
    movq %rsi, (%rdx,%rbx,8)        # cursor += class size
    jmp .Lrt_mem_alloc_ret

    # Large: the most recently cached block of the class, else a fresh
    # mapping of the class size.
.Lrt_mem_alloc_large:
    leaq .Lrt_mem_lc_head(%rip), %rdx
    movq (%rdx,%rbx,8), %rax
    testq %rax, %rax
    jz 3f
    movq (%rax), %rcx               # unlink it
    movq %rcx, (%rdx,%rbx,8)
    leaq .Lrt_mem_lc_n(%rip), %rdx
    decq (%rdx,%rbx,8)              # one block fewer in the class
    movl %ebx, %ecx
    movl $1, %esi
    shlq %cl, %rsi
    subq %rsi, .Lrt_mem_lc_bytes(%rip) # and its bytes out of the cache
    jmp .Lrt_mem_alloc_ret
3:  movl %ebx, %ecx
    movl $1, %esi
    shlq %cl, %rsi                  # mmap(NULL, 2^k, RW, PRIVATE|ANON, -1, 0)
    xorl %edi, %edi
    movl $RT_MEM_PROT_RW, %edx
    movl $RT_MEM_MAP_PRIVANON, %ecx
    movl $-1, %r8d
    xorl %r9d, %r9d
    call mmap@PLT
    cmpq $-1, %rax
    je .Lrt_mem_alloc_oom
.Lrt_mem_alloc_ret:
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_mem_alloc_oom:
    movl $SEA_E_OUT_OF_MEMORY, %edi
    movq %r12, %rsi                 # the site of the allocating entry
    xorl %edx, %edx                 # no argument slots
    call sea_err                    # noreturn
    ud2
    .size sea_alloc, . - sea_alloc

# ---------------------------------------------------------------------
# sea_free_block -- give a block back (internal, DESIGN.md 4.1).
#   Purpose : a small block goes back on its class's free list; a large
#             block into the cache of its class while the class holds
#             fewer than SEA_LCACHE_PER_CLASS blocks and the cache holds
#             at most SEA_LCACHE_MAX_BYTES with it, else it is unmapped.
#   Inputs  : %rdi = the block (from sea_alloc), %rsi = the byte count
#             it was allocated with
#   Outputs : none
#   Clobbers: all caller-saved registers (munmap may be called)
#   Callee-saved used: %rbp = frame pointer
#   Frame   : 8 bytes (%rbp); %rsp = 0 (mod 16) at the call
# ---------------------------------------------------------------------
    .globl sea_free_block
    .hidden sea_free_block
    .type sea_free_block, @function
    .p2align 4
sea_free_block:
    pushq %rbp
    movq %rsp, %rbp
    RT_MEM_CLASS %rsi               # %ecx = k
    cmpl $RT_MEM_K_SMALL, %ecx
    ja 1f
    leaq .Lrt_mem_free(%rip), %rdx  # small: push on the free list
    movq (%rdx,%rcx,8), %rax
    movq %rax, (%rdi)               # link to the previous head
    movq %rdi, (%rdx,%rcx,8)
    jmp 3f
1:  movl $1, %esi
    shlq %cl, %rsi                  # %rsi = the class size (munmap's length too)
    leaq .Lrt_mem_lc_n(%rip), %rdx
    cmpq $SEA_LCACHE_PER_CLASS, (%rdx,%rcx,8)
    jae 2f                          # the class is full: unmap
    movq .Lrt_mem_lc_bytes(%rip), %rax
    addq %rsi, %rax
    cmpq $SEA_LCACHE_MAX_BYTES, %rax
    ja 2f                           # the cache would exceed its bytes: unmap
    movq %rax, .Lrt_mem_lc_bytes(%rip)
    incq (%rdx,%rcx,8)
    leaq .Lrt_mem_lc_head(%rip), %rdx # push on the class's cache list
    movq (%rdx,%rcx,8), %rax
    movq %rax, (%rdi)
    movq %rdi, (%rdx,%rcx,8)
    jmp 3f
2:  call munmap@PLT                 # (%rdi = block, %rsi = class size); cannot fail for a whole mapping
3:  popq %rbp
    ret
    .size sea_free_block, . - sea_free_block

# ---------------------------------------------------------------------
# sea_retain -- count + 1 (internal, for runtime code).
#   Inputs  : %rdi = an object, or 0
#   Outputs : none; a null pointer and a static object (count
#             SEA_RC_STATIC) are left alone
#   Clobbers: %rax, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .globl sea_retain
    .hidden sea_retain
    .type sea_retain, @function
    .p2align 4
sea_retain:
    testq %rdi, %rdi
    jz 1f                           # null: nothing to count
    movq SEA_OBJ_RC(%rdi), %rax
    testq %rax, %rax                # SEA_RC_STATIC (0): never counted
    jz 1f
    incq SEA_OBJ_RC(%rdi)
1:  ret
    .size sea_retain, . - sea_retain

# ---------------------------------------------------------------------
# sea_release -- count - 1, and sea_free when it reaches 0 (internal).
#   Inputs  : %rdi = an object, or 0
#   Outputs : none; a null pointer and a static object are left alone
#   Clobbers: all caller-saved registers (sea_free may run)
#   Callee-saved used: none
#   Frame   : none (a tail jump to sea_free)
# ---------------------------------------------------------------------
    .globl sea_release
    .hidden sea_release
    .type sea_release, @function
    .p2align 4
sea_release:
    testq %rdi, %rdi
    jz 1f                           # null
    movq SEA_OBJ_RC(%rdi), %rax
    testq %rax, %rax
    jz 1f                           # static
    decq %rax
    movq %rax, SEA_OBJ_RC(%rdi)
    jz sea_free                     # the last count: free it (tail call)
1:  ret
    .size sea_release, . - sea_release

# ---------------------------------------------------------------------
# sea_free -- free an object whose count has just reached 0 (entry FREE,
#   DESIGN.md 4.8).
#   Purpose : an array (SEA_TAG_ARRAY) first releases what it refers to:
#             each non-null `str` element (SEA_EK_STR), or each non-null
#             reference field of each struct element (SEA_EK_STRUCT; the
#             offsets SEA_SL_REFS of its descriptor SEA_ARR_SLAY), with
#             sea_release (static and null references skipped); then its
#             block (SEA_ARR_SIZE + SEA_ARR_CAP * SEA_ARR_ESIZE bytes) is
#             freed. A string (SEA_TAG_STR) frees its block (SEA_STR_BYTES
#             + SEA_STR_LEN bytes). A handle (SEA_TAG_LU or SEA_TAG_CHOL,
#             L-is; the private layout of rt_lu.s: n at RT_MEM_H_N, the
#             factor at RT_MEM_H_F) holds no references: its block (64 +
#             8n^2 bytes, + 4n pivot bytes for an Lu) is freed. An Axes
#             (SEA_TAG_AXES, L-lb) releases its figure with sea_release
#             (which frees the figure at 0), then its RT_MEM_AH_SIZE
#             block is freed. A Figure (SEA_TAG_FIGURE) releases its
#             name and every string it retained (each axes record's
#             title, labels and category labels, each series' label),
#             frees every uncounted block it owns by its exact size (the
#             series' data blocks, the category label blocks, the axes
#             and series tables; DESIGN.md 2.14.6), then its
#             RT_MEM_FG_SIZE block. Any other tag traps (ud2; arm64:
#             brk): no other object exists.
#             The live count drops by one and the freed count rises by
#             one, for every object.
#   Inputs  : %rdi = the object (never static, never null)
#   Outputs : none; cannot fail
#   Clobbers: all caller-saved registers
#   Callee-saved used (all saved and restored): %rbx = the object,
#             %r12 = elements (records) left, %r13 = current element (record), %r14 = the
#             struct descriptor, %r15 = index of the reference field,
#             %rbp = frame pointer; 0(%rsp) = element size
#   Frame   : 56 bytes (%rbp %rbx %r12-%r15) + 8 (element size) = 64;
#             %rsp = 0 (mod 16) at the calls
# ---------------------------------------------------------------------
    .globl sea_free
    .type sea_free, @function
    .p2align 4
sea_free:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    cmpb $SEA_TAG_ARRAY, SEA_OBJ_TAG(%rbx)
    jne .Lrt_mem_free_str

    # An array: the number of elements and the first one.
    movq SEA_ARR_ROWS(%rbx), %r12
    imulq SEA_ARR_COLS(%rbx), %r12  # rows * cols (< 2^62)
    movq SEA_ARR_DATA(%rbx), %r13
    movzbl SEA_ARR_EK(%rbx), %eax
    cmpl $SEA_EK_STR, %eax
    je .Lrt_mem_free_strs
    cmpl $SEA_EK_STRUCT, %eax
    je .Lrt_mem_free_structs
    jmp .Lrt_mem_free_arr           # numeric elements hold no references

    # str[]: release each element.
.Lrt_mem_free_strs:
    testq %r12, %r12
    jz .Lrt_mem_free_arr
    movq (%r13), %rdi
    call sea_release                # skips null and static strings
    addq $SEA_ESIZE_PTR, %r13
    decq %r12
    jmp .Lrt_mem_free_strs

    # Struct elements: release each reference field of each element.
.Lrt_mem_free_structs:
    movq SEA_ARR_SLAY(%rbx), %r14
    movq SEA_ARR_ESIZE(%rbx), %rax
    movq %rax, 0(%rsp)              # the element size
.Lrt_mem_free_elem:
    testq %r12, %r12
    jz .Lrt_mem_free_arr            # every element done
    xorl %r15d, %r15d               # index of the reference field
.Lrt_mem_free_field:
    cmpq SEA_SL_NREF(%r14), %r15
    jae .Lrt_mem_free_elem_next     # this element's fields are done
    movq SEA_SL_REFS(%r14,%r15,8), %rax # the field's byte offset
    movq (%r13,%rax), %rdi
    call sea_release                # skips null and static references
    incq %r15
    jmp .Lrt_mem_free_field
.Lrt_mem_free_elem_next:
    addq 0(%rsp), %r13              # the next element
    decq %r12
    jmp .Lrt_mem_free_elem

    # The array's own block.
.Lrt_mem_free_arr:
    movq SEA_ARR_CAP(%rbx), %rsi
    imulq SEA_ARR_ESIZE(%rbx), %rsi
    addq $SEA_ARR_SIZE, %rsi        # the byte count it was allocated with
    jmp .Lrt_mem_free_block

    # A string.
.Lrt_mem_free_str:
    cmpb $SEA_TAG_STR, SEA_OBJ_TAG(%rbx)
    jne .Lrt_mem_free_handle        # not a string: a handle, or a runtime bug
    movq SEA_STR_LEN(%rbx), %rsi
    addq $SEA_STR_BYTES, %rsi
    jmp .Lrt_mem_free_block

    # The plotting handles (L-lb).
.Lrt_mem_free_handle:
    cmpb $SEA_TAG_AXES, SEA_OBJ_TAG(%rbx)
    je .Lrt_mem_free_axes
    cmpb $SEA_TAG_FIGURE, SEA_OBJ_TAG(%rbx)
    je .Lrt_mem_free_figure
    # A factorization handle (L-is): 64 + 8n^2 bytes, + 4n pivot bytes
    # for an Lu.
    movq RT_MEM_H_N(%rbx), %rcx     # n
    movq %rcx, %rsi
    imulq %rcx, %rsi
    shlq $3, %rsi                   # the factor: 8n^2
    addq $RT_MEM_H_F, %rsi          # after the header and fields
    cmpb $SEA_TAG_CHOL, SEA_OBJ_TAG(%rbx)
    je .Lrt_mem_free_block          # a Chol: no pivots
    cmpb $SEA_TAG_LU, SEA_OBJ_TAG(%rbx)
    jne .Lrt_mem_free_bad           # no other object exists: a runtime bug
    leaq (%rsi,%rcx,4), %rsi        # an Lu: + the n u32 pivots
.Lrt_mem_free_block:
    movq %rbx, %rdi
    call sea_free_block
    decq sea_live(%rip)             # one object fewer
    incq sea_freed(%rip)            # and one more freed (allocations = live + freed)
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_mem_free_bad:
    ud2                             # trap: no such object (a runtime bug)

    # An Axes (L-lb): release its figure (sea_free runs for it when that
    # was the last reference), then its own 32-byte block.
.Lrt_mem_free_axes:
    movq RT_MEM_AH_FIG(%rbx), %rdi
    call sea_release
    movl $RT_MEM_AH_SIZE, %esi
    jmp .Lrt_mem_free_block

    # A Figure (L-lb): its name, then per axes record its three strings
    # and both category label lists, the axes table, then per series
    # record its label and data block, the series table, and last the
    # figure's own block. Every block is freed with its exact size
    # (DESIGN.md 2.14.6 "Block sizes"); a 0 pointer is a block that was
    # never allocated.
.Lrt_mem_free_figure:
    movq RT_MEM_FG_NAME(%rbx), %rdi
    call sea_release                # the name (static or null: left alone)
    movq RT_MEM_FG_AXT(%rbx), %r13  # the first axes record
    movq RT_MEM_FG_NAX(%rbx), %r12  # records left
.Lrt_mem_free_fig_ax:
    testq %r12, %r12
    jz .Lrt_mem_free_fig_axt
    movq RT_MEM_AX_TITLE(%r13), %rdi
    call sea_release
    movq RT_MEM_AX_XLAB(%r13), %rdi
    call sea_release
    movq RT_MEM_AX_YLAB(%r13), %rdi
    call sea_release
    movq RT_MEM_AX_XCAT(%r13), %rdi # the x category labels
    movq RT_MEM_AX_NXCAT(%r13), %rsi
    call .Lrt_mem_free_labels
    movq RT_MEM_AX_YCAT(%r13), %rdi # the y category labels
    movq RT_MEM_AX_NYCAT(%r13), %rsi
    call .Lrt_mem_free_labels
    addq $RT_MEM_AX_SIZE, %r13
    decq %r12
    jmp .Lrt_mem_free_fig_ax
.Lrt_mem_free_fig_axt:
    movq RT_MEM_FG_AXT(%rbx), %rdi  # the axes table: 256 x its capacity
    movq RT_MEM_FG_AXCAP(%rbx), %rsi
    shlq $8, %rsi
    call sea_free_block
    movq RT_MEM_FG_SRT(%rbx), %r13  # the first series record
    movq RT_MEM_FG_NSR(%rbx), %r12  # records left
.Lrt_mem_free_fig_sr:
    testq %r12, %r12
    jz .Lrt_mem_free_fig_srt
    movq RT_MEM_SR_LABEL(%r13), %rdi
    call sea_release                # the label (0 for "")
    movq RT_MEM_SR_DATA(%r13), %rdi
    testq %rdi, %rdi
    jz 3f                           # no data block (an xline, an empty series)
    movq RT_MEM_SR_N(%r13), %rsi    # n
    movq RT_MEM_SR_KIND(%r13), %rax
    cmpq $RT_MEM_SK_BARH, %rax
    jb 1f                           # line (1), bar (3): 16n
    je 2f                           # barh: 8n
    movq RT_MEM_SR_M(%r13), %rcx    # contour, image: 8(n + m + nm)
    movq %rsi, %rax
    imulq %rcx, %rax                # nm
    addq %rcx, %rsi
    addq %rax, %rsi
    shlq $3, %rsi
    jmp 4f
1:  shlq $4, %rsi                   # 16n: x then y (or h)
    jmp 4f
2:  shlq $3, %rsi                   # 8n: h
4:  call sea_free_block
3:  addq $RT_MEM_SR_SIZE, %r13
    decq %r12
    jmp .Lrt_mem_free_fig_sr
.Lrt_mem_free_fig_srt:
    movq RT_MEM_FG_SRT(%rbx), %rdi  # the series table: 128 x its capacity
    movq RT_MEM_FG_SRCAP(%rbx), %rsi
    shlq $7, %rsi
    call sea_free_block
    movl $RT_MEM_FG_SIZE, %esi      # the figure's own block
    jmp .Lrt_mem_free_block
    .size sea_free, . - sea_free

# ---------------------------------------------------------------------
# .Lrt_mem_free_labels -- release a category label list and free its
#   block (sea_free's Figure branch, L-lb).
#   Inputs  : %rdi = the block of string pointers (0 when the count is
#             0: never allocated), %rsi = the count
#   Outputs : none
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = the block, %r12 =
#             the count, %r13 = the index, %rbp = frame pointer
#   Frame   : 40 bytes (%rbp %rbx %r12 %r13 + 8 pad); %rsp = 0 (mod 16)
#             at the calls
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_mem_free_labels:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    testq %rdi, %rdi
    jz 2f                           # an empty list: nothing allocated
    movq %rdi, %rbx
    movq %rsi, %r12
    xorl %r13d, %r13d
1:  movq (%rbx,%r13,8), %rdi        # each label, retained by X_TICKS / Y_TICKS
    call sea_release
    incq %r13
    cmpq %r12, %r13
    jb 1b
    movq %rbx, %rdi                 # the block: 8 x the count
    leaq (,%r12,8), %rsi
    call sea_free_block
2:  addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

    .bss
    .p2align 3
    .globl sea_live
    .hidden sea_live
    .type sea_live, @object
    .size sea_live, 8
sea_live:
    .zero 8                         # arrays, strings and handles allocated and not yet freed
    .globl sea_freed
    .hidden sea_freed
    .type sea_freed, @object
    .size sea_freed, 8
sea_freed:
    .zero 8                         # arrays, strings and handles freed so far
.Lrt_mem_free:
    .zero 8 * RT_MEM_NCLASS         # small classes: head of the free list, by k
.Lrt_mem_cur:
    .zero 8 * RT_MEM_NCLASS         # small classes: next block to carve, by k
.Lrt_mem_end:
    .zero 8 * RT_MEM_NCLASS         # small classes: end of the current chunk, by k
.Lrt_mem_lc_head:
    .zero 8 * RT_MEM_NCLASS         # large classes: head of the cache list, by k
.Lrt_mem_lc_n:
    .zero 8 * RT_MEM_NCLASS         # large classes: blocks in the cache, by k
.Lrt_mem_lc_bytes:
    .zero 8                         # bytes of all cached large blocks

    .section .note.GNU-stack,"",@progbits
