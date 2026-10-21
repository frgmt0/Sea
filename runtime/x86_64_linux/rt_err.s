# =====================================================================
# sea/runtime/x86_64_linux/rt_err.s -- run-time error reporting
# (LANGUAGE.md 9.2, 9.4; DESIGN.md 4.5, 4.6, 4.7.1, 4.8, 2.6.2).
# The x86_64-linux twin of runtime/arm64_macos/rt_err.s.
#
# Defines: sea_err   (global, rt.inc)
#
#   sea_err(%rdi = code SEA_E_* 1 .. SEA_E_RT_END-1,
#           %rsi = site index into sea_sites, or SEA_SITE_NONE,
#           %rdx = address of the argument slots)           noreturn
#
# The sequence of LANGUAGE.md 9.2:
#   1. standard output is flushed (sea_out_flush; a broken stdout
#      stays broken and the failure is ignored: the status is 1 anyway);
#   2. one line goes to standard error, written with one write(2) (or
#      several if it exceeds RT_ERR_BUF_BYTES):
#        `<file>:<line>: error: <message>` + LF         site given
#        `error: <message>` + LF                        SEA_SITE_NONE
#      <file> is the string object at SEA_SITE_FILE of the record
#      `sea_sites + SEA_SITE_SIZE*site`, <line> its SEA_SITE_LINE;
#   3. open output files are flushed and closed: Sea's file writers
#      open, write and close within one call and keep no descriptor
#      open between calls, so nothing is left to flush here;
#   4. the process ends with _exit(SEA_EXIT_RUN_ERROR) (1), never exit:
#      no atexit handler or library flush runs, which also makes this
#      path safe from the SIGSEGV / SIGBUS handler of rt_main.s
#      (DESIGN.md 4.6).
# A code outside 1 .. SEA_E_RT_END-1 (a caller bug) prints nothing after
# the flush and exits 1.
#
# The message text and the args letters come from the table that
# SEA_EMIT_ERRMSG_TABLE (errors.inc) emits, the same macro as the
# arm64-macos runtime's, so the texts cannot diverge. Each `%x` of the
# text takes the next letter of the args string and the next slot(s):
#   i  one slot, i64, decimal (a leading '-' if negative)
#   f  one slot, the bits of an f64, text from `sea_fmt_g`
#   s  one slot, a string object (SEA_STR_LEN at +16, bytes at +24)
#   h  two slots: rows, then cols or SEA_SHAPE_VEC: `RxC` or `R`
#   e  one slot, the host errno value; the reason is the text of the
#      errno-table record (the linux column) with that value, or of
#      record 0 if none has
# (an `%` is always followed by one conversion character, which is
# skipped; the character itself is not looked at).
#
# EXTERNAL INTERNAL SYMBOL used (defined by rt_fmt.s, not here):
#   sea_fmt_g(%rdi = destination buffer of at least 16 bytes (this file
#             passes RT_ERR_FMTG_BYTES = 32), %xmm0 = the f64)
#             -> %rax = number of bytes written
#   writes the text of printf("%g") in Sea's rules (LANGUAGE.md 11.1).
#
# Standard error is unbuffered for the program but this routine collects
# the line in a static buffer of RT_ERR_BUF_BYTES bytes (written when
# full and at the end), so a normal message is one write(2).
# =====================================================================
.include "errors.inc"
.include "rt.inc"

.equ RT_ERR_BUF_BYTES,  4096        # the line buffer; longer lines are written in pieces
.equ RT_ERR_FMTG_BYTES, 32          # bytes sea_fmt_g may write (at 0(%rsp))
.equ RT_ERR_SAVE,       40          # offset of the 8-byte save slot in sea_err's scratch
.equ RT_ERR_SCRATCH,    48          # stack scratch of sea_err: sea_fmt_g output, save slot

    .text

# ---------------------------------------------------------------------
# .Lrt_err_put -- append bytes to the line buffer, writing it to fd 2
#   whenever it becomes full.
#   Inputs  : %rdi = pointer, %rsi = byte count (may be 0)
#   Outputs : none
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = source cursor, %r12 = bytes left (both
#             saved and restored), %rbp = frame pointer
#   Frame   : 24 bytes (%rbp %rbx %r12); %rsp = 0 (mod 16) at the calls
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_err_put:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    movq %rdi, %rbx
    movq %rsi, %r12
.Lrt_err_put_loop:
    testq %r12, %r12
    jz .Lrt_err_put_done
    movq .Lrt_err_fill(%rip), %rcx  # bytes in the buffer
    movl $RT_ERR_BUF_BYTES, %edx
    subq %rcx, %rdx                 # free space (>= 1)
    cmpq %rdx, %r12
    cmovbq %r12, %rdx               # n = min(left, free)
    leaq .Lrt_err_buf(%rip), %rdi
    addq %rcx, %rdi                 # destination
    addq %rdx, %rcx
    movq %rcx, .Lrt_err_fill(%rip)  # fill += n
    movq %rbx, %rsi
    addq %rdx, %rbx
    subq %rdx, %r12
    call memcpy@PLT
    cmpq $RT_ERR_BUF_BYTES, .Lrt_err_fill(%rip)
    jb .Lrt_err_put_loop            # not full yet
    call .Lrt_err_flush             # full: write it out
    jmp .Lrt_err_put_loop
.Lrt_err_put_done:
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_err_flush -- write the line buffer to fd 2 and empty it.
#   Purpose : a failed write to standard error is ignored (there is no
#             better channel to report it on).
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp = frame pointer
#   Frame   : 8 bytes (%rbp)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_err_flush:
    pushq %rbp
    movq %rsp, %rbp
    movq .Lrt_err_fill(%rip), %rdx
    movq $0, .Lrt_err_fill(%rip)    # emptied either way
    testq %rdx, %rdx
    jz .Lrt_err_flush_ret
    movl $2, %edi
    leaq .Lrt_err_buf(%rip), %rsi
    call sea_write_all              # result ignored
.Lrt_err_flush_ret:
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_err_put_dec -- append the decimal text of a 64-bit integer.
#   Inputs  : %rdi = value, %esi = 1 if %rdi is a signed i64, 0 if
#             unsigned
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp = frame pointer
#   Frame   : 8 bytes (%rbp) + 32 (digit scratch at 0(%rsp); at most 20
#             digits and a sign)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_err_put_dec:
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp                  # %rsp = 0 (mod 16)
    leaq 32(%rsp), %r8              # end of the scratch: digits are written backwards
    xorl %r9d, %r9d                 # sign needed?
    movq %rdi, %rax
    testl %esi, %esi
    jz 1f
    testq %rax, %rax
    jns 1f
    negq %rax                       # magnitude (INT64_MIN stays 2^63 as unsigned)
    movl $1, %r9d
1:
    movl $10, %ecx
.Lrt_err_dec_loop:
    xorl %edx, %edx
    divq %rcx                       # %rax = quotient, %rdx = next digit
    addb $48, %dl                   # '0'
    decq %r8
    movb %dl, (%r8)
    testq %rax, %rax
    jnz .Lrt_err_dec_loop
    testl %r9d, %r9d
    jz 2f
    decq %r8
    movb $45, (%r8)                 # '-'
2:
    leaq 32(%rsp), %rsi
    subq %r8, %rsi                  # byte count
    movq %r8, %rdi
    call .Lrt_err_put
    movq %rbp, %rsp
    popq %rbp
    ret

# ---------------------------------------------------------------------
# sea_err -- see the file header.
#   Inputs  : %rdi = code, %rsi = site index or SEA_SITE_NONE,
#             %rdx = slots
#   Outputs : never returns
#   Clobbers: everything
#   Callee-saved used (not restored: the function never returns):
#             %rbx = code, %r12 = site, %r13 = slot cursor,
#             %r14 = message cursor, %r15 = args-letter cursor,
#             %rbp = frame pointer
#   Frame   : 8 bytes (%rbp), then %rsp is rounded down to a multiple
#             of 16 (it may be entered from the signal handler) and
#             RT_ERR_SCRATCH bytes of scratch at 0(%rsp)
# ---------------------------------------------------------------------
    .globl sea_err
    .type sea_err, @function
    .p2align 4
sea_err:
    pushq %rbp
    movq %rsp, %rbp
    andq $-16, %rsp                 # noreturn: force 16-byte alignment
    subq $RT_ERR_SCRATCH, %rsp      # scratch at 0(%rsp)
    movq %rdi, %rbx                 # code
    movq %rsi, %r12                 # site
    movq %rdx, %r13                 # argument slots

    # 1. Standard output first, so the message follows all output.
    #    A failure (stdout broken) is ignored here.
    call sea_out_flush

    # A code that is not a run-time code prints nothing.
    leaq -1(%rbx), %rax
    cmpq $(SEA_E_RT_END - 2), %rax
    ja .Lrt_err_exit

    movq $0, .Lrt_err_fill(%rip)    # an empty line buffer

    # 2a. `<file>:<line>: ` when the error has a location.
    cmpq $SEA_SITE_NONE, %r12
    je .Lrt_err_nosite
    imulq $SEA_SITE_SIZE, %r12, %rax
    leaq sea_sites(%rip), %rcx
    addq %rcx, %rax                 # record = sites + site * SEA_SITE_SIZE
    movq SEA_SITE_FILE(%rax), %rcx  # the static string object of the path
    movq SEA_STR_LEN(%rcx), %rsi
    leaq SEA_STR_BYTES(%rcx), %rdi
    call .Lrt_err_put
    leaq .Lrt_err_s_colon(%rip), %rdi
    movl $1, %esi
    call .Lrt_err_put
    imulq $SEA_SITE_SIZE, %r12, %rax # the record again (caller-saved registers are gone)
    leaq sea_sites(%rip), %rcx
    addq %rcx, %rax
    movq SEA_SITE_LINE(%rax), %rdi
    xorl %esi, %esi                 # unsigned
    call .Lrt_err_put_dec
    leaq .Lrt_err_s_colonsp(%rip), %rdi
    movl $2, %esi
    call .Lrt_err_put
.Lrt_err_nosite:
    # 2b. `error: `
    leaq .Lrt_err_s_error(%rip), %rdi
    movl $7, %esi
    call .Lrt_err_put

    # 2c. The message with its substitutions.
    imulq $SEA_ERRTAB_SIZE, %rbx, %rax
    leaq .Lrt_err_tab(%rip), %rcx
    addq %rcx, %rax                 # record = table + SEA_ERRTAB_SIZE * code
    movq SEA_ERRTAB_MSG(%rax), %r14
    movq SEA_ERRTAB_ARGS(%rax), %r15
.Lrt_err_scan:
    movq %r14, %rdi                 # start of a literal run
1:  movzbl (%r14), %eax
    testl %eax, %eax
    jz .Lrt_err_lit_end             # end of the text
    cmpl $37, %eax                  # '%': a substitution follows
    je .Lrt_err_lit_end
    incq %r14
    jmp 1b
.Lrt_err_lit_end:
    movq %r14, %rsi
    subq %rdi, %rsi
    call .Lrt_err_put               # the literal run
    movzbl (%r14), %eax
    testl %eax, %eax
    jz .Lrt_err_msg_done
    addq $2, %r14                   # skip `%` and its conversion character
    movzbl (%r15), %eax             # the args letter of this substitution
    testl %eax, %eax
    jz .Lrt_err_scan                # no letter left (cannot happen with a valid table)
    incq %r15
    cmpl $105, %eax                 # 'i'
    je .Lrt_err_a_i
    cmpl $102, %eax                 # 'f'
    je .Lrt_err_a_f
    cmpl $115, %eax                 # 's'
    je .Lrt_err_a_s
    cmpl $104, %eax                 # 'h'
    je .Lrt_err_a_h
    cmpl $101, %eax                 # 'e'
    je .Lrt_err_a_e
    jmp .Lrt_err_scan               # unknown letter (cannot happen with a valid table)

.Lrt_err_a_i:                       # i64, decimal
    movq (%r13), %rdi
    addq $SEA_SLOT_SIZE, %r13
    movl $1, %esi
    call .Lrt_err_put_dec
    jmp .Lrt_err_scan

.Lrt_err_a_f:                       # f64, Sea's %g
    movq (%r13), %xmm0
    addq $SEA_SLOT_SIZE, %r13
    movq %rsp, %rdi                 # the scratch holds RT_ERR_FMTG_BYTES bytes of text
    call sea_fmt_g                  # %rax = byte count
    movq %rax, %rsi
    movq %rsp, %rdi
    call .Lrt_err_put
    jmp .Lrt_err_scan

.Lrt_err_a_s:                       # string object
    movq (%r13), %rcx
    addq $SEA_SLOT_SIZE, %r13
    movq SEA_STR_LEN(%rcx), %rsi
    leaq SEA_STR_BYTES(%rcx), %rdi
    call .Lrt_err_put
    jmp .Lrt_err_scan

.Lrt_err_a_h:                       # shape: rows [x cols]
    movq (%r13), %rdi               # rows
    movq SEA_SLOT_SIZE(%r13), %rax  # cols (SEA_SHAPE_VEC for a vector)
    addq $(2*SEA_SLOT_SIZE), %r13
    movq %rax, RT_ERR_SAVE(%rsp)    # keep cols across the call
    xorl %esi, %esi
    call .Lrt_err_put_dec
    cmpq $SEA_SHAPE_VEC, RT_ERR_SAVE(%rsp)
    je .Lrt_err_scan                # a vector has no `x cols`
    leaq .Lrt_err_s_x(%rip), %rdi
    movl $1, %esi
    call .Lrt_err_put
    movq RT_ERR_SAVE(%rsp), %rdi
    xorl %esi, %esi
    call .Lrt_err_put_dec
    jmp .Lrt_err_scan

.Lrt_err_a_e:                       # errno reason from the table
    movq (%r13), %rax               # host errno value
    addq $SEA_SLOT_SIZE, %r13
    leaq .Lrt_err_errno(%rip), %rcx
    movq SEA_ERRNO_TEXT(%rcx), %rdi # default: the text of record 0
    leaq SEA_ERRNO_SIZE(%rcx), %rdx # records 1 .. SEA_ERRNO_COUNT-1 are searched
    movl $(SEA_ERRNO_COUNT - 1), %r8d
2:  cmpq SEA_ERRNO_HOST(%rdx), %rax
    jne 3f
    movq SEA_ERRNO_TEXT(%rdx), %rdi # found
    jmp 4f
3:  addq $SEA_ERRNO_SIZE, %rdx
    decl %r8d
    jnz 2b
4:  movq %rdi, RT_ERR_SAVE(%rsp)
    call strlen@PLT
    movq %rax, %rsi
    movq RT_ERR_SAVE(%rsp), %rdi
    call .Lrt_err_put
    jmp .Lrt_err_scan

.Lrt_err_msg_done:
    leaq .Lrt_err_s_lf(%rip), %rdi
    movl $1, %esi
    call .Lrt_err_put
    call .Lrt_err_flush             # the whole line, one write(2)

.Lrt_err_exit:
    movl $SEA_EXIT_RUN_ERROR, %edi
    call _exit@PLT                  # does not return
    ud2                             # not reached
    .size sea_err, . - sea_err

# ---------------------------------------------------------------------
# Constant data: the message and errno tables (errors.inc macros) and
# the few literals of the line.
# ---------------------------------------------------------------------
    .section .data.rel.ro,"aw",@progbits
    SEA_EMIT_ERRMSG_TABLE .Lrt_err_tab
    SEA_EMIT_ERRNO_TABLE .Lrt_err_errno, linux

    .section .rodata
.Lrt_err_s_colon:    .ascii ":"
.Lrt_err_s_colonsp:  .ascii ": "
.Lrt_err_s_error:    .ascii "error: "
.Lrt_err_s_x:        .ascii "x"
.Lrt_err_s_lf:       .ascii "\n"

    .bss
    .p2align 4
.Lrt_err_buf:
    .zero RT_ERR_BUF_BYTES          # the line buffer
    .p2align 3
.Lrt_err_fill:
    .zero 8                         # bytes in the line buffer

    .section .note.GNU-stack,"",@progbits
