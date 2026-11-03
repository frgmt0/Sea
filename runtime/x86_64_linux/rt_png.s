# =====================================================================
# sea/runtime/x86_64_linux/rt_png.s -- the PNG writer of the plotting
# library: stored deflate inside one zlib stream, CRC-32, Adler-32 and
# base64 (DESIGN.md 2.14.6 "PNG", L-kt; LANGUAGE.md 12.6). The
# x86_64-linux twin of runtime/arm64_macos/rt_png.s: the same bytes.
#
# Defines (.globl + .hidden: private to the runtime, L-ld; no rt.inc
# record):
#   sea_crc32   (bytes, len) -> the CRC-32 of ISO 3309 (reflected
#               polynomial EDB88320, initial and final XOR FFFFFFFF),
#               computed bitwise: 8 steps per byte, no table, no state
#   sea_adler32 (bytes, len) -> the Adler-32 (s1 = 1, s2 = 0, both mod
#               65521, the reduction deferred over at most 5552 bytes)
#   sea_b64     (dst, src, len) -> 4 * ceil(len / 3) base64 bytes of
#               RFC 4648 (A-Z a-z 0-9 + /, `=` padding, no line breaks)
#               written at dst; their count
#   sea_png     (raw, w, h, site) -> a new uncounted block holding the
#               PNG of a w x h RGB image (depth 8) whose raw data, h rows
#               of the filter byte 0 and 3w pixel bytes, rows from the
#               top, is at raw (h * (1 + 3w) bytes); its length
# Uses: sea_alloc (rt_mem.s), sea_err (rt_err.s).
#
# The PNG (2.14.6): the signature 89 50 4E 47 0D 0A 1A 0A; IHDR (w, h
# big-endian, then 8 2 0 0 0); one IDAT holding 78 01, the raw data in
# stored blocks of 65535 bytes, the last one shorter and BFINAL (never an
# empty block: the raw data is at least 4 bytes), each block the header
# byte (0, or 1 for the last), LEN little-endian and NLEN = ~LEN, then
# the bytes; then the Adler-32 of the raw data, big-endian; IEND. Each
# chunk is its data length (big-endian u32), its type, its data and the
# CRC-32 of type and data (big-endian). An IDAT of more than 2^31 - 1
# bytes is sea_err(SEA_E_OUT_OF_MEMORY, site); so is a failed allocation
# (through sea_alloc's own path). The block is exactly the PNG's length,
# so the caller frees it with sea_free_block(block, length).
#
# ABI: System V AMD64; %rbx %rbp %r12 - %r15 preserved; MXCSR untouched,
# no floating point at all. Stack: sea_png's frame is 72 bytes below its
# return address (+ sea_alloc's or sea_err's); the other three are
# leaves without a frame.
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

.equ RTN_BLOCK,     65535           # the largest stored block's LEN
.equ RTN_IDAT_MAX,  0x7FFFFFFF      # the largest IDAT (2^31 - 1 bytes)
.equ RTN_FIXED,     57              # signature 8 + IHDR 25 + IDAT's 12 + IEND 12
.equ RTN_ADLER_MOD, 65521
.equ RTN_ADLER_RUN, 5552            # bytes between two reductions
.equ RTN_POLY,      0xEDB88320      # the reflected CRC-32 polynomial

    .text

# ---------------------------------------------------------------------
# sea_crc32 -- CRC-32 of a byte string, bitwise.
#   Inputs  : %rdi = the bytes, %rsi = their count
#   Outputs : %rax = the CRC (32 bits, zero-extended)
#   Clobbers: %rcx, %rdx, %rsi, %rdi, %r8, flags
#   Callee-saved used: none.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .globl sea_crc32
    .hidden sea_crc32
    .type sea_crc32, @function
    .p2align 4
sea_crc32:
    movl $0xFFFFFFFF, %eax          # the initial value
    movl $RTN_POLY, %r8d
1:  testq %rsi, %rsi
    jz 3f
    movzbl (%rdi), %edx
    xorl %edx, %eax                 # the next byte into the low bits
    movl $8, %ecx
2:  movl %eax, %edx                 # one step: shift right, XOR the polynomial
    andl $1, %edx                   #   when the bit shifted out was 1
    negl %edx                       # 0 or all ones
    andl %r8d, %edx
    shrl $1, %eax
    xorl %edx, %eax
    decl %ecx
    jnz 2b
    incq %rdi
    decq %rsi
    jmp 1b
3:  notl %eax                       # the final XOR (zero-extends %rax)
    ret
    .size sea_crc32, . - sea_crc32

# ---------------------------------------------------------------------
# sea_adler32 -- Adler-32 of a byte string: s1 = 1, s2 = 0; per byte s1
#   += byte, s2 += s1, both reduced mod 65521 after every run of at most
#   5552 bytes (no 32-bit sum can overflow within one run).
#   Inputs  : %rdi = the bytes, %rsi = their count
#   Outputs : %rax = s2 * 65536 + s1
#   Clobbers: %rcx, %rdx, %rsi, %rdi, %r8, %r9, flags
#   Callee-saved used: none.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .globl sea_adler32
    .hidden sea_adler32
    .type sea_adler32, @function
    .p2align 4
sea_adler32:
    movl $1, %r8d                   # s1
    xorl %r9d, %r9d                 # s2
1:  testq %rsi, %rsi
    jz 4f
    movq %rsi, %rcx                 # this run: min(left, 5552)
    cmpq $RTN_ADLER_RUN, %rcx
    jbe 2f
    movl $RTN_ADLER_RUN, %ecx
2:  subq %rcx, %rsi
3:  movzbl (%rdi), %eax             # s1 += byte; s2 += s1
    addl %eax, %r8d
    addl %r8d, %r9d
    incq %rdi
    decq %rcx
    jnz 3b
    movl %r8d, %eax                 # the reductions
    xorl %edx, %edx
    movl $RTN_ADLER_MOD, %ecx
    divl %ecx
    movl %edx, %r8d
    movl %r9d, %eax
    xorl %edx, %edx
    divl %ecx
    movl %edx, %r9d
    jmp 1b
4:  movl %r9d, %eax
    shll $16, %eax
    orl %r8d, %eax                  # s2 << 16 | s1 (zero-extends %rax)
    ret
    .size sea_adler32, . - sea_adler32

# ---------------------------------------------------------------------
# sea_b64 -- base64 (RFC 4648, `=` padding, no line breaks).
#   Inputs  : %rdi = the destination (4 * ceil(len / 3) bytes), %rsi =
#             the source bytes, %rdx = their count
#   Outputs : %rax = the bytes written
#   Clobbers: %rcx, %rdx, %rsi, %rdi, %r8 - %r11, flags
#   Callee-saved used: none.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .globl sea_b64
    .hidden sea_b64
    .type sea_b64, @function
    .p2align 4
sea_b64:
    movq %rdi, %r11                 # the start, for the count
    leaq .Lrt_png_b64(%rip), %r10
1:  cmpq $3, %rdx
    jb 2f
    movzbl (%rsi), %eax             # three bytes -> a 24-bit group
    shll $16, %eax
    movzbl 1(%rsi), %ecx
    shll $8, %ecx
    orl %ecx, %eax
    movzbl 2(%rsi), %ecx
    orl %ecx, %eax
    movl %eax, %ecx                 # four 6-bit digits, the highest first
    shrl $18, %ecx
    movb (%r10,%rcx), %r8b
    movb %r8b, (%rdi)
    movl %eax, %ecx
    shrl $12, %ecx
    andl $63, %ecx
    movb (%r10,%rcx), %r8b
    movb %r8b, 1(%rdi)
    movl %eax, %ecx
    shrl $6, %ecx
    andl $63, %ecx
    movb (%r10,%rcx), %r8b
    movb %r8b, 2(%rdi)
    andl $63, %eax
    movb (%r10,%rax), %r8b
    movb %r8b, 3(%rdi)
    addq $3, %rsi
    addq $4, %rdi
    subq $3, %rdx
    jmp 1b
2:  testq %rdx, %rdx
    jz 9f                           # no tail
    movzbl (%rsi), %eax             # one or two bytes left: the group padded with 0
    shll $16, %eax
    cmpq $2, %rdx
    jb 3f
    movzbl 1(%rsi), %ecx
    shll $8, %ecx
    orl %ecx, %eax
3:  movl %eax, %ecx
    shrl $18, %ecx
    movb (%r10,%rcx), %r8b
    movb %r8b, (%rdi)
    movl %eax, %ecx
    shrl $12, %ecx
    andl $63, %ecx
    movb (%r10,%rcx), %r8b
    movb %r8b, 1(%rdi)
    movb $61, 2(%rdi)               # '=' unless two bytes were left
    movb $61, 3(%rdi)
    cmpq $2, %rdx
    jb 4f
    shrl $6, %eax
    andl $63, %eax
    movb (%r10,%rax), %r8b
    movb %r8b, 2(%rdi)
4:  addq $4, %rdi
9:  movq %rdi, %rax
    subq %r11, %rax
    ret
    .size sea_b64, . - sea_b64

# ---------------------------------------------------------------------
# sea_png -- a PNG of a w x h RGB image from its raw (filtered) data.
#   Inputs  : %rdi = the raw data (h * (1 + 3w) bytes), %rsi = w (>= 1),
#             %rdx = h (>= 1), %rcx = the site
#   Outputs : %rax = the new uncounted block, %rdx = its length (= its
#             size)
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the raw data, %r12 = the raw length then
#             the bytes left, %r13 = the write cursor, %r14 = the block,
#             %r15 = the IDAT length, %rbp; locals 0 w, 8 h, 16 the site
#   Frame   : 72 bytes below the return address (%rbp + 5 saved + 24)
# ---------------------------------------------------------------------
    .globl sea_png
    .hidden sea_png
    .type sea_png, @function
    .p2align 4
sea_png:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $24, %rsp                  # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, 0(%rsp)
    movq %rdx, 8(%rsp)
    movq %rcx, 16(%rsp)
    # The sizes: raw = h * (1 + 3w); blocks = ceil(raw / 65535); IDAT =
    # 2 + raw + 5 * blocks + 4. The products are tested for overflow:
    # either overflowing means an IDAT far over 2^31 - 1.
    leaq (%rsi,%rsi,2), %rax
    incq %rax                       # 1 + 3w (w is bounded by memory: no carry)
    mulq %rdx                       # * h
    jc 8f
    movq %rax, %r12                 # the raw length
    leaq (RTN_BLOCK - 1)(%r12), %rax
    xorl %edx, %edx
    movl $RTN_BLOCK, %ecx
    divq %rcx                       # the block count
    leaq (%rax,%rax,4), %r15        # 5 per block
    addq %r12, %r15
    addq $6, %r15                   # + the zlib header and the Adler-32
    cmpq $RTN_IDAT_MAX, %r15
    ja 8f                           # an IDAT over 2^31 - 1 bytes
    leaq RTN_FIXED(%r15), %rdi      # the block
    movq 16(%rsp), %rsi
    call sea_alloc
    movq %rax, %r14
    movq %rax, %r13
    # The signature.
    movabsq $0x0A1A0A0D474E5089, %rax
    movq %rax, (%r13)
    addq $8, %r13
    # IHDR: 13, "IHDR", w, h, 8 2 0 0 0, the CRC of type and data.
    movl $13, %eax
    call .Lrt_png_be32
    movl $0x52444849, (%r13)        # "IHDR"
    addq $4, %r13
    movq 0(%rsp), %rax
    call .Lrt_png_be32
    movq 8(%rsp), %rax
    call .Lrt_png_be32
    movl $0x00000208, (%r13)        # 8 2 0 0
    movb $0, 4(%r13)                # 0
    addq $5, %r13
    leaq -17(%r13), %rdi
    movl $17, %esi
    call .Lrt_png_crc
    # IDAT: its length, "IDAT", 78 01, the stored blocks, the Adler-32.
    movl %r15d, %eax
    call .Lrt_png_be32
    movl $0x54414449, (%r13)        # "IDAT"
    movw $0x0178, 4(%r13)           # 78 01
    addq $6, %r13
    movq %rbx, %rsi                 # the source cursor
1:  movq %r12, %rcx                 # this block: min(left, 65535)
    xorl %eax, %eax                 # BFINAL 0
    cmpq $RTN_BLOCK, %rcx
    jbe 2f
    movl $RTN_BLOCK, %ecx
    jmp 3f
2:  movl $1, %eax                   # the last block: BFINAL 1
3:  movb %al, (%r13)
    movw %cx, 1(%r13)               # LEN, little-endian
    movl %ecx, %eax
    notl %eax
    movw %ax, 3(%r13)               # NLEN
    addq $5, %r13
    subq %rcx, %r12
    movq %r13, %rdi                 # the bytes
    rep movsb                       # (%rsi advances; DF is clear by the ABI)
    movq %rdi, %r13
    testq %r12, %r12
    jnz 1b
    movq %rbx, %rdi                 # the Adler-32 of the raw data
    movq 8(%rsp), %rsi              # (its length again: h * (1 + 3w))
    movq 0(%rsp), %rax
    leaq 1(%rax,%rax,2), %rax
    imulq %rax, %rsi
    call sea_adler32
    call .Lrt_png_be32
    leaq 4(%r15), %rsi              # the CRC of "IDAT" and its data
    movq %r13, %rdi
    subq %rsi, %rdi
    call .Lrt_png_crc
    # IEND: 0, "IEND", its CRC.
    xorl %eax, %eax
    call .Lrt_png_be32
    movl $0x444E4549, (%r13)        # "IEND"
    addq $4, %r13
    leaq -4(%r13), %rdi
    movl $4, %esi
    call .Lrt_png_crc
    movq %r14, %rax                 # the block and its length
    leaq RTN_FIXED(%r15), %rdx
    addq $24, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
8:  movl $SEA_E_OUT_OF_MEMORY, %edi # sea_err(OUT_OF_MEMORY, site): no slots
    movq 16(%rsp), %rsi
    movq %rsp, %rdx                 # (a valid slot vector, unused)
    call sea_err                    # noreturn
    ud2
    .size sea_png, . - sea_png

# .Lrt_png_be32 -- store %eax big-endian at %r13, advance %r13 by 4.
#   Clobbers: %rax.  Frame: none (leaf)
    .p2align 4
.Lrt_png_be32:
    bswapl %eax
    movl %eax, (%r13)
    addq $4, %r13
    ret

# .Lrt_png_crc -- append the CRC-32 of %rsi bytes at %rdi, big-endian,
#   at %r13 (advanced by 4). Clobbers: %rax, %rcx, %rdx, %rsi, %rdi, %r8.
#   Frame: none (calls the leaves sea_crc32 and .Lrt_png_be32).
    .p2align 4
.Lrt_png_crc:
    call sea_crc32
    jmp .Lrt_png_be32

    .section .rodata
.Lrt_png_b64:
    .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    .section .note.GNU-stack,"",@progbits
