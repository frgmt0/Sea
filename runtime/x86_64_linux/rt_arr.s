# =====================================================================
# sea/runtime/x86_64_linux/rt_arr.s -- array constructors and copy on
# write (DESIGN.md 4.1, 4.2, 4.7.1, 4.8 entries ARR_NEW, ARR_NEW_S,
# ARR_UNIQUE, ARR_NEW_U). The x86_64-linux twin of
# runtime/arm64_macos/rt_arr.s.
#
# Defines (global, rt.inc SEA_ENTRY_LIST):
#   sea_arr_new    (ek, rank, rows, cols, site) -> array, buffer zeroed
#   sea_arr_new_u  (ek, rank, rows, cols, site) -> array, buffer as the
#                  block holds it (numeric element kinds only)
#   sea_arr_new_s  (slay, rank, rows, cols, site) -> struct array, zeroed
#   sea_arr_unique (a, site) -> a with count 1, or a copy
# Uses: sea_alloc and sea_live (rt_mem.s), sea_err (rt_err.s), glibc
#   memset and memcpy through the PLT.
#
# An array is one block (DESIGN.md 4.1): the SEA_ARR_SIZE-byte header and,
# right after it at header + SEA_ARR_SIZE, the buffer of rows * cols
# elements, so SEA_ARR_DATA = header + 64 and SEA_ARR_CAP = rows * cols.
# The block of a request of 64 + n bytes is at least 64-byte aligned
# (rt_mem.s), so the buffer is SEA_DATA_ALIGN-aligned. Every returned
# array has count 1 and is counted in sea_live.
#
# Checks, in this order (DESIGN.md 4.8): the first of rows, cols outside
# 0 .. SEA_LIM_EXTENT is sea_err(SEA_E_ARRAY_SIZE, site, {that value});
# rows * cols * esize + SEA_ARR_SIZE above 2^62 (a size that does not
# fit) and a failed allocation are sea_err(SEA_E_OUT_OF_MEMORY, site).
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

.equ RT_ARR_MAX_BYTES,  0x4000000000000000 # 2^62: the largest block attempted (DESIGN.md 4.1)

.if SEA_ARR_SIZE % SEA_DATA_ALIGN
    .error "rt_arr: the buffer after the header would not be SEA_DATA_ALIGN-aligned"
.endif

# .Lrt_arr_make's locals (offsets from %rsp after its prologue).
.equ RT_ARR_M_SLOT,     0           # the argument slot of `invalid array size`
.equ RT_ARR_M_EK,       8
.equ RT_ARR_M_RANK,     16
.equ RT_ARR_M_SLAY,     24
.equ RT_ARR_M_CLEAR,    32
.equ RT_ARR_M_FRAME,    40          # bytes of locals: %rsp = 0 (mod 16) after them

    .text

# ---------------------------------------------------------------------
# .Lrt_arr_make -- the common constructor.
#   Purpose : the checks of the file header, then a new array: count 1,
#             SEA_TAG_ARRAY, ek, rank, rows, cols, cap rows * cols, data
#             at header + SEA_ARR_SIZE, esize, slay, the other header
#             bytes 0; the buffer cleared to zero bytes when asked; the
#             live count + 1.
#   Inputs  : (a local convention) %edi = ek, %esi = rank, %rdx = rows,
#             %rcx = cols, %r8 = site, %r9 = esize, %r10 = slay (or 0),
#             %r11 = 1 to clear the buffer, 0 to leave it
#   Outputs : %rax = the array
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = rows, %r12 = cols,
#             %r13 = site, %r14 = esize, %r15 = the array, %rbp = frame
#             pointer; locals RT_ARR_M_* at 0(%rsp)
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + RT_ARR_M_FRAME = 88 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_arr_make:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15                      # %rsp = 8 (mod 16)
    subq $RT_ARR_M_FRAME, %rsp      # %rsp = 0 (mod 16)
    movq %rdx, %rbx
    movq %rcx, %r12
    movq %r8, %r13
    movq %r9, %r14
    movq %rdi, RT_ARR_M_EK(%rsp)
    movq %rsi, RT_ARR_M_RANK(%rsp)
    movq %r10, RT_ARR_M_SLAY(%rsp)
    movq %r11, RT_ARR_M_CLEAR(%rsp)
    # The extents, rows first: unsigned compares, so a negative extent
    # is above the limit too.
    movq %rbx, %rax
    cmpq $SEA_LIM_EXTENT, %rbx
    ja .Lrt_arr_make_badsize
    movq %r12, %rax
    cmpq $SEA_LIM_EXTENT, %r12
    ja .Lrt_arr_make_badsize
    # Bytes: rows * cols (< 2^62) * esize, as 128 bits, + the header.
    movq %rbx, %rax
    imulq %r12, %rax
    mulq %r14                       # %rdx:%rax = elements * esize
    jc .Lrt_arr_make_oom            # above 2^64
    addq $SEA_ARR_SIZE, %rax
    jc .Lrt_arr_make_oom
    movabsq $RT_ARR_MAX_BYTES, %rcx
    cmpq %rcx, %rax
    ja .Lrt_arr_make_oom            # above 2^62: does not fit
    movq %rax, %rdi
    movq %r13, %rsi
    call sea_alloc                  # %rax = the block (or out of memory there)
    movq %rax, %r15
    # The header.
    movq $1, SEA_ARR_RC(%r15)       # count 1
    movq $0, SEA_ARR_TAG(%r15)      # tag, ek, rank and the bytes after them ...
    movb $SEA_TAG_ARRAY, SEA_ARR_TAG(%r15)
    movq RT_ARR_M_EK(%rsp), %rax
    movb %al, SEA_ARR_EK(%r15)
    movq RT_ARR_M_RANK(%rsp), %rax
    movb %al, SEA_ARR_RANK(%r15)    # ... bytes 11 .. 15 stay 0
    movq %rbx, SEA_ARR_ROWS(%r15)
    movq %r12, SEA_ARR_COLS(%r15)
    movq %rbx, %rax
    imulq %r12, %rax
    movq %rax, SEA_ARR_CAP(%r15)    # cap = rows * cols
    leaq SEA_ARR_SIZE(%r15), %rcx
    movq %rcx, SEA_ARR_DATA(%r15)   # the buffer right after the header
    movq %r14, SEA_ARR_ESIZE(%r15)
    movq RT_ARR_M_SLAY(%rsp), %rdx
    movq %rdx, SEA_ARR_SLAY(%r15)
    incq sea_live(%rip)             # one more live object
    # The buffer: zero bytes for sea_arr_new and sea_arr_new_s (a
    # recycled block is not clean).
    cmpq $0, RT_ARR_M_CLEAR(%rsp)
    je 1f
    imulq %r14, %rax                # bytes of the buffer
    movq %rcx, %rdi
    xorl %esi, %esi
    movq %rax, %rdx
    call memset@PLT
1:  movq %r15, %rax
    addq $RT_ARR_M_FRAME, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_arr_make_badsize:
    movq %rax, RT_ARR_M_SLOT(%rsp)  # the offending extent
    movl $SEA_E_ARRAY_SIZE, %edi
    movq %r13, %rsi
    leaq RT_ARR_M_SLOT(%rsp), %rdx
    call sea_err                    # noreturn
    ud2
.Lrt_arr_make_oom:
    movl $SEA_E_OUT_OF_MEMORY, %edi
    movq %r13, %rsi
    xorl %edx, %edx
    call sea_err                    # noreturn
    ud2

# RT_ARR_ESIZE -- the element size of a scalar element kind (inline).
#   Inputs : %edi = ek (SEA_EK_F64, SEA_EK_I64, SEA_EK_BOOL or SEA_EK_STR)
#   Outputs: %r9 = SEA_ESIZE_F64, SEA_ESIZE_I64, SEA_ESIZE_BOOL or
#            SEA_ESIZE_PTR
#   Clobbers: flags
.macro RT_ARR_ESIZE
    movl $SEA_ESIZE_F64, %r9d
    cmpl $SEA_EK_I64, %edi
    jne 1f
    movl $SEA_ESIZE_I64, %r9d
1:  cmpl $SEA_EK_BOOL, %edi
    jne 2f
    movl $SEA_ESIZE_BOOL, %r9d
2:  cmpl $SEA_EK_STR, %edi
    jne 3f
    movl $SEA_ESIZE_PTR, %r9d
3:
.endm

# ---------------------------------------------------------------------
# sea_arr_new -- entry ARR_NEW (DESIGN.md 4.8).
#   Purpose : a new array of a scalar element kind, its buffer zeroed
#             (f64 +0.0, i64 0, bool false, str null).
#   Inputs  : %edi = ek (SEA_EK_F64, SEA_EK_I64, SEA_EK_BOOL, SEA_EK_STR),
#             %esi = rank (1 or 2), %rdx = rows, %rcx = cols (1 for a
#             vector), %r8 = site
#   Outputs : %rax = the array (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used: none
#   Frame   : none (a tail jump to .Lrt_arr_make)
# ---------------------------------------------------------------------
    .globl sea_arr_new
    .type sea_arr_new, @function
    .p2align 4
sea_arr_new:
    RT_ARR_ESIZE                    # %r9 = esize
    xorl %r10d, %r10d               # no struct descriptor
    movl $1, %r11d                  # cleared
    jmp .Lrt_arr_make
    .size sea_arr_new, . - sea_arr_new

# ---------------------------------------------------------------------
# sea_arr_new_u -- entry ARR_NEW_U (DESIGN.md 4.8).
#   Purpose : exactly sea_arr_new for a numeric element kind, except
#             that the buffer is not cleared (its contents are
#             unspecified until the creating node writes them).
#   Inputs  : %edi = ek (SEA_EK_F64, SEA_EK_I64, SEA_EK_BOOL), %esi =
#             rank, %rdx = rows, %rcx = cols, %r8 = site
#   Outputs : %rax = the array (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used: none
#   Frame   : none (a tail jump to .Lrt_arr_make)
# ---------------------------------------------------------------------
    .globl sea_arr_new_u
    .type sea_arr_new_u, @function
    .p2align 4
sea_arr_new_u:
    RT_ARR_ESIZE                    # %r9 = esize
    xorl %r10d, %r10d               # no struct descriptor
    xorl %r11d, %r11d               # not cleared
    jmp .Lrt_arr_make
    .size sea_arr_new_u, . - sea_arr_new_u

# ---------------------------------------------------------------------
# sea_arr_new_s -- entry ARR_NEW_S (DESIGN.md 4.8).
#   Purpose : a new array of struct elements (SEA_EK_STRUCT), esize the
#             descriptor's SEA_SL_SIZE, SEA_ARR_SLAY the descriptor, the
#             buffer zeroed (every reference field null).
#   Inputs  : %rdi = the SEA_SL_* descriptor, %esi = rank, %rdx = rows,
#             %rcx = cols, %r8 = site
#   Outputs : %rax = the array (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used: none
#   Frame   : none (a tail jump to .Lrt_arr_make)
# ---------------------------------------------------------------------
    .globl sea_arr_new_s
    .type sea_arr_new_s, @function
    .p2align 4
sea_arr_new_s:
    movq %rdi, %r10                 # the descriptor
    movq SEA_SL_SIZE(%rdi), %r9     # esize = the struct size
    movl $SEA_EK_STRUCT, %edi
    movl $1, %r11d                  # cleared
    jmp .Lrt_arr_make
    .size sea_arr_new_s, . - sea_arr_new_s

# ---------------------------------------------------------------------
# sea_arr_unique -- entry ARR_UNIQUE: copy on write (DESIGN.md 4.2, 4.8).
#   Purpose : a's count is 1: return a. Otherwise a new array with a's
#             ek, rank, rows, cols, esize and slay (cap rows * cols), the
#             rows * cols * esize data bytes copied, every non-null
#             dynamic `str` element and every non-null dynamic reference
#             field of every struct element retained (static ones are
#             never counted); then a's count drops by one if it is above
#             1 (a static a, count 0, stays) and the copy is returned.
#   Inputs  : %rdi = a, %rsi = site
#   Outputs : %rax = an array with count 1 and a's contents
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = a, %r12 = the copy,
#             %r13 = elements left, %r14 = element cursor, %r15 = the
#             struct descriptor, %rbp = frame pointer
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + 8 pad = 56 bytes
# ---------------------------------------------------------------------
    .globl sea_arr_unique
    .type sea_arr_unique, @function
    .p2align 4
sea_arr_unique:
    cmpq $1, SEA_ARR_RC(%rdi)
    jne 1f
    movq %rdi, %rax                 # the only reference: write in place
    ret
1:  pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    # The copy: same element kind, shape, element size and descriptor.
    movq %rsi, %r8                  # site
    movzbl SEA_ARR_EK(%rbx), %edi
    movzbl SEA_ARR_RANK(%rbx), %esi
    movq SEA_ARR_ROWS(%rbx), %rdx
    movq SEA_ARR_COLS(%rbx), %rcx
    movq SEA_ARR_ESIZE(%rbx), %r9
    movq SEA_ARR_SLAY(%rbx), %r10
    xorl %r11d, %r11d               # every byte is copied: no clearing
    call .Lrt_arr_make
    movq %rax, %r12
    # The data bytes.
    movq SEA_ARR_CAP(%r12), %r13    # rows * cols
    movq %r13, %rdx
    imulq SEA_ARR_ESIZE(%r12), %rdx
    movq SEA_ARR_DATA(%r12), %rdi
    movq SEA_ARR_DATA(%rbx), %rsi
    call memcpy@PLT
    # The copy holds one more count of every reference it contains.
    movq SEA_ARR_DATA(%r12), %r14
    movzbl SEA_ARR_EK(%r12), %eax
    cmpl $SEA_EK_STR, %eax
    je .Lrt_arr_uq_strs
    cmpl $SEA_EK_STRUCT, %eax
    je .Lrt_arr_uq_structs
    jmp .Lrt_arr_uq_done
.Lrt_arr_uq_strs:                   # each str element
    testq %r13, %r13
    jz .Lrt_arr_uq_done
    movq (%r14), %rdi
    call sea_retain                 # skips null and static strings
    addq $SEA_ESIZE_PTR, %r14
    decq %r13
    jmp .Lrt_arr_uq_strs
.Lrt_arr_uq_structs:                # each reference field of each element
    movq SEA_ARR_SLAY(%r12), %r15
.Lrt_arr_uq_elem:
    testq %r13, %r13
    jz .Lrt_arr_uq_done
    xorl %ecx, %ecx                 # field index (sea_retain keeps %rcx)
2:  cmpq SEA_SL_NREF(%r15), %rcx
    jae 3f
    movq SEA_SL_REFS(%r15,%rcx,8), %rax # the field's offset
    movq (%r14,%rax), %rdi
    call sea_retain                 # clobbers only %rax and flags
    incq %rcx
    jmp 2b
3:  addq SEA_SL_SIZE(%r15), %r14    # the next element
    decq %r13
    jmp .Lrt_arr_uq_elem
.Lrt_arr_uq_done:
    # Give up the variable's count on a (a static a keeps count 0).
    cmpq $1, SEA_ARR_RC(%rbx)
    jbe 4f
    decq SEA_ARR_RC(%rbx)
4:  movq %r12, %rax
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
    .size sea_arr_unique, . - sea_arr_unique

    .section .note.GNU-stack,"",@progbits
