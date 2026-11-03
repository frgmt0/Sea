// =====================================================================
// sea/runtime/arm64_macos/rt_png.s -- the PNG writer of the plotting
// library: RGB images in stored deflate blocks, CRC-32, Adler-32 and
// base64 (LANGUAGE.md 12.6; DESIGN.md 2.14.6 "PNG", "Base64"; lead
// decisions L-kt, L-ld).
//
// Defines (private, .private_extern; no rt.inc record, L-ld):
//   _sea_crc32    (bytes, count) -> w0 = CRC-32
//   _sea_adler32  (bytes, count) -> w0 = Adler-32
//   _sea_b64      (dst, bytes, count) -> x0 = bytes written
//   _sea_png      (raw, rawlen, w, h, site) -> x0 = PNG block, x1 = its
//                 length (an uncounted _sea_alloc block of exactly that
//                 size, freed by the caller with _sea_free_block)
// Uses: _sea_alloc (rt_mem.s), _sea_err (rt_err.s), memcpy (libSystem).
//
// THE FILE (2.14.6 "PNG"). The signature 89 50 4E 47 0D 0A 1A 0A; the
// chunk IHDR (w, h big-endian, then depth 8, colour type 2, deflate,
// filter method 0, no interlace); one chunk IDAT holding the zlib stream
// 78 01, the raw data (per row the filter byte 0 and 3w pixel bytes,
// given by the caller) in stored blocks of at most 65 535 bytes (every
// block but the last exactly 65 535, BFINAL on the last; the raw data is
// never empty), each block the header byte (0, or 1 on the last), LEN
// (u16 little-endian), NLEN (its one's complement), LEN bytes; then the
// Adler-32 of the raw data, big-endian; the chunk IEND. Each chunk is its
// data length (u32 big-endian), its type, its data and the CRC-32 of type
// and data (big-endian). An IDAT over 2^31 - 1 bytes is OUT_OF_MEMORY.
// With R raw bytes and B = ceil(R / 65535) blocks the IDAT data is D = 2
// + R + 5 B + 4 bytes and the file 8 + 25 + (12 + D) + 12 = 57 + D.
//
// CRC-32 (ISO 3309, reflected polynomial EDB88320, initial and final XOR
// FFFFFFFF) is computed bitwise, 8 steps per byte, no table and no
// state; Adler-32 reduces modulo 65521 after at most 5 552 bytes (the
// largest run whose sums cannot overflow 32 bits); base64 is RFC 4648's
// alphabet with `=` padding and no line breaks.
//
// ABI: AAPCS64; every routine preserves x19-x28, x29, sp, d8-d15 and FPCR
// (never written); no routine recurses.
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

.equ RPNG_BLOCK,    65535           /* the largest stored block */
.equ RPNG_NMAX,     5552            /* bytes per Adler-32 reduction */
.equ RPNG_MOD,      65521           /* the Adler-32 modulus */
.equ RPNG_FIXED,    57              /* signature + IHDR + IDAT and IEND framing */
.equ RPNG_IDATMAX,  0x7fffffff      /* the largest IDAT (L-kt) */

// The address of a label.
.macro LADR reg, label
    adrp \reg, \label@PAGE
    add \reg, \reg, \label@PAGEOFF
.endm
// Store the low 32 bits of a w register big-endian at [base + off] (tmp
// scratch).
.macro STBE32 wreg, base, off, tmp
    rev \tmp, \wreg
    str \tmp, [\base, #\off]
.endm

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// _sea_crc32 -- the CRC-32 of a byte string, bitwise.
//   Inputs  : x0 = bytes, x1 = count
//   Outputs : w0 = the CRC
//   Clobbers: x0-x6, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .private_extern _sea_crc32
    .p2align 2
_sea_crc32:
    mov w2, #-1                     // the register, initial FFFFFFFF
    movz w3, #0x8320                // the reflected polynomial EDB88320
    movk w3, #0xedb8, lsl #16
1:  cbz x1, 3f
    ldrb w4, [x0], #1
    eor w2, w2, w4                  // the next byte into the low bits
    mov x5, #8
2:  sbfx w6, w2, #0, #1             // all ones when the low bit is set
    and w6, w6, w3
    eor w2, w6, w2, lsr #1          // shift right, xor the polynomial if it was set
    subs x5, x5, #1
    b.ne 2b
    sub x1, x1, #1
    b 1b
3:  mvn w0, w2                      // the final XOR
    ret

// ---------------------------------------------------------------------
// _sea_adler32 -- the Adler-32 of a byte string: s1 = 1, s2 = 0, per byte
//   s1 += byte, s2 += s1, both reduced modulo 65521 after every run of at
//   most 5 552 bytes; the result s2 * 65536 + s1.
//   Inputs  : x0 = bytes, x1 = count
//   Outputs : w0 = the checksum
//   Clobbers: x0-x7, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .private_extern _sea_adler32
    .p2align 2
_sea_adler32:
    mov x2, #1                      // s1
    mov x3, #0                      // s2
    mov x7, #RPNG_MOD
1:  cbz x1, 4f
    mov x4, #RPNG_NMAX              // this run: min(count, 5552) bytes
    cmp x1, x4
    csel x4, x1, x4, lo
    sub x1, x1, x4
2:  ldrb w5, [x0], #1
    add x2, x2, x5                  // s1 += byte
    add x3, x3, x2                  // s2 += s1
    subs x4, x4, #1
    b.ne 2b
    udiv x6, x2, x7                 // both modulo 65521
    msub x2, x6, x7, x2
    udiv x6, x3, x7
    msub x3, x6, x7, x3
    b 1b
4:  orr x0, x2, x3, lsl #16         // s2 * 65536 + s1
    ret

// ---------------------------------------------------------------------
// _sea_b64 -- base64 (RFC 4648, `=` padding, no line breaks) of a byte
//   string into a buffer of at least 4 * ceil(count / 3) bytes.
//   Inputs  : x0 = destination, x1 = bytes, x2 = count
//   Outputs : x0 = the bytes written (4 * ceil(count / 3))
//   Clobbers: x0-x10, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .private_extern _sea_b64
    .p2align 2
_sea_b64:
    mov x9, x0                      // the start, for the count
    LADR x3, Lrpng_alpha
1:  cmp x2, #3
    b.lo 2f
    // Three bytes: four letters of six bits each, the highest first.
    ldrb w4, [x1]
    ldrb w5, [x1, #1]
    ldrb w6, [x1, #2]
    add x1, x1, #3
    sub x2, x2, #3
    lsl w4, w4, #16
    orr w4, w4, w5, lsl #8
    orr w4, w4, w6                  // the 24-bit group
    ubfx w5, w4, #18, #6
    ldrb w5, [x3, x5]
    strb w5, [x0]
    ubfx w5, w4, #12, #6
    ldrb w5, [x3, x5]
    strb w5, [x0, #1]
    ubfx w5, w4, #6, #6
    ldrb w5, [x3, x5]
    strb w5, [x0, #2]
    and w5, w4, #0x3f
    ldrb w5, [x3, x5]
    strb w5, [x0, #3]
    add x0, x0, #4
    b 1b
2:  cbz x2, 9f                      // nothing left: no padding
    // One or two bytes left: the group padded with zero bits, then `=`.
    ldrb w4, [x1]
    lsl w4, w4, #16
    mov w6, #'='
    cmp x2, #2
    b.lo 3f
    ldrb w5, [x1, #1]
    orr w4, w4, w5, lsl #8
3:  ubfx w5, w4, #18, #6
    ldrb w5, [x3, x5]
    strb w5, [x0]
    ubfx w5, w4, #12, #6
    ldrb w5, [x3, x5]
    strb w5, [x0, #1]
    strb w6, [x0, #3]               // the last letter is always padding
    strb w6, [x0, #2]               // and the third with one byte left ...
    cmp x2, #2
    b.lo 4f
    ubfx w5, w4, #6, #6             // ... else a letter
    ldrb w5, [x3, x5]
    strb w5, [x0, #2]
4:  add x0, x0, #4
9:  sub x0, x0, x9                  // the bytes written
    ret

// ---------------------------------------------------------------------
// _sea_png -- the PNG file of an RGB image from its raw data (the file
//   header's layout).
//   Inputs  : x0 = raw data (rows top-down, each the filter byte 0 and
//             3w bytes), x1 = its length R (>= 1), x2 = w, x3 = h,
//             x4 = site
//   Outputs : x0 = the file (a new uncounted block of exactly x1 bytes),
//             x1 = its length 57 + D
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = raw, x20 = R, x21 = w, x22 = h, x23 = site,
//             x24 = the file, x25 = D, x26 = the cursor (and the bytes
//             left of the raw data in the block loop: x21)
//   Frame   : 80 bytes (frame record + x19..x26)
// ---------------------------------------------------------------------
    .private_extern _sea_png
    .p2align 2
_sea_png:
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    // D = 2 + R + 5 B + 4 with B = ceil(R / 65535); over 2^31 - 1 is
    // OUT_OF_MEMORY (R <= 2^62, so nothing here overflows).
    mov x9, #RPNG_BLOCK
    add x10, x20, x9
    sub x10, x10, #1
    udiv x10, x10, x9               // B
    add x11, x10, x10, lsl #2       // 5 B
    add x25, x20, x11
    add x25, x25, #6                // D
    mov x9, #RPNG_IDATMAX
    cmp x25, x9
    b.hi Lrpng_oom
    add x0, x25, #RPNG_FIXED        // the file's size
    mov x1, x23
    bl _sea_alloc                   // noreturn on failure
    mov x24, x0
    // The signature.
    LADR x9, Lrpng_sig
    ldr x10, [x9]
    str x10, [x24]
    // IHDR: length 13, the type, w, h, 8 2 0 0 0, the CRC of 17 bytes.
    mov w10, #13
    STBE32 w10, x24, 8, w11
    LADR x9, Lrpng_ihdr
    ldr w10, [x9]
    str w10, [x24, #12]
    STBE32 w21, x24, 16, w11
    STBE32 w22, x24, 20, w11
    mov w10, #8
    strb w10, [x24, #24]            // depth 8
    mov w10, #2
    strb w10, [x24, #25]            // colour type 2 (RGB)
    strb wzr, [x24, #26]            // deflate
    strb wzr, [x24, #27]            // filter method 0
    strb wzr, [x24, #28]            // no interlace
    add x0, x24, #12
    mov x1, #17
    bl _sea_crc32
    STBE32 w0, x24, 29, w11
    // IDAT: length D, the type, the zlib header 78 01.
    STBE32 w25, x24, 33, w11
    LADR x9, Lrpng_idat
    ldr w10, [x9]
    str w10, [x24, #37]
    mov w10, #0x78
    strb w10, [x24, #41]
    mov w10, #0x01
    strb w10, [x24, #42]
    add x26, x24, #43               // the cursor: the first block
    mov x21, x20                    // raw bytes left (w is no longer needed)
    mov x22, x19                    // the raw cursor (h is no longer needed)
1:  // One stored block: LEN = min(left, 65535), BFINAL when it is the last.
    mov x9, #RPNG_BLOCK
    cmp x21, x9
    csel x10, x21, x9, ls           // LEN
    cset w11, ls                    // the last block?
    strb w11, [x26]                 // the header byte (BTYPE 00)
    strb w10, [x26, #1]             // LEN, little-endian
    lsr w12, w10, #8
    strb w12, [x26, #2]
    mvn w12, w10                    // NLEN
    strb w12, [x26, #3]
    lsr w12, w12, #8
    strb w12, [x26, #4]
    add x0, x26, #5
    mov x1, x22
    mov x2, x10
    add x26, x0, x10                // past the block
    add x22, x22, x10
    sub x21, x21, x10
    bl _memcpy                      // its bytes
    cbnz x21, 1b
    // The Adler-32 of the raw data, then the CRC of type and data.
    mov x0, x19
    mov x1, x20
    bl _sea_adler32
    rev w0, w0
    str w0, [x26]
    add x26, x26, #4
    add x0, x24, #37
    add x1, x25, #4
    bl _sea_crc32
    rev w0, w0
    str w0, [x26]
    add x26, x26, #4
    // IEND: length 0, the type, the CRC of the type.
    str wzr, [x26]
    LADR x9, Lrpng_iend
    ldr w10, [x9]
    str w10, [x26, #4]
    add x0, x26, #4
    mov x1, #4
    bl _sea_crc32
    rev w0, w0
    str w0, [x26, #8]
    mov x0, x24
    add x1, x25, #RPNG_FIXED
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret
Lrpng_oom:
    mov w0, #SEA_E_OUT_OF_MEMORY
    mov x1, x23                     // the site
    mov x2, #0
    bl _sea_err                     // noreturn

    .section __TEXT,__const
Lrpng_sig:   .byte 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
Lrpng_ihdr:  .ascii "IHDR"
Lrpng_idat:  .ascii "IDAT"
Lrpng_iend:  .ascii "IEND"
Lrpng_alpha: .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
