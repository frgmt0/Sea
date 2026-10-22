// =====================================================================
// sea/runtime/arm64_macos/rt_args.s -- the command-line arguments
// (DESIGN.md 4.5, 4.8 entry ARGS; LANGUAGE.md 10.10).
//
// Defines (global, rt.inc SEA_ENTRY_LIST):
//   _sea_args (site) -> a new str[] of the arguments after the program
//                       name, in order
// Uses: _sea_argc, _sea_argv (rt_main.s: main's argc and argv, saved
//       before it switches stacks), _sea_arr_new (rt_arr.s), _sea_alloc
//       and _sea_live (rt_mem.s), strlen and memcpy (libSystem).
//
// Each argument becomes a new string object (count 1, tag SEA_TAG_STR,
// bytes 9..15 zero, its bytes without the NUL; DESIGN.md 4.1), which adds
// one to the live counter; the vector holds the one count of each. An
// argument longer than SEA_LIM_STR_BYTES, or no memory, is
// _sea_err(SEA_E_OUT_OF_MEMORY, site).
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// _sea_args -- the entry ARGS.
//   Inputs  : x0 = site
//   Outputs : x0 = a new str[] (rank 1) of argc - 1 strings
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = site, x20 = the vector, x21 = argument
//             index (from 0), x22 = number of arguments, x23 = argv + 8
//             (the first argument), x24 = the current argument's length
//   Frame   : 64 bytes (frame record + x19..x24)
// ---------------------------------------------------------------------
    .globl _sea_args
    .p2align 2
_sea_args:
    stp x29, x30, [sp, #-64]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    // n = argc - 1 (0 if the program was started without even a name).
    adrp x9, _sea_argc@PAGE
    ldr x22, [x9, _sea_argc@PAGEOFF]
    subs x22, x22, #1
    csel x22, x22, xzr, gt
    adrp x9, _sea_argv@PAGE
    ldr x23, [x9, _sea_argv@PAGEOFF]
    add x23, x23, #8                // argv[1]
    // The vector: str elements, zeroed (null until filled below).
    mov x0, #SEA_EK_STR
    mov x1, #1                      // rank 1
    mov x2, x22                     // rows = n
    mov x3, #1                      // cols 1: a vector
    mov x4, x19
    bl _sea_arr_new
    mov x20, x0
    mov x21, #0
Lrt_args_loop:
    cmp x21, x22
    b.hs Lrt_args_done
    ldr x0, [x23, x21, lsl #3]      // argv[i + 1]
    bl _strlen
    mov x24, x0                     // its length
    mov x9, #SEA_LIM_STR_BYTES
    cmp x24, x9
    b.hi Lrt_args_oom               // longer than a str may be
    add x0, x0, #SEA_STR_BYTES      // header and bytes: one block
    mov x1, x19
    bl _sea_alloc                   // noreturn on failure
    mov x9, #1
    str x9, [x0, #SEA_STR_RC]       // count 1
    str xzr, [x0, #SEA_STR_TAG]     // bytes 8..15 zero
    mov w9, #SEA_TAG_STR
    strb w9, [x0, #SEA_STR_TAG]
    str x24, [x0, #SEA_STR_LEN]
    ldr x9, [x20, #SEA_ARR_DATA]
    str x0, [x9, x21, lsl #3]       // element i holds it
    adrp x9, _sea_live@PAGE
    ldr x10, [x9, _sea_live@PAGEOFF]
    add x10, x10, #1                // one more live object
    str x10, [x9, _sea_live@PAGEOFF]
    add x0, x0, #SEA_STR_BYTES      // copy the argument's bytes
    ldr x1, [x23, x21, lsl #3]
    mov x2, x24
    bl _memcpy
    add x21, x21, #1
    b Lrt_args_loop
Lrt_args_done:
    mov x0, x20
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
Lrt_args_oom:
    mov w0, #SEA_E_OUT_OF_MEMORY
    mov x1, x19                     // the site
    mov x2, #0
    bl _sea_err                     // noreturn
