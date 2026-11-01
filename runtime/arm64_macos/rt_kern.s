// =====================================================================
// sea/runtime/arm64_macos/rt_kern.s -- the kernel variant of Sea's own
// kernels (DESIGN.md 4.4, 4.8 symbol _sea_variant, 2.13.5 "Variants",
// L-iu).
//
// Defines: _sea_variant   (global, rt.inc): u64, the SEA_VAR_* id of the
//          selected kernel variant. main (rt_main.s) stores it before
//          _sea_main runs; on arm64-macos it is always SEA_VAR_NEON.
//          Compiled code reads it for LIR `vfeat`, and Sea's kernels
//          (rt_gemm.s) read it to choose their form.
// Uses   : nothing.
//
// The cell lives here and not in rt_main.s (L-iu) so that a C test
// (tests/la/la_check.c) can link the runtime's kernel entries from
// libsea.a with its own main: it then sets the cell itself. No code.
// =====================================================================
.include "rt.inc"

    .section __DATA,__bss
    .globl _sea_variant
.zerofill __DATA,__bss,_sea_variant,8,3     /* SEA_VAR_* of the selected variant */
