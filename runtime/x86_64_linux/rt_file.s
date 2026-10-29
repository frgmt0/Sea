# =====================================================================
# sea/runtime/x86_64_linux/rt_file.s -- make_dir and the JSON emitter
# (LANGUAGE.md 9.2, 10.10, 11.4; DESIGN.md 2.11.6, 4.5, 4.7.1, 4.8
# entries 25 and 27-38; L-bz, L-ca, L-cb, L-co).
# The x86_64-linux twin of runtime/arm64_macos/rt_file.s.
#
# Defines (global, rt.inc SEA_ENTRY_LIST):
#   sea_make_dir  (path, site)        create one directory level
#   sea_json_open (path, site)        begin a JSON file
#   sea_json_close (site)             LF, flush, close, free the state
#   sea_json_obj  (site)              begin an object as the next value
#   sea_json_arr  (site)              begin an array as the next value
#   sea_json_end  (site)              end the innermost container
#   sea_json_key  (key, site)         the next member's key
#   sea_json_f64  (x in %xmm0, site in %rdi)  a number or null
#   sea_json_i64  (v, site)           an i64 in decimal
#   sea_json_bool (v, site)           true / false
#   sea_json_str  (s, site)           an escaped string
#   sea_json_vec  (a, site)           a dynamic vector as a flat array
#   sea_json_mat  (a, site)           a dynamic matrix as an array of rows
# Defines (.globl + .hidden: internal to libsea, DESIGN.md 4.5):
#   sea_json_abort ()                 for sea_err (rt_err.s), step 3 of
#                  LANGUAGE.md 9.2: if a JSON file is open (the state
#                  exists and its descriptor is not -1), set the
#                  descriptor field to -1, write the buffered bytes and
#                  close the descriptor, ignoring a failure of either
#                  (L-ca). Clobbers the caller-saved registers.
#   sea_json_st    u64: the address of the emitter's state block, 0 while no
#                  write_json is running (the arm64 runtime's _sea_json_st;
#                  read by the rt tests to see the state freed)
# Uses: sea_alloc, sea_free_block, sea_retain, sea_release (rt_mem.s),
#   sea_write_all (rt_out.s), sea_err (rt_err.s); glibc memcpy, memchr,
#   mkdir, open, close, snprintf, __errno_location through the PLT.
#
# MAKE_DIR (DESIGN.md 4.8 entry 25, Decision 89, L-cb). The path's
# bytes are copied into a new NUL-terminated block (a path holding a NUL
# byte is CANNOT_MKDIR with EINVAL; the block is freed on every exit);
# mkdir(buf, 0777), the umask applying; success returns. On a failure the
# errno is saved first, then open(buf, O_RDONLY | O_DIRECTORY) tests for
# a directory (closed at once when it succeeds; no stat): a directory
# returns (`/` and `.` give EEXIST on Linux), anything else is
# sea_err(CANNOT_MKDIR, site, {path, saved errno}): an existing file
# `File exists`, a missing parent `No such file or directory` (no parent
# is created).
#
# THE JSON EMITTER (DESIGN.md 2.11.6). One state at a time (pass 2b's
# blocks do not nest), a heap block of RTJ_SIZE bytes whose address is
# in sea_json_st (0 while no write_json is running):
#   RTJ_FD     i64  the descriptor, -1 until JSON_OPEN stores it and
#                   after a failure closed it
#   RTJ_PATH   ptr  the path string, retained (released by JSON_CLOSE)
#   RTJ_BUF    ptr  the SEA_JSON_BUF_BYTES output buffer
#   RTJ_FILL   u64  bytes in it; < SEA_JSON_BUF_BYTES between calls
#                   (a full buffer is written at once)
#   RTJ_STK    ptr  the container stack: one byte per open container,
#                   bit RTJ_K_ARR set for an array (clear: an object),
#                   bit RTJ_K_HAS set once it has an element or member
#   RTJ_CAP    u64  its capacity in bytes (RTJ_STK_MIN, doubled as
#                   needed: no depth limit, L-co; no memory is
#                   OUT_OF_MEMORY at the entry's site)
#   RTJ_DEPTH  u64  the number of open containers
# Every block comes from sea_alloc, which does not count objects, and
# the retained path is released by JSON_CLOSE, so a completed
# write_json leaves sea_live unchanged (DESIGN.md 2.11.6).
#
# Layout (L-bz; LANGUAGE.md 11.4). A value at depth d (the top value at
# 0): a scalar in its spelling; a non-empty object `{`, LF, each member
# on its own line indented 2(d + 1) spaces as `"key": ` and its value at
# depth d + 1, `,` after every member but the last, then LF, 2d spaces,
# `}`; an array likewise with `[`, its elements and `]`; `{}` and `[]`
# when empty; after the top value one LF (JSON_CLOSE). The prefix of a
# value (the `,` after its predecessor, LF and the indentation) is
# written when the value begins (.Lrt_file_vstart): nothing for the top
# value or the value of a member (whose key wrote it), else `,` if the
# array already has an element, LF and 2 * depth spaces. A key writes
# the same prefix in its object, then the escaped key and `": "`. An end
# writes LF and 2 * (depth after the pop) spaces before `}` / `]` only
# when the container has an element. Numbers: %.17g through snprintf
# (as sea_str_f64), `null` for NaN and +-Inf; i64 in decimal by own
# code; strings: `\"`, `\\`, `\n`, `\t`, every other byte below 0x20 as
# `\u00` and two lowercase hex digits, every other byte (0x7F and 0x80 -
# 0xFF included) as it is.
#
# Failures (DESIGN.md 2.11.6, L-ca). Every entry stores its site in
# .Lrt_file_site first. A failed write of the buffer (or a failed final
# write or close in JSON_CLOSE) closes the descriptor if it is still open
# (ignoring that close's result), sets RTJ_FD to -1, keeps the state and
# its retained path, and calls sea_err(CANNOT_WRITE, site, {path, saved
# errno}); sea_err then finds no open file. JSON_OPEN allocates the
# state (descriptor -1) before it opens the file; a failed open (a NUL
# byte in the path: EINVAL) frees the state and then reports CANNOT_OPEN
# with the path (still valid: the caller holds it) and the errno.
#
# Linux values (DESIGN.md 4.7.1; private to the runtime, not rt.inc):
# O_RDONLY 0, O_WRONLY 1, O_CREAT 0x40, O_TRUNC 0x200, O_DIRECTORY
# 0x10000; EINVAL comes from errors.inc's errno table (linux column);
# open is variadic, so %al = 0 before the call.
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

.equ RT_FILE_O_RDONLY,    0
.equ RT_FILE_O_WCT,       0x241     # O_WRONLY | O_CREAT | O_TRUNC
.equ RT_FILE_O_DIRECTORY, 0x10000
# EINVAL's host value on this target, from the linux column of errors.inc's errno table
# (SEA_ERRNO_LIST), so the value is not written twice.
.macro RT_FILE_ERRNO_PICK id, name, darwin, linux, text
.ifc \name, EINVAL
.equ RT_FILE_EINVAL, \linux
.endif
.endm
SEA_ERRNO_LIST RT_FILE_ERRNO_PICK
.ifndef RT_FILE_EINVAL
    .error "rt_file: EINVAL is not in the errno table of errors.inc"
.endif
.equ RT_FILE_DIR_MODE,    0777      # mkdir mode, before the umask
.equ RT_FILE_JSON_MODE,   0666      # JSON file mode, before the umask

# The emitter state (see the file header).
.equ RTJ_FD,              0
.equ RTJ_PATH,            8
.equ RTJ_BUF,             16
.equ RTJ_FILL,            24
.equ RTJ_STK,             32
.equ RTJ_CAP,             40
.equ RTJ_DEPTH,           48
.equ RTJ_SIZE,            56
.equ RTJ_STK_MIN,         32        # first stack capacity (bytes = containers)
.equ RTJ_K_ARR,           1         # stack entry bit: an array (clear: an object)
.equ RTJ_K_HAS,           2         # stack entry bit: it has an element / member
.equ RTJ_SPACES,          64        # bytes of the blank run indentation copies from
.equ RTJ_NUMBUF,          32        # %.17g text (at most 24 bytes + NUL) and i64 digits
# The bits of +Inf shifted left by one: |bits| << 1 >= it is NaN or +-Inf.
.equ RTJ_INF2,            0xFFE0000000000000

    .text

# ---------------------------------------------------------------------
# .Lrt_file_cpath -- a NUL-terminated copy of a string's bytes.
#   Inputs  : %rdi = the string object, %rsi = site (out of memory)
#   Outputs : %rax = a new block of SEA_STR_LEN + 1 bytes (the caller
#             frees it with that byte count), %rdx = 1 if the string
#             holds a NUL byte, else 0
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = the string, %r12 =
#             the block, %rbp = frame pointer
#   Frame   : 24 bytes (%rbp %rbx %r12)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_cpath:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq SEA_STR_LEN(%rbx), %rdi
    incq %rdi                       # the bytes and the NUL
    call sea_alloc                  # (%rsi = site); out of memory there
    movq %rax, %r12
    movq %r12, %rdi
    leaq SEA_STR_BYTES(%rbx), %rsi
    movq SEA_STR_LEN(%rbx), %rdx
    call memcpy@PLT                 # the bytes
    movq SEA_STR_LEN(%rbx), %rcx
    movb $0, (%r12,%rcx)            # the terminating NUL
    leaq SEA_STR_BYTES(%rbx), %rdi
    xorl %esi, %esi
    movq SEA_STR_LEN(%rbx), %rdx
    call memchr@PLT                 # a NUL byte inside the path?
    xorl %edx, %edx
    testq %rax, %rax
    setnz %dl                       # %rdx = 1 if there is one
    movq %r12, %rax
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_file_raise -- sea_err(code, site, {path, errno}); noreturn.
#   Inputs  : %edi = code (SEA_E_CANNOT_*, args letters "se"), %rsi =
#             site, %rdx = the path string, %rcx = the host errno
#   Outputs : never returns
#   Frame   : 8 bytes (%rbp), %rsp rounded down to 16, a 16-byte slot
#             vector at 0(%rsp)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_raise:
    pushq %rbp
    movq %rsp, %rbp
    andq $-16, %rsp                 # noreturn: align however we came here
    subq $16, %rsp
    movq %rdx, 0(%rsp)              # slot 0: the path
    movq %rcx, SEA_SLOT_SIZE(%rsp)  # slot 1: the errno
    movq %rsp, %rdx
    call sea_err                    # noreturn
    ud2

# ---------------------------------------------------------------------
# sea_make_dir -- entry MAKE_DIR (DESIGN.md 4.8 entry 25; LANGUAGE.md
#   10.10). See the file header.
#   Inputs  : %rdi = the path string (borrowed), %rsi = site
#   Outputs : none (returns when the directory exists afterwards)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = the path, %r12 =
#             site, %r13 = the NUL-terminated block, %r14 = the saved
#             errno, %rbp = frame pointer
#   Frame   : 40 bytes (%rbp %rbx %r12-%r14) + 8 pad = 48 bytes
# ---------------------------------------------------------------------
    .globl sea_make_dir
    .type sea_make_dir, @function
    .p2align 4
sea_make_dir:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    call .Lrt_file_cpath            # (%rdi = path, %rsi = site)
    movq %rax, %r13
    movl $RT_FILE_EINVAL, %r14d     # a NUL byte in the path: EINVAL
    testq %rdx, %rdx
    jnz .Lrt_file_md_fail
    # mkdir(buf, 0777): success is the end.
    movq %r13, %rdi
    movl $RT_FILE_DIR_MODE, %esi
    call mkdir@PLT
    testl %eax, %eax
    jz .Lrt_file_md_ok
    call __errno_location@PLT
    movslq (%rax), %r14             # the errno of mkdir, saved first
    # Is the path a directory already? open(buf, O_RDONLY | O_DIRECTORY).
    movq %r13, %rdi
    movl $(RT_FILE_O_RDONLY | RT_FILE_O_DIRECTORY), %esi
    xorl %eax, %eax                 # variadic: no vector registers
    call open@PLT
    testl %eax, %eax
    js .Lrt_file_md_fail            # not a directory: report mkdir's errno
    movl %eax, %edi
    call close@PLT                  # a directory: close it, done
.Lrt_file_md_ok:
    movq %r13, %rdi
    movq SEA_STR_LEN(%rbx), %rsi
    incq %rsi
    call sea_free_block             # the NUL-terminated block
    addq $8, %rsp
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_file_md_fail:
    movq %r13, %rdi
    movq SEA_STR_LEN(%rbx), %rsi
    incq %rsi
    call sea_free_block             # freed on every exit
    movl $SEA_E_CANNOT_MKDIR, %edi
    movq %r12, %rsi
    movq %rbx, %rdx
    movq %r14, %rcx
    call .Lrt_file_raise            # noreturn
    ud2
    .size sea_make_dir, . - sea_make_dir

# ---------------------------------------------------------------------
# .Lrt_file_free_state -- free the emitter's state and forget it.
#   Purpose : release the retained path, free the buffer, the stack and
#             the state block, and clear sea_json_st. The descriptor
#             is not touched (the callers have closed it or never opened
#             it).
#   Inputs  : none (the state of sea_json_st, not 0)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = the state, %rbp =
#             frame pointer
#   Frame   : 24 bytes (%rbp %rbx + 8 pad)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_free_state:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq sea_json_st(%rip), %rbx
    movq $0, sea_json_st(%rip)  # no write_json is running any more
    movq RTJ_PATH(%rbx), %rdi
    call sea_release                # the retained path
    movq RTJ_BUF(%rbx), %rdi
    movl $SEA_JSON_BUF_BYTES, %esi
    call sea_free_block             # the buffer
    movq RTJ_STK(%rbx), %rdi
    movq RTJ_CAP(%rbx), %rsi
    call sea_free_block             # the container stack
    movq %rbx, %rdi
    movl $RTJ_SIZE, %esi
    call sea_free_block             # the state itself
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_file_fail -- a write or close of the JSON file failed; noreturn.
#   Purpose : close the descriptor if it is still open (its result
#             ignored), set RTJ_FD to -1, keep the state and the path,
#             then sea_err(CANNOT_WRITE, site, {path, errno}).
#   Inputs  : %rdi = the saved host errno
#   Outputs : never returns
#   Callee-saved used (not restored): %rbx = errno, %r12 = the state
#   Frame   : 8 bytes (%rbp), %rsp rounded down to 16
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_fail:
    pushq %rbp
    movq %rsp, %rbp
    andq $-16, %rsp                 # noreturn: align however we came here
    movq %rdi, %rbx                 # the errno, kept across close
    movq sea_json_st(%rip), %r12
    movq RTJ_FD(%r12), %rdi
    cmpq $-1, %rdi
    je 1f                           # already closed
    movq $-1, RTJ_FD(%r12)          # no open file for sea_err
    call close@PLT                  # result ignored
1:  movl $SEA_E_CANNOT_WRITE, %edi
    movq .Lrt_file_site(%rip), %rsi
    movq RTJ_PATH(%r12), %rdx
    movq %rbx, %rcx
    call .Lrt_file_raise            # noreturn
    ud2

# ---------------------------------------------------------------------
# .Lrt_file_flush -- write the buffered bytes of the JSON file.
#   Purpose : sea_write_all(fd, buf, fill), the buffer emptied; a
#             failure is .Lrt_file_fail(errno) (noreturn).
#   Inputs  : none (the state)
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp = frame pointer
#   Frame   : 8 bytes (%rbp)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_flush:
    pushq %rbp                      # %rsp = 0 (mod 16)
    movq %rsp, %rbp
    movq sea_json_st(%rip), %rax
    movq RTJ_FILL(%rax), %rdx
    testq %rdx, %rdx
    jz 1f                           # nothing buffered
    movq $0, RTJ_FILL(%rax)         # emptied either way
    movq RTJ_FD(%rax), %rdi
    movq RTJ_BUF(%rax), %rsi
    call sea_write_all              # %rax = 0 or the errno
    testq %rax, %rax
    jz 1f
    movq %rax, %rdi
    call .Lrt_file_fail             # noreturn
1:  popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_file_put -- append bytes to the JSON buffer, writing it whenever
#   it becomes full.
#   Inputs  : %rdi = bytes, %rsi = count (may be 0)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = source cursor, %r12 =
#             bytes left, %rbp = frame pointer
#   Frame   : 24 bytes (%rbp %rbx %r12)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_put:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
.Lrt_file_put_loop:
    testq %r12, %r12
    jz .Lrt_file_put_done
    movq sea_json_st(%rip), %rax
    movq RTJ_FILL(%rax), %rcx
    movl $SEA_JSON_BUF_BYTES, %edx
    subq %rcx, %rdx                 # free space (>= 1)
    cmpq %rdx, %r12
    cmovbq %r12, %rdx               # n = min(left, free)
    movq RTJ_BUF(%rax), %rdi
    addq %rcx, %rdi                 # destination = buffer + fill
    addq %rdx, %rcx
    movq %rcx, RTJ_FILL(%rax)       # fill += n
    movq %rbx, %rsi
    addq %rdx, %rbx
    subq %rdx, %r12
    call memcpy@PLT
    movq sea_json_st(%rip), %rax
    cmpq $SEA_JSON_BUF_BYTES, RTJ_FILL(%rax)
    jb .Lrt_file_put_loop           # room left
    call .Lrt_file_flush            # full: write it out
    jmp .Lrt_file_put_loop
.Lrt_file_put_done:
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_file_byte -- append one byte to the JSON buffer.
#   Inputs  : %edi = the byte
#   Clobbers: all caller-saved registers (a flush may run)
#   Callee-saved used: none
#   Frame   : none (a tail jump to .Lrt_file_flush when the buffer fills)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_byte:
    movq sea_json_st(%rip), %rax
    movq RTJ_FILL(%rax), %rcx       # < SEA_JSON_BUF_BYTES between calls
    movq RTJ_BUF(%rax), %rdx
    movb %dil, (%rdx,%rcx)
    incq %rcx
    movq %rcx, RTJ_FILL(%rax)
    cmpq $SEA_JSON_BUF_BYTES, %rcx
    je .Lrt_file_flush              # full: write it out (tail call)
    ret

# ---------------------------------------------------------------------
# .Lrt_file_nl_indent -- append LF and 2 * n spaces.
#   Inputs  : %rdi = n (a depth)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = spaces left, %rbp =
#             frame pointer
#   Frame   : 24 bytes (%rbp %rbx + 8 pad)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_nl_indent:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    leaq (%rdi,%rdi), %rbx          # 2n spaces
    movl $10, %edi                  # LF
    call .Lrt_file_byte
1:  testq %rbx, %rbx
    jz 2f
    movl $RTJ_SPACES, %esi
    cmpq %rsi, %rbx
    cmovbq %rbx, %rsi               # n = min(left, RTJ_SPACES)
    subq %rsi, %rbx
    leaq .Lrt_file_blanks(%rip), %rdi
    call .Lrt_file_put
    jmp 1b
2:  addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_file_vstart -- the prefix of a value about to be written.
#   Purpose : nothing for the top value (depth 0) or a member's value
#             (the innermost container is an object: its key wrote the
#             prefix); in an array, `,` if it has an element already,
#             then LF and 2 * depth spaces, and the array is marked as
#             having an element.
#   Inputs  : none (the state)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = depth, %rbp = frame
#             pointer
#   Frame   : 24 bytes (%rbp %rbx + 8 pad)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_vstart:
    movq sea_json_st(%rip), %rax
    movq RTJ_DEPTH(%rax), %rcx
    testq %rcx, %rcx
    jz 3f                           # the top value: no prefix
    movq RTJ_STK(%rax), %rdx
    movzbl -1(%rdx,%rcx), %r8d      # the innermost container
    testl $RTJ_K_ARR, %r8d
    jz 3f                           # an object: the key wrote the prefix
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rcx, %rbx                 # depth
    orb $RTJ_K_HAS, -1(%rdx,%rcx)   # the array has an element now
    testl $RTJ_K_HAS, %r8d
    jz 1f                           # its first element: no comma
    movl $44, %edi                  # ','
    call .Lrt_file_byte
1:  movq %rbx, %rdi
    call .Lrt_file_nl_indent
    addq $8, %rsp
    popq %rbx
    popq %rbp
3:  ret

# ---------------------------------------------------------------------
# .Lrt_file_begin -- begin an object or an array as the next value.
#   Purpose : the value's prefix, then push the container (no element
#             yet), growing the stack when it is full, then the byte `{`
#             or `[` (growth first: an out-of-memory leaves the file
#             untouched).
#   Inputs  : %edi = 0 for an object, RTJ_K_ARR for an array
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = kind, %r12 = the
#             state, %r13 = the new stack block, %rbp = frame pointer
#   Frame   : 32 bytes (%rbp %rbx %r12 %r13) + 8 pad = 40 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_begin:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movl %edi, %ebx
    call .Lrt_file_vstart
    movq sea_json_st(%rip), %r12
    movq RTJ_DEPTH(%r12), %rcx
    cmpq RTJ_CAP(%r12), %rcx
    jb 1f                           # room for one more container
    # Grow: twice the capacity, the entries copied, the old block freed.
    movq RTJ_CAP(%r12), %rdi
    shlq $1, %rdi
    movq .Lrt_file_site(%rip), %rsi
    call sea_alloc                  # out of memory there (L-co)
    movq %rax, %r13
    movq %r13, %rdi
    movq RTJ_STK(%r12), %rsi
    movq RTJ_DEPTH(%r12), %rdx
    call memcpy@PLT
    movq RTJ_STK(%r12), %rdi
    movq RTJ_CAP(%r12), %rsi
    call sea_free_block
    movq %r13, RTJ_STK(%r12)
    shlq $1, RTJ_CAP(%r12)
    movq RTJ_DEPTH(%r12), %rcx
1:  movq RTJ_STK(%r12), %rdx
    movb %bl, (%rdx,%rcx)           # the new container, no element yet
    incq %rcx
    movq %rcx, RTJ_DEPTH(%r12)
    # The byte last, so that an out-of-memory in the growth above leaves
    # the file as it was (the same order as the arm64 runtime).
    movl $123, %edi                 # '{'
    movl $91, %eax                  # '['
    testl %ebx, %ebx
    cmovnzl %eax, %edi
    call .Lrt_file_byte
    addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_file_end -- end the innermost container.
#   Purpose : pop it; if it has an element, LF and 2 * (depth after the
#             pop) spaces; then `}` or `]`.
#   Inputs  : none (the state)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = the entry, %r12 =
#             the depth, %rbp = frame pointer
#   Frame   : 24 bytes (%rbp %rbx %r12)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_end:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq sea_json_st(%rip), %rax
    movq RTJ_DEPTH(%rax), %r12
    decq %r12
    movq %r12, RTJ_DEPTH(%rax)      # popped
    movq RTJ_STK(%rax), %rdx
    movzbl (%rdx,%r12), %ebx        # its entry
    testl $RTJ_K_HAS, %ebx
    jz 1f                           # empty: `{}` / `[]`
    movq %r12, %rdi
    call .Lrt_file_nl_indent
1:  movl $125, %edi                 # '}'
    movl $93, %eax                  # ']'
    testl $RTJ_K_ARR, %ebx
    cmovnzl %eax, %edi
    call .Lrt_file_byte
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_file_wstr -- a string, escaped (LANGUAGE.md 11.4, L-bz).
#   Purpose : `"`, the bytes with `\"`, `\\`, `\n`, `\t` and `\u00xx`
#             (lowercase hex) for the other bytes below 0x20, the rest
#             as they are (runs of them copied with one .Lrt_file_put),
#             `"`.
#   Inputs  : %rdi = the string object, or null (written as "")
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = cursor, %r12 = end,
#             %r13 = start of the pending run, %rbp = frame pointer; the
#             escape text at 0(%rsp)
#   Frame   : 32 bytes (%rbp %rbx %r12 %r13) + 8 pad + 16 (escape) = 56
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_wstr:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $24, %rsp                  # %rsp = 0 (mod 16); escape at 0(%rsp)
    xorl %ebx, %ebx                 # a null string: no bytes, written as ""
    xorl %r12d, %r12d
    testq %rdi, %rdi
    jz 1f
    leaq SEA_STR_BYTES(%rdi), %rbx
    movq SEA_STR_LEN(%rdi), %r12
    addq %rbx, %r12                 # end of the bytes
1:  movl $34, %edi                  # opening '"'
    call .Lrt_file_byte
    movq %rbx, %r13                 # the pending run starts here
.Lrt_file_wstr_loop:
    cmpq %r12, %rbx
    jae .Lrt_file_wstr_done
    movzbl (%rbx), %eax
    cmpl $34, %eax                  # '"'
    je .Lrt_file_wstr_esc
    cmpl $92, %eax                  # '\'
    je .Lrt_file_wstr_esc
    cmpl $32, %eax
    jb .Lrt_file_wstr_esc           # a control byte
    incq %rbx                       # an ordinary byte: part of the run
    jmp .Lrt_file_wstr_loop
.Lrt_file_wstr_esc:
    # The run before this byte, then its escape.
    movq %r13, %rdi
    movq %rbx, %rsi
    subq %r13, %rsi
    call .Lrt_file_put
    movzbl (%rbx), %eax
    incq %rbx
    movq %rbx, %r13                 # the next run starts after it
    movb $92, 0(%rsp)               # '\'
    movl $2, %esi                   # a two-byte escape unless \u00xx
    movb %al, 1(%rsp)               # \" and \\ : the byte itself
    cmpl $34, %eax
    je 2f
    cmpl $92, %eax
    je 2f
    movb $110, 1(%rsp)              # \n
    cmpl $10, %eax
    je 2f
    movb $116, 1(%rsp)              # \t
    cmpl $9, %eax
    je 2f
    movb $117, 1(%rsp)              # \u00 and two lowercase hex digits
    movb $48, 2(%rsp)
    movb $48, 3(%rsp)
    leaq .Lrt_file_hex(%rip), %rcx
    movl %eax, %edx
    shrl $4, %edx
    movb (%rcx,%rdx), %dl
    movb %dl, 4(%rsp)               # high digit (0 or 1)
    andl $15, %eax
    movb (%rcx,%rax), %al
    movb %al, 5(%rsp)               # low digit
    movl $6, %esi
2:  movq %rsp, %rdi
    call .Lrt_file_put
    jmp .Lrt_file_wstr_loop
.Lrt_file_wstr_done:
    movq %r13, %rdi                 # the last run
    movq %rbx, %rsi
    subq %r13, %rsi
    call .Lrt_file_put
    movl $34, %edi                  # closing '"'
    call .Lrt_file_byte
    addq $24, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_file_wf64 -- a number: %.17g of a finite x, `null` otherwise.
#   Inputs  : %xmm0 = x
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp = frame pointer; the text at 0(%rsp)
#   Frame   : 8 bytes (%rbp) + 8 pad + RTJ_NUMBUF = 48 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_wf64:
    pushq %rbp
    movq %rsp, %rbp
    subq $(RTJ_NUMBUF + 8 + 8), %rsp # %rsp = 0 (mod 16); text at 0(%rsp)
    movq %xmm0, %rax
    shlq $1, %rax                   # |bits| << 1
    movabsq $RTJ_INF2, %rcx
    cmpq %rcx, %rax
    jb 1f
    leaq .Lrt_file_s_null(%rip), %rdi # NaN, +-Inf: null
    movl $4, %esi
    jmp 2f
1:  # snprintf(buf, RTJ_NUMBUF, "%.17g", x): variadic, one vector
    # register (%al = 1), x still in %xmm0.
    movq %rsp, %rdi
    movl $RTJ_NUMBUF, %esi
    leaq .Lrt_file_s_g17(%rip), %rdx
    movl $1, %eax
    call snprintf@PLT               # %eax = text length (<= 24)
    movslq %eax, %rsi
    movq %rsp, %rdi
2:  call .Lrt_file_put
    movq %rbp, %rsp
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_file_wi64 -- an i64 in decimal (`-` before a negative value;
#   -9223372036854775808 for -2^63).
#   Inputs  : %rdi = v
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp = frame pointer; the digits at 0(%rsp)
#   Frame   : 8 bytes (%rbp) + RTJ_NUMBUF
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_wi64:
    pushq %rbp
    movq %rsp, %rbp
    subq $RTJ_NUMBUF, %rsp          # %rsp = 0 (mod 16)
    leaq RTJ_NUMBUF(%rsp), %r8      # digits are written backwards
    movq %rdi, %rax
    xorl %r9d, %r9d                 # negative?
    testq %rax, %rax
    jns 1f
    negq %rax                       # the magnitude (2^63 stays 2^63 unsigned)
    movl $1, %r9d
1:  movl $10, %ecx
2:  xorl %edx, %edx
    divq %rcx                       # %rax = quotient, %rdx = the next digit
    addb $48, %dl
    decq %r8
    movb %dl, (%r8)
    testq %rax, %rax
    jnz 2b
    testl %r9d, %r9d
    jz 3f
    decq %r8
    movb $45, (%r8)                 # '-'
3:  movq %r8, %rdi
    leaq RTJ_NUMBUF(%rsp), %rsi
    subq %r8, %rsi                  # byte count
    call .Lrt_file_put
    movq %rbp, %rsp
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_file_wbool -- `true` for a nonzero v, `false` for 0.
#   Inputs  : %edi = v (0 or 1)
#   Clobbers: all caller-saved registers
#   Frame   : none (a tail jump to .Lrt_file_put)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_wbool:
    testl %edi, %edi
    jz 1f
    leaq .Lrt_file_s_true(%rip), %rdi
    movl $4, %esi
    jmp .Lrt_file_put
1:  leaq .Lrt_file_s_false(%rip), %rdi
    movl $5, %esi
    jmp .Lrt_file_put

# ---------------------------------------------------------------------
# .Lrt_file_elem -- element k of a dynamic array, as the scalar entries
#   write it (by its SEA_ARR_EK: f64, i64, bool, str).
#   Inputs  : %rdi = the array, %rsi = the linear index k
#   Clobbers: all caller-saved registers
#   Frame   : none (a tail jump to the writer)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_file_elem:
    movzbl SEA_ARR_EK(%rdi), %eax
    movq SEA_ARR_DATA(%rdi), %rcx
    cmpl $SEA_EK_BOOL, %eax
    je 1f
    movq (%rcx,%rsi,8), %rdi        # an 8-byte element
    cmpl $SEA_EK_F64, %eax
    je 2f
    cmpl $SEA_EK_STR, %eax
    je .Lrt_file_wstr               # a string pointer
    jmp .Lrt_file_wi64              # SEA_EK_I64
1:  movzbl (%rcx,%rsi), %edi        # a one-byte bool
    jmp .Lrt_file_wbool
2:  movq %rdi, %xmm0                # the bits of an f64
    jmp .Lrt_file_wf64

# ---------------------------------------------------------------------
# sea_json_open -- entry JSON_OPEN (DESIGN.md 4.8 entry 27).
#   Purpose : allocate the state (the path retained, an empty buffer,
#             the stack of RTJ_STK_MIN bytes, depth 0, RTJ_FD -1), then
#             open a NUL-terminated copy of the path with O_WRONLY |
#             O_CREAT | O_TRUNC, mode 0666 (the umask applies), and store
#             the descriptor. A failure (a NUL byte in the path: EINVAL)
#             frees the state, then CANNOT_OPEN with the path and errno.
#   Inputs  : %rdi = the path string (borrowed), %rsi = site
#   Outputs : none
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = the path, %r12 = the
#             state, %r13 = the NUL-terminated block, %r14 = descriptor
#             or errno, %rbp = frame pointer
#   Frame   : 40 bytes (%rbp %rbx %r12-%r14) + 8 pad = 48 bytes
# ---------------------------------------------------------------------
    .globl sea_json_open
    .type sea_json_open, @function
    .p2align 4
sea_json_open:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rsi, .Lrt_file_site(%rip)
    movq %rdi, %rbx
    # 1. The state, with no descriptor.
    movl $RTJ_SIZE, %edi
    movq .Lrt_file_site(%rip), %rsi
    call sea_alloc
    movq %rax, %r12
    movq $-1, RTJ_FD(%r12)
    movq %rbx, RTJ_PATH(%r12)
    movq $0, RTJ_FILL(%r12)
    movq $0, RTJ_DEPTH(%r12)
    movq $RTJ_STK_MIN, RTJ_CAP(%r12)
    movl $SEA_JSON_BUF_BYTES, %edi
    movq .Lrt_file_site(%rip), %rsi
    call sea_alloc
    movq %rax, RTJ_BUF(%r12)
    movl $RTJ_STK_MIN, %edi
    movq .Lrt_file_site(%rip), %rsi
    call sea_alloc
    movq %rax, RTJ_STK(%r12)
    movq %rbx, %rdi
    call sea_retain                 # the path, kept for the messages
    movq %r12, sea_json_st(%rip)
    # 2. The NUL-terminated path, then open.
    movq %rbx, %rdi
    movq .Lrt_file_site(%rip), %rsi
    call .Lrt_file_cpath
    movq %rax, %r13
    movl $RT_FILE_EINVAL, %r14d     # a NUL byte in the path: EINVAL
    testq %rdx, %rdx
    jnz .Lrt_file_open_fail
    movq %r13, %rdi
    movl $RT_FILE_O_WCT, %esi
    movl $RT_FILE_JSON_MODE, %edx
    xorl %eax, %eax                 # variadic: no vector registers
    call open@PLT
    movslq %eax, %r14               # the descriptor, or -1
    testq %r14, %r14
    jns 1f
    call __errno_location@PLT
    movslq (%rax), %r14             # the errno of open
    jmp .Lrt_file_open_fail
1:  movq %r13, %rdi                 # opened: free the copy, store the descriptor
    movq SEA_STR_LEN(%rbx), %rsi
    incq %rsi
    call sea_free_block
    movq %r14, RTJ_FD(%r12)
    addq $8, %rsp
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_file_open_fail:
    movq %r13, %rdi
    movq SEA_STR_LEN(%rbx), %rsi
    incq %rsi
    call sea_free_block             # the NUL-terminated copy
    call .Lrt_file_free_state       # the state (the caller still holds the path)
    movl $SEA_E_CANNOT_OPEN, %edi
    movq .Lrt_file_site(%rip), %rsi
    movq %rbx, %rdx
    movq %r14, %rcx
    call .Lrt_file_raise            # noreturn
    ud2
    .size sea_json_open, . - sea_json_open

# ---------------------------------------------------------------------
# sea_json_close -- entry JSON_CLOSE (DESIGN.md 4.8 entry 28).
#   Purpose : LF after the top value, the final write of the buffer,
#             close; then the path released and the state freed. A
#             failed write or close is CANNOT_WRITE with the path and
#             the errno (.Lrt_file_fail; for close the descriptor is
#             marked -1 first, so it is not closed twice).
#   Inputs  : %rdi = site
#   Outputs : none
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp = frame pointer
#   Frame   : 8 bytes (%rbp)
# ---------------------------------------------------------------------
    .globl sea_json_close
    .type sea_json_close, @function
    .p2align 4
sea_json_close:
    pushq %rbp                      # %rsp = 0 (mod 16)
    movq %rsp, %rbp
    movq %rdi, .Lrt_file_site(%rip)
    movl $10, %edi                  # LF after the top value
    call .Lrt_file_byte
    call .Lrt_file_flush            # the final write
    movq sea_json_st(%rip), %rax
    movq RTJ_FD(%rax), %rdi
    movq $-1, RTJ_FD(%rax)          # closed (whatever close returns)
    call close@PLT
    testl %eax, %eax
    jz 1f
    call __errno_location@PLT
    movslq (%rax), %rdi
    call .Lrt_file_fail             # noreturn
1:  call .Lrt_file_free_state
    popq %rbp
    ret
    .size sea_json_close, . - sea_json_close

# ---------------------------------------------------------------------
# sea_json_obj, sea_json_arr -- entries JSON_OBJ, JSON_ARR (DESIGN.md
#   4.8 entries 29, 30): begin an object / an array as the next value.
#   Inputs  : %rdi = site
#   Clobbers: all caller-saved registers
#   Frame   : none (a tail jump to .Lrt_file_begin)
# ---------------------------------------------------------------------
    .globl sea_json_obj
    .type sea_json_obj, @function
    .p2align 4
sea_json_obj:
    movq %rdi, .Lrt_file_site(%rip)
    xorl %edi, %edi                 # an object
    jmp .Lrt_file_begin
    .size sea_json_obj, . - sea_json_obj

    .globl sea_json_arr
    .type sea_json_arr, @function
    .p2align 4
sea_json_arr:
    movq %rdi, .Lrt_file_site(%rip)
    movl $RTJ_K_ARR, %edi           # an array
    jmp .Lrt_file_begin
    .size sea_json_arr, . - sea_json_arr

# ---------------------------------------------------------------------
# sea_json_end -- entry JSON_END (DESIGN.md 4.8 entry 31): end the
#   innermost open object or array.
#   Inputs  : %rdi = site
#   Clobbers: all caller-saved registers
#   Frame   : none (a tail jump to .Lrt_file_end)
# ---------------------------------------------------------------------
    .globl sea_json_end
    .type sea_json_end, @function
    .p2align 4
sea_json_end:
    movq %rdi, .Lrt_file_site(%rip)
    jmp .Lrt_file_end
    .size sea_json_end, . - sea_json_end

# ---------------------------------------------------------------------
# sea_json_key -- entry JSON_KEY (DESIGN.md 4.8 entry 32).
#   Purpose : in the innermost (open) object: `,` if it has a member
#             already, LF, 2 * depth spaces, the escaped key, `": "`.
#   Inputs  : %rdi = the key string (borrowed), %rsi = site
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = the key, %rbp = frame
#             pointer
#   Frame   : 24 bytes (%rbp %rbx + 8 pad)
# ---------------------------------------------------------------------
    .globl sea_json_key
    .type sea_json_key, @function
    .p2align 4
sea_json_key:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rsi, .Lrt_file_site(%rip)
    movq %rdi, %rbx
    movq sea_json_st(%rip), %rax
    movq RTJ_DEPTH(%rax), %rcx
    movq RTJ_STK(%rax), %rdx
    movzbl -1(%rdx,%rcx), %r8d      # the object
    orb $RTJ_K_HAS, -1(%rdx,%rcx)   # it has a member now
    testl $RTJ_K_HAS, %r8d
    jz 1f                           # its first member: no comma
    movl $44, %edi                  # ','
    call .Lrt_file_byte
1:  movq sea_json_st(%rip), %rax
    movq RTJ_DEPTH(%rax), %rdi
    call .Lrt_file_nl_indent
    movq %rbx, %rdi
    call .Lrt_file_wstr             # "key"
    leaq .Lrt_file_s_colon(%rip), %rdi
    movl $2, %esi
    call .Lrt_file_put              # ": "
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret
    .size sea_json_key, . - sea_json_key

# ---------------------------------------------------------------------
# sea_json_f64 -- entry JSON_F64 (DESIGN.md 4.8 entry 33): the value's
#   prefix, then %.17g of a finite x or `null`.
#   Inputs  : %xmm0 = x, %rdi = site
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp = frame pointer; x at 0(%rsp)
#   Frame   : 8 bytes (%rbp) + 16
# ---------------------------------------------------------------------
    .globl sea_json_f64
    .type sea_json_f64, @function
    .p2align 4
sea_json_f64:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp                  # %rsp = 0 (mod 16)
    movq %rdi, .Lrt_file_site(%rip)
    movsd %xmm0, 0(%rsp)            # x, kept across the prefix
    call .Lrt_file_vstart
    movsd 0(%rsp), %xmm0
    call .Lrt_file_wf64
    movq %rbp, %rsp
    popq %rbp
    ret
    .size sea_json_f64, . - sea_json_f64

# ---------------------------------------------------------------------
# sea_json_i64, sea_json_bool, sea_json_str -- entries JSON_I64,
#   JSON_BOOL, JSON_STR (DESIGN.md 4.8 entries 34-36): the value's
#   prefix, then the value as .Lrt_file_wi64 / _wbool / _wstr write it.
#   Inputs  : %rdi = v (an i64, a bool 0/1, or a borrowed string),
#             %rsi = site
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = v, %rbp = frame
#             pointer
#   Frame   : 24 bytes (%rbp %rbx + 8 pad)
# ---------------------------------------------------------------------
.macro RT_FILE_SCALAR name, writer
    .globl \name
    .type \name, @function
    .p2align 4
\name:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rsi, .Lrt_file_site(%rip)
    movq %rdi, %rbx                 # v, kept across the prefix
    call .Lrt_file_vstart
    movq %rbx, %rdi
    call \writer
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret
    .size \name, . - \name
.endm
    RT_FILE_SCALAR sea_json_i64, .Lrt_file_wi64
    RT_FILE_SCALAR sea_json_bool, .Lrt_file_wbool
    RT_FILE_SCALAR sea_json_str, .Lrt_file_wstr

# ---------------------------------------------------------------------
# sea_json_vec -- entry JSON_VEC (DESIGN.md 4.8 entry 37): a dynamic
#   vector (ek f64, i64, bool or str) as a flat array, each element
#   written as the scalar entries write it; an empty vector is `[]`.
#   Inputs  : %rdi = the array (borrowed), %rsi = site
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = the array, %r12 =
#             its element count (rows * cols), %r13 = index, %rbp =
#             frame pointer
#   Frame   : 32 bytes (%rbp %rbx %r12 %r13) + 8 pad = 40 bytes
# ---------------------------------------------------------------------
    .globl sea_json_vec
    .type sea_json_vec, @function
    .p2align 4
sea_json_vec:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rsi, .Lrt_file_site(%rip)
    movq %rdi, %rbx
    movq SEA_ARR_ROWS(%rbx), %r12
    imulq SEA_ARR_COLS(%rbx), %r12  # elements (cols = 1 for a vector)
    movl $RTJ_K_ARR, %edi
    call .Lrt_file_begin            # `[` as the next value
    xorl %r13d, %r13d
1:  cmpq %r12, %r13
    jae 2f
    call .Lrt_file_vstart           # `,`, LF, indentation
    movq %rbx, %rdi
    movq %r13, %rsi
    call .Lrt_file_elem
    incq %r13
    jmp 1b
2:  call .Lrt_file_end              # `]` (`[]` when empty)
    addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
    .size sea_json_vec, . - sea_json_vec

# ---------------------------------------------------------------------
# sea_json_mat -- entry JSON_MAT (DESIGN.md 4.8 entry 38): a dynamic
#   matrix as an array of rows: for r >= 1 rows and c >= 1 columns, r
#   arrays of c elements, element (i, j) (at i + j * r, column-major) at
#   position j of row i; a matrix with no element is `[]`.
#   Inputs  : %rdi = the array (borrowed), %rsi = site
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = the array, %r12 =
#             rows, %r13 = cols, %r14 = row i, %r15 = column j, %rbp =
#             frame pointer
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + 8 pad = 56 bytes
# ---------------------------------------------------------------------
    .globl sea_json_mat
    .type sea_json_mat, @function
    .p2align 4
sea_json_mat:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rsi, .Lrt_file_site(%rip)
    movq %rdi, %rbx
    movq SEA_ARR_ROWS(%rbx), %r12
    movq SEA_ARR_COLS(%rbx), %r13
    movl $RTJ_K_ARR, %edi
    call .Lrt_file_begin            # the outer `[`
    testq %r12, %r12
    jz 4f                           # no element: `[]`
    testq %r13, %r13
    jz 4f
    xorl %r14d, %r14d               # row i
1:  movl $RTJ_K_ARR, %edi
    call .Lrt_file_begin            # row i's `[` (with its prefix)
    xorl %r15d, %r15d               # column j
2:  call .Lrt_file_vstart
    movq %r15, %rsi
    imulq %r12, %rsi
    addq %r14, %rsi                 # k = i + j * rows
    movq %rbx, %rdi
    call .Lrt_file_elem
    incq %r15
    cmpq %r13, %r15
    jb 2b
    call .Lrt_file_end              # row i's `]`
    incq %r14
    cmpq %r12, %r14
    jb 1b
4:  call .Lrt_file_end              # the outer `]`
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
    .size sea_json_mat, . - sea_json_mat

# ---------------------------------------------------------------------
# sea_json_abort -- for sea_err: flush and close an open JSON file.
#   Purpose : see the file header (LANGUAGE.md 9.2 step 3, L-ca). The
#             descriptor field is set to -1 before anything is written,
#             so the file is never closed twice; failures are ignored.
#   Inputs  : none
#   Outputs : none
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = the descriptor, %rbp
#             = frame pointer
#   Frame   : 24 bytes (%rbp %rbx + 8 pad)
# ---------------------------------------------------------------------
    .globl sea_json_abort
    .hidden sea_json_abort
    .type sea_json_abort, @function
    .p2align 4
sea_json_abort:
    movq sea_json_st(%rip), %rax
    testq %rax, %rax
    jz 2f                           # no write_json is running
    cmpq $-1, RTJ_FD(%rax)
    je 2f                           # no open descriptor
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq RTJ_FD(%rax), %rbx
    movq $-1, RTJ_FD(%rax)          # no open file from now on
    movq RTJ_FILL(%rax), %rdx
    movq $0, RTJ_FILL(%rax)
    testq %rdx, %rdx
    jz 1f
    movl %ebx, %edi
    movq RTJ_BUF(%rax), %rsi
    call sea_write_all              # result ignored
1:  movl %ebx, %edi
    call close@PLT                  # result ignored
    addq $8, %rsp
    popq %rbx
    popq %rbp
2:  ret
    .size sea_json_abort, . - sea_json_abort

# ---------------------------------------------------------------------
# Constant data.
# ---------------------------------------------------------------------
    .section .rodata
.Lrt_file_blanks:
    .space RTJ_SPACES, 32           # a run of spaces for the indentation
.Lrt_file_hex:
    .ascii "0123456789abcdef"       # \u00xx digits, lowercase (L-bz)
.Lrt_file_s_g17:
    .asciz "%.17g"
.Lrt_file_s_null:
    .ascii "null"
.Lrt_file_s_true:
    .ascii "true"
.Lrt_file_s_false:
    .ascii "false"
.Lrt_file_s_colon:
    .ascii ": "

# ---------------------------------------------------------------------
# Mutable state.
# ---------------------------------------------------------------------
    .bss
    .p2align 3
    .globl sea_json_st
    .hidden sea_json_st
    .type sea_json_st, @object
    .size sea_json_st, 8
sea_json_st:
    .zero 8                         # the emitter's state block, or 0
.Lrt_file_site:
    .zero 8                         # the site of the running entry

    .section .note.GNU-stack,"",@progbits
