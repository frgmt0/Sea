# =====================================================================
# sea/runtime/x86_64_linux/rt_out.s -- buffered standard output and the
# raw write loop (DESIGN.md 4.5 "I/O", 4.6, 4.7.1; LANGUAGE.md 9.2, 11.3).
# The x86_64-linux twin of runtime/arm64_macos/rt_out.s: same routines,
# same buffer, same failure model.
#
# Defines (all .globl + .hidden: internal to libsea, not a contract entry
# of rt.inc; used by rt_main.s, rt_err.s and rt_fmt.s):
#   sea_write_all    write(2) loop for any descriptor
#   sea_out_write    append bytes to the standard-output buffer
#   sea_out_repeat   append one byte value n times (padding)
#   sea_out_flush    write the buffer to fd 1
#   sea_out_bytes    sea_out_write whose failure is sea_out_fail
#   sea_out_fail     noreturn: report a failed stdout write as the
#                    run-time error `cannot write '<stdout>': <reason>`
#   sea_stdout_name  the static string object "<stdout>" (SEA_STR_*)
#
# THE BUFFER API (what sea_printf in rt_fmt.s calls). System V AMD64:
# %rax %rcx %rdx %rsi %rdi %r8-%r11 and %xmm0-%xmm15 are clobbered by
# every routine, %rbx %rbp %r12-%r15 are preserved. Every routine that
# can fail returns %rax = 0 on success, or the host errno value
# (nonzero) of the failed write; the failure is sticky:
#
#   sea_out_write (%rdi = pointer, %rsi = byte count) -> %rax
#       Appends the bytes. The buffer (SEA_STDOUT_BUF_BYTES = 64 KiB,
#       LANGUAGE.md 11.3) is written to fd 1 as soon as it is full.
#   sea_out_repeat (%edi = byte value, %rsi = count) -> %rax
#       Same as sea_out_write of `count` copies of the byte.
#   sea_out_flush () -> %rax
#       Writes whatever is buffered.
#   sea_out_bytes (%rdi = pointer, %rsi = byte count, %rdx = site index
#                  or SEA_SITE_NONE)
#       sea_out_write; on failure it does not return but runs
#       sea_out_fail(errno, site). Returns nothing on success.
#   sea_out_fail (%rdi = errno, %rsi = site index or SEA_SITE_NONE)
#       Never returns: sea_err(SEA_E_CANNOT_WRITE, site, slots) with
#       the slots { &sea_stdout_name, errno } built on the stack.
#
# Failure model (the Baysick rule, LANGUAGE.md 9.4: status 0 means every
# byte arrived). A write(2) that fails with anything but EINTR or EAGAIN,
# or that writes 0 bytes (reported as EIO), empties the buffer, marks
# stdout broken and remembers the errno. From then on sea_out_write,
# sea_out_repeat and sea_out_flush write nothing and return the
# remembered errno, so sea_err's own flush cannot loop and the process
# cannot exit 0 after losing output.
#
# Standard error is not buffered here; sea_err owns its line buffer.
# SIGPIPE is ignored by main (rt_main.s), so a closed pipe is EPIPE here,
# never a signal. glibc is called through the PLT (DESIGN.md 4.7.1).
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# Linux x86_64 values (DESIGN.md 4.7.1; private to the runtime).
.equ RT_OUT_EINTR,      4           # <errno.h> EINTR
.equ RT_OUT_EIO,        5           # <errno.h> EIO: a write that made no progress
.equ RT_OUT_EAGAIN,     11          # <errno.h> EAGAIN (= EWOULDBLOCK): a full non-blocking stdout
.equ RT_OUT_POLLOUT,    4           # <poll.h> POLLOUT
.equ RT_OUT_PFD_FD,     0           # struct pollfd: i32 fd
.equ RT_OUT_PFD_EVENTS, 4           # i16 events
.equ RT_OUT_PFD_REVENTS, 6          # i16 revents
.equ RT_OUT_PAD_CHUNK,  64          # bytes of the stack block sea_out_repeat copies from

    .text

# ---------------------------------------------------------------------
# sea_write_all -- write a whole byte range to a file descriptor.
#   Purpose : call write(2) until every byte is written; retry on
#             EINTR; on EAGAIN (a full non-blocking descriptor) wait
#             with poll(POLLOUT) and retry; give up on any other error
#             or on a write that makes no progress.
#   Inputs  : %edi = fd, %rsi = pointer, %rdx = byte count
#   Outputs : %rax = 0 if every byte was written, else the errno (EIO
#             for a write that returned 0)
#   Clobbers: all caller-saved registers (calls libc)
#   Callee-saved used: %rbx = fd, %r12 = cursor, %r13 = bytes remaining,
#             %rbp = frame pointer
#   Frame   : 40 bytes (%rbp %rbx %r12 %r13 + the 8-byte pollfd at
#             0(%rsp)); %rsp = 0 (mod 16) at every call
# ---------------------------------------------------------------------
    .globl sea_write_all
    .hidden sea_write_all
    .type sea_write_all, @function
    .p2align 4
sea_write_all:
    pushq %rbp                      # entered at 8 (mod 16): now 0
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp                   # the pollfd; %rsp = 0 (mod 16)
    movl %edi, %ebx                 # fd
    movq %rsi, %r12                 # next byte to write
    movq %rdx, %r13                 # bytes left
.Lrt_out_wa_loop:
    testq %r13, %r13
    jz .Lrt_out_wa_ok               # everything written
    movl %ebx, %edi
    movq %r12, %rsi
    movq %r13, %rdx
    call write@PLT                  # %rax = bytes written, or -1
    testq %rax, %rax
    js .Lrt_out_wa_err              # -1: inspect errno
    jz .Lrt_out_wa_noprog           # 0 bytes: no progress, give up
    addq %rax, %r12                 # advance past the bytes written
    subq %rax, %r13
    jmp .Lrt_out_wa_loop
.Lrt_out_wa_err:
    call __errno_location@PLT       # %rax = &errno (int *)
    movl (%rax), %eax               # the errno of the failed write
    cmpl $RT_OUT_EINTR, %eax
    je .Lrt_out_wa_loop             # interrupted: try again
    cmpl $RT_OUT_EAGAIN, %eax
    jne .Lrt_out_wa_done            # real error: %rax = errno
    # A non-blocking descriptor that is full: wait until it is writable
    # (poll on {fd, POLLOUT, 0}, no timeout), then write again. A poll
    # that fails is ignored: the next write reports the real error.
    movl %ebx, RT_OUT_PFD_FD(%rsp)
    movw $RT_OUT_POLLOUT, RT_OUT_PFD_EVENTS(%rsp)
    movw $0, RT_OUT_PFD_REVENTS(%rsp)
    movq %rsp, %rdi                 # &pollfd
    movl $1, %esi                   # one descriptor
    movl $-1, %edx                  # no timeout
    call poll@PLT
    jmp .Lrt_out_wa_loop
.Lrt_out_wa_noprog:
    movl $RT_OUT_EIO, %eax          # a write that writes nothing is EIO
    jmp .Lrt_out_wa_done
.Lrt_out_wa_ok:
    xorl %eax, %eax                 # all bytes written
.Lrt_out_wa_done:
    addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
    .size sea_write_all, . - sea_write_all

# ---------------------------------------------------------------------
# sea_out_flush -- write the buffered bytes to standard output.
#   Purpose : if stdout is already broken return the remembered errno
#             without writing; otherwise write the buffer with
#             sea_write_all and empty it. A failed write marks stdout
#             broken (the buffer is dropped) and remembers the errno.
#   Inputs  : none
#   Outputs : %rax = 0, or the errno of the (current or earlier) failure
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp = frame pointer
#   Frame   : 8 bytes (%rbp)
# ---------------------------------------------------------------------
    .globl sea_out_flush
    .hidden sea_out_flush
    .type sea_out_flush, @function
    .p2align 4
sea_out_flush:
    pushq %rbp                      # %rsp = 0 (mod 16)
    movq %rsp, %rbp
    movq .Lrt_out_err(%rip), %rax
    testq %rax, %rax
    jnz .Lrt_out_flush_ret          # already broken: %rax = errno
    movq .Lrt_out_fill(%rip), %rdx  # bytes buffered
    testq %rdx, %rdx
    jz .Lrt_out_flush_ret           # nothing to write (%rax = 0)
    movq $0, .Lrt_out_fill(%rip)    # the buffer is emptied either way
    movl $1, %edi                   # fd 1
    leaq .Lrt_out_buf(%rip), %rsi
    call sea_write_all              # %rax = 0 or errno
    testq %rax, %rax
    jz .Lrt_out_flush_ret
    movq %rax, .Lrt_out_err(%rip)   # failed: remember it (sticky)
.Lrt_out_flush_ret:
    popq %rbp
    ret
    .size sea_out_flush, . - sea_out_flush

# ---------------------------------------------------------------------
# sea_out_write -- append bytes to the standard-output buffer.
#   Purpose : copy the bytes into the buffer; whenever the buffer
#             becomes full write it out (sea_out_flush). A broken
#             stdout discards the bytes and returns the errno.
#   Inputs  : %rdi = pointer to the bytes, %rsi = byte count (may be 0)
#   Outputs : %rax = 0, or the errno of the failed write
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = source cursor, %r12 = bytes left,
#             %rbp = frame pointer
#   Frame   : 24 bytes (%rbp %rbx %r12); %rsp = 0 (mod 16) at the calls
# ---------------------------------------------------------------------
    .globl sea_out_write
    .hidden sea_out_write
    .type sea_out_write, @function
    .p2align 4
sea_out_write:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx                 # next source byte
    movq %rsi, %r12                 # bytes left
.Lrt_out_w_loop:
    movq .Lrt_out_err(%rip), %rax
    testq %rax, %rax
    jnz .Lrt_out_w_done             # broken: discard, report the errno
    testq %r12, %r12
    jz .Lrt_out_w_done              # nothing (more) to append: %rax = 0
    movq .Lrt_out_fill(%rip), %rcx  # fill
    movl $SEA_STDOUT_BUF_BYTES, %edx
    subq %rcx, %rdx                 # free space (>= 1: a full buffer is flushed at once)
    cmpq %rdx, %r12
    cmovbq %r12, %rdx               # n = min(left, free)
    leaq .Lrt_out_buf(%rip), %rdi
    addq %rcx, %rdi                 # destination = buffer + fill
    addq %rdx, %rcx
    movq %rcx, .Lrt_out_fill(%rip)  # fill += n
    movq %rbx, %rsi                 # source
    addq %rdx, %rbx                 # advance the cursor ...
    subq %rdx, %r12                 # ... and the count
    call memcpy@PLT                 # copy n bytes (%rdx)
    cmpq $SEA_STDOUT_BUF_BYTES, .Lrt_out_fill(%rip)
    jb .Lrt_out_w_loop              # room left: continue with the rest
    call sea_out_flush              # buffer full: write it out
    testq %rax, %rax
    jz .Lrt_out_w_loop
.Lrt_out_w_done:
    popq %r12
    popq %rbx
    popq %rbp
    ret
    .size sea_out_write, . - sea_out_write

# ---------------------------------------------------------------------
# sea_out_repeat -- append one byte value `count` times.
#   Purpose : padding for width fields. Builds a RT_OUT_PAD_CHUNK-byte
#             block on the stack and appends it with sea_out_write.
#   Inputs  : %edi = byte value, %rsi = count (may be 0)
#   Outputs : %rax = 0, or the errno of the failed write
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = bytes left, %rbp = frame pointer
#   Frame   : 16 bytes (%rbp %rbx) + 8 pad + RT_OUT_PAD_CHUNK (block at
#             0(%rsp)) = 88 bytes; %rsp = 0 (mod 16) at the calls
# ---------------------------------------------------------------------
    .globl sea_out_repeat
    .hidden sea_out_repeat
    .type sea_out_repeat, @function
    .p2align 4
sea_out_repeat:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx                      # %rsp = 8 (mod 16)
    subq $(RT_OUT_PAD_CHUNK + 8), %rsp # the block at 0(%rsp); %rsp = 0 (mod 16)
    movq %rsi, %rbx                 # bytes left
    movzbl %dil, %eax               # the byte ...
    movabsq $0x0101010101010101, %rcx
    imulq %rcx, %rax                # ... in all 8 bytes of %rax
    movq %rax, 0(%rsp)              # fill the 64-byte block
    movq %rax, 8(%rsp)
    movq %rax, 16(%rsp)
    movq %rax, 24(%rsp)
    movq %rax, 32(%rsp)
    movq %rax, 40(%rsp)
    movq %rax, 48(%rsp)
    movq %rax, 56(%rsp)
.Lrt_out_rep_loop:
    xorl %eax, %eax
    testq %rbx, %rbx
    jz .Lrt_out_rep_done            # all appended
    movl $RT_OUT_PAD_CHUNK, %esi
    cmpq %rsi, %rbx
    cmovbq %rbx, %rsi               # n = min(left, chunk)
    subq %rsi, %rbx
    movq %rsp, %rdi
    call sea_out_write
    testq %rax, %rax
    jz .Lrt_out_rep_loop            # ok: next chunk
.Lrt_out_rep_done:
    addq $(RT_OUT_PAD_CHUNK + 8), %rsp
    popq %rbx
    popq %rbp
    ret
    .size sea_out_repeat, . - sea_out_repeat

# ---------------------------------------------------------------------
# sea_out_bytes -- append bytes; a failed write is the run-time error.
#   Purpose : sea_out_write whose failure does not return: it is
#             sea_out_fail(errno, site). This is the entry rt_fmt.s
#             uses.
#   Inputs  : %rdi = pointer, %rsi = byte count (may be 0), %rdx = site
#             index or SEA_SITE_NONE
#   Outputs : returns only on success (nothing is returned)
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = site (saved and restored), %rbp = frame
#             pointer
#   Frame   : 24 bytes (%rbp %rbx + 8 pad)
# ---------------------------------------------------------------------
    .globl sea_out_bytes
    .hidden sea_out_bytes
    .type sea_out_bytes, @function
    .p2align 4
sea_out_bytes:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdx, %rbx                 # keep the site across the call
    call sea_out_write              # %rax = 0 or errno
    testq %rax, %rax
    jnz .Lrt_out_bytes_fail
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret
.Lrt_out_bytes_fail:
    movq %rax, %rdi                 # errno
    movq %rbx, %rsi                 # site
    call sea_out_fail               # noreturn
    ud2
    .size sea_out_bytes, . - sea_out_bytes

# ---------------------------------------------------------------------
# sea_out_fail -- a stdout write failed: report it and terminate.
#   Purpose : sea_err(SEA_E_CANNOT_WRITE, site, slots) with the slot
#             vector { &sea_stdout_name, errno } (args letters "se").
#   Inputs  : %rdi = host errno value, %rsi = site index or SEA_SITE_NONE
#   Outputs : never returns
#   Clobbers: everything
#   Callee-saved used: %rbp = frame pointer
#   Frame   : 8 bytes (%rbp) + 16-byte slot vector at 0(%rsp)
# ---------------------------------------------------------------------
    .globl sea_out_fail
    .hidden sea_out_fail
    .type sea_out_fail, @function
    .p2align 4
sea_out_fail:
    pushq %rbp
    movq %rsp, %rbp
    andq $-16, %rsp                 # noreturn: align however we came here
    subq $16, %rsp                  # the slot vector
    leaq sea_stdout_name(%rip), %rax
    movq %rax, 0(%rsp)              # slot 0 = path string
    movq %rdi, SEA_SLOT_SIZE(%rsp)  # slot 1 = errno
    movl $SEA_E_CANNOT_WRITE, %edi
    movq %rsp, %rdx                 # the slot vector (%rsi = site already)
    call sea_err                    # noreturn
    ud2                             # not reached
    .size sea_out_fail, . - sea_out_fail

# ---------------------------------------------------------------------
# Data. The string object is static (count SEA_RC_STATIC, SEA_STR_*),
# so it is shown by `%s` like any Sea string.
# ---------------------------------------------------------------------
    .section .rodata
    .p2align 3
    .globl sea_stdout_name
    .hidden sea_stdout_name
    .type sea_stdout_name, @object
sea_stdout_name:
    .quad SEA_RC_STATIC             # SEA_STR_RC
.Lrt_out_nm_tag:
    .byte SEA_TAG_STR               # SEA_STR_TAG
    .space SEA_STR_LEN - SEA_STR_TAG - 1, 0 # the rest of the header
.Lrt_out_nm_len:
    .quad 8                         # SEA_STR_LEN: the length of "<stdout>"
.Lrt_out_nm_bytes:
    .ascii "<stdout>"               # SEA_STR_BYTES
    .size sea_stdout_name, . - sea_stdout_name
.if (SEA_STR_RC != 0) || ((.Lrt_out_nm_tag - sea_stdout_name) != SEA_STR_TAG) || ((.Lrt_out_nm_len - sea_stdout_name) != SEA_STR_LEN) || ((.Lrt_out_nm_bytes - sea_stdout_name) != SEA_STR_BYTES)
    .error "rt_out: sea_stdout_name does not match the SEA_STR_* layout of rt.inc"
.endif

    .bss
    .p2align 4
.Lrt_out_buf:
    .zero SEA_STDOUT_BUF_BYTES      # the standard-output buffer
    .p2align 3
.Lrt_out_fill:
    .zero 8                         # bytes buffered, 0 .. SEA_STDOUT_BUF_BYTES-1 between calls
.Lrt_out_err:
    .zero 8                         # 0, or the errno that broke stdout (sticky)

    .section .note.GNU-stack,"",@progbits
