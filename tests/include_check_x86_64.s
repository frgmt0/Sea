# tests/include_check_x86_64.s -- assembled on Linux by
# `make -f Makefile.linux check-includes` (GNU as, x86_64 ELF).
# Proves that Sea's contract include files parse with GNU as, are safe to
# include twice, define no name that Baysick's include/limits.inc or
# include/runtime.inc define (Sea's names use .equiv, so a clash is an
# error), that the documented layouts and code ranges hold
# (include_asserts.inc), and that the emitted tables have the documented
# sizes. bsk_contract.inc is written by Makefile.linux into its temporary
# directory: it includes Baysick's two files by absolute path, so the
# search path cannot pick Sea's own limits.inc instead.
# The Apple as / arm64 twin is tests/include_check.s.
.include "bsk_contract.inc"
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"
.include "include_asserts.inc"

    .section .data.rel.ro,"aw",@progbits
    SEA_EMIT_ERRMSG_TABLE .Lerrtab
SEA_ASSERT ((sea_errmsg_1 - .Lerrtab) == (SEA_E_RT_END*SEA_ERRTAB_SIZE)), "message table records"
SEA_ASSERT ((sea_errargs_1 - sea_errmsg_1) == 53),          "message 1 text (with NUL)"
SEA_ASSERT ((sea_errmsg_2 - sea_errargs_1) == 4),           "message 1 args (with NUL)"
SEA_ASSERT ((sea_errargs_19 - sea_errmsg_19) == 24),        "message 19: escaped quotes are one byte each"
SEA_ASSERT ((sea_errmsg_5 - sea_errargs_4) == 1),           "no args: empty string"

    SEA_EMIT_ERRNO_TABLE .Lerrnotab, linux
SEA_ASSERT ((sea_errno_text_0 - .Lerrnotab) == (SEA_ERRNO_COUNT*SEA_ERRNO_SIZE)), "errno table records"
SEA_ASSERT ((sea_errno_text_1 - sea_errno_text_0) == 14),   "errno text 0 (with NUL)"
SEA_ASSERT ((sea_errno_text_3 - sea_errno_text_2) == 26),   "errno text 2 (with NUL)"

    .text
    ret

    .section .note.GNU-stack,"",@progbits
