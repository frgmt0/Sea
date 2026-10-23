# =====================================================================
# sea/runtime/x86_64_linux/rt_sort.s -- sorting (DESIGN.md 4.5, 4.7.1,
# 4.8 entries SORT and ARGSORT, "The sort entries in detail"; LANGUAGE.md
# 10.6). The x86_64-linux twin of runtime/arm64_macos/rt_sort.s: the same
# keys, algorithms, scratch block and results, so both targets give the
# same bytes.
#
# Defines (global, rt.inc SEA_ENTRY_LIST):
#   sea_sort    (v, desc, site) -> a new vector of v's elements in the
#               stable order of LANGUAGE.md 10.6
#   sea_argsort (v, desc, site) -> a new i64 vector p (0-based) such that
#               v[p[0]], v[p[1]], ... is that order
# Uses: sea_arr_new (rt_arr.s), sea_alloc, sea_free_block, sea_retain
#   (rt_mem.s), sea_str_cmp (rt_str.s).
#
# v is a vector of ek SEA_EK_F64, SEA_EK_I64 or SEA_EK_STR, borrowed and
# never written; desc is 0 (ascending) or 1 (descending). The result is a
# new vector with count 1 (sea_arr_new of v's ek, or SEA_EK_I64 for
# argsort; rank 1, rows n, cols 1), also for n = 0 and n = 1.
#
# Keys (f64, i64). For an f64 element with bits b: every NaN (exponent
# all ones, mantissa not 0, either sign) becomes #7FF8000000000000 and -0
# (#8000000000000000) becomes 0; then key = b XOR #FFFFFFFFFFFFFFFF if b's
# sign bit is set, else b XOR #8000000000000000. For an i64 element key =
# b XOR #8000000000000000. With desc 1, key = NOT key. Unsigned key order
# is the order of LANGUAGE.md 10.6 (NaN above +inf ascending, below -inf
# descending, +-0 one key), and a stable sort on the keys keeps equal
# elements in input order in both directions.
#
# Algorithm. n <= RT_SORT_SMALL (32): a stable insertion sort of (key,
# index) pairs, held as a key array of 8n bytes followed by a 32-bit
# index array of 4n bytes (12n bytes rounded up to 8). Otherwise an LSD
# radix sort with 8 passes of 8 bits from the least significant byte, on
# a key array and a 32-bit index array (extents are below 2^31), ping-
# ponged between two buffers of each; the 8 histograms of 256 u64 counts
# are counted in one pass over the keys, and a pass whose byte is the
# same for every key is skipped. sort then gathers v[index[k]] (the
# original bits: -0, the NaN payloads and signs are kept); argsort writes
# the indices as i64. str (both entries): a stable bottom-up merge sort
# of 32-bit indices in STR_CMP's order (reversed for desc, ties keeping
# input order), ping-ponged between two index buffers; sort stores the
# gathered string pointers and retains each.
#
# Scratch. One block from sea_alloc for n >= 2 (none for n <= 1):
#   f64/i64, n <= 32 : keys 8n, indices 4n           = 12n rounded to 8
#   f64/i64, n > 32  : histograms RT_SORT_HIST_BYTES (16384), keys A, B
#                      (8n each), indices A, B (4n each) = 24n + 16384
#   str              : indices A, B (4n each)        = 8n
# The result is allocated first, then the scratch; the scratch is freed
# with sea_free_block before the entry returns, so the live-object count
# changes only by the result. A failed allocation of either is
# sea_err(SEA_E_OUT_OF_MEMORY, site) through sea_alloc's own path
# (rt_arr.s for the result); nothing else fails.
#
# Stack (below the return address of the entry). The entries jump to
# .Lrt_sort_common (104 bytes); below it .Lrt_sort_radix (8 return + 48)
# or .Lrt_sort_merge (8 return + 104), so at most 216 bytes belong to
# this file (DESIGN.md 4.8: at most 256); .Lrt_sort_keys and
# .Lrt_sort_insert are leaves without a frame.
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

.equ RT_SORT_SMALL,      32         # n <= this: insertion sort
.equ RT_SORT_HIST_BYTES, 16384      # 8 histograms * 256 counts * 8 bytes
.equ RT_SORT_HIST_ONE,   2048       # one histogram: 256 counts * 8 bytes

.if SEA_LIM_EXTENT > 0x7FFFFFFF
    .error "rt_sort: 32-bit indices need extents below 2^31"
.endif

# .Lrt_sort_common's locals (offsets from %rsp after its prologue).
.equ RT_SORT_C_DESC,     0          # desc mask: 0 or all ones
.equ RT_SORT_C_SITE,     8          # the site
.equ RT_SORT_C_MODE,     16         # 0 sort, 1 argsort
.equ RT_SORT_C_BYTES,    24         # the scratch block's request in bytes
.equ RT_SORT_C_RDATA,    32         # the result's elements
.equ RT_SORT_C_EK,       40         # v's element kind
.equ RT_SORT_C_K,        48         # the str gather's cursor
.equ RT_SORT_C_FRAME,    56         # bytes of locals: %rsp = 0 (mod 16) after them

# .Lrt_sort_merge's locals.
.equ RT_SORT_M_N,        0          # n
.equ RT_SORT_M_W,        8          # run width
.equ RT_SORT_M_LO,       16         # the start of the left run
.equ RT_SORT_M_MID,      24         # the end of the left run
.equ RT_SORT_M_HI,       32         # the end of the right run
.equ RT_SORT_M_K,        40         # output cursor
.equ RT_SORT_M_DESC,     48         # desc mask
.equ RT_SORT_M_FRAME,    56

    .text

# ---------------------------------------------------------------------
# sea_sort -- the entry SORT.
#   Inputs  : %rdi = v, %rsi = desc (0 or 1), %rdx = site
#   Outputs : %rax = the sorted vector (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used: none here (.Lrt_sort_common saves what it uses)
#   Frame   : none (a jump to .Lrt_sort_common with %rcx = 0)
# ---------------------------------------------------------------------
    .globl sea_sort
    .type sea_sort, @function
    .p2align 4
sea_sort:
    xorl %ecx, %ecx                 # mode 0: the sorted values
    jmp .Lrt_sort_common
    .size sea_sort, . - sea_sort

# ---------------------------------------------------------------------
# sea_argsort -- the entry ARGSORT.
#   Inputs  : %rdi = v, %rsi = desc (0 or 1), %rdx = site
#   Outputs : %rax = the i64 permutation vector (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used: none here
#   Frame   : none (a jump to .Lrt_sort_common with %rcx = 1)
# ---------------------------------------------------------------------
    .globl sea_argsort
    .type sea_argsort, @function
    .p2align 4
sea_argsort:
    movl $1, %ecx                   # mode 1: the permutation
    jmp .Lrt_sort_common
    .size sea_argsort, . - sea_argsort

# ---------------------------------------------------------------------
# .Lrt_sort_common -- both entries (see the file header).
#   Inputs  : %rdi = v, %rsi = desc (0 or 1), %rdx = site, %rcx = mode
#             (0 sort, 1 argsort)
#   Outputs : %rax = the result vector (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = v, then the final
#             index buffer of the str gather; %r12 = n, %r13 = the result,
#             %r14 = the scratch block, %r15 = v's elements, %rbp = frame
#             pointer; locals RT_SORT_C_* at 0(%rsp)
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + RT_SORT_C_FRAME = 104 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_sort_common:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15                      # %rsp = 8 (mod 16)
    subq $RT_SORT_C_FRAME, %rsp     # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    negq %rsi                       # desc 0 -> 0, desc 1 -> all ones
    movq %rsi, RT_SORT_C_DESC(%rsp)
    movq %rdx, RT_SORT_C_SITE(%rsp)
    movq %rcx, RT_SORT_C_MODE(%rsp)
    movq SEA_ARR_ROWS(%rbx), %r12
    imulq SEA_ARR_COLS(%rbx), %r12  # n (cols is 1 for a vector)
    movzbl SEA_ARR_EK(%rbx), %edi
    movq %rdi, RT_SORT_C_EK(%rsp)

    # The result first: v's ek for sort, i64 for argsort; rank 1, n x 1.
    movl $SEA_EK_I64, %eax
    testq %rcx, %rcx
    cmovnel %eax, %edi
    movl $1, %esi
    movq %r12, %rdx
    movl $1, %ecx
    movq RT_SORT_C_SITE(%rsp), %r8
    call sea_arr_new                # noreturn on failure
    movq %rax, %r13
    movq SEA_ARR_DATA(%rbx), %r15   # v's elements (8 bytes each)
    movq SEA_ARR_DATA(%r13), %rax
    movq %rax, RT_SORT_C_RDATA(%rsp) # the result's elements
    cmpq $1, %r12
    ja .Lrt_sort_common_many
    testq %r12, %r12
    jz .Lrt_sort_common_done        # n = 0: the empty vector

    # n = 1: no scratch. argsort: [0]; sort: v[0], retained if a str.
    movq RT_SORT_C_RDATA(%rsp), %rdx
    cmpq $0, RT_SORT_C_MODE(%rsp)
    je 1f
    movq $0, (%rdx)
    jmp .Lrt_sort_common_done
1:  movq (%r15), %rdi
    movq %rdi, (%rdx)               # the element's bits unchanged
    cmpq $SEA_EK_STR, RT_SORT_C_EK(%rsp)
    jne .Lrt_sort_common_done
    call sea_retain                 # the result holds one more count
    jmp .Lrt_sort_common_done

.Lrt_sort_common_many:
    cmpq $SEA_EK_STR, RT_SORT_C_EK(%rsp)
    je .Lrt_sort_common_str
    cmpq $RT_SORT_SMALL, %r12
    ja .Lrt_sort_common_radix

    # f64/i64, 2 <= n <= 32: keys (8n) and indices (4n), 12n rounded to 8.
    leaq (%r12,%r12,2), %rdi        # 3n
    shlq $2, %rdi                   # 12n
    addq $7, %rdi
    andq $-8, %rdi
    movq %rdi, RT_SORT_C_BYTES(%rsp)
    movq RT_SORT_C_SITE(%rsp), %rsi
    call sea_alloc                  # noreturn on failure
    movq %rax, %r14
    movq %r14, %rdi                 # keys at the start of the block
    leaq (%r14,%r12,8), %rsi        # indices after the 8n key bytes
    movq %r15, %rdx
    movq %r12, %rcx
    movl RT_SORT_C_EK(%rsp), %r8d
    movq RT_SORT_C_DESC(%rsp), %r9
    call .Lrt_sort_keys
    movq %r14, %rdi
    leaq (%r14,%r12,8), %rsi
    movq %r12, %rdx
    call .Lrt_sort_insert
    leaq (%r14,%r12,8), %rax        # the sorted indices
    jmp .Lrt_sort_common_gather

.Lrt_sort_common_radix:
    # f64/i64, n > 32: histograms, keys A and B, indices A and B.
    leaq (%r12,%r12,2), %rdi        # 3n
    shlq $3, %rdi                   # 24n
    addq $RT_SORT_HIST_BYTES, %rdi
    movq %rdi, RT_SORT_C_BYTES(%rsp)
    movq RT_SORT_C_SITE(%rsp), %rsi
    call sea_alloc                  # noreturn on failure
    movq %rax, %r14
    leaq RT_SORT_HIST_BYTES(%r14), %rdi # keys A after the histograms
    movq %r12, %rax
    shlq $4, %rax
    leaq (%rdi,%rax), %rsi          # indices A after keys A and B
    movq %r15, %rdx
    movq %r12, %rcx
    movl RT_SORT_C_EK(%rsp), %r8d
    movq RT_SORT_C_DESC(%rsp), %r9
    call .Lrt_sort_keys
    movq %r14, %rdi
    movq %r12, %rsi
    call .Lrt_sort_radix            # %rax = the buffer of the sorted indices

.Lrt_sort_common_gather:
    # %rax = the 32-bit indices in sorted order.
    movq RT_SORT_C_RDATA(%rsp), %rdx
    cmpq $0, RT_SORT_C_MODE(%rsp)
    jne .Lrt_sort_common_perm
    xorl %ecx, %ecx                 # k
2:  movl (%rax,%rcx,4), %r8d        # index[k]
    movq (%r15,%r8,8), %r9          # v[index[k]], its original bits
    movq %r9, (%rdx,%rcx,8)
    incq %rcx
    cmpq %r12, %rcx
    jb 2b
    jmp .Lrt_sort_common_free

.Lrt_sort_common_perm:
    # argsort: the indices as i64 (%rax = indices, %rdx = the result's
    # elements).
    xorl %ecx, %ecx
3:  movl (%rax,%rcx,4), %r8d        # zero-extended to 64 bits
    movq %r8, (%rdx,%rcx,8)
    incq %rcx
    cmpq %r12, %rcx
    jb 3b

.Lrt_sort_common_free:
    movq %r14, %rdi
    movq RT_SORT_C_BYTES(%rsp), %rsi # the request it was allocated with
    call sea_free_block
.Lrt_sort_common_done:
    movq %r13, %rax
    addq $RT_SORT_C_FRAME, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

.Lrt_sort_common_str:
    # str, n >= 2: indices A and B, 4n bytes each.
    leaq (,%r12,8), %rdi            # 8n
    movq %rdi, RT_SORT_C_BYTES(%rsp)
    movq RT_SORT_C_SITE(%rsp), %rsi
    call sea_alloc                  # noreturn on failure
    movq %rax, %r14
    movq %r15, %rdi                 # the string pointers
    movq %r14, %rsi                 # indices A
    leaq (%r14,%r12,4), %rdx        # indices B
    movq %r12, %rcx
    movq RT_SORT_C_DESC(%rsp), %r8
    call .Lrt_sort_merge            # %rax = the buffer of the sorted indices
    movq RT_SORT_C_RDATA(%rsp), %rdx
    cmpq $0, RT_SORT_C_MODE(%rsp)
    jne .Lrt_sort_common_perm
    # sort: gather the pointers; each gains the result's count.
    movq %rax, %rbx                 # v is no longer needed (%r15 holds its elements)
    movq $0, RT_SORT_C_K(%rsp)
4:  movq RT_SORT_C_K(%rsp), %rcx
    movl (%rbx,%rcx,4), %eax
    movq (%r15,%rax,8), %rdi        # v[index[k]]
    movq RT_SORT_C_RDATA(%rsp), %rdx
    movq %rdi, (%rdx,%rcx,8)
    call sea_retain                 # static strings unchanged
    movq RT_SORT_C_K(%rsp), %rcx
    incq %rcx
    movq %rcx, RT_SORT_C_K(%rsp)
    cmpq %r12, %rcx
    jb 4b
    jmp .Lrt_sort_common_free

# ---------------------------------------------------------------------
# .Lrt_sort_keys -- the keys and the identity indices (file header).
#   Inputs  : %rdi = key array (8n bytes), %rsi = index array (4n bytes),
#             %rdx = v's elements, %rcx = n (>= 1), %r8d = ek
#             (SEA_EK_F64 or SEA_EK_I64), %r9 = desc mask (0 or all ones)
#   Outputs : key[k] = the key of element k, index[k] = k
#   Clobbers: %rax, %r8, %r10, %r11, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_sort_keys:
    xorl %eax, %eax                 # k
    cmpl $SEA_EK_F64, %r8d
    jne .Lrt_sort_keys_i64
.Lrt_sort_keys_f64:
    movq (%rdx,%rax,8), %r10        # the element's bits b
    movq %r10, %r11
    btrq $63, %r11                  # b without its sign
    cmpq .Lrt_sort_inf(%rip), %r11
    cmovaq .Lrt_sort_nan(%rip), %r10 # every NaN -> #7FF8000000000000
    xorl %r11d, %r11d
    cmpq .Lrt_sort_sign(%rip), %r10
    cmoveq %r11, %r10               # -0 -> +0
    movq %r10, %r11
    sarq $63, %r11                  # all ones if negative, else 0
    btsq $63, %r11                  # negative: invert all; else flip the sign
    xorq %r11, %r10
    xorq %r9, %r10                  # desc: NOT key
    movq %r10, (%rdi,%rax,8)
    movl %eax, (%rsi,%rax,4)        # index k
    incq %rax
    cmpq %rcx, %rax
    jb .Lrt_sort_keys_f64
    ret
.Lrt_sort_keys_i64:
    movq .Lrt_sort_sign(%rip), %r8  # the sign bit
1:  movq (%rdx,%rax,8), %r10
    xorq %r8, %r10                  # the sign flip: signed order as unsigned
    xorq %r9, %r10                  # desc: NOT key
    movq %r10, (%rdi,%rax,8)
    movl %eax, (%rsi,%rax,4)
    incq %rax
    cmpq %rcx, %rax
    jb 1b
    ret

# ---------------------------------------------------------------------
# .Lrt_sort_insert -- stable insertion sort of (key, index) pairs by
#   unsigned key: an element moves left only past strictly greater keys.
#   Inputs  : %rdi = key array, %rsi = index array, %rdx = n (>= 2)
#   Outputs : both arrays permuted together into ascending key order
#   Clobbers: %rax, %rcx, %r8-%r11, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_sort_insert:
    movl $1, %ecx                   # i: the element to insert
1:  movq (%rdi,%rcx,8), %r8         # its key
    movl (%rsi,%rcx,4), %r9d        # its index
    movq %rcx, %r10                 # j: the hole
2:  testq %r10, %r10
    jz 3f
    movq -8(%rdi,%r10,8), %rax      # key[j-1]
    cmpq %r8, %rax
    jbe 3f                          # key[j-1] <= key: the place (stable)
    movq %rax, (%rdi,%r10,8)        # shift the greater pair right
    movl -4(%rsi,%r10,4), %r11d
    movl %r11d, (%rsi,%r10,4)
    decq %r10
    jmp 2b
3:  movq %r8, (%rdi,%r10,8)         # the pair into the hole
    movl %r9d, (%rsi,%r10,4)
    incq %rcx
    cmpq %rdx, %rcx
    jb 1b
    ret

# ---------------------------------------------------------------------
# .Lrt_sort_radix -- LSD radix sort, 8 passes of 8 bits (file header).
#   Inputs  : %rdi = the scratch block: the histograms
#             (RT_SORT_HIST_BYTES), then keys A (8n, filled), keys B (8n),
#             indices A (4n, filled), indices B (4n); %rsi = n (> 32)
#   Outputs : %rax = the index buffer (A or B) holding the indices in
#             ascending key order (stable)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = this pass's histogram,
#             %r12 = source keys, %r13 = destination keys, %r14 = source
#             indices, %r15 = destination indices, %rbp = frame pointer
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15); calls nothing
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_sort_radix:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    leaq RT_SORT_HIST_BYTES(%rdi), %r12 # source keys (A)
    leaq (%r12,%rsi,8), %r13        # destination keys (B)
    leaq (%r13,%rsi,8), %r14        # source indices (A)
    leaq (%r14,%rsi,4), %r15        # destination indices (B)

    # Clear the 8 * 256 counts.
    movq %rdi, %rax
    movl $(RT_SORT_HIST_BYTES / 8), %ecx
1:  movq $0, (%rax)
    addq $8, %rax
    decl %ecx
    jnz 1b

    # Count all 8 histograms in one pass over the keys.
    xorl %r8d, %r8d                 # k
2:  movq (%r12,%r8,8), %rax         # key[k]
    movq %rdi, %r9                  # the histogram of byte 0
    movl $8, %r10d                  # bytes left
3:  movzbl %al, %edx
    incq (%r9,%rdx,8)               # one more key with this byte
    shrq $8, %rax                   # the next byte
    addq $RT_SORT_HIST_ONE, %r9     # and its histogram
    decl %r10d
    jnz 3b
    incq %r8
    cmpq %rsi, %r8
    jb 2b

    # The passes, byte 0 (least significant) to byte 7.
    xorl %ecx, %ecx                 # the shift of this pass's byte
    movq %rdi, %rbx                 # this pass's histogram
4:  movq (%r12), %rax               # any key's byte at this position:
    shrq %cl, %rax
    movzbl %al, %eax
    cmpq %rsi, (%rbx,%rax,8)
    je 7f                           # ... held by all n keys: skip the pass
    # Exclusive prefix sums in place: count -> first destination.
    xorl %r8d, %r8d
    xorl %edx, %edx                 # the running total
5:  movq (%rbx,%r8,8), %rax
    movq %rdx, (%rbx,%r8,8)
    addq %rax, %rdx
    incq %r8
    cmpq $256, %r8
    jb 5b
    # Scatter in input order (stable) from the source to the destination.
    xorl %r8d, %r8d
6:  movq (%r12,%r8,8), %rax         # key
    movl (%r14,%r8,4), %r9d         # its index
    movq %rax, %rdx
    shrq %cl, %rdx
    movzbl %dl, %edx                # its byte in this pass
    movq (%rbx,%rdx,8), %r10        # its destination
    incq (%rbx,%rdx,8)
    movq %rax, (%r13,%r10,8)
    movl %r9d, (%r15,%r10,4)
    incq %r8
    cmpq %rsi, %r8
    jb 6b
    # The destination becomes the source of the next pass.
    xchgq %r12, %r13
    xchgq %r14, %r15
7:  addl $8, %ecx
    addq $RT_SORT_HIST_ONE, %rbx
    cmpl $64, %ecx
    jb 4b
    movq %r14, %rax                 # the indices after the last pass
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_sort_merge -- stable bottom-up merge sort of string indices.
#   Purpose : sorts the indices 0 .. n-1 of the string pointers by
#             STR_CMP's order (desc: the reverse order); a right element
#             goes before a left one only when it is strictly before it,
#             so equal strings keep their input order in both directions.
#             Runs of width 1, 2, 4, ... are merged from one buffer into
#             the other, which then swap roles.
#   Inputs  : %rdi = the string pointers, %rsi = index buffer A (4n
#             bytes), %rdx = index buffer B (4n bytes), %rcx = n (>= 2),
#             %r8 = desc mask (0 or all ones)
#   Outputs : %rax = the buffer (A or B) holding the sorted indices
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = string pointers,
#             %r12 = source buffer, %r13 = destination buffer, %r14 = left
#             cursor, %r15 = right cursor, %rbp = frame pointer; locals
#             RT_SORT_M_* at 0(%rsp)
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + RT_SORT_M_FRAME = 104 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_sort_merge:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15                      # %rsp = 8 (mod 16)
    subq $RT_SORT_M_FRAME, %rsp     # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, RT_SORT_M_N(%rsp)
    movq %r8, RT_SORT_M_DESC(%rsp)
    # The source starts as the identity 0 .. n-1.
    xorl %eax, %eax
1:  movl %eax, (%r12,%rax,4)
    incq %rax
    cmpq %rcx, %rax
    jb 1b
    movq $1, RT_SORT_M_W(%rsp)      # run width
.Lrt_sort_merge_width:
    movq RT_SORT_M_W(%rsp), %rax
    cmpq RT_SORT_M_N(%rsp), %rax
    jae .Lrt_sort_merge_done        # one run covers everything
    movq $0, RT_SORT_M_LO(%rsp)     # the first pair of runs
.Lrt_sort_merge_pair:
    movq RT_SORT_M_LO(%rsp), %rax
    movq RT_SORT_M_N(%rsp), %rdx
    cmpq %rdx, %rax
    jae .Lrt_sort_merge_next
    movq %rax, %r9
    addq RT_SORT_M_W(%rsp), %r9
    cmpq %rdx, %r9
    cmovaq %rdx, %r9                # mid = min(lo + width, n)
    movq %r9, %r10
    addq RT_SORT_M_W(%rsp), %r10
    cmpq %rdx, %r10
    cmovaq %rdx, %r10               # hi = min(mid + width, n)
    movq %r9, RT_SORT_M_MID(%rsp)
    movq %r10, RT_SORT_M_HI(%rsp)
    movq %rax, %r14                 # left cursor
    movq %r9, %r15                  # right cursor
    movq %rax, RT_SORT_M_K(%rsp)    # output cursor
.Lrt_sort_merge_step:
    cmpq RT_SORT_M_MID(%rsp), %r14
    jae .Lrt_sort_merge_restr       # left run used up
    cmpq RT_SORT_M_HI(%rsp), %r15
    jae .Lrt_sort_merge_restl       # right run used up
    movl (%r12,%r15,4), %eax
    movq (%rbx,%rax,8), %rdi        # the right string
    movl (%r12,%r14,4), %eax
    movq (%rbx,%rax,8), %rsi        # the left string
    call sea_str_cmp                # -1, 0, 1: right vs left
    movq %rax, %rdx
    negq %rdx
    cmpq $0, RT_SORT_M_DESC(%rsp)
    cmovneq %rdx, %rax              # desc: the reverse order
    testq %rax, %rax
    js .Lrt_sort_merge_right        # strictly before: right first
    movl (%r12,%r14,4), %eax        # else the left one (ties: input order)
    movq RT_SORT_M_K(%rsp), %rdx
    movl %eax, (%r13,%rdx,4)
    incq %r14
    incq RT_SORT_M_K(%rsp)
    jmp .Lrt_sort_merge_step
.Lrt_sort_merge_right:
    movl (%r12,%r15,4), %eax
    movq RT_SORT_M_K(%rsp), %rdx
    movl %eax, (%r13,%rdx,4)
    incq %r15
    incq RT_SORT_M_K(%rsp)
    jmp .Lrt_sort_merge_step
.Lrt_sort_merge_restl:
    # Copy the rest of the left run.
    movq RT_SORT_M_MID(%rsp), %r9
    movq RT_SORT_M_K(%rsp), %rdx
2:  cmpq %r9, %r14
    jae .Lrt_sort_merge_pairend
    movl (%r12,%r14,4), %eax
    movl %eax, (%r13,%rdx,4)
    incq %r14
    incq %rdx
    jmp 2b
.Lrt_sort_merge_restr:
    # Copy the rest of the right run.
    movq RT_SORT_M_HI(%rsp), %r10
    movq RT_SORT_M_K(%rsp), %rdx
3:  cmpq %r10, %r15
    jae .Lrt_sort_merge_pairend
    movl (%r12,%r15,4), %eax
    movl %eax, (%r13,%rdx,4)
    incq %r15
    incq %rdx
    jmp 3b
.Lrt_sort_merge_pairend:
    movq RT_SORT_M_W(%rsp), %rax
    shlq $1, %rax
    addq %rax, RT_SORT_M_LO(%rsp)   # the next pair of runs
    jmp .Lrt_sort_merge_pair
.Lrt_sort_merge_next:
    xchgq %r12, %r13                # the merged runs become the source
    shlq $1, RT_SORT_M_W(%rsp)      # of runs twice as wide
    jmp .Lrt_sort_merge_width
.Lrt_sort_merge_done:
    movq %r12, %rax
    addq $RT_SORT_M_FRAME, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

    .section .rodata
    .p2align 3
.Lrt_sort_inf:  .quad 0x7FF0000000000000 # +inf: an f64 above it (sign cleared) is a NaN
.Lrt_sort_nan:  .quad 0x7FF8000000000000 # the canonical NaN
.Lrt_sort_sign: .quad 0x8000000000000000 # the sign bit (-0's bits)

    .section .note.GNU-stack,"",@progbits
