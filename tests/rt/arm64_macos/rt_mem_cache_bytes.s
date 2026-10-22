// sea/tests/rt/arm64_macos/rt_mem_cache_bytes.s -- the large-block cache in all: eight freed 32 MiB blocks fill the SEA_LCACHE_MAX_BYTES (256 MiB) cache and stay mapped; a freed 64 MiB block would exceed it and is unmapped although its class is empty; a 32 MiB allocation then takes the last cached block
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

// ---- test helpers (the same block in every 4c runtime test) ----------
// A static string object (rt.inc SEA_STR_*): count SEA_RC_STATIC, tag, length, bytes.
.macro SSTR label, len, text
    .p2align 3
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad \len
    .ascii "\text"
.endm
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
// Print a literal text, then a register in signed decimal (x0-x17 clobbered;
// reg must not be x0-x17 unless it is x1).
.macro KV text, reg
    mov x1, \reg
    .pushsection __TEXT,__cstring,cstring_literals
Lkv\@: .asciz "\text"
    .popsection
    LA x0, Lkv\@
    bl Lput_kv
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

// Lput_kv -- print a text, then x1 in signed decimal. x0 = text. Clobbers
// x0-x17. Callee-saved used: x19 (the value). Frame 32 bytes.
    .p2align 2
Lput_kv:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x1
    bl Lput_cstr
    mov x0, x19
    bl Lput_dec
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lput_str -- print a string object's bytes between [ and ]. x0 = the
// object. Clobbers x0-x17. Callee-saved used: x19. Frame 32 bytes.
    .p2align 2
Lput_str:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    LA x0, Lput_s_lb
    mov x1, #1
    bl _sea_out_write
    add x0, x19, #SEA_STR_BYTES
    ldr x1, [x19, #SEA_STR_LEN]
    bl _sea_out_write
    LA x0, Lput_s_rb
    mov x1, #1
    bl _sea_out_write
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .section __TEXT,__const
Lput_s_lb: .ascii "["
Lput_s_rb: .ascii "]"
    .section __TEXT,__text,regular,pure_instructions
// ---- end of the test helpers ------------------------------------------

// CHECK cond, text: print text and LF if the flags satisfy cond, else
// "BAD " before it (x0-x17 clobbered).
.macro CHECK cond, text
    b.\cond Lck_ok\@
    TXT "BAD "
Lck_ok\@:
    TXT "\text\n"
.endm
.equ T_MS_ASYNC, 1                  /* <sys/mman.h> MS_ASYNC on Darwin */
.equ BLK, 0x2000000                 /* 32 MiB: eight fill SEA_LCACHE_MAX_BYTES */
.equ BIG, 0x4000000                 /* 64 MiB */
.equ NBLK, 8

    .section __TEXT,__text,regular,pure_instructions
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x24, Lblk
    mov x19, #0
1:  mov x0, #BLK
    mov x1, #0
    bl _sea_alloc
    str x0, [x24, x19, lsl #3]
    add x19, x19, #1
    cmp x19, #NBLK
    b.lo 1b
    mov x0, #BIG
    mov x1, #0
    bl _sea_alloc
    mov x21, x0                     // the 64 MiB block
    mov x19, #0
2:  ldr x0, [x24, x19, lsl #3]
    mov x1, #BLK
    bl _sea_free_block
    add x19, x19, #1
    cmp x19, #NBLK
    b.lo 2b
    mov x19, #0                     // all eight cached
    mov x20, #1
3:  ldr x0, [x24, x19, lsl #3]
    bl Lmapped
    cmp x0, #1
    csel x20, x20, xzr, eq
    add x19, x19, #1
    cmp x19, #NBLK
    b.lo 3b
    cmp x20, #1
    CHECK eq, "eight 32 MiB blocks cached"
    mov x0, x21                     // the 64 MiB block does not fit: unmapped
    mov x1, #BIG
    bl _sea_free_block
    mov x0, x21
    bl Lmapped
    cmp x0, #0
    CHECK eq, "64 MiB block unmapped"
    mov x0, #BLK                    // a 32 MiB allocation: the most recently freed
    mov x1, #0
    bl _sea_alloc
    ldr x9, [x24, #(8 * (NBLK - 1))]
    cmp x0, x9
    CHECK eq, "32 MiB block from the cache"
    EPILOGUE

// Lmapped -- x0 = 1 if the page holding the address in x0 is mapped,
// else 0 (msync fails with ENOMEM on an unmapped range). Clobbers x0-x17.
// Frame 16 bytes.
    .p2align 2
Lmapped:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x1, #1                      // one byte: its page
    mov w2, #T_MS_ASYNC
    bl _msync
    cmp w0, #0
    cset x0, eq
    ldp x29, x30, [sp], #16
    ret

.zerofill __DATA,__bss,Lblk,(8 * NBLK),3
    .section __DATA,__const
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
