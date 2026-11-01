# =====================================================================
# sea/runtime/x86_64_linux/rt_kern.s -- the kernel variant of Sea's own
# kernels (DESIGN.md 4.4, 4.7.1 "Kernel variant", 4.8 symbol sea_variant,
# 2.13.5 "Variants", L-iu). The x86_64-linux twin of
# runtime/arm64_macos/rt_kern.s.
#
# Defines: sea_variant   (global, rt.inc): u64, the SEA_VAR_* id of the
#          selected kernel variant, SEA_VAR_SSE2 or SEA_VAR_AVX2. main
#          (rt_main.s) stores it before sea_main runs. Compiled code reads
#          it for LIR `vfeat avx2`, and Sea's kernels (rt_gemm.s) read it
#          to choose their form.
# Uses   : nothing.
#
# The cell lives here and not in rt_main.s (L-iu) so that a C test
# (tests/la/la_check.c) can link the runtime's kernel entries from
# libsea.a with its own main: it then sets the cell itself. No code.
# =====================================================================
.include "rt.inc"

    .bss
    .p2align 3
    .globl sea_variant
    .type sea_variant, @object
    .size sea_variant, 8
sea_variant:
    .zero 8                         # SEA_VAR_* of the selected variant

    .section .note.GNU-stack,"",@progbits
