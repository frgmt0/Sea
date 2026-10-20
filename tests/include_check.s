// tests/include_check.s -- assembled by `make check-includes` (macOS).
// Proves that Sea's contract include files parse with Apple `as`, are safe
// to include twice, define no name that Baysick's include/limits.inc or
// include/runtime.inc define (Sea's names use .equiv, so a clash is an
// error), that the documented layouts and code ranges hold
// (include_asserts.inc), and that the emitted tables have the documented
// sizes. bsk_contract.inc is written by the Makefile into its temporary
// directory: it includes Baysick's two files by absolute path, so the
// search path cannot pick Sea's own limits.inc instead.
// The GNU as / x86_64 ELF twin is tests/include_check_x86_64.s.
.include "bsk_contract.inc"
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"
.include "include_asserts.inc"

    .section __DATA,__const
    SEA_EMIT_ERRMSG_TABLE errtab
SEA_ASSERT ((sea_errmsg_1 - errtab) == (SEA_E_RT_END*SEA_ERRTAB_SIZE)), "message table records"
SEA_ASSERT ((sea_errargs_1 - sea_errmsg_1) == 53),          "message 1 text (with NUL)"
SEA_ASSERT ((sea_errmsg_2 - sea_errargs_1) == 4),           "message 1 args (with NUL)"
SEA_ASSERT ((sea_errargs_19 - sea_errmsg_19) == 24),        "message 19: escaped quotes are one byte each"
SEA_ASSERT ((sea_errmsg_5 - sea_errargs_4) == 1),           "no args: empty string"

    SEA_EMIT_ERRNO_TABLE errnotab, darwin
SEA_ASSERT ((sea_errno_text_0 - errnotab) == (SEA_ERRNO_COUNT*SEA_ERRNO_SIZE)), "errno table records"
SEA_ASSERT ((sea_errno_text_1 - sea_errno_text_0) == 14),   "errno text 0 (with NUL)"
SEA_ASSERT ((sea_errno_text_3 - sea_errno_text_2) == 26),   "errno text 2 (with NUL)"

    .section __TEXT,__text
    .p2align 2
    ret
